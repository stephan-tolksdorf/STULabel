// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "TypeTraits.hpp"

namespace stu {

template <typename Derived, typename T = bool>
struct Parameter {
  using Value = T;

  T value;

  STU_INLINE_T Parameter() = default;

  STU_CONSTEXPR_T Parameter(const Parameter&) = default;
  STU_CONSTEXPR_T Parameter(Parameter&&) = default;

  STU_CONSTEXPR_T Parameter& operator=(const Parameter&) = default;
  STU_CONSTEXPR_T Parameter& operator=(Parameter&&) = default;

  template <bool enable = isIntegral<T>, EnableIf<enable> = 0>
  explicit STU_CONSTEXPR
  Parameter(T value) noexcept
  : value(value) {}

  template <typename... Args,
            EnableIf<!isIntegral<T> && isConstructible<T, Args&&...>> = 0>
  explicit STU_CONSTEXPR
  Parameter(Args&&... args) noexcept(isNothrowConstructible<T, Args&&...>)
  : value(std::forward<Args>(args)...) {}

  explicit STU_CONSTEXPR_T
  operator T() const noexcept { return value; }

  template <bool enable = !isSame<T, bool> && isExplicitlyConvertible<T, bool>,
            EnableIf<enable> = 0>
  explicit STU_CONSTEXPR_T
  operator bool() const noexcept { return value; }

  template <bool enable = !isReference<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Parameter& operator=(T other) {
    value = other;
    return *this;
  }
  template <bool enable = !isReference<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Parameter& operator=(EnableIf<enable, T&&> other) {
    value = std::move(other);
    return *this;
  }

  template <typename U, EnableIf<isEqualityComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator==(const Derived& lhs, const U& rhs) noexcept(isNothrowEqualityComparable<T, U>) {
    return lhs.value == rhs;
  }
  template <typename U, EnableIf<isEqualityComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator==(const U& lhs, const Derived& rhs) noexcept(isNothrowEqualityComparable<U, T>) {
    return lhs == rhs.value;
  }

  template <typename U, EnableIf<isEqualityComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator!=(const Derived& lhs, const U& rhs) noexcept(isNothrowEqualityComparable<T, U>) {
    return !(lhs.value == rhs);
  }
  template <typename U, EnableIf<isEqualityComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator!=(const U& lhs, const Derived& rhs) noexcept(isNothrowEqualityComparable<U, T>) {
    return !(lhs == rhs.value);
  }

  template <typename U, EnableIf<isLessThanComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator<(const Derived& lhs, const U& rhs) noexcept(isNothrowLessThanComparable<T, U>) {
    return lhs.value < rhs;
  }
  template <typename U, EnableIf<isLessThanComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator<(const U& lhs, const Derived& rhs) noexcept(isNothrowLessThanComparable<U, T>) {
    return lhs < rhs.value;
  }

  template <typename U, EnableIf<isLessThanComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator>(const Derived& lhs, const U& rhs) noexcept(isNothrowLessThanComparable<T, U>) {
    return lhs.value > rhs;
  }
  template <typename U, EnableIf<isLessThanComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator>(const U& lhs, const Derived& rhs) noexcept(isNothrowLessThanComparable<U, T>) {
    return lhs > rhs.value;
  }

  template <typename U, EnableIf<isLessThanComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator<=(const Derived& lhs, const U& rhs) noexcept(isNothrowLessThanComparable<T, U>) {
    return lhs.value <= rhs;
  }
  template <typename U, EnableIf<isLessThanComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator<=(const U& lhs, const Derived& rhs) noexcept(isNothrowLessThanComparable<U, T>) {
    return lhs <= rhs.value;
  }

  template <typename U, EnableIf<isLessThanComparable<T, U> && !isSame<U, Derived>> = 0>
  friend STU_CONSTEXPR
  bool operator>=(const Derived& lhs, const U& rhs) noexcept(isNothrowLessThanComparable<T, U>) {
    return lhs.value >= rhs;
  }
  template <typename U, EnableIf<isLessThanComparable<U, T>> = 0>
  friend STU_CONSTEXPR
  bool operator>=(const U& lhs, const Derived& rhs) noexcept(isNothrowLessThanComparable<U, T>) {
    return lhs >= rhs.value;
  }

};


} // namespace stu
