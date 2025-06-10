// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Utility.hpp"

#include <cstddef>

#if __OBJC__
  #include <Foundation/Foundation.h>
#endif

namespace stu {

/// Required members:
///
///   static void incrementRefCount(T* __nonnull instance);
///   static void decrementRefCount(T* __nonnull instance);
template <typename T, typename AlwaysInt = int>
struct RefCountTraits : NotSpecialized {};

/// Indicates whether T is intrusively reference-counted.
template <typename T>
constexpr bool isRefCountable = !std::is_base_of<NotSpecialized, RefCountTraits<T>>::value;

template <typename T>
STU_CONSTEXPR
void incrementRefCount(T* pointer) {
  RefCountTraits<T>::incrementRefCount(pointer);
}

template <typename T>
STU_CONSTEXPR
void decrementRefCount(T* pointer) {
  RefCountTraits<T>::decrementRefCount(pointer);
}

struct ShouldIncrementRefCount : Parameter<ShouldIncrementRefCount> {
  using Parameter::Parameter;
};

/// \brief A smart pointer for intrusively reference-counted class types.
///
/// Supports any type for which `RefCountTraits` is specialized.
template <typename T>
class RC {
  static_assert(!isPointer<T>,
                "Did you accidentally add a * to the template parameter type "
                "or forget to apply `RemovePointer` to a CoreFoundation type?");

  static_assert(isRefCountable<T>);

  using Traits = RefCountTraits<T>;

  T* __unsafe_unretained pointer_{};
public:
  STU_INLINE_T
  RC() = default;

  /* implicit */  STU_INLINE_T
  RC(std::nullptr_t) noexcept {}

  /* implicit */ STU_INLINE
  RC(T* pointer, ShouldIncrementRefCount shouldIncRefCount = ShouldIncrementRefCount{true})
  : pointer_(pointer)
  {
    if (shouldIncRefCount && pointer) {
      Traits::incrementRefCount(pointer);
    }
  }

  STU_INLINE
  RC(const RC& other)
  : pointer_(other.pointer_)
  {
    if (pointer_) Traits::incrementRefCount(pointer_);
  }

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE
  RC(const RC<U>& other)
  : pointer_(other.pointer_)
  {
    if (pointer_) Traits::incrementRefCount(pointer_);
  }

  STU_INLINE_T
  RC(RC&& other) noexcept
  : pointer_(std::exchange(other.pointer_, nullptr))
  {}

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE_T
  RC(RC<U>&& other) noexcept
  : pointer_(std::exchange(other.pointer_, nullptr))
  {}

  STU_INLINE
  RC& operator=(T* p) {
    if (p) Traits::incrementRefCount(p);
    if (pointer_) Traits::decrementRefCount(pointer_);
    pointer_ = p;
    return *this;
  }

  STU_INLINE
  RC& operator=(const RC& other) {
    *this = other.get();
    return *this;
  }

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE
  RC& operator=(const RC<U>& other) {
    *this = other.get();
    return *this;
  }

  STU_INLINE
  RC& operator=(RC&& other) noexcept {
    return this->template operator=<T>(std::move(other));
  }

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE
  RC& operator=(RC<U>&& other) noexcept {
    *this = nullptr;
    pointer_ = std::exchange(other.pointer_, nullptr);
    return *this;
  }

  STU_INLINE
  ~RC() {
    if (pointer_) Traits::decrementRefCount(pointer_);
  }

  STU_INLINE_T
  explicit operator bool() const noexcept { return pointer_ != nullptr; }

  [[nodiscard]] STU_INLINE_T
  T* toRawPointer() && noexcept {
    T* const pointer = pointer_;
    pointer_ = nullptr;
    return pointer;
  }

  STU_INLINE_T
  T& operator*() const { return *pointer_; }

  STU_INLINE_T
  T* operator->() const { return pointer_; }

  STU_INLINE_T
  T* get() const { return pointer_; }

  STU_INLINE_T
  friend bool operator==(const RC& lhs, const RC& rhs) { return lhs.get() == rhs.get(); }
  STU_INLINE_T
  friend bool operator!=(const RC& lhs, const RC& rhs) { return !(lhs == rhs); }

  STU_INLINE_T
  friend bool operator==(T* lhs, const RC& rhs) { return lhs == rhs.get(); }
  STU_INLINE_T
  friend bool operator!=(T* lhs, const RC& rhs) { return !(lhs == rhs); }

  STU_INLINE_T
  friend bool operator==(const RC& lhs, T* rhs) { return lhs.get() == rhs; }
  STU_INLINE_T
  friend bool operator!=(const RC& lhs, T* rhs) { return !(lhs == rhs); }

  // TODO: comparison operators
};

template <typename T>
struct IsBitwiseMovable<RC<T>> : True {};

template <typename T>
struct IsBitwiseZeroConstructible<RC<T>> : True {};

template <class T, class U>
STU_INLINE
RC<T> static_pointer_cast(const RC<U>& p) {
  return RC<T>(static_cast<T*>(p.get()));
}

template <class T, class U>
STU_INLINE
RC<T> static_pointer_cast(RC<U>&& p) {
  return RC<T>(static_cast<T*>(std::move(p).toRawPointer()), ShouldIncrementRefCount{false});
}

template<class T, class U>
STU_INLINE
RC<T> const_pointer_cast(const RC<U>& p) {
  return RC<T>(const_cast<T*>(p.get()));
}

template<class T, class U>
STU_INLINE
RC<T> const_pointer_cast(RC<U>&& p) {
  return RC<T>{const_cast<T*>(std::move(p).toRawPointer()), ShouldIncrementRefCount{false}};
}

template <class T, class U>
STU_INLINE
RC<T> dynamic_pointer_cast(const RC<U>& p) {
  return RC<T>{dynamic_cast<T*>(p.get())};
}

template<class T, class U>
STU_INLINE
RC<T> dynamic_pointer_cast(RC<U>&& p) {
  T* const pointer = dynamic_cast<T*>(p.get()); // dynamic_cast may throw
  stu::discard(std::move(p).toRawPointer());
  return RC<T>(pointer, ShouldIncrementRefCount{false});
}

} // namespace stu
