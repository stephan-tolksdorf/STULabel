// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

STU_EXPORT
@interface STULabelDrawingBlockParameters : NSObject

@property (readonly) STUTextFrame *textFrame;
@property (readonly) STUTextFrameRange range;
@property (readonly) CGPoint textFrameOrigin;
@property (readonly) CGContextRef context;
@property (readonly) CGFloat contextBaseCTM_d;
@property (readonly) bool pixelAlignBaselines;
@property (readonly, nullable) STUTextFrameDrawingOptions *options;
@property (readonly, nullable) const STUCancellationFlag *cancellationFlag;

- (void)draw;

- (nonnull instancetype)init NS_UNAVAILABLE;

@end

/// Must be thread-safe.
typedef void (^ STULabelDrawingBlock)(STULabelDrawingBlockParameters *params);

STU_ASSUME_NONNULL_AND_STRONG_END
