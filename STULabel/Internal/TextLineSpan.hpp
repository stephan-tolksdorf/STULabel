// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyle.hpp"
#import "ThreadLocalAllocator.hpp"

#import "stu/FunctionRef.hpp"

namespace stu_label {

struct TextLineSpan {
  Range<stu::Float64> x;
  bool isLeftEndOfLine : 1;
  stu::UInt32 lineIndex : 31;
  bool isRightEndOfLine : 1;
  stu::UInt32 rangeIndex : 31;
};

struct HorizontalInsets {
  CGFloat left{};
  CGFloat right{};

  STU_CONSTEXPR_T
  HorizontalInsets() = default;

  STU_CONSTEXPR_T
  HorizontalInsets(CGFloat left, CGFloat right)
  : left{left}, right{right}
  {}

  explicit STU_CONSTEXPR
  HorizontalInsets(UIEdgeInsets edgeInsets)
  : left{edgeInsets.left}, right{edgeInsets.right}
  {}
};

/// Spans that overlap after the edge insets have been applied are fused (and are assigned the
/// the rangeIndex of the left-most overlapping span).
/// The function returns the new span count (which is less than or equal to the old count).
STU_WARN_UNUSED_RESULT
stu::Int adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(ArrayRef<TextLineSpan>,
                                                           HorizontalInsets);

STU_INLINE
void adjustTextLineSpansByHorizontalInsets(TempVector<TextLineSpan>& vector,
                                           HorizontalInsets insets)
{
  const stu::Int n = adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(vector, insets);
  vector.removeLast(vector.count() - n);
}

void extendTextLinesToCommonHorizontalBounds(ArrayRef<TextLineSpan> spans);

struct TaggedStringRange {
  Range<stu::Int32> rangeInOriginalString;
  Range<stu::Int32> rangeInTruncatedString;
  stu::Int32 paragraphIndex;
  bool hasSpan : 1;
  stu::UInt32 tagIndex : 31;
  stu::UInt tag;

  stu::UInt taggedNonOverriddenStylePointer_;

  STU_INLINE_T
  bool styleWasOverridden() const {
    return taggedNonOverriddenStylePointer_ & 1;
  }

  STU_INLINE_T
  const TextStyle* nonOverriddenStyle() const {
    return reinterpret_cast<const TextStyle*>(taggedNonOverriddenStylePointer_ & ~stu::UInt{1});
  }
};

template <typename T>
struct FirstLastRange {
  T first;
  T last;
};

struct TaggedRangeLineSpans {
  TempArray<TaggedStringRange> ranges;
  TempArray<TextLineSpan> spans;
  /// The number of tags with at least one associated span.
  stu::Int32 spanTagCount;

  template <typename Callable,
           EnableIf<isCallable<Callable,
                               void(ArrayRef<const TextLineSpan> spans,
                                    FirstLastRange<const TaggedStringRange&> ranges)>> = 0>
  STU_INLINE
  void forEachTaggedLineSpanSequence(Callable callable) const {
    stu::Int i = 0;
    while (i < spans.count()) {
      const stu::Int i0 = i;
      stu::Int32 r0 = spans[i].rangeIndex;
      stu::Int32 r1 = r0;
      const stu::Int32 tagIndex = ranges[r0].tagIndex;
      while (++i < spans.count()) {
        const stu::Int32 r = spans[i].rangeIndex;
        if (ranges[r].tagIndex != tagIndex) break;
        r0 = min(r0, r);
        r1 = max(r1, r);
      }
      // Include adjacent ranges that have the same tag index but no glyph spans.
      while (r0 > 0 && ranges[r0 - 1].tagIndex == tagIndex) {
        --r0;
      }
      do ++r1;
      while (r1 < ranges.count() && ranges[r1].tagIndex == tagIndex);
      callable(spans[{i0, i}],
               FirstLastRange<const TaggedStringRange&>{ranges[r0], ranges[r1 - 1]});
    }
  }
};

struct TextFrameLine;

struct SeparateParagraphs : Parameter<SeparateParagraphs> { using Parameter::Parameter; };

TaggedRangeLineSpans findAndSortTaggedRangeLineSpans(
                       ArrayRef<const TextFrameLine> lines,
                       Optional<TextStyleOverride&> styleOverride,
                       TextFlags tagTextFlagsMask,
                       SeparateParagraphs separateParagraphs,
                       // 0 is interpreted as a missing tag.
                       FunctionRef<stu::UInt(const TextStyle&)> tagger,
                       Optional<FunctionRef<bool (stu::UInt, stu::UInt)>> tagEquality);

} // stu_label
