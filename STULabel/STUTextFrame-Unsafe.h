// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame.h"
#import "STUTextFrameLine.h"

STU_EXTERN_C_BEGIN

@interface STUTextFrame () {
@public
  const struct STUTextFrameData * const data;
}
@end

typedef struct STUTextBackgroundSegment STUTextBackgroundSegment;

typedef struct STUTextFrameData {
  int32_t paragraphCount;
  int32_t lineCount;
  const uint8_t * __nonnull _textStylesData;
  uint16_t _colorCount;
  STUTextFrameFlags flags;
  STUTextFrameConsistentAlignment consistentAlignment;
  STUTextLayoutMode layoutMode;
  /// Indicates whether `rangeInOriginalString.start == 0` and
  /// `rangeInOriginalString.end == originalAttributedString.length`.
  bool rangeInOriginalStringIsFullString;
  /// The number of layout iterations that were necessary to determine the textScaleFactor.
  /// If textScaleFactor equals 1, this value is 1 too.
  uint8_t _layoutIterationCount;
  int32_t truncatedStringLength NS_SWIFT_NAME(truncatedStringUTF16Length);
  /// The range in the original string from which the STUTextFrame was created.
  STUStartEndRangeI32 rangeInOriginalString;
  /// The scale factor that was applied to shrink the text to fit the text frame's size. This value
  /// is always between 0 (exclusive) and 1 (inclusive). It only can be less than 1 if the
  /// `STUTextFrameOptions.minimumTextScaleFactor` was less than 1.
  CGFloat textScaleFactor;
  /// The size that was specified when the `STUTextFrame` instance was initialized. This size can be
  /// much larger than the `typographicBounds.size`.
  CGSize size;
  /// The displayScale that was specified when the `STUTextFrame` instance was initialized,
  /// or 0 if the specified value was `nil` or outside the valid range.
  CGFloat displayScale NS_SWIFT_NAME(displayScaleOrZero);
  /// The smallest rectangle containing the scaled layout bound rectangles of all lines.
  /// @note The layout bounds rectangle of a line is defined as:
  ///        @code
  ///        CGRect(x: line.x, y: line.y - line.heightAboveBaseline,
  ///               width: line.width, height: line.heightAboveBaseline + line.heightBelowBaseline)
  ///        @endcode
  CGRect layoutBounds;
  size_t _dataSize;
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
  STUParagraphAlignmentJustifiedLeft  = 1,
  STUParagraphAlignmentRight          = 2,
  STUParagraphAlignmentJustifiedRight = 3,
  STUParagraphAlignmentCenter         = 4
};

/// Text paragraphs are separated by any of the following characters (grapheme clusters):
/// `"\r"`, `"\n"`, `"\r\n"`,`"\u2029"`
typedef struct NS_REFINED_FOR_SWIFT STUTextFrameParagraph {
  /// The 0-based index of the paragraph in the text frame.
  int32_t paragraphIndex;
  /// The index of the first text frame line associated with a subsequent paragraph, or the
  /// text frame's line count if there is no such line.
  int32_t endLineIndex;
  /// The paragraph's range in the `STUTextFrame.originalAttributedString`.
  ///
  /// This range includes any trailing whitespace of the paragraph, including the paragraph
  /// terminator (unless the paragraph is the last paragraph and has no terminator)
  STUStartEndRangeI32 rangeInOriginalString;
  /// The subrange of the `rangeInOriginalString` that was replaced by a truncation token, or the
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
  bool isFirstParagraph : 1;
  bool isLastParagraph : 1;
  bool excisedStringRangeIsContinuedInNextParagraph : 1;
  bool excisedStringRangeIsContinuationFromLastParagraph : 1;
  /// The UTF-16 code unit length of the paragraph terminator (`"\r"`, `"\n"`, `"\r\n"` or
  /// `"\u2029"`). The value is between 0 and 2 (inclusive).
  uint8_t paragraphTerminatorInOriginalStringLength : 2
            NS_SWIFT_NAME(paragraphTerminatorInOriginalStringUTF16Length);
  /// The truncation token in the last line of this paragraph,
  /// or `nil` if the paragraph is not truncated.
  ///
  /// @note If `excisedStringRangeIsContinuationFromLastParagraph`, the paragraph has no text lines
  ///       and no truncation token even though `excisedRangeInOriginalString` is not empty.
  NSAttributedString * __unsafe_unretained __nullable truncationToken;
} STUTextFrameParagraph;

static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameParagraph * __nonnull
  STUTextFrameDataGetParagraphs(const STUTextFrameData * __nonnull data)
{
  return (const STUTextFrameParagraph *)
           ((const STUTextFrameLine *)(data + 1));
}

static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameLine * __nonnull
  STUTextFrameDataGetLines(const STUTextFrameData * __nonnull data)
{
  return (const STUTextFrameLine *)(STUTextFrameDataGetParagraphs(data) + data->paragraphCount);
}

static STU_INLINE NS_REFINED_FOR_SWIFT
const STUTextFrameParagraph * __nonnull
  STUTextFrameLineGetParagraph(const STUTextFrameLine * __nonnull line)
{
  __auto_type * const lastPara = (const STUTextFrameParagraph *)(line - line->lineIndex) - 1;
  return lastPara + (line->paragraphIndex - lastPara->paragraphIndex);
}

static STU_INLINE NS_REFINED_FOR_SWIFT
int32_t STUTextFrameParagraphGetStartIndexOfTruncationTokenInTruncatedString(
                      const STUTextFrameParagraph * __nonnull pinfo)
{
  return pinfo->rangeInTruncatedString.start
       + (pinfo->excisedRangeInOriginalString.start - pinfo->rangeInOriginalString.start);
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

STU_EXTERN_C_END
