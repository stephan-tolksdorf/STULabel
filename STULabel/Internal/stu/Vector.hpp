// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Array.hpp"
#include "stu/Ref.hpp"

namespace stu {

template <typename T, int minEmbeddedStorageCapacity = 0,
          typename AllocatorRef = stu::Malloc>
class Vector;

/// Due to implementation details, the embedded storage capacity must be an odd value.
template <typename T, int oddCapacity>
class VectorStorage {
public:
  static constexpr int capacity = oddCapacity;
  static_assert(capacity > 0 && capacity%2 == 1);

#if STU_USE_ADDRESS_SANITIZER
  STU_INLINE
  VectorStorage() {
    sanitizer::annotateContiguousArray(buffer_, capacity*sizeof(T), capacity*sizeof(T), size_t{0});
  }

  STU_INLINE
  ~VectorStorage() {
    sanitizer::annotateContiguousArray(buffer_, capacity*sizeof(T), size_t{0}, capacity*sizeof(T));
  }
#endif

private:
  template <typename, int, typename> friend class Vector;

  STU_INLINE_T T* buffer() { return reinterpret_cast<T*>(buffer_); }

#if STU_USE_ADDRESS_SANITIZER
  alignas(max(alignof(T), 8u))
#else
  alignas(T)
#endif
  Byte buffer_[capacity*sizeof(T)];
};

template <typename T>
class VectorStorage<T, 0> {
public:
  static constexpr int capacity = 0;
private:
  template <typename, int, typename> friend class Vector;

  STU_INLINE_T T* buffer() { return nullptr; }
};

namespace detail {
  template <typename AllocatorRef, bool mayReferenceExternalStorage,
            bool inlineAllocatorRefGet = !AllocatorRefHasNonTrivialGet<AllocatorRef>::value>
  class VectorBaseWithAllocatorRef;
}

template <typename T, int minEmbeddedStorageCapacity, typename AllocatorRef>
class Vector
      : private detail::VectorBaseWithAllocatorRef<AllocatorRef, minEmbeddedStorageCapacity != 0>,
        public ArrayBase<Vector<T, minEmbeddedStorageCapacity, AllocatorRef>, T&, const T&>,
        private VectorStorage<T, max(0, minEmbeddedStorageCapacity)>
{
  using Base = detail::VectorBaseWithAllocatorRef<AllocatorRef, minEmbeddedStorageCapacity != 0>;
  using ArrayBase = ArrayBase<Vector<T, minEmbeddedStorageCapacity, AllocatorRef>, T&, const T&>;

  static_assert(minEmbeddedStorageCapacity >= -1);
  static_assert(isAllocatorRef<AllocatorRef>);

  static_assert(isNothrowDestructible<T>);
  static_assert(isBitwiseMovable<T>,
                "This is only a sneak peek version of the full implementation.");

  using Base::begin_;
  using Base::count_;
  using Base::capacity_;
  using EmbeddedStorage = VectorStorage<T, max(0, minEmbeddedStorageCapacity)>;

  STU_INLINE EmbeddedStorage& embeddedStorage() {
    return static_cast<EmbeddedStorage&>(*this);
  }

  template <typename, int, typename> friend class Vector;

public:
  static const int embeddedStorageCapacity = EmbeddedStorage::capacity;

  using Base::isAllocated;

  // SFINAE-disabling this and other constructors when the AllocatorRef is not default-constructible
  // improves the error messages generated by clang.
  template <bool enable = true, EnableIf<enable && isDefaultConstructible<AllocatorRef>> = 0>
  STU_INLINE_T
  Vector() noexcept(isNothrowConstructible<AllocatorRef>)
  : Vector{embeddedStorage(), AllocatorRef{}, unchecked}
  {}

  explicit STU_INLINE
  Vector(AllocatorRef allocator) noexcept
  : Vector{embeddedStorage(), std::move(allocator), unchecked}
  {}

  template <int n,
            EnableIf<minEmbeddedStorageCapacity != 0 && isDefaultConstructible<AllocatorRef>
                     && delayToInstantiation(n)> = 0>
  explicit STU_INLINE
  Vector(Ref<VectorStorage<T, n>> storage) noexcept
  : Vector{storage.get(), AllocatorRef{}, unchecked}
  {}

  template <int n, EnableIf<minEmbeddedStorageCapacity != 0 && delayToInstantiation(n)> = 0>
  explicit STU_INLINE
  Vector(Ref<VectorStorage<T, n>> storage, AllocatorRef allocator) noexcept
  : Vector{storage.get(), std::move(allocator), unchecked}
  {}

private:
  template <int n>
  STU_INLINE
  Vector(VectorStorage<T, n>& storage, AllocatorRef allocator, Unchecked)
  : Base{storage.buffer(), 0, VectorStorage<T, n>::capacity, std::move(allocator)}
  {
  #if STU_USE_ADDRESS_SANITIZER
    STU_DEBUG_ASSERT(n == 0 || __asan_address_is_poisoned(storage.buffer()));
  #endif
  }

public:
  // We'll implement these members when we need them.
  Vector(const Vector& other) = delete;
  Vector& operator=(const Vector& other) = delete;

  template <bool enable = true,
            EnableIf<enable && (minEmbeddedStorageCapacity <= 0
                                || isNothrowMoveConstructible<T>)> = 0>
  STU_INLINE
  Vector(Vector&& other) noexcept
  : Vector{std::move(other).allocator()}
  {
    initWithRValueVector(std::move(other));
  }
  template <int s>
  STU_INLINE
  Vector(Vector<T, s, AllocatorRef>&& other) noexcept
  : Vector{std::move(other).allocator()}
  {
    static_assert(minEmbeddedStorageCapacity >= s,
                  "The moved from Vector cannot have a greater embedded storage capacity.");
    static_assert(s != -1 || minEmbeddedStorageCapacity != 0);
    static_assert(s <= 0 || isNothrowMoveConstructible<T>);
    initWithRValueVector(std::move(other));
  }

  Vector& operator=(Vector<T, 0, AllocatorRef>&& other) noexcept {
    if (this != &other) {
      destroy();
      static_cast<AllocatorRef&&>(*this) = std::move(other).allocator();
      initWithRValueVector(std::move(other));
    }
    return *this;
  }

  STU_INLINE
  Vector(Capacity<Int> capacity, AllocatorRef allocator = AllocatorRef{}) noexcept
  : Vector{std::move(allocator)}
  {
    setCapacity(capacity.value);
  }

  STU_INLINE
  Vector(UninitializedArray<T, AllocatorRef> uninitializeArray) noexcept
  : Vector{std::move(uninitializeArray).allocator()}
  {
    begin_ = uninitializeArray.begin();
    capacity_ = uninitializeArray.capacity();
    discard(std::move(uninitializeArray).toNonOwningArrayRef());
  }

  STU_INLINE
  ~Vector() {
    destroy();
  }

  /* implicit */ STU_INLINE
  operator Array<T, AllocatorRef>() &&
    noexcept(minEmbeddedStorageCapacity == 0 && !STU_ASSERT_MAY_THROW)
  {
    Base::decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(sizeof(T));
    return {down_cast<T*>(std::exchange(begin_, nullptr)),
            std::exchange(count_, 0),
            std::move(*this).allocator()};
  }

  STU_INLINE_T const T* begin() const noexcept { return down_cast<const T*>(begin_); }
  STU_INLINE_T       T* begin()       noexcept { return down_cast<      T*>(begin_); }

  using ArrayBase::end;

  STU_INLINE_T
  Int count() const noexcept {
    STU_ASSUME(count_ >= 0);
    return count_;
  }

  STU_INLINE_T
  Int capacity() const {
    STU_ASSUME(capacity_ >= 0);
    return capacity_;
  }

  STU_INLINE_T
  Int freeCapacity() const {
    const Int result = capacity_ - count_;
    STU_ASSUME(result >= 0);
    return result;
  }

  using Base::allocator;

  STU_INLINE
  void ensureFreeCapacity(Int minFreeCapacity) {
    if (freeCapacity() < minFreeCapacity) {
      ensureFreeCapacity_slowPath(minFreeCapacity);
    }
  }

  STU_INLINE
  void trimFreeCapacity(Int desiredMaxFreeCapacity = 0)  {
    if (freeCapacity() > desiredMaxFreeCapacity) {
      trimFreeCapacity_slowPath(desiredMaxFreeCapacity);
    }
  }

  STU_INLINE
  void setCapacity(Int capacity) {
    if (capacity > capacity_) {
      Base::increaseCapacity_bitwiseMovableElements(sign_cast(capacity), sizeof(T));
      STU_ASSUME(capacity_ >= capacity);
      STU_ASSUME(begin_ != nullptr);
    } else if (capacity < capacity_) {
      STU_PRECONDITION(capacity >= count_);
      Base::decreaseCapacity_bitwiseMovableElements(capacity, sizeof(T));
    }
  }

  // Accepting the argument by value simplifies exception handling and avoids aliasing issues
  // (but makes transactional use with move-only types impossible).
  STU_INLINE
  T& append(T value) {
    static_assert(isNothrowMoveConstructible<T>);
    const Int count = count_;
    if (STU_UNLIKELY(count == capacity_)) {
      ensureFreeCapacity_slowPath();
    }
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count + 1);
    T* p = begin() + count;
    STU_ASSUME(p != nullptr);
    new (p) T(std::move(value));
    count_ = count + 1;
    return *p;
  }

  template <bool enable = !isConstructible<T, Uninitialized>, EnableIf<enable> = 0>
  STU_INLINE
  T& append(Uninitialized) {
    static_assert(isTriviallyDestructible<T>);
    if (STU_UNLIKELY(count_ == capacity_)) {
      // For consistency with the other single-element append methods.
      ensureFreeCapacity_slowPath();
      STU_ASSUME(capacity_ > count_);
    }
    return *append(repeat(uninitialized, 1));
  }

  template <bool enable = !isConstructible<T, Uninitialized>, EnableIf<enable> = 0>
  STU_INLINE
  T* append(Repeated<Uninitialized> uninitializedValues) {
    static_assert(isTriviallyDestructible<T>);
    const Int count = count_;
    if (STU_UNLIKELY(freeCapacity() < uninitializedValues.count)) {
      ensureFreeCapacity_slowPath(uninitializedValues.count);
    }
    sanitizer::annotateContiguousArray(begin(), capacity_,
                                       count, count + uninitializedValues.count);
    T* const p = end();
    count_ = count + uninitializedValues.count;
    return p;
  }

  template <bool enable = isCopyConstructible<T>, EnableIf<enable> = 0>
  STU_INLINE
  T* append(Repeated<T> repeatedValue) {
    static_assert(isNothrowCopyConstructible<T>);
    const Int count = count_;
    if (STU_UNLIKELY(freeCapacity() < repeatedValue.count)) {
      ensureFreeCapacity_slowPath(repeatedValue.count);
    }
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count + repeatedValue.count);
    T* const p = end();
    count_ = count + repeatedValue.count;
    for (Int i = 0; i < repeatedValue.count; ++i) {
      T* const pi = &p[i];
      STU_ASSUME(pi != nullptr);
      new (pi) T(static_cast<const T&>(repeatedValue.value));
    }
    return p;
  }

public:
  template <typename Array,
            typename U = RemoveReference<decltype(declval<const Array&>()[0])>,
            EnableIf<isConvertible<const Array&, ArrayRef<U>>> = 0>
  STU_INLINE
  void append(const Array& arrayRef) {
    const ArrayRef<U> array = arrayRef;
    if (array.isEmpty()) return;
    const Int count = count_;
    STU_PRECONDITION(!this->aliases(array[0]));
    if (STU_UNLIKELY(freeCapacity() < array.count())) {
      ensureFreeCapacity_slowPath(array.count());
    }
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count + array.count());
    T* p = end();
    static_assert(isBitwiseCopyable<T>);
    memcpy(p, array.begin(), sign_cast(array.count())*sizeof(T));
    count_ = count + array.count();
  }

  STU_INLINE
  void insert(Int index, T value) {
    static_assert(isNothrowMoveConstructible<T>);
    const Int count = this->count();
    STU_PRECONDITION(0 <= index && index <= count);
    if (STU_UNLIKELY(count == capacity_)) {
      ensureFreeCapacity_slowPath();
    }
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count + 1);
    T* p = begin() + index;
    if (index < count) {
      static_assert(isBitwiseMovable<T>);
      memmove(p + 1, p, sign_cast(count - index)*sizeof(T));
    }
    count_ = count + 1;
    STU_ASSUME(p != nullptr);
    new (p) T(std::move(value));
  }

  STU_INLINE
  void removeLast() {
    STU_PRECONDITION(count_ != 0);
    --count_;
    begin()[count_].~T();
    sanitizer::annotateContiguousArray(begin(), capacity_, count_ + 1, count_);
  }

  STU_INLINE
  T popLast() noexcept {
    static_assert(isNothrowMoveConstructible<T>);
    T last = std::move((*this)[$ - 1]);
    removeLast();
    return last;
  }

  STU_INLINE
  void removeLast(Int n) {
    const Int count = this->count();
    STU_PRECONDITION(n <= count);
    if (n <= 0) return;
    count_ = count - n;
    array_utils::destroyArray(end(), n);
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count - n);
  }

  STU_INLINE
  void removeAll() {
    removeLast(this->count());
  }

  STU_INLINE
  void removeRange(IndexRange<Int> range) {
    removeRangeImpl(range);
  }

  STU_INLINE
  void removeRange(IndexRange<Int, OffsetFromEnd<Int>> range) {
    removeRangeImpl(range);
  }

  STU_INLINE
  void removeRange(IndexRange<OffsetFromEnd<Int>> range) {
    removeRangeImpl(range);
  }

private:
  template <typename LB, typename UB>
  STU_INLINE
  void removeRangeImpl(IndexRange<LB, UB> indexRange) {
    const Int count = this->count();
    STU_PRECONDITION(indexRange.isValidForArrayWithLength(count));
    const auto [i, n] = indexRange.startIndexAndCountForArrayWithLength(count, unchecked);
    if (n == 0) return;
    count_ = count - n;
    T* const p = begin() + i;
    array_utils::destroyArray(p, n);
    const Int m = count - (i + n);
    if (m != 0) {
      static_assert(isBitwiseMovable<T>);
      memmove(p, p + n, sign_cast(m)*sizeof(T));
    }
    sanitizer::annotateContiguousArray(begin(), capacity_, count, count - n);
  }


public:
  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(T&)>> = 0>
  STU_INLINE
  void removeWhere(Predicate&& predicate) {
    static_assert(isNothrowMoveConstructible<T> && isNothrowDestructible<T>);
    T* const end = this->end();
    Int d = 0;
    for (T* p = begin(); p != end; ++p) {
      if (!predicate(*p)) {
        if (d == 0) continue;
        p[d] = std::move(*p);
      } else {
        --d;
      }
      p->~T();
    }
    count_ += d;
  }

  STU_INLINE
  void destroy() {
    if (!begin_) return;
    if (count_) {
      array_utils::destroyArray(begin(), count_);
    }
    if (isAllocated()) {
      sanitizer::annotateContiguousArray(begin(), capacity_, count_, capacity_);
      allocator().get().deallocate(begin(), capacity_);
    } else {
      sanitizer::annotateContiguousArray(begin(), capacity_, count_, Int{0});
    }
  }

  /// Assumes isEmpty() && capacity() >= embeddedStorageCapacity,
  /// and that the other vector's AllocatorRef has already been moved into this vector.
  template <int s>
  STU_INLINE
  void initWithRValueVector(Vector<T, s, AllocatorRef>&& other)
         noexcept(minEmbeddedStorageCapacity >= s
                  && (s <= 0 || isNothrowMoveConstructible<T>))
  {
    if constexpr (s > 0) {
      if (other.begin_ == other.embeddedStorage().buffer()) {
        if (other.count_ == 0) return;
        if constexpr (minEmbeddedStorageCapacity < s) {
          ensureFreeCapacity(other.count_);
        }
        sanitizer::annotateContiguousArray(begin(), capacity_, Int{0}, other.count_);
        static_assert(isBitwiseMovable<T>);
        memcpy(begin_, other.begin_, sign_cast(other.count_)*sizeof(T));
        count_ = other.count_;
        sanitizer::annotateContiguousArray(other.begin(), other.capacity_, other.count_, Int{0});
        other.count_ = 0;
        return;
      }
    }
    if constexpr (embeddedStorageCapacity > 0) {
      if (other.begin_ == nullptr) return;
    }
    begin_ = std::exchange(other.begin_, nullptr);
    count_ = std::exchange(other.count_, 0);
    capacity_ = std::exchange(other.capacity_, 0);
  }

  STU_INLINE
  void ensureFreeCapacity_slowPath() {
    Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(sizeof(T));
  }

  STU_INLINE
  void ensureFreeCapacity_slowPath(Int minFreeCapacity) {
    Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(minFreeCapacity, sizeof(T));
  }

  STU_INLINE
  void trimFreeCapacity_slowPath(Int desiredMaxFreeCapacity) {
    Base::trimFreeCapacity_slowPath_bitwiseMovableElements(desiredMaxFreeCapacity, sizeof(T));
  }
};

template <typename T, int c, typename AllocatorRef>
struct IsBitwiseMovable<Vector<T, c, AllocatorRef>>
       : BoolConstant<c <= 0> {};

namespace detail {

// We erase the element type in order to reduce the size of the generated machine code for
// different Vector instantiations.

struct VectorBaseData {
  void* begin_;
  Int count_;
  Int capacity_;

  template <bool mayReferenceExternalStorage>
  STU_INLINE
  bool isAllocated() const {
    return capacity_ != 0 && (!mayReferenceExternalStorage || (capacity_ & 1) == 0);
  }

  template <typename Allocator, bool mayReferenceExternalStorage>
  STU_INLINE
  void increaseCapacity_bitwiseMovableElements_inline(UInt newCapacity, UInt elementSize,
                                                      Allocator&& allocator)
  {
    if constexpr (mayReferenceExternalStorage) {
      newCapacity += newCapacity%2; // Round up to an even number.
    }
    STU_CHECK(sign_cast(newCapacity) > capacity_);
    UInt newAllocationSize;
    STU_CHECK(!__builtin_mul_overflow(newCapacity, elementSize, &newAllocationSize));
    const UInt usedSize = sign_cast(count_)*elementSize;
    const UInt oldAllocationSize = sign_cast(capacity_)*elementSize;
    Byte* const oldArray = static_cast<Byte*>(begin_);
    const bool hasAllocated = isAllocated<mayReferenceExternalStorage>();
    Byte* newArray;
    if (!hasAllocated) {
      newArray = allocator.allocate(newAllocationSize);
      if (usedSize) {
        memcpy(newArray, oldArray, usedSize);
        sanitizer::annotateContiguousArray(oldArray, oldAllocationSize, usedSize, UInt{0});
      }
    } else {
      sanitizer::annotateContiguousArray(oldArray, oldAllocationSize,
                                         usedSize, oldAllocationSize);
      auto guard = ScopeGuard{[&]{
        sanitizer::annotateContiguousArray(oldArray, oldAllocationSize,
                                           oldAllocationSize, usedSize);
      }};
      STU_ASSUME(oldAllocationSize < newAllocationSize);
      newArray = allocator.increaseCapacity(oldArray, usedSize,
                                            oldAllocationSize, newAllocationSize);
      guard.dismiss();
    }
    begin_ = newArray;
    capacity_ = sign_cast(newCapacity);
    sanitizer::annotateContiguousArray(newArray, newAllocationSize, newAllocationSize, usedSize);
  }

  template <typename Allocator, bool mayReferenceExternalStorage>
  STU_INLINE
  void decreaseCapacity_bitwiseMovableElements_inline(Int newCapacity, UInt elementSize,
                                                      Allocator&& allocator)
  {
    STU_CHECK(newCapacity >= count_);
    STU_DEBUG_ASSERT(newCapacity < capacity_);
    if (!isAllocated<mayReferenceExternalStorage>()) return;
    Byte* const oldArray = static_cast<Byte*>(begin_);
    const UInt oldAllocationSize = sign_cast(capacity_)*elementSize;
    if (STU_UNLIKELY(newCapacity == 0)) {
      if (!oldArray) return;
      sanitizer::annotateContiguousArray(oldArray, oldAllocationSize, UInt{0}, oldAllocationSize);
      allocator.deallocate(oldArray, oldAllocationSize);
      begin_ = nullptr;
      capacity_ = 0;
      return;
    }
    if constexpr (mayReferenceExternalStorage) {
      newCapacity += newCapacity & 1; // Round up to an even number.
    }
    if (newCapacity == capacity_) return;
    const UInt usedSize = sign_cast(count_)*elementSize;
    const UInt newAllocationSize = sign_cast(newCapacity)*elementSize;
    sanitizer::annotateContiguousArray(oldArray, oldAllocationSize,
                                       usedSize, oldAllocationSize);
    auto guard = ScopeGuard{[&]{
      sanitizer::annotateContiguousArray(oldArray, oldAllocationSize,
                                         oldAllocationSize, usedSize);
    }};
    STU_ASSUME(oldAllocationSize > newAllocationSize);
    Byte* const newArray = allocator.decreaseCapacity(static_cast<Byte*>(begin_), usedSize,
                                                      oldAllocationSize, newAllocationSize);
    guard.dismiss();
    begin_ = newArray;
    capacity_ = newCapacity;
    sanitizer::annotateContiguousArray(newArray, newAllocationSize, newAllocationSize, usedSize);
  }

  template <typename Allocator, bool mayReferenceExternalStorage>
  STU_INLINE
  void decreaseCapacityToCountAndMoveToAllocatedArray_bitwiseMovableElements_inline(
         UInt elementSize, Allocator&& allocator)
  {
    static_assert(mayReferenceExternalStorage);
    STU_ASSERT(!isAllocated<mayReferenceExternalStorage>());
    Byte* const oldArray = static_cast<Byte*>(begin_);
    const UInt usedSize = sign_cast(count_)*elementSize;
    const UInt oldAllocationSize = sign_cast(capacity_)*elementSize;
    if (STU_UNLIKELY(usedSize == 0)) {
      if (!oldArray) return;
      begin_ = nullptr;
      capacity_ = 0;
    } else {
      Byte* const array = allocator.allocate(usedSize);
      begin_ = array;
      capacity_ = count_;
      memcpy(array, oldArray, usedSize);
      sanitizer::annotateContiguousArray(oldArray, oldAllocationSize, usedSize, UInt{0});
    }
  }
};

template <typename T>
constexpr bool isTrivialAllocator =
  std::is_empty<T>::value && isDefaultConstructible<T> && std::is_trivially_copyable<T>::value;

template <typename Allocator, // = AllocatorTypeOfRef<AllocatorRef>
          bool mayReferenceExternalStorage,
          bool allocatorIsTrivial = isTrivialAllocator<Allocator>>
struct VectorBase : VectorBaseData { // allocatorIsTrivial == true

  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(UInt elementSize) {
    ensureFreeCapacity_slowPath_bitwiseMovableElements(1 + (count_ == 0), elementSize);
  }

  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(Int minFreeCapacity, UInt elementSize) {
    UInt newCapacity = sign_cast(count_) + sign_cast(minFreeCapacity);
    newCapacity = max(newCapacity, 2*sign_cast(count_ != 0 ? capacity_ : 0));
    increaseCapacity_bitwiseMovableElements(newCapacity, elementSize);
  }

  STU_NO_INLINE
  void trimFreeCapacity_slowPath_bitwiseMovableElements(Int desiredMaxFreeCapacity,
                                                        UInt elementSize)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    STU_CHECK(desiredMaxFreeCapacity >= 0);
    decreaseCapacity_bitwiseMovableElements(count_ + desiredMaxFreeCapacity, elementSize);
  }

  STU_NO_INLINE
  void increaseCapacity_bitwiseMovableElements(UInt newCapacity, UInt elementSize) {
    increaseCapacity_bitwiseMovableElements_inline<Allocator, mayReferenceExternalStorage>
                                                  (newCapacity, elementSize, Allocator{});
  }

  STU_NO_INLINE
  void decreaseCapacity_bitwiseMovableElements(Int newCapacity, UInt elementSize)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    decreaseCapacity_bitwiseMovableElements_inline<Allocator, mayReferenceExternalStorage>
                                                  (newCapacity, elementSize, Allocator{});
  }

  STU_NO_INLINE
  void decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
         UInt elementSize)
         noexcept(!mayReferenceExternalStorage && !STU_ASSERT_MAY_THROW)
  {
    if constexpr (!mayReferenceExternalStorage) {
      __builtin_trap();
    } else {
      if (isAllocated<mayReferenceExternalStorage>()) {
        if (count_ == capacity_) return;
        decreaseCapacity_bitwiseMovableElements_inline<Allocator, false>
                                                      (count_, elementSize, Allocator{});
      } else {
        decreaseCapacityToCountAndMoveToAllocatedArray_bitwiseMovableElements_inline
          <Allocator, mayReferenceExternalStorage>(elementSize, Allocator{});
      }
    }
  }
};

template <typename Allocator, bool mayReferenceExternalStorage>
struct VectorBase<Allocator, mayReferenceExternalStorage, /* allocatorIsTrivial */ false>
       : VectorBaseData
{
  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(UInt elementSize, Allocator allocator) {
    ensureFreeCapacity_slowPath_bitwiseMovableElements(1 + (count_ == 0), elementSize,
                                                       static_cast<Allocator&&>(allocator));
  }

  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(Int minFreeCapacity, UInt elementSize,
                                                          Allocator allocator)
  {
    UInt newCapacity = sign_cast(count_) + sign_cast(minFreeCapacity);
    newCapacity = max(newCapacity, 2*sign_cast(count_ != 0 ? capacity_ : 0));
    increaseCapacity_bitwiseMovableElements(newCapacity, elementSize,
                                            static_cast<Allocator&&>(allocator));
  }

  STU_NO_INLINE
  void trimFreeCapacity_slowPath_bitwiseMovableElements(Int desiredMaxFreeCapacity,
                                                        UInt elementSize, Allocator allocator)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    STU_CHECK(desiredMaxFreeCapacity >= 0);
    decreaseCapacity_bitwiseMovableElements(count_ + desiredMaxFreeCapacity, elementSize,
                                            static_cast<Allocator&&>(allocator));
  }

  STU_NO_INLINE
  void increaseCapacity_bitwiseMovableElements(UInt newCapacity, UInt elementSize,
                                               Allocator allocator)
  {
    increaseCapacity_bitwiseMovableElements_inline<Allocator, mayReferenceExternalStorage>
                                                  (newCapacity, elementSize,
                                                   static_cast<Allocator&&>(allocator));
  }

  STU_NO_INLINE
  void decreaseCapacity_bitwiseMovableElements(Int newCapacity, UInt elementSize,
                                               Allocator allocator)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    decreaseCapacity_bitwiseMovableElements_inline<Allocator, mayReferenceExternalStorage>
                                                  (newCapacity, elementSize,
                                                   static_cast<Allocator&&>(allocator));
  }

  STU_NO_INLINE
  void decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
         UInt elementSize, Allocator allocator)
       noexcept(!mayReferenceExternalStorage && !STU_ASSERT_MAY_THROW)
  {
    if constexpr (!mayReferenceExternalStorage) {
      __builtin_trap();
    } else {
      if (isAllocated<mayReferenceExternalStorage>()) {
        if (count_ == capacity_) return;
        decreaseCapacity_bitwiseMovableElements_inline<Allocator, false>
                                                      (count_, elementSize,
                                                       static_cast<Allocator&&>(allocator));
      } else {
        decreaseCapacityToCountAndMoveToAllocatedArray_bitwiseMovableElements_inline
          <Allocator, mayReferenceExternalStorage>(elementSize, static_cast<Allocator&&>(allocator));
      }
    }
  }
};

template <typename AllocatorRef, bool mayReferenceExternalStorage,
          bool inlineAllocatorRefGet>
class VectorBaseWithAllocatorRef // inlineAllocatorRefGet == true
      : protected VectorBase<AllocatorTypeOfRef<AllocatorRef>, mayReferenceExternalStorage>,
        private AllocatorRef
{
  using Base = VectorBase<AllocatorTypeOfRef<AllocatorRef>, mayReferenceExternalStorage>;
protected:
  using Allocator = AllocatorTypeOfRef<AllocatorRef>;

  STU_INLINE
  VectorBaseWithAllocatorRef(AllocatorRef&& allocator)
  : Base{}, AllocatorRef{std::move(allocator)} {}

  STU_INLINE
  VectorBaseWithAllocatorRef(void* begin, Int count, Int capacity, AllocatorRef&& allocator)
  : Base{{.begin_ = begin, .count_ = count, .capacity_ = capacity}},
    AllocatorRef{std::move(allocator)}
  {}

  STU_INLINE_T
  const AllocatorRef& allocator() const & { return *static_cast<const AllocatorRef*>(this); }
  STU_INLINE_T AllocatorRef&  allocator() & { return *static_cast<AllocatorRef*>(this); }
  STU_INLINE_T AllocatorRef&& allocator()&& { return std::move(*this); }

  STU_INLINE
  bool isAllocated() const { return Base::template isAllocated<mayReferenceExternalStorage>(); }

  STU_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(UInt elementSize) {
    if constexpr (isTrivialAllocator<Allocator>) {
      Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(elementSize);
    } else {
      Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(elementSize, allocator().get());
    }
  }

  STU_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(Int minFreeCapacity, UInt elementSize) {
    if constexpr (isTrivialAllocator<Allocator>) {
      Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(minFreeCapacity, elementSize);
    } else {
      Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(minFreeCapacity, elementSize,
                                                               allocator().get());
    }
  }

  STU_INLINE
  void trimFreeCapacity_slowPath_bitwiseMovableElements(Int desiredMaxFreeCapacity,
                                                        UInt elementSize)
  {
    if constexpr (isTrivialAllocator<Allocator>) {
      Base::trimFreeCapacity_slowPath_bitwiseMovableElements(desiredMaxFreeCapacity, elementSize);
    } else {
      Base::trimFreeCapacity_slowPath_bitwiseMovableElements(desiredMaxFreeCapacity, elementSize,
                                                             allocator().get());
    }
  }

  STU_INLINE
  void increaseCapacity_bitwiseMovableElements(UInt newCapacity, UInt elementSize) {
    if constexpr (isTrivialAllocator<Allocator>) {
      Base::increaseCapacity_bitwiseMovableElements(newCapacity, elementSize);
    } else {
      Base::increaseCapacity_bitwiseMovableElements(newCapacity, elementSize, allocator().get());
    }
  }

  STU_INLINE
  void decreaseCapacity_bitwiseMovableElements(Int newCapacity, UInt elementSize) {
    if constexpr (isTrivialAllocator<Allocator>) {
      Base::decreaseCapacity_bitwiseMovableElements(newCapacity, elementSize);
    } else {
      Base::decreaseCapacity_bitwiseMovableElements(newCapacity, elementSize, allocator().get());
    }
  }

  STU_INLINE
  void decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
         UInt elementSize)
  {
    if constexpr (!mayReferenceExternalStorage) {
      if (this->count_ == this->capacity_) return;
      decreaseCapacity_bitwiseMovableElements(this->count_, elementSize);
    } else if constexpr (isTrivialAllocator<Allocator>) {
      Base::decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
              elementSize);
    } else {
      Base::decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
              elementSize, allocator().get());
    }
  }
};

template <typename AllocatorRef, bool mayReferenceExternalStorage>
class VectorBaseWithAllocatorRef<AllocatorRef, mayReferenceExternalStorage,
                                 /* inlineAllocatorRefGet */ false>
      : public VectorBaseWithAllocatorRef<AllocatorRef, mayReferenceExternalStorage, true>
{
  using Base = VectorBaseWithAllocatorRef<AllocatorRef, mayReferenceExternalStorage, true>;
public:
  using Base::Base;

  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(UInt elementSize) {
    Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(elementSize);
  }

  STU_NO_INLINE
  void ensureFreeCapacity_slowPath_bitwiseMovableElements(Int minFreeCapacity, UInt elementSize) {
    Base::ensureFreeCapacity_slowPath_bitwiseMovableElements(minFreeCapacity, elementSize);
  }

  STU_NO_INLINE
  void trimFreeCapacity_slowPath_bitwiseMovableElements(Int desiredMaxFreeCapacity,
                                                        UInt elementSize)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    Base::trimFreeCapacity_slowPath_bitwiseMovableElements(desiredMaxFreeCapacity, elementSize);
  }

  STU_NO_INLINE
  void increaseCapacity_bitwiseMovableElements(UInt newCapacity, UInt elementSize) {
    Base::increaseCapacity_bitwiseMovableElements(newCapacity, elementSize);
  }

  STU_NO_INLINE
  void decreaseCapacity_bitwiseMovableElements(Int newCapacity, UInt elementSize)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    Base::decreaseCapacity_bitwiseMovableElements(newCapacity, elementSize);
  }

  STU_NO_INLINE
  void decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
         UInt elementSize) noexcept(!mayReferenceExternalStorage && !STU_ASSERT_MAY_THROW)
  {
    Base::decreaseCapacityToCountAndMoveToAllocatedArrayIfNeccesary_bitwiseMovableElements(
            elementSize);
  }
};

extern template struct VectorBase<Malloc, false>;
extern template struct VectorBase<Malloc, true>;

} // namespace detail
} // namespace stu
