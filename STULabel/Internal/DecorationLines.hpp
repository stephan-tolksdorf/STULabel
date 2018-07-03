// Copyright 2017–2018 Stephan Tolksdorf

#import "Font.hpp"
#import "GlyphSpan.hpp"
#import "DisplayScaleRounding.hpp"
#import "SortedIntervalBuffer.hpp"
#import "TextStyle.hpp"

namespace stu_label {

class DrawingContext;

struct DecorationLine {
  struct OffsetAndThickness {
    CGFloat offsetLLO;
    CGFloat thickness;

    STU_INLINE
    Range<CGFloat> yLLO() const { return {offsetLLO + Range{-thickness/2, thickness/2}}; }

    static OffsetAndThickness forUnderline(const TextStyle::UnderlineInfo&,
                                           const TextStyle::BaselineOffsetInfo* __nullable,
                                           const CachedFontInfo&,
                                           OptionalDisplayScaleRef);

    static OffsetAndThickness forStrikethrough(const TextStyle::StrikethroughInfo&,
                                               const TextStyle::BaselineOffsetInfo* __nullable,
                                               const CachedFontInfo&,
                                               OptionalDisplayScaleRef);
  };

  Rect<CGFloat> rectLLO() const { return {x, {offsetLLO + Range{-thickness/2, thickness/2}}}; }

  OffsetAndThickness offsetAndThickness() const {
    return {.offsetLLO = offsetLLO, .thickness = thickness};
  }

  Range<CGFloat> x;
  CGFloat offsetLLO;
  CGFloat thickness;
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

  void draw(DrawingContext&) const;
};

struct Strikethroughs {
  TempArray<DecorationLine> lines;
  bool hasShadow;

  static Strikethroughs find(const TextFrameLine& line, DrawingContext& context);

  void draw(DrawingContext&) const;
};

} // stu_label
