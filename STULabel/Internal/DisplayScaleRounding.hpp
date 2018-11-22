// Copyright 2017–2018 Stephan Tolksdorf

#import "Once.hpp"
#import "Rect.hpp"

#include <cmath>

#if TARGET_OS_IOS
  #define STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT 1
#else
  #define STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT 0
#endif

namespace stu_label {

// When rendering text into bitmap contexts or when calculating layout information for labels
// we often need to round coordinates up or down to pixel boundaries.
//
// Naively implementing `floorToScale(x, scale)` as `floor(x*scale)/scale` and 
// `ceilToScale(x, scale)` as `ceil(x*scale)/scale` leads to unsatisfactory results for certain `x` 
// when 1/scale is not representable as a binary floating point number. For example, with these
// definitions `floorToScale(3/3.0 + 4/3.0, 3) == (3 + 3)/3.0` and
// `ceilToScale(6/3.0 + 7/3.0, 3) == (6 + 8)/3.0` (assuming the sums are evaluated as 
// double-precision floating-point operations).
//
// To avoid this issue, we also compute `nearbyint(x*scale)/scale` and return this value instead 
// of the floored or ceiled value when it is very close to `x`. See below for details.
//
// To avoid the relatively costly divisions, we precompute the inverse scale and then replace the
// divisions with multiplications by the inverse. (The additional floating-point rounding error is
// unproblematic for our purposes.)

/// Stores the display scale and its inverse as a Float64 and as a Float32.
/// `create` makes sure that the value and the inverse are both greater than 0.
class DisplayScale {
public:
  /* implicit */ STU_CONSTEXPR
  operator CGFloat() const {
    return value();
  }

  STU_CONSTEXPR
  CGFloat value() const {
  #if CGFLOAT_IS_DOUBLE
    return value_f64();
  #else
    return value_f32();
  #endif
  }

  STU_CONSTEXPR
  CGFloat inverseValue() const {
  #if CGFLOAT_IS_DOUBLE
    return inverseValue_f64();
  #else
    return inverseValue_f32();
  #endif
  }

  STU_CONSTEXPR
  Float64 value_f64() const {
    STU_ASSUME(scale_f64_ > 0);
    return scale_f64_;
  }

  STU_CONSTEXPR
  Float64 inverseValue_f64() const {
    STU_ASSUME(inverseScale_f64_ > 0);
    return inverseScale_f64_;
  }

  STU_CONSTEXPR
  Float32 value_f32() const {
    STU_ASSUME(scale_f32_ > 0);
    return scale_f32_;
  }

  STU_CONSTEXPR
  Float32 inverseValue_f32() const {
    STU_ASSUME(inverseScale_f32_ > 0);
    return inverseScale_f32_;
  }

  // Defined below after the Optional<DisplayScale> specialization.
  static Optional<DisplayScale> create(CGFloat scale);
  static DisplayScale createOrIfInvalidGetMainSceenScale(CGFloat scale);

  STU_CONSTEXPR
  static const DisplayScale& one();

  STU_CONSTEXPR
  static const Optional<DisplayScale>& oneAsOptional();

  static const Optional<DisplayScale> none;

  DisplayScale(const DisplayScale&) = default;
  DisplayScale& operator=(const DisplayScale&) = default;

  STU_CONSTEXPR
  DisplayScale(CGFloat scale, Unchecked)
  : scale_f64_{scale},
    inverseScale_f64_{1/scale_f64_},
    scale_f32_{narrow_cast<Float32>(scale)},
  #if CGFLOAT_IS_DOUBLE
    inverseScale_f32_{narrow_cast<Float32>(inverseScale_f64_)}
  #else
    inverseScale_f32_{1/scale}
  #endif
  {}

  template <typename T, EnableIf<isSame<T, Float64>> = 0>
  STU_CONSTEXPR
  Pair<T, T> valueAndInverse() const {
    return {value_f64(), inverseValue_f64()};
  }

  template <typename T, EnableIf<isSame<T, Float32>> = 0>
  STU_CONSTEXPR
  Pair<T, T> valueAndInverse() const {
    return {value_f32(), inverseValue_f32()};
  }

private:
  Float64 scale_f64_{};
  Float64 inverseScale_f64_{};
  Float32 scale_f32_{};
  Float32 inverseScale_f32_{};

  static Once mainScreenDisplayScale_once;
  static Optional<DisplayScale> mainScreenDisplayScale;
  static Optional<DisplayScale> mainScreenDisplayScale_initialize(DisplayScale);

  static Optional<DisplayScale> create_slowPath(CGFloat scale);

  static DisplayScale createOrIfInvalidGetMainSceenScale_slowPath(CGFloat scale);

  friend stu::OptionalValueStorage<DisplayScale>;
  STU_CONSTEXPR DisplayScale() = default;
};

using OptionalDisplayScaleRef = const Optional<DisplayScale>&;

} // namespace stu_label

template <>
class stu::OptionalValueStorage<stu_label::DisplayScale> {
  friend stu_label::DisplayScale;
public:
  STU_CONSTEXPR CGFloat displayScaleOrZero() const { return value_.value(); }
protected:
  stu_label::DisplayScale value_{};
  STU_CONSTEXPR bool hasValue() const noexcept { return value_.scale_f64_ != 0; }
  STU_CONSTEXPR void clearValue() noexcept { value_.scale_f64_ = 0; }
  STU_CONSTEXPR void constructValue(const stu_label::DisplayScale& value) { value_ = value; }
  STU_CONSTEXPR
  void constructValue(CGFloat value, Unchecked) {
    value_ = stu_label::DisplayScale{value, unchecked};
  }
};

namespace stu_label {
  
namespace detail {
  constexpr Optional<DisplayScale> displayScale_1{inPlace, 1, unchecked};

  constexpr Optional<DisplayScale> displayScale_none{};
}

STU_CONSTEXPR
const DisplayScale& DisplayScale::one() { return *detail::displayScale_1; }

STU_CONSTEXPR
const Optional<DisplayScale>& DisplayScale::oneAsOptional() { return detail::displayScale_1; }

constexpr Optional<DisplayScale> DisplayScale::none = {};

STU_INLINE
Optional<DisplayScale> DisplayScale::create(CGFloat scale) {
  if (mainScreenDisplayScale_once.isInitialized()) {
    if (scale == mainScreenDisplayScale.storage().value_) {
      return mainScreenDisplayScale;
    }
  }
  if (scale > 0) {
    return create_slowPath(scale);
  }
  return DisplayScale::none;
}

STU_INLINE
DisplayScale DisplayScale::createOrIfInvalidGetMainSceenScale(CGFloat scale) {
  if (mainScreenDisplayScale_once.isInitialized()) {
    if (scale == mainScreenDisplayScale.storage().value_
        || (STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT && !(scale > 0)))
    {
      mainScreenDisplayScale.assumeNotNone();
      return *mainScreenDisplayScale;
    }
  }
  return createOrIfInvalidGetMainSceenScale_slowPath(scale);
}

namespace detail {
  template <typename T, EnableIf<isOneOf<T, float, double>> = 0>
  constexpr T maxRelDiffForRounding = isSame<T, double> ? 128*DBL_EPSILON : 32*FLT_EPSILON;
}

template <typename T, EnableIf<isOneOf<T, Float64, Float32>> = 0>
[[nodiscard]] STU_CONSTEXPR
T roundToScale(T value, const DisplayScale& displayScale) {
  const auto [scale, inverseScale] = displayScale.valueAndInverse<T>();
  return std::nearbyint(value*scale)*inverseScale;
}

/// Rounds the value down to the previous multiple of 1/displayScale, unless the value is very close
/// to the next multiple of 1/displayScale, in which case the value is rounded *up* to that
/// multiple.
template <typename T, EnableIf<isOneOf<T, Float64, Float32>> = 0>
[[nodiscard]] STU_CONSTEXPR
T floorToScale(T value, const DisplayScale& displayScale) {
  const auto [scale, inverseScale] = displayScale.valueAndInverse<T>();
  const T scaledValue = value*scale;
  const T roundedValue = std::nearbyint(scaledValue)*inverseScale;
  const T flooredValue = std::floor(scaledValue)*inverseScale;
  return abs(roundedValue - value) <= abs(value)*detail::maxRelDiffForRounding<T>
       ? roundedValue : flooredValue;
}

/// Rounds the value up such that `value + scaledOffset/displayScale` is a multiple of
/// `1/displayScale`, unless `value + scaledOffset/displayScale` is very close to the previous
/// multiple of `1/displayScale`, in which case the value is rounded *down* to that multiple
/// minus `scaledOffset/displayScale`.
template <typename T, EnableIf<isOneOf<T, Float64, Float32>> = 0>
[[nodiscard]] STU_CONSTEXPR
T ceilToScale(T value, const DisplayScale& displayScale, T scaledOffset = 0) {
  const auto [scale, inverseScale] = displayScale.valueAndInverse<T>();
  const T scaledValue = value*scale + scaledOffset;
  const T roundedValue = (std::nearbyint(scaledValue) - scaledOffset)*inverseScale;
  const T ceiledValue = (std::ceil(scaledValue) - scaledOffset)*inverseScale;
  return abs(roundedValue - value) <= abs(value)*detail::maxRelDiffForRounding<T>
       ? roundedValue : ceiledValue;
}

[[nodiscard]] STU_CONSTEXPR
CGSize ceilToScale(CGSize size, const DisplayScale& scale) {
  size.width = ceilToScale(size.width, scale);
  size.height = ceilToScale(size.height, scale);
  return size;
}

template <typename T, EnableIf<isOneOf<T, Float64, Float32>> = 0>
[[nodiscard]] STU_CONSTEXPR
Rect<T> ceilToScale(Rect<T> rect, const DisplayScale& scale) {
  Rect<T> result;
  result.x.start = floorToScale(rect.x.start, scale);
  result.y.start = floorToScale(rect.y.start, scale);
  result.x.end   = ceilToScale(rect.x.end, scale);
  result.y.end   = ceilToScale(rect.y.end, scale);
  return result;
}

[[nodiscard]] STU_CONSTEXPR
CGRect ceilToScale(CGRect rect, const DisplayScale& scale) {
  return ceilToScale(Rect{rect}, scale);
}

} // stu_label
