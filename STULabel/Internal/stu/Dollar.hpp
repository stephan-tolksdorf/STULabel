// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#import "stu/Comparable.hpp"

namespace stu {

template <typename T>
struct DollarOffset;

struct Dollar {
  template <typename T>
  STU_CONSTEXPR_T
  friend DollarOffset<T> operator+(Dollar, T value) {
    return DollarOffset<T>{move(value)};
  }

  template <typename T>
  STU_CONSTEXPR_T
  friend DollarOffset<T> operator+(T value, Dollar) {
    return DollarOffset<T>{move(value)};
  }

  template <typename T>
  STU_CONSTEXPR_T
  friend DollarOffset<T> operator-(Dollar, T value) {
    return DollarOffset<T>{-value};
  }
};

constexpr Dollar $ = {};

template <typename T>
struct DollarOffset : Comparable<DollarOffset<T>> {
  T value{};

  STU_CONSTEXPR_T
  DollarOffset() = default;

  /* implicit */ STU_CONSTEXPR_T
  DollarOffset(Dollar) noexcept
  : value{}
  {}

  explicit STU_CONSTEXPR_T
  DollarOffset(const T& value) noexcept(isNothrowCopyConstructible<T>)
  : value{value}
  {}

  explicit STU_CONSTEXPR_T
  DollarOffset(T&& value) noexcept(isNothrowMoveConstructible<T>)
  : value{std::move(value)}
  {}

  template <typename T2, EnableIf<!isSame<T, T2> && isSafelyConvertible<T2&&, T>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  DollarOffset(DollarOffset<T2> offset) noexcept(isNothrowConstructible<T, T2&&>)
  : DollarOffset{std::move(offset.value)}
  {}

  template <typename T2, EnableIf<!isSame<T, T2> && isNonSafelyConvertible<T2&&, T>> = 0>
  explicit STU_CONSTEXPR
  DollarOffset(DollarOffset<T2> offset) noexcept(isNothrowConstructible<T, T2&&>)
  : DollarOffset(static_cast<T>(std::move(offset.value)))
  {}


  template <bool enable = isIncrementable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  DollarOffset& operator++() noexcept(isNothrowIncrementable<T>) {
    ++value;
    return *this;
  }

  template <bool enable = isDecrementable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  DollarOffset& operator--() noexcept(isNothrowDecrementable<T>) {
    --value;
    return *this;
  }

  template <bool enable = isIncrementable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  DollarOffset operator++(int)
                 noexcept(isNothrowIncrementable<T> && isNothrowCopyConstructible<T>)
  {
    DollarOffset temp{*this};
    ++value;
    return temp;
  }

  template <bool enable = isDecrementable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  DollarOffset operator--(int)
                 noexcept(isNothrowDecrementable<T> && isNothrowCopyConstructible<T>)
  {
    DollarOffset temp{*this};
    --value;
    return temp;
  }

  STU_CONSTEXPR
  DollarOffset& operator+=(const T& other) noexcept(isNothrowCompoundAddable<T>) {
    value += other;
    return *this;
  }

  STU_CONSTEXPR
  DollarOffset& operator-=(const T& other) noexcept(isNothrowCompoundSubtractable<T>) {
    value -= other;
    return *this;
  }

  template <bool enable = isAddable<T> && isCompoundAddable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend DollarOffset operator+(const T& lhs, DollarOffset rhs)
                        noexcept(noexcept(isNothrowCompoundAddable<T>))
  {
    rhs += lhs;
    return rhs;
  }

  template <bool enable = isAddable<T> && isCompoundAddable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend DollarOffset operator+(DollarOffset lhs, const T& rhs)
                        noexcept(noexcept(isNothrowCompoundAddable<T>))
  {
    lhs += rhs;
    return lhs;
  }

  template <bool enable = isSubtractable<T> && isCompoundSubtractable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend DollarOffset operator-(const T& lhs, DollarOffset rhs)
                        noexcept(noexcept(isNothrowCompoundSubtractable<T>))
  {
    rhs -= lhs;
    return rhs;
  }

  template <bool enable = isSubtractable<T> && isCompoundSubtractable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend DollarOffset operator-(DollarOffset lhs, const T& rhs)
                        noexcept(noexcept(isNothrowCompoundSubtractable<T>))
  {
    lhs -= rhs;
    return lhs;
  }

  template <bool enable = isEqualityComparable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend bool operator==(const DollarOffset& lhs, const DollarOffset& rhs)
                noexcept(isNothrowEqualityComparable<T>)
  {
    return lhs.value == rhs.value;
  }

  template <bool enable = isLessThanComparable<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  friend bool operator<(const DollarOffset& lhs, const DollarOffset& rhs)
                noexcept(isNothrowLessThanComparable<T>)
  {
    return lhs.value < rhs.value;
  }

};

template <typename T>
using OffsetFromEnd = DollarOffset<T>;

} // namespace stu
