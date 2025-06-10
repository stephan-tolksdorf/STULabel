// Copyright 2018 Stephan Tolksdorf

#pragma once

#include "stu/Allocation.hpp"

#include <cstddef>

namespace stu {

template <typename T>
using Deleter = void (*)(T* __nonnull) noexcept;

// Customization point for UniquePtr.
template <typename UniquePtr>
struct UniquePtrBase {};

template <typename T, Deleter<T>... deleter>
class UniquePtr : public UniquePtrBase<UniquePtr<T, deleter...>> {
  static_assert(sizeof...(deleter) <= 1);
  static constexpr bool hasDeleter = sizeof...(deleter) == 1;

  T* pointer_{};

  STU_INLINE
  void destroy() const {
    if (pointer_) {
      if constexpr (hasDeleter) {
        ((void)deleter(pointer_), ...);
      } else {
        delete pointer_;
      }
    }
  }

public:
  STU_INLINE_T
  UniquePtr() = default;

  /* implicit */ STU_INLINE_T
  UniquePtr(std::nullptr_t) noexcept {}

  explicit STU_INLINE_T
  UniquePtr(T* pointer) noexcept
  : pointer_(pointer)
  {}

  UniquePtr(const UniquePtr&) = delete;
  UniquePtr& operator=(const UniquePtr&) = delete;

  STU_INLINE_T
  UniquePtr(UniquePtr&& other) noexcept
  : pointer_(std::exchange(other.pointer_, nullptr))
  {}

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE_T
  UniquePtr(UniquePtr<U, deleter...>&& other) noexcept
  : pointer_(std::exchange(other.pointer_, nullptr))
  {}

  STU_INLINE
  UniquePtr& operator=(std::nullptr_t) noexcept {
    destroy();
    pointer_ = nullptr;
    return *this;
  }

  STU_INLINE
  UniquePtr& operator=(UniquePtr&& other) noexcept {
    return this->template operator=<T>(std::move(other));
  }

  template <typename U,
            EnableIf<isConvertible<U*, T*>> = 0>
  STU_INLINE
  UniquePtr& operator=(UniquePtr<U, deleter...>&& other) noexcept {
    destroy();
    pointer_ = std::exchange(other.pointer_, nullptr);
    return *this;
  }

  STU_INLINE
  ~UniquePtr() {
    destroy();
  }

  STU_INLINE_T
  explicit operator bool() const noexcept { return pointer_ != nullptr; }

  STU_INLINE
  void assumeIsNull() const noexcept {
    STU_ASSUME(pointer_ == nullptr);
  }

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
  friend bool operator==(const UniquePtr& lhs, const UniquePtr& rhs) {
    return lhs.get() == rhs.get();
  }
  STU_INLINE_T
  friend bool operator!=(const UniquePtr& lhs, const UniquePtr& rhs) { return !(lhs == rhs); }

  STU_INLINE_T
  friend bool operator==(T* lhs, const UniquePtr& rhs) { return lhs == rhs.get(); }
  STU_INLINE_T
  friend bool operator!=(T* lhs, const UniquePtr& rhs) { return !(lhs == rhs); }

  STU_INLINE_T
  friend bool operator==(const UniquePtr& lhs, T* rhs) { return lhs.get() == rhs; }
  STU_INLINE_T
  friend bool operator!=(const UniquePtr& lhs, T* rhs) { return !(lhs == rhs); }
};

template <typename T>
UniquePtr(T*) -> UniquePtr<T>;

template <typename T, Deleter<T>... deleter>
struct IsBitwiseMovable<UniquePtr<T, deleter...>> : True {};

template <typename T, Deleter<T>... deleter>
struct IsBitwiseZeroConstructible<UniquePtr<T, deleter...>> : True {};

template <typename T>
static void destroyAndFree(T* __nonnull pointer) noexcept;

template <typename T>
class Malloced : public UniquePtr<T, destroyAndFree<T>> {
public:
  using UniquePtr<T, destroyAndFree<T>>::UniquePtr;

private:
  template <typename U, typename... Args>
  friend Malloced<U> mallocNew(Args&&...);

  template <typename U>
  friend void destroyAndFree(U* __nonnull) noexcept;

  template <typename... Args>
  STU_INLINE
  static Malloced<T> create(Args&&... args) {
    T* const p = static_cast<T*>(malloc(sizeof(T)));
    if (STU_UNLIKELY(!p)) detail::badAlloc();
    return Malloced{new (p) T{std::forward<Args>(args)...}};
  }

  STU_INLINE
  static void destroyAndFree(T* __nonnull pointer) noexcept {
    static_assert(noexcept(pointer->~T()));
    pointer->~T();
    free(pointer);
  }
};

template <typename T>
Malloced(T*) -> Malloced<T>;

template <typename T>
struct IsBitwiseMovable<Malloced<T>> : True {};

template <typename T>
struct IsBitwiseZeroConstructible<Malloced<T>> : True {};

template <typename T, typename... Args>
STU_INLINE
Malloced<T> mallocNew(Args&&... args) {
  return Malloced<T>::create(std::forward<Args>(args)...);
}

template <typename T>
void destroyAndFree(T* __nonnull pointer) noexcept {
  Malloced<T>::destroyAndFree(pointer);
}

} // namespace stu
