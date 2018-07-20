// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "STULabel/STUTextAttachment-Internal.hpp"

#import "DrawingContext.hpp"
#import "DecorationLines.hpp"

#import "stu/ScopeGuard.hpp"

namespace stu_label {

static void drawRunGlyphsDirectly(GlyphSpan span, const TextStyle& style, DrawingContext& context) {
  const GlyphsWithPositions gwp = span.getGlyphsWithPositions();
  if (gwp.count() == 0) return;
  const FontRef font = span.run().font();
  const ColorIndex colorIndex = context.textColorIndex(style);
  context.setFillColor(colorIndex);
  const TextStyle::StrokeInfo* stroke = style.strokeInfo();
  const CGContextRef cgContext = context.cgContext();
  if (stroke) {
    const CGFloat lineWidth = stroke->strokeWidth*font.size();
    if (lineWidth > 0) {
      CGContextSetLineWidth(cgContext, lineWidth);
      const ColorIndex strokeColorIndex = stroke->colorIndex ? *stroke->colorIndex : colorIndex;
      context.setStrokeColor(strokeColorIndex);
      CGContextSetTextDrawingMode(cgContext, stroke->doNotFill ? kCGTextStroke : kCGTextFillStroke);
    } else {
      if (stroke->doNotFill) return;
      stroke = nil;
    }
  }
  CTFontDrawGlyphs(font.ctFont(), gwp.glyphs().begin(), gwp.positions().begin(),
                   sign_cast(gwp.count()), cgContext);
  if (stroke) {
    CGContextSetTextDrawingMode(cgContext, kCGTextFill);
  }
}


static void drawRunGlyphs(GlyphSpan glyphSpan, const TextStyle& style,
                          CGFloat ctLineXOffset, DrawingContext& context)
{
  CGAffineTransform matrix = glyphSpan.run().textMatrix();
  matrix.tx = context.lineOrigin().x + ctLineXOffset;
  matrix.ty = context.lineOrigin().y;
  CGContextSetTextMatrix(context.cgContext(), matrix);
  if (!context.needToDrawGlyphsDirectly(style)) {
    glyphSpan.draw(context.cgContext());
    context.currentCGContextColorsMayHaveChanged();
  } else {
    drawRunGlyphsDirectly(glyphSpan, style, context);
  }
}


static void drawGlyphs(const TextFrameLine& line, bool drawShadow, DrawingContext& context) {
  if (context.styleOverride() || (line.textFlags() & TextFlags::hasAttachment)) {
    line.forEachStyledGlyphSpan(context.styleOverride(),
      [&](const StyledGlyphSpan& span, const TextStyle& style, Range<Float64> x) -> ShouldStop
    {
      if (style.flags() & TextFlags::hasAttachment) {
        context.setShadow(drawShadow ? style.shadowInfo() : nil);
        // We don't apply any stroke style to the context. (Any objections?)
        drawAttachment(style.attachmentInfo()->attribute, narrow_cast<CGFloat>(x.start),
                       span.glyphSpan.count(), context);
        return ShouldStop{context.isCancelled()};
      }
      context.setShadow(drawShadow ? style.shadowInfo() : nil);
      const auto oldColorIndices = context.currentColorIndices();
      if (STU_UNLIKELY(span.isPartialLigature)) {
        Rect<CGFloat> clipRect = context.clipRect();
        if (span.leftEndOfLigatureIsClipped) {
          clipRect.x.start = narrow_cast<CGFloat>(context.lineOrigin().x + x.start);
        }
        if (span.rightEndOfLigatureIsClipped) {
          clipRect.x.end = narrow_cast<CGFloat>(context.lineOrigin().x + x.end);
        }
        CGContextSaveGState(context.cgContext());
        CGContextClipToRect(context.cgContext(), clipRect);
      }
      drawRunGlyphs(span.glyphSpan, style, span.ctLineXOffset, context);
      if (STU_UNLIKELY(span.isPartialLigature)) {
        CGContextRestoreGState(context.cgContext());
        context.restoreColorIndicesAfterCGContextRestoreGState(oldColorIndices);
      }
      return ShouldStop{context.isCancelled()};
    });
    return;
  }
  // When there's no style override, we want to delegate the drawing to CTLineDraw where possible.
  const TextFrame& textFrame = line.textFrame();
  const TextStyle* nonTokenStyle = &textFrame.firstNonTokenTextStyleForLineAtIndex(line.lineIndex);
  const TextStyle* tokenStyle = &textFrame.firstTokenTextStyleForLineAtIndex(line.lineIndex);
  line.forEachCTLineSegment(
    FlagsRequiringIndividualRunIteration{
      context.hasCancellationFlag() ? detail::everyRunFlag
      : context.textFlagsNecessitatingDirectGlyphDrawingOfNonHighlightedText()},
    [&](TextLinePart part, CTLineXOffset ctLineXOffset, CTLine& ctLine,
        Optional<GlyphSpan> optGlyphSpan) -> ShouldStop
  {
    if (!optGlyphSpan) {
      context.setShadow(nil);
      const CGContextRef cgContext = context.cgContext();
      CGContextSetTextMatrix(cgContext,
                             CGAffineTransform{.a = 1, .d = 1,
                                               .tx = context.lineOrigin().x + ctLineXOffset.value,
                                               .ty = context.lineOrigin().y});
      CTLineDraw(&ctLine, cgContext);
      context.currentCGContextColorsMayHaveChanged();
      return ShouldStop{context.isCancelled()};
    }
    const GlyphSpan glyphSpan = *optGlyphSpan;
    const CFRange range = CTRunGetStringRange(glyphSpan.run().ctRun());
    const TextStyle* style;
    if (part == TextLinePart::originalString) {
      nonTokenStyle = &nonTokenStyle->styleForStringIndex(narrow_cast<Int32>(range.location));
      style = nonTokenStyle;
    } else {
      if (part == TextLinePart::truncationToken) {
        tokenStyle = &tokenStyle->styleForStringIndex(narrow_cast<Int32>(range.location));
      } // We don't need to search for a hyphen token's style.
      style = tokenStyle;
    }
    context.setShadow(drawShadow ? style->shadowInfo() : nil);
    drawRunGlyphs(glyphSpan, *style, ctLineXOffset.value, context);
    return ShouldStop{context.isCancelled()};
  });
}

typedef enum : uint8_t {
  needNotDrawGlyphsShadow,
  canDrawGlyphsTogetherWithShadow,
  shouldDrawGlyphsShadowSeparately
} GlyphsShadowDrawingMode;

static GlyphsShadowDrawingMode determineShadowDrawingMode(
                                 const TextFrameLine& line,
                                 const Optional<TextStyleOverride&> styleOverride,
                                 const Optional<Rect<CGFloat>>& glyphBoundsLLO,
                                 const DrawingContext& context)
{
  Rect bounds = Rect<CGFloat>::infinitelyEmpty();
  bool shouldDrawShadowSeparately = false;
  line.forEachStyledStringRange(styleOverride,
    [&](const TextStyle& style, StyledStringRange) -> ShouldStop
  {
    const TextStyle::ShadowInfo* const shadow = style.shadowInfo();
    if (!shadow) return {};
    // Core Text draws stroked glyphs one by one left to right, which can lead to shadows
    // being drawn on top of glyphs if the shadow x-offset is negative. (When the text run with the
    // shadow isn't surrounded by enough whitespace, this could happen even if the run isn't
    // stroked, but this hopefully isn't much of a problem in practice, so we ignore this case in
    // the interest of performance.)
    // Another problem is that Core Graphics implements a fill & stroke call as two separate
    // operations as far as the shadow drawing is concerned, which can can lead to the shadow of
    // the stroke being drawn over the filled path, which probably is not what you want.
    const TextStyle::StrokeInfo* const stroke = style.strokeInfo();
    shouldDrawShadowSeparately |= stroke && (stroke->doNotFill == false
                                             || shadow->offsetX - shadow->blurRadius < 0);
    if (!glyphBoundsLLO) {
      return ShouldStop{shouldDrawShadowSeparately};
    }
    // We add the shadow to a zero rect and then add the glyph bounds afterwards.
    bounds = bounds.convexHull(Rect<CGFloat>{}.outset(shadow->blurRadius) + shadow->offset());
    return {};
  });
  if (glyphBoundsLLO) {
    bounds.y *= -1;
    bounds.x.start += glyphBoundsLLO->x.start;
    bounds.x.end   += glyphBoundsLLO->x.end;
    bounds.y.start += glyphBoundsLLO->y.start;
    bounds.y.end   += glyphBoundsLLO->y.end;
    if (!bounds.overlaps(context.clipRect())) {
      return needNotDrawGlyphsShadow;
    }
  }
  return shouldDrawShadowSeparately ? shouldDrawGlyphsShadowSeparately
                                    : canDrawGlyphsTogetherWithShadow;
}

void TextFrameLine::drawLLO(DrawingContext& context) const {
  const TextFlags flags = context.effectiveLineFlags();

  Optional<Rect<CGFloat>> glyphsBoundingRectLLO;
  if (!(flags & TextFlags::hasStroke)) {
    glyphsBoundingRectLLO = loadGlyphsBoundingRectLLO();
    if (glyphsBoundingRectLLO) {
      *glyphsBoundingRectLLO += context.lineOrigin();
    }
  }

  const GlyphsShadowDrawingMode glyphsDrawingMode =
    !(flags & TextFlags::hasShadow) ? needNotDrawGlyphsShadow
    : determineShadowDrawingMode(*this, context.styleOverride(), glyphsBoundingRectLLO, context);

  if (context.isCancelled()) return;

  const Optional<Underlines> underlines = flags & TextFlags::hasUnderline
                                        ? Underlines::find(*this, context)
                                        : Optional<Underlines>();

  if (context.isCancelled()) return;

  if (glyphsDrawingMode == shouldDrawGlyphsShadowSeparately) {
    DrawingContext::ShadowOnlyDrawingScope shadowOnlyScope{context};
    drawGlyphs(*this, true, context);
    if (context.isCancelled()) return;
  }

  if (glyphsDrawingMode == canDrawGlyphsTogetherWithShadow
      || !glyphsBoundingRectLLO
      || context.clipRect().overlaps(*glyphsBoundingRectLLO))
  {
    drawGlyphs(*this, glyphsDrawingMode == canDrawGlyphsTogetherWithShadow, context);
    if (context.isCancelled()) return;
  }
  if (underlines && !underlines->lines.isEmpty()) {
    underlines->draw(context);
    if (context.isCancelled()) return;
  }

  if (flags & TextFlags::hasStrikethrough) {
    const Strikethroughs strikes = Strikethroughs::find(*this, context);
    if (context.isCancelled()) return;
    if (!strikes.lines.isEmpty()) {
      strikes.draw(context);
    }
  }
}

} // namespace stu_label
