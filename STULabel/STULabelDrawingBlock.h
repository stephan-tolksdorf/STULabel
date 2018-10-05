// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

STU_EXPORT
@interface STULabelDrawingBlockParameters : NSObject

@property (readonly) STUTextFrame *textFrame NS_REFINED_FOR_SWIFT;
  // var textFrame: STUTextFrameWithOrigin

@property (readonly) STUTextFrameRange range NS_REFINED_FOR_SWIFT;
  // var indices: Range<STUTextFrame.Index>

@property (readonly) CGPoint textFrameOrigin NS_REFINED_FOR_SWIFT;

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

typedef NS_ENUM(uint8_t, STULabelDrawingBounds) {
  STULabelTextImageBounds = 1,
  STULabelTextLayoutBounds = 2,
  STULabelTextLayoutBoundsPlusInsets = 0,
  STULabelViewBounds = 3
};
enum { STULabelDrawingBoundsBitSize STU_SWIFT_UNAVAILABLE = 2 };

typedef NS_OPTIONS(uint8_t, STULabelDrawingBlockColorOptions) {
  /// Indicates that the drawing block only uses colors present in the content of the text frame,
  /// or other grayscale colors.
  STULabelDrawingBlockOnlyUsesTextColors = 1,
  /// Indicates that the drawing block needs a bitmap context with a wide-gamut color space and more
  /// than 8-bits per color channel for optimal display quality.
  STULabelDrawingBlockUsesExtendedColors = 2
};
enum { STULabelDrawingBlockColorOptionsBitSize STU_SWIFT_UNAVAILABLE = 3 };

STU_ASSUME_NONNULL_AND_STRONG_END
