// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame.h"
#import "STUTextFrameLine.h"

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
  /// rangeInOriginalString.start == 0 && rangeInOriginalString.end == originalAttributedString.length
  bool rangeInOriginalStringIsFullString;
  /// The number of layout iterations that were necessary to determine the scaleFactor.
  /// If scaleFactor equals 1, this value is 1 too.
  uint8_t _layoutIterationCount;
  int32_t truncatedStringLength NS_SWIFT_NAME(truncatedStringUTF16Length);
  /// The UTF-16 range in the original string from which the STUTextFrame was constructed.
  STUStartEndRangeI32 rangeInOriginalString;
  /// The scale factor that was applied to shrink the text to fit the text frame's size. This value
  /// is always between 0 (exclusive) and 1 (inclusive). It only can be less than 1 if the
  /// `STUTextFrameOptions.minimumTextScaleFactor` was less than 1.
  CGFloat scaleFactor;
  /// The size that was specified when the `STUTextFrame` instance was initialized. This size can be
  /// much larger than the `typographicBounds.size`.
  CGSize size;
  /// The displayScale that was specified when the `STUTextFrame` instance was initialized,
  /// or 0 if the specified value was `nil` or outside the valid range.
  CGFloat displayScale NS_SWIFT_NAME(displayScaleOrZero);
  /// The smallest rectangle containing the scaled layout bound rectangles of all lines.
  /// @note
  ///   The layout bounds rectangle of a line is defined as:
  ///        CGRect(x: line.x, y: line.y - line.heightAboveBaseline,
  ///               width: line.width, height: line.heightAboveBaseline + line.heightBelowBaseline)
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

typedef struct NS_REFINED_FOR_SWIFT STUTextFrameParagraph {
  STUStartEndRangeI32 rangeInOriginalString;
  /// The range in the string that was excised because the paragraph was truncated or clipped.
  STUStartEndRangeI32 excisedRangeInOriginalString;
  STUStartEndRangeI32 rangeInTruncatedString;
  int32_t endLineIndex;
  int32_t paragraphIndex;
  int32_t truncationTokenLength NS_SWIFT_NAME(truncationTokenUTF16Length);
  STUTextFlags textFlags;
  STUParagraphAlignment alignment;
  STUWritingDirection baseWritingDirection : 1;
  bool isFirstParagraph : 1;
  bool isLastParagraph : 1;
  bool excisedStringRangeContinuesInNextParagraph : 1;
  uint8_t paragraphTerminatorInOriginalStringLength : 2
            NS_SWIFT_NAME(paragraphTerminatorInOriginalStringUTF16Length);
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

