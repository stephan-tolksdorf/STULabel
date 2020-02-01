// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STULabel.h"
#import "STULabel/STUMainScreenProperties.h"

#import "Common.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

static const Float32 maxFloatInputValue = 1 << 30;

STU_INLINE
Float64 clampFloatInput(Float64 value) {
  return value >= 0 ? min(value,  maxFloatInputValue)
       : value <  0 ? max(value, -maxFloatInputValue)
       : 0; // Handles NaN values.
}

STU_INLINE
Float32 clampFloatInput(Float32 value) {
  return value >= 0 ? min(value,  maxFloatInputValue)
       : value <  0 ? max(value, -maxFloatInputValue)
       : 0; // Handles NaN values.
}

template <typename T, EnableIf<isFloatingPoint<T>> = 0>
STU_INLINE
T clampNonNegativeFloatInput(T value) {
  return value >= 0 ? min(value, maxFloatInputValue) : 0;
}

template <typename T, EnableIf<isFloatingPoint<T>> = 0>
STU_INLINE
T clampNonPositiveFloatInput(T value) {
  return value <= 0 ? max(-maxFloatInputValue, value) : 0;
}



STU_INLINE
CFTimeInterval clampNonNegativeTimeIntervalInput(CFTimeInterval value) {
  return value >= 0 ? value : 0;
}

STU_INLINE
CGFloat clampMinTextScaleFactor(CGFloat value) {
  return 0 < value && value <= 1 ? value : 1;
}

STU_INLINE
CGFloat clampTextScaleFactorStepSize(CGFloat value) {
  return value >= 0 ? min(value, 1.f) : 0;
}

STU_INLINE
NSInteger clampMaxLineCount(NSInteger value) {
  if (value < 0) {
    value = 0;
  }
  return value;
}

STU_INLINE
CGPoint clampPointInput(CGPoint point) {
  return CGPoint{clampFloatInput(point.x), clampFloatInput(point.y)};
}

STU_INLINE
CGVector clampVectorInput(CGVector offset) {
  return CGVector{clampFloatInput(offset.dx), clampFloatInput(offset.dy)};
}

STU_INLINE
CGSize clampSizeInput(CGSize size) {
  return CGSize{clampNonNegativeFloatInput(size.width), clampNonNegativeFloatInput(size.height)};
}

STU_INLINE
CGRect clampRectInput(CGRect rect) {
  if (STU_UNLIKELY(rect.size.width < 0 || rect.size.height < 0)) {
    rect = CGRectStandardize(rect);
  }
  return CGRect{clampPointInput(rect.origin), clampSizeInput(rect.size)};
}

STU_INLINE
UIEdgeInsets clampEdgeInsetsInput(UIEdgeInsets edgeInsets) {
  return UIEdgeInsets{.top    = clampFloatInput(edgeInsets.top),
                      .left   = clampFloatInput(edgeInsets.left),
                      .bottom = clampFloatInput(edgeInsets.bottom),
                      .right  = clampFloatInput(edgeInsets.right)};
}

STU_INLINE
UIEdgeInsets clampNonNegativeEdgeInsetsInput(UIEdgeInsets edgeInsets) {
  return UIEdgeInsets{.top    = clampNonNegativeFloatInput(edgeInsets.top),
                      .left   = clampNonNegativeFloatInput(edgeInsets.left),
                      .bottom = clampNonNegativeFloatInput(edgeInsets.bottom),
                      .right  = clampNonNegativeFloatInput(edgeInsets.right)};
}

STU_INLINE
CGFloat clampDisplayScaleInput(CGFloat scale) {
  scale = clampNonNegativeFloatInput(scale);
  if (scale == 0) {
    scale = stu_mainScreenScale();
  }
  return scale;
}

STU_INLINE
STUTextLayoutMode clampTextLayoutMode(STUTextLayoutMode value) {
  switch (value) {
  case STUTextLayoutModeDefault:
  case STUTextLayoutModeTextKit:
    return value;
  }
  return STUTextLayoutModeDefault;
}


STU_INLINE
UIUserInterfaceLayoutDirection clampUserInterfaceLayoutDirection(UIUserInterfaceLayoutDirection value) {
  switch (value) {
  case UIUserInterfaceLayoutDirectionLeftToRight:
  case UIUserInterfaceLayoutDirectionRightToLeft:
    return value;
  }
  return UIUserInterfaceLayoutDirectionLeftToRight;
}

STU_INLINE
STUWritingDirection clampBaseWritingDirection(STUWritingDirection value) {
  switch (value) {
  case STUWritingDirectionLeftToRight:
  case STUWritingDirectionRightToLeft:
    return value;
  }
  return STUWritingDirectionLeftToRight;
}

STU_INLINE
STUDefaultTextAlignment clampDefaultTextAlignment(STUDefaultTextAlignment value) {
  switch (value) {
  case STUDefaultTextAlignmentLeft:
  case STUDefaultTextAlignmentRight:
  case STUDefaultTextAlignmentStart:
  case STUDefaultTextAlignmentEnd:
    return value;
  }
  return STUDefaultTextAlignmentLeft;
}

STU_INLINE
STULabelDefaultTextAlignment clampDefaultTextAlignment(STULabelDefaultTextAlignment value) {
  switch (value) {
  case STULabelDefaultTextAlignmentLeading:
  case STULabelDefaultTextAlignmentTrailing:
  case STULabelDefaultTextAlignmentTextStart:
  case STULabelDefaultTextAlignmentTextEnd:
    return value;
  }
  return STULabelDefaultTextAlignmentLeading;
}


STU_INLINE
NSTextAlignment clampTextAlignment(NSTextAlignment textAlignment) {
  switch (textAlignment) {
  case NSTextAlignmentLeft:
  case NSTextAlignmentCenter:
  case NSTextAlignmentRight:
  case NSTextAlignmentJustified:
  case NSTextAlignmentNatural:
    return textAlignment;
  }
  return NSTextAlignmentNatural;
}

STU_INLINE
STULabelVerticalAlignment clampVerticalAlignmentInput(STULabelVerticalAlignment verticalAlignment) {
  switch (verticalAlignment) {
  case STULabelVerticalAlignmentTop:
  case STULabelVerticalAlignmentBottom:
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight:
    return verticalAlignment;
  }
  return STULabelVerticalAlignmentTop;
}

STU_INLINE
STUTextRangeType clampTextRangeType(STUTextRangeType rangeType) {
  switch (rangeType) {
  case STURangeInOriginalString:
  case STURangeInTruncatedString:
   return rangeType;
  }
  return STURangeInOriginalString;
}

STU_INLINE
STULastLineTruncationMode clampLastLineTruncationMode(STULastLineTruncationMode mode) {
  switch (mode)  {
  case STULastLineTruncationModeEnd:
  case STULastLineTruncationModeMiddle:
  case STULastLineTruncationModeStart:
  case STULastLineTruncationModeClip:
    return mode;
  }
  return STULastLineTruncationModeEnd;
}

STU_INLINE
STUBaselineAdjustment clampBaselineAdjustment(STUBaselineAdjustment mode) {
  switch (mode)  {
  case STUBaselineAdjustmentNone:
  case STUBaselineAdjustmentAlignFirstBaseline:
  case STUBaselineAdjustmentAlignFirstLineCenter:
  case STUBaselineAdjustmentAlignFirstLineCapHeightCenter:
  case STUBaselineAdjustmentAlignFirstLineXHeightCenter:
    return mode;
  }
  return STUBaselineAdjustmentNone;
}

STU_INLINE
STUFirstOrLastBaseline clampFirstOrLastBaseline(STUFirstOrLastBaseline baseline) {
  switch (baseline)  {
  case STUFirstBaseline:
  case STULastBaseline:
    return baseline;
  }
  return STUFirstBaseline;
}

STU_INLINE STULabelDrawingBounds clampLabelDrawingBounds(STULabelDrawingBounds bounds) {
  switch (bounds)  {
  case STULabelTextImageBounds:
  case STULabelTextLayoutBounds:
  case STULabelTextLayoutBoundsPlusInsets:
  case STULabelViewBounds:
    return bounds;
  }
  return STULabelTextLayoutBoundsPlusInsets;
}

STU_INLINE
STULabelDrawingBlockColorOptions
  clampLabelDrawingBlockColorOptions(STULabelDrawingBlockColorOptions options)
{
  return options & ((1 << STULabelDrawingBlockColorOptionsBitSize) - 1);
}


STU_INLINE
Range<Int32> clampToInt32IndexRange(NSRange range) {
  const UInt maxValue = INT32_MAX;
  UInt end = 0;
  if (STU_UNLIKELY(__builtin_add_overflow(range.location, range.length, &end))) {
    end = maxValue;
  }
  return {narrow_cast<Int32>(min(range.location, maxValue)),
          narrow_cast<Int32>(min(end, maxValue))};
}

template <typename Int, typename Float,
          EnableIf<isSignedInteger<Int> && isFloatingPoint<Float>> = 0>
STU_CONSTEXPR
Int truncatePositiveFloatTo(Float value) {
  if (STU_LIKELY(value < maxValue<Unsigned<Int>>/2 + 1)) {
    return static_cast<Int>(value);
  }
  return maxValue<Int>;
}

template <typename Int, typename Float,
          EnableIf<isSignedInteger<Int> && isFloatingPoint<Float>> = 0>
STU_CONSTEXPR
Int truncateFloatTo(Float value) {
  if (STU_LIKELY(value < maxValue<Unsigned<Int>>/2 + 1)) {
    if (STU_LIKELY(value >= minValue<Int>)) {
      return static_cast<Int>(value);
    } else {
      return minValue<Int>;
    }
  }
  return maxValue<Int>;
}

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
