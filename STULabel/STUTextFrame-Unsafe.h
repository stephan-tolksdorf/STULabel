// Copyright 2017–2018 Stephan Tolksdorf

// NOTE:
// This header is part of the public "unsafe" lower-level Objective-C API of STULabel.
// `STUTextFrameData`, `STUTextFrameParagraph` and `STUTextFrameLine` instances are not
// reference-counted. They are owned by the `STUTextFrame` object. When the text frame is destroyed,
// so will be the `STUTextFrameData`, `STUTextFrameParagraph` and `STUTextFrameLine` instances.
// Hence, while you access these data structs through pointers into memory owned by a text frame,
// you need to make sure that the text frame is kept alive, e.g. by storing a reference to the text
// frame in a local variable that is annotated with the NS_VALID_UNTIL_END_OF_SCOPE attribute.

#import "STUTextFrame.h"
#import "STUTextFrameLine.h"

STU_EXTERN_C_BEGIN

@interface STUTextFrame () {
@public
  /// @note Points into memory owned by the @c STUTextFrame instance.
  const struct STUTextFrameData * const data;
}
@end

typedef struct STUTextBackgroundSegment STUTextBackgroundSegment;

/// @note All functions accepting a pointer to a @c STUTextFrameData instance assume that the
///       instance is owned by a @c STUTextFrame. Never pass a pointer to a copied or manually
///       created @c STUTextFrameData struct instance.
typedef struct STUTextFrameData {
  int32_t paragraphCount;
  int32_t lineCount;
  const uint8_t * __nonnull _textStylesData;
  uint16_t _colorCount;
  STUTextFrameFlags flags;
  STUTextFrameConsistentAlignment consistentAlignment;
  /// The mode in which the text layout was calculated.
  STUTextLayoutMode layoutMode;
  /// Indicates whether `rangeInOriginalString.start == 0` and
  /// `rangeInOriginalString.end == originalAttributedString.length`.
  bool rangeInOriginalStringIsFullString;
  /// The number of layout iterations that were necessary to determine the textScaleFactor.
  /// If textScaleFactor equals 1, this value is 1 too.
  uint8_t _layoutIterationCount;
  int32_t truncatedStringLength NS_SWIFT_NAME(truncatedStringUTF16Length);
  /// The range in the original string from which the @c STUTextFrame was created.
  STUStartEndRangeI32 rangeInOriginalString;
  /// The size that was specified when the @c STUTextFrame instance was initialized. This size can
  /// be much larger than the layout bounds of the text, particularly if the text frame was created
  ///  by a label view, which may create text frames with e.g. a height of CGFLOAT_MAX.
  CGSize size;
  /// The displayScale that was specified when the @c STUTextFrame instance was initialized,
  /// or 0 if the specified value was @c nil or outside the valid range.
  CGFloat displayScale NS_SWIFT_NAME(displayScaleOrZero);
  /// The scale factor that was applied to shrink the text to fit the text frame's size. This value
  /// is always between 0 (exclusive) and 1 (inclusive). It only can be less than 1 if the
  /// @c STUTextFrameOptions.minimumTextScaleFactor was less than 1.
  CGFloat textScaleFactor;
  /// The minimum X value of the layout bounds of all text lines in the coordinate system of the
  /// (scaled) text frame, including the space of any horizontal paragraph insets.
  double minX;
  /// The maximum X value (minX + width) of the layout bounds of all text lines in the coordinate
  /// system of the (scaled) text frame, including the space of any horizontal paragraph insets.
  double maxX;
  /// The Y-coordinate of the first baseline in the coordinate system of the (scaled) text frame.
  double firstBaseline;
  /// The Y-coordinate of the last baseline in the coordinate system of the (scaled) text frame.
  double lastBaseline;
  /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float firstLineHeight;
  /// The part of the first line's layout height that lies above the baseline.
  float firstLineHeightAboveBaseline;
  /// The value that the line layout algorithm would calculate for the distance between the last
  /// baseline and the baseline of the hypothetical next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float lastLineHeight;
  /// The part of the last line's layout height that lies below the baseline.
  float lastLineHeightBelowBaseline;
  /// The part of the last line's layout height that lies below the baseline, excluding any line
  /// spacing. This is the height below the baseline that is assumed when deciding whether the
  /// line fits the text frame's size.
  float lastLineHeightBelowBaselineWithoutSpacing;
  /// The part of the last line's layout height that lies below the baseline, with only a minimal
  /// layout-mode-dependent amount of spacing included. This is the height below the baseline
  /// assumed for a label's intrinsic content height.
  float lastLineHeightBelowBaselineWithMinimalSpacing;
  size_t _dataSize;
  /// The attributed string of the @c STUShapedString from which this text frame was created.
  NSAttributedString * __unsafe_unretained __nullable originalAttributedString;
  _Atomic(CFAttributedStringRef) _truncatedAttributedString;
  _Atomic(const STUTextBackgroundSegment *) _backgroundSegments;
} STUTextFrameData;

static STU_INLINE NS_REFINED_FOR_SWIFT
STUTextFrameIndex STUTextFrameDataGetEndIndex(const STUTextFrameData * __nonnull data) {
  return (STUTextFrameIndex){.indexInTruncatedString = (uint32_t)data->truncatedStringLength,
                             .lineIndex = (uint32_t)MAX(0, data->lineCount - 1)};
}

typedef NS_ENUM(uint8_t, STUParagraphAlignment)  {
  STUParagraphAlignmentLeft           = 0,
#if !TARGET_ABI_USES_IOS_VALUES
  STUParagraphAlignmentJustifiedLeft  = 2,
  STUParagraphAlignmentRight          = 1,
#else
  STUParagraphAlignmentJustifiedLeft  = 1,
  STUParagraphAlignmentRight          = 2,
#endif
  STUParagraphAlignmentJustifiedRight = 3,
  STUParagraphAlignmentCenter         = 4,
};

/// Contains layout information for a single paragraph in a @c STUTextFrame.
///
/// Text paragraphs are separated by any of the following characters (grapheme clusters):
/// `"\r"`, `"\n"`, `"\r\n"`,`"\u2029"`
typedef struct NS_REFINED_FOR_SWIFT STUTextFrameParagraph {
  /// The 0-based index of the paragraph in the text frame.
  int32_t paragraphIndex;
  STUStartEndRangeI32 lineIndexRange;
  int32_t initialLinesEndIndex;
  /// The paragraph's range in the @c STUTextFrame.originalAttributedString.
  ///
  /// This range includes any trailing whitespace of the paragraph, including the paragraph
  /// terminator (unless the paragraph is the last paragraph and has no terminator)
  STUStartEndRangeI32 rangeInOriginalString;
  /// The subrange of the @c rangeInOriginalString that was replaced by a truncation token, or the
  /// empty range with `start = end = rangeInOriginalString.end` if the paragraph was not truncated.
  ///
  /// @note If the range in the original string replaced with a truncation token spans multiple
  ///       paragraphs, only the first paragraph will have a truncation token. The other
  ///       paragraphs will have no text lines.
  ///
  /// @note If the last line of the paragraph is not truncated but contains a truncation token
  ///       because the following text from the next paragraph was removed during truncation,
  ///       this range will only contain the last line's trailing whitespace, including
  ///       the paragraph terminator.
  STUStartEndRangeI32 excisedRangeInOriginalString;
  /// The range in the text frame's truncated string corresponding to the paragraph's text.
  STUStartEndRangeI32 rangeInTruncatedString;
  /// The UTF-16 code unit length of the truncation token.
  int32_t truncationTokenLength NS_SWIFT_NAME(truncationTokenUTF16Length);
  STUTextFlags textFlags;
  STUParagraphAlignment alignment;
  STUWritingDirection baseWritingDirection : 1;
  bool isLastParagraph : 1;
  bool excisedStringRangeIsContinuedInNextParagraph : 1;
  bool excisedStringRangeIsContinuationFromLastParagraph : 1;
  /// The UTF-16 code unit length of the paragraph terminator (`"\r"`, `"\n"`, `"\r\n"` or
  /// `"\u2029"`). The value is between 0 and 2 (inclusive).
  uint8_t paragraphTerminatorInOriginalStringLength : 2
            NS_SWIFT_NAME(paragraphTerminatorInOriginalStringUTF16Length);
  bool isIndented : 1;
  /// The truncation token in the last line of this paragraph,
  /// or @c nil if the paragraph is not truncated.
  ///
  /// @note If @c excisedStringRangeIsContinuationFromLastParagraph, the paragraph has no text lines
  ///       and no truncation token even though @c excisedRangeInOriginalString is not empty.
  NSAttributedString * __unsafe_unretained __nullable truncationToken;
  CGFloat initialLinesLeftIndent;
  CGFloat initialLinesRightIndent;
  CGFloat nonInitialLinesLeftIndent;
  CGFloat nonInitialLinesRightIndent;
} STUTextFrameParagraph;

/// @pre @c data must be a pointer to a valid @c STUTextFrameData instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameParagraph * __nonnull
  STUTextFrameDataGetParagraphs(const STUTextFrameData * __nonnull data)
{
  return (const STUTextFrameParagraph *)
           ((const STUTextFrameLine *)(data + 1));
}

/// @pre @c data must be a pointer to a valid @c STUTextFrameData instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameLine * __nonnull
  STUTextFrameDataGetLines(const STUTextFrameData * __nonnull data)
{
  return (const STUTextFrameLine *)(STUTextFrameDataGetParagraphs(data) + data->paragraphCount);
}

/// @pre @c line must be a pointer to a valid @c STUTextFrameLine instance owned by a text frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameParagraph * __nonnull
  STUTextFrameLineGetParagraph(const STUTextFrameLine * __nonnull line)
{
  __auto_type * const lastPara = (const STUTextFrameParagraph *)(line - line->lineIndex) - 1;
  return lastPara + (line->paragraphIndex - lastPara->paragraphIndex);
}

/// @pre @c para must be a pointer to a valid @c STUTextFrameParagraph instance owned by a text
///       frame.
///       Passing in a pointer to a copy of the original instance or to a manually created instance
///       will lead to undefined behaviour.
//  (This precondition is currently unnecessary, but may be needed in the future.)
static STU_INLINE NS_REFINED_FOR_SWIFT
int32_t STUTextFrameParagraphGetStartIndexOfTruncationTokenInTruncatedString(
                      const STUTextFrameParagraph * __nonnull para)
{
  return para->rangeInTruncatedString.start
       + (para->excisedRangeInOriginalString.start - para->rangeInOriginalString.start);
}

static STU_INLINE NS_SWIFT_NAME(STUTextFrameConsistentAlignment.init(_:))
STUTextFrameConsistentAlignment stuTextFrameConsistentAlignment(STUParagraphAlignment alignment) {
  switch (alignment) {
  case STUParagraphAlignmentLeft:
  case STUParagraphAlignmentJustifiedLeft:
    return STUTextFrameConsistentAlignmentLeft;
  case STUParagraphAlignmentCenter:
    return STUTextFrameConsistentAlignmentCenter;
  case STUParagraphAlignmentRight:
  case STUParagraphAlignmentJustifiedRight:
    return STUTextFrameConsistentAlignmentRight;
  default:
    return STUTextFrameConsistentAlignmentNone;
  }
}

static STU_INLINE NS_SWIFT_NAME(getter:STUTextFrame.__data(self:))
const STUTextFrameData * __nonnull __STUTextFrameGetData(const STUTextFrame * __nonnull textFrame) {
  return textFrame->data;
}

STU_EXPORT
extern const bool __STULabelWasBuiltWithAddressSanitizer;

STU_EXTERN_C_END
