// Copyright 2017–2018 Stephan Tolksdorf

#import "Font.hpp"
#import "GlyphSpan.hpp"
#import "DisplayScaleRounding.hpp"
#import "SortedIntervalBuffer.hpp"
#import "TextStyle.hpp"

namespace stu_label {

class DrawingContext;

struct StyledGlyphSpan;

struct DecorationLine {
  struct OffsetAndThickness {
    /// The LLO Y-offset from the baseline to the center of the line.
    CGFloat offsetLLO;
    CGFloat thickness;
    CGFloat unroundedThickness;

    STU_INLINE
    Range<CGFloat> yLLO() const { return {offsetLLO + Range{-thickness/2, thickness/2}}; }

    /// @pre style.strikethroughInfo() != nullptr
    static OffsetAndThickness forStrikethrough(const StyledGlyphSpan&, const TextStyle&,
                                               FontRef, OptionalDisplayScaleRef,
                                               LocalFontInfoCache&);
  };

  Rect<CGFloat> rectLLO() const { return {x, {offsetLLO + Range{-thickness/2, thickness/2}}}; }

  OffsetAndThickness offsetAndThickness() const {
    return {.offsetLLO = offsetLLO,
            .thickness = thickness,
            .unroundedThickness = unroundedThickness};
  }

  Range<CGFloat> x;
  CGFloat fullLineXStart;
  /// The offset rounded for the drawing context display scale.
  CGFloat offsetLLO;
  /// The thickness rounded for the drawing context display scale.
  CGFloat thickness;
  /// The offset rounded for the textFrame.displayScale if that scale is nonzero,
  /// otherwise this->offsetLLO.
  CGFloat originalOffsetLLO;
  /// The thickness rounded for the textFrame.displayScale if that scale is nonzero,
  /// otherwise this->thickness.
  CGFloat originalThickness;
  CGFloat unroundedThickness;
  NSUnderlineStyle style : 32;
  ColorIndex colorIndex;
  bool hasUnderlineContinuation;
  bool isUnderlineContinuation;
  const TextStyle::ShadowInfo * __nullable shadowInfo;
};

struct TextFrameLine;

struct Underlines {
  TempArray<DecorationLine> lines;
  TempArray<Range<CGFloat>> lowerLinesGaps;
  TempArray<Range<CGFloat>> upperLinesGaps;
  bool hasShadow;
  bool hasDoubleLine;

  static Underlines find(const TextFrameLine& line, DrawingContext& context);

  /// The offset and thickness of a run's underline may depend on the styling of adjacent runs.
  /// The returned rect contains the bounds of any shadow.
  static Rect<Float64> imageBoundsLLO(const TextFrameLine&, Optional<TextStyleOverride&>,
                                      const Optional<DisplayScale>&, LocalFontInfoCache&);

  void drawLLO(DrawingContext&) const;
};

struct Strikethroughs {
  TempArray<DecorationLine> lines;
  bool hasShadow;

  static Strikethroughs find(const TextFrameLine& line, DrawingContext& context);

  void drawLLO(DrawingContext&) const;
};

} // stu_label
