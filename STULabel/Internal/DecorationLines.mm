// Copyright 2017–2018 Stephan Tolksdorf

#import "DecorationLines.hpp"

#import "GlyphSpan.hpp"
#import "DrawingContext.hpp"
#import "GlyphPathIntersectionBounds.hpp"
#import "TextFrame.hpp"

namespace stu_label {

using OffsetAndThickness = DecorationLine::OffsetAndThickness;

/// Assumes offset to be non-negative.
static OffsetAndThickness roundOffsetAndThickness(CGFloat offset, CGFloat thickness,
                                                  const DisplayScale& displayScale)
{
  const DisplayScale& displayScale1 = displayScale >= 1 ? displayScale
                                    : DisplayScale::one();
  const CGFloat unroundedThickness = thickness;
  thickness = ceilToScale(thickness, displayScale1);
  offset = roundToScale(offset, displayScale1);
  if (static_cast<Int>(nearbyint(thickness*displayScale1)) & 1) {
    // The thickness in pixels is an odd number.
    offset += displayScale1.inverseValue()/2;
  }
  return {.offsetLLO = offset, .thickness = thickness, .unroundedThickness = unroundedThickness};
}

/// Assumes the offset to be non-negative.
static OffsetAndThickness adjustUnderlineOffsetAndThickness(CGFloat offset, CGFloat thickness,
                                                            NSUnderlineStyle style,
                                                            OptionalDisplayScaleRef displayScale)
{
  switch (style & 0xf) {
  case NSUnderlineStyleDouble: {
    thickness *= 0.75f;
    CGFloat unroundedThickness = thickness;
    if (displayScale) {
      thickness = ceilToScale(thickness, *displayScale);
      offset = roundToScale(offset, *displayScale);
    }
    offset += thickness/2;
    thickness *= 3;
    unroundedThickness *= 3;
    return {.offsetLLO = -offset, .thickness = thickness, .unroundedThickness = unroundedThickness};
  }
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
  OffsetAndThickness ot = displayScale
                        ? roundOffsetAndThickness(offset, thickness, *displayScale)
                        : OffsetAndThickness{.offsetLLO = offset, .thickness = thickness,
                                             .unroundedThickness = thickness};
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
  CGFloat offset = fontInfo.xHeight/2;
  CGFloat thickness = info.originalFontStrikethroughThickness;
  if (!fontInfo.shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont) {
    thickness = max(thickness, fontInfo.strikethroughThickness);
  }
  if (lineStyle & NSUnderlineStyleThick) {
    thickness *= 3;
  }
  CGFloat unroundedThickness = thickness;
  if (displayScale) {
    const auto ot = roundOffsetAndThickness(offset, thickness, *displayScale);
    offset = ot.offsetLLO;
    thickness = ot.thickness;
  }
  if ((lineStyle & NSUnderlineStyleDouble) == NSUnderlineStyleDouble) {
    thickness *= 3;
    unroundedThickness *= 3;
  }
  if (optBaselineOffset) {
    // In contrast to underlines, we do adjust the strikethrough offset by the baseline offset.
    // TODO: Make this configurable (e.g. by introducing a new string attribute).
    offset += optBaselineOffset->baselineOffset;
  }
  return {.offsetLLO = offset, .thickness = thickness, .unroundedThickness = unroundedThickness};
}

/// Assumes an LLO coordinate system, with the baseline at y = 0.
static void findXBoundsOfIntersectionsOfGlyphsWithHorizontalLine(
              CGFloat runXOffset, GlyphSpan span,
              CGFloat minY, CGFloat maxY, CGFloat dilation,
              OptionalDisplayScaleRef displayScale,
              LocalGlyphBoundsCache& localGlyphBoundsCache,
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
  const FontFaceGlyphBoundsCache::Ref boundsCache = localGlyphBoundsCache.glyphBoundsCache(font);
  const GlyphsWithPositions gwp = span.getGlyphsWithPositions();

  const auto dilateAndRoundGap = [&](Range<CGFloat> xi) STU_INLINE_LAMBDA -> Range<CGFloat> {
    CGFloat start = xi.start - dilation;
    const CGFloat end = xi.end + dilation;
    if (displayScale) {
      // The horizontal subpixel placement of rasterized glyphs seems left-biased.
      // Rounding the left bound of the descender gap downwards counters this effect.
      const CGFloat f = floorToScale(start, *displayScale);
      if (f + displayScale->inverseValue()*(3/4.f) > start) {
        start = f;
      }
    }
    return {start, end};
  };

  for (Int i = 0; i < gwp.count(); ++i) {
    CGPoint position = gwp.positions()[i];
    position.x += runXOffset;
    Rect<CGFloat> bounds = boundsCache.boundingRect(gwp.glyphs()[i], position);
    if (bounds.isEmpty()) continue;
    if (hasNonIdentityMatrix) {
      bounds = CGRectApplyAffineTransform(bounds, textMatrix);
    }
    if (!bounds.y.overlaps(Range{minY, maxY})) continue;
    CGAffineTransform matrix = textMatrix;
    matrix.tx = position.x;
    matrix.ty = position.y;
    const CGPathRef path = CTFontCreatePathForGlyph(font, gwp.glyphs()[i], &matrix);
    if (!path) continue;
    const LowerAndUpperInterval xis = findXBoundsOfPathIntersectionWithHorizontalLines(
                                        path, Range<CGFloat>{minY, lowerStripeMaxY},
                                        Range<CGFloat>{upperStripeMinY, maxY}, 0.25);
    if (xis.lower.start <= xis.lower.end) {
      buffer.add(dilateAndRoundGap(xis.lower));
    }
    if (upperStripeBuffer && xis.upper.start <= xis.upper.end) {
      upperStripeBuffer->add(dilateAndRoundGap(xis.upper));
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
    TempVector<DecorationLine> buffer{MaxInitialCapacity{128}, lines.allocator()};
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
        CGFloat offset;
        CGFloat thickness;
        if (previous && previousTextStyle == &style && !style.isOverrideStyle()
            && previousFont == font)
        {
          offset    = previous->offsetLLO;
          thickness = previous->thickness;
        } else {
          offset    = info.originalFontUnderlineOffset;
          thickness = info.originalFontUnderlineThickness;
          const CachedFontInfo& fontInfo = context.fontInfo(font);
          if (!fontInfo.shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont) {
            offset    = max(offset,    fontInfo.underlineOffset);
            thickness = max(thickness, fontInfo.underlineThickness);
          }
        }
        const bool isContinuation = previous && previous->x.end == x.start
                                             && previous->style == lineStyle;
        CGFloat fullLineXStart = x.start;
        if (isContinuation) {
          fullLineXStart = previous->fullLineXStart;
          previous->hasUnderlineContinuation = true;
          offset    = max(offset, previous->offsetLLO);
          thickness = max(thickness, previous->thickness);
        }
        // Below we'll adjust the offset and thickness again when we iterate backwards over the
        // decoration lines.
        buffer.append(DecorationLine{.x = x, .fullLineXStart = fullLineXStart,
                                     .offsetLLO = offset, .thickness = thickness,
                                     .style = lineStyle,
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
      // Adjust the offset and thickness, invert the offset sign, propagate the maximum offset and
      // thickness back through continued underlines, and determine hasDoubleLine and hasShadow.
      CGFloat offset = 0;
      CGFloat thickness = 0;
      CGFloat unroundedThickness = 0;
      for (DecorationLine& u : buffer.reversed()) {
        hasDoubleLine |= (u.style & NSUnderlineStyleDouble) == NSUnderlineStyleDouble;
        hasShadow |= u.shadowInfo != nullptr;
        if (!u.hasUnderlineContinuation) {
          // This also inverts the sign off the offset.
          const auto ot = adjustUnderlineOffsetAndThickness(u.offsetLLO, u.thickness, u.style,
                                                            context.displayScale());
          offset = ot.offsetLLO;
          thickness = ot.thickness;
          unroundedThickness = ot.unroundedThickness;
        }
        u.offsetLLO = offset;
        u.thickness = thickness;
        u.unroundedThickness = unroundedThickness;
      }
    }
    removeLinePartsNotIntersectingClipRectAndMergeIdenticallyStyledAdjacentUnderlines(
      buffer, context.clipRect() - context.lineOrigin());
    lines = std::move(buffer);
  }

  // Calculate descender gaps.
  TempArray<Range<CGFloat>> lowerLinesGaps{lines.allocator()};
  TempArray<Range<CGFloat>> upperLinesGaps{lines.allocator()};
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
        context.displayScale(), context.glyphBoundsCache(),
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

Rect<Float64> Underlines::imageBoundsLLO(const TextFrameLine& line,
                                         Optional<TextStyleOverride&> styleOverride,
                                         const Optional<DisplayScale>& displayScale,
                                         LocalFontInfoCache& fontInfoCache)
{
  Rect<Float64> bounds = Rect<Float64>::infinitelyEmpty();

  const TextStyle* previousStyle = nullptr;
  CTFont* previousFont = nullptr;
  Float64 previousXEnd = -infinity<Float64>;
  NSUnderlineStyle previousUnderlineStyle;
  CGFloat previousOffset;
  CGFloat previousThickness;
  bool previousHasShadow = false;
  Range<Float32> previousShadowOffsetY;
  Float32 previousShadowBlurRadius;

  const auto enlargeYBoundsForPreviousUnderline = [&] {
    if (previousStyle) {
      const Range<CGFloat> y = adjustUnderlineOffsetAndThickness(
                                 previousOffset, previousThickness, previousUnderlineStyle,
                                 displayScale).yLLO();
      bounds.y = bounds.y.convexHull(y);
      if (previousHasShadow) {
        Range<CGFloat> shadowY = y;
        shadowY.start += previousShadowOffsetY.start - previousShadowBlurRadius;
        shadowY.end   += previousShadowOffsetY.end   + previousShadowBlurRadius;
        bounds.y = bounds.y.convexHull(shadowY);
      }
    }
  };

  line.forEachStyledGlyphSpan(TextFlags::hasUnderline, styleOverride,
      [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x)
  {
    CTFont* const font = span.glyphSpan.run().font();
    if (x.isEmpty() || !font) return;
    bounds.x = bounds.x.convexHull(x);
    const TextStyle::UnderlineInfo& info = *style.underlineInfo();
    const NSUnderlineStyle underlineStyle = static_cast<NSUnderlineStyle>(info.style);
    CGFloat offset;
    CGFloat thickness;
    if (previousStyle == &style && !style.isOverrideStyle() && previousFont == font) {
      offset    = previousOffset;
      thickness = previousThickness;
    } else {
      offset    = info.originalFontUnderlineOffset;
      thickness = info.originalFontUnderlineThickness;
      const CachedFontInfo& fontInfo = fontInfoCache[font];
      if (!fontInfo.shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont) {
        offset    = max(offset,    fontInfo.underlineOffset);
        thickness = max(thickness, fontInfo.underlineThickness);
      }
    }
    if (previousXEnd == x.start && previousUnderlineStyle == underlineStyle) {
      previousOffset    = max(offset, previousOffset);
      previousThickness = max(thickness, previousThickness);
    } else {
      enlargeYBoundsForPreviousUnderline();
      previousOffset    = offset;
      previousThickness = thickness;
      previousHasShadow = false;
    }
    if (const auto shadowInfo = style.shadowInfo(); STU_UNLIKELY(shadowInfo)) {
      bounds.x = bounds.x.convexHull((x + shadowInfo->offsetX).outsetBy(shadowInfo->blurRadius));
      const auto shadowY = -shadowInfo->offsetY + Range<Float32>{};
      const auto shadowBlurRadius = shadowInfo->blurRadius;
      if (!previousHasShadow) {
        previousHasShadow = true;
        previousShadowOffsetY = shadowY;
        previousShadowBlurRadius = shadowBlurRadius;
      } else {
        previousShadowOffsetY = previousShadowOffsetY.convexHull(shadowY);
        previousShadowBlurRadius = max(previousShadowBlurRadius, shadowBlurRadius);
      }
    }
    previousStyle = &style;
    previousFont = font;
    previousXEnd = x.end;
    previousUnderlineStyle = underlineStyle;
  });
  enlargeYBoundsForPreviousUnderline();
  return bounds;
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
        && previous->offsetLLO == ot.offsetLLO
        && previous->unroundedThickness == ot.unroundedThickness
        && previous->style == lineStyle && previous->colorIndex == colorIndex
        && (previous->shadowInfo == shadowInfo
            || (previous->shadowInfo && shadowInfo && *previous->shadowInfo == *shadowInfo)))
    {
      previous->x.end = x.end;
    } else {
      buffer.append(DecorationLine{.x = x, .fullLineXStart = x.start,
                                   .offsetLLO = ot.offsetLLO, .thickness = ot.thickness,
                                   .unroundedThickness = ot.unroundedThickness,
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

static void drawDecorationLine(const DecorationLine& line, Range<CGFloat> x,
                               DoubleLineStripe stripes, DrawShadow drawShadow,
                               DrawingContext& context)
{
  if (context.displayScale() && x.end - x.start < context.displayScale()->inverseValue()) {
    return;
  }
  const CGFloat patternOffset = x.start - line.fullLineXStart;
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
    // We use the unrounded thickness here because we don't want the pattern to noticeably change
    // for different display scales, even for long lines.
    CGFloat t = line.unroundedThickness;
    if (isDouble) {
      t /= 3;
    }
    if (line.style & NSUnderlineStyleThick) {
      t *= 0.5;
    }
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
    CGContextSetLineDash(cgContext, patternOffset, lengths, count);
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
    drawDecorationLine(line, line.x, DoubleLineStripe::both, drawShadow, context);
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
        drawDecorationLine(line, {start, min(end, gap.start)}, stripe, drawShadow, context);
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

void Underlines::drawLLO(DrawingContext& context) const {
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

void Strikethroughs::drawLLO(DrawingContext& context) const {
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
