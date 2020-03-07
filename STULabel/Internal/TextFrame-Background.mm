// Copyright 2017–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "STULabel/STUTextAttributes-Internal.hpp"

#import "TextLineSpansPath.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

struct STUTextBackgroundSegment {
  /// The bounds do not account for the display scale rounding of the baseline and the additional
  /// rounding of the top of any background of the first line in the text frame and the bottom of
  /// any background of the last line in the text frame.
  stu_label::Rect<CGFloat> bounds;
  uint32_t spanCount;
  bool isLast : 1;
  uint32_t lineIndexOffset : 31;
  Optional<ColorIndex> colorIndex;
  Optional<ColorIndex> strokeColorIndex;
  const STUBackgroundAttribute* __unsafe_unretained attribute;
  TextLineSpan spans[];

  const STUTextBackgroundSegment* next() const {
    static_assert(alignof(STUTextBackgroundSegment) == alignof(TextLineSpan));
    return isLast ? nullptr
         : reinterpret_cast<const STUTextBackgroundSegment*>(spans + spanCount);
  }

  void draw(ArrayRef<const TextFrameLine> textFrameLines, DrawingContext& context) const;
};

namespace stu_label {

using BackgroundSegment = STUTextBackgroundSegment;

class TempBackgroundSegments {
  TaggedRangeLineSpans taggedRangeLineSpans_;
  TempVector<Byte> data_;
  BackgroundSegment* lastSegment_{};

 static TaggedRangeLineSpans findBackgroundLineSpans(
                               const ArrayRef<const TextFrameLine> lines,
                               Optional<TextStyleOverride&> styleOverride);

  void appendSegment(const TextStyle::BackgroundInfo& info,
                     const STUBackgroundAttribute* __nullable __unsafe_unretained attrib,
                     ArrayRef<const TextLineSpan> spans,
                     ArrayRef<const TextFrameLine> textFrameLines);

public:
  TempBackgroundSegments(const TextFrame& textFrame,
                         Range<Int> lineRange,
                         Optional<TextStyleOverride&> styleOverride);

  const BackgroundSegment* first() const {
    return data_.isEmpty() ? nullptr
         : reinterpret_cast<const BackgroundSegment*>(&data_[0]);
  }

  Int dataSize() const { return data_.count(); }
};

TaggedRangeLineSpans TempBackgroundSegments::findBackgroundLineSpans(
                                               const ArrayRef<const TextFrameLine> lines,
                                               Optional<TextStyleOverride&> styleOverride)
{
 return findAndSortTaggedRangeLineSpans(lines, styleOverride,
          TextFlags::hasBackground, SeparateParagraphs{false},
          [](const TextStyle& style) -> UInt {
            const TextStyle::BackgroundInfo* const info = style.backgroundInfo();
            if (info->stuAttribute) {
              const UInt p = reinterpret_cast<UInt>(info->stuAttribute);
              STU_DEBUG_ASSERT((p & 1) == 0);
              return p;
            } else {
              const UInt colorIndex = info->colorIndex.value_or(ColorIndex::reserved).value;
              return (colorIndex << 1) | 1;
            }
          },
          [](UInt tag1, UInt tag2) -> bool {
            if ((tag1 | tag2) & 1) return false;
            return [(__bridge STUBackgroundAttribute*)reinterpret_cast<void*>(tag1)
                      isEqual:(__bridge STUBackgroundAttribute*)reinterpret_cast<void*>(tag2)];
          });
}

TempBackgroundSegments::TempBackgroundSegments(const TextFrame& textFrame,
                                               Range<Int> lineRange,
                                               Optional<TextStyleOverride&> styleOverride)
: taggedRangeLineSpans_{findBackgroundLineSpans(textFrame.lines()[lineRange], styleOverride)},
  data_{freeCapacityInCurrentThreadLocalAllocatorBuffer}
{
  ArrayRef<const TextFrameLine> textFrameLines = textFrame.lines();
  taggedRangeLineSpans_.forEachTaggedLineSpanSequence(
    [&](ArrayRef<const TextLineSpan> spans, FirstLastRange<const TaggedStringRange&> ranges)
  {                                        // clang analyzer bug?
    const TextStyle::BackgroundInfo& info = ranges.last.styleWasOverridden()
                                            && (styleOverride->flags & TextFlags::hasBackground)
                                          ? styleOverride->highlightStyle->info.background
                                          : *ranges.last.nonOverriddenStyle()->backgroundInfo();
    const STUBackgroundAttribute* __unsafe_unretained const attrib =
        (ranges.last.tag & 1) ? nil
      : (__bridge STUBackgroundAttribute*)reinterpret_cast<void*>(ranges.last.tag);
    appendSegment(info, attrib, spans, textFrameLines);
  });
  if (data_.isEmpty()) {
    BackgroundSegment* const bs = reinterpret_cast<BackgroundSegment*>(
                                    data_.append(repeat(uninitialized, sizeof(BackgroundSegment))));
    *bs = BackgroundSegment{.isLast = true};
  }
  data_.trimFreeCapacity();
}

void TempBackgroundSegments::appendSegment(
       const TextStyle::BackgroundInfo& info,
       const STUBackgroundAttribute* __nullable __unsafe_unretained attrib,
       ArrayRef<const TextLineSpan> inputSpans,
       ArrayRef<const TextFrameLine> lines)
{
  STU_ASSERT(!inputSpans.isEmpty());
  Int32 firstLineIndex = inputSpans[0].lineIndex;
  Int32 lastLineIndex = inputSpans[$ - 1].lineIndex;
  const Int32 lineIndexOffset = firstLineIndex;
  const CGFloat strokeWidth = !attrib || !info.borderColorIndex ? 0 : attrib->_borderWidth;

  const Int size = sign_cast(sizeof(BackgroundSegment) + inputSpans.arraySizeInBytes());
  auto* p = reinterpret_cast<BackgroundSegment*>(data_.append(repeat(uninitialized, size)));
  *p = BackgroundSegment{
         .spanCount = static_cast<UInt32>(inputSpans.count()),
         .isLast = true,
         .lineIndexOffset = sign_cast(lineIndexOffset),
         .colorIndex = info.colorIndex,
         .strokeColorIndex = strokeWidth == 0 ? none : info.borderColorIndex,
         .attribute = attrib
      };
  array_utils::copyConstructArray(inputSpans, p->spans);
  ArrayRef<TextLineSpan> spans{p->spans, inputSpans.count()};

  const auto removeLastSpans = [&](Int n) STU_INLINE_LAMBDA {
    spans = spans[{0, $ - n}];
    p->spanCount = static_cast<UInt32>(spans.count());
    data_.removeLast(n*sign_cast(sizeof(TextLineSpan)));
  };

  CGFloat zeroWidth = 0;
  if (attrib) {
    const CGFloat leftInset  = attrib->_edgeInsets.left;
    const CGFloat rightInset = attrib->_edgeInsets.right;
    if (leftInset != 0 || rightInset != 0) {
      zeroWidth = max(0.f, -(leftInset + rightInset));
      const Int newCount = adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(
                             ArrayRef{const_cast<TextLineSpan*>(spans.begin()), spans.count()},
                             HorizontalInsets{leftInset, rightInset});
      removeLastSpans(spans.count() - newCount);
    }
  }
  if (firstLineIndex != lastLineIndex
      && (!attrib || attrib->_extendTextLinesToCommonHorizontalBounds))
  {
    extendTextLinesToCommonHorizontalBounds(spans);
  }

  Rect bounds = Rect<Float64>::infinitelyEmpty();

  // Remove zero-width spans and calculate X bounds
  TextLineSpan* end = nullptr;
  for (TextLineSpan& span : spans) {
    if (span.x.end - span.x.start > zeroWidth) {
      bounds.x = bounds.x.convexHull(span.x);
      span.lineIndex -= lineIndexOffset;
      if (!end) continue;
      *end++ = span;
      continue;
    } else if (!end) {
      end = &span;
    }
  }
  if (end) {
    removeLastSpans(spans.end() - end);
    if (spans.isEmpty()) {
      data_.removeLast(sign_cast(sizeof(BackgroundSegment)));
      return;
    }
    firstLineIndex = lineIndexOffset + spans[0].lineIndex;
    lastLineIndex =  lineIndexOffset + spans[$ - 1].lineIndex;
  }

  const auto verticalInsets = !attrib ? VerticalEdgeInsets{}
                            : VerticalEdgeInsets(attrib->_edgeInsets);
  for (const TextFrameLine& line : lines[{firstLineIndex, lastLineIndex + 1}]) {
    bounds.y = bounds.y.convexHull(textLineVerticalPosition(line, none, verticalInsets).y());
  }
  if (strokeWidth != 0) {
    bounds = bounds.outset(strokeWidth/2);
  }
  p->bounds = narrow_cast<Rect<CGFloat>>(bounds);

  if (lastSegment_) {
    lastSegment_->isLast = false;
  }
  lastSegment_ = p;
}

} // namespace stu_label

void BackgroundSegment::draw(ArrayRef<const TextFrameLine> lines, DrawingContext& context) const {
  if (spanCount == 0) return;
  const Range<Int> lineRange = sign_cast(lineIndexOffset)
                             + Range{0, spans[spanCount - 1].lineIndex + 1};
  
  TempArray<TextLineVerticalPosition> verticalPositions =
    textLineVerticalPositions(lines[lineRange], context.displayScale(),
                              !attribute ? VerticalEdgeInsets{}
                                         : VerticalEdgeInsets(attribute->_edgeInsets),
                              VerticalOffsets{.textFrameOriginY = context.textFrameOrigin().y,
                                              .ctmYOffset = context.ctmYOffset()});

  const bool shouldFillLineGaps = !attribute ? true : attribute->_fillTextLineGaps;
  // Fill line gaps with a thickness less than 1 pixel anyway.
  if (!shouldFillLineGaps && context.displayScale()) {
    const Float64 pixelDistance = context.displayScale()->inverseValue_f64();
    for (Int i = 1; i < verticalPositions.count(); ++i) {
      const Float64 d = verticalPositions[i].baseline - verticalPositions[i - 1].baseline
                      - (verticalPositions[i].ascent + verticalPositions[i - 1].descent);
      if (d < pixelDistance && d > 0) {
        const Float32 e = narrow_cast<Float32>(d/2);
        verticalPositions[i - 1].descent += e;
        verticalPositions[i].ascent += e;
      }
    }
  }

  stu_label::Rect<CGFloat> clipRect = context.clipRect();

  const CGPathDrawingMode mode = !strokeColorIndex ? kCGPathFill
                               : !colorIndex ? kCGPathStroke
                               : kCGPathFillStroke;
  if (strokeColorIndex) {
    context.setStrokeColor(*strokeColorIndex);
    const CGFloat strokeWidth = attribute->_borderWidth;
    CGContextSetLineWidth(context.cgContext(), attribute->_borderWidth);
    clipRect = context.clipRect().outset(strokeWidth/2);
  }
  if (colorIndex) {
    context.setFillColor(*colorIndex);
  }

  clipRect.x -= context.textFrameOrigin().x;
  const CGAffineTransform translation = {.a = 1, .d = 1, .tx = context.textFrameOrigin().x};

  const RC<CGPath> path{CGPathCreateMutable(), ShouldIncrementRefCount{false}};
  addLineSpansPath(*path, ArrayRef{spans, sign_cast(spanCount)}, verticalPositions,
                   ShouldFillTextLineGaps{shouldFillLineGaps},
                   // We already extended the spans if necessary.
                   ShouldExtendTextLinesToCommonHorizontalBounds{false}, UIEdgeInsets{},
                   CornerRadius{attribute ? attribute->_cornerRadius : 0},
                   &clipRect, &translation);
  CGContextAddPath(context.cgContext(), path.get());
  if (context.isCancelled()) return;
  CGContextDrawPath(context.cgContext(), mode);
}

namespace stu_label {

static void drawBackgroundSegments(const BackgroundSegment* bs,
                                   ArrayRef<const TextFrameLine> textFrameLines,
                                   DrawingContext& context)
{
  const Rect clipRect = context.clipRect() - context.textFrameOrigin();
  for (; bs; bs = bs->next()) {
    if (!clipRect.overlaps(bs->bounds)) continue;
    if (context.isCancelled()) return;
    bs->draw(textFrameLines, context);
  }
}

void TextFrame::drawBackground(Range<Int> clipLineRange, DrawingContext& context) const {
  if (clipLineRange.isEmpty()) return;

  const ArrayRef<const TextFrameLine> lines = this->lines();

  // Depending on the background attribute options the shape of a background decoration may depend
  // on the background of adjacent lines.
  while (clipLineRange.start > 0
         && (lines[clipLineRange.start - 1].textFlags() & TextFlags::hasBackground))
  {
    clipLineRange.start -= 1;
  }
  while (clipLineRange.end < lines.count()
         && (lines[clipLineRange.end].textFlags() & TextFlags::hasBackground))
  {
    clipLineRange.end += 1;
  }

  const Optional<TextStyleOverride&> styleOverride = context.styleOverride();
  if (styleOverride
      && (!(styleOverride->flagsMask & TextFlags::hasBackground)
          || !styleOverride->drawnRange.contains(range())))
  {
    TempBackgroundSegments ts{*this, clipLineRange, styleOverride};
    drawBackgroundSegments(ts.first(), lines, context);
    return;
  }

  _Atomic(const BackgroundSegment*)* const frameBackgroundSegments =
    const_cast<_Atomic(const BackgroundSegment*)*>(&_backgroundSegments);

  const BackgroundSegment* bs = atomic_load_explicit(frameBackgroundSegments,
                                                     memory_order_relaxed);
  if (bs) {
    bs = atomic_load_explicit(frameBackgroundSegments, memory_order_acquire);
  } else {
    TempBackgroundSegments ts{*this, {0, lineCount}, styleOverride};
    if (context.isCancelled()) return;
    Byte* p = Malloc{}.allocate(ts.dataSize());
    memcpy(p, ts.first(), sign_cast(ts.dataSize()));
    bs = reinterpret_cast<BackgroundSegment*>(p);
    const BackgroundSegment* expected = nullptr;
    if (!atomic_compare_exchange_strong_explicit(frameBackgroundSegments, &expected, bs,
                                                 memory_order_release, memory_order_acquire))
    {
      Malloc{}.deallocate(p, ts.dataSize());
      bs = expected;
    }
  }
  drawBackgroundSegments(bs, lines, context);
}

} // namespace stu_label
