// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelLayer.h"

#import "STUImageUtils.h"

#import "Internal/Unretained.hpp"

@interface STULabelLayer ()

- (void)stu_didMoveToWindow:(UIWindow*)window;

@property (nonatomic, setter=stu_setAlwaysUsesContentSublayer:) bool stu_alwaysUsesContentSublayer;

@property (readonly, nullable) CALayer* stu_contentSublayer;

@end

namespace stu_label {
  struct LabelParameters;
  struct LabelTextFrameInfo;
  Unretained<STUTextFrameOptions* __nonnull> defaultLabelTextFrameOptions();
}

// For some reason LabelLayer can't friend this function if the CGSize is returned by value.
const CGSize& STULabelLayerGetSize(const STULabelLayer* __nonnull);

CGFloat STULabelLayerGetScreenScale(const STULabelLayer* __nonnull);

bool STULabelLayerIsAttributed(const STULabelLayer* __nonnull);

const stu_label::LabelParameters& STULabelLayerGetParams(const STULabelLayer* __nonnull);

NSInteger STULabelLayerGetMaximumNumberOfLines(const STULabelLayer* __nonnull);

const stu_label::LabelTextFrameInfo& STULabelLayerGetCurrentTextFrameInfo(STULabelLayer* __nonnull);

