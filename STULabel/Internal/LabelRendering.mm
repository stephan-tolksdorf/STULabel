// Copyright 2017–2018 Stephan Tolksdorf

#import "LabelRendering.hpp"

#import "STULabel/STULabelDrawingBlock-Internal.h"
#import "STULabel/STUTextFrame-Internal.hpp"
#import "STULabel/STUTextHighlightStyle-Internal.hpp"

#import "LabelParameters.hpp"

namespace stu_label {

static CGRect renderBoundsWithTextFrameImageBounds(CGRect imageBounds,
                                                   const LabelTextFrameInfo& info,
                                                   CGSize sizeIncludingEdgeInsets,
                                                   UIEdgeInsets edgeInsets,
                                                   Out<bool> outTextFrameExceedsBounds)
{
  const CGFloat minImageX = imageBounds.origin.x;
  const CGFloat maxImageX = minImageX + imageBounds.size.width;
  bool exceedsBounds;
  CGFloat x, width;
  switch (info.horizontalAlignment) {
  case STULabelHorizontalAlignmentLeft: {
    x = info.layoutBounds.origin.x - edgeInsets.left;
    const CGFloat maxX = x + sizeIncludingEdgeInsets.width;
    exceedsBounds = minImageX < x | maxImageX > maxX;
    width = min(maxX, maxImageX) - x;
    break;
  }
  case STULabelHorizontalAlignmentRight: {
    const CGFloat maxX = info.layoutBounds.origin.x + info.layoutBounds.size.width
                       + edgeInsets.right;
    const CGFloat minX = maxX - sizeIncludingEdgeInsets.width;
    exceedsBounds = maxImageX > maxX | minImageX < minX;
    x = max(minX, minImageX);
    width = maxX - x;
    break;
  }
  case STULabelHorizontalAlignmentCenter: {
    const CGFloat midX = info.layoutBounds.origin.x + info.layoutBounds.size.width/2
                       + (edgeInsets.right - edgeInsets.left);
    width = 2*max(midX - minImageX, maxImageX - midX);
    exceedsBounds = width > sizeIncludingEdgeInsets.width;
    if (exceedsBounds) {
      width = sizeIncludingEdgeInsets.width;
    }
    x = midX - width/2;
    break;
  }
  }

  const CGFloat minImageY = imageBounds.origin.y;
  const CGFloat maxImageY = minImageY + imageBounds.size.height;
  CGFloat y, height;
  switch (info.verticalAlignment) {
  case STULabelVerticalAlignmentTop: {
    y = info.layoutBounds.origin.y - edgeInsets.top;
    const CGFloat maxY = y + sizeIncludingEdgeInsets.height;
    exceedsBounds |= minImageY < y | maxImageY > maxY;
    height = min(maxY, maxImageY) - y;
    break;
  }
  case STULabelVerticalAlignmentBottom: {
    const CGFloat maxY = info.layoutBounds.origin.y + info.layoutBounds.size.height
                       + edgeInsets.bottom;
    const CGFloat minY = maxY - sizeIncludingEdgeInsets.height;
    exceedsBounds |= maxImageY > maxY | minImageY < minY;
    y = max(minY, minImageY);
    height = maxY - y;
    break;
  }
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight: {
    const CGFloat midY = info.layoutBounds.origin.y + info.layoutBounds.size.height/2
                       + (edgeInsets.bottom - edgeInsets.top);
    height = 2*max(midY - minImageY, maxImageY - midY);
    exceedsBounds |= height > sizeIncludingEdgeInsets.height;
    if (exceedsBounds) {
      height = sizeIncludingEdgeInsets.height;
    }
    y = midY - height/2;
    break;
  }
  }

  outTextFrameExceedsBounds = exceedsBounds;
  return CGRect{{x, y}, {width, height}};
}

LabelTextFrameRenderInfo labelTextFrameRenderInfo(const STUTextFrame* __unsafe_unretained textFrame,
                                                  const LabelTextFrameInfo& info,
                                                  const CGPoint& frameOriginInLayer,
                                                  const LabelParameters& params,
                                                  bool preferImageMode,
                                                  const STUCancellationFlag* __nullable
                                                    cancellationFlag)
{
  const CGFloat maxImagePixelDimension = 4096;

  LabelRenderMode mode = params.alwaysUsesContentSublayer ? LabelRenderMode::imageInSublayer
                       : preferImageMode ? LabelRenderMode::image
                                         : LabelRenderMode::drawInCAContext;

  const STUTextFrameFlags frameFlags = [&]() STU_INLINE_LAMBDA -> STUTextFrameFlags  {
    const auto frameFlags = textFrame->data->flags;
    if (!params.drawingOptions) return frameFlags;
    TextFrameDrawingOptions& options = params.drawingOptions->impl;
    TextFlags extraFlags = options.overrideColorFlags(frameFlags & STUTextFrameHasLink);
    if (params.isEffectivelyHighlighted()) {
      extraFlags |= options.highlightStyle().unretained->style.flags;
    }
    return frameFlags | static_cast<STUTextFrameFlags>(extraFlags);
  }();

  // Obtaining image bounds from CoreText is currently a pretty slow operation, so we can't
  // just always do it. (I wonder whether it shouldn't be possible to compute glyph path bounds
  // during text shaping such that the introduced overhead is minimal, possibly by
  // caching/precomputing glyph bounds at the system level. Having cheap image bounds for glyph runs
  // would really be quite useful.)

  const bool useImageBounds = !params.clipsContentToBounds
                           || (mode != LabelRenderMode::drawInCAContext
                               && info.layoutBounds.size.width*info.layoutBounds.size.height
                                  <= (2./3)*params.size().width*params.size().height
                               && params.displayScale()
                                  *(1 + max(info.layoutBounds.size.width,
                                            info.layoutBounds.size.height))
                                  <= maxImagePixelDimension);

  CGRect bounds;
  CGRect imageBounds;
  bool mayBeClipped = true;
  if (useImageBounds) {
    imageBounds = STUTextFrameGetImageBoundsForRange(textFrame, STUTextFrameGetRange(textFrame),
                                                     CGPoint{}, params.displayScale(),
                                                     params.drawingOptions, cancellationFlag);
    bounds = renderBoundsWithTextFrameImageBounds(imageBounds, info, params.size(),
                                                  params.edgeInsets(), Out{mayBeClipped});
    if (mayBeClipped && !params.clipsContentToBounds) {
      mayBeClipped = false;
      mode = LabelRenderMode::imageInSublayer;
      bounds = imageBounds;
    }
    bounds = ceilToScale(bounds, params.displayScale());
  }
  if (!useImageBounds || mode == LabelRenderMode::drawInCAContext) {
    bounds = CGRect{-frameOriginInLayer, params.size()};
    if (!useImageBounds && params.clipsContentToBounds) {
      // If the bounds fully contain the layoutBounds we just assume that the text isn't clipped.
      // This is a performance optimization that avoids always having to redraw when the bounds
      // grow.
      mayBeClipped = !CGRectContainsRect(bounds, info.layoutBounds);
    }
  }

  if (params.displayScale()*max(bounds.size.width, bounds.size.height) > maxImagePixelDimension) {
    if (params.clipsContentToBounds && useImageBounds && mode != LabelRenderMode::drawInCAContext) {
      const CGRect oldBounds = bounds;
      bounds = CGRectIntersection(bounds, CGRect{-frameOriginInLayer, params.size()});
      mayBeClipped = bounds != oldBounds;
    }
    mode = LabelRenderMode::tiledSublayer;
  }

  // Not using grayscale pixel formats when synchronously drawing into a CALayer context seems
  // to improve performance.
  bool isGrayscale = mode != LabelRenderMode::drawInCAContext
                  && !params.neverUseGrayscaleBitmapFormat
                  && !(frameFlags & STUTextFrameMayNotBeGrayscale);

  bool shouldDrawBackgroundColor = (params.backgroundColorFlags() & ColorFlags::isOpaque)
                                && (   mode == LabelRenderMode::drawInCAContext
                                    || (mode == LabelRenderMode::image && isGrayscale));

  const bool isIOS9 = NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_9_x_Max;

  const bool useExtendedColor = !isIOS9 && (frameFlags & STUTextUsesWideColor);
  if (!useExtendedColor && (params.backgroundColorFlags() & ColorFlags::isExtended)) {
    shouldDrawBackgroundColor = false;
  }

  if (shouldDrawBackgroundColor
      && isGrayscale && (params.backgroundColorFlags() & ColorFlags::isNotGray))
  {
    if (mode == LabelRenderMode::drawInCAContext) {
      isGrayscale = false;
    } else {
      shouldDrawBackgroundColor = false;
    }
  }

  const bool isOpaque = shouldDrawBackgroundColor
                     && (params.backgroundColorFlags() & ColorFlags::isOpaque);
  if (isIOS9 && !isOpaque) {
    isGrayscale = false;
  }
  const auto imageFormat = isGrayscale ? STUPredefinedCGImageFormatGrayscale
                         : !useExtendedColor ? STUPredefinedCGImageFormatRGB
                         : STUPredefinedCGImageFormatExtendedRGB;
  return {
    .bounds = bounds,
    .mode = mode,
    .imageFormat = imageFormat,
    .shouldDrawBackgroundColor = shouldDrawBackgroundColor,
    .isOpaque = isOpaque,
    .mayBeClipped = mayBeClipped
  };
}

void drawLabelTextFrameRange(
       const STUTextFrame* __unsafe_unretained textFrame, STUTextFrameRange range,
       CGPoint textFrameOrigin, CGContextRef context, bool isVectorContext, CGFloat contextBaseCTM_d,
       const STUTextFrameDrawingOptions* __unsafe_unretained __nullable options,
       __unsafe_unretained __nullable STULabelDrawingBlock drawingBlock,
       const STUCancellationFlag* __nullable cancellationFlag)
{
  if (!context) return;
  if (!drawingBlock) {
    STUTextFrameDrawRange(textFrame, range, textFrameOrigin, context, isVectorContext,
                          contextBaseCTM_d, options, cancellationFlag);
  } else {
    STU_DEBUG_ASSERT(!options || options->impl.isFrozen());
    STULabelDrawingBlockParameters* const p =
      STULabelDrawingBlockParametersCreate(
        // Pointer to non-const is an Obj-C convention.
        const_cast<STUTextFrame*>(textFrame), range, textFrameOrigin, context, isVectorContext,
        contextBaseCTM_d, const_cast<STUTextFrameDrawingOptions*>(options), cancellationFlag);
    STULabelDrawingBlock const retainedDrawingBlock = drawingBlock;
    retainedDrawingBlock(p);
  }
}

PurgeableImage createLabelTextFrameImage(const STUTextFrame* __unsafe_unretained textFrame,
                                         const LabelTextFrameRenderInfo& renderInfo,
                                         const LabelParameters& params,
                                         const STUCancellationFlag* __nullable cancellationFlag)
{
  return {renderInfo.bounds.size, params.displayScale(),
          renderInfo.shouldDrawBackgroundColor ? params.backgroundColor() : nil,
          renderInfo.imageFormat,
          renderInfo.isOpaque ? STUCGImageFormatWithoutAlphaChannel : STUCGImageFormatOptionsNone,
          [&](CGContext* context) {
            drawLabelTextFrameRange(textFrame, STUTextFrameGetRange(textFrame),
                                    -renderInfo.bounds.origin, context, false, 1,
                                    params.drawingOptions, params.drawingBlock, cancellationFlag);
          }};
}

} // namespace stu_label

