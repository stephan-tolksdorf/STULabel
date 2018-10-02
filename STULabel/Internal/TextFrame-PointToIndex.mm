// Copyright 2018 Stephan Tolksdorf

#import "TextFrame.hpp"

namespace stu_label {

auto TextFrame::rangeOfGraphemeClusterClosestTo(Point<Float64> point,
                                                TextFrameOrigin unscaledTextFrameOrigin,
                                                CGFloat displayScaleValue) const
  -> GraphemeClusterRange
{
  if (this->lineCount == 0 || this->maxX <= this->minX) {
  Empty:
    const TextFrameIndex index = range().start;
    return {.range = {index, index},
            .bounds = CGRectZero,
            .writingDirection = paragraphs().isEmpty() ? STUWritingDirectionLeftToRight
                              : paragraphs()[0].baseWritingDirection,
            .isLigatureFraction = false};
  }

  Point<Float64> origin = unscaledTextFrameOrigin.value;

  if (this->textScaleFactor < 1) {
    displayScaleValue *= this->textScaleFactor;
    const Float64 inverseScaleFactor = 1.0/this->textScaleFactor;
    point.x *= inverseScaleFactor;
    point.y *= inverseScaleFactor;
    origin.x *= inverseScaleFactor;
    origin.y *= inverseScaleFactor;
  }
  const Optional<DisplayScale> displayScale = DisplayScale::create(displayScaleValue);

  const Float64 e = displayScale ? displayScale->inverseValue_f64() : 0.5;
  Range<Int> lineIndexRange = verticalSearchTable().indexRange(
                                narrow_cast<Range<Float32>>(point.y - origin.y + Range{-e, e}));
  const auto lines = this->lines();
  if (lineIndexRange.isEmpty()) {
    if (lineIndexRange.start > 0) {
      lineIndexRange.end = lineIndexRange.start;
      lineIndexRange.start -= 1;
    } else if (lineIndexRange.end < lines.count()) {
      lineIndexRange.start = lineIndexRange.end;
      lineIndexRange.end += 1;
    } else {
      STU_DEBUG_ASSERT(false && "we shouldn't get here");
      goto Empty;
    }
  }
  while (lineIndexRange.start > 0 && lines[lineIndexRange.start].width == 0) {
    lineIndexRange.start -= 1;
  }
  while (lineIndexRange.end < lines.count() && lines[lineIndexRange.end - 1].width == 0) {
    lineIndexRange.end += 1;
  }

  Int closestLineIndex = -1;
  Float64 closestSquaredDistance = infinity<Float64>;
  Float64 closestYDistanceFromLineCenter = infinity<Float64>;

  const auto updateClosestLineIndex = [&](const TextFrameLine& line) {
    if (line.width == 0) return;
    const auto lineBounds = line.typographicBounds(TextFrameOrigin{origin}, displayScale);
    const auto squaredDistance = lineBounds.squaredDistanceTo(point);
    const auto yDistanceFromLineCenter = abs(point.y - lineBounds.y.center());
    if (squaredDistance < closestSquaredDistance
        || (squaredDistance == closestSquaredDistance
            && yDistanceFromLineCenter < closestYDistanceFromLineCenter))
    {
      closestLineIndex = line.lineIndex;
      closestSquaredDistance = squaredDistance;
      closestYDistanceFromLineCenter = yDistanceFromLineCenter;
    }
  };

  for (const auto& line : lines[lineIndexRange]) {
    updateClosestLineIndex(line);
  }
  if (closestLineIndex < 0) {
    STU_DEBUG_ASSERT(false && "we shouldn't get here");
    goto Empty;
  }
  // If the point lies outside the typographic bounds of any line, a glyph in a line above or below
  // the point might be closest.
  if (0 < closestSquaredDistance) {
    const auto yRange = point.y + Range<Float64>{}.outsetBy(sqrt(closestSquaredDistance) + e);
    const auto lineIndexRange2 = verticalSearchTable().indexRange(Range<Float32>{yRange - origin.y});
    for (const auto& line : lines[{lineIndexRange2.start, lineIndexRange.start}].reversed()) {
      updateClosestLineIndex(line);
    }
    for (const auto& line : lines[{lineIndexRange.end, lineIndexRange2.end}]) {
      updateClosestLineIndex(line);
    }
  }

  const TextFrameLine& line = lines[closestLineIndex];
  auto result = line.rangeOfGraphemeClusterAtXOffset(point.x - origin.x - line.originX);
  result.bounds.x += line.originX;
  Float64 baseline = line.originY;
  if (displayScale) {
    baseline = ceilToScale(baseline, *displayScale);
  }
  result.bounds.y += baseline;
  result.bounds *= this->textScaleFactor;
  result.bounds += unscaledTextFrameOrigin.value;
  return result;
}

auto TextFrameLine::rangeOfGraphemeClusterAtXOffset(Float64 xOffset) const
  -> TextFrame::GraphemeClusterRange
{
  const CGFloat width = this->width;
  // Currently we always ignore any trailing whitespace.
  xOffset = clamp(0, xOffset, width);
  const TextFrame& tf = this->textFrame();
  const TextFrameParagraph& para = tf.paragraphs()[this->paragraphIndex];

  Range<Int32> rangeInOriginalString = this->rangeInOriginalString;
  Range<TextFrameCompactIndex> range{};
  STUWritingDirection writingDirection;
  Range<Float64> xOffsetBounds = Range<CGFloat>::infinitelyEmpty();
  bool isLigatureFraction = false;

  forEachStyledGlyphSpan(none,
    [&](const StyledGlyphSpan& span, const TextStyle&, Range<Float64> spanXOffset) -> ShouldStop
  {
    // We only need to look at a single span.
    if (!spanXOffset.contains(xOffset) && (xOffset < width || spanXOffset.end < width)) return {};
    const GlyphSpan glyphSpan = span.glyphSpan;
    if (glyphSpan.isEmpty()) return {};
    if (span.part == TextLinePart::insertedHyphen) {
      const Int32 index = rangeInTruncatedString.end - 1;
      range.start = TextFrameCompactIndex{index, IsIndexOfInsertedHyphen{true}};
      range.end = TextFrameCompactIndex{index + 1, IsIndexOfInsertedHyphen{false}};
      rangeInOriginalString.start = rangeInOriginalString.end;
      writingDirection = paragraphBaseWritingDirection;
      xOffsetBounds = spanXOffset;
      return stop;
    }
    writingDirection = glyphSpan.run().writingDirection();

    Int glyphIndex = 0;
    Float64 glyphXOffset = spanXOffset.start;
    {
      const Int lastGlyphIndex = glyphSpan.count() - 1;
      for (Float64 nextGlyphXOffset; glyphIndex < lastGlyphIndex;
           ++glyphIndex, glyphXOffset = nextGlyphXOffset)
      {
        nextGlyphXOffset = glyphXOffset + glyphSpan[{glyphIndex, Count{1}}].typographicWidth();
        if (xOffset < nextGlyphXOffset) break;
      }
    }

    Range<Int> stringRange = span.glyphSpan[{glyphIndex, glyphIndex + 1}].stringRange();

    const auto string = NSStringRef{span.attributedString.string};

    const int maxInnerOffsetCount = 15;
    Array<Range<Int>, Fixed, maxInnerOffsetCount + 1> graphemeClusterStringRanges;

    const Int graphemeClusterCount = string.copyRangesOfGraphemeClustersSkippingTrailingIgnorables(
                                              stringRange, graphemeClusterStringRanges);
    if (graphemeClusterCount == 1) {
      stringRange = graphemeClusterStringRanges[0];
    } else if (graphemeClusterStringRanges[0].start < stringRange.start
               || stringRange.end < graphemeClusterStringRanges[graphemeClusterCount - 1].end)
    { // There's likely another glyph whose string range overlaps with stringRange.
      stringRange.start = graphemeClusterStringRanges[0].start;
      stringRange.end = graphemeClusterStringRanges[graphemeClusterCount - 1].end;
    } if (1 < graphemeClusterCount && graphemeClusterCount - 1 <= maxInnerOffsetCount) {
      Array<CGFloat, Fixed, maxInnerOffsetCount> ligatureInnerOffsets;
      if (span.glyphSpan.copyInnerCaretOffsetsForLigatureGlyphAtIndex(
                           glyphIndex, ligatureInnerOffsets[{0, graphemeClusterCount - 1}]))
      {
        const Float64 innerOffset = xOffset - glyphXOffset;
        Int i = 0;
        for (; i < graphemeClusterCount - 1; ++i) {
          if (innerOffset < ligatureInnerOffsets[i]) break;
        }
        stringRange = graphemeClusterStringRanges[i];
      }
    }

    // For simplicity we don't try to determine the outer X bounds for the grapheme cluster here.
    // Instead we will calculate the bounds below by iterating over the line again (with the
    // iteration restricted to the grapheme cluster's string range).

    Int offsetInTruncatedString;
    if (span.part == TextLinePart::originalString) {
      if (stringRange.start < para.excisedRangeInOriginalString().start) {
        stringRange.intersect(Range{rangeInOriginalString.start,
                                    para.excisedRangeInOriginalString().start});
        offsetInTruncatedString = this->rangeInTruncatedString.start
                                - this->rangeInOriginalString.start;
      } else {
        stringRange.intersect(Range{para.excisedRangeInOriginalString().end,
                                    rangeInOriginalString.end});
        offsetInTruncatedString = this->rangeInTruncatedString.end
                                - this->rangeInOriginalString.end;
      }
      rangeInOriginalString = Range<Int32>{stringRange};
    } else {
      STU_DEBUG_ASSERT(span.part == TextLinePart::truncationToken);
      rangeInOriginalString = para.excisedRangeInOriginalString();
      offsetInTruncatedString = span.startIndexOfTruncationTokenInTruncatedString;
    }

    stringRange += offsetInTruncatedString;
    range.start = TextFrameCompactIndex(narrow_cast<Int32>(stringRange.start));
    range.end = TextFrameCompactIndex(narrow_cast<Int32>(stringRange.end));

    return stop;
  });

  if (STU_UNLIKELY(range.isEmpty())) {
    return {.range = this->range(),
            .bounds = {},
            .writingDirection = paragraphBaseWritingDirection,
            .isLigatureFraction = false};
  }

  if (xOffsetBounds.isEmpty()) {
    bool leftEndOfLigatureIsClipped = false;
    bool rightEndOfLigatureIsClipped = false;
    TextStyleOverride styleOverride{Range{lineIndex, Count{1}}, rangeInOriginalString, range};
    forEachStyledGlyphSpan(styleOverride,
      [&](const StyledGlyphSpan& span, const TextStyle&, Range<Float64> xOffset)
    {
      if (xOffsetBounds.isEmpty()) {
        leftEndOfLigatureIsClipped = span.leftEndOfLigatureIsClipped;
      }
      rightEndOfLigatureIsClipped = span.rightEndOfLigatureIsClipped;
      xOffsetBounds = xOffsetBounds.convexHull(xOffset);
    });
    isLigatureFraction = leftEndOfLigatureIsClipped || rightEndOfLigatureIsClipped;
  }

  return {.range = {range.start.withLineIndex(lineIndex), range.end.withLineIndex(lineIndex)},
          .bounds = {xOffsetBounds, {-(ascent + leading/2), (descent + leading/2)}},
          .writingDirection = writingDirection,
          .isLigatureFraction = isLigatureFraction};
}

} // namespace stu_label
