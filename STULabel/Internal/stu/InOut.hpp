// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

namespace stu {

template <typename T>
class Out {
  static_assert(!isConst<T>);
  T& value_;
public:
  explicit STU_CONSTEXPR
  Out(T& outValueRef) noexcept
  : value_(outValueRef) {}

  /* implicit */ STU_CONSTEXPR_T
  operator T&() const noexcept { return value_; }

  STU_CONSTEXPR_T
  T& get() const noexcept { return value_; }

  template <typename U, EnableIf<isAssignable<T&, U&&>> = 0>
  STU_CONSTEXPR
  T& operator=(U&& other) const noexcept(isNothrowAssignable<T&, U&&>) {
    value_ = std::forward<U>(other);
    return value_;
  }

  template <typename U = T, typename R = decltype(*declval<U&>())>
  STU_CONSTEXPR_T auto operator*() -> R { return *value_; }

  template <typename U = T, typename R = decltype(&*declval<U&>())>
  STU_CONSTEXPR_T auto operator->() -> R { return &*value_; }
};

template <typename T>
class InOut {
  static_assert(!isConst<T>);
  T& value_;
public:
  explicit STU_CONSTEXPR_T
  InOut(T& inOutValueRef) noexcept : value_(inOutValueRef) {}

  /* implicit */ STU_CONSTEXPR_T
  operator T&() const noexcept { return value_; }

  STU_CONSTEXPR_T
  T& get() const noexcept { return value_; }

  template <typename U, EnableIf<isAssignable<T&, U&&>> = 0>
  STU_CONSTEXPR
  T& operator=(U&& other) const noexcept(isNothrowAssignable<T&, U&&>) {
    value_ = std::forward<U>(other);
    return value_;
  }

  template <typename U = T, typename R = decltype(*declval<U&>())>
  STU_CONSTEXPR_T
  auto operator*() -> R { return *value_; }

  template <typename U = T, typename R = decltype(&*declval<U&>())>
  STU_CONSTEXPR_T
  auto operator->() -> R { return &*value_; }
};

} // namespace stu
