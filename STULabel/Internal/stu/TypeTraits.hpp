// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Config.hpp"

#include <type_traits>
#include <utility>

#include <float.h>

namespace stu {

template <typename T, T value>
using IntegralConstant = std::integral_constant<T, value>;

template <bool value>
using BoolConstant = std::integral_constant<bool, value>;

using True = std::true_type;
using False = std::false_type;

template <bool condition, typename T1, typename T2>
using Conditional = typename std::conditional<condition, T1, T2>::type;

template <typename T1, typename T2>
constexpr bool isSame = std::is_same<T1, T2>::value;

namespace detail {
  template <typename T, typename... Ts>
  struct IsOneOfImpl : False {};

  template <typename T, typename... Ts>
  struct IsOneOfImpl<T, T, Ts...> : True {};

  template <typename T, typename T2, typename... Ts>
  struct IsOneOfImpl<T, T2, Ts...> : IsOneOfImpl<T, Ts...> {};
}
/// A type trait that indicates whether `T` is one of the types in the `Ts` parameter pack.
template <typename T, typename... Ts>
constexpr bool isOneOf = detail::IsOneOfImpl<T, Ts...>::value;

template <typename T>
constexpr bool isPointer = std::is_pointer<T>::value;

template <typename T>
constexpr bool isReference = std::is_reference<T>::value;

template <typename T>
constexpr bool isConst = std::is_const<T>::value;

template <typename T>
using RemoveConst = typename std::remove_const<T>::type;

template <typename T>
using RemoveCV = typename std::remove_cv<T>::type;

template <typename T>
using RemovePointer = typename std::remove_pointer<T>::type;

template <typename T>
using RemoveReference = typename std::remove_reference<T>::type;

template <typename T>
using AddPointer = typename std::add_pointer<T>::type;
template <typename T>
using AddLValueReference = typename std::add_lvalue_reference<T>::type;
template <typename T>
using AddRValueReference = typename std::add_rvalue_reference<T>::type;


template <typename T>
using RemoveCVReference = RemoveCV<RemoveReference<T>>;

template <typename T>
using Decay = typename std::decay<T>::type;

struct NoType {
  NoType() = delete;
  ~NoType() = delete;
  NoType(const NoType&) = delete;
  void operator=(const NoType&) = delete;
};

template <typename T>
constexpr bool isType = !isSame<RemoveCVReference<T>, NoType>;

template <typename T, typename Default>
using TypeOr = Conditional<isType<T>, T, Default>;

template <typename T>
constexpr bool isVoid = std::is_void<T>::value;

template <bool condition, typename T = int>
using EnableIf = std::enable_if_t<condition, T>;

using std::declval;

template <typename T>
constexpr T delayToInstantiation(T value) { return value; };

// (can)Apply are inspired by http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4502.pdf

namespace detail {
  template <typename Default, typename alwaysInt,
            template <typename...> typename F, typename... Ts>
  struct ApplyImpl : False {
    using Type = Default;
  };

  template <typename Default, template <class...> class F, class... Ts>
  struct ApplyImpl<Default, EnableIf<isType<F<Ts...>>>, F, Ts...> : True {
    using Type = F<Ts...>;
  };
} // namespace detail

template <template<class...> class F, class... Ts>
constexpr bool canApply = detail::ApplyImpl<False, int, F, Ts...>::value;

template <template<class...> class F, class... Ts>
constexpr bool appliedIsTrue = detail::ApplyImpl<False, int, F, Ts...>::Type::value;

template <template<class...> class F, class... Ts>
using Apply = typename detail::ApplyImpl<NoType, int, F, Ts...>::Type;

template <typename Default, template<class...> class F, class... Ts>
using ApplyOr = typename detail::ApplyImpl<Default, int, F, Ts...>::Type;

template <typename Expected, template<class...> class F, class... Ts>
constexpr bool appliedIs = isSame<Expected, Apply<F, Ts...>>;



template <typename T, typename... Args>
constexpr bool isConstructible = std::is_constructible<T, Args...>::value;

template <typename T>
constexpr bool isDefaultConstructible = isConstructible<T>;

template <typename T>
constexpr bool isMoveConstructible = std::is_move_constructible<T>::value;

template <typename T>
constexpr bool isCopyConstructible = std::is_copy_constructible<T>::value;

template <typename T>
constexpr bool isTriviallyConstructible = std::is_trivially_constructible<T>::value;

template <typename T, typename... Args>
constexpr bool isNothrowConstructible = std::is_nothrow_constructible<T, Args...>::value;


template <typename T>
constexpr bool isNothrowMoveConstructible = std::is_nothrow_move_constructible<T>::value;

template <typename T>
constexpr bool isNothrowCopyConstructible = std::is_nothrow_copy_constructible<T>::value;

template <typename T>
constexpr bool isTriviallyDestructible = std::is_trivially_destructible<T>::value;

template <typename T>
constexpr bool isNothrowDestructible = std::is_nothrow_destructible<T>::value;


template <typename T, typename Arg>
constexpr bool isAssignable = std::is_assignable<T, Arg>::value;


template <typename T>
constexpr bool isCopyAssignable = std::is_copy_assignable<T>::value;

template <typename T>
constexpr bool isMoveAssignable = std::is_move_assignable<T>::value;

template <typename T, typename Arg>
constexpr bool isNothrowAssignable = std::is_nothrow_assignable<T, Arg>::value;

template <typename T>
constexpr bool isNothrowCopyAssignable = std::is_nothrow_copy_assignable<T>::value;

template <typename T>
constexpr bool isNothrowMoveAssignable = std::is_nothrow_move_assignable<T>::value;

template <typename T>
constexpr bool isTrivial = std::is_trivial<T>::value;
  
template <typename T>
constexpr bool isEmpty = std::is_empty<T>::value;


namespace detail {
  template <typename T, typename... Args>
  using ListInitializationType = decltype(T{declval<Args>()...});

  template <typename To, typename From>
  using DecltypeStaticCast = decltype(static_cast<To>(declval<From>()));
}

template <typename T, typename... Args>
constexpr bool isListInitializable = canApply<detail::ListInitializationType, T, Args...>;

template <typename From, typename To>
constexpr bool isConvertible = std::is_convertible<From, To>::value;

template <typename From, typename To>
constexpr bool isExplicitlyConvertible = canApply<detail::DecltypeStaticCast, To, From>;


namespace detail {
  template <typename From, typename To>
  struct IsConvertibleArrayPointer : False {};

  template <typename T> struct IsConvertibleArrayPointer<T*, T*> : True {};
  template <typename T> struct IsConvertibleArrayPointer<T*, const T*> : True {};
  template <typename T> struct IsConvertibleArrayPointer<const T*, T*> : False {};

  template <typename From, typename To>
  struct IsConvertibleArrayPointer<From*, To*>
  : BoolConstant<isConvertible<From*, To*> && sizeof(From) == sizeof(To)> {};
}

/// Indicates whether `From` and `To` are pointer types, `From` is
/// convertible to `To` and the respective element types have the same size.
/// If the element types are not equal (modulo constness), they must be complete.
template <typename From, typename To>
constexpr bool isConvertibleArrayPointer =
  detail::IsConvertibleArrayPointer<RemoveCV<From>, RemoveCV<To>>::value;



namespace detail {
  // We want to avoid instantiating Base when possible, so we first check the base class
  // relationship using is_base_of and then check for public inheritance using is_convertible
  // in a second step.
  template <typename T, typename Base,
            bool = isType<T> && std::is_base_of<Base, T>::value>
  struct IsDerivedFromImpl : std::is_convertible<T*, Base*> {};

  template <typename T, typename Base>
  struct IsDerivedFromImpl<T, Base, false> : False {};
}

/// A type trait that indicates whether `RemoveCVReference<T>` is a class type that is
/// publicly derived from `Base`:
template <typename T, typename Base>
constexpr bool isDerivedFrom =
                detail::IsDerivedFromImpl<RemoveCVReference<T>, Base>::value;

template <typename T>
constexpr bool isFloatingPoint = std::is_floating_point<T>::value;

namespace detail {
  template <int bits> struct IntTypes { using Signed = NoType; using Unsigned = NoType; };
  template <> struct IntTypes<8>  { using Signed = Int8;  using Unsigned = UInt8; };
  template <> struct IntTypes<16> { using Signed = Int16; using Unsigned = UInt16; };
  template <> struct IntTypes<32> { using Signed = Int32; using Unsigned = UInt32; };
  template <> struct IntTypes<64> { using Signed = Int64; using Unsigned = UInt64; };
#if STU_HAS_INT128
  template <> struct IntTypes<128> { using Signed = Int128; using Unsigned = UInt128; };
#endif
}

/// \brief An alias for the signed fixed-width integer type with the specified
///        number of bits.
///
///  For example, Int_<32> evaluates to Int32.
template <int bits>
using Int_ = typename detail::IntTypes<bits>::Signed;

/// \brief An alias for the unsigned fixed-width integer type with the specified
///        number of bits.
///
/// For example, UInt_<32> evaluates to UInt32.
template <int bits>
using UInt_ = typename detail::IntTypes<bits>::Unsigned;

template <typename T>
struct IntegerTraits {
  static const bool isCharacter = false;
  static const bool isInteger = false;
  static const bool isSigned = false;
  static const bool isUnsigned = false;
  using SignedType = NoType;
  using UnsignedType = NoType;
  static const int conversionRank = 0;
};

template <typename T>
struct IntegerTraits<const T> : IntegerTraits<T>
{
  using SignedType = const typename IntegerTraits<T>::SignedType;
  using UnsignedType = const typename IntegerTraits<T>::UnsignedType;
};
template <typename T>
struct IntegerTraits<volatile T> : IntegerTraits<T>
{
  using SignedType = volatile typename IntegerTraits<T>::SignedType;
  using UnsignedType = volatile typename IntegerTraits<T>::UnsignedType;
};
template <typename T>
struct IntegerTraits<const volatile T> : IntegerTraits<T>
{
  using SignedType = const volatile typename IntegerTraits<T>::SignedType;
  using UnsignedType = const volatile typename IntegerTraits<T>::UnsignedType;
};

namespace detail {
  template <typename Int, typename SInt, typename UInt,
            int rank, bool isInt, bool isChar>
  struct IntegerTraitsImpl {
    static const bool isCharacter = isChar;
    static const bool isInteger = isInt;
    static const bool isSigned = Int(-1) < 0;
    static const bool isUnsigned = !isSigned;

    static const int bits = sizeof(Int)*8;

    using SignedType = SInt;
    using UnsignedType = UInt;

    static const Int max = Int(UInt(-1) >> (isSigned ? 1 : 0));
    static const Int min = !isSigned ? 0
                         : Int(-SInt(UInt(-1) >> 1) - 1);

    static const int conversionRank = rank;
  };
}

#define STU_DEFINE_INTEGER_TRAITS(rank, Signed, Unsigned, isInt, isChar) \
template <> \
struct IntegerTraits<Signed> \
: detail::IntegerTraitsImpl<Signed, Signed, Unsigned, rank, isInt, isChar>{}; \
template <> \
struct IntegerTraits<Unsigned> \
: detail::IntegerTraitsImpl<Unsigned, Signed, Unsigned, rank, isInt, isChar>{}

STU_DEFINE_INTEGER_TRAITS(1, signed char, unsigned char, true, true);
STU_DEFINE_INTEGER_TRAITS(4, short, unsigned short, true, false);
STU_DEFINE_INTEGER_TRAITS(8, int, unsigned, true, false);
STU_DEFINE_INTEGER_TRAITS(12, long, unsigned long, true, false);
STU_DEFINE_INTEGER_TRAITS(16, long long, unsigned long long, true, false);
#if STU_HAS_INT128
  STU_DEFINE_INTEGER_TRAITS(20, Int128, UInt128, true, false);
#endif
#undef STU_DEFINE_INTEGER_TRAITS

#define STU_DEFINE_CHAR_INTEGER_TRAITS(Char) \
template <> struct IntegerTraits<Char> \
: detail::IntegerTraitsImpl< \
            Char, \
            Conditional< (Char(-1) < 0), Char,  Int_<sizeof(Char)*8>>, \
            Conditional<!(Char(-1) < 0), Char, UInt_<sizeof(Char)*8>>, \
            IntegerTraits<UInt_<sizeof(Char)*8>>::conversionRank, \
            false, true> {}

STU_DEFINE_CHAR_INTEGER_TRAITS(char);
STU_DEFINE_CHAR_INTEGER_TRAITS(wchar_t);
STU_DEFINE_CHAR_INTEGER_TRAITS(char16_t);
STU_DEFINE_CHAR_INTEGER_TRAITS(char32_t);

#undef STU_DEFINE_INTEGER_CHAR_TRAITS

template <typename T>
constexpr bool isInteger = IntegerTraits<T>::isInteger;

template <typename T>
constexpr bool isCharacter = IntegerTraits<T>::isCharacter;

template <typename T>
constexpr bool isSigned = std::is_signed<T>::value;

template <typename T>
constexpr bool isUnsigned = std::is_unsigned<T>::value;

template <typename T>
constexpr bool isSignedInteger = IntegerTraits<T>::isSigned && IntegerTraits<T>::isInteger;

template <typename T>
constexpr bool isUnsignedInteger = IntegerTraits<T>::isUnsigned && IntegerTraits<T>::isInteger;

template <typename T>
constexpr bool isBool = isSame<RemoveCV<T>, bool>;

template <typename T>
constexpr bool isIntegral = std::is_integral<T>::value;

template <typename T>
using Signed = typename IntegerTraits<T>::SignedType;

template <typename T>
using Unsigned = typename IntegerTraits<T>::UnsignedType;

template <typename T>
constexpr bool isClass = std::is_class<T>::value;

template <typename T>
constexpr bool isEnum = std::is_enum<T>::value;

namespace detail {
  template <typename T, bool = isEnum<T>>
  struct UnderlyingTypeImpl {
    using Type = typename std::underlying_type<T>::type;
  };

  template <typename T>
  using NestedUnderlyingType = typename T::UnderlyingType;

  template <typename T>
  struct UnderlyingTypeImpl<T, false>
  : ApplyImpl<T, int, NestedUnderlyingType, T>
  {};
}

template <typename T>
using UnderlyingType = typename detail::UnderlyingTypeImpl<T>::Type;

namespace detail {
  template <bool isListInitializable, typename T, typename F>
  struct IsSafelyConvertibleImpl2 : BoolConstant<isListInitializable> {};

  template <typename F>
  struct IsSafelyConvertibleImpl2<true, bool, F> : False {};

  template <>
  struct IsSafelyConvertibleImpl2<true, bool, bool> : True {};

  template <typename F>
  struct IsSafelyConvertibleImpl2<false, float, F>
  : BoolConstant<isInteger<F> && sizeof(F) < sizeof(float)> {};

  template <typename F>
  struct IsSafelyConvertibleImpl2<false, double, F>
  : BoolConstant<isInteger<F> && sizeof(F) < sizeof(double)> {};

  template <typename F>
  struct IsSafelyConvertibleImpl2<false, long double, F>
  : BoolConstant<isInteger<F> && sizeof(F) < sizeof(long double)> {};

  template <typename From, typename To,
            typename F = RemoveCVReference<From>, typename T = RemoveCVReference<To>,
            bool convertible = isConvertible<From, To>,
            bool same = isSame<F, T>>
  struct IsSafelyConvertibleImpl : BoolConstant<same> {};

  template <typename From, typename To,
            typename F, typename T>
  struct IsSafelyConvertibleImpl<From, To, F, T, true, false>
  : IsSafelyConvertibleImpl2<isListInitializable<To, From>, T, F> {};
}

/// The minimum representable finite value.
template <typename T>
constexpr inline T minValue = IntegerTraits<T>::min;

/// The maximum representable finite value.
template <typename T>
constexpr inline T maxValue = IntegerTraits<T>::max;

template <> constexpr inline float maxValue<float> =  FLT_MAX;
template <> constexpr inline float minValue<float> = -FLT_MAX;
template <> constexpr inline double maxValue<double> =  DBL_MAX;
template <> constexpr inline double minValue<double> = -DBL_MAX;

template <typename T, EnableIf<isOneOf<T, float, double>> = 0>
constexpr T infinity = __builtin_inff();

template <typename T, EnableIf<isOneOf<T, float, double>> = 0>
constexpr T epsilon = isSame<T, float> ? FLT_EPSILON : static_cast<T>(DBL_EPSILON);

/// \brief A type trait that indicates whether `T1` can be safely converted to
///        `T2` without changing the (integral) value.
///
/// This is a variant of `IsConvertible` which does not allow conversions where
/// `T2` can not exactly represent all possible values of `T1`. In particular,
/// this trait returns `false` for all conversions which may change the sign
/// or truncate the value of an integer, but it returns `true` e.g. for
/// conversions from an unsigned integer type to a larger signed integer type or
/// conversions from `int` to `double`.
template <typename From, typename To>
constexpr bool isSafelyConvertible = detail::IsSafelyConvertibleImpl<From, To>::value;

namespace detail {
  template <bool isConvertible, typename From, typename To>
  struct IsNonSafelyConvertibleImpl : False {};

  template <typename From, typename To>
  struct IsNonSafelyConvertibleImpl<true, From, To>
  : BoolConstant<!isSafelyConvertible<From, To>> {};
}

template <typename From, typename To>
constexpr bool isNonSafelyConvertible =
  detail::IsNonSafelyConvertibleImpl<isConvertible<From, To>, From, To>::value;

/// Using this wrapper has the advantage that the relevant types show up in the error message first.
template <typename From, typename To>
STU_CONSTEXPR
void static_assert_isSafelyConvertible() {
  static_assert(isSafelyConvertible<From, To>);
}

namespace detail {
  template <typename T, typename U>
  using DecltypeEquals = decltype(declval<const T&>() == declval<const U&>());

  template <typename T, typename U>
  using NoexceptEquals = BoolConstant<noexcept(declval<const T&>() == declval<const U&>())>;

  template <typename T, typename U>
  using DecltypeLessThan = decltype(declval<const T&>() < declval<const U&>());

  template <typename T, typename U>
  using NoexceptLessThan = BoolConstant<noexcept(declval<const T&>() < declval<const U&>())>;

  template <typename T>
  using DecltypeDifference = decltype(declval<const T&>() - declval<const T&>());

  template <typename T>
  using DecltypeIncrement = decltype(++declval<T&>());

  template <typename T>
  using NoexceptIncrement = BoolConstant<noexcept(++declval<T&>())>;

  template <typename T>
  using DecltypeDecrement = decltype(--declval<T&>());

  template <typename T>
  using NoexceptDecrement = BoolConstant<noexcept(--declval<T&>())>;

  template <typename T, typename U>
  using DecltypePlus = decltype(declval<const T&>() + declval<const U&>());

  template <typename T, typename U>
  using NoexceptPlus = BoolConstant<noexcept(declval<const T&>() + declval<const U&>())>;

  template <typename T, typename U>
  using DecltypeMinus = decltype(declval<const T&>() - declval<const U&>());

  template <typename T, typename U>
  using NoexceptMinus = BoolConstant<noexcept(declval<const T&>() - declval<const U&>())>;

  template <typename T, typename Offset>
  using DecltypeCompoundPlus = decltype(declval<T&>() += declval<const Offset&>());

  template <typename T, typename Offset>
  using NoexceptCompoundPlus = BoolConstant<noexcept(declval<T&>() += declval<const Offset&>())>;

  template <typename T, typename Offset>
  using DecltypeCompoundMinus = decltype(declval<T&>() -= declval<const Offset&>());

  template <typename T, typename Offset>
  using NoexceptCompoundMinus = BoolConstant<noexcept(declval<T&>() -= declval<const Offset&>())>;
}


template <typename T, typename U = T>
constexpr bool isEqualityComparable = appliedIs<bool, detail::DecltypeEquals, T, U>;

template <typename T, typename U = T>
constexpr bool isLessThanComparable = appliedIs<bool, detail::DecltypeLessThan, T, U>;

template <typename T>
constexpr bool isComparable = isEqualityComparable<T> && isLessThanComparable<T>;


template <typename T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isIncrementable = appliedIs<ReturnValue, detail::DecltypeIncrement, T>;

template <typename T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isDecrementable = appliedIs<ReturnValue, detail::DecltypeDecrement, T>;

template <typename T, typename U = T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isCompoundAddable = appliedIs<ReturnValue, detail::DecltypeCompoundPlus, T, U>;

template <typename T, typename U = T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isCompoundSubtractable = appliedIs<ReturnValue, detail::DecltypeCompoundMinus, T, U>;

template <typename T, typename U = T>
constexpr bool isAddable = canApply<detail::DecltypePlus, T, U>;

template <typename T, typename U = T>
constexpr bool isSubtractable = canApply<detail::DecltypeMinus, T, U>;


template <typename T>
using DifferenceType = Apply<detail::DecltypeDifference, T>;

template <typename T, typename Offset = DifferenceType<T>,
          typename ReturnValue = AddLValueReference<T>>
constexpr bool isOffsetable =
    appliedIs<ReturnValue, detail::DecltypeCompoundPlus, T, Offset>
 && appliedIs<ReturnValue, detail::DecltypeCompoundMinus, T, Offset>;


template <typename T, typename U = T>
constexpr bool isNothrowEqualityComparable = isEqualityComparable<T, U>
                                          && appliedIsTrue<detail::NoexceptEquals, T, U>;


template <typename T, typename U = T>
constexpr bool isNothrowLessThanComparable = isLessThanComparable<T, U>
                                          && appliedIsTrue<detail::NoexceptLessThan, T, U>;


template <typename T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isNothrowIncrementable = isIncrementable<T, ReturnValue>
                                     && appliedIsTrue<detail::NoexceptIncrement, T>;

template <typename T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isNothrowDecrementable = isDecrementable<T, ReturnValue>
                                     && appliedIsTrue<detail::NoexceptDecrement, T>;

template <typename T, typename U = T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isNothrowCompoundAddable = isCompoundAddable<T, U, ReturnValue>
                                       && appliedIsTrue<detail::NoexceptCompoundPlus, T, U>;

template <typename T, typename U = T, typename ReturnValue = AddLValueReference<T>>
constexpr bool isNothrowCompoundSubtractable = isCompoundSubtractable<T, U, ReturnValue>
                                       && appliedIsTrue<detail::NoexceptCompoundMinus, T, U>;

template <typename T, typename U = T>
constexpr bool isNothrowAddable = appliedIsTrue<detail::NoexceptPlus, T, U>;

template <typename T, typename U = T>
constexpr bool isNothrowSubtractable = appliedIsTrue<detail::NoexceptMinus, T, U>;

template <typename... Ts>
using CommonType = typename std::common_type<Ts...>::type;

template <typename T, bool value = true>
struct DelayCheckToInstantiation : BoolConstant<value> {};

namespace detail {

  template <typename Callable, typename... Arguments>
  using DecltypeCall = decltype(declval<Callable>()(declval<Arguments>()...));

  template <typename Callable, typename ReturnValue, typename... Arguments>
  using NoexceptCall =
    BoolConstant<noexcept(ReturnValue(declval<Callable>()(declval<Arguments>()...)))>;

  template<typename Callable, typename Signature>
  struct IsCallable : False {
    static_assert(!isType<Signature>, "The second template parameter must be a function type");
  };

  template <typename Callable, typename ReturnValue, typename... Arguments>
  struct IsCallable<Callable, ReturnValue(Arguments...)>
  : BoolConstant<isSafelyConvertible<Apply<DecltypeCall, Callable, Arguments...>, ReturnValue>>
  {};

  template <typename Callable, typename ReturnValue, typename... Arguments>
  struct IsCallable<Callable, ReturnValue(Arguments...) noexcept>
  : Conditional<!IsCallable<Callable, ReturnValue(Arguments...)>::value, False,
                ApplyOr<False, NoexceptCall, Callable, ReturnValue, Arguments...>>
  {};
}

template <typename T, typename Signature>
constexpr bool isCallable = detail::IsCallable<T, Signature>::value;


namespace detail {

  template <typename T>
  struct BoundMemberFunctionType {
    // using ImplicitArgument = ...;
    // using Type = ...;
  };

  #define STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION(declaredQualifier, qualifier, noexcept) \
    template <typename T, typename ReturnValue, typename... Arguments> \
    struct BoundMemberFunctionType<ReturnValue (T::*)(Arguments...) declaredQualifier noexcept> { \
      using ImplicitArgument = T qualifier; \
      using Type = ReturnValue(Arguments...) noexcept; \
    };

  #define STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION2(declaredQualifier, qualifier) \
    STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION(declaredQualifier, qualifier,) \
    STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION(declaredQualifier, qualifier, noexcept) \

  #define STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATIONS(const) \
    STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION2(const,    const &) \
    STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION2(const &,  const &) \
    STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATION2(const &&, const &&)

  STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATIONS()
  STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATIONS(const)

  #undef STU_BOUNDMEMBERFUNCTIONTYPE_SPECIALIZATIONS

  template <typename Callable>
  using DecltypeOperatorCall = decltype(&Callable::operator());

  template <typename Callable>
  struct CallableSignatureImpl
  : BoundMemberFunctionType<Apply<DecltypeOperatorCall, Callable>> {};

  template <typename R, typename... Args>
  struct CallableSignatureImpl<R(Args...)> { using Type = R(Args...); };

  template <typename R, typename... Args>
  struct CallableSignatureImpl<R(*)(Args...)> { using Type = R(Args...); };

  template <typename R, typename... Args>
  struct CallableSignatureImpl<R(Args...) noexcept> { using Type = R(Args...) noexcept; };

  template <typename R, typename... Args>
  struct CallableSignatureImpl<R(*)(Args...) noexcept> { using Type = R(Args...) noexcept; };

} // namespace detail

template <typename T>
using CallableSignature = typename detail::CallableSignatureImpl<RemoveReference<T>>::Type;


/// \brief A type trait that indicates whether values of a type can be safely
///        bitwise copy-constructed and copy-assigned in memory.
///
/// It is safe to copy a bitwise-copyable value with memcpy or memmove and
/// continue to use both values afterwards.
///
/// A bitwise-copyable value must be trivially destructible, so that it's safe
/// to overwrite an existing value with the copy of another value.
///
/// This type trait is used for optimization purposes and can be specialized
/// as needed.
template <typename T>
struct IsBitwiseCopyable : std::is_trivially_copyable<T> {};

template <typename T>
constexpr bool isBitwiseCopyable = IsBitwiseCopyable<T>::value;

/// \brief A type traits that indicates whether values of a type can be safely
///        relocated in memory.
///
/// It is safe to bitwise copy construct a bitwise-movable value with memcpy or
/// memmove if afterwards only one of the two values is continued to be used and
/// the destructor of the other value is never called.
///
/// A bitwise-copyable type is also bitwise-movable, while the opposite is not
/// necessarily true.
///
/// This type trait is used for optimization purposes and can be specialized
/// as needed.
template <typename T>
struct IsBitwiseMovable : IsBitwiseCopyable<T> {};

template <typename T>
constexpr bool isBitwiseMovable = IsBitwiseMovable<T>::value;

template <typename T>
struct IsMemberwiseConstructible : std::is_trivially_constructible<T> {};

template <typename T>
constexpr bool isMemberwiseConstructible = IsMemberwiseConstructible<T>::value;

template <typename T>
struct IsBitwiseZeroConstructible : IsMemberwiseConstructible<T> {};

template <typename T>
constexpr bool isBitwiseZeroConstructible = IsBitwiseZeroConstructible<T>::value;


template <int ...>
struct Indices {};

namespace detail {
  template <int length, int... tail>
  struct MakeIndicesImpl {
    using Type = typename MakeIndicesImpl<length - 1, length - 1, tail...>::Type;
  };

  template <int... indices>
  struct MakeIndicesImpl<0, indices...> {
    using Type = Indices<indices...>;
  };
}

template <int length, int... tail>
using MakeIndices = typename detail::MakeIndicesImpl<length, tail...>::Type;

namespace detail {
  template <typename... Types>
  struct FirstTypeImpl;

  template <>
  struct FirstTypeImpl<> { using Type = NoType; };

  template <typename T0, typename... Ts>
  struct FirstTypeImpl<T0, Ts...> { using Type = T0; };
};

template <typename... Ts>
using FirstType = typename detail::FirstTypeImpl<Ts...>::Type;

} // namespace stu

