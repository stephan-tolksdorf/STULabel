// Copyright 2017–2018 Stephan Tolksdorf

#import "LabelRendering.hpp"

#import "STULabel/STULabelDrawingBlock-Internal.hpp"
#import "STULabel/STUTextFrame-Internal.hpp"
#import "STULabel/STUTextHighlightStyle-Internal.hpp"

#import "LabelParameters.hpp"

namespace stu_label {

static Rect<CGFloat> renderBoundsForTextFrameImageBounds(Rect<CGFloat> imageBounds,
                                                         const LabelTextFrameInfo& info,
                                                         CGSize sizeIncludingEdgeInsets,
                                                         UIEdgeInsets edgeInsets,
                                                         CGFloat tolerance,
                                                         Out<bool> outTextFrameExceedsBounds)
{
  bool exceedsBounds;
  CGFloat minX, maxX;
  switch (info.horizontalAlignment) {
  case STULabelHorizontalAlignmentLeft: {
    minX = info.layoutBounds.x.start - edgeInsets.left;
    maxX = minX + sizeIncludingEdgeInsets.width;
    exceedsBounds = imageBounds.x.start + tolerance < minX | imageBounds.x.end - tolerance > maxX;
    maxX = min(maxX, imageBounds.x.end);
    break;
  }
  case STULabelHorizontalAlignmentRight: {
    maxX = info.layoutBounds.x.end + edgeInsets.right;
    minX = maxX - sizeIncludingEdgeInsets.width;
    exceedsBounds = imageBounds.x.end - tolerance > maxX | imageBounds.x.start + tolerance < minX;
    minX = max(minX, imageBounds.x.start);
    break;
  }
  case STULabelHorizontalAlignmentCenter: {
    const CGFloat midX = (info.layoutBounds.x.start + info.layoutBounds.x.end)/2
                       + (edgeInsets.right - edgeInsets.left);
    CGFloat width = 2*max(midX - imageBounds.x.start, imageBounds.x.end - midX);
    exceedsBounds = width > sizeIncludingEdgeInsets.width + 2*tolerance;
    width = min(width, sizeIncludingEdgeInsets.width);
    minX = midX - width/2;
    maxX = minX + width;
    break;
  }
  }

  CGFloat minY, maxY;
  switch (info.verticalAlignment) {
  case STULabelVerticalAlignmentTop: {
    minY = info.layoutBounds.y.start - edgeInsets.top;
    maxY = minY + sizeIncludingEdgeInsets.height;
    exceedsBounds |= imageBounds.y.start + tolerance < minY | imageBounds.y.end - tolerance > maxY;
    maxY = min(maxY, imageBounds.y.end);
    break;
  }
  case STULabelVerticalAlignmentBottom: {
    maxY = info.layoutBounds.y.end + edgeInsets.bottom;
    minY = maxY - sizeIncludingEdgeInsets.height;
    exceedsBounds |= imageBounds.y.end - tolerance > maxY | imageBounds.y.start + tolerance < minY;
    minY = max(minY, imageBounds.y.start);
    break;
  }
  case STULabelVerticalAlignmentCenter:
  case STULabelVerticalAlignmentCenterCapHeight:
  case STULabelVerticalAlignmentCenterXHeight: {
    const CGFloat midY = (info.layoutBounds.y.start + info.layoutBounds.y.end)/2
                       + (edgeInsets.bottom - edgeInsets.top);
    CGFloat height = 2*max(midY - imageBounds.y.start, imageBounds.y.end - midY);
    exceedsBounds |= height > sizeIncludingEdgeInsets.height + 2*tolerance;
    height = min(height, sizeIncludingEdgeInsets.height);
    minY = midY - height/2;
    maxY = minY + height;
    break;
  }
  }

  outTextFrameExceedsBounds = exceedsBounds;
  return {Range{minX, maxX}, Range{minY, maxY}};
}

LabelTextFrameRenderInfo labelTextFrameRenderInfo(const STUTextFrame* __unsafe_unretained textFrame,
                                                  const LabelTextFrameInfo& info,
                                                  const CGPoint& frameOriginInLayer,
                                                  const LabelParameters& params,
                                                  bool allowExtendedRGBBitmapFormat,
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
                               && info.minFrameSize.area()
                                  <= (2./3)*params.size().width*params.size().height
                               && params.displayScale()
                                  *(1 + max(info.minFrameSize.width, info.minFrameSize.height))
                                  <= maxImagePixelDimension);

  Rect<CGFloat> bounds{uninitialized};
  Rect<CGFloat> imageBounds{uninitialized};
  bool mayBeClipped = true;
  if (useImageBounds) {
    imageBounds = STUTextFrameGetImageBoundsForRange(textFrame, STUTextFrameGetRange(textFrame),
                                                     CGPoint{}, params.displayScale(),
                                                     params.drawingOptions, cancellationFlag);
    const CGFloat tolerance = params.displayScale().inverseValue()/4;
    bounds = renderBoundsForTextFrameImageBounds(imageBounds, info, params.size(),
                                                 params.edgeInsets(), tolerance,
                                                 Out{mayBeClipped});
    if (mayBeClipped && !params.clipsContentToBounds) {
      mayBeClipped = false;
      // If the text only exceeds the bounds opposite the content aligment, we don't actually need
      // a sublayer, we could just use LabelRenderMode::image here. However, it's probably not
      // worth further complicating this logic.
      mode = LabelRenderMode::imageInSublayer;
      bounds = imageBounds;
    }
    if (params.drawingBlock) {
      const STULabelDrawingBounds drawingBounds = params.drawingBlockImageBounds;
      if (drawingBounds != STULabelTextImageBounds) {
        Rect<CGFloat> r;
        switch (drawingBounds) {
        case STULabelTextLayoutBounds:
          r = info.layoutBounds;
          break;
        case STULabelTextLayoutBoundsPlusInsets:
          r = info.layoutBounds.inset(-params.edgeInsets());
          break;
        case STULabelViewBounds:
          r = Rect{-frameOriginInLayer, params.size()};
          break;
        case STULabelTextImageBounds:
          __builtin_unreachable();
        }
        bounds = bounds.convexHull(r);
      }
    }
    bounds = ceilToScale(bounds, params.displayScale());
  }
  if (!useImageBounds || mode == LabelRenderMode::drawInCAContext) {
    bounds = Rect{-frameOriginInLayer, params.size()};
    if (!useImageBounds && params.clipsContentToBounds) {
      // If the bounds fully contain the layoutBounds we just assume that the text isn't clipped.
      // This is a performance optimization that avoids always having to redraw when the bounds
      // grow.
      mayBeClipped = !bounds.contains(info.layoutBounds);
    }
  }

  if (params.displayScale()*max(bounds.width(), bounds.height()) > maxImagePixelDimension) {
    if (params.clipsContentToBounds && useImageBounds && mode != LabelRenderMode::drawInCAContext) {
      const auto oldBounds = bounds;
      bounds.intersect(Rect{-frameOriginInLayer, params.size()});
      mayBeClipped = bounds != oldBounds;
    }
    mode = LabelRenderMode::tiledSublayer;
  }

  // Not using grayscale pixel formats when synchronously drawing into a CALayer context seems
  // to improve performance.
  bool isGrayscale = mode != LabelRenderMode::drawInCAContext
                  && !params.neverUseGrayscaleBitmapFormat
                  && !(frameFlags & STUTextFrameMayNotBeGrayscale)
                  && (!params.drawingBlock
                      || (params.drawingBlockColorOptions & STULabelDrawingBlockOnlyUsesTextColors));

  bool shouldDrawBackgroundColor = (params.backgroundColorFlags() & ColorFlags::isOpaque)
                                && (   mode == LabelRenderMode::drawInCAContext
                                    || (mode == LabelRenderMode::image && isGrayscale));

  const bool isIOS9 = NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_9_x_Max;

  const bool useExtendedColor =
               !isIOS9
               && (allowExtendedRGBBitmapFormat && !params.neverUsesExtendedRGBBitmapFormat)
               && ((frameFlags & STUTextUsesExtendedColor)
                   || ((params.drawingBlockColorOptions & STULabelDrawingBlockUsesExtendedColors)
                       && params.drawingBlock));

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

void drawLabelTextFrame(
       const STUTextFrame* __unsafe_unretained textFrame, STUTextFrameRange range,
       CGPoint textFrameOrigin, CGContextRef context, ContextBaseCTM_d contextBaseCTM_d,
       PixelAlignBaselines pixelAlignBaselines,
       const STUTextFrameDrawingOptions* __unsafe_unretained __nullable options,
       __unsafe_unretained __nullable STULabelDrawingBlock drawingBlock,
       const STUCancellationFlag* __nullable cancellationFlag)
{
  if (!context) return;
  if (!drawingBlock) {
    drawTextFrame(textFrame, range, textFrameOrigin, context, contextBaseCTM_d,
                  pixelAlignBaselines, options, cancellationFlag);
  } else {
    STU_DEBUG_ASSERT(!options || options->impl.isFrozen());
    STULabelDrawingBlockParameters* const p =
      createLabelDrawingBlockParametersInstance(
        // Pointer to non-const is an Obj-C convention.
        const_cast<STUTextFrame*>(textFrame), range, textFrameOrigin, context, contextBaseCTM_d,
        pixelAlignBaselines, const_cast<STUTextFrameDrawingOptions*>(options), cancellationFlag);
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
            drawLabelTextFrame(textFrame, STUTextFrameGetRange(textFrame),
                               -renderInfo.bounds.origin, context, ContextBaseCTM_d{1},
                               PixelAlignBaselines{true}, params.drawingOptions,
                               params.drawingBlock, cancellationFlag);
          }};
}

} // namespace stu_label

