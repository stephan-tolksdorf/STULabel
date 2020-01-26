// Copyright 2017–2018 Stephan Tolksdorf

#import "TextLineSpan.hpp"

#import "DisplayScaleRounding.hpp"
#import "TextFrame.hpp"
#import "ThreadLocalAllocator.hpp"

namespace stu_label {

struct VerticalEdgeInsets {
  stu::Float32 top{};
  stu::Float32 bottom{};

  STU_INLINE VerticalEdgeInsets() = default;

  explicit STU_CONSTEXPR
  VerticalEdgeInsets(const UIEdgeInsets& edgeInsets)
  : top{narrow_cast<stu::Float32>(edgeInsets.top)},
    bottom{narrow_cast<stu::Float32>(edgeInsets.bottom)}
  {}
};

struct TextLineVerticalPosition {
  stu::Float64 baseline;
  stu::Float32 ascent;
  stu::Float32 descent;

  STU_INLINE Range<stu::Float64> y() const { return baseline + Range{-ascent, descent}; }

  STU_INLINE
  void scale(const TextFrameScale& textFrameScale) {
    baseline *= textFrameScale.value();
    ascent *= textFrameScale.value_f32();
    descent *= textFrameScale.value_f32();
  }

  STU_INLINE
  bool operator==(const TextLineVerticalPosition& other) {
    return baseline == other.baseline
        && ascent == other.ascent
        && descent == other.descent;
  }
  STU_INLINE
  bool operator!=(const TextLineVerticalPosition& other) {
    return !(*this == other);
  }
};

struct VerticalOffsets {
  stu::Float64 textFrameOriginY;
  stu::Float64 ctmYOffset;
};

STU_INLINE
TextLineVerticalPosition textLineVerticalPosition(const TextFrameLine& line,
                                                  OptionalDisplayScaleRef displayScale,
                                                  VerticalEdgeInsets insets = VerticalEdgeInsets{},
                                                  VerticalOffsets offsets = VerticalOffsets{})
{
  stu::Float64 baseline = line.originY;
  stu::Float32 ascent = line.ascent + line.leading/2 - insets.top;
  stu::Float32 descent = line.descent + line.leading/2 - insets.bottom;
  if (STU_UNLIKELY(-ascent > descent)) {
    descent = (-ascent + descent)/2;
    ascent = -descent;
  }
  if (displayScale) {
    baseline += offsets.textFrameOriginY;
    baseline = ceilToScale(baseline, *displayScale, offsets.ctmYOffset);
    if (line.lineIndex == 0) {
      ascent = ceilToScale(ascent, *displayScale);
    }
    if (line.isLastLine) {
      descent = ceilToScale(descent, *displayScale);
    }
  }
  return {.baseline = baseline, .ascent = ascent, .descent = descent};
}


STU_INLINE
TempArray<TextLineVerticalPosition>
  textLineVerticalPositions(ArrayRef<const TextFrameLine> lines,
                            OptionalDisplayScaleRef displayScale,
                            VerticalEdgeInsets insets = VerticalEdgeInsets{},
                            VerticalOffsets offsets = VerticalOffsets{})
{
  TempArray<TextLineVerticalPosition> verticalPositions{uninitialized, Count{lines.count()}};
  stu::Int i = 0;
  for (const TextFrameLine& line : lines) {
    verticalPositions[i] = textLineVerticalPosition(line, displayScale, insets, offsets);
    ++i;
  }
  return verticalPositions;
}

struct TextLineSpansPathBounds {
  Rect<stu::Float64> rect;
  bool pathExtendedToCommonHorizontalTextLineBoundsIsRect;
};

TextLineSpansPathBounds calculateTextLineSpansPathBounds(
                          ArrayRef<const TextLineSpan> spans,
                          ArrayRef<const TextLineVerticalPosition> verticalPositions);

using CGMutablePath = RemovePointer<CGMutablePathRef>;

struct CornerRadius : Parameter<CornerRadius, CGFloat> { using Parameter::Parameter; };
struct ShouldFillTextLineGaps : Parameter<ShouldFillTextLineGaps> { using Parameter::Parameter; };
struct ShouldExtendTextLinesToCommonHorizontalBounds
       : Parameter<ShouldExtendTextLinesToCommonHorizontalBounds>
{
  using Parameter::Parameter;
};

/// \pre The spans must be non-adjacent and sorted left-to-right, top-to-bottom.
///
/// Time & space complexity: linear in the number of spans.
void addLineSpansPath(CGMutablePath&,
                      ArrayRef<const TextLineSpan>,
                      ArrayRef<const TextLineVerticalPosition>,
                      ShouldFillTextLineGaps = ShouldFillTextLineGaps{false},
                      ShouldExtendTextLinesToCommonHorizontalBounds =
                        ShouldExtendTextLinesToCommonHorizontalBounds{false},
                      UIEdgeInsets = UIEdgeInsets{}, CornerRadius = CornerRadius{},
                      const Rect<CGFloat>* __nullable clipRectBeforeTransform = nullptr,
                      const CGAffineTransform* __nullable = nullptr);

} // stu_label
