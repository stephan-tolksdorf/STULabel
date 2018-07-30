// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelLayoutInfo-Internal.hpp"

#import "STULabel/STUTextFrame-Unsafe.h"

#import "Internal/LabelParameters.hpp"

using namespace stu;
using namespace stu_label;

namespace stu_label {

const LabelTextFrameInfo LabelTextFrameInfo::empty = {.isValid = true,
                                                      .flags = STUTextFrameHasMaxTypographicWidth};

STU_NO_INLINE
LabelTextFrameInfo labelTextFrameInfo(const TextFrame& frame,
                                      STULabelVerticalAlignment verticalAlignment,
                                      const DisplayScale& displayScale)
{
  const CGFloat scale = frame.textScaleFactor;

  const CGFloat minX = frame.layoutBounds.origin.x;
  const CGFloat maxX = minX + frame.layoutBounds.size.width;
  STULabelHorizontalAlignment horizontalAlignment;
  CGFloat x;
  CGFloat width;
  switch (frame.consistentAlignment) {
  case STUTextFrameConsistentAlignmentNone:
  case STUTextFrameConsistentAlignmentLeft:
    horizontalAlignment = STULabelHorizontalAlignmentLeft;
    x = 0;
    width = maxX;
    break;
  case STUTextFrameConsistentAlignmentRight:
    horizontalAlignment = STULabelHorizontalAlignmentRight;
    x = minX;
    width = frame.size.width - x;
    break;
  case STUTextFrameConsistentAlignmentCenter: {
    horizontalAlignment = STULabelHorizontalAlignmentCenter;
    const CGFloat midX = frame.size.width/2;
    width = max(midX - minX, maxX - midX);
    x = midX - width;
    width *= 2;
    break;
  }
  }

  CGFloat minY = frame.layoutBounds.origin.y;
  CGFloat maxY = frame.layoutMode == STUTextLayoutModeDefault
               ? minY + frame.layoutBounds.size.height
               : frame.layoutBoundsWithMinimalSpacingBelowLastBaselineMaxY;
  CGFloat maxYWithoutSpacingBelowLastLine;
  CGFloat firstBaseline;
  CGFloat lastBaseline;
  CGFloat centerY;
  Float32 firstLineAscent;
  Float32 firstLineLeading;
  Float32 lastLineDescent;
  Float32 lastLineLeading;
  if (!frame.lines().isEmpty()) {
    const TextFrameLine& firstLine = frame.lines()[0];
    const TextFrameLine& lastLine = frame.lines()[$ - 1];

    // The font scale factors that we compute can usually be converted to Float32 without a rounding
    // error. (The only case where there may be a rounding error is when the user-specified minimum
    // scale factor was reached. Not that floating point rounding errors really matter here anyway.)
    const Float32 scale32 = narrow_cast<Float32>(scale);
    firstLineAscent  = scale32*firstLine.ascent;
    firstLineLeading = scale32*firstLine.leading;
    lastLineDescent  = scale32*lastLine.descent;
    lastLineLeading  = scale32*lastLine.leading;

    const Float64 scale64 = scale;

    const CGFloat unroundedFirstBaseline = narrow_cast<CGFloat>(scale64*firstLine.originY);
    firstBaseline = unroundedFirstBaseline;
    if (displayScale != frame.displayScale) {
      firstBaseline = ceilToScale(firstBaseline, displayScale);
    }
    CGFloat d = firstBaseline - unroundedFirstBaseline;
    minY += d;
    if (frame.lines().count() == 1) {
      lastBaseline = firstBaseline;
    } else {
      const CGFloat unroundedLastBaseline = narrow_cast<CGFloat>(scale64*lastLine.originY);
      lastBaseline = unroundedLastBaseline;
      if (displayScale != frame.displayScale) {
        lastBaseline = ceilToScale(lastBaseline, displayScale);
      }
      d = lastBaseline - unroundedLastBaseline;
    }
    maxY += d;
    maxYWithoutSpacingBelowLastLine = d
                                    + narrow_cast<CGFloat>(
                                        scale64*(lastLine.originY
                                                 + lastLine._heightBelowBaselineWithoutSpacing));

    switch (verticalAlignment) {
    case STULabelVerticalAlignmentCenterXHeight:
    case STULabelVerticalAlignmentCenterCapHeight: {
      const bool isXHeight = verticalAlignment == STULabelVerticalAlignmentCenterXHeight;
      const CGFloat hf = scale32*(isXHeight
                                  ? firstLine.maxFontMetricValue<FontMetric::xHeight>()
                                  : firstLine.maxFontMetricValue<FontMetric::capHeight>());
      if (frame.lines().count() == 1) {
        centerY = firstBaseline - hf/2;
      } else {
        const CGFloat hl = scale32*(isXHeight
                                    ? lastLine.maxFontMetricValue<FontMetric::xHeight>()
                                    : lastLine.maxFontMetricValue<FontMetric::capHeight>());
        centerY = (firstBaseline + lastBaseline)/2 - (hf + hl)/4;
      }
      break;
    }
    default:
      centerY = (minY + maxY)/2;
    }
  } else {
    firstBaseline = 0;
    lastBaseline = 0;
    centerY = 0;
    firstLineAscent = 0;
    firstLineLeading = 0;
    lastLineDescent = 0;
    lastLineLeading = 0;
    maxYWithoutSpacingBelowLastLine = 0;
  }

  CGFloat y;
  CGFloat height;
  switch (verticalAlignment) {
  case STULabelVerticalAlignmentTop:
  case STULabelVerticalAlignmentBottom:
    y = 0;
    height = maxY;
    break;
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight:
    height = max(centerY - minY, maxY - centerY);
    y = centerY - height;
    height *= 2;
    break;
  }

  CGSize minFrameSize = {min(frame.size.width, width),
                         min(frame.size.height, maxYWithoutSpacingBelowLastLine - y)};
  // For values only slightly larger than the the rounded value ceilToScale may actually round down.
  minFrameSize.width = min(minFrameSize.width, ceilToScale(minFrameSize.width, displayScale));
  minFrameSize.height = min(minFrameSize.height, ceilToScale(minFrameSize.height, displayScale));

  return {
    .isValid = true,
    .flags = frame.flags,
    .textLayoutMode = frame.layoutMode,
    .horizontalAlignment = horizontalAlignment,
    .verticalAlignment = verticalAlignment,
    .lineCount = frame.lineCount,
    .frameSize = frame.size,
    .layoutBounds = CGRect{{x, y}, {width, height}},
    .minFrameSize = minFrameSize,
    .firstBaseline = firstBaseline,
    .lastBaseline = lastBaseline,
    .textScaleFactor = scale,
    .firstLineAscent = firstLineAscent,
    .firstLineLeading = firstLineLeading,
    .firstLineHeight = frame.firstLineHeight,
    .lastLineDescent = lastLineDescent,
    .lastLineLeading = lastLineLeading,
    .lastLineHeight = frame.lastLineHeight
  };
}

 STULabelLayoutInfo stuLabelLayoutInfo(const LabelTextFrameInfo& info,
                                       CGPoint textFrameOrigin,
                                       const stu_label::DisplayScale& displayScale)
{
  return {
    .layoutBounds = textFrameOrigin + info.layoutBounds,
    .lineCount = info.lineCount,
    .textFrameFlags = info.flags,
    .textLayoutMode = info.textLayoutMode,
    .horizontalAlignment = info.horizontalAlignment,
    .verticalAlignment = info.verticalAlignment,
    .firstBaseline = textFrameOrigin.y + info.firstBaseline,
    .lastBaseline = textFrameOrigin.y + info.lastBaseline,
    .firstLineAscent = info.firstLineAscent,
    .firstLineLeading = info.firstLineLeading,
    .firstLineHeight = info.lastLineHeight,
    .lastLineDescent = info.lastLineDescent,
    .lastLineLeading = info.lastLineLeading,
    .lastLineHeight = info.lastLineHeight,
    .textFrameOrigin = textFrameOrigin,
    .textScaleFactor = info.textScaleFactor,
    .displayScale = displayScale,
  };
};

STU_NO_INLINE
bool LabelTextFrameInfo::isValidForSizeImpl(CGSize size, const DisplayScale& displayScale) const {
  STU_DEBUG_ASSERT(isValid);
  const CGFloat maxWidth  = max(frameSize.width, layoutBounds.width());
  const CGFloat maxHeight = max(frameSize.height, layoutBounds.height());
  return isValid
      && size.width  >= minFrameSize.width
      && size.height >= minFrameSize.height
      && ((flags & STUTextFrameHasMaxTypographicWidth)
          || (size.width < maxWidth + displayScale.inverseValue()
              && (!(flags & (STUTextFrameIsScaled | STUTextFrameIsTruncated))
                  || size.height <= maxHeight + displayScale.inverseValue())));
}

STU_NO_INLINE
CGSize LabelTextFrameInfo::sizeThatFits(const UIEdgeInsets& insets,
                                        const DisplayScale& displayScale) const
{
  return ceilToScale(layoutBounds.inset(-roundLabelEdgeInsetsToScale(insets, displayScale)),
                     displayScale).size();
}

STU_NO_INLINE
CGPoint textFrameOriginInLayer(const LabelTextFrameInfo& info,
                               const LabelParameters& p)
{
  STU_DEBUG_ASSERT(info.isValid);
  CGFloat x;
  switch (info.horizontalAlignment) {
  case STULabelHorizontalAlignmentLeft:
    x = p.edgeInsets().left - info.layoutBounds.x.start;
    break;
  case STULabelHorizontalAlignmentRight:
    x = p.size().width - p.edgeInsets().right - info.layoutBounds.x.end;
    break;
  case STULabelHorizontalAlignmentCenter:
    x = (p.size().width/2 - (info.layoutBounds.x.start + info.layoutBounds.x.end)/2)
      + (p.edgeInsets().left - p.edgeInsets().right);
    break;
  }
  CGFloat y;
  switch (info.verticalAlignment) {
  case STULabelVerticalAlignmentTop:
    y = p.edgeInsets().top - info.layoutBounds.y.start;
    break;
  case STULabelVerticalAlignmentBottom:
    y = p.size().height - p.edgeInsets().bottom - info.layoutBounds.y.end;
    break;
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight:
    y = (p.size().height/2 - (info.layoutBounds.y.start + info.layoutBounds.y.end)/2)
      + (p.edgeInsets().top - p.edgeInsets().bottom);
    break;
  }
  return {roundToScale(x, p.displayScale()), roundToScale(y, p.displayScale())};
}

} // namespace stu_label



