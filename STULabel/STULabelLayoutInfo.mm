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
  const double minX = frame.minX;
  const double maxX = frame.maxX;
  STULabelHorizontalAlignment horizontalAlignment;
  CGFloat x;
  CGFloat width;
  switch (frame.consistentAlignment) {
  case STUTextFrameConsistentAlignmentNone:
  case STUTextFrameConsistentAlignmentLeft:
    horizontalAlignment = STULabelHorizontalAlignmentLeft;
    x = 0;
    width = narrow_cast<CGFloat>(maxX);
    break;
  case STUTextFrameConsistentAlignmentRight:
    horizontalAlignment = STULabelHorizontalAlignmentRight;
    x = narrow_cast<CGFloat>(minX);
    width = frame.size.width - x;
    break;
  case STUTextFrameConsistentAlignmentCenter: {
    horizontalAlignment = STULabelHorizontalAlignmentCenter;
    const double midX = (minX + maxX)/2;
    width = narrow_cast<CGFloat>(max(midX - minX, maxX - midX));
    x = narrow_cast<CGFloat>(midX - width);
    width *= 2;
    break;
  }
  }

  double minY;
  double maxY;
  double maxYWithoutSpacingBelowLastLine;
  double firstBaseline;
  double lastBaseline;
  double centerY;
  if (frame.lineCount != 0) {
    firstBaseline = ceilToScale(frame.firstBaseline, displayScale);
    lastBaseline = ceilToScale(frame.lastBaseline, displayScale);

    minY = firstBaseline - frame.firstLineHeightAboveBaseline;
    maxY = lastBaseline
            + (frame.layoutMode == STUTextLayoutModeDefault
                ? frame.lastLineHeightBelowBaseline
                : frame.lastLineHeightBelowBaselineWithMinimalSpacing);
    maxYWithoutSpacingBelowLastLine = lastBaseline + frame.lastLineHeightBelowBaselineWithoutSpacing;

    switch (verticalAlignment) {
    case STULabelVerticalAlignmentCenterXHeight:
    case STULabelVerticalAlignmentCenterCapHeight: {
      const ArrayRef<const TextFrameLine> lines = frame.lines();
      const TextFrameLine& firstLine = lines[0];
      const TextFrameLine& lastLine = lines[$ - 1];
      const bool isXHeight = verticalAlignment == STULabelVerticalAlignmentCenterXHeight;
      const CGFloat scale = frame.textScaleFactor;
      const CGFloat hf = scale*(isXHeight
                                ? firstLine.maxFontMetricValue<FontMetric::xHeight>()
                                : firstLine.maxFontMetricValue<FontMetric::capHeight>());
      if (frame.lines().count() == 1) {
        centerY = firstBaseline - hf/2;
      } else {
        const CGFloat hl = scale*(isXHeight
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
    minY = 0;
    maxY = 0;
    maxYWithoutSpacingBelowLastLine = 0;
    firstBaseline = 0;
    lastBaseline = 0;
    centerY = 0;
  }

  CGFloat y;
  CGFloat height;
  switch (verticalAlignment) {
  case STULabelVerticalAlignmentTop:
  case STULabelVerticalAlignmentBottom:
    y = 0;
    height = narrow_cast<CGFloat>(maxY);
    break;
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight:
    height = narrow_cast<CGFloat>(max(centerY - minY, maxY - centerY));
    y = narrow_cast<CGFloat>(centerY - height);
    height *= 2;
    break;
  }

  CGSize minFrameSize = {min(frame.size.width, width),
                         min(frame.size.height,
                             narrow_cast<CGFloat>(maxYWithoutSpacingBelowLastLine) - y)};
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
    .layoutBounds = CGRect{{x, y}, {width, height}},
    .frameSize = frame.size,
    .minFrameSize = minFrameSize,
    .firstBaseline = narrow_cast<CGFloat>(firstBaseline),
    .lastBaseline = narrow_cast<CGFloat>(lastBaseline),
    .firstLineHeight = frame.firstLineHeight,
    .firstLineHeightAboveBaseline = frame.firstLineHeightAboveBaseline,
    .lastLineHeight = frame.lastLineHeight,
    .lastLineHeightBelowBaseline = frame.lastLineHeightBelowBaseline,
    .textScaleFactor = frame.textScaleFactor,
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
    .firstLineHeight = info.lastLineHeight,
    .firstLineHeightAboveBaseline = info.firstLineHeightAboveBaseline,
    .lastLineHeight = info.lastLineHeight,
    .lastLineHeightBelowBaseline = info.lastLineHeightBelowBaseline,
    .textScaleFactor = info.textScaleFactor,
    .displayScale = displayScale,
    .textFrameOrigin = textFrameOrigin,
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



