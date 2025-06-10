// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

#include <functional>

namespace stu {

template <typename T>
class Ref;

namespace detail {
  template <typename T> struct RefValueTypeImpl { using Type = NoType; };
  template <typename T> struct RefValueTypeImpl<Ref<T>> { using Type = T; };
  template <typename T> struct RefValueTypeImpl<std::reference_wrapper<T>> { using Type = T; };
}

template <typename T>
using RefValueType = typename detail::RefValueTypeImpl<RemoveCVReference<T>>::Type;

template <typename T>
constexpr bool isRef = isType<RefValueType<T>>;

/// Customization point for RefT<
template <typename T, typename AlwaysInt = int>
class RefBase {};

/// Like std::reference_wrapper<T>, but with an explicit constructor.
template <typename T>
class Ref : public RefBase<T> {
  static_assert(!isReference<T>);
public:
  explicit STU_CONSTEXPR_T
  Ref(T& reference) noexcept
  : pointer_(&reference) {}

  STU_CONSTEXPR_T
  Ref(const Ref&) noexcept = default;

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Ref(Ref<U> other) noexcept
  : Ref(other.get()) {}

  STU_CONSTEXPR_T
  Ref& operator=(const Ref&) noexcept = default;
  
  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Ref& operator=(Ref<U> other) noexcept {
    pointer_ = &other.get();
    return *this;
  }

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Ref(std::reference_wrapper<U> other) noexcept
  : Ref(other.get()) {}

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Ref& operator=(std::reference_wrapper<U> other) noexcept {
    pointer_ = &other.get();
    return *this;
  }

  /* implicit */ STU_CONSTEXPR_T
  operator T&() const & noexcept { return *pointer_; }

  STU_CONSTEXPR_T
  T& get() const & noexcept { return *pointer_; }

  STU_CONSTEXPR_T
  T* pointer() const noexcept { return pointer_; }

  // This deleted overload prevents assignments to the referenced value.
  template <typename Other,
            EnableIf<!isRef<RemoveReference<Other>>> = 0>
  Ref& operator=(Other&& other) = delete;

  template <typename U = T, typename R = decltype(*declval<U&>())>
  STU_CONSTEXPR_T
  auto operator*() -> R { return **pointer_; }

  template <typename U = T, typename R = decltype(&*declval<U&>())>
  STU_CONSTEXPR_T
  auto operator->() -> R { return &**pointer_; }

private:
  T* pointer_;
};

} // namespace stu
