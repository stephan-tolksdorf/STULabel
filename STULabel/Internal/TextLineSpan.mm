// Copyright 2017–2018 Stephan Tolksdorf

#import "TextLineSpan.hpp"

#import "TextFrame.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

struct LineSpanBuffer {
  TempVector<TextLineSpan> spans;

  /// Ensures that the x ranges for spans on the same line are monotonically increasing.
  /// Merges adjacent spans with the same range index.
  ///
  /// @note Expects spans to be added left to right.
  void add(TextLineSpan span) {
    span.x.end = max(span.x.start, span.x.end);
    if (!spans.isEmpty()) {
      TextLineSpan& last = spans[$ - 1];
      if (last.lineIndex == span.lineIndex) {
        if (last.x.end >= span.x.start) {
          span.x.end = max(last.x.end, span.x.end);
          if (last.rangeIndex == span.rangeIndex) {
            last.x.end = span.x.end;
            last.isRightEndOfLine = span.isRightEndOfLine;
            return;
          }
        }
      }
    }
    spans.append(span);
  }

  operator TempArray<TextLineSpan>() && { return std::move(spans); }
  operator TempVector<TextLineSpan>() && { return std::move(spans); }
};

TempArray<TextLineSpan>
  TextFrame::lineSpans(STUTextFrameRange range,
                       Optional<FunctionRef<bool(const TextStyle&)>> predicate) const
{
  TextStyleOverride styleOverride{*this, range, nil};
  const Range<Int32> rangeInTruncatedString = styleOverride.drawnRange.rangeInTruncatedString();
  LineSpanBuffer spans;
  for (auto& line : lines()[styleOverride.drawnLineRange]) {
      const auto lineX = line.originX;
      const auto lineWidth = line.width;
      if (lineWidth > 0) {
        line.forEachStyledGlyphSpan(&styleOverride,
          [&](const StyledGlyphSpan&, const TextStyle& style, Range<Float64> x)
        {
          if (STU_UNLIKELY(x.isEmpty())) return;
          if (predicate && !predicate(style)) return;
          spans.add(TextLineSpan{.x = {lineX + x.start, lineX + x.end},
                                 .isLeftEndOfLine = x.start == 0,
                                 .lineIndex = sign_cast(line.lineIndex),
                                 .isRightEndOfLine = x.end == lineWidth});
        });
      } else { // lineWidth <= 0
        const Range<Int32> r = line.rangeInTruncatedStringIncludingTrailingWhitespace();
        if (!rangeInTruncatedString.contains(r)) continue;
        if (predicate && !predicate(firstNonTokenTextStyleForLineAtIndex(line.lineIndex))) continue;
        spans.add(TextLineSpan{.x = {lineX, lineX},
                               .isLeftEndOfLine = true,
                               .lineIndex = sign_cast(line.lineIndex),
                               .isRightEndOfLine = true});
      }
  }
  return std::move(spans);
}
  
Int adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(ArrayRef<TextLineSpan> spans,
                                                           HorizontalInsets insets)
{
  Int n = 0;
  UInt32 lineIndex = maxValue<UInt32>;
  Float64 previousEnd = minValue<Float64>;
  for (TextLineSpan span : spans) {
    const bool wasEmpty = span.x.start == span.x.end;
    span.x.start += insets.left;
    span.x.end   -= insets.right;
    if (STU_UNLIKELY(!(span.x.start < span.x.end))) {
      if (!wasEmpty) continue; // Removes span.
    }
    if (previousEnd < span.x.start || lineIndex != span.lineIndex) {
      spans[n++] = span;
    } else {
      spans[n - 1].x.end = span.x.end;
      spans[n - 1].isRightEndOfLine = span.isRightEndOfLine;
    }
    lineIndex = span.lineIndex;
    previousEnd = span.x.end;
  }
  return n;
}

void extendTextLinesToCommonHorizontalBounds(ArrayRef<TextLineSpan> spans) {
  Float64 minX =  infinity<Float64>;
  Float64 maxX = -infinity<Float64>;
  for (auto& span : spans) {
    if (span.isLeftEndOfLine) {
      minX = min(minX, span.x.start);
    }
    if (span.isRightEndOfLine) {
      maxX = max(maxX, span.x.end);
    }
  }
  if (minX == infinity<Float64> && maxX == -infinity<Float64>) return;
  for (auto& span : spans) {
    if (span.isLeftEndOfLine) {
      span.x.start = minX;
    }
    if (span.isRightEndOfLine) {
      span.x.end = maxX;
    }
  }
}

using detail::everyRunFlag;

static TempArray<TaggedStringRange> findTaggedStringRanges(
                                      ArrayRef<const TextFrameParagraph> paragraphs,
                                      Range<Int32> fullRangeInTruncatedString,
                                      Optional<TextStyleOverride&> styleOverride,
                                      TextFlags tagTextFlagsMask,
                                      SeparateParagraphs separateParagraphs,
                                      FunctionRef<UInt(const TextStyle& style)> tagger,
                                      Optional<FunctionRef<bool(UInt, UInt)>> tagEquality)
{
  if (!tagTextFlagsMask) {
    tagTextFlagsMask = everyRunFlag;
  }
  TempVector<TaggedStringRange> buffer{MaxInitialCapacity{256}};
  UInt32 tagIndex = 0;
  for (const TextFrameParagraph& para : paragraphs) {
    if (!(tagTextFlagsMask & para.effectiveTextFlags(everyRunFlag, styleOverride))) {
      continue;
    }
    para.forEachStyledStringRange(styleOverride,
      [&](const TextStyle& style, StyledStringRange range)
    {
      if (!(tagTextFlagsMask & (style.flags() | everyRunFlag))) return;
      const Range<Int32> rangeInTruncatedString = range.stringRange + range.offsetInTruncatedString;
      if (!rangeInTruncatedString.overlaps(fullRangeInTruncatedString)) return;
      const UInt tag = tagger(style);
      if (!tag) return;
      if (!buffer.isEmpty()) {
        const TaggedStringRange& last = buffer[$ - 1];
        if (!(   (!separateParagraphs ||  para.paragraphIndex == last.paragraphIndex)
              && rangeInTruncatedString.start == last.rangeInTruncatedString.end
              && (tag == last.tag || (tagEquality && tagEquality(tag, last.tag)))))
        {
          ++tagIndex;
        }
      }
      buffer.append(TaggedStringRange{
                      .rangeInTruncatedString = rangeInTruncatedString,
                      .rangeInOriginalString = !range.isTruncationTokenRange ? range.stringRange
                                             : para.excisedRangeInOriginalString(),
                      .paragraphIndex = para.paragraphIndex,
                      .tagIndex = tagIndex,
                      .tag = tag,
                      .taggedNonOverriddenStylePointer_ =
                        !style.isOverrideStyle() ? reinterpret_cast<UInt>(&style)
                        : (reinterpret_cast<UInt>(styleOverride->overriddenStyle()) | 1)
                    });
    });
  }
  return std::move(buffer);
}

static Int32 indexOfTaggedRange(Int32 indexInTruncatedString,
                                ArrayRef<const TaggedStringRange> ranges,
                                Int32 previousRangeIndex)
{
  Int32 i = previousRangeIndex;
  while (indexInTruncatedString >= ranges[i].rangeInTruncatedString.end) {
    ++i;
    if (i == ranges.count()) return -1;
  }
  while (indexInTruncatedString < ranges[i].rangeInTruncatedString.start) {
    if (i == 0) return -1;
    --i;
  }
  return i;
}

static TempVector<TextLineSpan> findTaggedLineSpansForRanges(
                                  ArrayRef<const TextFrameParagraph> paragraphs,
                                  Range<Int32> lineIndexRange,
                                  Optional<TextStyleOverride&> styleOverride,
                                  ArrayRef<TaggedStringRange> ranges,
                                  TextFlags tagStyleFlagMask)
{
  if (paragraphs.isEmpty() || ranges.isEmpty()) {
    return {};
  }
  if (!tagStyleFlagMask) {
    tagStyleFlagMask |= everyRunFlag;
  }
  const TextFrame& textFrame = paragraphs[0].textFrame();
  const ArrayRef<const TextFrameLine> lines = textFrame.lines();
  LineSpanBuffer buffer;
  Int32 previousTaggedRangeIndex = 0;
  for (const TextFrameParagraph& para : paragraphs) {
    if (!(tagStyleFlagMask & para.effectiveTextFlags(everyRunFlag, styleOverride))) {
      continue;
    }
    for (const TextFrameLine& line : lines[para.lineIndexRange().intersection(lineIndexRange)]) {
      if (!(tagStyleFlagMask & line.effectiveTextFlags(everyRunFlag, styleOverride))) {
        continue;
      }
      const auto lineX = line.originX;
      const auto lineWidth = line.width;
      if (STU_UNLIKELY(lineWidth <= 0)) {
        // If the line is empty and the line's range in the truncated string including the trailing
        // whitespace is contained in a single tagged range, we add an empty span.
        const Int32 taggedRangeIndex = indexOfTaggedRange(line.rangeInTruncatedString.start,
                                                          ranges, previousTaggedRangeIndex);
        if (taggedRangeIndex < 0) continue;
        previousTaggedRangeIndex = taggedRangeIndex;
        const Range<Int32> r = line.rangeInTruncatedStringIncludingTrailingWhitespace();
        TaggedStringRange& range = ranges[taggedRangeIndex];
        if (!range.rangeInTruncatedString.contains(r)) continue;
        range.hasSpan = true;
        buffer.add(TextLineSpan{.x = {lineX, lineX},
                                .isLeftEndOfLine = true,
                                .lineIndex = sign_cast(line.lineIndex),
                                .isRightEndOfLine = true,
                                .rangeIndex = sign_cast(taggedRangeIndex)});
        continue;
      }
      line.forEachStyledGlyphSpan(styleOverride,
        [&](const StyledGlyphSpan& span, const TextStyle& style, Range<Float64> x)
      {
        if (!(tagStyleFlagMask & (style.flags() | everyRunFlag))) return;
        if (x.isEmpty()) return;
        if (buffer.spans.count() == IntegerTraits<Int32>::max) return;
        const Int32 indexInTruncatedString = span.rangeInTruncatedString().start
                                           - (span.part == TextLinePart::insertedHyphen);
        const Int32 taggedRangeIndex = indexOfTaggedRange(indexInTruncatedString,
                                                          ranges, previousTaggedRangeIndex);
        if (taggedRangeIndex < 0) return;
        previousTaggedRangeIndex = taggedRangeIndex;
        TaggedStringRange& range = ranges[taggedRangeIndex];
        range.hasSpan = true;
        buffer.add(TextLineSpan{.x = {lineX + x.start, lineX + x.end},
                                .isLeftEndOfLine = x.start == 0,
                                .lineIndex = sign_cast(line.lineIndex),
                                .isRightEndOfLine = x.end == lineWidth,
                                .rangeIndex = sign_cast(taggedRangeIndex)});
      });
    }
  }
  return std::move(buffer);
}

TaggedRangeLineSpans findAndSortTaggedRangeLineSpans(
                       ArrayRef<const TextFrameLine> lines,
                       Optional<TextStyleOverride&> styleOverride,
                       TextFlags tagStyleFlagMask,
                       SeparateParagraphs separateParagraphs,
                       FunctionRef<UInt(const TextStyle& style)> tagger,
                       Optional<FunctionRef<bool(UInt, UInt)>> tagEquality)
{
  if (lines.isEmpty()) return TaggedRangeLineSpans{};
  const TextFrame& textFrame = lines[0].textFrame();
  const auto paragraphs = textFrame.paragraphs()[{lines[0].paragraphIndex,
                                                  lines[$ - 1].paragraphIndex + 1}];
  const Range<Int32> lineIndexRange = {lines[0].lineIndex, lines[$ - 1].lineIndex + 1};
  const Range<Int32> rangeInTruncatedString = {
    lines[0].rangeInTruncatedString.start, lines[$ - 1].rangeInTruncatedString.end
  };
  TempArray<TaggedStringRange> ranges = findTaggedStringRanges(paragraphs, rangeInTruncatedString,
                                                               styleOverride, tagStyleFlagMask,
                                                               separateParagraphs,
                                                               tagger, tagEquality);
  TempVector<TextLineSpan> spans = findTaggedLineSpansForRanges(paragraphs, lineIndexRange,
                                                                styleOverride, Ref{ranges},
                                                                tagStyleFlagMask);

  Int32 spanTagCount = 0;
  if (!spans.isEmpty()) {
    UInt32 previousTagIndex = maxValue<UInt32>;
    STU_DISABLE_LOOP_UNROLL
    for (const auto& range : ranges) {
      spanTagCount += range.hasSpan && range.tagIndex != previousTagIndex;
      previousTagIndex = range.tagIndex;
    }
    std::sort(spans.begin(), spans.end(),
              [&](const TextLineSpan& span1, const TextLineSpan& span2) -> bool {
                const TaggedStringRange& range1 = ranges[span1.rangeIndex];
                const TaggedStringRange& range2 = ranges[span2.rangeIndex];
                if (range1.tagIndex != range2.tagIndex) {
                  return range1.tagIndex < range2.tagIndex;
                }
                if (span1.lineIndex != span2.lineIndex) {
                  return span1.lineIndex < span2.lineIndex;
                }
                return span1.x.start < span2.x.start;
              });
    if (spans.count() > spanTagCount) { // Fuse spans that have no gap and the same tagIndex.
      TextLineSpan* last = &spans[0];
      for (auto& span : spans[{1, $}]) {
        if (last->lineIndex == span.lineIndex && last->x.end == span.x.start
            && ranges[last->rangeIndex].tagIndex == ranges[span.rangeIndex].tagIndex)
        {
          last->x.end = span.x.end;
          last->isRightEndOfLine = span.isRightEndOfLine;
        } else {
          ++last;
          if (last != &span) {
            *last = span;
          }
        }
      }
      const Int n = last + 1 - spans.begin();
      spans.removeLast(spans.count() - n);
    }
  }
  return {.ranges = std::move(ranges), .spans = std::move(spans), .spanTagCount = spanTagCount};
}

} // stu_label

