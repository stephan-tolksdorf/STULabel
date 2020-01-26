// Copyright 2017 Stephan Tolksdorf

#import "STUStartEndRange.h"

#import "stu/Range.hpp"

template <>
struct stu::RangeConversion<STUStartEndRange> {
  STU_CONSTEXPR
  static Range<stu::Int> toRange(STUStartEndRange range) noexcept {
    return {range.start, range.end};
  }

  STU_CONSTEXPR
  static STUStartEndRange fromRange(Range<stu::Int> range) noexcept {
    return {range.start, range.end};
  }
};

template <>
struct stu::RangeConversion<STUStartEndRangeI32> {
  STU_CONSTEXPR
  static Range<stu::Int32> toRange(STUStartEndRangeI32 range) noexcept {
    return {range.start, range.end};
  }

  STU_CONSTEXPR
  static STUStartEndRangeI32 fromRange(Range<stu::Int32> range) noexcept {
    return {range.start, range.end};
  }
};

