// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Iterator.hpp"
#include "stu/MinMax.hpp"
#include "stu/Utility.hpp"

#include <cmath>

namespace stu {

template <typename T>
struct Range;

template <typename T>
struct RangeConversion {
  // static constexpr Range<Bound> toRange(T range);
  // static constexpr T fromRange(Range<Bound> range);
};

namespace detail {
  template <typename T>
  using DecltypeRangeConversionBound =
    typename decltype(RangeConversion<T>::toRange(declval<T>()))::Bound;

  template <typename T, typename AlwaysInt = int>
  struct RangeBoundImpl {};

  template <typename T>
  struct RangeBoundImpl<Range<T>, int> {
    using Type = T;
  };

  template <typename T>
  struct RangeBoundImpl<T, EnableIf<isType<DecltypeRangeConversionBound<T>>>> {
    using Type = DecltypeRangeConversionBound<T>;
  };
}

/// SFINAE-friendly
template <typename Range>
using RangeBound = typename detail::RangeBoundImpl<Decay<Range>>::Type;

// Customization point for Range.
template <typename BoundType>
struct RangeBase {};

template <typename T>
struct Range : RangeBase<T> {
  using Bound = T;

  static_assert(isComparable<T>);

  T start; ///< Inclusive lower bound.
  T end; ///< Exclusive upper bound.

  STU_CONSTEXPR_T
  Range() noexcept(isNothrowConstructible<T>)
  : start{}, end{} {}

  explicit STU_CONSTEXPR
  Range(Uninitialized) {
  #if STU_DEBUG
    if constexpr (isInteger<T> || isOneOf<T, Float32, Float64>) {
      start = maxValue<T>/4;
      end = maxValue<T>;
    }
  #endif
  }

  STU_CONSTEXPR_T
  Range(T start, T end) noexcept(isNothrowMoveConstructible<T>)
  : start{std::move(start)}, end{std::move(end)}
  {}

  template <typename Int>
  STU_CONSTEXPR_T
  Range(T startValue, Count<Int> count)
    noexcept(isNothrowMoveConstructible<T> && noexcept(T(startValue + count.value)))
  : start{std::move(startValue)}, end{start + count.value} {}

  template <typename U, EnableIf<!isSame<U, T> && isSafelyConvertible<U, T>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Range(Range<U> range) noexcept(isNothrowConstructible<T, U&&>)
  : Range(std::move(range.start), std::move(range.end))
  {}

  template <typename U, EnableIf<isNonSafelyConvertible<U, T>> = 0>
  explicit STU_CONSTEXPR
  Range(Range<U> range) noexcept(isNothrowConstructible<T, U&&>)
  : Range(static_cast<T>(std::move(range.start)),
          static_cast<T>(std::move(range.end)))
  {}

  template <typename R,
            typename U = RangeBound<R>,
            EnableIf<isSafelyConvertible<U, T> && !isSame<Decay<R>, Range<U>>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Range(R&& range)
    noexcept(noexcept(Range{RangeConversion<Decay<R>>::toRange(std::forward<R>(range))}))
                    : Range{RangeConversion<Decay<R>>::toRange(std::forward<R>(range))}
  {}

  template <typename R,
            typename U = RangeBound<R>,
            EnableIf<isNonSafelyConvertible<U, T> && !isSame<Decay<R>, Range<U>>> = 0>
  explicit STU_CONSTEXPR
  Range(R&& range)
    noexcept(noexcept(Range{RangeConversion<Decay<R>>::toRange(std::forward<R>(range))}))
                    : Range{RangeConversion<Decay<R>>::toRange(std::forward<R>(range))}
  {}

  template <typename R, typename U = RangeBound<R>,
            EnableIf<isSafelyConvertible<T, U> && !isSame<Decay<R>, Range<U>>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator R() const &
    STU_NOEXCEPT_AUTO_RETURN(RangeConversion<Decay<R>>
                             ::fromRange(implicit_cast<const Range<U>>(*this)))

  template <typename R, typename U = RangeBound<R>,
            EnableIf<isNonSafelyConvertible<T, U> && !isSame<Decay<R>, Range<U>>> = 0>
  explicit STU_CONSTEXPR
  operator R() const &
    STU_NOEXCEPT_AUTO_RETURN(RangeConversion<Decay<R>>
                             ::fromRange(static_cast<const Range<U>>(*this)))


  template <typename R, typename U = RangeBound<R>,
            EnableIf<isSafelyConvertible<T, U> && !isSame<Decay<R>, Range<U>>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator R() &&
    STU_NOEXCEPT_AUTO_RETURN(RangeConversion<Decay<R>>
                             ::fromRange(implicit_cast<Range<U>>(std::move(*this))))

  template <typename R, typename U = RangeBound<R>,
            EnableIf<isNonSafelyConvertible<T, U> && !isSame<Decay<R>, Range<U>>> = 0>
  explicit STU_CONSTEXPR
  operator R() &&
    STU_NOEXCEPT_AUTO_RETURN(RangeConversion<Decay<R>>
                             ::fromRange(static_cast<Range<U>>(std::move(*this))))

  STU_CONSTEXPR_T
  bool isEmpty() const {
    return !(start < end);
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  static Range infinitelyEmpty() { return {infinity<T>, -infinity<T>}; }

  /// Returns `start ≤ value < end`.
  [[nodiscard]] STU_CONSTEXPR
  bool contains(const T& value) const {
    return (value < end) && !(value < start);
  }

  /// Returns `start ≤ other.start && other.end ≤ end`.
  ///
  /// Note that this definition implies that this method may return false even though the other
  /// range is empty.
  template <typename OtherRange, typename U = RangeBound<OtherRange>,
            typename CommonBound = CommonType<T, U>>
  [[nodiscard]] STU_CONSTEXPR
  bool contains(const OtherRange& other) const {
    auto impl = [](const Range<T>& self, const Range<U>& other) -> bool {
      using B = const CommonBound&;
      if constexpr (   isSigned<T> == isSigned<U>
                    && isLessThanComparable<T, U>
                    && isLessThanComparable<U, T>)
      {
        return !(other.start < self.start)
            && !(self.end < other.end);
      } else if constexpr (isSigned<T> == isSigned<U>) {
        return !(implicit_cast<B>(other.start) < implicit_cast<B>(self.start))
            && !(implicit_cast<B>(self.end) < implicit_cast<B>(other.end));
      } else if constexpr (isSigned<T>) {
        return !(self.end < T{})
            && !(static_cast<B>(self.end) < static_cast<B>(other.end))
            && (self.start < T{}
                || !(static_cast<B>(other.start) < static_cast<B>(self.start)));
      } else { // isSigned<U>
        return !(other.start < U{})
            && !(static_cast<B>(other.start) < static_cast<B>(self.start))
            && (other.end < U{}
                || !(static_cast<B>(self.end) < static_cast<B>(other.end)));
      }
    };
    if constexpr (isSame<OtherRange, Range<U>>) {
      return impl(*this, other);
    } else {
      const Range<U> temp{other};
      return impl(*this, temp);
    }
  }

  /// Returns true iff the intersection of this and the other range is not empty, i.e
  /// iff `max(start, other.start) < min(end, other.end)`.
  template <typename OtherRange, typename U = RangeBound<OtherRange>,
            typename CommonBound = CommonType<T, U>>
  [[nodiscard]] STU_CONSTEXPR
  bool overlaps(const OtherRange& other) const {
    auto impl = [](const Range& self, const Range<U>& other) -> bool {
      using B = const CommonBound&;
      if constexpr (isSigned<T> == isSigned<U>
                    && isLessThanComparable<T, U>
                    && isLessThanComparable<U, T>)
      {
        return max(self.start, other.start)
             < min(self.end, other.end);
      } else if constexpr (isSigned<T> == isSigned<U>) {
        return max(implicit_cast<B>(self.start), implicit_cast<B>(other.start))
             < min(implicit_cast<B>(self.end), implicit_cast<B>(other.end));
      } else {
        if constexpr (isSigned<T>) {
          return !(self.end < T{})
              && (self.start < T{} ? static_cast<B>(other.start)
                  : max(static_cast<B>(self.start), static_cast<B>(other.start)))
                 < min(static_cast<B>(self.end), static_cast<B>(other.end));
        } else { // isSigned<U>
          return !(other.end < U{})
              && (other.start < U{} ? static_cast<B>(self.start)
                  : max(static_cast<B>(self.start), static_cast<B>(other.start)))
                 < min(static_cast<B>(self.end), static_cast<B>(other.end));
        }
      }
    };
    if constexpr (isSame<OtherRange, Range<U>>) {
      return impl(*this, other);
    } else {
      const Range<U> temp{other};
      return impl(*this, temp);
    }
  }

  template <typename Range1, typename Range2,
            typename Bound1 = RangeBound<Range1>,
            typename Bound2 = RangeBound<Range2>,
            typename CommonBound = CommonType<Bound1, Bound2>,
            // TODO: Find out why the Xcode clang reports a nonsense "default template
            // argument not permitted on a friend template" error without the following line.
            EnableIf<isSame<Range1, Range> || isSame<Range2, Range>> = 0
           >
  STU_CONSTEXPR
  friend bool operator==(const Range1& range1, const Range2& range2)
  {
    return ([](const Range<Bound1>& range1, const Range<Bound2>& range2) -> bool {
      using B = const CommonType<Bound1, Bound2>&;
      if constexpr (isSigned<Bound1> == isSigned<Bound2>
                    && isEqualityComparable<Bound1, Bound2>)
      {
        return range1.start == range2.start
            && range1.end == range2.end;
      } else if constexpr (isSigned<Bound1> == isSigned<Bound2>) {
        return implicit_cast<B>(range1.start) == implicit_cast<B>(range2.start)
            && implicit_cast<B>(range1.end) == implicit_cast<B>(range2.end);
      } else {
        if constexpr (isSigned<Bound1>) {
          if (range1.start < Bound1{} || range1.end < Bound1{}) return false;
        } else {
          if (range2.start < Bound2{} || range2.end < Bound2{}) return false;
        }
        return static_cast<B>(range1.start) == static_cast<B>(range2.start)
            && static_cast<B>(range1.end) == static_cast<B>(range2.end);
      }
    })(range1, range2);
  }

  template <typename Range1, typename Range2,
            EnableIf<   isConvertible<const Range1&, const Range&>
                     && isConvertible<const Range2&, const Range&>> = 0>
  STU_CONSTEXPR
  friend bool operator!=(const Range1& range1, const Range2& range2) {
    return !(range1 == range2);
  }

  /// Returns Range(max(start, other.start), min(end, other.end))
  [[nodiscard]] STU_CONSTEXPR
  Range intersection(const Range& other) const {
    return {max(start, other.start), min(end, other.end)};
  }

  /// *this = this->intersection(other);
  STU_CONSTEXPR
  void intersect(const Range& other) {
    *this = intersection(other);
  }

  /// Returns Range(clamp(other.start, start, other.end), clamp(other.start, end, other.end))
  [[nodiscard]] STU_CONSTEXPR
  Range clampedTo(const Range& other) const {
    return {clamp(other.start, start, other.end), clamp(other.start, end, other.end)};
  }

  /// *this = this->clampedTo(other);
  STU_CONSTEXPR
  void clampTo(const Range& other) {
    *this = clampedTo(other);
  }

  /// Returns Range(min(start, other.start), max(end, other.end))
  [[nodiscard]] STU_CONSTEXPR
  Range convexHull(const Range& other) const {
    return {min(start, other.start), max(end, other.end)};
  }

private:
  using Difference = DifferenceType<T>;
public:
  using Count = Conditional<isIntegral<Difference>, Difference, NoType>;
  using Offset = Conditional<isOffsetable<T, Difference>, Difference, NoType>;

  /// May overflow.
  template <bool enable = isType<Count>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Count count() const {
    return max(start, end) - start;
  }

  /// May overflow.
  STU_CONSTEXPR
  T diameter() const {
    return max(start, end) - start;
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  T center() const {
    return start/2 + max(start/2, end/2);
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Range outsetBy(T value) const {
    Range range = *this;
    range.start -= value;
    range.end   += value;
    return range;
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Range insetBy(T value) const {
    return outsetBy(-value);
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Range roundedToNearbyInt() const {
    return {std::nearbyint(start), std::nearbyint(end)};
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  void roundToNearbyInt() {
    *this = roundedToNearbyInt();
  }

  // TODO: Make Range itself iterable once P0962R1 is implemented in Xcode's clang.

  struct Iterable {
    Range range;

    using Iterator = Apply<CountingIterator, T>;

    Iterator begin() const { return Iterator(range.start); }
    Iterator end() const { return Iterator(max(range.start, range.end)); }
  };

  template <bool enable = isType<Count>, EnableIf<enable> = 0>
  Iterable iter() const { return {*this}; }

  // TODO: proper constraints

  template <typename U, EnableIf<isType<decltype(declval<T&>() += declval<const U&>())>> = 0>
  STU_CONSTEXPR
  Range& operator+=(const U& offset) {
    start += offset;
    end += offset;
    return *this;
  }

  template <typename U, EnableIf<isType<decltype(declval<T&>() -= declval<const U&>())>> = 0>
  STU_CONSTEXPR
  Range& operator-=(const U& offset) {
    start -= offset;
    end -= offset;
    return *this;
  }

  template <typename U, EnableIf<isType<decltype(declval<T&>() *= declval<const U&>())>> = 0>
  STU_CONSTEXPR
  Range& operator*=(const U& scale) {
    start *= scale;
    end *= scale;
    if constexpr (isSigned<U>) {
      if (scale < 0) {
        using std::swap;
        swap(start, end);
      }
    }
    return *this;
  }

  template <typename U, EnableIf<isType<decltype(declval<T&>() /= declval<const U&>())>> = 0>
  STU_CONSTEXPR
  Range& operator/=(const U& scale) {
    start /= scale;
    end /= scale;
    if constexpr (isSigned<U>) {
      if (scale < 0) {
        using std::swap;
        swap(start, end);
      }
    }
    return *this;
  }

  // The implementation assumes commutative + and * operations.

  STU_CONSTEXPR
  friend Range operator+(Range range, const T& offset) {
    range += offset;
    return range;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator+(const Range& range, const U& offset) {
    Range<CommonType<T, U>> result{range};
    result += offset;
    return result;
  }

  STU_CONSTEXPR
  friend Range operator+(const T& offset, Range range) {
    return range + offset;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator+(const U& offset, const Range& range) {
    return range + offset;
  }

  STU_CONSTEXPR
  friend Range operator-(Range range, const T& offset) {
    range -= offset;
    return range;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator-(const Range& range, const U& offset) {
    Range<CommonType<T, U>> result{range};
    return result -= offset;
  }

  STU_CONSTEXPR
  friend Range operator*(Range range, const T& scale) {
    range *= scale;
    return range;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator*(const Range& range, const U& scale) {
    Range<CommonType<T, U>> result{range};
    result *= scale;
    return result;
  }

  STU_CONSTEXPR
  friend Range operator*(const T& scale, Range range) {
    return range*scale;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator*(const U& scale, const Range& range) {
    return range*scale;
  }

  STU_CONSTEXPR
  friend Range operator/(Range range, const T& scale) {
    range /= scale;
    return range;
  }
  template <typename U, EnableIf<!isSafelyConvertible<U, T>> = 0>
  STU_CONSTEXPR
  friend Range<CommonType<T, U>> operator/(const Range& range, const U& scale) {
    Range<CommonType<T, U>> result{range};
    result /= scale;
    return result;
  }
};

template <typename T>
struct IsMemberwiseConstructible<Range<T>> : IsMemberwiseConstructible<T> {};

template <typename R, EnableIf<isConstructible<Range<RangeBound<R>>, R&&>> = 0>
Range(R&&) -> Range<RangeBound<R>>;

template <typename Start, typename End,
          typename T = CommonType<Start, End>,
          EnableIf<isComparable<T>> = 0>
Range(Start start, End end) -> Range<T>;

// The following factory functions are still needed due to a bug in clang 6 that prevents deduction
// guide-based template parameter inference when the constructor is called within a pair of
// parentheses (e.g. in a macro expansion).

template <typename R, EnableIf<isConstructible<Range<RangeBound<R>>, R&&>> = 0>
STU_CONSTEXPR
Range<RangeBound<R>> range(R&& range) {
  return Range<RangeBound<R>>(std::forward<R>(range));
}

template <typename Start, typename End,
          typename T = CommonType<Start, End>,
          EnableIf<isComparable<T>> = 0>
STU_CONSTEXPR_T
Range<T> range(Start start, End end) {
  return Range<T>(std::move(start), std::move(end));
}

template <typename T, typename Int>
STU_CONSTEXPR_T
Range<T> range(T start, Count<Int> count) {
  return {start, count};
}

template <typename Int, EnableIf<isInteger<Int>> = 0>
STU_CONSTEXPR_T
auto sign_cast(Range<Int> value) noexcept {
  using Result = Conditional<isSigned<Int>, Range<Unsigned<Int>>, Range<Signed<Int>>>;
  return static_cast<Result>(value);
}

} // namespace stu
