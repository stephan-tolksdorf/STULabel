// Copyright 2016–2018 Stephan Tolksdorf

#import "STULabelPrerenderer.h"
#import "STULayerWithNullDefaultActions.h"
#import "STUTextFrameAccessibilityElement.h"

#import <UIKit/UIKit.h>

@protocol STULabelLayerDelegate;

/// @note This class must only be used on the main thread.
/// @note
/// `encodeWithCoder:` (`encode(with:)`) only calls the superclass method and doesn't encode
/// any of the `STULabelLayer` properties itself.
STU_EXPORT
@interface STULabelLayer : STULayerWithNullDefaultActions

@property (nonatomic, weak, nullable) NSObject<STULabelLayerDelegate> *labelLayerDelegate;

/// Default value: false
@property (nonatomic) bool displaysAsynchronously;

- (void)configureWithPrerenderer:(nonnull STULabelPrerenderer *)prerenderer;

@property (nonatomic, copy, null_resettable) NSAttributedString *attributedText;

@property (nonatomic, copy, null_resettable) NSString *text;

@property (nonatomic, null_resettable) UIFont *font;

@property (nonatomic, null_resettable) UIColor *textColor;

@property (nonatomic) NSTextAlignment textAlignment;

/// The alignment of text paragraphs whose implicit or explicit `NSTextAlignment` is `.natural` or
/// `.justified`.
///
/// Default value: `.leading`
@property (nonatomic) STULabelDefaultTextAlignment defaultTextAlignment;

/// This value is used for interpreting the `defaultTextAlignment` modes `.leading` and `.trailing`.
/// It is also used as the `defaultBaseWritingDirection` when the `STULabelLayer` constructs a
/// `STUShapedString`.
///
/// The initial value of this property is `UIApplication.shared.userInterfaceLayoutDirection`.
///
/// If the `STULabelLayer` is owned by a `STULabel`, the label view automatically sets the layer's
/// `userInterfaceLayoutDirection` to the value of the view's
/// `effectiveUserInterfaceLayoutDirection` and updates the value when the view's
/// `semanticContentAttribute` or `traitCollection` change.
@property (nonatomic) UIUserInterfaceLayoutDirection userInterfaceLayoutDirection;

/// The `STUShapedString` instance used by the label for rendering purposes. This instance is
/// is lazily constructed from `self.attributedText`
/// (and the default base writing direction corresponding to `self.userInterfaceLayoutDirection`).
///
/// If the attributed text is null, the getter returns an empty shaped string.
@property (nonatomic, null_resettable) STUShapedString *shapedText;

/// Default value: .top
@property (nonatomic) STULabelVerticalAlignment verticalAlignment;

@property (nonatomic) UIEdgeInsets contentInsets;

@property (nonatomic) STUDirectionalEdgeInsets directionalContentInsets;

/// Default value: true
@property (nonatomic) bool clipsContentToBounds;

/// Sets `maxLineCount`, `lastLineTruncationMode`, `truncationToken`, `minTextScaleFactor`
/// `textScalingBaselineAdjustment` and `lastHyphenationLocationInRangeCallback`.
///
/// `options.defaultTextAlignment` is ignored.
- (void)setTextFrameOptions:(nullable STUTextFrameOptions *)options;

@property (nonatomic) STUTextLayoutMode textLayoutMode;

/// The maximum number of lines.
/// A value of 0 means that there is no maximum.
/// Default value: 1
@property (nonatomic) NSInteger maxLineCount;

/// Default value: `.end`
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
/// Default value: `nil`
@property (nonatomic, copy, nullable) NSAttributedString *truncationToken;

/// Default value: `nil`
@property (nonatomic, nullable) STUTruncationRangeAdjuster truncationRangeAdjuster;

/// Default value: 1
@property (nonatomic) CGFloat minTextScaleFactor;

/// Default value: `.none`
@property (nonatomic) STUBaselineAdjustment textScalingBaselineAdjustment;

/// Default value: `nil`
@property (nonatomic, nullable) STULastHyphenationLocationInRangeFinder
                                  lastHyphenationLocationInRangeFinder;

/// The actually displayed background color of the `STULabeLayer`.
@property (nonatomic, nullable) CGColorRef displayedBackgroundColor;

/// The `CALayer` background color, which may be null even though the background color of the
/// displayed content is `displayedBackgroundColor`.
///
/// The `STULabelLayer` will automatically set and clear this property to optimize rendering
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

/// An array with `STUTextLink` objects for every link contained in the label's truncated text.
@property (nonatomic, readonly, nonnull) STUTextLinkArray *links;

@property (nonatomic, readonly, nonnull) STUTextFrame *textFrame;

@property (nonatomic, readonly) CGPoint textFrameOrigin;

@property (copy, nonnull) NSString *contentsGravity
  STU_UNAVAILABLE("Use verticalAlignment and textAlignment or  NSParagraphStyle.textAlignment instead.");

@property BOOL drawsAsynchronously
  STU_UNAVAILABLE("Use displaysAsynchronously instead.");

@end

@protocol STULabelLayerDelegate <NSObject>
@optional

/// The proposed value is usually the current value of `labelLayer.displaysAsynchronously`,
/// but it may be `false` even when `labelLayer.displaysAsynchronously` is `true` if the
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

