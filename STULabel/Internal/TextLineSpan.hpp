// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyle.hpp"
#import "ThreadLocalAllocator.hpp"

#import "stu/FunctionRef.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

struct TextLineSpan {
  Range<Float64> x;
  bool isLeftEndOfLine : 1;
  UInt32 lineIndex : 31;
  bool isRightEndOfLine : 1;
  UInt32 rangeIndex : 31;
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
Int adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(ArrayRef<TextLineSpan>,
                                                           HorizontalInsets);

STU_INLINE
void adjustTextLineSpansByHorizontalInsets(TempVector<TextLineSpan>& vector,
                                           HorizontalInsets insets)
{
  const Int n = adjustTextLineSpansByHorizontalInsetsAndReturnNewCount(vector, insets);
  vector.removeLast(vector.count() - n);
}

void extendTextLinesToCommonHorizontalBounds(ArrayRef<TextLineSpan> spans);

struct TaggedStringRange {
  Range<Int32> rangeInOriginalString;
  Range<Int32> rangeInTruncatedString;
  Int32 paragraphIndex;
  bool hasSpan : 1;
  UInt32 tagIndex : 31;
  UInt tag;

  UInt taggedNonOverriddenStylePointer_;

  STU_INLINE_T
  bool styleWasOverridden() const {
    return taggedNonOverriddenStylePointer_ & 1;
  }

  STU_INLINE_T
  const TextStyle* nonOverriddenStyle() const {
    return reinterpret_cast<const TextStyle*>(taggedNonOverriddenStylePointer_ & ~UInt{1});
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
  Int32 spanTagCount;

  template <typename Callable,
           EnableIf<isCallable<Callable,
                               void(ArrayRef<const TextLineSpan> spans,
                                    FirstLastRange<const TaggedStringRange&> ranges)>> = 0>
  STU_INLINE
  void forEachTaggedLineSpanSequence(Callable callable) const {
    Int i = 0;
    while (i < spans.count()) {
      const Int i0 = i;
      Int32 r0 = spans[i].rangeIndex;
      Int32 r1 = r0;
      const Int32 tagIndex = ranges[r0].tagIndex;
      while (++i < spans.count()) {
        const Int32 r = spans[i].rangeIndex;
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
                       FunctionRef<UInt(const TextStyle&)> tagger,
                       Optional<FunctionRef<bool (UInt, UInt)>> tagEquality);

} // stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
