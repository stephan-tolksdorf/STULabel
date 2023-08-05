// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/ArrayRef.hpp"
#include "stu/ArrayUtils.hpp"

namespace stu {

template <typename T>
struct Repeated {
  static_assert(isCopyConstructible<T>);

  T value;
  Int count;

  template <typename U, EnableIf<isSafelyConvertible<T, U> && !isSame<T, Uninitialized>> = 0>
  /* implicit */
  operator Repeated<U>() const noexcept(isNothrowConstructible<U, const T&>) {
    return {value, count};
  }
};

template <typename T>
STU_CONSTEXPR Repeated<T> repeat(T value, Int count) {
  return {std::move(value), count};
}

template <typename T, int length>
struct ArrayStorage {
  T array[length];

  STU_CONSTEXPR_T Int count() const noexcept { return length; }

  STU_CONSTEXPR_T const T* begin() const noexcept { return array; }
  STU_CONSTEXPR_T       T* begin()       noexcept { return array; }

  STU_CONSTEXPR_T const T* end() const noexcept { return array + length; }
  STU_CONSTEXPR_T       T* end()       noexcept { return array + length; }
};

template <typename T>
struct ArrayStorage<T, 0> {
  STU_CONSTEXPR_T Int count() const noexcept { return 0; }

  STU_CONSTEXPR_T const T* begin() const noexcept { return nullptr; }
  STU_CONSTEXPR_T       T* begin()       noexcept { return nullptr; }

  STU_CONSTEXPR_T const T* end() const noexcept { return nullptr; }
  STU_CONSTEXPR_T       T* end()       noexcept { return nullptr; }
};

template <typename T, typename LengthOrAllocatorRef = Malloc, int... staticCount>
class Array;

template <typename T, int count>
class Array<T, Fixed, count>
      : public ArrayStorage<T, count>,
        public ArrayBase<Array<T, Fixed, count>, T&, const T&>
{
  static_assert(count >= 0);
public:
  Array() = default;
};

namespace detail {
  template <typename T>
  struct ArrayFields {
    T* begin_{};
    Int count_{};
  };
}

template <typename T, typename AllocatorRef, int... staticCount>
class Array
      : private detail::ArrayFields<T>,
        public ArrayBase<Array<T, AllocatorRef>, T&, const T&>,
        private AllocatorRef
{
  static_assert(isAllocatorRef<AllocatorRef>);
  static_assert(sizeof...(staticCount) == 0);

  using Fields = detail::ArrayFields<T>;

  using Fields::begin_;
  using Fields::count_;

public:
  STU_INLINE_T
  Array() = default;

  STU_INLINE
  explicit Array(AllocatorRef allocator) noexcept
  : AllocatorRef{std::move(allocator)}
  {}

  template <bool enable = isMemberwiseConstructible<T>, EnableIf<enable> = 0>
  STU_INLINE
  Array(Uninitialized, Count<Int> count, AllocatorRef allocator = AllocatorRef{}) noexcept
  : Array{std::move(allocator)}
  {
    begin_ = this->allocator().get().template allocate<T>(count.value);
    count_ = count.value;
  }

  template <bool enable = isBitwiseZeroConstructible<T>, EnableIf<enable> = 0>
  STU_INLINE
  Array(ZeroInitialized, Count<Int> count, AllocatorRef allocator = AllocatorRef()) noexcept
  : Array{std::move(allocator)}
  {
    if constexpr (isSame<AllocatorRef, Malloc>) {
      begin_ = static_cast<T*>(calloc(sign_cast(count.value), sizeof(T)));
      if (!begin_) {
        detail::badAlloc();
      }
    } else {
      begin_ = this->allocator().get().template allocate<T>(count.value);
      memset(begin_, 0, sign_cast(count.value)*sizeof(T));
    }
    count_ = count.value;
  }

  template <bool enable = isDefaultConstructible<T>, EnableIf<enable> = 0>
  STU_INLINE
  Array(Count<Int> count, AllocatorRef allocator = AllocatorRef{}) noexcept
  : Array{std::move(allocator)}
  {
    T* array = this->allocator().get().template allocate<T>(count.value);
    auto guard = scopeGuardIf<!isNothrowConstructible<T>>([&] {
      this->allocator().get().deallocate(array, count.value);
    });
    array_utils::initializeArray(array, count.value);
    guard.dismiss();
    begin_ = array;
    count_ = count.value;
  }

  template <bool enable = isCopyConstructible<T>, EnableIf<enable> = 0>
  STU_INLINE
  Array(Repeated<T> repeatedValue, AllocatorRef allocator = AllocatorRef())
    noexcept(isNothrowCopyConstructible<T>)
  : Array{std::move(allocator)}
  {
    T* array = this->allocator().get().template allocate<T>(repeatedValue.count);
    auto guard = scopeGuardIf<!isNothrowCopyConstructible<T>>([&] {
      this->allocator().get().deallocate(array, repeatedValue.count);
    });
    array_utils::initializeArray(array, repeatedValue.count, repeatedValue.value);
    guard.dismiss();
    begin_ = array;
    count_ = repeatedValue.count;
  }

  STU_INLINE
  Array(T* array, Int count, AllocatorRef allocator) noexcept(!STU_ASSERT_MAY_THROW)
  : Fields{array, count}, AllocatorRef{std::move(allocator)}
  {
    STU_PRECONDITION(count >= 0);
  }

  Array(const Array&) = delete;
  Array& operator=(const Array&) = delete;

  STU_INLINE
  Array(Array&& other) noexcept
  : Fields{std::exchange(other.begin_, nullptr), std::exchange(other.count_, 0)},
    AllocatorRef{std::move(other).allocator()}
  {}

  [[nodiscard]] STU_INLINE
  ArrayRef<T> toNonOwningArrayRef() && noexcept {
    ArrayRef<T> array{begin_, count_};
    begin_ = nullptr;
    count_ = 0;
    return array;
  }

  STU_INLINE
  Array& operator=(Array&& other) noexcept {
    if (this != &other) {
      if (begin_) {
        array_utils::destroyAndDeallocate(allocator(), begin_, count_);
      }
      begin_ = std::exchange(other.begin_, nullptr);
      count_ = std::exchange(other.count_, 0);
      static_cast<AllocatorRef&>(*this) = std::move(other.allocator());
    }
    return *this;
  }

  STU_INLINE
  ~Array() {
    if (begin_) {
      array_utils::destroyAndDeallocate(allocator(), begin_, count_);
    }
  }

  STU_INLINE_T const T* begin() const noexcept { return begin_; }
  STU_INLINE_T       T* begin()       noexcept { return begin_; }

  STU_INLINE_T Int count() const noexcept { return count_; }

  STU_INLINE_T
  const AllocatorRef& allocator() const & { return static_cast<const AllocatorRef&>(*this); }
  STU_INLINE_T AllocatorRef&  allocator() & { return static_cast<AllocatorRef&>(*this); }
  STU_INLINE_T AllocatorRef&& allocator() && { return std::move(*this); }
};

template <typename T, int count>
struct IsBitwiseCopyable<Array<T, Fixed, count>> : IsBitwiseCopyable<T> {};
template <typename T, int count>
struct IsBitwiseMovable<Array<T, Fixed, count>> : IsBitwiseMovable<T> {};

template <typename T, typename AllocatorRef>
struct IsBitwiseMovable<Array<T, AllocatorRef>> : IsBitwiseMovable<AllocatorRef> {};


template <typename T, typename AllocatorRef>
class UninitializedArray : private detail::ArrayFields<T>, AllocatorRef {
  static_assert(isAllocatorRef<AllocatorRef>);
  using Fields = detail::ArrayFields<T>;
  using Fields::begin_;
  using Fields::count_;

public:
  STU_INLINE
  UninitializedArray(Capacity<Int> capacity, AllocatorRef allocator = AllocatorRef{})
  : AllocatorRef{std::move(allocator)}
  {
    if (capacity != 0) {
      begin_ = this->allocator().get().template allocate<T>(capacity.value);
      count_ = capacity.value;
    }
  }

  UninitializedArray(const UninitializedArray&) = delete;
  UninitializedArray& operator=(const UninitializedArray&) = delete;

  STU_INLINE
  UninitializedArray(UninitializedArray&& other) noexcept
  : Fields{std::exchange(other.begin_, nullptr), std::exchange(other.count_, 0)},
    AllocatorRef{std::move(other).allocator()}
  {}

  STU_INLINE
  UninitializedArray& operator=(UninitializedArray&& other) noexcept {
    if (this != &other) {
      if (begin_) {
        this->allocator().get().deallocate(begin_, count_);
      }
      begin_ = std::exchange(other.begin_, nullptr);
      count_ = std::exchange(other.count_, 0);
      static_cast<AllocatorRef&>(*this) = std::move(other.allocator());
    }
    return *this;
  }

  STU_INLINE
  ~UninitializedArray() {
    if (begin_) {
      this->allocator().get().deallocate(begin_, count_);
    }
  }

  [[nodiscard]] STU_INLINE
  ArrayRef<T> toNonOwningArrayRef() && noexcept {
    ArrayRef<T> array{begin_, count_};
    begin_ = nullptr;
    count_ = 0;
    return array;
  }

  STU_INLINE_T const T* begin() const noexcept { return begin_; }
  STU_INLINE_T       T* begin()       noexcept { return begin_; }

  STU_INLINE_T Int capacity() const noexcept { return count_; }

  STU_INLINE_T
  const AllocatorRef& allocator() const & { return static_cast<const AllocatorRef&>(*this); }
  STU_INLINE_T AllocatorRef&  allocator() & { return static_cast<AllocatorRef&>(*this); }
  STU_INLINE_T AllocatorRef&& allocator() && { return std::move(*this); }
};

} // namespace stu
