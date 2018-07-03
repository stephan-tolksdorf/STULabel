// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/Comparable.hpp"

namespace stu {

namespace detail {
  template <typename T, bool = isEnum<T>>
  struct IsBoolEnum : BoolConstant<isSame<UnderlyingType<T>, bool>> {};

  template <typename T>
  struct IsBoolEnum<T, false> : False {};
}

template <typename T>
struct IsOptionsEnum : detail::IsBoolEnum<T> {};

template <typename T>
constexpr bool isOptionsEnum = IsOptionsEnum<RemoveCVReference<T>>::value;

template <typename Enum>
struct EnumBitwiseOpResult;

namespace OptionsEnumOperators {

  template <typename Enum, EnableIf<isOptionsEnum<Enum>> = 0>
  STU_CONSTEXPR_T
  bool operator!(Enum value) {
    return !static_cast<UnderlyingType<Enum>>(value);
  }

  template <typename Enum, EnableIf<isOptionsEnum<Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator~(Enum value) {
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(~static_cast<UnderlyingType<Enum>>(value))};
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator|(Enum lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(lhs) | static_cast<U>(static_cast<Enum>(rhs)))};
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator&(Enum lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(lhs) & static_cast<U>(static_cast<Enum>(rhs)))};
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator^(Enum lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(lhs) ^ static_cast<U>(static_cast<Enum>(rhs)))};
  }

  template <typename T, typename Enum,
            EnableIf<!isOptionsEnum<T> && isOptionsEnum<Enum>
                     && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator|(T&& lhs, Enum rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(static_cast<Enum>(lhs)) | static_cast<U>(rhs))};
  }

  template <typename T, typename Enum,
            EnableIf<!isOptionsEnum<T> && isOptionsEnum<Enum>
                     && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator&(T&& lhs, Enum rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(static_cast<Enum>(lhs)) & static_cast<U>(rhs))};
  }

  template <typename T, typename Enum,
            EnableIf<!isOptionsEnum<T> && isOptionsEnum<Enum>
                     && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  EnumBitwiseOpResult<Enum> operator^(T&& lhs, Enum rhs) {
    using U = UnderlyingType<Enum>;
    return EnumBitwiseOpResult<Enum>{
             static_cast<Enum>(static_cast<U>(static_cast<Enum>(lhs)) ^ static_cast<U>(rhs))};
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  Enum& operator|=(Enum& lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    lhs = static_cast<Enum>(static_cast<U>(lhs) | static_cast<U>(static_cast<Enum>(rhs)));
    return lhs;
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  Enum& operator&=(Enum& lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    lhs = static_cast<Enum>(static_cast<U>(lhs) & static_cast<U>(static_cast<Enum>(rhs)));
    return lhs;
  }

  template <typename Enum, typename T,
            EnableIf<isOptionsEnum<Enum> && isSafelyConvertible<T&&, Enum>> = 0>
  STU_CONSTEXPR_T
  Enum& operator^=(Enum& lhs, T&& rhs) {
    using U = UnderlyingType<Enum>;
    lhs = static_cast<Enum>(static_cast<U>(lhs) ^ static_cast<U>(static_cast<Enum>(rhs)));
    return lhs;
  }
} // namespace OptionsEnumOperators

using namespace OptionsEnumOperators;

template <typename Enum>
struct EnumBitwiseOpResult : Comparable<EnumBitwiseOpResult<Enum>> {
  Enum value;

  explicit STU_CONSTEXPR_T
  EnumBitwiseOpResult(Enum value) : value{value} {}

  /* implicit */ STU_CONSTEXPR_T
  operator Enum() const noexcept { return value; }

  template <typename T,
            EnableIf<!isSame<RemoveCVReference<T>, Enum>
                     && isExplicitlyConvertible<const Enum&, T>> = 0>
  explicit STU_CONSTEXPR_T
  operator T() const noexcept(noexcept(static_cast<T>(value))) {
    return static_cast<T>(value);
  }

  STU_CONSTEXPR_T
  EnumBitwiseOpResult operator|(EnumBitwiseOpResult other) const {
    return EnumBitwiseOpResult{value | other.value};
  }

  STU_CONSTEXPR_T
  EnumBitwiseOpResult operator&(EnumBitwiseOpResult other) const{
    return EnumBitwiseOpResult{value & other.value};
  }

  STU_CONSTEXPR_T
  EnumBitwiseOpResult operator^(EnumBitwiseOpResult other) const {
    return EnumBitwiseOpResult{value ^ other.value};
  }

  STU_CONSTEXPR_T
  EnumBitwiseOpResult operator~() const {
    return EnumBitwiseOpResult{~value};
  }
};

} // namespace stu

