// Copyright 2017–2018 Stephan Tolksdorf

#import "TextLineSpan.hpp"

#import "DisplayScaleRounding.hpp"
#import "TextFrame.hpp"
#import "ThreadLocalAllocator.hpp"

namespace stu_label {

struct VerticalEdgeInsets {
  Float32 top{};
  Float32 bottom{};

  STU_INLINE VerticalEdgeInsets() = default;

  explicit STU_CONSTEXPR
  VerticalEdgeInsets(const UIEdgeInsets& edgeInsets)
  : top{narrow_cast<Float32>(edgeInsets.top)},
    bottom{narrow_cast<Float32>(edgeInsets.bottom)}
  {}
};

struct TextLineVerticalPosition {
  Float64 baseline;
  Float32 ascent;
  Float32 descent;

  STU_INLINE Range<Float64> y() const { return baseline + Range{-ascent, descent}; }

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
  Float64 textFrameOriginY;
  Float64 ctmYOffset;
};

STU_INLINE
TextLineVerticalPosition textLineVerticalPosition(const TextFrameLine& line,
                                                  OptionalDisplayScaleRef displayScale,
                                                  VerticalEdgeInsets insets = VerticalEdgeInsets{},
                                                  VerticalOffsets offsets = VerticalOffsets{})
{
  Float64 baseline = line.originY;
  Float32 ascent = line.ascent + line.leading/2 - insets.top;
  Float32 descent = line.descent + line.leading/2 - insets.bottom;
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
  Int i = 0;
  for (const TextFrameLine& line : lines) {
    verticalPositions[i] = textLineVerticalPosition(line, displayScale, insets, offsets);
    ++i;
  }
  return verticalPositions;
}

struct TextLineSpansPathBounds {
  Rect<Float64> rect;
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
