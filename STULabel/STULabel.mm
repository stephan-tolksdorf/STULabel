// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel.h"
#import "STULabelSwiftExtensions.h"

#import "NSAttributedString+STUDynamicTypeFontScaling.h"
#import "UIFont+STUDynamicTypeFontScaling.h"

#import "STULabelLayoutInfo-Internal.hpp"

#import "Internal/LabelParameters.hpp"
#import "Internal/LabelRendering.hpp"
#import "Internal/Localized.hpp"
#import "Internal/Once.hpp"
#import "Internal/STULabelAddToContactsViewController.h"
#import "Internal/STULabelGhostingMaskLayer.h"
#import "Internal/STULabelLinkOverlayLayer.h"
#import "Internal/STULabelSubrangeView.h"

#import <ContactsUI/ContactsUI.h>
#import <SafariServices/SafariServices.h>

#import <objc/runtime.h>

using namespace stu;
using namespace stu_label;

// MARK: - STULabelEdgeAndBaselineLayoutGuide

@interface STULabelContentLayoutGuide : UILayoutGuide
@end
@implementation STULabelContentLayoutGuide {
  NSLayoutConstraint* _leftConstraint;
  NSLayoutConstraint* _rightConstraint;
  NSLayoutConstraint* _topConstraint;
  NSLayoutConstraint* _bottomConstraint;
  UIEdgeInsets _contentInsets;
}

static void STULabelContentLayoutGuideInit(STULabelContentLayoutGuide* self, STULabel* label) {
  [label addLayoutGuide:self];
  self->_leftConstraint   = [self.leftAnchor constraintEqualToAnchor:label.leftAnchor];
  self->_rightConstraint  = [self.rightAnchor constraintEqualToAnchor:label.rightAnchor];
  self->_topConstraint    = [self.topAnchor constraintEqualToAnchor:label.topAnchor];
  self->_bottomConstraint = [self.bottomAnchor constraintEqualToAnchor:label.bottomAnchor];
}

static void STULabelContentLayoutGuideUpdate(STULabelContentLayoutGuide* __unsafe_unretained self,
                                             const LabelParameters& params)
{
  const UIEdgeInsets& insets = params.edgeInsets();
  if (self->_contentInsets.left != insets.left) {
    self->_contentInsets.left = insets.left;
    self->_leftConstraint.constant = insets.left;
  }
  if (self->_contentInsets.right != insets.right) {
    self->_contentInsets.right = insets.right;
    self->_rightConstraint.constant = -insets.right;
  }
  if (self->_contentInsets.top != insets.top) {
    self->_contentInsets.top = insets.top;
    self->_topConstraint.constant = insets.top;
  }
  if (self->_contentInsets.bottom != insets.bottom) {
    self->_contentInsets.bottom = insets.bottom;
    self->_bottomConstraint.constant = -insets.bottom;
  }
}

@end

/// The topAnchor is positioned at the Y coordinate of the first baseline, and
/// the bottomAchor is positioned at the Y coordinate of the last baseline.
@interface STULabelBaselinesLayoutGuide : UILayoutGuide
@end
@implementation STULabelBaselinesLayoutGuide {
  NSLayoutConstraint* _firstBaselineConstraint;
  NSLayoutConstraint* _lastBaselineConstraint;
  CGFloat _firstBaseline;
  CGFloat _lastBaseline;
}

static void STULabelBaselinesLayoutGuideInit(STULabelBaselinesLayoutGuide* self, STULabel* label) {
  [label addLayoutGuide:self];
  self->_firstBaselineConstraint = [self.topAnchor constraintEqualToAnchor:label.topAnchor];
  self->_lastBaselineConstraint  = [self.bottomAnchor constraintEqualToAnchor:label.topAnchor];
}

static void STULabelBaselinesLayoutGuideUpdate(STULabelBaselinesLayoutGuide* __unsafe_unretained self,
                                               const LabelTextFrameInfo& info)
{
  if (self->_firstBaseline != info.firstBaseline) {
    self->_firstBaseline = info.firstBaseline;
    self->_firstBaselineConstraint.constant = info.firstBaseline;
  }
  if (self->_lastBaseline != info.lastBaseline) {
    self->_lastBaseline = info.lastBaseline;
    self->_lastBaselineConstraint.constant = info.lastBaseline;
  }
}

@end

// MARK: - STULabel

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(tvos)
@interface STULabelDragInteraction : UIDragInteraction {
@package
  STULabel* __unsafe_unretained stu_label; // This field is set and cleared by the owning label.
}
@end

static void updateLabelLinkObserversAfterLayoutChange(STULabel* label);
static void updateLabelLinkObserversInLabelDealloc(STULabel* label);

static void addLabelLinkPopoverObserver(STULabel* label, STUTextLink* link, UIViewController* vc);

@implementation STULabel  {
  // The layer is owned by the view and stays constant, so we can safely cache a reference.
  __unsafe_unretained STULabelLayer* _layer;
  CGRect _contentBounds;
  CGSize _maxWidthIntrinsicContentSize;
  CGSize _intrinsicContentSizeKnownToAutoLayout;
  CGFloat _layoutWidthForIntrinsicContentSizeKnownToAutoLayout;
  struct STULabelBitField {
    UInt8 oldTintAdjustmentMode : 2;
    bool isSettingBounds : 1;
    bool isUpdatingConstraints : 1;
    bool intrinsicContentSizeIsKnownToAutoLayout : 1;
    bool waitingForPossibleSetBoundsCall : 1;
    bool didSetNeedsLayoutOnSuperview : 1;
    bool hasMaxWidthIntrinsicContentSize : 1;
    bool adjustsFontForContentSizeCategory : 1;
    bool usesTintColorAsLinkColor : 1;
    bool hasActiveLinkOverlayLayer : 1;
    bool activeLinkOverlayIsHidden : 1;
    bool isEnabled : 1;
    bool accessibilityElementRepresentsUntruncatedText : 1;
    bool accessibilityElementSeparatesLinkElements : 1;
    bool delegateRespondsToOverlayStyleForActiveLink : 1;
    bool delegateRespondsToLinkWasTapped : 1;
    bool delegateRespondsToLinkCanBeLongPressed : 1;
    bool delegateRespondsToLinkWasLongPressed : 1;
    bool delegateRespondsToShouldDisplayAsynchronously : 1;
    bool delegateRespondsToDidDisplayText : 1;
    bool delegateRespondsDidMoveDisplayedText : 1;
    bool delegateRespondsToTextLayoutWasInvalidated : 1;
    bool delegateRespondsToLinkCanBeDragged : 1;
    bool delegateRespondsToDragItemForLink : 1;
    bool dragInteractionEnabled : 1;
  } _bits;
  STUTextFrameFlags _textFrameFlags;
  CGFloat _linkTouchAreaExtensionRadius;
  size_t _touchCount;
  size_t _accessibilityElementParagraphSeparationCharacterThreshold;

@package // fileprivate
  STULabelLinkObserver* __unsafe_unretained _lastLinkObserver;
@private
  __weak id<STULabelDelegate> _delegate;
  UIColor* _disabledTextColor;
  UIColor* _disabledLinkColor;
  STULabelBaselinesLayoutGuide* _baselinesLayoutGuide;
  STULabelContentLayoutGuide* _contentLayoutGuide;
  UIContentSizeCategory _contentSizeCategory;
  UITouch* _currentTouch;
  UILongPressGestureRecognizer* _longPressGestureRecognizer;
  STULabelOverlayStyle* _activeLinkOverlayStyle;
  /// A STULabelLinkOverlayLayer if _bits.hasActiveLinkOverlayLayer, else a STUTextLink, or null.
  id _activeLinkOrOverlayLayer;
  CGPoint _activeLinkContentOrigin;
  STULabelDragInteraction* _dragInteraction API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos);
  STULabelGhostingMaskLayer* _ghostingMaskLayer;
  STUTextFrameAccessibilityElement* _textFrameAccessibilityElement;
}

+ (Class)layerClass {
  return STULabelLayer.class;
}

@dynamic layer;

// Dummy method whose presence signals to UIKit that this view uses custom drawing. This ensures
// that the contentScaleFactor (== layer.contentsScale) gets properly updated.
- (void)drawRect:(CGRect __unused)rect {}

// We override layerWillDraw with an empty method in order to prevent the default implementation
// from setting the contentsFormat of the layer.
- (void)layerWillDraw:(CALayer* __unused)layer {}

static void initCommon(STULabel* self) {
  static Class stuLabelLayerClass;
  static UIColor* disabledTextColor;
  static STULabelOverlayStyle* defaultLabelOverlayStyle;
  static bool dragInteractionIsEnabledByDefault;
  static dispatch_once_t once;
  dispatch_once_f(&once, nullptr, [](void *) {
    stuLabelLayerClass = STULabelLayer.class;
    disabledTextColor = [[UIColor alloc] initWithWhite:CGFloat(0.56) alpha:1];
    defaultLabelOverlayStyle = STULabelOverlayStyle.defaultStyle;
    if (@available(iOS 11, *)) {
      dragInteractionIsEnabledByDefault = [UIDragInteraction isEnabledByDefault];
    }
  });

  self->_bits.isEnabled = true;
  self->_bits.usesTintColorAsLinkColor = true;
  self->_bits.dragInteractionEnabled = dragInteractionIsEnabledByDefault;
  self->_linkTouchAreaExtensionRadius = 10;
  self->_accessibilityElementParagraphSeparationCharacterThreshold = 280;
  self->_disabledTextColor = disabledTextColor;
  self->_activeLinkOverlayStyle = defaultLabelOverlayStyle;

  self->_layer = static_cast<STULabelLayer*>([self layer]);
  STU_CHECK([self->_layer isKindOfClass:stuLabelLayerClass]);
  self->_layer.labelLayerDelegate = self;
  self->_layer.overrideLinkColor = self.tintColor;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    initCommon(self);
  }
  return self;
}

- (nullable instancetype)initWithCoder:(NSCoder*)decoder {
  if ((self = [super initWithCoder:decoder])) {
    initCommon(self);
  }
  return self;
}

- (void)dealloc {
  if (_dragInteraction) {
    _dragInteraction->stu_label = nil;
  }
  if (!_lastLinkObserver) return;
  updateLabelLinkObserversInLabelDealloc(self);
}

- (void)setDelegate:(nullable id<STULabelDelegate>)delegate {
  _delegate = delegate;

  if (!delegate) {
    _bits.delegateRespondsToOverlayStyleForActiveLink = false;
    _bits.delegateRespondsToLinkWasTapped = false;
    _bits.delegateRespondsToLinkCanBeLongPressed = false;
    _bits.delegateRespondsToLinkWasLongPressed = false;
    _bits.delegateRespondsToShouldDisplayAsynchronously = false;
    _bits.delegateRespondsToDidDisplayText = false;
    _bits.delegateRespondsDidMoveDisplayedText = false;
    _bits.delegateRespondsToTextLayoutWasInvalidated = false;
    _bits.delegateRespondsToLinkCanBeDragged = false;
    _bits.delegateRespondsToDragItemForLink = false;
  } else {
    _bits.delegateRespondsToOverlayStyleForActiveLink =
      [delegate respondsToSelector:@selector(label:overlayStyleForActiveLink:withDefault:)];
    _bits.delegateRespondsToLinkWasTapped =
      [delegate respondsToSelector:@selector(label:link:wasTappedAtPoint:)];
    _bits.delegateRespondsToLinkCanBeLongPressed =
      [delegate respondsToSelector:@selector(label:link:canBeLongPressedAtPoint:)];
    _bits.delegateRespondsToLinkWasLongPressed =
      [delegate respondsToSelector:@selector(label:link:wasLongPressedAtPoint:)];
    _bits.delegateRespondsToShouldDisplayAsynchronously =
      [delegate respondsToSelector:@selector(label:shouldDisplayAsynchronouslyWithProposedValue:)];
    _bits.delegateRespondsToDidDisplayText =
      [delegate respondsToSelector:@selector(label:didDisplayTextWithFlags:inRect:)];
    _bits.delegateRespondsDidMoveDisplayedText =
      [delegate respondsToSelector:@selector(label:didMoveDisplayedTextToRect:)];
    _bits.delegateRespondsToTextLayoutWasInvalidated =
      [delegate respondsToSelector:@selector(labelTextLayoutWasInvalidated:)];
    _bits.delegateRespondsToLinkCanBeDragged =
      [delegate respondsToSelector:@selector(label:link:canBeDraggedFromPoint:)];
    _bits.delegateRespondsToDragItemForLink =
      [delegate respondsToSelector:@selector(label:dragItemForLink:)];
  }
}

// MARK: - Layout related

- (void)setBounds:(CGRect)bounds {
  const bool isRecursiveCall = _bits.isSettingBounds;
  _bits.isSettingBounds = true;
  _bits.waitingForPossibleSetBoundsCall = false;
  [super setBounds:bounds];
  _bits.isSettingBounds = isRecursiveCall;
}

static void updateLayoutGuides(STULabel* __unsafe_unretained self) {
  if (self->_contentLayoutGuide) {
    STULabelContentLayoutGuideUpdate(self->_contentLayoutGuide,
                                     STULabelLayerGetParams(self->_layer));
  }
  if (self->_baselinesLayoutGuide) {
    STULabelBaselinesLayoutGuideUpdate(self->_baselinesLayoutGuide,
                                       STULabelLayerGetCurrentTextFrameInfo(self->_layer));
  }
}

- (void)updateConstraints {
  const bool isRecursiveCall = _bits.isUpdatingConstraints;
  _bits.isUpdatingConstraints = true;
  [super updateConstraints];
  updateLayoutGuides(self);
  _bits.isUpdatingConstraints = isRecursiveCall;
}

- (CGSize)intrinsicContentSize {
  CGFloat layoutWidth = STULabelLayerGetSize(_layer).width;
  if (!_bits.hasMaxWidthIntrinsicContentSize) {
    // We can't use an arbitrarily large width here, because paragraphs may be right-aligned and
    // the spacing between floating-point numbers increases with their magnitude.
    _maxWidthIntrinsicContentSize = [_layer sizeThatFits:CGSize{max(CGFloat(1 << 14), layoutWidth),
                                                                maxValue<CGFloat>}];
    _bits.hasMaxWidthIntrinsicContentSize = true;
  }
  CGSize size;
  if (_layer.maximumLineCount == 1
      || layoutWidth <= 0 // This is an optimization for newly created label views.
      || layoutWidth >= _maxWidthIntrinsicContentSize.width)
  {
    // If maximumLineCount == 1 and layoutWidth < _maxWidthIntrinsicContentSize.width, the text
    // truncation could increase the typographic height if the truncation token has a line height
    // larger than the main text, but supporting such odd formatting doesn't seem worth the slow
    // down of intrinsicContentSize for single line labels.
    // Similarly, if the final layout width actually is 0 and the label is not empty, the intrinsic
    // size calculated here likely isn't high enough, but in that case the layout is broken anyway.
    layoutWidth = _maxWidthIntrinsicContentSize.width;
    size = _maxWidthIntrinsicContentSize;
  } else {
    size.height = [_layer sizeThatFits:CGSize{layoutWidth, maxValue<CGFloat>}].height;
    size.width = _maxWidthIntrinsicContentSize.width;
  }
  if (_bits.isUpdatingConstraints) {
    _bits.intrinsicContentSizeIsKnownToAutoLayout = true;
    _layoutWidthForIntrinsicContentSizeKnownToAutoLayout = layoutWidth;
    if (size == _intrinsicContentSizeKnownToAutoLayout) {
      _bits.waitingForPossibleSetBoundsCall = false;
    } else {
      _intrinsicContentSizeKnownToAutoLayout = size;
    }
  }
  return size;
}

- (void)layoutSubviews {
  updateLayoutGuides(self);
  [super layoutSubviews];
  // UIKit sometimes doesn't properly update the layout after a call to
  // invalidateIntrinsicContentSize. Sometimes it just forgets to query the updated intrinsic
  // content size (rdar://34422006) and sometimes it simply doesn't update the layout after changes
  // in the constraints. To workaround these issue we track Auto-Layout-initiated intrinsic content
  // size invalidations and the subsequent setBounds calls. Any setBounds call should have happened
  // by now, so if none has, we request a relayout of the superview, which seems to reliably flush
  // any pending layout updates.
  if (_bits.waitingForPossibleSetBoundsCall && !_bits.didSetNeedsLayoutOnSuperview) {
    _bits.didSetNeedsLayoutOnSuperview = true;
    [self.superview setNeedsLayout];
  } else {
    _bits.didSetNeedsLayoutOnSuperview = false;
  }
  _bits.waitingForPossibleSetBoundsCall = false;
}

- (void)labelLayerTextLayoutWasInvalidated:(STULabelLayer* __unused)labelLayer {
  _textFrameAccessibilityElement = nil;
  if (!_bits.isSettingBounds) {
    _bits.hasMaxWidthIntrinsicContentSize = false;
  }
  if (_bits.intrinsicContentSizeIsKnownToAutoLayout
      && (!_bits.isSettingBounds
          || STULabelLayerGetSize(_layer).width
             != _layoutWidthForIntrinsicContentSizeKnownToAutoLayout))
  {
    _bits.intrinsicContentSizeIsKnownToAutoLayout = false;
    _bits.waitingForPossibleSetBoundsCall = true; // See the comment in layoutSubviews.
    [self invalidateIntrinsicContentSize];
  }
  if (_bits.delegateRespondsToTextLayoutWasInvalidated) {
    [_delegate labelTextLayoutWasInvalidated:self];
  }
}

- (UILayoutGuide*)contentLayoutGuide {
  if (!_contentLayoutGuide) {
    _contentLayoutGuide = [[STULabelContentLayoutGuide alloc] init];
    STULabelContentLayoutGuideInit(_contentLayoutGuide, self);
    [self setNeedsUpdateConstraints];
  }
  return _contentLayoutGuide;
}

static STULabelBaselinesLayoutGuide* baselinesLayoutGuide(STULabel* __unsafe_unretained self) {
  if (!self->_baselinesLayoutGuide) {
    self->_baselinesLayoutGuide = [[STULabelBaselinesLayoutGuide alloc] init];
    STULabelBaselinesLayoutGuideInit(self->_baselinesLayoutGuide, self);
    [self setNeedsUpdateConstraints];
  }
  return self->_baselinesLayoutGuide;
}

- (NSLayoutYAxisAnchor*)firstBaselineAnchor {
  return baselinesLayoutGuide(self).topAnchor;
}

- (NSLayoutYAxisAnchor*)lastBaselineAnchor {
  return baselinesLayoutGuide(self).bottomAnchor;
}


- (bool)accessibilityElementRepresentsUntruncatedText {
  return _bits.accessibilityElementRepresentsUntruncatedText;
}
- (void)setAccessibilityElementRepresentsUntruncatedText:(bool)value {
  if (_bits.accessibilityElementRepresentsUntruncatedText == value) return;
  _bits.accessibilityElementRepresentsUntruncatedText = value;
  _textFrameAccessibilityElement = nil;
}

- (size_t)accessibilityElementParagraphSeparationCharacterThreshold {
  return _accessibilityElementParagraphSeparationCharacterThreshold;
}
- (void)setAccessibilityElementParagraphSeparationCharacterThreshold:(size_t)value {
  if (_accessibilityElementParagraphSeparationCharacterThreshold == value) return;
  _accessibilityElementParagraphSeparationCharacterThreshold = value;
  _textFrameAccessibilityElement = nil;
}

- (bool)accessibilityElementSeparatesLinkElements {
  return _bits.accessibilityElementSeparatesLinkElements;
}
- (void)setAccessibilityElementSeparatesLinkElements:(bool)value {
  if (_bits.accessibilityElementSeparatesLinkElements == value) return;
  _bits.accessibilityElementSeparatesLinkElements = value;
  _textFrameAccessibilityElement = nil;
}

- (STUTextFrameAccessibilityElement*)accessibilityElement {
  if (!_textFrameAccessibilityElement) {
    STUTextFrame* const textFrame = _layer.textFrame;
    bool separateParagraphs = true;
    if (_accessibilityElementParagraphSeparationCharacterThreshold > 1) {
      if (_accessibilityElementParagraphSeparationCharacterThreshold >= maxValue<Int32>) {
        separateParagraphs = false;
      } else {
        NSString* const string = _bits.accessibilityElementRepresentsUntruncatedText
                               ? textFrame.originalAttributedString.string
                               : textFrame.truncatedAttributedString.string;
        const Int n = NSStringRef{string}.countGraphemeClusters();
        separateParagraphs = sign_cast(n)
                             > _accessibilityElementParagraphSeparationCharacterThreshold;
      }
    }
    const id<STULabelDelegate> delegate = _delegate;
    STUTextLinkArray* const links = _bits.delegateRespondsToLinkCanBeDragged
                                 || _bits.delegateRespondsToDragItemForLink
                                  ? _layer.links : nil;
    _textFrameAccessibilityElement =
      [[STUTextFrameAccessibilityElement alloc]
         initWithAccessibilityContainer:self
                              textFrame:textFrame
                 originInContainerSpace:_layer.textFrameOrigin
                           displayScale:_layer.contentsScale
               representUntruncatedText:_bits.accessibilityElementRepresentsUntruncatedText
                     separateParagraphs:separateParagraphs
                   separateLinkElements:_bits.accessibilityElementSeparatesLinkElements
                        isDraggableLink:^bool(STUTextRange range __unused, id linkValue,
                                              CGPoint point)
                        {
                          if (!links) {
                            return isDefaultDraggableLinkValue(linkValue);
                          }
                          if (STUTextLink* const link = [links linkClosestToPoint:point
                                                                      maxDistance:0])
                          {
                            STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
                            if (_bits.delegateRespondsToLinkCanBeDragged) {
                              return [delegate label:self link:link canBeDraggedFromPoint:point];
                            } else {
                              return [delegate label:self dragItemForLink:link] != nil;
                            }
                            STU_REENABLE_CLANG_WARNING
                          }
                          return false;
                        }];
  }
  return _textFrameAccessibilityElement;
}

- (NSArray*)accessibilityElements {
  return @[self.accessibilityElement];
}

// MARK: - Determining the base writing direction from the UI layout direction

API_AVAILABLE(ios(10.0), tvos(10))
STU_INLINE UIContentSizeCategory preferredContentSizeCategory(UIView* self) {
  UIContentSizeCategory category = self.traitCollection.preferredContentSizeCategory;
  if (![category isEqualToString:UIContentSizeCategoryUnspecified]) {
    return category;
  }
  return UIApplication.sharedApplication.preferredContentSizeCategory;
}

- (BOOL)adjustsFontForContentSizeCategory {
  return _bits.adjustsFontForContentSizeCategory;
}
- (void)setAdjustsFontForContentSizeCategory:(BOOL)value {
  if (_bits.adjustsFontForContentSizeCategory == value) return;
  _bits.adjustsFontForContentSizeCategory = value;
  if (@available(iOS 10, tvOS 10, *)) {
    if (value) {
      _contentSizeCategory = preferredContentSizeCategory(self);
    } else {
      _contentSizeCategory = nil;
    }
  }
}

static UIUserInterfaceLayoutDirection effectiveUILayoutDirection(UIView* __nonnull view) {
  const UISemanticContentAttribute contentAttribute = view.semanticContentAttribute;
  switch (contentAttribute) {
  case UISemanticContentAttributeForceLeftToRight: return UIUserInterfaceLayoutDirectionLeftToRight;
  case UISemanticContentAttributeForceRightToLeft: return UIUserInterfaceLayoutDirectionRightToLeft;
  default: break;
  }
  if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max) {
  STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
    return view.effectiveUserInterfaceLayoutDirection;
  STU_REENABLE_CLANG_WARNING
  } else {
    return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:contentAttribute];
  }
}

static_assert((int)UIUserInterfaceLayoutDirectionLeftToRight == (int)STUWritingDirectionLeftToRight);
static_assert((int)UIUserInterfaceLayoutDirectionRightToLeft == (int)STUWritingDirectionRightToLeft);

- (void)setSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute {
  [super setSemanticContentAttribute:semanticContentAttribute];
  _layer.userInterfaceLayoutDirection = effectiveUILayoutDirection(self);
}

- (void)traitCollectionDidChange:(UITraitCollection*)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  _layer.userInterfaceLayoutDirection = effectiveUILayoutDirection(self);
  if (!_bits.adjustsFontForContentSizeCategory) return;
  if (@available(iOS 10, tvOS 10, *)) {
    const UIContentSizeCategory newCategory = preferredContentSizeCategory(self);
    if (![newCategory isEqualToString:_contentSizeCategory]) {
      _contentSizeCategory = newCategory;
      if (STULabelLayerIsAttributed(_layer)) {
        if (NSAttributedString* const text = _layer.attributedText) {
          auto* const newText = [text stu_copyWithFontsAdjustedForContentSizeCategory:newCategory];
          if (text != newText) {
            _layer.attributedText = newText;
          }
        }
      } else {
        UIFont* const font = _layer.font;
        UIFont* const newFont = [font stu_fontAdjustedForContentSizeCategory:newCategory];
        if (newFont != font) {
          _layer.font = newFont;
        }
      }
    }
  }
}

// MARK: - Tint and disabled colors

- (bool)usesTintColorAsLinkColor {
  return _bits.usesTintColorAsLinkColor;
}
- (void)setUsesTintColorAsLinkColor:(bool)usesTintColorAsLinkColor {
  if (_bits.usesTintColorAsLinkColor == usesTintColorAsLinkColor) return;
  _bits.usesTintColorAsLinkColor = usesTintColorAsLinkColor;
  if (_bits.isEnabled || !_disabledLinkColor) {
    _layer.overrideLinkColor = usesTintColorAsLinkColor ? self.tintColor : nil;
  }
}

static void tintColorMayHaveChanged(STULabel* __unsafe_unretained self) {
  if (self->_bits.usesTintColorAsLinkColor
      && (self->_bits.isEnabled || !self->_disabledLinkColor))
  {
    self->_layer.overrideLinkColor = self.tintColor;
  }
}

- (void)tintColorDidChange {
  tintColorMayHaveChanged(self);
}

- (void)didMoveToSuperview {
  // In contrast to the trait collection handling, UIKit doesn't call tintColorDidChange when
  // the inherited tint color changes due to a move to a (different) superview.
  if (self.superview) {
    tintColorMayHaveChanged(self);
  }
}

- (void)didMoveToWindow {
  UIWindow* const window = self.window;
  tintColorMayHaveChanged(self);
  [_layer stu_didMoveToWindow:window];
}

- (void)setTintAdjustmentMode:(UIViewTintAdjustmentMode)tintAdjustmentMode {
  _bits.oldTintAdjustmentMode = static_cast<UInt8>(tintAdjustmentMode);
  [super setTintAdjustmentMode:tintAdjustmentMode];
}

- (BOOL)isEnabled {
  return _bits.isEnabled;
}
- (void)setEnabled:(BOOL)enabled {
  enabled = !!enabled;
  if (_bits.isEnabled == enabled) return;
  _bits.isEnabled = enabled;
  if (UIViewTintAdjustmentMode{_bits.oldTintAdjustmentMode} == UIViewTintAdjustmentModeAutomatic) {
    if (enabled) {
      self.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
    } else {
      self.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
      _bits.oldTintAdjustmentMode = static_cast<UInt8>(UIViewTintAdjustmentModeAutomatic);
    }
  }
  if (_disabledTextColor) {
    _layer.overrideTextColor = !enabled ? _disabledTextColor : nil;
  }
  if (_disabledLinkColor) {
    _layer.overrideLinkColor = !enabled ? _disabledLinkColor
                             : _bits.usesTintColorAsLinkColor ? self.tintColor : nil;
  }
}

// MARK: - Active link overlay

STU_INLINE STULabelLinkOverlayLayer* __nullable activeLinkOverlayLayer(STULabel* self) {
  return !self->_bits.hasActiveLinkOverlayLayer ? nil
       : (STULabelLinkOverlayLayer*)self->_activeLinkOrOverlayLayer;
}

STU_INLINE STUTextLink* __nullable activeLink(STULabel* self) {
  return self->_bits.hasActiveLinkOverlayLayer
       ? ((STULabelLinkOverlayLayer*)self->_activeLinkOrOverlayLayer).link
       : self->_activeLinkOrOverlayLayer;
}

- (nullable STUTextLink*)activeLink {
  if (!_activeLinkOrOverlayLayer || _bits.activeLinkOverlayIsHidden) return nil;
  STUTextLink* const link = activeLink(self);
  return _activeLinkContentOrigin == _contentBounds.origin ? link
       : [_layer.links linkMatchingLink:link];
}


static void addActiveLinkOverlay(STULabel* self, STULabelOverlayStyle* style,
                                 STUTextLink* link, bool hidden)
{
  STU_DEBUG_ASSERT(self->_activeLinkContentOrigin == self->_contentBounds.origin);
  STULabelLinkOverlayLayer *overlay;
  if (!self->_bits.hasActiveLinkOverlayLayer) {
    overlay = [[STULabelLinkOverlayLayer alloc] initWithStyle:style link:link];
    self->_activeLinkOrOverlayLayer = overlay;
    self->_bits.hasActiveLinkOverlayLayer = true;
    [self->_layer addSublayer:overlay];
    self->_bits.activeLinkOverlayIsHidden = overlay.hidden;
  } else {
    overlay = self->_activeLinkOrOverlayLayer;
    overlay.position = CGPointZero;
    overlay.overlayStyle = style;
    overlay.link = link;
  }
  if (self->_bits.activeLinkOverlayIsHidden != hidden) {
    self->_bits.activeLinkOverlayIsHidden = hidden;
    overlay.hidden = hidden;
  }
}

static void removeActiveLinkOverlay(STULabel* self, bool keepActiveLink) {
  if (!self->_bits.hasActiveLinkOverlayLayer) return;
  self->_bits.activeLinkOverlayIsHidden = true;
  STULabel* __weak weakSelf = self;
  [activeLinkOverlayLayer(self) setHidden:true
                  withAnimationCompletion:^(STULabelLinkOverlayLayer* overlay)
  {
    [overlay removeFromSuperlayer];
    STULabel* const label = weakSelf;
    if (!label || label->_activeLinkOrOverlayLayer != overlay) return;
    label->_activeLinkOrOverlayLayer = keepActiveLink ? overlay.link : nil;
    label->_bits.hasActiveLinkOverlayLayer = false;
    label->_bits.activeLinkOverlayIsHidden = false;
  }];
}

static void updateActiveLinkOverlayIsHidden(STULabel* self) {
  if (!self->_currentTouch) return;
  const CGPoint point = [self->_currentTouch locationInView:self]
                      + (self->_activeLinkContentOrigin - self->_contentBounds.origin);
  STUTextLink* const link = activeLink(self);
  const STUIndexAndDistance iad = [link findRectClosestToPoint:point maxDistance:CGFLOAT_MAX];
  bool outOfArea = iad.distance > self->_linkTouchAreaExtensionRadius;
  if (outOfArea && self->_bits.hasActiveLinkOverlayLayer) {
    const UIEdgeInsets e = activeLinkOverlayLayer(self).overlayStyle.edgeInsets;
    stu_label::Rect rect = [link rectAtIndex:iad.index];
    rect.x.start += min(e.left, 0.f);
    rect.x.end   -= min(e.right, 0.f);
    rect.y.start += min(e.top, 0.f);
    rect.y.end   -= min(e.bottom, 0.f);
    outOfArea = rect.distanceTo(point) > self->_linkTouchAreaExtensionRadius;
  }
  if (outOfArea == self->_bits.activeLinkOverlayIsHidden) return;
  self->_bits.activeLinkOverlayIsHidden = outOfArea;
  if (self->_bits.hasActiveLinkOverlayLayer) {
    activeLinkOverlayLayer(self).hidden = outOfArea;
  }
}

static void clearCurrentLabelTouch(STULabel* self) {
  self->_currentTouch = nil;
  removeActiveLinkOverlay(self, false);
}

- (void)setActiveLinkOverlayStyle:(nullable STULabelOverlayStyle*)style {
  if (style == _activeLinkOverlayStyle) return;
  STULabelOverlayStyle* const oldStyle = _activeLinkOverlayStyle;
  _activeLinkOverlayStyle = style;
  if (_bits.hasActiveLinkOverlayLayer) {
    STULabelLinkOverlayLayer* const overlay = _activeLinkOrOverlayLayer;
    if (style) {
      // We don't overwrite the style if it was chosen by the delegate.
      if (overlay.overlayStyle != oldStyle) return;
      overlay.overlayStyle = style;
    } else {
      removeActiveLinkOverlay(self, true);
    }
  }
  if (!style || !_activeLinkOrOverlayLayer) return;
  STUTextLink* link = _activeLinkOrOverlayLayer;
  if (_activeLinkContentOrigin != _contentBounds.origin) {
    _activeLinkContentOrigin = _contentBounds.origin;
    link = [_layer.links linkMatchingLink:link];
    STU_ASSERT(link != nil);
  }
  addActiveLinkOverlay(self, style, activeLink(self), _bits.activeLinkOverlayIsHidden);
  updateActiveLinkOverlayIsHidden(self);
}

- (void)setLinkTouchAreaExtensionRadius:(CGFloat)radius {
  _linkTouchAreaExtensionRadius = clampFloatInput(radius);
  updateActiveLinkOverlayIsHidden(self);
}

// MARK: - Default link action sheet

static void openURL(NSURL* url) {
  if (@available(iOS 10, *)) {
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
       if (!success) {
       #if STU_DEBUG
         NSLog(@"Failed to open URL %@", url);
       #else
         NSLog(@"Failed to open URL");
       #endif
       }
     }];
  } else {
    [UIApplication.sharedApplication openURL:url];
  }
}

static UIAlertAction* openURLAction(NSString* title, NSURL* url) {
  return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction* action __unused) { openURL(url); }];
}

static UIAlertAction* copyAction(NSString* title, NSString* string) {
  return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction* action __unused) {
           UIPasteboard.generalPasteboard.string = string;
         }];
}

static UIAlertAction* shareAction(NSString* title, NSURL* url,
                                  UIViewController* __weak weakPresentingViewController,
                                  STULabel* __weak weakLabel, STUTextLink* weakLink)
{
  return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction* action __unused) {
           UIViewController* const presentingViewController = weakPresentingViewController;
           STULabel* const label = weakLabel;
           STUTextLink* const link = [label.links linkMatchingLink:weakLink];
           if (!presentingViewController || !label || !link) return;
           UIActivityViewController* const ac = [[UIActivityViewController alloc]
                                                   initWithActivityItems:@[url]
                                                   applicationActivities:nil];
           addLabelLinkPopoverObserver(label, link, ac);
           [presentingViewController presentViewController:ac animated:true completion:nil];
         }];
}

static UIAlertAction* addToContactsAction(NSString* title, CNContact* contact,
                                          UIViewController* __weak weakPresentingViewController,
                                          STULabel* __weak weakLabel, STUTextLink* weakLink)
{
  return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction* action __unused) {
           UIViewController* const presentingViewController = weakPresentingViewController;
           STULabel* const label = weakLabel;
           STUTextLink* const link = [label.links linkMatchingLink:weakLink];
           if (!presentingViewController || !label || !link) return;
           UIViewController* const vc = [[STULabelAddToContactsViewController alloc]
                                           initWithContact:contact];
           vc.modalPresentationStyle = UIModalPresentationPopover;
           addLabelLinkPopoverObserver(label, link, vc);
           [presentingViewController presentViewController:vc animated:true completion:nil];
         }];
}

static UIAlertAction* addToReadingListAction(NSString* title, NSURL* url) {
  return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction* action __unused) {
           NSError* error;
           if (![SSReadingList.defaultReadingList addReadingListItemWithURL:url title:nil
                                                                previewText:nil error:&error])
           {
           #if STU_DEBUG
             NSLog(@"Failed to add url %@ to reading list: %@", url, error.description);
           #else
             NSLog(@"Failed to add url to reading list: %@", error.description);
           #endif
           }
         }];
}

static NSString* urlStringWithoutScheme(NSURL* __unsafe_unretained url) {
  NSString* const scheme = url.scheme;
  NSString* const string = url.absoluteString;
  return [string hasPrefix:scheme]
      && string.length > scheme.length && [string characterAtIndex:scheme.length] == ':'
       ? [string substringFromIndex:scheme.length + 1]
       : string;
}

static bool isDefaultDraggableLinkValue(id __unsafe_unretained linkValue) {
  return [linkValue isKindOfClass:NSURL.class]
      || ([linkValue isKindOfClass:NSString.class] && [NSURL URLWithString:linkValue] != nil)
      || [linkValue isKindOfClass:UIImage.class];
}


static NSURL* __nullable urlLinkAttribute(STUTextLink* __unsafe_unretained link) {
  const id attribute = link.linkAttribute;
  if ([attribute isKindOfClass:NSURL.class]) {
    return attribute;
  }
  if ([attribute isKindOfClass:NSString.class]) {
    return [NSURL URLWithString:attribute];
  }
  return nil;
}

- (nullable NSString*)stu_actionSheetMessageForLink:(STUTextLink*)link {
  NSURL* const url = urlLinkAttribute(link);
  if (!url) return nil;
  NSString* const scheme = [url.scheme lowercaseString];
  if (   [scheme isEqualToString:@"mailto"]
      || [scheme isEqualToString:@"tel"] || [scheme isEqualToString:@"telprompt"])
  {
    return urlStringWithoutScheme(url);
  } else {
    return url.absoluteString;
  }
}

- (nullable NSArray<UIAlertAction*>*)
    stu_alertActionsForLink:(STUTextLink*)link
   presentingViewController:(UIViewController*)presentingViewController
{
  NSURL* const url = urlLinkAttribute(link);
  if (!url) return nil;
  NSString* const scheme = [url.scheme lowercaseString];
  if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) {
    if (url.host.length == 0) return nil;
    return @[openURLAction(localized(@"Open"), url),
             addToReadingListAction(localized(@"Add to Reading List"), url),
             copyAction(localized(@"Copy"), url.absoluteString),
             shareAction(localized(@"Share…"), url, presentingViewController, self, link)];
  }
  NSString* const target = urlStringWithoutScheme(url);
  const NSUInteger q = [target rangeOfString:@"?"].location;
  NSString* const targetWithoutQuery = q == NSNotFound ? target : [target substringToIndex:q];
  if ([scheme isEqualToString:@"mailto"]) {
    if (targetWithoutQuery.length == 0) return nil;
    CNMutableContact* const contact = [[CNMutableContact alloc] init];
    contact.emailAddresses = @[[CNLabeledValue labeledValueWithLabel:nil
                                                               value:targetWithoutQuery]];
    return @[openURLAction(localized(@"New Mail Message"), url),
             copyAction(localized(@"Copy Email"), targetWithoutQuery),
             addToContactsAction(localized(@"Add to Contacts"), contact, presentingViewController,
                                 self, link)];
  } else if ([scheme isEqualToString:@"tel"] || [scheme isEqualToString:@"telprompt"]) {
    if (targetWithoutQuery.length == 0) return nil;
    CNPhoneNumber* const number = [CNPhoneNumber phoneNumberWithStringValue:targetWithoutQuery];
    if (!number) return nil;
    CNMutableContact* const contact = [[CNMutableContact alloc] init];
    contact.phoneNumbers = @[[CNLabeledValue labeledValueWithLabel:nil value:number]];
    NSMutableArray* const array = [[NSMutableArray alloc] initWithCapacity:3];
    if ([UIApplication.sharedApplication canOpenURL:url]) {
      [array addObject:openURLAction([NSString stringWithFormat:localized(@"Call %@"), target],
                                     url)];
    }
    [array addObject:copyAction(localized(@"Copy Phone Number"), target)];
    [array addObject:addToContactsAction(localized(@"Add to Contacts"), contact,
                                         presentingViewController, self, link)];
    return array;
  }
  return @[openURLAction(localized(@"Open"), url),
           copyAction(localized(@"Copy"), url.absoluteString),
           shareAction(localized(@"Share…"), url, presentingViewController, self, link)];
}

- (bool)stu_presentActionSheetForLink:(STUTextLink*)link
                   fromViewController:(UIViewController*)presentingViewController
{
  if (!presentingViewController) return false;
  NSArray<UIAlertAction*>* const actions = [self stu_alertActionsForLink:link
                                                presentingViewController:presentingViewController];
  if (!actions) return false;
  NSString* const message = [self stu_actionSheetMessageForLink:link];
  if (!message) return false;
  UIAlertController* const ac = [UIAlertController
                                  alertControllerWithTitle:nil
                                                   message:message
                                            preferredStyle:UIAlertControllerStyleActionSheet];
  for (UIAlertAction* const action in actions) {
    [ac addAction:action];
  }
  [ac addAction:[UIAlertAction actionWithTitle:localized(@"Cancel") style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction* action __unused) {}]];
  addLabelLinkPopoverObserver(self, link, ac);
  [presentingViewController presentViewController:ac animated:true completion:nil];
  return true;
}

// MARK: - Touch event handling

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  _touchCount += touches.count;
  [super touchesBegan:touches withEvent:event];
  if (!_bits.isEnabled) return;
  if (_ghostingMaskLayer) return;
  if (_currentTouch) return; // Could happen if self.isMultipleTouchEnabled.
  UITouch* const touch = touches.anyObject;
  STUTextLink* const link = [_layer.links linkClosestToPoint:[touch locationInView:self]
                                                 maxDistance:_linkTouchAreaExtensionRadius];
  if (!link) return;
  STULabelOverlayStyle* const style = _bits.delegateRespondsToOverlayStyleForActiveLink
                                    ? [_delegate label:self overlayStyleForActiveLink:link
                                           withDefault:_activeLinkOverlayStyle]
                                    : _activeLinkOverlayStyle;
  _currentTouch = touch;
  _activeLinkContentOrigin = _contentBounds.origin;
  if (!style) {
    _activeLinkOrOverlayLayer = link;
  } else {
    addActiveLinkOverlay(self, style, link, false);
  }
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [super touchesMoved:touches withEvent:event];
  if (!_currentTouch || ![touches containsObject:_currentTouch]) return;
  updateActiveLinkOverlayIsHidden(self);
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [super touchesCancelled:touches withEvent:event];
  const size_t touchesCount = touches.count;
  STU_DEBUG_ASSERT(touchesCount <= _touchCount);
  _touchCount -= touchesCount;
  if (!_currentTouch || ![touches containsObject:_currentTouch]) return;
  clearCurrentLabelTouch(self);
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
  [super touchesEnded:touches withEvent:event];
  const size_t touchesCount = touches.count;
  STU_DEBUG_ASSERT(touchesCount <= _touchCount);
  _touchCount -= touchesCount;
  if (!_currentTouch || ![touches containsObject:_currentTouch]) return;
  STUTextLink* const link = self.activeLink;
  const CGPoint point = [_currentTouch locationInView:self];
  clearCurrentLabelTouch(self);
  if (!link) return;
  if (_bits.delegateRespondsToLinkWasTapped) {
    [_delegate label:self link:link wasTappedAtPoint:point];
  } else if (NSURL* const url = urlLinkAttribute(link)) {
    openURL(url);
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer {
  if (gestureRecognizer == _longPressGestureRecognizer) {
    STUTextLink* const link = self.activeLink;
    if (!link) return false;
    return !_bits.delegateRespondsToLinkCanBeLongPressed
        || [_delegate label:self link:link
              canBeLongPressedAtPoint:[_longPressGestureRecognizer locationInView:self]];
  }
  if ([gestureRecognizer isKindOfClass:UITapGestureRecognizer.class]
      && [_layer.links linkClosestToPoint:[gestureRecognizer locationInView:self]
                              maxDistance:_linkTouchAreaExtensionRadius])
  {
    return false;
  }
  return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

static void initializeLongPressGestureRecognizer(STULabel* self) {
  STU_DEBUG_ASSERT(self->_longPressGestureRecognizer == nil);
  self->_longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
                                         initWithTarget:self
                                         action:@selector(stu_longPressGesture)];
  [self addGestureRecognizer:self->_longPressGestureRecognizer];
}

- (UILongPressGestureRecognizer*)longPressGestureRecognizer {
  if (!_longPressGestureRecognizer) {
    initializeLongPressGestureRecognizer(self);
  }
  return _longPressGestureRecognizer;
}

- (void)stu_longPressGesture {
  if (_longPressGestureRecognizer.state != UIGestureRecognizerStateBegan) return;
  STUTextLink* const link = self.activeLink;
  if (!link) return;
  [self stu_link:link wasLongPressedAtPoint:[_longPressGestureRecognizer locationInView:self]
                         afterCancelledDrag:false];
}

- (void)stu_link:(STUTextLink*)link wasLongPressedAtPoint:(CGPoint)point
afterCancelledDrag:(bool)afterCancelledDrag
{
  if (afterCancelledDrag) {
    // The drag cancel animation may take some time in which the user may have navigated away.
    UIWindow* const window = self.window;
    if (!window
        || !CGRectIntersectsRect(window.bounds, [window convertRect:link.bounds fromView:self]))
    {
      return;
    }
    if (_bits.delegateRespondsToLinkCanBeLongPressed
        && ![_delegate label:self link:link canBeLongPressedAtPoint:point])
    {
      return;
    }
  }
  if (_bits.delegateRespondsToLinkWasLongPressed) {
    [_delegate label:self link:link wasLongPressedAtPoint:point];
  } else {
    [self stu_presentActionSheetForLink:link
                     fromViewController:[self valueForKey:@"_viewControllerForAncestor"]]; // TODO
  }
}

// MARK: - UIDragInteraction

static void initializeDragInteraction(STULabel* self) API_AVAILABLE(ios(11.0)) {
  STU_DEBUG_ASSERT(self->_dragInteraction == nil);
  self->_dragInteraction = [[STULabelDragInteraction alloc] initWithDelegate:self];
  if (self->_dragInteraction.enabled != self->_bits.dragInteractionEnabled) {
    self->_dragInteraction.enabled = self->_bits.dragInteractionEnabled;
  }
  self->_dragInteraction->stu_label = self;
  [self addInteraction:self->_dragInteraction];
}

- (UIDragInteraction*)dragInteraction {
  if (!_dragInteraction) {
    initializeDragInteraction(self);
  }
  return _dragInteraction;
}

- (bool)dragInteractionEnabled {
  return _bits.dragInteractionEnabled;
}

STU_INLINE // Called by -[STULabelDragInteraction setEnabled:].
void STULabelSetBitsDragInterationEnabled(STULabel* self, bool dragInterationEnabled) {
  self->_bits.dragInteractionEnabled = dragInterationEnabled;
}

- (void)setDragInteractionEnabled:(bool)enabled {
  if (_bits.dragInteractionEnabled == enabled) return;
  if (!_dragInteraction) {
    _bits.dragInteractionEnabled = enabled;
    if (enabled && (_textFrameFlags & STUTextFrameHasLink)) {
      if (@available(iOS 11, *)) {
        initializeDragInteraction(self);
      }
    }
  } else {
    _dragInteraction.enabled = enabled; // Will also set _bits.dragInteractionEnabled;
  }
}

static const char* const associatedLinkKey = "STULabelLink";

STU_INLINE STUTextLink* __nullable dragItemLink(UIDragItem* item)
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  return objc_getAssociatedObject(item, associatedLinkKey);
}


STU_INLINE void setDragItemLink(UIDragItem* item, STUTextLink* __nullable link)
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  objc_setAssociatedObject(item, associatedLinkKey, link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

STU_INLINE
STUTextLink* __nullable dragSessionCurrentlyLiftedLink(id<UIDragSession> session)
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  return objc_getAssociatedObject(session, associatedLinkKey);
}

STU_INLINE
void setDragSessionCurrentlyLiftedLink(id<UIDragSession> session, STUTextLink* __nullable link)
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  objc_setAssociatedObject(session, associatedLinkKey, link, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<UIDragItem*>*)stu_dragItemsForPoint:(CGPoint)point
                                       session:(nullable id<UIDragSession>)session
  API_AVAILABLE(ios(11.0))
{
  STUTextLink* const link = self.activeLink
                          ?: [_layer.links linkClosestToPoint:point
                                                  maxDistance:_linkTouchAreaExtensionRadius];
  if (!link) return nil;
  if ([_ghostingMaskLayer hasGhostedLink:link]) return nil;

  const id<STULabelDelegate> delegate = _delegate;
  if (_bits.delegateRespondsToLinkCanBeDragged
      && ![delegate label:self link:link canBeDraggedFromPoint:point])
  {
    return nil;
  }
  UIDragItem* dragItem = nil;
  if (_bits.delegateRespondsToDragItemForLink) {
    dragItem = [delegate label:self dragItemForLink:link];
    if (!dragItem) return nil;
  }
  if (!dragItem || !dragItem.previewProvider) {
    NSURL* const url = urlLinkAttribute(link);
    UIImage* image = nil;
    if (!url) {
      if (const id value = link.linkAttribute; [value isKindOfClass:UIImage.class]) {
        image = value;
      }
    }
    if (!dragItem) {
      if (!url && !image) return nil;
      dragItem = [[UIDragItem alloc] initWithItemProvider:
                    [[NSItemProvider alloc] initWithObject:url ?: image]];
    }
    if (!dragItem.previewProvider) {
      STUTextFrame* const textFrame = _layer.textFrame;
      dragItem.previewProvider = ^UIDragPreview*{
        if (image) {
          return [[UIDragPreview alloc] initWithView:[[UIImageView alloc] initWithImage:image]];
        }
        NSAttributedString* const originalAttributedString = textFrame.originalAttributedString;
        const NSRange rangeInOriginalString = link.rangeInOriginalString;
        NSAttributedString* title;
        if (equal(link.linkAttribute,
                  [originalAttributedString attributesAtIndex:rangeInOriginalString.location
                                               effectiveRange:nil]
                    [NSLinkAttributeName]))
        {
          title = [originalAttributedString attributedSubstringFromRange:rangeInOriginalString];
        } else {
          title = [textFrame.truncatedAttributedString
                     attributedSubstringFromRange:link.rangeInTruncatedString];
        }
        title = [title stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations];
        return [UIDragPreview previewForURL:(url ?: [NSURL URLWithString:@""])
                                      title:title.string];
      };
    }
  }

  setDragItemLink(dragItem, link);
  setDragSessionCurrentlyLiftedLink(session, link);

  return [NSArray arrayWithObject:dragItem];
}


- (NSArray<UIDragItem*>*)dragInteraction:(UIDragInteraction* __unused)interaction
                itemsForBeginningSession:(id<UIDragSession>)session
  NS_AVAILABLE_IOS(11_0)
{
  return [self stu_dragItemsForPoint:[session locationInView:self] session:session];
}


- (NSArray<UIDragItem*>*)dragInteraction:(UIDragInteraction* __unused)interaction
                 itemsForAddingToSession:(id<UIDragSession>)session
                        withTouchAtPoint:(CGPoint)point
  NS_AVAILABLE_IOS(11_0)
{
  return [self stu_dragItemsForPoint:point session:session];
}

- (UITargetedDragPreview*)stu_targetedDragPreviewForItem:(UIDragItem*)item
    NS_AVAILABLE_IOS(11_0)
{
  STUTextLink* const link = [_layer.links linkMatchingLink:dragItemLink(item)];
  if (!link) return nil;

  STUTextFrame* const textFrame = _layer.textFrame;

  NSRange rangeInTruncatedString = link.rangeInTruncatedString;
  STUTextFrameRange range = [textFrame rangeForRangeInTruncatedString:rangeInTruncatedString];
  STUTextRectArray* rects = link;
  NSDictionary* const attributes = [textFrame attributesAtIndexInTruncatedString:
                                                rangeInTruncatedString.location];

  { // If the link was truncated with an ellipsis, we include the ellipsis in the range.
    const STUTextFrameRange range2 = [textFrame rangeForRangeInOriginalString:
                                                  link.rangeInOriginalString];
    const NSRange rangeInTruncatedString2 = STUTextFrameRangeGetRangeInTruncatedString(range2);
    if (rangeInTruncatedString2.length == rangeInTruncatedString.length + 1) {
      const bool isTruncatedAtEnd = rangeInTruncatedString2.location
                                    == rangeInTruncatedString.location;
      NSAttributedString* truncationToken = nil;
      [textFrame getRangeInOriginalString:nil
                          truncationToken:&truncationToken
                             indexInToken:nil
                                 forIndex:isTruncatedAtEnd ? range.end : range2.start];
      if (truncationToken && [truncationToken.string isEqualToString:@"…"]) {
        rangeInTruncatedString = rangeInTruncatedString2;
        range = range2;
        rects = [textFrame rectsForRange:range frameOrigin:_layer.textFrameOrigin
                            displayScale:_layer.contentsScale];
      }
    }
  }

  STUTextFrameDrawingOptions* const drawingOptions = STULabelLayerGetParams(_layer)
                                                     .frozenDrawingOptions().unretained;

  // We treat lone text attachment as inline images and use different preview parameters.

  bool isAttachment = false;
  const CGRect linkBounds = rects.bounds;
  CGRect attachmentBounds = {};
  if (rangeInTruncatedString.length == 1) {
    STUTextAttachment* const attachment = attributes[STUAttachmentAttributeName];
    if (attachment) {
      isAttachment = true;
      // For text attachments smaller than the full line height it looks better when the image view
      // only uses the typographic bounds of the text attachment itself.
      // (UITextView's targeted drag preview for small attachments is currently buggy.)
      attachmentBounds = attachment.bounds;
      const CGFloat scale = _layer.layoutInfo.textScaleFactor;
      attachmentBounds.origin.x *= scale;
      attachmentBounds.origin.y *= scale;
      attachmentBounds.size.width *= scale;
      attachmentBounds.size.height *= scale;
      attachmentBounds.origin.x += linkBounds.origin.x;
      attachmentBounds.origin.y += [link baselineForRectAtIndex:0];
    }
  }
  const CGFloat ex = isAttachment ? 0 : -14;
  const CGFloat ey = isAttachment ? 0 : -10;
  const CGRect bounds = !isAttachment ? CGRectInset(linkBounds, ex, ey) : attachmentBounds;
  const CGFloat contentsScale = _layer.contentsScale;
  const bool shouldTile = max(bounds.size.width, bounds.size.height)*contentsScale > 4096;
  
  STULabelSubrangeView* const view = [(shouldTile ? [STULabelTiledSubrangeView alloc]
                                                  : [STULabelSubrangeView alloc]) init];
  view.contentScaleFactor = contentsScale;
  view.frame = bounds;
  const CGPoint drawingOrigin = _layer.textFrameOrigin - bounds.origin;
  const STULabelDrawingBlock drawingBlock = _layer.drawingBlock;
  [view setDrawingBlock:^(CGContext* context, CGRect rect __unused,
                          const STUCancellationFlag* cancellationFlag)
  {
    drawLabelTextFrameRange(textFrame, range, drawingOrigin, context, false, 0,
                            drawingOptions, drawingBlock, cancellationFlag);
  }];

  UIDragPreviewParameters* params = nil;
  if (isAttachment) {
    params = [[UIDragPreviewParameters alloc] init];
  } else {
    // We use the initWithTextLineRects initializer because we want the text-optimized behaviour.
    // In particular, we don't want the small zoom effect that we'd get with the other initializer.
    params = [[UIDragPreviewParameters alloc] initWithTextLineRects:@[]];
    // The current UIKit implementation seems to not properly round some of the corners of more
    // complex line rect shapes, so we use our own implementation here.
    const CGAffineTransform tf = CGAffineTransformMakeTranslation(-bounds.origin.x,
                                                                  -bounds.origin.y);
    const CGPathRef path = [rects createPathWithEdgeInsets:UIEdgeInsets{.left = ex, .right = ex,
                                                                        .top = ey, .bottom = ey}
                                              cornerRadius:abs(min(ex, ey))
                   extendTextLinesToCommonHorizontalBounds:true
                                          fillTextLineGaps:true
                                                 transform:&tf];
    params.visiblePath = [UIBezierPath bezierPathWithCGPath:path];
    CFRelease(path);
  }

  const auto rangeInTruncatedStringFor = [&](STUTextRange range) -> Range<UInt> {
    return range.type == STURangeInTruncatedString ? range.range
         : STUTextFrameRangeGetRangeInTruncatedString(
            [textFrame rangeForRangeInOriginalString:range.range]);
  };

  UIColor* backgroundColor = nil;
  if (STUTextHighlightStyle* const highlightStyle = drawingOptions.highlightStyle;
      highlightStyle
      && rangeInTruncatedStringFor(drawingOptions.highlightRange)
         .contains(rangeInTruncatedString.location)
      && highlightStyle.background)
  {
    backgroundColor = highlightStyle.background.color; // May be nil.
  } else if (attributes) {
    STUBackgroundAttribute* const bg = attributes[STUBackgroundAttributeName];
    if (bg) {
      backgroundColor = bg.color;
    } else {
      backgroundColor = attributes[NSBackgroundColorAttributeName];
    }
  }
  if (!backgroundColor) {
    backgroundColor = self.backgroundColor;
  }
  id<STULabelDelegate> delegate = _delegate;
  if (delegate && [delegate respondsToSelector:
                    @selector(label:backgroundColorForTargetedPreviewOfDragItem:withDefault:)])
  {
    backgroundColor = [delegate label:self backgroundColorForTargetedPreviewOfDragItem:item
                        withDefault:backgroundColor];
  }
  if (backgroundColor) {
    params.backgroundColor = backgroundColor;
  }
  return [[UITargetedDragPreview alloc]
            initWithView:view parameters:params
                  target:[[UIDragPreviewTarget alloc] initWithContainer:self center:view.center]];
}

- (UITargetedDragPreview*)dragInteraction:(UIDragInteraction* __unused)interaction
                    previewForLiftingItem:(UIDragItem*)item
                                  session:(id<UIDragSession> __unused)session
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  return [self stu_targetedDragPreviewForItem:item];
}

- (UITargetedDragPreview*)dragInteraction:(UIDragInteraction* __unused)interaction
                 previewForCancellingItem:(UIDragItem*)item
                              withDefault:(UITargetedDragPreview* __unused)defaultPreview
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  return [self stu_targetedDragPreviewForItem:item];
}

- (void)stu_startedDragInteractionWithLink:(STUTextLink*)link {
  if (!_ghostingMaskLayer) {
    _layer.stu_alwaysUsesContentSublayer = true;
    CALayer* const contentLayer = _layer.stu_contentSublayer;
    _ghostingMaskLayer = [[STULabelGhostingMaskLayer alloc] init];
    [_ghostingMaskLayer setMaskedLayerFrame:contentLayer.frame links:_layer.links];
    contentLayer.mask = _ghostingMaskLayer;
  }
  [_ghostingMaskLayer ghostLink:link];
}

- (void)stu_cancelledDragInteractionWithLink:(STUTextLink*)link {
  if ([_ghostingMaskLayer unghostLink:link]) {
    [self stu_dragInteractionEnded];
  }
}

- (void)stu_dragInteractionEnded {
  if (!_ghostingMaskLayer) return;
  [_ghostingMaskLayer removeFromSuperlayer];
  _ghostingMaskLayer = nil;
  _layer.stu_alwaysUsesContentSublayer = false;
}

- (void)dragInteraction:(UIDragInteraction* __unused)interaction
willAnimateLiftWithAnimator:(id<UIDragAnimating>)animator session:(id<UIDragSession>)session
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  STUTextLink* const link = dragSessionCurrentlyLiftedLink(session);
  if (!link) return;
  setDragSessionCurrentlyLiftedLink(session, nil);
  [self stu_startedDragInteractionWithLink:link];
  [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
    if (finalPosition == UIViewAnimatingPositionEnd) return;
    [self stu_cancelledDragInteractionWithLink:link];
    [self stu_link:link wasLongPressedAtPoint:[session locationInView:self]
                           afterCancelledDrag:true];
  }];
}

-(void)dragInteraction:(UIDragInteraction* __unused)interaction item:(UIDragItem*)item
willAnimateCancelWithAnimator:(id<UIDragAnimating>)animator
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
    if (finalPosition != UIViewAnimatingPositionEnd) return;
    [self stu_cancelledDragInteractionWithLink:dragItemLink(item)];
  }];
}

- (void)dragInteraction:(UIDragInteraction* __unused)interaction
                session:(id<UIDragSession> __unused)session
    didEndWithOperation:(UIDropOperation __unused)operation
  API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
{
  [self stu_dragInteractionEnded];
}

// MARK: - STULabelLayerDelegate methods (except labelLayerTextLayoutWasInvalidated)

- (bool)labelLayer:(STULabelLayer* __unused)labelLayer
shouldDisplayAsynchronouslyWithProposedValue:(bool)value
{
  value &= _touchCount == 0;
  if (_bits.delegateRespondsToShouldDisplayAsynchronously) {
    // This is also an event notification, so we do the call even if we don't need the return value.
    value = [_delegate label:self shouldDisplayAsynchronouslyWithProposedValue:value];
  }
  // Synchronous drawing seems preferable for interactive usage and simplifies keeping the 
  // the overlays in sync with the displayed content.
  if (_currentTouch || _ghostingMaskLayer) {
    return false;
  }
  return value;
}

- (void)labelLayer:(STULabelLayer* __unused)labelLayer
didDisplayTextWithFlags:(STUTextFrameFlags)textFrameFlags inRect:(CGRect)contentBounds
{
  _contentBounds = contentBounds;
  _textFrameFlags = textFrameFlags;
  updateLayoutGuides(self);
  if (textFrameFlags & STUTextFrameHasLink) {
    if (!_longPressGestureRecognizer) {
      initializeLongPressGestureRecognizer(self);
    }
    if (!_dragInteraction && _bits.dragInteractionEnabled) {
      if (@available(iOS 11, *)) {
        initializeDragInteraction(self);
      }
    }
  }
  if (_activeLinkOrOverlayLayer || _ghostingMaskLayer) {
    STUTextLinkArray* const links = _layer.links;
    if (_activeLinkOrOverlayLayer) {
      STUTextLink* const link = [links linkMatchingLink:activeLink(self)];
      if (!link) {
        clearCurrentLabelTouch(self);
      } else {
        if (!_bits.hasActiveLinkOverlayLayer) {
          _activeLinkOrOverlayLayer = link;
        } else {
          STULabelLinkOverlayLayer* const overlay = self->_activeLinkOrOverlayLayer;
          overlay.link = link;
          overlay.position = CGPointZero;
        }
        updateActiveLinkOverlayIsHidden(self);
      }
    }
    if (self->_ghostingMaskLayer) {
      CALayer* const contentLayer = _layer.stu_contentSublayer;
      contentLayer.mask = _ghostingMaskLayer;
      [_ghostingMaskLayer setMaskedLayerFrame:contentLayer.frame links:links];
    }
  }
  if (_lastLinkObserver) {
    updateLabelLinkObserversAfterLayoutChange(self);
  }
  if (_bits.delegateRespondsToDidDisplayText) {
    [_delegate label:self didDisplayTextWithFlags:textFrameFlags inRect:contentBounds];
  }
}

- (void)labelLayer:(STULabelLayer* __unused)labelLayer
didMoveDisplayedTextToRect:(CGRect)contentBounds
{
  _contentBounds.origin = contentBounds.origin;
  updateLayoutGuides(self);
  if (_textFrameAccessibilityElement) {
    _textFrameAccessibilityElement.textFrameOriginInContainerSpace = _layer.textFrameOrigin;
  }
  if (_activeLinkOrOverlayLayer) {
    if (_bits.hasActiveLinkOverlayLayer) {
      const CGPoint position = {_activeLinkContentOrigin.x - contentBounds.origin.x,
                                _activeLinkContentOrigin.y - contentBounds.origin.y};
      activeLinkOverlayLayer(self).position = position;
      updateActiveLinkOverlayIsHidden(self);
    }
  }
  if (_ghostingMaskLayer) {
    CALayer* const contentLayer = _layer.stu_contentSublayer;
    if (contentLayer.frame.size == _ghostingMaskLayer.frame.size) {
      _ghostingMaskLayer.position = contentLayer.position;
    } else {
      [_ghostingMaskLayer setMaskedLayerFrame:contentLayer.frame links:_layer.links];
    }
  }
  if (_lastLinkObserver) {
    updateLabelLinkObserversAfterLayoutChange(self);
  }
  if (_bits.delegateRespondsDidMoveDisplayedText) {
    [_delegate label:self didMoveDisplayedTextToRect:contentBounds];
  }
}

// MARK: - STULabelLayer forwarder methods

- (STULabelDrawingBlock)drawingBlock {
  return _layer.drawingBlock;
}
- (void)setDrawingBlock:(STULabelDrawingBlock)drawingBlock {
  [_layer setDrawingBlock:drawingBlock];
}

- (bool)displaysAsynchronously {
  return _layer.displaysAsynchronously;
}
- (void)setDisplaysAsynchronously:(bool)displaysAsynchronously {
  _layer.displaysAsynchronously = displaysAsynchronously;
}

- (STULabelVerticalAlignment)verticalAlignment {
  return _layer.verticalAlignment;
}
- (void)setVerticalAlignment:(STULabelVerticalAlignment)verticalAlignment  {
  _layer.verticalAlignment = verticalAlignment;
}

- (UIEdgeInsets)contentInsets {
  return _layer.contentInsets;
}
- (void)setContentInsets:(UIEdgeInsets)contentInsets {
  _layer.contentInsets = contentInsets;
}

- (STUDirectionalEdgeInsets)directionalContentInsets {
  return _layer.directionalContentInsets;
}
- (void)setDirectionalContentInsets:(STUDirectionalEdgeInsets)contentInsets {
  _layer.directionalContentInsets = contentInsets;
}

- (UIColor*)backgroundColor {
  return [UIColor colorWithCGColor:_layer.displayedBackgroundColor];
}
- (void)setBackgroundColor:(UIColor*)backgroundColor {
  _layer.displayedBackgroundColor = backgroundColor.CGColor;
}

- (NSString*)text {
  return _layer.text;
}
- (void)setText:(NSString*)text {
  [_layer setText:text];
}

- (UIFont*)font {
  return _layer.font;
}
- (void)setFont:(UIFont*)font {
  _layer.font = font;
}

- (UIColor*)textColor {
  return _layer.textColor;
}
- (void)setTextColor:(UIColor*)textColor {
  _layer.textColor = textColor;
}

- (NSTextAlignment)textAlignment {
  return _layer.textAlignment;
}
- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  _layer.textAlignment = textAlignment;
}

- (STULabelDefaultTextAlignment)defaultTextAlignment {
  return _layer.defaultTextAlignment;
}
- (void)setDefaultTextAlignment:(STULabelDefaultTextAlignment)defaultTextAlignment {
  _layer.defaultTextAlignment = defaultTextAlignment;
}

- (NSAttributedString*)attributedText {
  return _layer.attributedText;
}
- (void)setAttributedText:(NSAttributedString*)attributedText {
  _layer.attributedText = attributedText;
}

- (void)setTextFrameOptions:(nullable STUTextFrameOptions*)options {
  [_layer setTextFrameOptions:options];
}

- (STUTextLayoutMode)textLayoutMode {
  return _layer.textLayoutMode;
}
- (void)setTextLayoutMode:(STUTextLayoutMode)textLayoutMode {
  _layer.textLayoutMode = textLayoutMode;
}

- (NSInteger)maximumLineCount {
  return _layer.maximumLineCount;
}
- (void)setMaximumLineCount:(NSInteger)maximumLineCount {
  _layer.maximumLineCount = maximumLineCount;
}

- (STULastLineTruncationMode)lastLineTruncationMode {
  return _layer.lastLineTruncationMode;
}
- (void)setLastLineTruncationMode:(STULastLineTruncationMode)lastLineTruncationMode {
  _layer.lastLineTruncationMode = lastLineTruncationMode;
}

- (NSAttributedString*)truncationToken {
  return _layer.truncationToken;
}
- (void)setTruncationToken:(NSAttributedString*)truncationToken {
  _layer.truncationToken = truncationToken;
}

- (STUTruncationRangeAdjuster)truncationRangeAdjuster {
  return _layer.truncationRangeAdjuster;
}
- (void)setTruncationRangeAdjuster:(STUTruncationRangeAdjuster)truncationRangeAdjuster {
  _layer.truncationRangeAdjuster = truncationRangeAdjuster;
}

- (CGFloat)minimumTextScaleFactor {
  return _layer.minimumTextScaleFactor;
}
- (void)setMinimumTextScaleFactor:(CGFloat)minimumTextScaleFactor {
  _layer.minimumTextScaleFactor = minimumTextScaleFactor;
}

- (CGFloat)textScaleFactorStepSize {
  return _layer.textScaleFactorStepSize;
}
- (void)setTextScaleFactorStepSize:(CGFloat)textScaleFactorStepSize {
  _layer.textScaleFactorStepSize = textScaleFactorStepSize;
}

- (STUBaselineAdjustment)textScalingBaselineAdjustment {
  return _layer.textScalingBaselineAdjustment;
}
- (void)setTextScalingBaselineAdjustment:(STUBaselineAdjustment)textScalingBaselineAdjustment {
  _layer.textScalingBaselineAdjustment = textScalingBaselineAdjustment;
}

- (STULastHyphenationLocationInRangeFinder)lastHyphenationLocationInRangeFinder {
  return _layer.lastHyphenationLocationInRangeFinder;
}
- (void)setLastHyphenationLocationInRangeFinder:(STULastHyphenationLocationInRangeFinder)finder {
  _layer.lastHyphenationLocationInRangeFinder = finder;
}

- (CGSize)sizeThatFits:(CGSize)size {
  return [_layer sizeThatFits:size];
}

- (BOOL)isHighlighted {
  return _layer.highlighted;
}
- (void)setHighlighted:(BOOL)highlighted {
  _layer.highlighted = highlighted;
}

- (nullable STUTextHighlightStyle*)highlightStyle {
  return _layer.highlightStyle;
}
- (void)setHighlightStyle:(nullable  STUTextHighlightStyle*)highlightStyle {
  _layer.highlightStyle = highlightStyle;
}

- (STUTextRange)highlightRange {
  return _layer.highlightRange;
}
- (void)setHighlightRange:(STUTextRange)highlightRange {
  _layer.highlightRange = highlightRange;
}
- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType {
  [_layer setHighlightRange:range type:rangeType];
}

- (STULabelLayoutInfo)layoutInfo {
  return _layer.layoutInfo;
}

- (nonnull STUTextLinkArray*)links {
  return _layer.links;
}

- (void)configureWithPrerenderer:(nonnull STULabelPrerenderer*)prerenderer {
  [_layer configureWithPrerenderer:prerenderer];
  // TODO: check override colors
}


- (bool)clipsContentToBounds {
  return _layer.clipsContentToBounds;
}
- (void)setClipsContentToBounds:(bool)clipsContentToBounds {
  _layer.clipsContentToBounds = clipsContentToBounds;
}

- (bool)neverUsesGrayscaleBitmapFormat {
  return _layer.neverUsesGrayscaleBitmapFormat;
}
- (void)setNeverUsesGrayscaleBitmapFormat:(bool)neverUsesGrayscaleBitmapFormat {
  _layer.neverUsesGrayscaleBitmapFormat = neverUsesGrayscaleBitmapFormat;
}

- (bool)neverUsesExtendedRGBBitmapFormat {
  return _layer.neverUsesExtendedRGBBitmapFormat;
}
- (void)setNeverUsesExtendedRGBBitmapFormat:(bool)neverUsesExtendedRGBBitmapFormat {
  _layer.neverUsesExtendedRGBBitmapFormat = neverUsesExtendedRGBBitmapFormat;
}

- (bool)releasesShapedStringAfterRendering {
  return _layer.releasesShapedStringAfterRendering;
}
- (void)setReleasesShapedStringAfterRendering:(bool)releasesShapedStringAfterRendering  {
  _layer.releasesShapedStringAfterRendering = releasesShapedStringAfterRendering;
}

- (bool)releasesTextFrameAfterRendering {
  return _layer.releasesTextFrameAfterRendering;
}
- (void)setReleasesTextFrameAfterRendering:(bool)releasesTextFrameAfterRendering {
  _layer.releasesTextFrameAfterRendering = releasesTextFrameAfterRendering;
}

- (STUTextFrame*)textFrame {
  return _layer.textFrame;
}

- (CGPoint)textFrameOrigin {
  return _layer.textFrameOrigin;
}

STU_EXPORT
STUTextFrameWithOrigin STULabelGetTextFrameWithOrigin(STULabel* self) {
  return STULabelLayerGetTextFrameWithOrigin(self->_layer);
};

@end

@implementation STULabelDragInteraction
- (void)setEnabled:(BOOL)enabled {
  if (stu_label) {
    STULabelSetBitsDragInterationEnabled(stu_label, enabled);
  }
  [super setEnabled:enabled];
}
@end

@implementation STULabelLinkObserver {
  STULabelLinkObserver* __unsafe_unretained __nullable _next;
  STULabelLinkObserver* __unsafe_unretained __nullable _previous;
  STULabel* __unsafe_unretained __nullable _label;
  STUTextLink* _link;
  STULabelLinkObserverBlock __nullable _observerBlock;
  bool _linkIsNull;
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (instancetype)initWithLabel:(STULabel*)label link:(STUTextLink*)link {
  return [self initWithLabel:label link:link observer:nil];
}

- (instancetype)initWithLabel:(STULabel*)label link:(STUTextLink*)link
                     observer:(STULabelLinkObserverBlock)observerBlock
{
  if (!label || !link) return nil;
  _label = label;
  _link = link;
  _linkIsNull = false;
  _observerBlock = observerBlock;

  // Add self to linked list.
  if (STULabelLinkObserver* __unsafe_unretained const last = label->_lastLinkObserver) {
    last->_next = self;
    self->_previous = last;
  }
  label->_lastLinkObserver = self;

  return self;
}

- (void)dealloc {
  // Remove self from linked list.
  if (_next) {
    _next->_previous = _previous;
  } else if (_label) {
    STU_ASSERT(self == _label->_lastLinkObserver);
    _label->_lastLinkObserver = _previous;
  }
  if (_previous) {
    _previous->_next = _next;
  }
}

- (nullable STULabel*)label { return _label; }

- (nullable STUTextLink*)link { return _linkIsNull ? nil : _link; }

- (STUTextLink*)mostRecentNonNullLink { return _link; }

- (void)linkDidChangeFrom:(nullable STUTextLink*)oldValue to:(nullable STUTextLink*)newValue {
  if (_observerBlock) {
    _observerBlock(_label, oldValue, newValue);
  }
}

static void updateLabelLinkObserversAfterLayoutChange(STULabel* label) {
  STUTextLinkArray* const currentLinks = label.links;
  for (STULabelLinkObserver* __strong observer = label->_lastLinkObserver;
       observer; observer = observer->_previous)
  {
    STUTextLink* const link = [currentLinks linkMatchingLink:observer->_link];
    STUTextLink* const oldLink = observer->_linkIsNull ? nil : observer->_link;
    if (link == oldLink) continue;
    if (link) {
      observer->_link = link;
      observer->_linkIsNull = false;
    } else {
      observer->_linkIsNull = true;
    }
    if (link && oldLink && [link isEqual:oldLink]) continue;
    [observer linkDidChangeFrom:oldLink to:link];
  }
}

static void updateLabelLinkObserversInLabelDealloc(STULabel* __unsafe_unretained label) {
  // Nil out all __unsafe_unretained references to dealloc'd label before calling linkDidChange.
  for (STULabelLinkObserver* __unsafe_unretained observer = label->_lastLinkObserver;
       observer; observer = observer->_previous)
  {
    observer->_label = nil;
  }
  for (STULabelLinkObserver* __strong observer = label->_lastLinkObserver;
       observer; observer = observer->_previous)
  {
    const bool linkWasNull = observer->_linkIsNull;
    observer->_linkIsNull = true;
    [observer linkDidChangeFrom:(linkWasNull ? nil : observer->_link) to:nil];
  }
}
@end

// MARK: - STULabelLinkPopoverObserver

@interface STULabelLinkPopoverObserver : STULabelLinkObserver
                                         <UIPopoverPresentationControllerDelegate>
- (instancetype)initWithLabel:(STULabel*)label link:(STUTextLink*)link
               popoverPresentationController:(UIPopoverPresentationController*)
                                               popoverPresentationController
  NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithLabel:(STULabel*)label link:(STUTextLink*)link
                     observer:(STULabelLinkObserverBlock)observerBlock
  NS_UNAVAILABLE;
@end

@implementation STULabelLinkPopoverObserver {
  UIPopoverPresentationController* __weak _popoverPresentationController;
}

static CGRect popoverSourceRect(STULabel* label, STUTextLink*link) {
  const CGRect linkBounds = link.bounds;
  UIWindow* const window = label.window;
  if (!window) return linkBounds;
  const CGRect visibleLabelBounds = [label convertRect:window.bounds fromView:window];
  /// UIPopoverPresentationController has difficulties with very large source rects.
  if (area(linkBounds) >= 0.75*area(visibleLabelBounds)) {
    const CGRect visibleLinkBounds = CGRectIntersection(linkBounds, visibleLabelBounds);
    if (!CGRectIsEmpty(visibleLinkBounds)) {
      return CGRect{{visibleLinkBounds.origin.x + visibleLinkBounds.size.width/2,
                     visibleLinkBounds.origin.y + visibleLinkBounds.size.height/2},
                    {1, 1}};
    }
  }
  return linkBounds;
}

- (instancetype)initWithLabel:(STULabel*)label link:(STUTextLink*)link
popoverPresentationController:(UIPopoverPresentationController*)ppc
{
  if (!ppc) return nil;
  if ((self = [super initWithLabel:label link:link observer:nil]))  {
    _popoverPresentationController = ppc;
    ppc.delegate = self;
    ppc.sourceView = label;
    ppc.sourceRect = popoverSourceRect(label, link);
    ppc.canOverlapSourceViewRect = true;
  }
  return self;
}

- (void)linkDidChangeFrom:(STUTextLink* __nullable __unused)oldValue
                       to:(STUTextLink* __nullable)newValue
{
  if (!newValue) return;
  // Setting this rect after the popover has been presented currently doesn't have any effect,
  // but maybe that changes in the future.
  _popoverPresentationController.sourceRect = popoverSourceRect(self.label, newValue);
}

// This delegate method may be called before linkDidChangeFrom:to:
- (void)popoverPresentationController:(UIPopoverPresentationController* __unused)ppc
          willRepositionPopoverToRect:(inout CGRect*)rect
                               inView:(inout UIView* __autoreleasing * __unused)view
{
  STUTextLink* const link = [self.label.links linkMatchingLink:self.mostRecentNonNullLink];
  if (!link) return;
  *rect = popoverSourceRect(self.label, link);
}

@end

static void addLabelLinkPopoverObserver(STULabel* label, STUTextLink* link, UIViewController* vc) {
  auto* const ppc = vc.popoverPresentationController;
  if (!ppc) return;
  auto* const observer = [[STULabelLinkPopoverObserver alloc] initWithLabel:label link:link
                                              popoverPresentationController:ppc];
  if (!observer) return;
  objc_setAssociatedObject(ppc, (__bridge void*)observer, observer,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
