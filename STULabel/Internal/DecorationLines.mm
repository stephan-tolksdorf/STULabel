// Copyright 2017–2018 Stephan Tolksdorf

#import "DecorationLines.hpp"

#import "GlyphSpan.hpp"
#import "DrawingContext.hpp"
#import "GlyphPathIntersectionBounds.hpp"
#import "TextFrame.hpp"

namespace stu_label {

using OffsetAndThickness = DecorationLine::OffsetAndThickness;

static OffsetAndThickness roundOffsetAndThickness(OffsetAndThickness ot,
                                                  const DisplayScale& displayScale)
{
  const DisplayScale& displayScale1 = displayScale >= 1 ? displayScale
                                    : DisplayScale::one();
  ot.thickness = ceilToScale(ot.thickness, displayScale1);
  ot.offsetLLO = roundToScale(ot.offsetLLO, displayScale1);
  if (static_cast<Int>(nearbyint(ot.thickness*displayScale1)) & 1) {
    // The thickness in pixels is an odd number.
    ot.offsetLLO += displayScale1.inverseValue()/2;
  }
  return ot;
}

OffsetAndThickness
  OffsetAndThickness::forUnderline(const TextStyle::UnderlineInfo& info,
                                   const TextStyle::BaselineOffsetInfo* __nullable __unused,
                                   const CachedFontInfo& fontInfo,
                                   OptionalDisplayScaleRef displayScale)
{
  CGFloat offset    = info.originalFontUnderlineOffset;
  CGFloat thickness = info.originalFontUnderlineThickness;
  if (!fontInfo.shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont) {
    offset    = max(offset,    fontInfo.underlineOffset);
    thickness = max(thickness, fontInfo.underlineThickness);
  }
  const NSUnderlineStyle lineStyle = static_cast<NSUnderlineStyle>(info.style.value);
  switch (lineStyle & 0xf) {
  case NSUnderlineStyleDouble:
    thickness *= 0.75f;
    if (displayScale) {
      thickness = ceilToScale(thickness, *displayScale);
      offset = roundToScale(offset, *displayScale);
    }
    offset += thickness/2;
    thickness *= 3;
    return OffsetAndThickness{.offsetLLO = -offset, .thickness = thickness};
  case NSUnderlineStyleThick:
  case NSUnderlineStyleSingle | NSUnderlineStyleThick:
    offset += thickness/2;
    thickness *= 2;
    break;
  case NSUnderlineStyleDouble | NSUnderlineStyleThick:
    offset *= 1.5f;
    thickness *= 4.5f;
    break;
  default:
    break;
  }
  // We round before inverting the offset because the rounding does not take into account the sign
  // of the offset.
  OffsetAndThickness ot = {offset, thickness};
  if (displayScale) {
    ot = roundOffsetAndThickness(ot, *displayScale);
  }
  ot.offsetLLO = -ot.offsetLLO;
  // Since underlines are always drawn with descender gaps, adjusting the underline offset
  // by any non-zero baseline offset attribute seems unnecessary and undesirable (since one
  // typically doesn't want a separate underline for e.g. a superscript footnote index).
  return ot;
}

OffsetAndThickness
  OffsetAndThickness::forStrikethrough(
                        const TextStyle::StrikethroughInfo& info,
                        const TextStyle::BaselineOffsetInfo* __nullable optBaselineOffset,
                        const CachedFontInfo& fontInfo,
                        OptionalDisplayScaleRef displayScale)
{
  const NSUnderlineStyle lineStyle = static_cast<NSUnderlineStyle>(info.style.value);
  OffsetAndThickness ot;
  ot.offsetLLO = fontInfo.xHeight/2;
  ot.thickness = info.originalFontStrikethroughThickness;
  if (!fontInfo.shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont) {
    ot.thickness = max(ot.thickness, fontInfo.strikethroughThickness);
  }
  if (lineStyle & NSUnderlineStyleThick) {
    ot.thickness *= 3;
  }
  if (displayScale) {
    ot = roundOffsetAndThickness(ot, *displayScale);
  }
  if ((lineStyle & NSUnderlineStyleDouble) == NSUnderlineStyleDouble) {
    ot.thickness *= 3;
  }
  if (optBaselineOffset) {
    // In contrast to underlines, we do adjust the strikethrough offset by the baseline offset.
    // TODO: Make this configurable (e.g. by introducing a new string attribute).
    ot.offsetLLO += optBaselineOffset->baselineOffset;
  }
  return ot;
}

/// Assumes an LLO coordinate system, with the baseline at y = 0.
static void findXBoundsOfIntersectionsOfGlyphsWithHorizontalLine(
              CGFloat runXOffset, GlyphSpan span,
              CGFloat minY, CGFloat maxY, CGFloat dilation,
              OptionalDisplayScaleRef displayScale __unused,
              SortedIntervalBuffer<CGFloat>& buffer,
              Optional<SortedIntervalBuffer<CGFloat>&> upperStripeBuffer)
{
  CGFloat lowerStripeMaxY;
  CGFloat upperStripeMinY;
  // Currently we don't enforce any minimal free space above and below the horizontal lines.
  if (!upperStripeBuffer) {
    lowerStripeMaxY = maxY;
    upperStripeMinY = minY;
  } else {
    const CGFloat oneThird = 1/(CGFloat)3;
    CGFloat h = (maxY - minY)*oneThird;
    lowerStripeMaxY = minY + h;
    upperStripeMinY = maxY - h;
  }
  const CTFont* const font = span.run().font();
  const CGAffineTransform textMatrix = span.run().textMatrix();
  const bool hasNonIdentityMatrix = span.run().status() & kCTRunStatusHasNonIdentityMatrix;
  const GlyphsWithPositions gwp = span.getGlyphsWithPositions();
  for (Int i = 0; i < gwp.count(); ++i) {
    CGRect bounds;
    CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal,
                                    &gwp.glyphs()[i], &bounds, 1);
    CGPoint position = gwp.positions()[i];
    bounds.origin.x += position.x + runXOffset;
    bounds.origin.y += position.y;
    if (hasNonIdentityMatrix) {
      bounds = CGRectApplyAffineTransform(bounds, textMatrix);
    }
    if (bounds.size.height <= 0) continue;
    if (bounds.origin.y >= maxY || bounds.origin.y + bounds.size.height <= minY) continue;
    CGAffineTransform matrix = textMatrix;
    matrix.tx = position.x + runXOffset;
    matrix.ty = position.y;
    const CGPathRef path = CTFontCreatePathForGlyph(font, gwp.glyphs()[i], &matrix);
    if (!path) continue;
    const LowerAndUpperInterval xis = findXBoundsOfPathIntersectionWithHorizontalLines(
                                        path, Range<CGFloat>{minY, lowerStripeMaxY},
                                        Range<CGFloat>{upperStripeMinY, maxY}, 0.25);
    if (xis.lower.start <= xis.lower.end) {
      buffer.add({xis.lower.start - dilation, xis.lower.end + dilation});
    }
    if (upperStripeBuffer && xis.upper.start <= xis.upper.end) {
      upperStripeBuffer->add({xis.upper.start - dilation, xis.upper.end + dilation});
    }
    CFRelease(path);
  }
}

static void removeLinePartsNotIntersectingClipRectAndMergeIdenticallyStyledAdjacentUnderlines(
              TempVector<DecorationLine>& buffer, const Rect<CGFloat>& clipRect)
{
  DecorationLine* previous = nullptr;
  DecorationLine* end = nullptr;
  for (DecorationLine& u : buffer) {
    const auto rect = u.rectLLO();
    bool remove = !rect.overlaps(clipRect) && !rectShadowOverlapsRect(rect, u.shadowInfo, clipRect);
    if (previous) {
      if (!remove) {
        if (u.isUnderlineContinuation
            && previous->colorIndex == u.colorIndex
            && (previous->shadowInfo == u.shadowInfo
                || (previous->shadowInfo && u.shadowInfo
                     && *previous->shadowInfo == *u.shadowInfo)))
        {
          previous->x.end = u.x.end;
          remove = true;
        }
      } else { // remove
        previous->hasUnderlineContinuation = false;
        previous = nullptr;
      }
    } else { // The previous line part may have been removed.
      u.isUnderlineContinuation = false;
    }
    if (!remove) {
      if (!end) {
        previous = &u;
      } else {
        *end = u;
        previous = end;
        ++end;
      }
    } else { // remove
      if (!end) {
        end = &u;
      }
    }
  }
  if (end) {
    if (previous) {
      previous->hasUnderlineContinuation = false;
    }
    buffer.removeLast(buffer.end() - end);
  }
}

Underlines Underlines::find(const TextFrameLine& line, DrawingContext& context) {
  bool hasShadow = false;
  bool hasDoubleLine = false;
  TempArray<DecorationLine> lines;
  {
    TempVector<DecorationLine> buffer{MaxInitialCapacity{128}};
    const TextStyle* previousTextStyle = nil;
    CTFont* previousFont = nil;
    line.forEachStyledGlyphSpan(TextFlags::hasUnderline, context.styleOverride(),
      [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x_f64)
      -> ShouldStop
    {
      const Range<CGFloat> x = narrow_cast<Range<CGFloat>>(x_f64);
      CTFont* const font = span.glyphSpan.run().font();
      if (!x.isEmpty() && font) {
        const TextStyle::UnderlineInfo& info = *style.underlineInfo();
        const NSUnderlineStyle lineStyle = static_cast<NSUnderlineStyle>(info.style);
        DecorationLine* const previous = !buffer.isEmpty() ? &buffer[$ - 1] : nil;
        OffsetAndThickness ot = previous && previousTextStyle == &style && !style.isOverrideStyle()
                                         && previousFont == font
                              ? previous->offsetAndThickness()
                              : OffsetAndThickness::forUnderline(info, style.baselineOffsetInfo(),
                                                                 context.fontInfo(font),
                                                                 context.displayScale());
        const bool isContinuation = previous && previous->x.end == x.start
                                             && previous->style == lineStyle;
        if (isContinuation) {
          previous->hasUnderlineContinuation = true;
          ot.offsetLLO = max(ot.offsetLLO, previous->offsetLLO);
          ot.thickness = max(ot.thickness, previous->thickness);
        }
        buffer.append(DecorationLine{.x = x, .offsetLLO = ot.offsetLLO,
                                     .style = lineStyle, .thickness = ot.thickness,
                                     .colorIndex = info.colorIndex ? *info.colorIndex
                                                   : context.textColorIndex(style),
                                     .isUnderlineContinuation = isContinuation,
                                     .shadowInfo = style.shadowInfo()});
        previousFont = font;
        previousTextStyle = &style;
      }
      return ShouldStop{context.isCancelled()};
    });
    if (!context.isCancelled()) {
      // Propagate the maximum offset and thickness back through continued underlines
      // and determine hasDoubleLine and hasShadow.
      OffsetAndThickness ot;
      for (DecorationLine& u : buffer.reversed()) {
        hasDoubleLine |= (u.style & NSUnderlineStyleDouble) == NSUnderlineStyleDouble;
        hasShadow |= u.shadowInfo != nullptr;
        if (u.hasUnderlineContinuation) {
          u.offsetLLO = ot.offsetLLO;
          u.thickness = ot.thickness;
        } else if (u.isUnderlineContinuation) {
          ot = u.offsetAndThickness();
        }
      }
    }
    removeLinePartsNotIntersectingClipRectAndMergeIdenticallyStyledAdjacentUnderlines(
      buffer, context.clipRect() - context.lineOrigin());
    lines = std::move(buffer);
  }

  // Calculate descender gaps.
  TempArray<Range<CGFloat>> lowerLinesGaps;
  TempArray<Range<CGFloat>> upperLinesGaps;
  if (lines.count() != 0 && !context.isCancelled()) {
    Int index = 0;
    SortedIntervalBuffer<CGFloat> buffer{MaxInitialCapacity{256}};
    if (hasDoubleLine) {
      buffer.setCapacity(buffer.capacity()/2);
    }
    SortedIntervalBuffer<CGFloat> buffer2{MaxInitialCapacity{buffer.capacity() + 1}};
    line.forEachStyledGlyphSpan(TextFlags::hasUnderline, context.styleOverride(),
      [&](const StyledGlyphSpan& span, const TextStyle& __unused style,
          Range<Float64> x_f64) -> ShouldStop
    {
      if (!lines.isValidIndex(index)) return {};
      const Range<CGFloat> x = narrow_cast<Range<CGFloat>>(x_f64);
      if (x.isEmpty()) return {};
      if (x.start >= lines[index].x.end) {
        ++index;
        if (!lines.isValidIndex(index)) return {};
      }
      const DecorationLine& u = lines[index];
      if (x.end <= u.x.start) return {};

      CGFloat dilation = u.thickness;
      const bool isDoubleLine = (u.style & NSUnderlineStyleDouble) == NSUnderlineStyleDouble;
      if (isDoubleLine) {
        dilation /= 3;
      } else if (u.style & NSUnderlineStyleThick) {
        dilation /= 1.5f;
      }
      // To simplify things, we only detect intersections of the underlined glyphs with the
      // underline and ignore adjacent non-underlined glyphs that might protrude (especially when
      // taking into account the dilation) beyond their horizontal typographic bounds.
      // Since underlines are usually word-aligned, this shouldn't be a problem in practice.
      findXBoundsOfIntersectionsOfGlyphsWithHorizontalLine(
        span.ctLineXOffset, span.glyphSpan,
        u.offsetLLO - u.thickness/2, u.offsetLLO + u.thickness/2, dilation,
        context.displayScale(),
        buffer, isDoubleLine ? Optional<SortedIntervalBuffer<CGFloat>&>(buffer2) : none);
    
      return ShouldStop{context.isCancelled()};
    });
    // The order of the following operations should be the reverse of the declaration order
    // (to improve reuse of TempAllocator memory).
    upperLinesGaps = std::move(buffer2);
    lowerLinesGaps = std::move(buffer);
  }
  return {.lines = std::move(lines),
          .lowerLinesGaps = std::move(lowerLinesGaps),
          .upperLinesGaps = std::move(upperLinesGaps),
          .hasShadow = hasShadow,
          .hasDoubleLine = hasDoubleLine};
}

Strikethroughs Strikethroughs::find(const TextFrameLine& line, DrawingContext& context) {
  TempVector<DecorationLine> buffer{MaxInitialCapacity{64}};
  bool hasShadow = false;
  const TextStyle* previousTextStyle = nil;
  CTFont* previousFont = nil;
  line.forEachStyledGlyphSpan(TextFlags::hasStrikethrough, context.styleOverride(),
    [&](const StyledGlyphSpan& span, const TextStyle& style, Range<Float64> x_f64) -> ShouldStop
  {
    const Range<CGFloat> x = narrow_cast<Range<CGFloat>>(x_f64);
    if (x.isEmpty()) return {};
    CTFont* const font = span.glyphSpan.run().font();
    if (!font) return {};
    DecorationLine* previous = !buffer.isEmpty() ? &buffer[$ - 1] : nil;
    if (previous && previous->x.end == x.start
                 && &style == previousTextStyle && !style.isOverrideStyle()
                 && font == previousFont)
    {
      previous->x.end = x.end;
      return {};
    }
    const TextStyle::StrikethroughInfo& info = *style.strikethroughInfo();
    const TextStyle::ShadowInfo* const shadowInfo = style.shadowInfo();
    hasShadow |= shadowInfo != nil;
    const NSUnderlineStyle lineStyle = static_cast<NSUnderlineStyle>(info.style);
    const auto ot = OffsetAndThickness::forStrikethrough(info, style.baselineOffsetInfo(),
                                                         context.fontInfo(font),
                                                         context.displayScale());
    const ColorIndex colorIndex = info.colorIndex ? *info.colorIndex
                                : context.textColorIndex(style);
    if (previous && previous->x.end == x.start
        && previous->offsetLLO == ot.offsetLLO && previous->thickness == ot.thickness
        && previous->style == lineStyle && previous->colorIndex == colorIndex
        && (previous->shadowInfo == shadowInfo
            || (previous->shadowInfo && shadowInfo && *previous->shadowInfo == *shadowInfo)))
    {
      previous->x.end = x.end;
    } else {
      buffer.append(DecorationLine{.x = x, .offsetLLO = ot.offsetLLO, .thickness = ot.thickness,
                                   .style = lineStyle,
                                   .colorIndex = colorIndex, .shadowInfo = shadowInfo});
    }
    previousFont = font;
    previousTextStyle = &style;
    return ShouldStop{context.isCancelled()};
  });
  return Strikethroughs{.lines = std::move(buffer), .hasShadow = hasShadow};
}

enum class DoubleLineStripe {
  upper,
  lower,
  both
};

struct DrawShadow : Parameter<DrawShadow> { using Parameter::Parameter; };

static void drawDecorationLine(const DecorationLine& line, Range<CGFloat> x, CGFloat phase,
                               DoubleLineStripe stripes, DrawShadow drawShadow,
                               DrawingContext& context)
{
  if (context.displayScale() && x.end - x.start < context.displayScale()->inverseValue()) {
    return;
  }
  x += context.lineOrigin().x;
  CGFloat y = context.lineOrigin().y + line.offsetLLO;
  const NSUnderlineStyle style = line.style;
  CGFloat thickness = line.thickness;
  const bool isDouble = (style & NSUnderlineStyleDouble) == NSUnderlineStyleDouble;
  if (isDouble) {
    thickness /= 3;
    if (stripes != DoubleLineStripe::lower) {
      y += thickness;
    } else {
      y -= thickness;
    }
  }
  const CGContextRef cgContext = context.cgContext();
  context.setShadow(drawShadow ? line.shadowInfo : nil);
  const uint32_t pattern = style & 0x700;
  if (pattern == 0 && context.displayScale()) { // An optimization for the common case.
    context.setFillColor(line.colorIndex);
    const Range<CGFloat> t{-thickness/2, thickness/2};
    CGContextFillRect(context.cgContext(), Rect{x, y + t});
    if (isDouble && stripes == DoubleLineStripe::both) {
      y -= 2*thickness;
      CGContextFillRect(context.cgContext(), Rect{x, y + t});
    }
    return;
  }
  CGContextSetLineWidth(cgContext, thickness);
  context.setStrokeColor(line.colorIndex);
  if (pattern) {
    const bool isThick = line.style & NSUnderlineStyleThick;
    const CGFloat t = thickness*(isThick ? 0.5f : 1);
    CGFloat lengths[6];
    size_t count;
    switch (pattern) {
    case NSUnderlinePatternDot:
      lengths[0] = t*3;
      lengths[1] = lengths[0];
      count = 2;
      break;
    case NSUnderlinePatternDash:
      lengths[0] = t*10;
      lengths[1] = t*5;
      count = 2;
      break;
    case NSUnderlinePatternDashDot:
    case NSUnderlinePatternDashDotDot:
      lengths[0] = t*10;
      lengths[1] = t*3;
      lengths[2] = lengths[1];
      lengths[3] = lengths[1];
      lengths[4] = lengths[1];
      lengths[5] = lengths[1];
      count = pattern == NSUnderlinePatternDashDot ? 4 : 6;
      break;
    default:
      count = 0;
    }
    CGContextSetLineDash(cgContext, phase, lengths, count);
  }
  CGContextMoveToPoint(cgContext, x.start, y);
  CGContextAddLineToPoint(cgContext, x.end, y);
  CGContextStrokePath(cgContext);
  if (isDouble && stripes == DoubleLineStripe::both) {
    y -= 2*thickness;
    CGContextMoveToPoint(cgContext, x.start, y);
    CGContextAddLineToPoint(cgContext, x.end, y);
    CGContextStrokePath(cgContext);
  }
  if (pattern) {
    CGContextSetLineDash(cgContext, 0, nil, 0);
  }
}

STU_INLINE
void drawDecorationLines(ArrayRef<const DecorationLine> lines,
                         DrawShadow drawShadow, DrawingContext& context)
{
  for (const DecorationLine& line : lines) {
    if (drawShadow && !line.shadowInfo) continue;
    drawDecorationLine(line, line.x, 0, DoubleLineStripe::both, drawShadow, context);
    if (context.isCancelled()) return;
  }
}

static void drawDecorationLinesWithGaps(ArrayRef<const DecorationLine> lines,
                                        DoubleLineStripe stripe,
                                        ArrayRef<const Range<CGFloat>> gaps,
                                        DrawShadow drawShadow,
                                        DrawingContext& context)
{
  Range<CGFloat> gap = {minValue<CGFloat>, minValue<CGFloat>};
  Int j = -1;
  for (const DecorationLine& line : lines) {
    if (   (drawShadow && !line.shadowInfo)
        || (stripe == DoubleLineStripe::upper
            && (line.style & NSUnderlineStyleDouble) != NSUnderlineStyleDouble))
    {
      continue;
    }
    const CGFloat end = line.x.end;
    CGFloat start = line.x.start;
    for (;;) {
      if (start < gap.start) {
        drawDecorationLine(line, {start, min(end, gap.start)}, start - line.x.start,
                           stripe, drawShadow, context);
        if (context.isCancelled()) return;
      }
      if (gap.end >= end) break;
      start = max(start, gap.end);
      if (++j < gaps.count()) {
        gap = gaps[j];
      } else {
        gap = Range{maxValue<CGFloat>, maxValue<CGFloat>};
      }
    }
  }
}

void Underlines::draw(DrawingContext& context) const {
  if (hasShadow) {
    DrawingContext::ShadowOnlyDrawingScope shadowOnlyScope{context};
    if (hasDoubleLine) {
      drawDecorationLinesWithGaps(lines, DoubleLineStripe::upper, upperLinesGaps,
                                  DrawShadow{true}, context);
      if (context.isCancelled()) return;
    }
    drawDecorationLinesWithGaps(lines, DoubleLineStripe::lower, lowerLinesGaps,
                                DrawShadow{true}, context);
    if (context.isCancelled()) return;
  }
  if (hasDoubleLine) {
    drawDecorationLinesWithGaps(lines, DoubleLineStripe::upper, upperLinesGaps,
                                DrawShadow{false}, context);
    if (context.isCancelled()) return;
  }
  drawDecorationLinesWithGaps(lines, DoubleLineStripe::lower, lowerLinesGaps,
                              DrawShadow{false}, context);
}

void Strikethroughs::draw(DrawingContext& context) const {
  if (hasShadow) {
    {
      DrawingContext::ShadowOnlyDrawingScope shadowOnlyScope{context};
      drawDecorationLines(lines, DrawShadow{true}, context);
    }
    if (context.isCancelled()) return;
  }
  drawDecorationLines(lines, DrawShadow{false}, context);
}

} // namespace stu_label
