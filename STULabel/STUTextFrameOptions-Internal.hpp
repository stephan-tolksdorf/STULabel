// Copyright 2018 Stephan Tolksdorf

#import "STUTextFrame.h"

#import "STULabelAlignment.h"

namespace stu_label {
  // Note: There are two places where we mutate text frame option properties:
  //       `STUTextFrameOptionsBuilder` and `LabelPropertiesCRTPBase`.
  struct TextFrameOptions {
    NSInteger maximumNumberOfLines;
    STUTextLayoutMode textLayoutMode;
    STUDefaultTextAlignment defaultTextAlignment;
    STULastLineTruncationMode lastLineTruncationMode;
    NSAttributedString* __nullable truncationToken;
    NSAttributedString* __nullable fixedTruncationToken;
    __nullable STUTruncationRangeAdjuster truncationRangeAdjuster;
    CGFloat minimumTextScaleFactor;
    CGFloat textScaleFactorStepSize;
    STUBaselineAdjustment textScalingBaselineAdjustment;
    __nullable STULastHyphenationLocationInRangeFinder lastHyphenationLocationInRangeFinder;
  };
}

@interface STUTextFrameOptions () {
@package
  stu_label::TextFrameOptions _options;
}
@end

STUTextFrameOptions* STUTextFrameOptionsCopy(STUTextFrameOptions* options) NS_RETURNS_RETAINED;

STU_INLINE
STUDefaultTextAlignment stuDefaultTextAlignment(STULabelDefaultTextAlignment defaultTextAligment,
                                                STUWritingDirection defaultBaseWritingDirection)
{
  switch (defaultTextAligment) {
  case STULabelDefaultTextAlignmentLeading:
  case STULabelDefaultTextAlignmentTrailing:
    static_assert((int)STULabelDefaultTextAlignmentLeading == 0);
    static_assert((int)STULabelDefaultTextAlignmentTrailing == 1);
    static_assert((int)STUWritingDirectionLeftToRight == 0);
    static_assert((int)STUWritingDirectionRightToLeft == 1);
    static_assert((int)STUDefaultTextAlignmentLeft == 0);
    static_assert((int)STUDefaultTextAlignmentRight == 1);
    return STUDefaultTextAlignment(defaultBaseWritingDirection ^ defaultTextAligment);
  case STULabelDefaultTextAlignmentTextStart:
  case STULabelDefaultTextAlignmentTextEnd:
    static_assert((int)STULabelDefaultTextAlignmentTextStart == (int)STUDefaultTextAlignmentStart);
    static_assert((int)STULabelDefaultTextAlignmentTextEnd   == (int)STUDefaultTextAlignmentEnd);
    return STUDefaultTextAlignment(defaultTextAligment);
  }
}
