// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

namespace stu {

template <typename T>
struct Comparable {
  // We need the TT = T indirection to avoid issues with recursive template instantiations.
  
  template <typename TT = T, EnableIf<isEqualityComparable<TT>> = 0>
  STU_CONSTEXPR
  friend bool operator!=(const T& lhs, const T& rhs) noexcept(isNothrowEqualityComparable<TT>) {
    return !(lhs == rhs);
  }

  template <typename TT = T, EnableIf<isLessThanComparable<TT>> = 0>
  STU_CONSTEXPR
  friend bool operator>(const T& lhs, const T& rhs) noexcept(isNothrowLessThanComparable<TT>) {
    return rhs < lhs;
  }

  template <typename TT = T, EnableIf<isLessThanComparable<TT>> = 0>
  STU_CONSTEXPR
  friend bool operator>=(const T& lhs, const T& rhs) noexcept(isNothrowLessThanComparable<TT>) {
    return !(lhs < rhs);
  }

  template <typename TT = T, EnableIf<isLessThanComparable<TT>> = 0>
  STU_CONSTEXPR
  friend bool operator<=(const T& lhs, const T& rhs) noexcept(isNothrowLessThanComparable<TT>) {
    return !(rhs < lhs);
  }
};

} // namespace stu
