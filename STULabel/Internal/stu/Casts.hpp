// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

namespace stu {

template <typename T, typename U>
STU_CONSTEXPR_T
T bit_cast(const U& value) noexcept {
  static_assert(sizeof(T) == sizeof(U));
  T result;
  __builtin_memcpy(&result, &value, sizeof(result));
  return result;
}

template <typename T>
STU_CONSTEXPR_T
T implicit_cast(EnableIf<true, T> value) noexcept {
  return static_cast<T>(value); // The static_cast is necesary for rvalue references.
}


template <typename Int, EnableIf<isInteger<Int>> = 0>
STU_CONSTEXPR_T
auto sign_cast(Int value) noexcept {
  using Result = Conditional<isSigned<Int>, Unsigned<Int>, Signed<Int>>;
  return static_cast<Result>(value);
}

template <typename T, typename U>
STU_CONSTEXPR_T
T narrow_cast(U&& value) noexcept(noexcept(static_cast<T>(value))) {
  return static_cast<T>(value);
}

template <typename T, typename U,
          EnableIf<isPointer<T> && isConvertible<T, const U*>> = 0>
STU_CONSTEXPR_T
T down_cast(U* value) noexcept {
  return static_cast<T>(value);
}

template <typename T, typename U,
          EnableIf<isReference<T> && isConvertible<T, const U&>> = 0>
STU_CONSTEXPR_T
T down_cast(U& value) noexcept {
  return static_cast<T>(value);
}

} // namespace stu
