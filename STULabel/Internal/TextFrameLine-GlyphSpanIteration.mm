// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "NSStringRef.hpp"
#import "UnicodeCodePointProperties.hpp"

namespace stu_label {

using detail::everyRunFlag;

ShouldStop TextFrameLine::forEachCTLineSegment(
             FlagsRequiringIndividualRunIteration mask,
             FunctionRef<ShouldStop(TextLinePart, CTLineXOffset, CTLine&, Optional<GlyphSpan>)> body)
  const
{
  CTLine* const ctLine = _ctLine;
  NSArrayRef<CTRun*> runs;
  const bool shouldIterNonTokenRunsIndividually{(nonTokenTextFlags() | everyRunFlag) & mask.flags};
  if (ctLine) {
    if (!shouldIterNonTokenRunsIndividually && _leftPartEnd.runIndex < 0) {
      const auto shouldStop = body(TextLinePart::originalString, CTLineXOffset{0}, *ctLine, none);
      if (shouldStop) return shouldStop;
    } else {
      runs = glyphRuns(ctLine);
      Int endRunIndex = _leftPartEnd.runIndex;
      Int endGlyphIndex = _leftPartEnd.glyphIndex;
      if (endRunIndex < 0) {
        endRunIndex = runs.count();
        endGlyphIndex = 0;
      };
      for (CTRun* const run : runs[{0, endRunIndex}]) {
        const auto shouldStop = body(TextLinePart::originalString, CTLineXOffset{0}, *ctLine, run);
        if (shouldStop) return shouldStop;
      }
      if (endGlyphIndex > 0) {
        const auto shouldStop = body(TextLinePart::originalString, CTLineXOffset{0}, *ctLine,
                                     GlyphSpan{runs[endRunIndex], {0, endGlyphIndex}, unchecked});
        if (shouldStop) return shouldStop;
      }
    }
  }
  CTLine* const tokenCTLine = _tokenCTLine;
  if (!tokenCTLine) return {};
  const Int hyphenRunIndex = _hyphenRunIndex;
  STU_DEBUG_ASSERT(hyphenRunIndex < 0 ? this->hasTruncationToken : this->hasInsertedHyphen);
  if (hyphenRunIndex < 0 && !((tokenTextFlags() | everyRunFlag) & mask.flags)) {
    const auto shouldStop = body(TextLinePart::truncationToken, CTLineXOffset{this->leftPartWidth},
                                 *tokenCTLine, none);
    if (shouldStop) return shouldStop;
  } else {
    const NSArraySpan<CTRun*> tokenRuns = glyphRuns(tokenCTLine);
    if (hyphenRunIndex < 0) {
      for (CTRun* const run : tokenRuns) {
        const auto shouldStop = body(TextLinePart::truncationToken,
                                     CTLineXOffset{this->leftPartWidth}, *tokenCTLine, run);
        if (shouldStop) return shouldStop;
      }
    } else if (hyphenRunIndex < tokenRuns.count()) {
      const GlyphRunRef run{tokenRuns[hyphenRunIndex]};
      const GlyphSpan span = _hyphenGlyphIndex < 0 ? GlyphSpan{run}
                           : GlyphSpan{run, {_hyphenGlyphIndex, Count{1}}, unchecked};
      const auto shouldStop = body(TextLinePart::insertedHyphen,
                                   CTLineXOffset{this->leftPartWidth - _hyphenXOffset},
                                   *tokenCTLine, span);
      if (shouldStop) return shouldStop;
    }
  }
  Int startRunIndex = _rightPartStart.runIndex;
  if (startRunIndex < 0) return {};
  STU_DEBUG_ASSERT(ctLine != nullptr);
  const Int startGlyphIndex = _rightPartStart.glyphIndex;
  const CTLineXOffset rightPartXOffset{_rightPartXOffset};
  if (!shouldIterNonTokenRunsIndividually && startRunIndex == 0 && startGlyphIndex <= 0) {
    return body(TextLinePart::originalString, rightPartXOffset, *ctLine, none);
  }
  if (startGlyphIndex > 0) {
    const auto shouldStop = body(TextLinePart::originalString, rightPartXOffset, *ctLine,
                                 GlyphSpan{runs[startRunIndex], {startGlyphIndex, $}});
    if (shouldStop) return shouldStop;
    startRunIndex += 1;
  }
  for (CTRun* const run : runs[{startRunIndex, $}]) {
    const auto shouldStop = body(TextLinePart::originalString, rightPartXOffset, *ctLine, run);
    if (shouldStop) return shouldStop;
  }
  return {};
}

struct TokenStringOffset : Parameter<TokenStringOffset, Int32> { using Parameter::Parameter; };

} // namespace stu_label

template <>
class stu::OptionalValueStorage<stu_label::TokenStringOffset> {
  static STU_CONSTEXPR Int32 reservedValue() noexcept { return minValue<Int32>; }
public:
  stu_label::TokenStringOffset value_{reservedValue()};
  STU_CONSTEXPR bool hasValue() const noexcept { return value_.value != reservedValue(); }
  STU_CONSTEXPR void clearValue() noexcept { value_.value = reservedValue(); }
  STU_CONSTEXPR
  void constructValue(stu_label::TokenStringOffset value) { value_ = value; }
};

namespace stu_label {

STU_NO_INLINE static
ShouldStop
  forEachStyledGlyphSpanSubspan(
    StyledGlyphSpan&, Float64 minX, Float64 maxX,
    const TextStyle&, TextStyleOverride&, TextFlags flagsTestMask,
    FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&, Range<Float64>)> body);

struct StyleOverrideOffsetRanges {
  Range<Int32> drawnRangeInOriginalString;
  Range<Int32> overrideRangeInOriginalString;
};

[[nodiscard]] STU_INLINE
ShouldStop forEachStyledGlyphSpanSubspan(
             StyledGlyphSpan& span,
             Float64 minX, Float64 maxX,
             InOut<const TextStyle*> inOutStyle,
             Optional<TextStyleOverride&> styleOverride,
             Optional<const StyleOverrideOffsetRanges&> soOffsetRanges,
             TextFlags flagsTestMask,
             FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&, Range<Float64>)> body)
{
  const TextStyle* style = inOutStyle = &inOutStyle->styleForStringIndex(span.stringRange.start);
  if (STU_UNLIKELY(styleOverride)) {
    const Range<Int32> drawnRange = soOffsetRanges
                                  ? soOffsetRanges->drawnRangeInOriginalString
                                  : styleOverride->drawnRangeInOriginalString;
    const Range<Int32> overrideRange = soOffsetRanges
                                     ? soOffsetRanges->overrideRangeInOriginalString
                                     : styleOverride->overrideRangeInOriginalString;
    if (!drawnRange.overlaps(span.stringRange)) return {};
    if (!drawnRange.contains(span.stringRange) || overrideRange.overlaps(span.stringRange)) {
      if (!overrideRange.contains(span.stringRange)) {
        return forEachStyledGlyphSpanSubspan(span, minX, maxX, *style, *styleOverride,
                                             flagsTestMask, body);
      }
      const TextFlags flags = (style->flags() & styleOverride->flagsMask)
                            | styleOverride->flags;
      if (!(flagsTestMask & (flags | everyRunFlag))) return {};
      if (style != styleOverride->overriddenStyle()) {
        styleOverride->applyTo(*style);
      }
      style = &styleOverride->style();
      goto CallBody;
    }
  }
  if (!(flagsTestMask & (style->flags()| everyRunFlag))) return {};
CallBody:
  return body(span, *style, Range{minX, maxX});
}

ShouldStop TextFrameLine::forEachStyledGlyphSpan(
             TextFlags flagsFilterMask, Optional<TextStyleOverride&> styleOverride,
             FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&, Range<Float64>)> body)
           const
{
  STU_DEBUG_ASSERT(_initStep == 0);
  const TextFrame& textFrame = this->textFrame();
  const TextFrameParagraph& para = textFrame.paragraphs()[this->paragraphIndex];
  StyledGlyphSpan span{.glyphSpan = GlyphSpan{uninitialized},
                       .startIndexOfTruncationTokenInTruncatedString =
                          para.rangeOfTruncationTokenInTruncatedString().start,
                       .line = this,
                       .paragraph = &para};
  CTLine* const ctLine = _ctLine;
  NSArrayRef<CTRun*> runs;
  const TextStyle* style;
  Float64 x;
  if (ctLine) {
    const Float64 leftPartWidth = this->leftPartWidth;
    TextFlags flags = this->nonTokenTextFlags() | everyRunFlag;
    if (STU_UNLIKELY(styleOverride)) {
      flags = stu_label::effectiveTextFlags(flags, this->range(), *styleOverride);
    }
    if (flagsFilterMask & flags) {
      runs = glyphRuns(ctLine);
      style = &textFrame.firstNonTokenTextStyleForLineAtIndex(this->lineIndex);
      span.part = TextLinePart::originalString;
      span.attributedString = textFrame.originalAttributedString;
      span.ctLineXOffset = 0;
      Int endRunIndex = _leftPartEnd.runIndex;
      Int endGlyphIndex = _leftPartEnd.glyphIndex;
      if (endRunIndex < 0) {
        endRunIndex = runs.count();
        endGlyphIndex = 0;
      };
      x = 0;
      const Int lastRunIndex = endRunIndex - (endGlyphIndex <= 0);
      for (Int i = 0; i <= lastRunIndex; ++i) {
        const GlyphRunRef run = runs[i];
        const Range<Int32> runStringRange = Range<Int32>(run.stringRange());
        if (i != endRunIndex) {
          span.glyphSpan = run;
          span.stringRange = runStringRange;
        } else {
          span.glyphSpan = GlyphSpan{run, {0, endGlyphIndex}, unchecked};
          STU_DEBUG_ASSERT(this->hasTruncationToken);
          span.stringRange = runStringRange
                             .intersection(!this->isTruncatedAsRightToLeftLine
                                           ? Range{this->rangeInOriginalString.start,
                                                   para.excisedRangeInOriginalString().start}
                                           : Range{para.excisedRangeInOriginalString().end,
                                                   this->rangeInOriginalString.end});
        }
        const Float64 nextX = i == lastRunIndex ? leftPartWidth
                            : x + span.glyphSpan.typographicWidth();
        const auto shouldStop = forEachStyledGlyphSpanSubspan(span, x, nextX, InOut{style},
                                                              styleOverride, none, flagsFilterMask,
                                                              body);
        if (shouldStop) return shouldStop;
        x = nextX;
      }
    } else {
      x = leftPartWidth;
    }
  } else {
    x = 0;
  }

  CTLine* const tokenCTLine = _tokenCTLine;
  if (!tokenCTLine) return {};
  const Float64 tokenEndX = x + this->tokenWidth;
  TextFlags tokenFlags = this->tokenTextFlags() | everyRunFlag;
  if (this->hasTruncationToken) {
    StyleOverrideOffsetRanges sor {
      .drawnRangeInOriginalString = Range<Int32>{uninitialized},
      .overrideRangeInOriginalString = Range<Int32>{uninitialized}
    };
    if (STU_UNLIKELY(styleOverride)) {
      const Range<Int32> tokenRange = {0, para.truncationTokenLength};
      sor.drawnRangeInOriginalString = styleOverride->drawnRange.rangeInTruncatedString()
                                     - span.startIndexOfTruncationTokenInTruncatedString;
      sor.overrideRangeInOriginalString = styleOverride->overrideRange.rangeInTruncatedString()
                                        - span.startIndexOfTruncationTokenInTruncatedString;
      tokenFlags = stu_label::effectiveTextFlags(tokenFlags, tokenRange, *styleOverride,
                                                 sor.drawnRangeInOriginalString,
                                                 sor.overrideRangeInOriginalString);
    }
    if (tokenFlags & flagsFilterMask) {
      span.part = TextLinePart::truncationToken;
      span.attributedString = para.truncationToken;
      span.ctLineXOffset = this->leftPartWidth;
      const TextStyle* tokenStyle = &textFrame.firstTokenTextStyleForLineAtIndex(this->lineIndex);
      const NSArrayRef<CTRun*> tokenRuns = glyphRuns(tokenCTLine);
      const Int lastTokenRunIndex = tokenRuns.count() - 1;
      for (Int i = 0; i <= lastTokenRunIndex; ++i) {
        const GlyphRunRef run = tokenRuns[i];
        span.glyphSpan = run;
        span.stringRange = Range<Int32>(run.stringRange());
        const Float64 nextX = i == lastTokenRunIndex ? tokenEndX
                            : min(x + span.glyphSpan.typographicWidth(), tokenEndX);
        const auto shouldStop = forEachStyledGlyphSpanSubspan(span, x, nextX, InOut{tokenStyle},
                                                              styleOverride, sor, flagsFilterMask,
                                                              body);
        if (shouldStop) return shouldStop;
        x = nextX;
      }
    }
  } else {
    STU_DEBUG_ASSERT(this->hasInsertedHyphen && _hyphenRunIndex >= 0);
    bool isOverridden = false;
    if (STU_UNLIKELY(styleOverride)) {
      const TextFrameCompactIndex hyphenIndex{this->rangeInOriginalString.end - 1,
                                              IsIndexOfInsertedHyphen{true}};
      if (styleOverride->drawnRange.contains(hyphenIndex)) {
        isOverridden = styleOverride->overrideRange.contains(hyphenIndex);
        if (isOverridden) {
          tokenFlags = (tokenFlags & styleOverride->flagsMask) | styleOverride->flags;
        }
      } else {
        tokenFlags = TextFlags{};
      }
    }
    if (tokenFlags & flagsFilterMask) {
      span.part = TextLinePart::insertedHyphen;
      span.attributedString = textFrame.originalAttributedString;
      span.stringRange = Range{rangeInOriginalString.end, Count{0}};
      span.ctLineXOffset = this->leftPartWidth - _hyphenXOffset;
      const NSArrayRef<CTRun*> tokenRuns = glyphRuns(tokenCTLine);
      if (tokenRuns.isValidIndex(_hyphenRunIndex)) {
        const GlyphRunRef run = tokenRuns[_hyphenRunIndex];
        span.glyphSpan = _hyphenGlyphIndex < 0 ? GlyphSpan{run}
                       : GlyphSpan{run, {_hyphenGlyphIndex, Count{1}}, unchecked};
        const TextStyle* tokenStyle = &textFrame.firstTokenTextStyleForLineAtIndex(this->lineIndex);
        if (STU_UNLIKELY(isOverridden)) {
          if (tokenStyle != styleOverride->overriddenStyle()) {
            styleOverride->applyTo(*tokenStyle);
          }
          tokenStyle = &styleOverride->style();
        }
        const auto shouldStop = body(span, *tokenStyle, Range{x, tokenEndX});
        if (shouldStop) return shouldStop;
      }
    }
  }

  Int startRunIndex = _rightPartStart.runIndex;
  if (startRunIndex < 0 || !runs) return {};
  span.part = TextLinePart::originalString;
  span.attributedString = textFrame.originalAttributedString;
  span.ctLineXOffset = _rightPartXOffset;
  x = tokenEndX;
  const Float64 width = this->width;
  const Int lastRunIndex = runs.count() - 1;
  for (Int i = startRunIndex; i <= lastRunIndex; ++i) {
    const GlyphRunRef run = runs[i];
    const Range<Int32> runStringRange = Range<Int32>(run.stringRange());
    if (i == startRunIndex && _rightPartStart.glyphIndex > 0) {
      span.glyphSpan = GlyphSpan{run, {_rightPartStart.glyphIndex, $}};
      STU_DEBUG_ASSERT(this->hasTruncationToken);
      span.stringRange = runStringRange
                         .intersection(!this->isTruncatedAsRightToLeftLine
                                       ? Range{para.excisedRangeInOriginalString().end,
                                               this->rangeInOriginalString.end}
                                       : Range{this->rangeInOriginalString.start,
                                               para.excisedRangeInOriginalString().start});
    } else {
      span.glyphSpan = run;
      span.stringRange = runStringRange;
    }
    const Float64 nextX = i == lastRunIndex ? width
                        : min(x + span.glyphSpan.typographicWidth(), width);
    const auto shouldStop = forEachStyledGlyphSpanSubspan(span, x, nextX, InOut{style},
                                                          styleOverride, none, flagsFilterMask,
                                                          body);
    if (shouldStop) return shouldStop;
    x = nextX;
  }
  return {};
}

static Int findGlyphStringEndIndex(Int glyphIndex,
                                   ArrayRef<const Int> stringIndices, bool isRTL,
                                   Int runStringEndIndex,
                                   const Int* __nullable sortedStringIndices,
                                   InOut<Int> inOutSortedStringIndicesCursor)
{
  const Int glyphStringIndex = stringIndices[glyphIndex];
  if (STU_LIKELY(!sortedStringIndices)) {
    Int i = glyphIndex;
    if (!isRTL) {
      do ++i;
      while (i < stringIndices.count() && stringIndices[i] <= glyphStringIndex);
      return i < stringIndices.count() ? stringIndices[i] : runStringEndIndex;
    } else {
      do --i;
      while (i >= 0 && stringIndices[i] <= glyphStringIndex);
      return i >= 0 ? stringIndices[i] : runStringEndIndex;
    }
  } else { // stringIndices is non-monotonic.
    Int i = inOutSortedStringIndicesCursor;
    if (sortedStringIndices[i] < glyphStringIndex) {
      do ++i;
      while (sortedStringIndices[i] < glyphStringIndex);
    } else {
      while (sortedStringIndices[i] > glyphStringIndex) {
        --i;
      }
    }
    inOutSortedStringIndicesCursor = i;
    do ++i;
    while (i < stringIndices.count() && sortedStringIndices[i] == glyphStringIndex);
    return i < stringIndices.count() ? sortedStringIndices[i] : runStringEndIndex;
  }
}

template <int maxInnerOffsetCount>
[[nodiscard]] static 
ShouldStop
  enumerateStyledLigatureSubspans(
    StyledGlyphSpan& span, Float64 minX, Float64 maxX,
    Range<Int> drawnRange, Range<Int> overrideRange,
    const TextStyle* __nullable nonOverrideStyle,
    const TextStyle* __nullable overrideStyle,
    bool firstGraphemeClusterIsDrawn, bool firstGraphemeClusterIsOverridden,
    const Array<Range<Int>, Fixed, maxInnerOffsetCount + 1>& graphemeClusterStringRanges,
    const Array<CGFloat, Fixed, maxInnerOffsetCount>& innerOffsets,
    Int innerOffsetCount,
    FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&, Range<Float64>)> body)
{
  STU_ASSERT(0 < innerOffsetCount && innerOffsetCount <= maxInnerOffsetCount);
  span.isPartialLigature = true;
  bool spanIsDrawn = firstGraphemeClusterIsDrawn;
  bool spanIsOverridden = firstGraphemeClusterIsOverridden;
  for (Int i = -1;;) {
    bool nextIsDrawn = false;
    bool nextIsOverridden = false;
    const Int i0 = i;
    while (++i < innerOffsetCount) {
      nextIsDrawn = drawnRange.overlaps(graphemeClusterStringRanges[i + 1]);
      nextIsOverridden = overrideRange.overlaps(graphemeClusterStringRanges[i + 1]);
      if ((spanIsDrawn != nextIsDrawn) | (spanIsOverridden != nextIsOverridden)) break;
    }
    if (spanIsDrawn) {
      const TextStyle* const style = spanIsOverridden ? overrideStyle : nonOverrideStyle;
      if (style) {
        const bool leftEndOfLigatureIsClipped = i0 >= 0;
        span.leftEndOfLigatureIsClipped = leftEndOfLigatureIsClipped;
        const Float64 spanMinX = !leftEndOfLigatureIsClipped ? minX
                               : minX + innerOffsets[i0];
        const bool rightEndOfLigatureIsClipped = i != innerOffsetCount;
        span.rightEndOfLigatureIsClipped = rightEndOfLigatureIsClipped;
        const Float64 spanMaxX = !rightEndOfLigatureIsClipped ? maxX
                               : minX + innerOffsets[i];
        span.stringRange = Range<Int32>{graphemeClusterStringRanges[i0 + 1]
                                        .convexHull(graphemeClusterStringRanges[i])};
        const auto shouldStop = body(span, *style, Range{spanMinX, spanMaxX});
        if (shouldStop) return shouldStop;
      }
    }
    if (i == innerOffsetCount) break;
    spanIsDrawn = nextIsDrawn;
    spanIsOverridden = nextIsOverridden;
  }
  span.isPartialLigature = false;
  span.leftEndOfLigatureIsClipped = false;
  span.rightEndOfLigatureIsClipped = false;
  return {};
}


[[nodiscard]] static STU_NO_INLINE
ShouldStop forEachStyledGlyphSpanSubspan(
             StyledGlyphSpan& span, Float64 minX, const Float64 maxX,
             const TextStyle& textStyle, TextStyleOverride& styleOverride,
             const TextFlags flagsTestMask,
             FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&, Range<Float64>)> body)
{
  const TextFlags textFlags = textStyle.flags() | everyRunFlag;
  const bool shouldCallBodyOnNonOverridden{flagsTestMask & textFlags};
  const bool shouldCallBodyOnOverridden = !styleOverride.overrideRange.isEmpty()
                                        && (flagsTestMask
                                            & (  (textFlags & styleOverride.flagsMask)
                                               | styleOverride.flags));
  if (!(shouldCallBodyOnNonOverridden | shouldCallBodyOnOverridden)) return {};
  const Range<Int> drawnRange =
    span.part != TextLinePart::truncationToken ? styleOverride.drawnRangeInOriginalString
    : styleOverride.drawnRange.rangeInTruncatedString()
      - span.startIndexOfTruncationTokenInTruncatedString;
  const Range<Int> overrideRange =
    span.part != TextLinePart::truncationToken ? styleOverride.overrideRangeInOriginalString
    : styleOverride.overrideRange.rangeInTruncatedString()
      - span.startIndexOfTruncationTokenInTruncatedString;

  const GlyphRunRef run = span.glyphSpan.run();
  const Range<Int> runStringRange = run.stringRange();

  const TextStyle* const nonOverrideStyle = !shouldCallBodyOnNonOverridden ? nullptr : &textStyle;
  const TextStyle* const overrideStyle =
    !shouldCallBodyOnOverridden || !overrideRange.overlaps(runStringRange) ? nullptr
    : ((void)styleOverride.applyTo(textStyle), &styleOverride.style());

  const Int runGlyphCount = run.count();
  span.glyphSpan.assumeFullRunGlyphCountIs(runGlyphCount);
  const Range<Int> glyphIndexRange = span.glyphSpan.glyphRange();
  if (glyphIndexRange.isEmpty()) return {};

  const auto stringIndices = GlyphSpan{run, {0, runGlyphCount}, unchecked}.stringIndicesArray();

  const CTRunStatus runStatus = run.status();
  const bool isRTL = runStatus & kCTRunStatusRightToLeft;
  const bool isNonMonotonic = runStatus & kCTRunStatusNonMonotonic;

  TempArray<Int> sortedStringIndices;
  if (isNonMonotonic) {
    sortedStringIndices = TempArray<Int>{uninitialized, Count{stringIndices.count()},
                                         sortedStringIndices.allocator()};
    array_utils::copyConstructArray(stringIndices, sortedStringIndices.begin());
    sortedStringIndices.sort([](Int lhs, Int rhs){ return lhs < rhs; });
  }

  const int maxLigatureInnerOffsetCount = 15;
  Array<Range<Int>, Fixed, maxLigatureInnerOffsetCount + 1> graphemeClusterStringRanges;
  Array<CGFloat, Fixed, maxLigatureInnerOffsetCount> ligatureInnerOffsets;
  Optional<NSStringRef> string = none;

  Int subspanStartIndex = glyphIndexRange.start;
  Range<Int> subspanStringRange = Range{runStringRange.end, runStringRange.start}; // empty
  bool subspanIsDrawn = false;
  bool subspanIsOverridden = false;
  for (Int glyphIndex = subspanStartIndex, sortedStringIndicesCursor = glyphIndex;;) {
    Range<Int> glyphStringRange{stringIndices[glyphIndex],
                                findGlyphStringEndIndex(
                                  glyphIndex, stringIndices, isRTL, runStringRange.end,
                                  sortedStringIndices.begin(), InOut{sortedStringIndicesCursor})};
    Int ligatureInnerPositionCount = 0;
    bool glyphIsDrawn = drawnRange.overlaps(glyphStringRange);
    bool glyphIsOverridden = overrideRange.overlaps(glyphStringRange);
    {
      const bool glyphIsFullyDrawn = drawnRange.contains(glyphStringRange);
      const bool glyphIsFullyOverridden = overrideRange.contains(glyphStringRange);
      const bool mayNeedToSplitLigature = (glyphIsDrawn & !glyphIsFullyDrawn)
                                        | (glyphIsOverridden & !glyphIsFullyOverridden);
      if (STU_UNLIKELY(mayNeedToSplitLigature)) {
        if (!string) {
          string.emplace(span.attributedString.string);
        }
        ligatureInnerPositionCount = string->copyRangesOfGraphemeClustersSkippingTrailingIgnorables(
                                               glyphStringRange, graphemeClusterStringRanges)
                                   - 1;
        if (ligatureInnerPositionCount != 0) {
          if (glyphStringRange.end < graphemeClusterStringRanges[ligatureInnerPositionCount].end
              || graphemeClusterStringRanges[0].start < glyphStringRange.start)
          {
            // There's likely another glyph whose string range overlaps with glyphStringRange.
            ligatureInnerPositionCount = 0;
          } else if (ligatureInnerPositionCount + 1 > graphemeClusterStringRanges.count()) {
            STU_DEBUG_ASSERT(false && "Is this really an extremely long ligature?");
            ligatureInnerPositionCount = 0;
          } else {
            glyphIsDrawn = drawnRange.overlaps(graphemeClusterStringRanges[0]);
            glyphIsOverridden = overrideRange.overlaps(graphemeClusterStringRanges[0]);
            bool shouldSplitLigature = false;
            for (const auto& r : graphemeClusterStringRanges[{1, ligatureInnerPositionCount + 1}]) {
              if (glyphIsDrawn != drawnRange.contains(r)
                  || glyphIsOverridden != overrideRange.contains(r))
              {
                shouldSplitLigature = true;
                break;
              }
            }
            if (!shouldSplitLigature
                || !GlyphSpan{run, Range{0, runGlyphCount}, unchecked}
                    .copyInnerCaretOffsetsForLigatureGlyphAtIndex(
                       glyphIndex, ligatureInnerOffsets[{0, ligatureInnerPositionCount}]))
            {
              ligatureInnerPositionCount = 0;
            }
          }
        }
      }
    }
    if (ligatureInnerPositionCount == 0 && glyphIndex != subspanStartIndex
        && ((subspanIsDrawn == glyphIsDrawn) & (subspanIsOverridden == glyphIsOverridden)))
    { // The current span continues.
      subspanStringRange = subspanStringRange.convexHull(glyphStringRange);
      ++glyphIndex;
      if (glyphIndex < glyphIndexRange.end) continue;
    }
    if (subspanStartIndex < glyphIndex) {
      span.glyphSpan = GlyphSpan{run, {subspanStartIndex, glyphIndex}, unchecked};
      const Float64 nextX = glyphIndex == glyphIndexRange.end ? maxX
                          : min(minX + span.glyphSpan.typographicWidth(), maxX);
      if (subspanIsDrawn) {
        const TextStyle* const style = subspanIsOverridden ? overrideStyle : nonOverrideStyle;
        if (style) {
          span.stringRange = Range<Int32>{subspanStringRange};
          const auto shouldStop = body(span, *style, Range{minX, nextX});
          if (shouldStop) return shouldStop;
        }
      }
      if (glyphIndex == glyphIndexRange.end) break;
      minX = nextX;
    }
    if (ligatureInnerPositionCount == 0) {
      if (glyphIndex + 1 < glyphIndexRange.end) {
        subspanStartIndex = glyphIndex;
        subspanStringRange = glyphStringRange;
        subspanIsDrawn = glyphIsDrawn;
        subspanIsOverridden = glyphIsOverridden;
        ++glyphIndex;
        continue;
      }
      if (glyphIsDrawn) {
        const TextStyle* const style = glyphIsOverridden ? overrideStyle : nonOverrideStyle;
        if (style) {
          span.glyphSpan = GlyphSpan{run, {glyphIndex, glyphIndex + 1}, unchecked};
          span.stringRange = Range<Int32>{glyphStringRange};
          const auto shouldStop = body(span, *style, Range{minX, maxX});
          if (shouldStop) return shouldStop;
        }
      }
      break;
    }
    span.glyphSpan = GlyphSpan{run, {glyphIndex, glyphIndex + 1}, unchecked};
    const Float64 nextX = glyphIndex + 1 == glyphIndexRange.end ? maxX
                        : min(minX + span.glyphSpan.typographicWidth(), maxX);
    const auto shouldStop = enumerateStyledLigatureSubspans(
                              span, minX, nextX, drawnRange, overrideRange,
                              nonOverrideStyle, overrideStyle, glyphIsDrawn, glyphIsOverridden,
                              graphemeClusterStringRanges, ligatureInnerOffsets,
                              ligatureInnerPositionCount, body);
    if (shouldStop) return shouldStop;
    if (++glyphIndex == glyphIndexRange.end) break;
    minX = nextX;
    subspanStartIndex = glyphIndex;
    subspanStringRange = Range{runStringRange.end, runStringRange.start}; // empty
    continue;
  }
  return {};
}

} // namespace stu_label
