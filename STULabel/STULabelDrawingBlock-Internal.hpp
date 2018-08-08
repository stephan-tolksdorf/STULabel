// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelDrawingBlock.h"

#import "STUTextFrame-Internal.hpp"

namespace stu_label {

STULabelDrawingBlockParameters *
  createLabelDrawingBlockParametersInstance(
    STUTextFrame *textFrame, STUTextFrameRange range, CGPoint textFrameOrigin,
    CGContextRef context, ContextBaseCTM_d, PixelAlignBaselines,
    STUTextFrameDrawingOptions * __nullable options,
    const STUCancellationFlag * __nullable cancellationFlag)
  NS_RETURNS_RETAINED;

} // namespace stu_label
