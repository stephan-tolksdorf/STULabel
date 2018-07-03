// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

namespace stu {

template <typename A, typename B>
STU_CONSTEXPR_T
auto min(A&& a, B&& b) {
  using Result = decltype(a < b ? std::forward<A>(a) : std::forward<B>(b));
  static_assert_isSafelyConvertible<A&&, Result>();
  static_assert_isSafelyConvertible<B&&, Result>();
  return a < b ? std::forward<A>(a) : std::forward<B>(b);
}

template <typename A, typename B, typename C, typename... Ts>
STU_CONSTEXPR_T
auto min(A&& a, B&& b, C&& c, Ts&&... args) {
  return min(min(std::forward<A>(a), std::forward<B>(b)),
             std::forward<C>(c), std::forward<Ts>(args)...);
}

template <typename A, typename B>
STU_CONSTEXPR_T
auto max(A&& a, B&& b) {
  using Result = decltype(!(a < b) ? std::forward<A>(a) : std::forward<B>(b));
  static_assert_isSafelyConvertible<A&&, Result>();
  static_assert_isSafelyConvertible<B&&, Result>();
  return !(a < b) ? std::forward<A>(a) : std::forward<B>(b);
}

template <typename A, typename B, typename C, typename... Ts>
STU_CONSTEXPR_T
auto max(A&& a, B&& b, C&& c, Ts&&... args) {
  return max(max(std::forward<A>(a), std::forward<B>(b)),
             std::forward<C>(c), std::forward<Ts>(args)...);
}

/// \brief Returns `max(minValue, min(value, maxValue))`.
///
/// The return type is `T2`, unless all three types are integral types with the
/// same signness and `T1` and `T3` are both integer types that have a smaller
/// conversion rank than  `T2`, in which case the return type is the larger
/// type of `T1` and `T3`.
template <typename T1, typename T2, typename T3>
STU_CONSTEXPR_T
auto clamp(T1 minValue, T2 value, T3 maxValue) {
  if constexpr (isIntegral<T1> && isIntegral<T2> && isIntegral<T3>
                && isSignedInteger<T1> == isSignedInteger<T2>
                && isSignedInteger<T1> == isSignedInteger<T3>
                && max(sizeof(T1), sizeof(T3)) < sizeof(T2))
  {
    using Result = Conditional<sizeof(T1) < sizeof(T3), T3, T1>;
    return narrow_cast<Result>(max(minValue, min(value, maxValue)));
  } else {
    return max(minValue, min(value, maxValue));
  }
}

} // namespace stu
