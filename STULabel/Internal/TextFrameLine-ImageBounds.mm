// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "STULabel/STUTextAttributes-Internal.hpp"

#import "DecorationLines.hpp"

#import <stdatomic.h>

namespace stu_label {

STU_INLINE
Rect<Float64> boundsEnlargedByStroke(Rect<Float64> bounds, const Float64 strokeWidth) {
  return bounds.isEmpty() ? bounds : bounds.outset(strokeWidth/2);
}

STU_INLINE
Rect<Float64> boundsEnlargedByStroke(Rect<Float64> bounds, const TextStyle::StrokeInfo& strokeInfo) {
 return boundsEnlargedByStroke(bounds, strokeInfo.strokeWidth);
}

STU_INLINE
Rect<Float64> lloBoundsEnlargedByShadow(Rect<Float64> bounds, const TextStyle::ShadowInfo& s) {
  if (!bounds.isEmpty()) {
    bounds = bounds.convexHull(s.offsetLLO() + bounds.outset(s.blurRadius));
  }
  return bounds;
}

/// Does not include any shadow.
STU_INLINE
Rect<Float64> lloBoundsEnlargedByStrikethrough(
                Rect<Float64> bounds, const StyledGlyphSpan& span, const TextStyle& style,
                Range<Float64> x, const Optional<DisplayScale>& displayScale,
                LocalFontInfoCache& fontInfoCache)
{
  if (STU_UNLIKELY(x.isEmpty())) return bounds;
  bounds.x = bounds.x.convexHull(x);
  const auto ot = DecorationLine::OffsetAndThickness::forStrikethrough(
                    span, style, span.glyphSpan.font(), displayScale, fontInfoCache);
  bounds.y = bounds.y.convexHull(ot.yLLO());
  return bounds;
}

STU_INLINE
Rect<Float64> lloBackgroundBounds(const TextFrameLine& line, const TextStyle::BackgroundInfo& info,
                                  Range<Float64> x, const Optional<DisplayScale>& displayScale)
{
  Float32 ascent = line.ascent + line.leading/2;
  Float32 descent = line.descent + line.leading/2;
  if (displayScale) {
    if (line.lineIndex == 0) {
      ascent = ceilToScale(ascent, *displayScale);
    }
    if (line.isLastLine) {
      descent = ceilToScale(descent, *displayScale);
    }
  }
  Rect<Float64> bounds = {x, Range{-descent, ascent}};
  if (const Optional<const STUBackgroundAttribute&> bg = info.stuAttribute) {
    UIEdgeInsets e = bg->_edgeInsets;
    if (info.borderColorIndex) {
      const auto b = bg->_borderWidth/2;
      e.top -= b;
      e.left -= b;
      e.right -= b;
      e.bottom -= b;
    }
    bounds = bounds.inset(e);
  }
  return bounds;
}

STU_INLINE
Rect<Float64> lloBoundsEnlargedByRunBackground(Rect<Float64> bounds, const TextFrameLine& line,
                                               const TextStyle::BackgroundInfo& info,
                                               Range<Float64> x,
                                               const Optional<DisplayScale>& displayScale)
{
  if (STU_UNLIKELY(x.isEmpty())) return bounds;
  return bounds.convexHull(lloBackgroundBounds(line, info, x, displayScale));
}

static Rect<Float64> boundsEnlargedByRunNonUnderlineDecorationBounds(
                       Rect<Float64> bounds, const StyledGlyphSpan& span,
                       const TextStyle& style, Range<Float64> x, STUTextFrameDrawingMode mode,
                       const Optional<DisplayScale>& displayScale,
                       LocalFontInfoCache& fontInfoCache)
{
  if (!(mode & STUTextFrameDrawOnlyBackground)) {
    if (const TextStyle::StrokeInfo* const strokeInfo = style.strokeInfo()) {
      bounds = boundsEnlargedByStroke(bounds, *strokeInfo);
    }
    if (style.flags() & TextFlags::hasStrikethrough) {
      bounds = lloBoundsEnlargedByStrikethrough(bounds, span, style, x, displayScale, fontInfoCache);
    }
    if (!bounds.isEmpty()) {
      if (const TextStyle::ShadowInfo* const shadowInfo = style.shadowInfo()) {
        bounds = lloBoundsEnlargedByShadow(bounds, *shadowInfo);
      }
    }
  }
  if (!(mode & STUTextFrameDrawOnlyForeground)) {
    if (const TextStyle::BackgroundInfo* const bgInfo = style.backgroundInfo()) {
      bounds = lloBoundsEnlargedByRunBackground(bounds, *span.line, *bgInfo, x, displayScale);
    }
  }
  return bounds;
}


namespace detail {

void adjustFastTextFrameLineBoundsToAccountForDecorationsAndAttachments(
       TextFrameLine& line, LocalFontInfoCache& fontInfoCache)
{
  const Range<Float64> fastBoundsYLLO = {line.fastBoundsLLOMinY, line.fastBoundsLLOMaxY};
  Rect<Float64> bounds = {{line.fastBoundsMinX, line.fastBoundsMaxX}, fastBoundsYLLO};
  const auto mask = (TextFlags::decorationFlags ^ TextFlags::hasUnderline)
                  | TextFlags::hasAttachment;
  if (line.textFlags() & mask) {
    line.forEachStyledGlyphSpan(mask, none,
      [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x)
    {
      Rect<Float64> r;
      if (const auto attachmentInfo = style.attachmentInfo(); STU_UNLIKELY(attachmentInfo)) {
        const STUTextAttachment* __unsafe_unretained const attachment = attachmentInfo->attribute;
        r = attachment->_imageBounds;
        r.x.start += x.start; // TODO: review
        r.x.end += x.end;
        r.x.end -= attachment->_width;
      } else {
       r = Rect{x, fastBoundsYLLO};
      }
      r = boundsEnlargedByRunNonUnderlineDecorationBounds(r, span, style, x,
                                                          STUTextFrameDefaultDrawingMode,
                                                          DisplayScale::oneAsOptional(),
                                                          fontInfoCache);
      bounds = bounds.convexHull(r);
    });
  }
  if (line.textFlags() & TextFlags::hasUnderline) {
    const auto r = Underlines::imageBoundsLLO(line, none, DisplayScale::oneAsOptional(),
                                              fontInfoCache);
    if (!r.x.isEmpty()) {
      bounds = bounds.convexHull(r);
    }
  }
  line.fastBoundsLLOMaxY = narrow_cast<Float32>(bounds.y.end);
  line.fastBoundsLLOMinY = narrow_cast<Float32>(bounds.y.start);
  line.fastBoundsMinX = narrow_cast<Float32>(bounds.x.start);
  line.fastBoundsMaxX = narrow_cast<Float32>(bounds.x.end);
}

} // namespace detail

template <typename T, EnableIf<isOneOf<T, CGFloat, Float64>> = 0>
static Rect<T> getTextAttachmentRunImageBoundsLLO(
                  Range<T> x, CGFloat baselineOffset,
                  const STUTextAttachment* __unsafe_unretained attachment)
{
  return {Range{x.start + attachment->_imageBounds.x.start,
                x.end + (attachment->_imageBounds.x.end - attachment->_width)},
          baselineOffset + -1*attachment->_imageBounds.y};
}

struct LineImageBounds {
  Rect<Float64> glyphBounds;
  Rect<Float64> imageBounds;
};

static
Rect<CGFloat> calculateLineGlyphPathBoundsLLO(const TextFrameLine& line,
                                              const STUCancellationFlag& cancellationFlag,
                                              LocalGlyphBoundsCache& glyphBoundsCache)
{
  Rect<CGFloat> bounds = Rect<CGFloat>::infinitelyEmpty();
  line.forEachCTLineSegment(FlagsRequiringIndividualRunIteration{detail::everyRunFlag},
    [&](TextLinePart part __unused, CTLineXOffset ctLineXOffset, CTLine& ctLine __unused,
        Optional<GlyphSpan> glyphSpan) -> ShouldStop
  {
    const GlyphSpan span = *glyphSpan;
    Rect<CGFloat> r = span.imageBounds(glyphBoundsCache);
    if (!r.isEmpty()) {
      r.x += ctLineXOffset.value;
      bounds = bounds.convexHull(r);
    }
    return ShouldStop{isCancelled(cancellationFlag)};
  });
  if ((line.textFlags() & TextFlags::hasAttachment) && !isCancelled(cancellationFlag)) {
    line.forEachStyledGlyphSpan(TextFlags::hasAttachment, none,
      [&](const StyledGlyphSpan&, const TextStyle& style, Range<Float64> x)
    {
      const auto r = getTextAttachmentRunImageBoundsLLO(
                       narrow_cast<Range<CGFloat>>(x), style.baselineOffset(),
                       style.attachmentInfo()->attribute);
      if (!r.isEmpty()) {
        bounds = bounds.convexHull(r);
      }
    });
  }
  if (bounds.x.start == Rect<CGFloat>::infinitelyEmpty().x.start) {
    bounds = Rect<CGFloat>{};
  }
  return bounds;
}

static
LineImageBounds calculateLineImageBoundsLLO(const TextFrameLine& line,
                                            const ImageBoundsContext& context)
{
  const TextFlags effectiveLineFlags = line.effectiveTextFlags(context.styleOverride);
  if (!(context.drawingMode & STUTextFrameDrawOnlyBackground)) {
    if (!(effectiveLineFlags & TextFlags::decorationFlags)
        && (!context.styleOverride
            || context.styleOverride->drawnRange.contains(line.range())))
    {
      const Rect bounds = calculateLineGlyphPathBoundsLLO(line, context.cancellationFlag,
                                                          context.glyphBoundsCache);
      return LineImageBounds{.glyphBounds = bounds, .imageBounds = bounds};
    }
  } else {
    if (!(effectiveLineFlags & TextFlags::hasBackground)) {
      return LineImageBounds{};
    }
  }

  Rect glyphBounds = Rect<Float64>::infinitelyEmpty();
  Rect imageBounds = glyphBounds;
  if (!(context.drawingMode & STUTextFrameDrawOnlyBackground)) {
    line.forEachStyledGlyphSpan(context.styleOverride,
      [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x) -> ShouldStop
    {
      Rect<Float64> r;
      if (!style.hasAttachment()) {
        r = span.glyphSpan.imageBounds(context.glyphBoundsCache);
        r.x += span.ctLineXOffset;
        if (STU_UNLIKELY(span.isPartialLigature)) {
          if (span.leftEndOfLigatureIsClipped) {
            r.x.start = max(r.x.start, x.start);
          }
          if (span.rightEndOfLigatureIsClipped) {
            r.x.end = min(r.x.end, x.end);
          }
        }
      } else  {
        r = getTextAttachmentRunImageBoundsLLO(x, style.baselineOffset(),
                                               style.attachmentInfo()->attribute);
      }
      if (!r.isEmpty()) {
        glyphBounds = r.convexHull(glyphBounds);
      }
      if (style.flags() & (TextFlags::decorationFlags ^ TextFlags::hasUnderline)) {
       r = boundsEnlargedByRunNonUnderlineDecorationBounds(
             r, span, style, x, context.drawingMode, context.displayScale,
             context.fontInfoCache);
      }
      if (!r.isEmpty()) {
        imageBounds = imageBounds.convexHull(r);
      }
      return ShouldStop{context.isCancelled()};
    });
    if (effectiveLineFlags & TextFlags::hasUnderline) {
      const auto r = Underlines::imageBoundsLLO(line, context.styleOverride, context.displayScale,
                                                context.fontInfoCache);
      if (!r.x.isEmpty()) {
        imageBounds = imageBounds.convexHull(r);
      }
    }
  } else { // mode & STUTextFrameDrawOnlyBackground
    line.forEachStyledGlyphSpan(TextFlags::hasBackground, context.styleOverride,
      [&](const StyledGlyphSpan&, const TextStyle& style, const Range<Float64> x)
    {
      imageBounds = imageBounds.convexHull(lloBackgroundBounds(line, *style.backgroundInfo(), x,
                                                               context.displayScale));
    });
  }
  if (imageBounds.x.start == Rect<Float64>::infinitelyEmpty().x.start) {
    imageBounds = Rect<Float64>{};
    if (glyphBounds.x.start == Rect<Float64>::infinitelyEmpty().x.start) {
      glyphBounds = Rect<Float64>{};
    }
  }
  return LineImageBounds{.glyphBounds = glyphBounds, .imageBounds = imageBounds};
}


STU_INLINE
bool getStrokeInfoWithWidthRepresentativeForFullLine(
       const TextFrameLine& line, Optional<TextStyleOverride&> styleOverride,
       Out<Optional<const TextStyle::StrokeInfo&>> outStrokeInfo)
{
  const TextStyle::StrokeInfo* first = nullptr;
  bool isFirst = true;
  if (line.forEachStyledStringRange(styleOverride,
        [&](const TextStyle& style, StyledStringRange range __unused) -> ShouldStop
      {
        if (isFirst) {
          isFirst = false;
          first = style.strokeInfo();
        } else {
          const TextStyle::StrokeInfo* const other = style.strokeInfo();
          if (first != other && (!first || !other || first->strokeWidth != other->strokeWidth)) {
            return stop;
          }
        }
        return {};
      }) == stop)
  {
    return false;
  }
  outStrokeInfo = first;
  return true;
}

STU_INLINE
bool getShadowInfoWithOffsetAndBlurRadiusRepresentativeForFullLine(
       const TextFrameLine& line, Optional<TextStyleOverride&> styleOverride,
       Out<Optional<const TextStyle::ShadowInfo&>> outShadowInfo)
{
  const TextStyle::ShadowInfo* first = nullptr;
  bool isFirst = true;
  if (line.forEachStyledStringRange(styleOverride,
        [&](const TextStyle& style, StyledStringRange) -> ShouldStop
      {
        if (isFirst) {
          isFirst = false;
          first = style.shadowInfo();
        } else {
          const TextStyle::ShadowInfo* const other = style.shadowInfo();
          if (first != other && (!first || !other
                                 || first->offsetX != other->offsetX
                                 || first->offsetY != other->offsetY
                                 || first->blurRadius != other->blurRadius))
          {
            return stop;
          }
        }
        return {};
      }) == stop)
  {
    return false;
  }
  outShadowInfo = first;
  return true;
}

static Rect<Float64> calculateLineImageBoundsUsingExistingGlyphBounds(
                       const TextFrameLine& line, Rect<Float32> glyphBounds,
                       const ImageBoundsContext& context)
{
  STU_DEBUG_ASSERT(!context.styleOverride
                   || context.styleOverride->drawnRange.contains(line.range()));
  STU_DEBUG_ASSERT(!(context.drawingMode & STUTextFrameDrawOnlyBackground));

  const TextFlags effectiveLineFlags = line.effectiveTextFlags(context.styleOverride);
  if (!(effectiveLineFlags & TextFlags::decorationFlags)) {
    return glyphBounds;
  }
  Rect<Float64> bounds = glyphBounds != Rect<Float32>{} ? glyphBounds
                       : Rect<Float64>::infinitelyEmpty();

  Optional<const TextStyle::StrokeInfo&> consistentStrokeInfo = none;
  const bool hasConsistentStroke = !(effectiveLineFlags & TextFlags::hasStroke)
                                   || getStrokeInfoWithWidthRepresentativeForFullLine(
                                        line, context.styleOverride, Out{consistentStrokeInfo});
  Optional<const TextStyle::ShadowInfo&> consistentShadowInfo = none;
  const bool hasConsistentShadow = !(effectiveLineFlags & TextFlags::hasShadow)
                                   || getShadowInfoWithOffsetAndBlurRadiusRepresentativeForFullLine(
                                        line, context.styleOverride, Out{consistentShadowInfo});

  if (hasConsistentStroke && consistentStrokeInfo) {
    bounds = boundsEnlargedByStroke(bounds, *consistentStrokeInfo);
  }
  const TextFlags flagsMask = (consistentShadowInfo ? TextFlags{} : TextFlags::hasBackground)
                            | (hasConsistentStroke ? TextFlags{} : TextFlags::hasStroke)
                            | (hasConsistentShadow ? TextFlags{} : TextFlags::hasShadow)
                            | TextFlags::hasUnderline
                            | TextFlags::hasStrikethrough;

  if (effectiveLineFlags & flagsMask) {
    const auto flagsMaskWithoutHasUnderline = flagsMask ^ TextFlags::hasUnderline;
    if (effectiveLineFlags & flagsMaskWithoutHasUnderline) {
      line.forEachStyledGlyphSpan((flagsMask ^ TextFlags::hasUnderline), context.styleOverride,
        [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x)
      {
        const TextStyle::StrokeInfo* const strokeInfo = hasConsistentStroke ? nil
                                                      : style.strokeInfo();
        const TextStyle::ShadowInfo* const shadowInfo = hasConsistentShadow ? nil
                                                      : style.shadowInfo();
        const bool useRunBounds = strokeInfo || shadowInfo;
        Rect<Float64> r;
        if (!useRunBounds) {
          r = bounds;
        } else {
          if (!style.hasAttachment()) {
            r = span.glyphSpan.imageBounds(context.glyphBoundsCache);
            r.x += span.ctLineXOffset;
          } else {
            r = getTextAttachmentRunImageBoundsLLO(x, style.baselineOffset(),
                                                   style.attachmentInfo()->attribute);
          }
        }
        if (strokeInfo) {
          r = boundsEnlargedByStroke(r, *strokeInfo);
        }
        if (style.flags() & TextFlags::hasStrikethrough) {
          r = lloBoundsEnlargedByStrikethrough(r, span, style, x, context.displayScale,
                                               context.fontInfoCache);
        }
        if (shadowInfo) {
          r = lloBoundsEnlargedByShadow(r, *shadowInfo);
        }
        if (!hasConsistentShadow && !(context.drawingMode & STUTextFrameDrawOnlyForeground)) {
          if (const TextStyle::BackgroundInfo * const bgInfo = style.backgroundInfo()) {
            r = lloBoundsEnlargedByRunBackground(r, line, *bgInfo, x, context.displayScale);
          }
        }
        if (!r.isEmpty()) {
          if (!useRunBounds) {
            bounds = r;
          } else {
            bounds = r.convexHull(bounds);
          }
        }
      });
    }
    if (effectiveLineFlags & TextFlags::hasUnderline) {
      const auto r = Underlines::imageBoundsLLO(line, context.styleOverride, context.displayScale,
                                                context.fontInfoCache);
      if (!r.x.isEmpty()) {
        bounds = bounds.convexHull(r);
      }
    }
  }
  if (consistentShadowInfo) {
    bounds = lloBoundsEnlargedByShadow(bounds, *consistentShadowInfo);
    if ((effectiveLineFlags & TextFlags::hasBackground)
        && !(context.drawingMode & STUTextFrameDrawOnlyForeground))
    {
      line.forEachStyledGlyphSpan(TextFlags::hasBackground, context.styleOverride,
        [&](const StyledGlyphSpan&, const TextStyle& style, const Range<Float64> x)
      {
        bounds = lloBoundsEnlargedByRunBackground(bounds, line, *style.backgroundInfo(), x,
                                                  context.displayScale);
      });
    }
  }
  if (bounds.x.start == Rect<Float64>::infinitelyEmpty().x.start) {
    bounds = Rect<Float64>{};
  }
  return bounds;
}

Rect<CGFloat> TextFrameLine::calculateImageBoundsLLO(const ImageBoundsContext& context) const {
  const Range<TextFrameCompactIndex> lineRange = this->range();
  const Optional<TextStyleOverride&> styleOverride = context.styleOverride;
  const bool fullLine = !styleOverride || styleOverride->drawnRange.contains(lineRange);
  if (!fullLine && !context.styleOverride->drawnRange.overlaps(lineRange)) {
    return {};
  }
  // Note that calculating the image bounds in two different ways (depending on whether we have
  // cached the glyph path bounds) means that we may return two minimally different results due to
  // floating-point rounding errors.
  if (fullLine && !(context.drawingMode & STUTextFrameDrawOnlyBackground)) {
    if (const Optional<Rect<Float32>> glyphBounds = loadGlyphsBoundingRectLLO()) {
      return narrow_cast<Rect<CGFloat>>(calculateLineImageBoundsUsingExistingGlyphBounds(
                                          *this, *glyphBounds, context));
    }
  }
  const LineImageBounds r = calculateLineImageBoundsLLO(*this, context);
  if (fullLine && !(context.drawingMode & STUTextFrameDrawOnlyBackground)
      && !context.isCancelled())
  {
    TextFrameLine& self = const_cast<TextFrameLine&>(*this);
    const auto bounds = narrow_cast<Rect<Float32>>(r.glyphBounds);
    atomic_store_explicit(&self._glyphsBoundingRectMinX,    bounds.x.start, memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectMaxX,    bounds.x.end,   memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectLLOMinY, bounds.y.start, memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectLLOMaxY, bounds.y.end,   memory_order_relaxed);
  }
  return narrow_cast<CGRect>(r.imageBounds);
}


} // namespace stu_label

