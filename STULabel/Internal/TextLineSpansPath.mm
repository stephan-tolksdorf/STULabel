// Copyright 2017–2018 Stephan Tolksdorf

#import "TextLineSpansPath.hpp"

#import "TextFrame.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

STU_INLINE
Rect<Float64> calculateSingleTextLineBounds(
                const ArrayRef<const TextLineSpan> spans,
                const ArrayRef<const TextLineVerticalPosition> verticalPositions,
                const InOut<Int> inOutSpanIndex)
{
  Int i = inOutSpanIndex;
  const Int32 lineIndex = spans[i].lineIndex;
  const Float64 startX = spans[i].x.start;
  for (; i < spans.count(); ++i) {
    if (spans[i].lineIndex != lineIndex) break;
  }
  const Float64 endX = spans[i - 1].x.end;
  inOutSpanIndex = i;
  return {Range{startX, endX}, verticalPositions[lineIndex].y()};
}

TextLineSpansPathBounds calculateTextLineSpansPathBounds(
                          const ArrayRef<const TextLineSpan> spans,
                          const ArrayRef<const TextLineVerticalPosition> verticalPositions)
{
  STU_ASSERT(!spans.isEmpty());
  if (spans.count() == 1) {
    const auto& span = spans[0];
    return {Rect{span.x, verticalPositions[span.lineIndex].y()},
            .pathExtendedToCommonHorizontalTextLineBoundsIsRect = true};
  }
  Int i = 0;
  bool textLineEndsIncluded = spans[0].isLeftEndOfLine;
  Rect<Float64> bounds = calculateSingleTextLineBounds(spans, verticalPositions, InOut{i});
  textLineEndsIncluded &= spans[i - 1].isRightEndOfLine;
  bool xBoundsAreEqual = true;
  while (i < spans.count()) {
    xBoundsAreEqual      &= spans[i].x.start == bounds.x.start;
    textLineEndsIncluded &= spans[i].isLeftEndOfLine;
    bounds = bounds.convexHull(calculateSingleTextLineBounds(spans, verticalPositions, InOut{i}));
    xBoundsAreEqual      &= spans[i - 1].x.end == bounds.x.end;
    textLineEndsIncluded &= spans[i - 1].isRightEndOfLine;
  }
  const bool isRect = textLineEndsIncluded | xBoundsAreEqual;
  return {bounds, .pathExtendedToCommonHorizontalTextLineBoundsIsRect = isRect};
}

// To construct a CGPath for the outlines of the sequence of text line spans we build an
// intermediate buffer containing all vertices (4 corners for each span). The vertices are
// organized into n + 1 logical lines, where n is the number of text lines. The first vertex line
// represents the top of the first text line. The following vertex lines, ordered from
// top to bottom, each represent the corresponding boundary between two text lines. The final
// vertex line represents the bottom of the last text line. Within each vertex line
// the vertices are ordered left to right. The Y-coordinate of a vertex is either the bottom
// of the text line above or the top of the of text line below the vertex.
//
// Each vertex is an endpoint of two edges in the path, one horizontal and one vertical. In effect,
// the path is pieced together from a sequence of right angles, though some of these "angles" may
// have a degenerate horizontal edge with a length of 0.
//
struct Vertex {
  bool isLeftEndpointOfHorizontalEdge : 1;
  bool isTopOfTextLine : 1;
  bool isFirstInVertexLine : 1;
  bool isVisited : 1;
  UInt indexOfVertexConnectedByVerticalEdge : sizeof(UInt)*8 - 4;
  CGFloat x;

  static_assert(sizeof(UInt) == sizeof(CGFloat));
};
static_assert(sizeof(Vertex) == 2*sizeof(CGFloat));

struct IsTopOfTextLine : Parameter<IsTopOfTextLine> { using Parameter::Parameter; };

STU_INLINE
Range<CGFloat> textLineY(const TextLineVerticalPosition vp, const VerticalEdgeInsets insets) {
  Range<Float32> y{insets.top - vp.ascent, vp.descent - insets.bottom};
  if (STU_UNLIKELY(y.isEmpty())) {
    y.start = (y.start + y.end)/2;
    y.end = y.start;
  }
  return narrow_cast<CGFloat>(vp.baseline) + y;
}

STU_INLINE
CGFloat vertexLineY(const ArrayRef<const TextLineVerticalPosition> verticalPositions,
                    const Int vertexLineIndex, const IsTopOfTextLine isTop,
                    const VerticalEdgeInsets insets)
{
  const Int textLineIndex = vertexLineIndex - !isTop;
  const Range<CGFloat> y = textLineY(verticalPositions[textLineIndex], insets);
  return isTop ? y.start : y.end;
}

struct MarkVerticalEdgesVisited : Parameter<MarkVerticalEdgesVisited> {
  using Parameter::Parameter;
};
struct VertexLineIndex : Parameter<VertexLineIndex, Int> {
  using Parameter::Parameter;
  using Parameter::operator=;
};

struct HorizontalEdge {
  Pair<Int, Int> vertexIndices;
  Int vertexLineIndex;
};

STU_INLINE
HorizontalEdge getNondegenerateHorizontalEdgeVerticallyConnectedToVertexAt(
                 const MarkVerticalEdgesVisited markVerticalEdgesVisited,
                 const ArrayRef<Vertex> vertices,
                 Int i, VertexLineIndex lineIndex)
{
  const CGFloat x = vertices[i].x;
  for (;;) {
    if (markVerticalEdgesVisited) {
      vertices[i].isVisited = true;
    }
    const Int i1 = sign_cast(vertices[i].indexOfVertexConnectedByVerticalEdge);
    const Int lineIndex1 = lineIndex.value + (i1 > i ? 1 : -1);
    STU_ASSERT(vertices[i1].x == x);
    if (markVerticalEdgesVisited) {
      STU_ASSERT(!vertices[i1].isVisited);
      vertices[i1].isVisited = true;
    }
    const Int i2 = i1 + (vertices[i1].isLeftEndpointOfHorizontalEdge ? 1 : -1);
    STU_DEBUG_ASSERT(vertices[i1].isTopOfTextLine == vertices[i2].isTopOfTextLine);
    if (vertices[i2].x == x) {
      i = i2;
      lineIndex = lineIndex1;
      continue;
    }
    return HorizontalEdge{.vertexIndices = {i1, i2}, .vertexLineIndex = lineIndex1};
  }
}

static void addVertexPath(CGMutablePath& path,
                          const ArrayRef<Vertex> vertices,
                          const ArrayRef<const TextLineVerticalPosition> verticalPositions,
                          const VerticalEdgeInsets verticalInsets,
                          const CornerRadius cornerRadius,
                          const CGAffineTransform* __nullable const transform)
{
  STU_DEBUG_ASSERT(cornerRadius >= 0);
  for (Int i0 = 0, lineIndex = -1; i0 < vertices.count(); ++i0) {
    if (vertices[i0].isFirstInVertexLine) {
      ++lineIndex;
    }
    if (vertices[i0].isVisited) continue;

    STU_DEBUG_ASSERT(vertices[i0].isLeftEndpointOfHorizontalEdge);
    STU_DEBUG_ASSERT(   !vertices[i0 + 1].isVisited
                     && !vertices[i0 + 1].isFirstInVertexLine);
    STU_DEBUG_ASSERT(vertices[i0].isTopOfTextLine == vertices[i0 + 1].isTopOfTextLine);

    bool isFirst = true;
    const bool clockWise = vertices[i0].isTopOfTextLine;
    i0 += clockWise ? 1 : 0;

    Int i = i0 ;
    CGFloat x1 = vertices[i].x;
    CGFloat y1 = vertexLineY(verticalPositions, lineIndex,
                             IsTopOfTextLine{vertices[i].isTopOfTextLine}, verticalInsets);
    CGFloat dx = 0, rx = 0;
    if (cornerRadius != 0) {
      dx = x1 - vertices[i - (clockWise ? 1 : -1)].x;
      rx = min(abs(dx/2), cornerRadius.value);
    }
    do {
      const HorizontalEdge hl = getNondegenerateHorizontalEdgeVerticallyConnectedToVertexAt(
                                  MarkVerticalEdgesVisited{true},
                                  vertices, i, VertexLineIndex{lineIndex});
      const Int i2 = hl.vertexIndices.second;
      lineIndex = hl.vertexLineIndex;
      const CGFloat x2 = vertices[i2].x;
      const CGFloat y2 = vertexLineY(verticalPositions, lineIndex,
                                     IsTopOfTextLine{vertices[i2].isTopOfTextLine}, verticalInsets);
      if (cornerRadius == 0) {
        if (isFirst) {
          isFirst = false;
          CGPathMoveToPoint(&path, transform, x1, y1);
        } else {
          CGPathAddLineToPoint(&path, transform, x1, y1);
        }
        CGPathAddLineToPoint(&path, transform, x1, y2);
      } else {
        const CGFloat dy = y2 - y1;
        const CGFloat ry = abs(dy/2);
        CGFloat r = min(rx, ry);
        if (isFirst) {
          isFirst = false;
          CGPathMoveToPoint(&path, transform, x1 - dx/2, y1);
        }
        CGPathAddArcToPoint(&path, transform, x1, y1, x1, y2, r);
        dx = x2 - x1;
        rx = min(abs(dx/2), cornerRadius.value);
        r = min(rx, ry);
        CGPathAddArcToPoint(&path, transform, x1, y2, x2, y2, r);
      }
      x1 = x2;
      y1 = y2;
      i = i2;
    } while (i != i0);
    CGPathCloseSubpath(&path);
  }
}

class VertexBuffer {
public:
  void addVerticesForSpans(ArrayRef<const TextLineSpan> spans);

  STU_INLINE ArrayRef<Vertex> vertices() { return vector_; }

  explicit VertexBuffer(ThreadLocalAllocatorRef allocator)
  : vector_{allocator} {}
private:
  TempVector<Vertex> vector_;
  bool isFirstInLine_;

  struct SpanUpperVertexIndices { Int start, end; };

  struct SpanAndUpperVertexIndices {
    const TextLineSpan& span;
    SpanUpperVertexIndices& upperVertexIndices;

    STU_INLINE
    Pair<Float64, Int&> start() const { return {span.x.start, upperVertexIndices.start}; }
    STU_INLINE
    Pair<Float64, Int&> end() const { return {span.x.end, upperVertexIndices.end}; }
  };

  struct SpansWithUpperVertexIndices {
    const TextLineSpan* const spans;
    SpanUpperVertexIndices* const upperVertexIndices;
    const Int count;

    STU_INLINE
    SpanAndUpperVertexIndices operator[](const Int index) const {
      STU_DEBUG_ASSERT(0 <= index && index < count);
      return {spans[index], upperVertexIndices[index]};
    }
  };

  STU_INLINE
  void addVertices(SpansWithUpperVertexIndices spansWithUpperVertexIndices,
                   const InOut<Int> inOut_i, const InOut<Int> inOut_k,
                   const InOut<Int> unfinishedSpanIndex)
  {
    const TextLineSpan* const spans = spansWithUpperVertexIndices.spans;
    const Int i = inOut_i;
    const Int k = inOut_k;
    STU_DEBUG_ASSERT(spans[i].x.start <= spans[k].x.start);
    const bool iIsBottom = i > k;
    if (i != unfinishedSpanIndex) {
      addVertex(IsLeftVertex{true}, IsUpperVertex{iIsBottom},  IsTopOfTextLine{iIsBottom},
                spansWithUpperVertexIndices[i].start());
    }
    if (spans[i].x.end <= spans[k].x.start) {
      addVertex(IsLeftVertex{false}, IsUpperVertex{iIsBottom}, IsTopOfTextLine{iIsBottom},
                spansWithUpperVertexIndices[i].end());
      inOut_i = i + 1;
      // We don't need to clear the unfinishedSpanIndex.
      return;
    }
    // spans[i].x.start <= spans[k].x.start < spans[i].x.end

    // NOTE: If the vertical lines in the "drawings" below aren't aligned, try a different monospace
    //       font, e.g. "SF Mono" or "Hack".

    // iIsBottom  !isIsBottom
    //   ┄┄┄      ┄┄┄┄
    // ↘┃ k         i
    //  ┛┄┄┄      ┓┄┄┄
    //    i      ↗┃ k
    //  ┄┄┄┄       ┄┄┄
    addVertex(IsLeftVertex{false}, IsUpperVertex{!iIsBottom}, IsTopOfTextLine{iIsBottom},
              spansWithUpperVertexIndices[k].start());
    if (spans[i].x.end < spans[k].x.end) {
      // iIsBottom  !isIsBottom
      //  ┄┄┄┄┄       ┄┄┄┄
      // ┃ k            i ┃ ↙
      // ┛┄┄┄┏━       ┓┄┄┄┗━
      //   i ┃ ↖      ┃ k
      // ┄┄┄┄          ┄┄┄┄┄
      addVertex(IsLeftVertex{true}, IsUpperVertex{iIsBottom}, IsTopOfTextLine{!iIsBottom},
                spansWithUpperVertexIndices[i].end());
      inOut_i = i + 1;
      unfinishedSpanIndex = k;
    } else {
      // iIsBottom  !isIsBottom
      //  ┄┄┄        ┄┄┄┄┄┄
      // ┃ k ┃ ↙       i
      // ┛┄┄┄┗━      ┓┄┄┄┏━
      //   i         ┃ k ┃ ↖
      // ┄┄┄┄┄┄       ┄┄┄
      addVertex(IsLeftVertex{true}, IsUpperVertex{!iIsBottom}, IsTopOfTextLine{iIsBottom},
                spansWithUpperVertexIndices[k].end());
      inOut_k = k + 1;
      unfinishedSpanIndex = i;
    }
  }

  struct IsLeftVertex : Parameter<IsLeftVertex> { using Parameter::Parameter; };
  struct IsUpperVertex : Parameter<IsUpperVertex> { using Parameter::Parameter; };

  STU_INLINE
  void addVertex(const IsLeftVertex isLeftVertex, const IsUpperVertex isUpperVertex,
                 const IsTopOfTextLine isTopOfTextLine,
                 const Pair<Float64, Int&> xAndUpperVertexIndex)
  {
    const Float64 x = xAndUpperVertexIndex.first;
    Int& upperVertexIndex = xAndUpperVertexIndex.second; // A reference.
    const Int count = vector_.count();
    Int other;
    if (isUpperVertex) {
      other = -1;
      upperVertexIndex = count;
    } else {
      other = upperVertexIndex;
      vector_[other].indexOfVertexConnectedByVerticalEdge = sign_cast(count);
    }
    vector_.append(Vertex{.isLeftEndpointOfHorizontalEdge = isLeftVertex.value,
                          .isTopOfTextLine = isTopOfTextLine.value,
                          .isFirstInVertexLine = isFirstInLine_,
                          .indexOfVertexConnectedByVerticalEdge = sign_cast(other),
                          .x = narrow_cast<CGFloat>(x)});
    isFirstInLine_ = false;
  }
};

void VertexBuffer::addVerticesForSpans(const ArrayRef<const TextLineSpan> spans) {
  if (spans.isEmpty()) return;
  vector_.ensureFreeCapacity(4*spans.count());
  const Int expectedCount = vector_.count() + 4*spans.count();

  TempArray<SpanUpperVertexIndices> tempIndices{uninitialized, Count{spans.count()},
                                                vector_.allocator()};
#if STU_DEBUG
  memset(tempIndices.begin(), UINT8_MAX, sign_cast(spans.count())*sizeof(SpanUpperVertexIndices));
#endif

  const SpansWithUpperVertexIndices spansWithUpperVertexIndices = {
    spans.begin(), tempIndices.begin(), spans.count()
  };

  for (Int i = 0, k = 0, lineIndex = spans[0].lineIndex; i < spans.count(); ++lineIndex) {
    isFirstInLine_ = true;
    // In order to add the vertices for the current vertex line from left to right we
    // iterate over both the spans above (i) and below (k) the vertex line.
    STU_DEBUG_ASSERT(k == spans.count() || spans[k].lineIndex == lineIndex);
    Int unfinishedSpanIndex = -1;
    const Int k0 = k;
    for (;;) {
      if (i == k0) { // No spans above the vertex line left.
        for (; k < spans.count() && spans[k].lineIndex == lineIndex; ++k) {
          if (k != unfinishedSpanIndex) {
            addVertex(IsLeftVertex{true}, IsUpperVertex{true}, IsTopOfTextLine{true},
                      spansWithUpperVertexIndices[k].start());
          }
          addVertex(IsLeftVertex{false}, IsUpperVertex{true},  IsTopOfTextLine{true},
                    spansWithUpperVertexIndices[k].end());
        }
        break;
      }
      if (k == spans.count() || spans[k].lineIndex != lineIndex) {
        // No spans below the vertex line left.
        for (; i < k0; ++i) {
          if (i != unfinishedSpanIndex) {
            addVertex(IsLeftVertex{true}, IsUpperVertex{false}, IsTopOfTextLine{false},
                      spansWithUpperVertexIndices[i].start());
          }
          addVertex(IsLeftVertex{false}, IsUpperVertex{false}, IsTopOfTextLine{false},
                    spansWithUpperVertexIndices[i].end());
        }
        break;
      }
      if (spans[i].x.start <= spans[k].x.start) {
        addVertices(spansWithUpperVertexIndices,
                    InOut{i}, InOut{k}, InOut{unfinishedSpanIndex});
      } else {
        addVertices(spansWithUpperVertexIndices,
                    InOut{k}, InOut{i}, InOut{unfinishedSpanIndex});
      }
    } // loop over spans above and below vertex line
  } // loop over vertex lines
  STU_ASSERT(vector_.count() == expectedCount);
}

STU_INLINE
void addRect(CGMutablePath& path, const CGRect rect, const CornerRadius cornerRadius,
             const CGAffineTransform* __nullable const transform)
{
  const CGFloat r = min(min(cornerRadius.value, rect.size.height/2), rect.size.width/2);
  if (r <= 0) {
    CGPathAddRect(&path, transform, rect);
  } else {
    CGPathAddRoundedRect(&path, transform, rect, r, r);
  }
}

/// Returns true if an empty span was removed, in which case tempSpans will contain the filtered
/// spans.
/// @pre tempSpans.isEmpty() || (spans.begin() == tempSpans.begin() && spans.count() == tempSpans.count())
static bool removeEmptySpansAndAssertSpansAreOrderedAndNonAdjacent(
              ArrayRef<const TextLineSpan> spans, Float64 zeroWidth,
              TempVector<TextLineSpan>& tempSpans)
{
  UInt32 lineIndex = maxValue<UInt32>;
  Float64 previousEnd = -infinity<Float64>;
  TextLineSpan* end = nullptr;
  for (Int i = 0; i < spans.count(); ++i) {
    const TextLineSpan& span = spans[i];
    STU_ASSERT(previousEnd < span.x.end || span.lineIndex > lineIndex);
    previousEnd = span.x.end;
    lineIndex = span.lineIndex;
    if (span.x.end - span.x.start > zeroWidth) {
      if (end) {
        *end++ = span;
      }
      continue;
    }
    if (!end) {
      if (tempSpans.isEmpty()) {
        tempSpans.append(spans);
      } else {
        STU_ASSERT(tempSpans.begin() == spans.begin());
      }
      end = &tempSpans[i];
    }
  }
  if (end) {
    tempSpans.removeLast(tempSpans.end() - end);
  }
  return end != nullptr;
}

static void extendOrAppendSpan(const ArrayRef<const TextLineSpan> spans,
                               const InOut<Int> inOutIndex, const Int endIndex,
                               Range<Float64> x, const UInt32 lineIndex,
                               const bool canMutateSpans,
                               const InOut<Int> inOutCopyEndIndex,
                               TempVector<TextLineSpan>& outSpans)
{
  Int index = inOutIndex;
  Int index1 = index;
  STU_ASSERT(index >= 0);
  while (index < endIndex) {
    const TextLineSpan& span = spans[index];
    if (span.x.end < x.start) {
      ++index;
      continue;
    }
    index1 = index;
    if (x.end < span.x.start) break;
    if (!canMutateSpans && span.x.contains(x)) {
      inOutIndex = index;
      return;
    }
    index1 = index + 1;
    x.start = min(x.start, span.x.start);
    if (x.end <= span.x.end) {
      x.end = span.x.end;
    } else {
      for (; index1 < endIndex && x.end >= spans[index1].x.start; ++index1) {
        x.end = max(x.end, spans[index1].x.end);
      }
    }
    if (canMutateSpans && index1 == index + 1) {
      const_cast<TextLineSpan&>(span).x = x;
      return;
    }
    break;
  }
  const Int oldCopyEndIndex = inOutCopyEndIndex;
  inOutCopyEndIndex = index1;
  if (outSpans.isEmpty()) {
    outSpans.ensureFreeCapacity(spans.count() + 1);
  }
  if (oldCopyEndIndex < index) {
    outSpans.append(spans[{oldCopyEndIndex, index}]);
  } else if (!outSpans.isEmpty()) {
    TextLineSpan& last = outSpans[$ - 1];
    if (last.lineIndex == lineIndex && last.x.end >= x.start) {
      last.x.end = max(last.x.end, x.end);
      return;
    }
  }
  outSpans.append(TextLineSpan{.x = x, .lineIndex = lineIndex});
}

static bool extendOrInsertSpansInCompletelyOverlappedLines(
              const ArrayRef<const TextLineSpan> spans,
              const ArrayRef<const TextLineVerticalPosition> vps,
              const VerticalEdgeInsets verticalinsets,
              TempVector<TextLineSpan>& tempSpans)
{
  if (spans.count() < 3 || vps.count() < 3) return false;

  const bool canMutateSpans = spans.begin() == tempSpans.begin();
  tempSpans.trimFreeCapacity(); // The thread local allocator doesn't move memory.
  TempVector<TextLineSpan> newSpans{tempSpans.allocator()};

  // We only look for lines that are overlapped by the adjacent lines above and below.

  Int i0 = 0; // The index of the first span on the previous line.
  Int i = 0; // The index of the first span on the current line.
  Int i1 = 0; // The index of the first span on the next line.
  Int copyEndIndex = 0; // The index of the last span copied from spans to newSpans plus 1.
  Range<CGFloat> previousLineY;
  Range<CGFloat> lineY = textLineY(vps[0], verticalinsets);
  Range<CGFloat> nextLineY = textLineY(vps[1], verticalinsets);
  for (UInt32 lineIndex = 1; lineIndex < sign_cast(vps.count() - 1); ++lineIndex) {
    previousLineY = lineY;
    lineY = nextLineY;
    nextLineY = textLineY(vps[lineIndex + 1], verticalinsets);
    if (STU_LIKELY(   max(previousLineY.end, lineY.start) < nextLineY.start
                   && previousLineY.end < min(lineY.end, nextLineY.start)))
    {
      continue;
    }
    if (spans[i0].lineIndex < lineIndex - 1) {
      i0 = i;
      if (spans[i0].lineIndex < lineIndex - 1) {
        i0 = i1;
        if (spans[i0].lineIndex < lineIndex - 1) {
          do {
            if (++i0 == spans.count()) goto Return;
          } while (spans[i0].lineIndex < lineIndex - 1);
          i1 = i0;
        }
        i = i0;
      }
    }
    if (spans[i].lineIndex < lineIndex) {
      i = i1;
      if (spans[i].lineIndex < lineIndex) {
        do {
          if (++i == spans.count()) goto Return;
        } while (spans[i].lineIndex < lineIndex);
        i1 = i;
      }
    }
    if (spans[i1].lineIndex == lineIndex) {
      do {
        if (++i1 == spans.count()) goto Return;
      } while (spans[i1].lineIndex == lineIndex);
    }
    Int i2 = i1;
    if (spans[i2].lineIndex == lineIndex + 1) {
      do ++i2;
      while (i2 != spans.count() && spans[i2].lineIndex == lineIndex + 1);
      if (   spans[i ].lineIndex == lineIndex
          && spans[i0].lineIndex == lineIndex - 1)
      {
        Int k0 = i0; // The index of the span on the previous line.
        Int k  = i;  // The index of the span on the current line.
        Int k1 = i1; // The index of the span on the next line.
        for (; k0 < k; ++k0) {
          const TextLineSpan& upper = spans[k0];
          for (; k1 < i2; ++k1) {
            const TextLineSpan& lower = spans[k1];
            if (lower.x.end <= upper.x.start) continue;
            if (lower.x.start >= upper.x.end) break;
            const Range<Float64> x = lower.x.intersection(upper.x);
            extendOrAppendSpan(spans, InOut{k}, i1, x, lineIndex,
                               canMutateSpans, InOut{copyEndIndex}, newSpans);
            if (lower.x.end > upper.x.end) break;
          }
        }
      }
      if (i2 == spans.count()) goto Return;
    }
    i0 = i;
    i  = i1;
    i1 = i2;
  }
Return:
  if (!newSpans.isEmpty()) {
    newSpans.append(spans[{copyEndIndex, $}]);
    tempSpans = std::move(newSpans);
    return true;
  }
  return false;
}

void addLineSpansPath(CGPath& path,
                      const ArrayRef<const TextLineSpan> originalSpans,
                      const ArrayRef<const TextLineVerticalPosition> verticalPositions,
                      const ShouldFillTextLineGaps fillTextLineGaps,
                      const ShouldExtendTextLinesToCommonHorizontalBounds shouldExtendToCommonBounds,
                      const UIEdgeInsets edgeInsets, CornerRadius cornerRadius,
                      const Rect<CGFloat>* __nullable const clipRect,
                      const CGAffineTransform* __nullable const transform)
{
  if (originalSpans.isEmpty()) return;
  ArrayRef<const TextLineSpan> spans = originalSpans;
  TempVector<TextLineSpan> tempSpans;
  const bool hasHorizontalInsets = edgeInsets.left != 0 || edgeInsets.right != 0;
  const bool needToExtendLines = shouldExtendToCommonBounds
                                 && spans[0].lineIndex != spans[$ - 1].lineIndex;
  if (hasHorizontalInsets || needToExtendLines) {
    tempSpans.append(spans);
    if (hasHorizontalInsets) {
      adjustTextLineSpansByHorizontalInsets(tempSpans, HorizontalInsets{edgeInsets});
    }
    if (needToExtendLines) {
      extendTextLinesToCommonHorizontalBounds(Ref{tempSpans});
    }
    spans = tempSpans;
  }
  const Float64 zeroWidth = max(0., -(edgeInsets.left + edgeInsets.right));
  if (removeEmptySpansAndAssertSpansAreOrderedAndNonAdjacent(spans, zeroWidth, tempSpans)) {
    spans = tempSpans;
  }
  const VerticalEdgeInsets verticalInsets{edgeInsets};
  if (fillTextLineGaps) {
    if (extendOrInsertSpansInCompletelyOverlappedLines(spans, verticalPositions, verticalInsets,
                                                       tempSpans))
    {
      spans = tempSpans;
    }
  }
  tempSpans.trimFreeCapacity(); // The thread local allocator doesn't move memory.

  for (Int i0 = 0, i1; i0 < spans.count(); i0 = i1) {
    Int32 firstLineIndex = spans[i0].lineIndex;
    Int32 lastLineIndex = firstLineIndex;
    for (i1 = i0 + 1;
         i1 < spans.count() && spans[i1].lineIndex <= lastLineIndex + fillTextLineGaps.value;
         ++i1)
    {
      const Int32 lineIndex = spans[i1].lineIndex;
      STU_DEBUG_ASSERT(lineIndex >= lastLineIndex);
      STU_DEBUG_ASSERT(lineIndex > lastLineIndex || spans[i1].x.start > spans[i1 - 1].x.end);
      lastLineIndex = lineIndex;
    }
    const ArrayRef<const TextLineSpan> localSpans = spans[{i0, i1}];
    if (firstLineIndex == lastLineIndex) {
      const TextLineVerticalPosition vpos = verticalPositions[firstLineIndex];
      const Range<CGFloat> y = textLineY(vpos, verticalInsets);
      for (const TextLineSpan& span : localSpans) {
        const Rect<CGFloat> rect = {narrow_cast<Range<CGFloat>>(span.x), y};
        if (clipRect && !rect.overlaps(*clipRect)) continue;
        addRect(path, rect, cornerRadius, transform);
      }
    } else {
      const auto vps = verticalPositions[{firstLineIndex, lastLineIndex + 1}];
      // If there's a clipRect, we could compute the bounds for the (sub)path here and compare it
      // with the clipRect. However, we currently don't use this function in a way where that would
      // be useful.
      VertexBuffer buffer{tempSpans.allocator()};
      buffer.addVerticesForSpans(localSpans);
      addVertexPath(path, buffer.vertices(), vps, verticalInsets, cornerRadius, transform);
    }
  }
}

} // stu_label
