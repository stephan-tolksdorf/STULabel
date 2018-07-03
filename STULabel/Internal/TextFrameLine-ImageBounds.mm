// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "STULabel/STUTextAttributes-Internal.hpp"

#import "DecorationLines.hpp"

#import <stdatomic.h>

namespace stu_label {

STU_INLINE
Rect<Float64> boundsEnlargedByStroke(Rect<Float64> bounds, const Float64 strokeWidth) {
  return bounds.outset(strokeWidth/2);
}

STU_INLINE
Rect<Float64> boundsEnlargedByStroke(Rect<Float64> bounds, const TextStyle::StrokeInfo& strokeInfo) {
 return boundsEnlargedByStroke(bounds, strokeInfo.strokeWidth);
}

STU_INLINE
Rect<Float64> lloBoundsEnlargedByShadow(Rect<Float64> bounds, const TextStyle::ShadowInfo& s) {
  auto offset = s.offset();
  offset.y *= -1;
  return bounds.convexHull(offset + bounds.outset(s.blurRadius));
}

STU_INLINE
Rect<Float64> lloBoundsEnlargedByRunUnderlineAndStrikethrough(
                Rect<Float64> bounds, GlyphRunRef run, const TextStyle& style, Range<Float64> x,
                const Optional<DisplayScale>& displayScale, LocalFontInfoCache& fontInfoCache)
{
  if (STU_UNLIKELY(x.isEmpty())) return bounds;
  bounds.x = bounds.x.convexHull(x);
  const CTFontRef font = run.font();
  const CachedFontInfo& fontInfo = fontInfoCache[font];
  if (const TextStyle::UnderlineInfo* const info = style.underlineInfo()) {
    const auto ot = DecorationLine::OffsetAndThickness::forUnderline(
                      *info, style.baselineOffsetInfo(), fontInfo, displayScale);
    bounds.y = bounds.y.convexHull(ot.yLLO());
  }
  if (const TextStyle::StrikethroughInfo* const info = style.strikethroughInfo()) {
    const auto ot = DecorationLine::OffsetAndThickness::forStrikethrough(
                      *info, style.baselineOffsetInfo(), fontInfo, displayScale);
    bounds.y = bounds.y.convexHull(ot.yLLO());
  }
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
      e.top += b;
      e.left += b;
      e.right += b;
      e.bottom += b;
    }
    bounds = bounds.inset(-e);
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

static
Rect<Float64> boundsEnlargedByRunDecorationBounds(Rect<Float64> bounds, const TextFrameLine& line,
                                                  GlyphRunRef run, const TextStyle& style,
                                                  Range<Float64> x,
                                                  const ImageBoundsContext& context)
{
  if (!(context.drawingMode & STUTextFrameDrawOnlyBackground)) {
    if (const TextStyle::StrokeInfo* const strokeInfo = style.strokeInfo()) {
      bounds = boundsEnlargedByStroke(bounds, *strokeInfo);
    }
    if (style.flags() & (TextFlags::hasUnderline | TextFlags::hasStrikethrough)) {
      bounds = lloBoundsEnlargedByRunUnderlineAndStrikethrough(
                 bounds, run, style, x, context.displayScale, context.fontInfoCache);
    }
    if (const TextStyle::ShadowInfo* const shadowInfo = style.shadowInfo()) {
      bounds = lloBoundsEnlargedByShadow(bounds, *shadowInfo);
    }
  }
  if (!(context.drawingMode & STUTextFrameDrawOnlyForeground)) {
    if (const TextStyle::BackgroundInfo* const bgInfo = style.backgroundInfo()) {
      bounds = lloBoundsEnlargedByRunBackground(bounds, line, *bgInfo, x, context.displayScale);
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
  ImageBoundsContext context = {
    .cancellationFlag = CancellationFlag::neverCancelledFlag,
    .drawingMode = STUTextFrameDefaultDrawingMode,
    .displayScale = DisplayScale::oneAsOptional(),
    .fontInfoCache = fontInfoCache
  };
  line.forEachStyledGlyphSpan(TextFlags::decorationFlags | TextFlags::hasAttachment, none,
                              [&](const StyledGlyphSpan& span, const TextStyle& style,
                                  const Range<Float64> x)
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
    r = boundsEnlargedByRunDecorationBounds(r, line, span.glyphSpan.run(), style, x, context);
    bounds = bounds.convexHull(r);
  });
  line.fastBoundsLLOMaxY = narrow_cast<Float32>(bounds.y.end);
  line.fastBoundsLLOMinY = narrow_cast<Float32>(bounds.y.start);
  line.fastBoundsMinX = narrow_cast<Float32>(bounds.x.start);
  line.fastBoundsMaxX = narrow_cast<Float32>(bounds.x.end);
}

} // namespace detail


#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_11_0) \
 || (defined(__TV_OS_VERSION_MIN_REQUIRED) && __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_11_0) \
 || (defined(__WATCH_OS_VERSION_MIN_REQUIRED) && __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_4_0)
  // rdar://33251252 was fixed in iOS 11 Beta 4, http://www.openradar.me/radar?id=4958590695636992
  #define STU_CTRunGetImageBounds_MAY_NEED_RADAR_33251252_WORKAROUND 0
#else
  #define STU_CTRunGetImageBounds_MAY_NEED_RADAR_33251252_WORKAROUND 1
#endif

#if STU_CTRunGetImageBounds_MAY_NEED_RADAR_33251252_WORKAROUND

static bool isCTRunGetImageBoundsReturningWrongXOrigins() {
  static bool isBuggy;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    UIFont * const font = [UIFont systemFontOfSize:UIFont.buttonFontSize];
    NSMutableAttributedString* const string = [[NSMutableAttributedString alloc]
                                                 initWithString:@"x"
                                                     attributes:@{NSFontAttributeName: font}];
    [string appendAttributedString:[[NSAttributedString alloc]
                                      initWithString:@"x"
                                        attributes:@{NSFontAttributeName: font,
                                                     NSForegroundColorAttributeName:
                                                       UIColor.redColor}]];
    const CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
    const CFArrayRef runs = CTLineGetGlyphRuns(line);
    const CGRect bounds1 = CTRunGetImageBounds((CTRunRef)CFArrayGetValueAtIndex(runs, 0), nil, (CFRange){});
    const CGRect bounds2 = CTRunGetImageBounds((CTRunRef)CFArrayGetValueAtIndex(runs, 1), nil, (CFRange){});
    CFRelease(line);
    isBuggy = bounds2.origin.x < bounds1.size.width/2;
  });
  return isBuggy;
}

class CTRunImageBoundsCorrector {
  const bool needToFix_{isCTRunGetImageBoundsReturningWrongXOrigins()};
  const NSArraySpan<CTRun*> nonTokenRuns_;
  Int nonTokenRunIndex_{};
  Float64 nonTokenOffset_{};
  const NSArraySpan<CTRun*> tokenRuns_;
  Int tokenRunIndex_{};
  Float64 tokenOffset_{};
public:
  CTRunImageBoundsCorrector(const TextFrameLine& line)
  : nonTokenRuns_{needToFix_ ? glyphRuns(line._ctLine) : NSArraySpan<CTRun*>{}},
    tokenRuns_{needToFix_ ? glyphRuns(line._tokenCTLine) : NSArraySpan<CTRun*>{}}
  {}

  /// This function requires that the line's runs are iterated from left to right.
  Rect<Float64> getRunImageBoundsLLO(TextLinePart part, CTLineXOffset ctLineXOffset,
                                     GlyphSpan glyphSpan)
  {
    CTRun* const glyphSpanRun = glyphSpan.run().ctRun();
    CGRect bounds = glyphSpan.imageBounds();
    Float64 xOffset = ctLineXOffset.value;
    if (needToFix_) {
      if (part == TextLinePart::originalString) {
        for (;;) {
          CTRun* const run = nonTokenRuns_[nonTokenRunIndex_];
          if (run == glyphSpanRun) break;
          nonTokenOffset_ += GlyphSpan{run}.typographicWidth();
          ++nonTokenRunIndex_;
        }
        xOffset += nonTokenOffset_;
      } else {
        for (;;) {
          CTRun* const run = tokenRuns_[tokenRunIndex_];
          if (run == glyphSpanRun) break;
          tokenOffset_ += GlyphSpan{run}.typographicWidth();
          ++tokenRunIndex_;
        }
        xOffset += tokenOffset_;
      }
    }
    return {bounds.origin + Point{xOffset, 0.0}, bounds.size};
  }
};

#else // !STU_CTRunGetImageBounds_MAY_NEED_RADAR_33251252_WORKAROUND

class CTRunImageBoundsCorrector {
  const bool needToFix_{false};
public:
  STU_INLINE CTRunImageBoundsCorrector(const TextFrameLine&) {}

  STU_INLINE
  Rect<Float64> getRunImageBoundsLLO(TextLinePart part, CTLineXOffset ctLineXOffset,
                                     GlyphSpan glyphSpan)
  {
    const CGRect bounds = glyphSpan.imageBounds();
    return {bounds.origin + Point{xOffset, 0.0}, bounds.size};
  }
};

#endif

// TODO: handling NSBaselineOffsetAttributeName

static Rect<Float64> getTextAttachmentRunImageBoundsLLO(
                       Range<Float64> x, const STUTextAttachment* __unsafe_unretained attachment)
{
  return {Range{x.start + attachment->_imageBounds.x.start,
                x.end + (attachment->_imageBounds.x.end - attachment->_width)},
          -1*attachment->_imageBounds.y};
}

struct LineImageBounds {
  Rect<Float64> glyphBounds;
  Rect<Float64> imageBounds;
};

static
Rect<Float64> calculateLineGlyphPathBoundsLLO(const TextFrameLine& line,
                                              const STUCancellationFlag& cancellationFlag)
{
  Rect<Float64> bounds = Rect<Float64>::infinitelyEmpty();
  CTRunImageBoundsCorrector ibc{line};
  line.forEachCTLineSegment(
    FlagsRequiringIndividualRunIteration{
      &cancellationFlag != &CancellationFlag::neverCancelledFlag ? detail::everyRunFlag : TextFlags{}},
    [&](TextLinePart part, CTLineXOffset ctLineXOffset, CTLine& ctLine,
        Optional<GlyphSpan> glyphSpan) -> ShouldStop
  {
    Rect<Float64> r;
    if (!glyphSpan) {
      CGRect rect = CTLineGetImageBounds(&ctLine, nil);
      rect.origin.x += ctLineXOffset.value;
      r = rect;
    } else {
      r = ibc.getRunImageBoundsLLO(part, ctLineXOffset, *glyphSpan);
    }
    bounds = bounds.convexHull(r);
    return ShouldStop{isCancelled(cancellationFlag)};
  });
  if ((line.textFlags() & TextFlags::hasAttachment) && !isCancelled(cancellationFlag)) {
    line.forEachStyledGlyphSpan(TextFlags::hasAttachment, none,
      [&](const StyledGlyphSpan&, const TextStyle& style, Range<Float64> x)
    {
      bounds = bounds.convexHull(getTextAttachmentRunImageBoundsLLO(
                                   x, style.attachmentInfo()->attribute));
    });
  }
  if (bounds.x.start == Rect<Float64>::infinitelyEmpty().x.start) {
    bounds = Rect<Float64>{};
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
      const Rect bounds = calculateLineGlyphPathBoundsLLO(line, context.cancellationFlag);
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
    CTRunImageBoundsCorrector ibc{line};
    line.forEachStyledGlyphSpan(context.styleOverride,
      [&](const StyledGlyphSpan& span, const TextStyle& style, const Range<Float64> x) -> ShouldStop
    {
      Rect<Float64> r;
      if (!style.hasAttachment()) {
        r = ibc.getRunImageBoundsLLO(span.part, CTLineXOffset{span.ctLineXOffset}, span.glyphSpan);
      } else  {
        r = getTextAttachmentRunImageBoundsLLO(x, style.attachmentInfo()->attribute);
      }
      glyphBounds = r.convexHull(glyphBounds);
      if (style.flags() & TextFlags::decorationFlags) {
       r = boundsEnlargedByRunDecorationBounds(r, line, span.glyphSpan.run(), style, x, context);
      }
      if (STU_UNLIKELY(span.isPartialLigature)) {
        if (span.leftEndOfLigatureIsClipped) {
          r.x.start = max(r.x.start, x.start);
        }
        if (span.rightEndOfLigatureIsClipped) {
          r.x.end = min(r.x.end, x.end);
        }
      }
      imageBounds = imageBounds.convexHull(r);
      return ShouldStop{context.isCancelled()};
    });
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

  const TextFlags lineFlags = line.effectiveTextFlags(context.styleOverride);
  if (!(lineFlags & TextFlags::decorationFlags)) {
    return glyphBounds;
  }
  Rect<Float64> bounds = glyphBounds != Rect<Float32>{} ? glyphBounds
                       : Rect<Float64>::infinitelyEmpty();

  Optional<const TextStyle::StrokeInfo&> consistentStrokeInfo = none;
  const bool hasConsistentStroke = !(lineFlags & TextFlags::hasStroke)
                                   || getStrokeInfoWithWidthRepresentativeForFullLine(
                                        line, context.styleOverride, Out{consistentStrokeInfo});
  Optional<const TextStyle::ShadowInfo&> consistentShadowInfo = none;
  const bool hasConsistentShadow = !(lineFlags & TextFlags::hasShadow)
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

  if (lineFlags & flagsMask) {
    CTRunImageBoundsCorrector ibc{line};
    line.forEachStyledGlyphSpan(flagsMask, context.styleOverride,
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
        const TextLinePart linePart = span.part;
        r = !style.hasAttachment()
          ? ibc.getRunImageBoundsLLO(linePart, CTLineXOffset{span.ctLineXOffset}, span.glyphSpan)
          : getTextAttachmentRunImageBoundsLLO(x, style.attachmentInfo()->attribute);
      }
      if (strokeInfo) {
        r = boundsEnlargedByStroke(r, *strokeInfo);
      }
      if (style.flags() & (TextFlags::hasUnderline | TextFlags::hasStrikethrough)) {
        r = lloBoundsEnlargedByRunUnderlineAndStrikethrough(r, span.glyphSpan.run(), style, x,
                                                            context.displayScale,
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
      if (!useRunBounds) {
        bounds = r;
      } else {
        bounds = r.convexHull(bounds);
      }
    });
  }
  if (consistentShadowInfo) {
    bounds = lloBoundsEnlargedByShadow(bounds, *consistentShadowInfo);
    if ((lineFlags & TextFlags::hasBackground)
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

Rect<Float32> TextFrameLine::glyphsBoundingRectLLO(const STUCancellationFlag& cancellationFlag) const {
  if (const Optional<Rect<Float32>> glyphBounds = loadGlyphsBoundingRectLLO()) {
    return *glyphBounds;
  }
  const Rect<Float32> bounds = narrow_cast<Rect<Float32>>(calculateLineGlyphPathBoundsLLO(
                                                            *this, cancellationFlag));
  if (!isCancelled(cancellationFlag)) {
    TextFrameLine& self = const_cast<TextFrameLine&>(*this);
    atomic_store_explicit(&self._glyphsBoundingRectMinX,    bounds.x.start, memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectMaxX,    bounds.x.end,   memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectLLOMinY, bounds.y.start, memory_order_relaxed);
    atomic_store_explicit(&self._glyphsBoundingRectLLOMaxY, bounds.y.end,   memory_order_relaxed);
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

