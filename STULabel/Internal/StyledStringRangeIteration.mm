// Copyright 2017–2018 Stephan Tolksdorf

#import "StyledStringRangeIteration.hpp"

#import "GlyphSpan.hpp"
#import "TextFrame.hpp"
#import "UnicodeCodePointProperties.hpp"

namespace stu_label::detail {

struct IsTruncationTokenRange : Parameter<IsTruncationTokenRange> { using Parameter::Parameter; };

STU_INLINE
ShouldStop forEachStyledStringRangeImpl(
             Range<Int32> stringRange, Int32 offsetInTruncatedString,
             IsTruncationTokenRange isTruncationTokenRange,
             InOut<const TextStyle*> inOutStyle, Optional<TextStyleOverride&> styleOverride,
             FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body)
{
  if (stringRange.isEmpty()) return {};
  Int32 index = stringRange.start;
  const TextStyle* style = &inOutStyle->styleForStringIndex(index);
  ShouldStop shouldStop;
  for (;;) {
    const TextStyle& next = style->next();
    const Int32 nextIndex = min(next.stringIndex(), stringRange.end);
    if (styleOverride && styleOverride->overriddenStyle() != style) {
      styleOverride->applyTo(*style);
    }
    shouldStop = body(styleOverride ? styleOverride->style() : *style,
                      {.stringRange = {index, nextIndex},
                       .offsetInTruncatedString = offsetInTruncatedString,
                       .isTruncationTokenRange = isTruncationTokenRange.value});
    if (shouldStop || nextIndex == stringRange.end) break;
    style = &next;
    index = nextIndex;
  }
  inOutStyle = style;
  return shouldStop;
}

STU_INLINE
ShouldStop forEachStyledStringRangeImpl(
             Range<Int32> stringRange, Int32 offsetInTruncatedString,
             IsTruncationTokenRange isTruncationTokenRange,
             InOut<const TextStyle*> inOutStyle,
             Optional<TextStyleOverride&> styleOverride,
             Range<Int32> soDrawnRangeInTruncatedString,
             Range<Int32> soOverrideRangeInTruncatedString,
             FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body)
{
  if (stringRange.isEmpty()) return {};
  Range<Int32> overriddenStringRange{uninitialized};
  if (styleOverride) {
    stringRange.intersect(soDrawnRangeInTruncatedString - offsetInTruncatedString);
    if (stringRange.isEmpty()) return {};
    overriddenStringRange = soOverrideRangeInTruncatedString - offsetInTruncatedString;
    if (!stringRange.overlaps(overriddenStringRange)) {
      styleOverride = none;
    }
  }
  const Int32 i1 = !styleOverride ? stringRange.end
                 : max(stringRange.start, overriddenStringRange.start);
  ShouldStop shouldStop = forEachStyledStringRangeImpl(
                            Range{stringRange.start, i1}, offsetInTruncatedString,
                            isTruncationTokenRange, inOutStyle, nil, body);
  if (!shouldStop && styleOverride) {
    const Int32 i2 = min(overriddenStringRange.end, stringRange.end);
    shouldStop = forEachStyledStringRangeImpl(
                   Range{i1, i2}, offsetInTruncatedString, isTruncationTokenRange,
                   inOutStyle, styleOverride, body);
    if (!shouldStop) {
      shouldStop = forEachStyledStringRangeImpl(
                     Range{i2, stringRange.end}, offsetInTruncatedString,
                     isTruncationTokenRange, inOutStyle, nil, body);
    }
  }
  return shouldStop;
}

STU_NO_INLINE
ShouldStop forEachStyledStringRange(
             const TextFrame& textFrame,
             const TextFrameParagraph& paragraph, Range<Int32> lineIndexRange,
             Optional<TextStyleOverride&> styleOverride,
             FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body)
{
  STU_DEBUG_ASSERT(paragraph.lineIndexRange().contains(lineIndexRange));
  if (lineIndexRange.isEmpty()) return {};
  const TextFrameLine& firstLine = textFrame.lines()[lineIndexRange.start];
  const TextFrameLine& lastLine = textFrame.lines()[lineIndexRange.end - 1];
  const TextStyle* style = &textFrame.firstNonTokenTextStyleForLineAtIndex(lineIndexRange.start);
  const TextStyle* tokenStyle = &textFrame.firstTokenTextStyleForLineAtIndex(lineIndexRange.end - 1);
  const Range<Int32> range1 = {firstLine.rangeInOriginalString.start,
                               paragraph.excisedRangeInOriginalString().start};
  const Range<Int32> range2 = {paragraph.excisedRangeInOriginalString().end,
                               lastLine.rangeInOriginalString.end};
  const Int32 range1OffsetInTruncatedString = firstLine.rangeInTruncatedString.start
                                            - firstLine.rangeInOriginalString.start;
  const Int32 range2OffsetInTruncatedString = lastLine.rangeInTruncatedString.end
                                            - lastLine.rangeInOriginalString.end;
  Range<Int32> drawnRangeInTruncatedString{uninitialized};
  Range<Int32> overrideRangeInTruncatedString{uninitialized};
  if (styleOverride) {
    drawnRangeInTruncatedString = styleOverride->drawnRange.rangeInTruncatedString();
    overrideRangeInTruncatedString = styleOverride->overrideRange.rangeInTruncatedString();
  }
  ShouldStop shouldStop = forEachStyledStringRangeImpl(
                            range1, range1OffsetInTruncatedString, IsTruncationTokenRange{false},
                            InOut{style}, styleOverride, drawnRangeInTruncatedString,
                            overrideRangeInTruncatedString, body);
  if (!shouldStop && STU_UNLIKELY(range1.end < range2.start)) {
    shouldStop = forEachStyledStringRangeImpl(
                   {0, paragraph.truncationTokenLength},
                   paragraph.rangeOfTruncationTokenInTruncatedString().start,
                   IsTruncationTokenRange{true}, InOut{tokenStyle}, styleOverride,
                   drawnRangeInTruncatedString, overrideRangeInTruncatedString, body);
    if (!shouldStop) {
      shouldStop = forEachStyledStringRangeImpl(
                     range2, range2OffsetInTruncatedString, IsTruncationTokenRange{false},
                     InOut{style}, styleOverride,
                     drawnRangeInTruncatedString, overrideRangeInTruncatedString,
                     body);
    }
  }
  return shouldStop;
}

} // namespace stu_label
