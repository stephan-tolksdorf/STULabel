// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelDrawingBlock.h"
#import "STULabelLayoutInfo.h"
#import "STUTextRange.h"

typedef void (^ STULabelRenderTaskSchedulerBlock)(
               void * __nullable taskContext,
               void (* __nonnull taskFunction)(void * __nullable taskContext));

typedef NS_OPTIONS(uint8_t, STULabelPrerendererSizeOptions) {
  STUShrinkLabelWidthToFit  = 1,
  STUShrinkLabelHeightToFit = 2
};

STU_DISABLE_CLANG_WARNING("-Wunguarded-availability-new")
typedef NSDirectionalEdgeInsets STUDirectionalEdgeInsets;
STU_REENABLE_CLANG_WARNING


STU_ASSUME_NONNULL_AND_STRONG_BEGIN

/// Can be used to lay out and render a label's text in advance on a non-main thread.
///
/// Instances of this class can be safely created and used on a non-main thread, but concurrent
/// access from multiple threads is not safe (unless all accesses are non-mutating).
///
/// @note If the text contains links and the @c STULabel view in which you want to display the text
///       is configured with @c usesTintColorAsLinkColor set to true (the default), you need to set
///       the prerenderer's @c linkOverrideColor to the label's @c tintColor. If the prerenderer
///       uses the wrong color for links, the label will have to discard the prerendered image and
///       render the text again.
///
STU_EXPORT
@interface STULabelPrerenderer : NSObject
@end 
@interface STULabelPrerenderer (Interface)

// Calling one of the render methods freezes this object.
@property (nonatomic, readonly) bool isFrozen;

// None of the property setters may be called after the object has been frozen.
// (This is checked by an always-on assert).

@property (nonatomic, nullable) NSAttributedString *attributedText;

@property (nonatomic) STULabelDefaultTextAlignment defaultTextAlignment;

@property (nonatomic) UIUserInterfaceLayoutDirection userInterfaceLayoutDirection;

/// This property indicates whether the prerenderer currently stores a @c STUShapedString instance
/// that is accessible through the @c shapedText property.
@property (nonatomic, readonly) bool hasShapedText;

/// The prerenderer lazily constructs the @c STUShapedString instance from @c self.attributedText
/// and @c self.defaultBaseWritingDirection. If the attributed text is null, the getter returns an
/// empty shaped string.
///
/// When the prerenderer is frozen, the setter must not be called and the getter may only be called
/// if @c self.hasShapedText.
@property (nonatomic, readonly, null_resettable) STUShapedString *shapedText;

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) STULabelPrerendererSizeOptions sizeOptions;

@property (nonatomic, readonly) UIEdgeInsets contentInsets;

@property (nonatomic, readonly) STUDirectionalEdgeInsets directionalContentInsets;

/// Equivalent to
///
///     self.setSize(CGSize(width: width, height: maxHeight),
///                  contentInsets: contentInsets,
///                  options: [.shrinkLabelHeightToFit])
///
- (void)setWidth:(CGFloat)width maxHeight:(CGFloat)maxHeight
   contentInsets:(UIEdgeInsets)contentInsets;

/// Equivalent to
///
///     self.setSize(CGSize(width: width, height: maxHeight),
///                  directionalContentInsets: contentInsets,
///                  options: [.shrinkLabelHeightToFit])
///
- (void)setWidth:(CGFloat)width maxHeight:(CGFloat)maxHeight
directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets;

/// Equivalent to
///
///     self.setSize(CGSize(width: maxWidth, height: maxHeight), contentInsets: contentInsets,
///                  options: [.shrinkLabelWidthToFit, .shrinkLabelHeightToFit])
///
- (void)setMaxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight
      contentInsets:(UIEdgeInsets)contentInsets;

/// Equivalent to
///
///     self.setSize(CGSize(width: maxWidth, height: maxHeight),
///                  directionalContentInsets: contentInsets,
///                  options: [.shrinkLabelWidthToFit, .shrinkLabelHeightToFit])
///
- (void)setMaxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight
directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets;

- (void)setSize:(CGSize)size contentInsets:(UIEdgeInsets)contentInsets
        options:(STULabelPrerendererSizeOptions)options;

- (void)setSize:(CGSize)size directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets
        options:(STULabelPrerendererSizeOptions)options;

/// Default value: @c UIScreen.main.scale
@property (nonatomic) CGFloat displayScale;

@property (nonatomic) STULabelVerticalAlignment verticalAlignment;

// MARK: - STUTextFrameOptions properties

/// Sets @c maximumNumberOfLines, @c lastLineTruncationMode, @c truncationToken,
/// @c minimumTextScaleFactor, @c textScaleFactorStepSize, @c textScalingBaselineAdjustment and
/// @c lastHyphenationLocationInRangeCallback.
///
/// @c options.defaultTextAlignment is ignored.
- (void)setTextFrameOptions:(nullable STUTextFrameOptions*)options;

/// Default value: @c .default
@property (nonatomic) STUTextLayoutMode textLayoutMode;

/// Default value: 1
@property (nonatomic) NSInteger maximumNumberOfLines;

/// Default value: @c .end
@property (nonatomic) STULastLineTruncationMode lastLineTruncationMode;

/// Default value: @c nil
@property (nonatomic, copy, nullable) NSAttributedString *truncationToken;

/// Default value: 1
@property (nonatomic) CGFloat minimumTextScaleFactor;

/// Default value: 1/128.0 (May change in the future.)
@property (nonatomic) CGFloat textScaleFactorStepSize;

/// Default value: @c .alignFirstBaseline
@property (nonatomic) STUBaselineAdjustment textScalingBaselineAdjustment;

/// Default value: @c nil
@property (nonatomic, nullable) STULastHyphenationLocationInRangeFinder
                                  lastHyphenationLocationInRangeFinder;


// MARK: - Configuration properties that do not influence the text layout

@property (nonatomic, nullable) CGColorRef backgroundColor;

@property(nonatomic, getter=isHighlighted) bool highlighted;

@property (nonatomic, nullable) STUTextHighlightStyle *highlightStyle;

@property (nonatomic) STUTextRange highlightRange;

- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType
  NS_SWIFT_NAME(setHighlightRange(_:type:));

/// Default value: true
@property (nonatomic) bool overrideColorsApplyToHighlightedText;

@property (nonatomic, nullable) UIColor *overrideTextColor;

@property (nonatomic, nullable) UIColor *overrideLinkColor;

@property (nonatomic, nullable) STULabelDrawingBlock drawingBlock;

/// Default value: @c .textLayoutBoundsPlusInsets
@property (nonatomic) STULabelDrawingBounds drawingBlockImageBounds;

@property (nonatomic) STULabelDrawingBlockColorOptions drawingBlockColorOptions;

/// Default value: false
@property (nonatomic) bool clipsContentToBounds;

/// Default value: false
@property (nonatomic) bool neverUsesGrayscaleBitmapFormat;

/// Default value: `UIScreen.main.traitCollection.displayGamut == UIDisplayGamutSRGB`
@property (nonatomic) bool neverUsesExtendedRGBBitmapFormat;

/// Default value: false
@property (nonatomic) bool releasesShapedStringAfterRendering;

/// Default value: false
@property (nonatomic) bool releasesTextFrameAfterRendering;

// MARK: - Getting layout information

@property (nonatomic, readonly) bool hasLayoutInfo;

/// \pre `!self.isFrozen || self.hasLayoutInfo`
/// \post `self.hasLayoutInfo`
@property (nonatomic, readonly) STULabelLayoutInfo layoutInfo;

/// \pre `!self.isFrozen || self.hasLayoutInfo`
/// \post `self.hasLayoutInfo`
@property (nonatomic, readonly) CGSize sizeThatFits;

- (bool)tryGetSizeThatFits:(nullable CGSize *)outSizeThatFits
                layoutInfo:(nullable STULabelLayoutInfo *)outLayoutInfo
  NS_SWIFT_NAME(tryGet(sizeThatFits:layoutInfo:));

/// \pre `!self.isFrozen || self.hasLayoutInfo `
/// \post `self.hasLayoutInfo`
@property (nonatomic, readonly) STUTextLinkArray *links;

@property (nonatomic, readonly) bool hasTextFrame;

/// \pre `!self.isFrozen || self.hasTextFrame`
/// \post `self.hasTextFrame && self.hasLayoutInfo`
@property (nonatomic, readonly) STUTextFrame *textFrame;

// MARK: - Starting the rendering

/// Freezes this object.
/// \pre `!self.isFrozen`
/// \post `self.hasLayoutInfo && self.hasTextFrame == !self.releasesTextFrameAfterRendering`
- (void)render;

/// Equivalent to `[self renderAsyncOnQueue:nil]`.
/// Freezes this object.
/// \pre `!self.isFrozen`
- (void)renderAsync;

/// Freezes this object.
/// \pre `!self.isFrozen`
- (void)renderAsyncOnQueue:(nullable dispatch_queue_t)queue;

/// Freezes this object.
/// \pre `!self.isFrozen`
- (void)renderUsingScheduler:(STU_NOESCAPE STULabelRenderTaskSchedulerBlock)scheduler;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
