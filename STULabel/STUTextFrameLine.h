// Copyright 2016–2018 Stephan Tolksdorf

// NOTE:
// This header is part of the public "unsafe" lower-level Objective-C API of STULabel
// (STUTextFrame-Unsafe.h), because `STUTextFrameLine` instances are not reference-counted.
// They are owned by the `STUTextFrame` object. When the text frame is destroyed, so will be the
// `STUTextFrameLine` instances. Hence, while you access a `STUTextFrameLine`, you need to make sure
// that the text frame is kept alive, e.g. by storing a reference to the text frame in a local
// variable that is annotated with the NS_VALID_UNTIL_END_OF_SCOPE attribute.

#import "STUTextFrame.h"

#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

STU_EXTERN_C_BEGIN

typedef struct STURunGlyphIndex {
  int32_t runIndex;
  int32_t glyphIndex;
} STURunGlyphIndex;

/// Contains layout information for a single line in a @c STUTextFrame.
///
/// @note All coordinates and sizes are not yet scaled by the @c textScaleFactor of the
///       @c STUTextFrame.
///
/// @note All functions accepting a pointer to a @c STUTextFrameLine instance assume that the
///       instance is owned by a @c STUTextFrame. Never pass a pointer to a copied or manually
///       created @c STUTextFrameLine struct instance.
///
/// The line's typographic metrics are aggregated from the @c UIFont metrics and baseline offsets
/// of the line's styled text ranges as follows:
///
/// @code
///   rangeAscentᵢ  =  rangeᵢ.font.ascender  + rangeᵢ.baselineOffset
///   rangeDescentᵢ = -rangeᵢ.font.descender - rangeᵢ.baselineOffset
///   rangeLeadingᵢ =  rangeᵢ.font.leading
///
///   ascent₀  =  rangeAscent₀
///   descent₀ =  rangeDescent₀
///   leading₀ =  rangeLeading₀
///
///   ascentₙ  = max(ascentₙ₋₁, rangeAscentₙ)
///   descentₙ = max(descentₙ₋₁, rangeDescentₙ)
///   leadingₙ = 2*max(max(ascentₙ₋₁  + leadingₙ₋₁/2, rangeAscentₙ  + rangeLeadingₙ/2) - ascentₙ,
///                    max(descentₙ₋₁ + leadingₙ₋₁/2, rangeDescentₙ + rangeLeadingₙ/2) - descentₙ)
/// @endcode
typedef struct NS_REFINED_FOR_SWIFT STUTextFrameLine {

  /// The 0-based index of the line in the text frame.
  int32_t lineIndex;

  /// The 0-based index of the line's paragraph in the text frame.
  int32_t paragraphIndex;
  
  /// The UTF-16 code unit range in the original string corresponding to the text of this line,
  /// including any text that was replaced with a truncation token, excluding any trailing
  /// whitespace.
  ///
  /// @note If the line contains a truncation token that (also) replaces text after the line's
  ///       terminator in the original string, the range for that text is NOT included in this
  ///       range.
  STUStartEndRangeI32 rangeInOriginalString;

  /// The UTF-16 code unit range in the @c STUTextFrame.truncatedAttributedString corresponding to
  /// the text of this line, including the text of any truncation token, excluding any trailing
  /// whitespace.
  STUStartEndRangeI32 rangeInTruncatedString;

  /// The UTF-16 code unit length of the whitespace after this line in the truncated string up to
  /// and including the next line terminator, if there is one.
  int32_t trailingWhitespaceInTruncatedStringLength
            NS_SWIFT_NAME(trailingWhitespaceInTruncatedStringUTF16Length);


  STUTextFlags textFlags         : STUTextFlagsBitSize;

  /// The text flags for the non-token part(s) of the line.
  STUTextFlags nonTokenTextFlags : STUTextFlagsBitSize;

  /// The text flags for the truncation or hyphen token, if there is one.
  STUTextFlags tokenTextFlags    : STUTextFlagsBitSize;

  // Fields with an underscore name prefix are 'private' implementation details.

  uint8_t _initStep;

  /// If `hasInsertedHyphen`, the run index of the hyphen glyph in _tokenCTLine, otherwise -1.
  int8_t _hyphenRunIndex;

  /// If `hasInsertedHyphen`, the glyph index of the hyphen glyph in _tokenCTLine, otherwise -1.
  int8_t _hyphenGlyphIndex;

  STUWritingDirection paragraphBaseWritingDirection : 1;

  bool isFirstLineInParagraph : 1;

  /// Indicates whether the trailing whitespace in the original string ends with a line terminator.
  bool isFollowedByTerminatorInOriginalString : 1;

  /// Indicates whether this is the last line in the @c STUTextFrame.
  bool isLastLine : 1;

  /// Indicates whether a hyphen was inserted during line breaking.
  bool hasInsertedHyphen : 1;

  /// Indicates whether the line contains a truncation token.
  /// @note A line may have a truncation token even though the line itself wasn't truncated.
  ///       In that case the truncation token indicates that one or more following lines were
  ///       removed.
  bool hasTruncationToken : 1;

  bool isTruncatedAsRightToLeftLine : 1;

  /// The unscaled typographic width of the line, not including any trailing whitespace or
  /// paragraph indent.
  float width;

  /// The X-coordinate of the left end of the text line in the text frame's unscaled coordinate
  /// system.
  double originX;
  /// The Y-coordinate of the line's baseline in the text frame's unscaled coordinate system.
  /// @note When the line is drawn into a bitmap context, the baseline's Y-coordinate will be
  ///       rounded up (assuming an upper-left origin) to the next pixel boundary.
  double originY;

  // The line's aggregated font metrics (after font substitution).

  /// The line's typographic ascent after font substitution.
  float ascent;
  /// The line's typographic descent after font substitution.
  float descent;
  /// The line's typographic leading after font substitution.
  float leading;

  /// The line height above the baseline assumed for layout purposes before applying first baseline
  /// offsets and minimum baseline distances, including any line spacing that is attributed to the
  /// upper part of this text line.
  float _heightAboveBaseline;
  /// The line height below the baseline assumed for layout purposes before applying first baseline
  /// offsets and minimum baseline distances, including any line spacing that is attributed to the
  /// lower part of this text line.
  float _heightBelowBaseline;
  /// The line height below the baseline assumed for layout purposes before applying first baseline
  /// offsets and minimum baseline distances, excluding any line spacing.
  float _heightBelowBaselineWithoutSpacing;

  ptrdiff_t _textStylesOffset;
  ptrdiff_t _tokenStylesOffset;

  // Core Text has no public API for concatenating `CTLine` instances or for inserting a `CTRun`
  // into an existing `CTLine`, except `CTLineCreateTruncatedLine`, which isn't flexible enough for
  // the purposes of this library. To work around this limitation, a single text line is represented
  // by up to two `CTLine` instances. `_ctLine` holds the text from the original string and consists
  // of up to three parts: the left part, the right part, and the part in the middle that is not
  // displayed. Any of the three parts may be empty. `_tokenCTLine` holds the truncation token or
  // inserted hyphen and is drawn between the left and right part.
  //
  // This representation means that we often have to drop down to the CTRun level where
  // otherwise the CTLine functions would suffice, and it considerably complicates the traversal of
  // glyph spans (see Internal/TextFrameLine-GlyphSpanIteration.mm). It also forces us to do manual
  // kerning when e.g. inserting a hyphen. Unfortunately, there is no efficient alternative.
  // (Inserting e.g. a hyphen by copying the line's substring from the original attributed
  // string, inserting the hyphen string and then retypesetting the line would be a) inefficient
  // for longer lines with complex scripts and b) sometimes incorrect, because the Unicode bidi
  // context and the paragraph styling may not be fully preserved.)

  /// The CTLine holding the text from the original string.
  __nullable CTLineRef _ctLine;
  /// The CTLine of the truncation token or the inserted hyphen.
  __nullable CTLineRef _tokenCTLine;

  /// The end of the left part in `_ctLine`.
  /// A `_leftPartEnd.runIndex == -1` indicates that the left part is the full `_ctLine`.
  STURunGlyphIndex _leftPartEnd;
  /// The start of the right part in `_ctLine`.
  /// A `_rightPartStart.runIndex == -1` indicates that there is no right part.
  STURunGlyphIndex _rightPartStart;

  /// The typographic width of the part of the line left of the inserted token. Equals `width` if
  /// there is no token.
  float leftPartWidth;
  /// The typographic width of the inserted truncation token or hyphen.
  float tokenWidth;
  /// The additional x offset that needs to be added to the line's origin x when drawing the right
  /// part `_ctLine`. This value is 0 if there is no right part.
  float _rightPartXOffset;
  /// The typographic x offset of the hyphen glyph in `_tokenCTLine`.
  /// This value 0 if `!hasInsertedHyphen`.
  float _hyphenXOffset;

  // Image bounds for the text line relative to the origin that are usually conservative, but not
  // always, since they e.g. don't correctly account for the glyph path bounds of stacked combining
  // marks (like e.g. in Zalgo text).
  float fastBoundsMinX;
  float fastBoundsMaxX;
  float fastBoundsLLOMaxY;
  float fastBoundsLLOMinY;

  // The following atomic members are used to cache the calculated capHeight, xHeight and
  // glyphPathBounds. Use the getter functions below to get the values.
  _Atomic(float) _capHeight;
  _Atomic(float) _xHeight;
  // The _glyphsBoundingRect... variables are relative to the line's origin and use the LLO
  // coordinate system.
  _Atomic(float) _glyphsBoundingRectMinX;
  _Atomic(float) _glyphsBoundingRectMaxX;
  _Atomic(float) _glyphsBoundingRectLLOMinY;
  _Atomic(float) _glyphsBoundingRectLLOMaxY;
} STUTextFrameLine;

// These functions are all thread-safe.

/// Returns the text frame range corresponding to the text of this line, including the text of any
/// truncation token, excluding any trailing whitespace.
///
/// @pre @c line must be a pointer to a valid @c STUTextFrameLine instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
//  (This precondition is currently unnecessary, but may be needed in the future.)
NS_REFINED_FOR_SWIFT
STU_INLINE STUTextFrameRange STUTextFrameLineGetRange(const STUTextFrameLine * __nonnull line) {
  return (STUTextFrameRange){
           .start = {.indexInTruncatedString = (uint32_t)line->rangeInTruncatedString.start,
                     .lineIndex = (uint32_t)line->lineIndex},
           .end = {.indexInTruncatedString = (uint32_t)line->rangeInTruncatedString.end,
                   .lineIndex = (uint32_t)line->lineIndex}
         };
}

/// @pre @c line must be a pointer to a valid @c STUTextFrameLine instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
CGFloat STUTextFrameLineGetXHeight(const STUTextFrameLine * __nonnull line) NS_REFINED_FOR_SWIFT;

/// @pre @c line must be a pointer to a valid @c STUTextFrameLine instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
CGFloat STUTextFrameLineGetCapHeight(const STUTextFrameLine * __nonnull line) NS_REFINED_FOR_SWIFT;

/// @param xOffset
///  The X offset from the origin of the line in the unscaled coordinate system of the text frame.
/// @returns
///  The range of the grapheme cluster associated with the glyph whose typographic bounds contain
///  the specified X-coordinate. The returned bounds are relative to the line's origin in the
///  unscaled coordinate system of the text frame.
/// @pre
///  `0 <= x && x <= line->width`
/// @note
///  The allowed range of the `x` argument currently does not contain the X bounds of any trailing
///  whitespace. If `x == line.x + line.width`, the range of the rightmost non-trailing-whitespace
///  grapheme cluster is returned.
/// @pre `line` must be a pointer to a valid `STUTextFrameLine` instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
STUTextFrameGraphemeClusterRange STUTextFrameLineGetRangeOfGraphemeClusterAtXOffset(
                                   const STUTextFrameLine * __nonnull line, double xOffset);

STU_EXTERN_C_END


