// Copyright 2016–2018 Stephan Tolksdorf

#import "STULabel/STUImageUtils.h"

#import "DrawingContext.hpp"
#import "TextFrame.hpp"


namespace stu_label {

void TextFrame::draw(CGPoint origin,
                     CGContext* cgContext, ContextBaseCTM_d baseCTM_d,
                     PixelAlignBaselines pixelAlignBaselines,
                     Optional<const TextFrameDrawingOptions&> options,
                     const Optional<TextStyleOverride&> styleOverride,
                     const Optional<const STUCancellationFlag&> cancellationFlag) const
{
  if (this->textScaleFactor < 1) {
    CGContextSaveGState(cgContext);
    CGContextTranslateCTM(cgContext, origin.x, origin.y);
    origin = CGPoint{};
    CGContextScaleCTM(cgContext, this->textScaleFactor, this->textScaleFactor);
  }
  auto guard = ScopeGuard{[&] {
    if (this->textScaleFactor < 1) {
      CGContextRestoreGState(cgContext);
    }
  }};

  CGFloat scale = 0;
  Float64 ctmYOffset = 0;
  if (!pixelAlignBaselines) {
    if (baseCTM_d == 0) {
      baseCTM_d.value = 1;
    }
  } else {
    const CGAffineTransform m = CGContextGetCTM(cgContext);
    ctmYOffset = m.ty;
    scale = assumedScaleForCTM(m);
    if (scale > 0) {
      if (baseCTM_d == 0) {
        baseCTM_d.value = m.d < 0 ? -scale : scale;
      }
    } else {
      scale = 0;
      if (baseCTM_d == 0) {
        baseCTM_d.value = m.d < 0 ? -1 : 1;
      }
    }
  }

  CGContextSetTextDrawingMode(cgContext, kCGTextFill);

  DrawingContext context{[&]()-> DrawingContext {
    const Optional<DisplayScale> displayScale = DisplayScale::create(scale);
    // We outset the clip rect by 2*displayScale.inverseValue(), so that we can ignore the effects
    // of (repeated) display scale rounding when comparing bounds.
    Rect clipRect = CGContextGetClipBoundingBox(cgContext);
    if (displayScale) {
      clipRect = clipRect.outset(2*displayScale->inverseValue());
    }
    return {cancellationFlag, cgContext, baseCTM_d, displayScale, clipRect, ctmYOffset, origin,
            options, *this, styleOverride};
  }()};

  const STUTextFrameDrawingMode mode = options ? options->drawingMode()
                                     : STUTextFrameDefaultDrawingMode;
  const bool shouldDrawBackground = !(mode & STUTextFrameDrawOnlyForeground)
                                 && (   (flags & STUTextFrameHasBackground)
                                     || (styleOverride
                                         && (styleOverride->flags & TextFlags::hasBackground)));
  const bool shouldDrawForeground = !(mode & STUTextFrameDrawOnlyBackground);

  const Rect clipRect = context.clipRect();
  const Range<Int> clipLineRange = verticalSearchTable()
                                   .indexRange(narrow_cast<Range<Float32>>(clipRect.y - origin.y));

  if (shouldDrawBackground) {
    drawBackground(clipLineRange, context);
    if (context.isCancelled()) return;
  }

  if (!shouldDrawForeground) return;

  const bool needToDrawAttachments = (flags & STUTextFrameHasTextAttachment);
  if (needToDrawAttachments) {
    UIGraphicsPushContext(cgContext);
  }
  // line.drawLLO assumes a lower-left-origin coordinate system
  context.invertYAxis(); // Also inverts context.clipRect (but not the local copy `clipRect`).
  auto guard2 = ScopeGuard{[&] {
    context.setShadow(nullptr);
    context.invertYAxis();
    if (needToDrawAttachments) {
      UIGraphicsPopContext();
    }
  }};

  const Point<Float64> textFrameOrigin = origin;

  for (const TextFrameLine& line : this->lines()[clipLineRange]) {
    if (context.isCancelled()) break;

    Point<Float64> lineOrigin = textFrameOrigin + line.origin();
    if (context.displayScale()) {
      lineOrigin.y = ceilToScale(lineOrigin.y, *context.displayScale(), ctmYOffset);
    }
    const Point<CGFloat> cgLineOrigin = narrow_cast<Point<CGFloat>>(lineOrigin);

    if (!clipRect.overlaps(cgLineOrigin + line.fastBounds())) continue;

    if (const auto scope = context.enterLineDrawingScope(line)) {
      context.setLineOrigin({cgLineOrigin.x, -cgLineOrigin.y});
      line.drawLLO(context);
    }
  }
}

} // namespace stu_label




