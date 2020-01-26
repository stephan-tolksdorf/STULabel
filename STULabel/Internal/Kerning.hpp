// Copyright 2017–2018 Stephan Tolksdorf

#import "GlyphSpan.hpp"
#import "NSAttributedStringRef.hpp"

namespace stu_label {

enum class GlyphPositionInSpan {
  leftmostGlyph,
  rightmostGlyph,
  lastGlyphInStringOrder
};
constexpr auto leftmostGlyph = GlyphPositionInSpan::leftmostGlyph;
constexpr auto rightmostGlyph = GlyphPositionInSpan::rightmostGlyph;
constexpr auto lastGlyphInStringOrder = GlyphPositionInSpan::lastGlyphInStringOrder;

struct GlyphForKerningPurposes {
  /// Contains the original font, not the substituted fallback font.
  NSDictionary<NSAttributedStringKey, id>* __unsafe_unretained attributes;
  CTFont* font;
  Range<stu::Int> stringRange;
  bool isRightToLeftRun;
  bool hasDelegate;
  Optional<CGGlyph> glyph;
  /// > 0 if glyph != none
  stu::Float64 width;
  /// May be <= 0.
  stu::Float64 unkernedWidth;

  /// Finds the first glyph in the span that has a positive advance, with the search order
  /// determined by the specified GlyphPositionInSpan.
  /// Returns 0 if there is no such glyph or the CTRun has a delegate.
  static GlyphForKerningPurposes find(GlyphSpan, const NSAttributedStringRef&, GlyphPositionInSpan);
};

#ifndef STU_TRUNCATION_TOKEN_KERNING
  #define STU_TRUNCATION_TOKEN_KERNING 0
#endif

#if STU_TRUNCATION_TOKEN_KERNING

// This function is currently too slow to be really useful.
// (Because Core Text doesn't make the relevant CTFont API functions public.)
Optional<Float64> kerningAdjustment(const GlyphForKerningPurposes& glyph,
                                    const NSStringRef& string,
                                    const GlyphForKerningPurposes& nextGlyph,
                                    const NSStringRef& nextGlyphString);

#endif

constexpr stu::Char32 hyphenCodePoint = 0x2010;

struct HyphenLine {
  CTLine* line;
  stu::Float64 xOffset;
  stu::Float64 width;
  stu::Float64 trailingGlyphAdvanceCorrection;
  stu::Int8 runIndex;
  stu::Int8 glyphIndex;
};

HyphenLine createHyphenLine(const NSAttributedStringRef& originalAttributedString,
                            GlyphRunRef trailingRun, stu::Char32 hyphen);


} // namespace stu_label
