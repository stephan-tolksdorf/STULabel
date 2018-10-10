// Copyright 2016–2018 Stephan Tolksdorf

#import "STULabelPrerenderer.h"
#import "STULayerWithNullDefaultActions.h"
#import "STUTextFrameAccessibilityElement.h"

#import <UIKit/UIKit.h>

@protocol STULabelLayerDelegate;

/// @note This class must only be used on the main thread.
/// @note
/// @c encodeWithCoder: (@c encode(with:)) only calls the superclass method and doesn't encode
/// any of the @c STULabelLayer properties itself.
STU_EXPORT
@interface STULabelLayer : STULayerWithNullDefaultActions

@property (nonatomic, weak, nullable) NSObject<STULabelLayerDelegate> *labelLayerDelegate;

/// Default value: false
@property (nonatomic) bool displaysAsynchronously;

- (void)configureWithPrerenderer:(nonnull STULabelPrerenderer *)prerenderer;

/// The attributed string that should be displayed in the label.
///
/// Setting the @c attributedText also sets the values of the @c text, @c font, @c textColor and
/// @c textAlignment properties. The values of the @c font, @c textColor and
/// @c textAlignment properties are set to the corresponding attribute values of the first character
/// in the string.
///
/// The label uses the Core Text default font (Helvetica 12pt.) for ranges in the attributed string
/// that have no font attribute.
@property (nonatomic, copy, null_resettable) NSAttributedString *attributedText;

@property (nonatomic, copy, null_resettable) NSString *text;

@property (nonatomic, null_resettable) UIFont *font;

@property (nonatomic, null_resettable) UIColor *textColor;

@property (nonatomic) NSTextAlignment textAlignment;

/// The alignment of text paragraphs whose implicit or explicit @c NSTextAlignment is @c .natural
/// or @c .justified.
///
/// Default value: @c .leading
@property (nonatomic) STULabelDefaultTextAlignment defaultTextAlignment;

/// This value is used for interpreting the @c defaultTextAlignment modes @c .leading and
/// @c .trailing.
/// It is also used as the @c defaultBaseWritingDirection when the @c STULabelLayer constructs a
/// @c STUShapedString.
///
/// The initial value of this property is @c UIApplication.shared.userInterfaceLayoutDirection.
///
/// If the @c STULabelLayer is owned by a @c STULabel, the label view automatically sets the layer's
/// @c userInterfaceLayoutDirection to the value of the view's
/// @c effectiveUserInterfaceLayoutDirection and updates the value when the view's
/// @c semanticContentAttribute or @c traitCollection change.
@property (nonatomic) UIUserInterfaceLayoutDirection userInterfaceLayoutDirection;

/// The @c STUShapedString instance used by the label for layout and rendering purposes.
///
/// If necessary, the label lazily constructs the @c STUShapedString from @c self.attributedText
/// (with the default base writing direction corresponding to @c self.userInterfaceLayoutDirection).
///
/// If the attributed text is null, the getter returns an empty shaped string.
///
/// Since text shaping can be a relatively expensive operation, creating the shaped string in
/// advance on a background thread, e.g. from a collection view prefetch handler, and then
/// setting the label's @c shapedText instead of the @c attributedText can be an effective
/// optimization. (If you know the layout width of the label in advance, you could alternatively
/// use a @c STULabelPrerenderer to reduce the work on the main-thread even further.)
///
/// If the attributed text is null, the getter returns an empty shaped string.
@property (nonatomic, null_resettable) STUShapedString *shapedText;

/// Default value: @c .top
@property (nonatomic) STULabelVerticalAlignment verticalAlignment;

@property (nonatomic) UIEdgeInsets contentInsets;

@property (nonatomic) STUDirectionalEdgeInsets directionalContentInsets;

/// Default value: false
@property (nonatomic) bool clipsContentToBounds;

/// Sets @c maximumNumberOfLines, @c lastLineTruncationMode, @c truncationToken,
/// @c minimumTextScaleFactor, @c textScaleFactorStepSize, @c textScalingBaselineAdjustment and
/// @c lastHyphenationLocationInRangeCallback.
///
/// @c options.defaultTextAlignment is ignored.
- (void)setTextFrameOptions:(nullable STUTextFrameOptions *)options;

@property (nonatomic) STUTextLayoutMode textLayoutMode;

/// The maximum number of lines.
///
/// A value of 0 means that there is no maximum.
/// Default value: 1
@property (nonatomic) NSInteger maximumNumberOfLines;

/// Default value: @c .end
@property (nonatomic) STULastLineTruncationMode lastLineTruncationMode;

/// If the label's last line is truncated, this string will be inserted into into the text at the
/// point where the truncation starts.
///
/// If this string is nil or empty, an ellipsis '…' character will be used as the truncation token.
///
/// Any string attribute that is consistent over the full excised range from the original text
/// (ignoring any trailing whitespace) will be copied to the truncation token, without overwriting
/// any attribute already present in the token.
///
/// Default value: @c nil
@property (nonatomic, copy, nullable) NSAttributedString *truncationToken;

/// Default value: @c nil
@property (nonatomic, nullable) STUTruncationRangeAdjuster truncationRangeAdjuster;

/// Default value: 1
@property (nonatomic) CGFloat minimumTextScaleFactor;

/// Default value: 1/128.0 (May change in the future.)
@property (nonatomic) CGFloat textScaleFactorStepSize;

/// Default value: @c .alignFirstBaseline
@property (nonatomic) STUBaselineAdjustment textScalingBaselineAdjustment;

/// Default value: @c nil
@property (nonatomic, nullable) STULastHyphenationLocationInRangeFinder
                                  lastHyphenationLocationInRangeFinder;

/// The actually displayed background color of the @c STULabeLayer.
@property (nonatomic, nullable) CGColorRef displayedBackgroundColor;

/// The @c CALayer background color, which may be null even though the background color of the
/// displayed content is @c displayedBackgroundColor.
///
/// The @c STULabelLayer will automatically set and clear this property to optimize rendering
/// performance.
STU_DISABLE_CLANG_WARNING("-Wproperty-attribute-mismatch")
@property (nonatomic, nullable) CGColorRef backgroundColor
    DEPRECATED_MSG_ATTRIBUTE("Use displayedBackgroundColor instead.");
STU_REENABLE_CLANG_WARNING

@property (nonatomic, getter=isHighlighted) bool highlighted;

@property (nonatomic, strong, nullable) STUTextHighlightStyle *highlightStyle;

@property (nonatomic) STUTextRange highlightRange;

- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType
  NS_SWIFT_NAME(setHighlightRange(_:type:));

/// Default value: true
@property (nonatomic) bool overrideColorsApplyToHighlightedText;

@property (nonatomic, nullable) UIColor *overrideTextColor;

@property (nonatomic, nullable) UIColor *overrideLinkColor;

@property (nonatomic, strong, nullable) STULabelDrawingBlock drawingBlock;

@property (nonatomic) STULabelDrawingBlockColorOptions drawingBlockColorOptions;

/// Default value: @c .textLayoutBoundsPlusInsets
@property (nonatomic) STULabelDrawingBounds drawingBlockImageBounds;


/// Default value: false
@property (nonatomic) bool neverUsesGrayscaleBitmapFormat;

/// Default value: false
@property (nonatomic) bool neverUsesExtendedRGBBitmapFormat;

/// Default value: false
@property (nonatomic) bool releasesShapedStringAfterRendering;

/// Default value: false
@property (nonatomic) bool releasesTextFrameAfterRendering;

- (CGSize)sizeThatFits:(CGSize)size;

@property (nonatomic, readonly) STULabelLayoutInfo layoutInfo;

/// An array with @c STUTextLink objects for every link contained in the label's truncated text.
@property (nonatomic, readonly, nonnull) STUTextLinkArray *links;

@property (nonatomic, readonly, nonnull) STUTextFrame *textFrame NS_REFINED_FOR_SWIFT;
// var textFrame: STUTextFrameWithOrigin

@property (nonatomic, readonly) CGPoint textFrameOrigin NS_REFINED_FOR_SWIFT;

@property (copy, nonnull) NSString *contentsGravity
  STU_UNAVAILABLE("Use verticalAlignment and textAlignment or  NSParagraphStyle.textAlignment instead.");

@property BOOL drawsAsynchronously
  STU_UNAVAILABLE("Use displaysAsynchronously instead.");

@end

@protocol STULabelLayerDelegate <NSObject>
@optional

/// The proposed value is usually the current value of @c labelLayer.displaysAsynchronously,
/// but it may be @c false even when @c labelLayer.displaysAsynchronously is @c true if the
/// label implementation has determined that synchronous drawing may on this occasion be preferable
/// to avoid visible flickering.
- (bool)labelLayer:(nonnull STULabelLayer *)labelLayer
        shouldDisplayAsynchronouslyWithProposedValue:(bool)proposedValue;

/// Tells the delegate that the label layer displayed text in the specified bounds.
/// @param labelLayer The label layer.
/// @param flags Flags indicating various properties of the displayed text.
/// @param contentBounds
///  The bounds of the displayed text in the local coordinate system of the label layer.
- (void)labelLayer:(nonnull STULabelLayer *)labelLayer
didDisplayTextWithFlags:(STUTextFrameFlags)flags
            inRect:(CGRect)contentBounds;

/// Tells the delegate that the displayed text moved to the specified bounds.
///
/// This delegate method is only called when the label's bounds change in a way that doesn't
/// invalidate the text layout except for the relative position of the text within the label
/// and only when the label was already displaying the text before the change.
///
/// @param labelLayer The label layer.
/// @param contentBounds
///  The new bounds of the displayed text in the local coordinate system of the label layer.
- (void)labelLayer:(nonnull STULabelLayer *)labelLayer
didMoveDisplayedTextToRect:(CGRect)contentBounds;

- (void)labelLayerTextLayoutWasInvalidated:(nonnull STULabelLayer *)labelLayer;

- (void)labelLayer:(nonnull STULabelLayer *)labelLayer
needsVisibleBoundsUpdates:(bool)needsVisibleBoundsUpdates;

@end

