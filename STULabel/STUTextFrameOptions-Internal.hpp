// Copyright 2018 Stephan Tolksdorf

#import "STUTextFrame.h"

#import "STULabelAlignment.h"

// TODO: Move the instance variables into an impl C++ class.

@interface STUTextFrameOptions () {
@package
  NSInteger _maximumLineCount;
  STUTextLayoutMode _textLayoutMode;
  STUDefaultTextAlignment _defaultTextAlignment;
  STULastLineTruncationMode _lastLineTruncationMode;
  NSAttributedString * __nullable _truncationToken;
  NSAttributedString * __nullable _fixedTruncationToken;
  __nullable STUTruncationRangeAdjuster _truncationRangeAdjuster;
  CGFloat _minimumTextScaleFactor;
  CGFloat _textScaleFactorStepSize;
  STUBaselineAdjustment _textScalingBaselineAdjustment;
  __nullable STULastHyphenationLocationInRangeFinder _lastHyphenationLocationInRangeFinder;
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
