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

#if TARGET_OS_MACCATALYST
  #import <AppKit/AppKit.h>
#else
  #import <SafariServices/SafariServices.h>
#endif

#import <objc/runtime.h>

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

// The lower-level parts of the Auto Layout API are largely private, which makes the implementation
// of some Auto-Layout-related functionality here more complicated and a bit less efficient than it
// otherwise would be.

// MARK: - STULabelContentLayoutGuide

@interface STULabelContentLayoutGuide : UILayoutGuide
@end
@implementation STULabelContentLayoutGuide {
  NSLayoutConstraint* _leftConstraint;
  NSLayoutConstraint* _rightConstraint;
  NSLayoutConstraint* _topConstraint;
  NSLayoutConstraint* _bottomConstraint;
  UIEdgeInsets _contentInsets;
}

/// Also adds the guide to the label.
static void initContentLayoutGuide(STULabelContentLayoutGuide* self, STULabel* label) {
  [label addLayoutGuide:self];
  self->_leftConstraint   = [self.leftAnchor constraintEqualToAnchor:label.leftAnchor];
  self->_rightConstraint  = [self.rightAnchor constraintEqualToAnchor:label.rightAnchor];
  self->_topConstraint    = [self.topAnchor constraintEqualToAnchor:label.topAnchor];
  self->_bottomConstraint = [self.bottomAnchor constraintEqualToAnchor:label.bottomAnchor];
  self->_leftConstraint.identifier   = @"contentInsets.left";
  self->_rightConstraint.identifier  = @"contentInsets.right";
  self->_topConstraint.identifier    = @"contentInsets.top";
  self->_bottomConstraint.identifier = @"contentInsets.bottom";
  [NSLayoutConstraint activateConstraints:@[self->_leftConstraint, self->_rightConstraint,
                                            self->_topConstraint, self->_bottomConstraint]];
}

static void updateContentLayoutGuide(STULabelContentLayoutGuide* __unsafe_unretained self,
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

// MARK: - STULabelBaselinesLayoutGuide

@class STULabelBaselinesLayoutGuide;

static STULabelBaselinesLayoutGuide* baselinesLayoutGuide(STULabel*);

namespace stu_label {

struct SpacingConstraint;
static void removeLineHeightSpacingConstraintRef(STULabelBaselinesLayoutGuide*,
                                                 const SpacingConstraint&);

struct FirstAndLastLineHeightInfo {
  Float32 firstLineHeight;
  Float32 lastLineHeight;
  Float32 firstLineHeightAboveBaseline;
  Float32 lastLineHeightBelowBaseline;

  FirstAndLastLineHeightInfo() = default;

  /* implicit */ STU_INLINE
  FirstAndLastLineHeightInfo(const LabelTextFrameInfo& info)
  : firstLineHeight{info.firstLineHeight},
    lastLineHeight{info.lastLineHeight},
    firstLineHeightAboveBaseline{info.firstLineHeightAboveBaseline},
    lastLineHeightBelowBaseline{info.lastLineHeightBelowBaseline}
  {}

  STU_INLINE
  friend bool operator==(const FirstAndLastLineHeightInfo& info1,
                         const FirstAndLastLineHeightInfo& info2)
  {
    return info1.firstLineHeight == info2.firstLineHeight
        && info1.lastLineHeight  == info2.lastLineHeight
        && info1.firstLineHeightAboveBaseline == info2.firstLineHeightAboveBaseline
        && info1.lastLineHeightBelowBaseline  == info2.lastLineHeightBelowBaseline;
  }

  STU_INLINE
  friend bool operator!=(const FirstAndLastLineHeightInfo& info1,
                         const FirstAndLastLineHeightInfo& info2)
  {
    return !(info1 == info2);
  }
};

struct alignas(8) SpacingConstraint {
  enum class Item : UInt8 {
    /// The left hand side of the constraint
    item1,
    /// The right hand side of the constraint
    item2
  };
  enum class Type : UInt8 {
    /// item1.baseline == item2.baseline
    ///                   + multiplier*max(item1.lineHeight, item2.lineHeight)
    ///                   + offset
    lineHeightSpacing = 0,

    /// item1.baseline == item2.baseline
    ///                   + multiplier*(item1.heightAboveBaseline + item2.heightBelowBaseline)
    ///                   + offset
    defaultSpacingBelow = 1,

    /// item1.baseline == item2.baseline
    ///                   - multiplier*(item1.heightBelowBaseline + item2.heightAboveBaseline)
    ///                   - offset
    defaultSpacingAbove = 2
  };

  CGFloat spacing() const {
    if (type == Type::lineHeightSpacing) {
      return max(height1, height2)*multiplier + offset;
    } else {
      return (height1 + height2)*multiplier + offset;
    }
  }

  CGFloat layoutConstantForSpacing(CGFloat spacing, const DisplayScale& scale) {
    const CGFloat value = ceilToScale(spacing, scale);
    return type == Type::defaultSpacingAbove ? -value : value;
  }

  NSLayoutConstraint* __weak layoutConstraint;
  // If the layout constraint lives longer than a referenced STULabelBaselinesLayoutGuide,
  // STULabelBaselinesLayoutGuide's deinit will set the corresponding reference here to nil.
  STULabelBaselinesLayoutGuide* __unsafe_unretained layoutGuide1;
  STULabelBaselinesLayoutGuide* __unsafe_unretained layoutGuide2;
  Type type;
  STUFirstOrLastBaseline baseline1;
  STUFirstOrLastBaseline baseline2;
  CGFloat multiplier;
  CGFloat offset;
  Float32 height1;
  Float32 height2;

  ~SpacingConstraint() {
    if (layoutGuide1) {
      removeLineHeightSpacingConstraintRef(layoutGuide1, *this);
    }
    if (layoutGuide2) {
      removeLineHeightSpacingConstraintRef(layoutGuide2, *this);
    }
  }

  void setHeight(Item item, const FirstAndLastLineHeightInfo& info) {
    const STUFirstOrLastBaseline baseline = item == Item::item1 ? baseline1 : baseline2;
    Float32 h;
    if (type == Type::lineHeightSpacing) {
      h = baseline == STUFirstBaseline ? info.firstLineHeight : info.lastLineHeight;
    } else {
      if ((type == Type::defaultSpacingBelow) == (item == Item::item1)) {
        h = baseline == STUFirstBaseline
          ? info.firstLineHeightAboveBaseline
          : info.lastLineHeight - info.lastLineHeightBelowBaseline;
      } else {
        h = baseline == STULastBaseline
          ? info.lastLineHeightBelowBaseline
          : info.firstLineHeight - info.firstLineHeightAboveBaseline;
      }
    }
    if (item == Item::item1) {
      height1 = h;
    } else {
      height2 = h;
    }
  }
};

} // namespace stu_label

/// Is attached to the NSLayoutConstraint instance as an associated object.
@interface STULabelSpacingConstraint : NSObject {
@package
  stu_label::SpacingConstraint impl;
}
@end
@implementation STULabelSpacingConstraint
@end

namespace stu_label {

class SpacingConstraintRef {
  UInt taggedPointer_;
public:
  SpacingConstraintRef(SpacingConstraint& constraint, SpacingConstraint::Item item)
  : taggedPointer_{reinterpret_cast<UInt>(&constraint) | static_cast<UInt>(item)}
  {
    static_assert(alignof(SpacingConstraint) >= 2);
  }

  SpacingConstraint& constraint() const {
    return *reinterpret_cast<SpacingConstraint*>(taggedPointer_ & ~UInt{1});
  }

  SpacingConstraint::Item item() const {
    return static_cast<SpacingConstraint::Item>(taggedPointer_ & 1);
  }
};
}

/// The topAnchor is positioned at the Y-coordinate of the first baseline, and
/// the bottomAchor is positioned at the Y-coordinate of the last baseline.
@interface STULabelBaselinesLayoutGuide : UILayoutGuide
@end
@implementation STULabelBaselinesLayoutGuide {
  NSLayoutConstraint* _firstBaselineConstraint;
  NSLayoutConstraint* _lastBaselineConstraint;
  CGFloat _firstBaseline;
  CGFloat _lastBaseline;
  CGFloat _screenScale;
  FirstAndLastLineHeightInfo _lineHeightInfo;
  stu::Vector<SpacingConstraintRef, 3> _lineHeightConstraints;
}

- (void)dealloc {
  for (auto& constraintRef : _lineHeightConstraints) {
    auto& constraint = constraintRef.constraint();
    if (constraintRef.item() == SpacingConstraint::Item::item1) {
      constraint.layoutGuide1 = nil;
    } else {
      constraint.layoutGuide2 = nil;
    }
  }
}

static void stu_label::removeLineHeightSpacingConstraintRef(
              STULabelBaselinesLayoutGuide* __unsafe_unretained self,
              const SpacingConstraint& constraint)
{
  auto& constraints = self->_lineHeightConstraints;
  for (Int i = 0; i < constraints.count(); ++i) {
    if (&constraints[i].constraint() == &constraint) {
      constraints.removeRange({i, Count{1}});
      return;
    }
  }
}

static STULabel* __nullable owningSTULabel(STULabelBaselinesLayoutGuide* __unsafe_unretained self) {
  UIView* const label = self.owningView;
  STU_CHECK_MSG([label isKindOfClass:STULabel.class],
                "STULabelBaselinesLayoutGuide must not be removed from its owning STULabel view");
  return static_cast<STULabel*>(label);
}

static
NSLayoutYAxisAnchor* firstBaselineAnchor(STULabelBaselinesLayoutGuide* __unsafe_unretained self) {
  NSLayoutYAxisAnchor* const anchor = self.topAnchor;
  if (!self->_firstBaselineConstraint) {
    STULabel* const label = owningSTULabel(self);
    self->_firstBaselineConstraint = [anchor constraintEqualToAnchor:label.topAnchor
                                                            constant:self->_firstBaseline];
    self->_firstBaselineConstraint.identifier = @"firstBaseline";
    self->_firstBaselineConstraint.active = true;
    lastBaselineAnchor(self);
  }
  return anchor;
}

static
NSLayoutYAxisAnchor* lastBaselineAnchor(STULabelBaselinesLayoutGuide* __unsafe_unretained self) {
  NSLayoutYAxisAnchor* const anchor = self.bottomAnchor;
  if (!self->_lastBaselineConstraint) {
    STULabel* const label = owningSTULabel(self);
    self->_lastBaselineConstraint = [anchor constraintEqualToAnchor:label.topAnchor
                                                           constant:self->_lastBaseline];
    self->_lastBaselineConstraint.identifier = @"lastBaseline";
    self->_lastBaselineConstraint.active = true;
    firstBaselineAnchor(self);
  }
  return anchor;
}

static void updateBaselinesLayoutGuide(STULabelBaselinesLayoutGuide* __unsafe_unretained self,
                                       CGFloat screenScale,
                                       const LabelTextFrameInfo& info)
{
  if (self->_firstBaselineConstraint && self->_firstBaseline != info.firstBaseline) {
    self->_firstBaselineConstraint.constant = info.firstBaseline;
  }
  if (self->_lastBaselineConstraint && self->_lastBaseline != info.lastBaseline) {
    self->_lastBaselineConstraint.constant = info.lastBaseline;
  }
  if (!self->_lineHeightConstraints.isEmpty()
      && (self->_lineHeightInfo != info || self->_screenScale != screenScale))
  {
    const DisplayScale scale = DisplayScale::createOrIfInvalidGetMainSceenScale(self->_screenScale);
    const FirstAndLastLineHeightInfo lineHeightInfo{info};
    for (SpacingConstraintRef& cr : self->_lineHeightConstraints) {
      SpacingConstraint& c = cr.constraint();
      c.setHeight(cr.item(), lineHeightInfo);
      c.layoutConstraint.constant = c.layoutConstantForSpacing(c.spacing(), scale);
    }
  }
  self->_firstBaseline = info.firstBaseline;
  self->_lastBaseline = info.lastBaseline;
  self->_screenScale = screenScale;
  self->_lineHeightInfo = info;
}

static const char* const spacingConstraintAssociatedObjectKey = "STULabelSpacingConstraint";

static
NSLayoutConstraint* createSpacingConstraint(SpacingConstraint::Type type,
                                            NSLayoutYAxisAnchor* __unsafe_unretained anchor,
                                            NSLayoutRelation relation,
                                            STULabel* __unsafe_unretained label,
                                            STUFirstOrLastBaseline baseline,
                                            CGFloat multiplier, CGFloat offset)
{
  if (!label) return nil;
  STULabelBaselinesLayoutGuide* const guide = baselinesLayoutGuide(label);
  NSLayoutAnchor* const labelAnchor = baseline == STUFirstBaseline
                                    ? firstBaselineAnchor(guide)
                                    : lastBaselineAnchor(guide);
  NSLayoutConstraint* constraint = nil;
  switch (relation) {
  case NSLayoutRelationLessThanOrEqual:
    constraint = [anchor constraintLessThanOrEqualToAnchor:labelAnchor];
    break;
  case NSLayoutRelationEqual:
    constraint = [anchor constraintEqualToAnchor:labelAnchor];
    break;
  case NSLayoutRelationGreaterThanOrEqual:
    constraint = [anchor constraintGreaterThanOrEqualToAnchor:labelAnchor];
    break;
  }
  if (!constraint) return nil;

  auto* const object = [[STULabelSpacingConstraint alloc] init];
  objc_setAssociatedObject(constraint, spacingConstraintAssociatedObjectKey, object,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  SpacingConstraint& c = object->impl;

  using Item = SpacingConstraint::Item;

  c.layoutConstraint = constraint;
  c.multiplier = clampFloatInput(multiplier);
  c.offset = clampFloatInput(offset);
  c.layoutGuide2 = guide;
  c.type = type;
  c.baseline2 = clampFirstOrLastBaseline(baseline);
  c.setHeight(Item::item2, guide->_lineHeightInfo);
  guide->_lineHeightConstraints.append(SpacingConstraintRef(c, Item::item2));

  const id otherItem = constraint.firstItem;
  STU_STATIC_CONST_ONCE(Class, baselinesLayoutGuideClass, STULabelBaselinesLayoutGuide.class);
  if ([otherItem isKindOfClass:baselinesLayoutGuideClass]) {
    auto* const other = static_cast<STULabelBaselinesLayoutGuide*>(otherItem);
    const auto attribute = constraint.firstAttribute;
    if (attribute == NSLayoutAttributeTop || attribute == NSLayoutAttributeBottom) {
      c.layoutGuide1 = other;
      c.baseline1 = attribute == NSLayoutAttributeTop ? STUFirstBaseline : STULastBaseline;
      c.setHeight(Item::item1, other->_lineHeightInfo);
      other->_lineHeightConstraints.append(SpacingConstraintRef(c, Item::item1));
    }
  }

  if (const CGFloat spacing = c.spacing(); spacing != 0) {
    const auto scale = DisplayScale::createOrIfInvalidGetMainSceenScale(guide->_screenScale);
    constraint.constant = c.layoutConstantForSpacing(spacing, scale);
  }

  return constraint;
}

static STULabelSpacingConstraint* __nullable spacingConstraint(NSLayoutConstraint* constraint) {
  return objc_getAssociatedObject(constraint, spacingConstraintAssociatedObjectKey);
}

static CGFloat screenScale(const SpacingConstraint& constraint) {
  return constraint.layoutGuide2 ? constraint.layoutGuide2->_screenScale
       : constraint.layoutGuide1 ? constraint.layoutGuide1->_screenScale
       : 0;
}

@end

// MARK: -

@implementation NSLayoutYAxisAnchor (STULabelLineHeightSpacing)

- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                                to:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel*)label
                        plusLineHeightMultipliedBy:(CGFloat)lineHeightMultiplier
                                              plus:(CGFloat)offset
{
  return createSpacingConstraint(SpacingConstraint::Type::lineHeightSpacing,
                                 self, relation, label, baseline, lineHeightMultiplier, offset);
}

- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                   toPositionAbove:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel *)label
                                 spacingMultiplier:(CGFloat)spacingMultiplier
                                            offset:(CGFloat)offset
{
  return createSpacingConstraint(SpacingConstraint::Type::defaultSpacingAbove,
                                 self, relation, label, baseline, spacingMultiplier, -offset);
}

- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                   toPositionBelow:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel *)label
                                 spacingMultiplier:(CGFloat)spacingMultiplier
                                            offset:(CGFloat)offset
{
  return createSpacingConstraint(SpacingConstraint::Type::defaultSpacingBelow,
                                 self, relation, label, baseline, spacingMultiplier, offset);
}

@end

@implementation NSLayoutConstraint (STULabelSpacing)

- (bool)stu_isLabelSpacingConstraint {
  return spacingConstraint(self) != nil;
}

- (CGFloat)stu_labelSpacingConstraintMultiplier {
  STULabelSpacingConstraint* const object = spacingConstraint(self);
  if (!object) return 0;
  SpacingConstraint& c = object->impl;
  return c.multiplier;
}

- (void)stu_setLabelSpacingConstraintMultiplier:(CGFloat)multiplier {
  multiplier = clampFloatInput(multiplier);
  STULabelSpacingConstraint* const object = spacingConstraint(self);
  if (!object) return;
  SpacingConstraint& c = object->impl;
  c.multiplier = multiplier;
  const auto scale = DisplayScale::createOrIfInvalidGetMainSceenScale(screenScale(c));
  self.constant = c.layoutConstantForSpacing(c.spacing(), scale);
}

- (CGFloat)stu_labelSpacingConstraintOffset {
  STULabelSpacingConstraint* const object = spacingConstraint(self);
  if (!object) return 0;
  SpacingConstraint& c = object->impl;
  return c.type == SpacingConstraint::Type::defaultSpacingAbove ? -c.offset : c.offset;
}

- (void)stu_setLabelSpacingConstraintOffset:(CGFloat)offset {
  offset = clampFloatInput(offset);
  STULabelSpacingConstraint* const object = spacingConstraint(self);
  if (!object) return;
  SpacingConstraint& c = object->impl;
  c.offset = c.type == SpacingConstraint::Type::defaultSpacingAbove ? -offset : offset;
  const auto scale = DisplayScale::createOrIfInvalidGetMainSceenScale(screenScale(c));
  self.constant = c.layoutConstantForSpacing(c.spacing(), scale);
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
    bool hasIntrinsicContentWidth : 1;
    bool maxWidthIntrinsicContentSizeIsValid : 1;
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

  self->_bits.hasIntrinsicContentWidth = true;
  self->_bits.isEnabled = true;
  self->_bits.usesTintColorAsLinkColor = true;
  self->_bits.dragInteractionEnabled = dragInteractionIsEnabledByDefault;
  self->_bits.accessibilityElementRepresentsUntruncatedText = true;
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

  // Note that [super setBounds] doesn't necessarily trigger a call to
  // labelLayerTextLayoutWasInvalidated, even when the size change invalidates the intrinsic content
  // size (when setBounds is called for a multi-line label with a larger size after the initial
  // call to intrinsicContentSize).
  if (_bits.intrinsicContentSizeIsKnownToAutoLayout && widthInvalidatesIntrinsicContentSize(self)) {
    [self invalidateIntrinsicContentSize];
  }
}

static void updateLayoutGuides(STULabel* __unsafe_unretained self) {
  if (self->_contentLayoutGuide) {
    updateContentLayoutGuide(self->_contentLayoutGuide,
                             STULabelLayerGetParams(self->_layer));
  }
  if (self->_baselinesLayoutGuide) {
    updateBaselinesLayoutGuide(self->_baselinesLayoutGuide,
                               STULabelLayerGetScreenScale(self->_layer),
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

- (bool)hasIntrinsicContentWidth {
  return _bits.hasIntrinsicContentWidth;
}
- (void)setHasIntrinsicContentWidth:(bool)hasIntrinsicContentWidth {
  if (_bits.hasIntrinsicContentWidth == hasIntrinsicContentWidth) return;
  _bits.hasIntrinsicContentWidth = hasIntrinsicContentWidth;
  [self invalidateIntrinsicContentSize];
}

- (CGSize)intrinsicContentSize {
  CGFloat layoutWidth = STULabelLayerGetSize(_layer).width;
  const bool useMaxLayoutWidth = STULabelLayerGetMaximumNumberOfLines(_layer) == 1
                              || !(layoutWidth > 0); // Optimization for newly created label views.
  if (!_bits.maxWidthIntrinsicContentSizeIsValid
      && (useMaxLayoutWidth || _bits.hasIntrinsicContentWidth))
  {
    // We can't use an arbitrarily large width here, because paragraphs may be right-aligned and
    // the spacing between floating-point numbers increases with their magnitude.
    _maxWidthIntrinsicContentSize = [_layer sizeThatFits:CGSize{max(CGFloat(1 << 14), layoutWidth),
                                                                maxValue<CGFloat>}];
    _bits.maxWidthIntrinsicContentSizeIsValid = true;
  }
  CGSize size;
  if (useMaxLayoutWidth || (_bits.maxWidthIntrinsicContentSizeIsValid
                            && layoutWidth >= _maxWidthIntrinsicContentSize.width))
  {
    // If maximumNumberOfLines == 1 and layoutWidth < _maxWidthIntrinsicContentSize.width, the text
    // truncation could increase the typographic height if the truncation token has a line height
    // larger than the main text, but supporting such odd formatting doesn't seem worth the slow
    // down of intrinsicContentSize for single line labels.
    // Similarly, if the final layout width actually is 0 and the label is not empty, the intrinsic
    // height calculated here likely isn't large enough, but in that case the layout is broken
    // anyway.
    layoutWidth = _maxWidthIntrinsicContentSize.width;
    size = _maxWidthIntrinsicContentSize;
  } else {
    size = [_layer sizeThatFits:CGSize{layoutWidth, maxValue<CGFloat>}];
    if (_bits.hasIntrinsicContentWidth) {
      STU_DEBUG_ASSERT(_bits.maxWidthIntrinsicContentSizeIsValid);
      size.height = max(size.height, _maxWidthIntrinsicContentSize.height);
      size.width = _maxWidthIntrinsicContentSize.width;
    }
  }
  if (_bits.isUpdatingConstraints) {
    _bits.intrinsicContentSizeIsKnownToAutoLayout = true;
    _layoutWidthForIntrinsicContentSizeKnownToAutoLayout = layoutWidth;
    if (size.height == _intrinsicContentSizeKnownToAutoLayout.height
        && (!_bits.hasIntrinsicContentWidth
            || size.width == _intrinsicContentSizeKnownToAutoLayout.width))
    {
      _bits.waitingForPossibleSetBoundsCall = false;
    }
    _intrinsicContentSizeKnownToAutoLayout = size;
  }
  if (!_bits.hasIntrinsicContentWidth) {
    size.width = UIViewNoIntrinsicMetric;
  }
  return size;
}

/// @pre intrinsicContentSizeIsKnownToAutoLayout
static bool widthInvalidatesIntrinsicContentSize(STULabel* __unsafe_unretained self) {
  STU_DEBUG_ASSERT(self->_bits.intrinsicContentSizeIsKnownToAutoLayout);
  if (STULabelLayerGetMaximumNumberOfLines(self->_layer) == 1) return false;
  const CGFloat width = STULabelLayerGetSize(self->_layer).width;
  return width > self->_layoutWidthForIntrinsicContentSizeKnownToAutoLayout
      || width < min(self->_layoutWidthForIntrinsicContentSizeKnownToAutoLayout,
                     self->_intrinsicContentSizeKnownToAutoLayout.width);
}

- (void)invalidateIntrinsicContentSize {
  if (_bits.intrinsicContentSizeIsKnownToAutoLayout) {
    _bits.intrinsicContentSizeIsKnownToAutoLayout = false;
    _bits.waitingForPossibleSetBoundsCall = true; // See the comment in layoutSubviews.
  }
  [super invalidateIntrinsicContentSize];
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
    _bits.maxWidthIntrinsicContentSizeIsValid = false;
  }
  if (_bits.intrinsicContentSizeIsKnownToAutoLayout && !_bits.isSettingBounds) {
    [self invalidateIntrinsicContentSize];
  }
  if (_bits.delegateRespondsToTextLayoutWasInvalidated) {
    [_delegate labelTextLayoutWasInvalidated:self];
  }
}

- (UILayoutGuide*)contentLayoutGuide {
  if (!_contentLayoutGuide) {
    _contentLayoutGuide = [[STULabelContentLayoutGuide alloc] init];
    initContentLayoutGuide(_contentLayoutGuide, self);
    [self setNeedsUpdateConstraints];
  }
  return _contentLayoutGuide;
}

static STULabelBaselinesLayoutGuide* baselinesLayoutGuide(STULabel* __unsafe_unretained self) {
  if (!self->_baselinesLayoutGuide) {
    self->_baselinesLayoutGuide = [[STULabelBaselinesLayoutGuide alloc] init];
    [self addLayoutGuide:self->_baselinesLayoutGuide];
    [self setNeedsUpdateConstraints];
  }
  return self->_baselinesLayoutGuide;
}

- (NSLayoutYAxisAnchor*)firstBaselineAnchor {
  return firstBaselineAnchor(baselinesLayoutGuide(self));
}

- (NSLayoutYAxisAnchor*)lastBaselineAnchor {
  return lastBaselineAnchor(baselinesLayoutGuide(self));
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
    STUTextLinkArray* const links = _layer.links;
    const id<STULabelDelegate> delegate = _delegate;
    const bool delegateRespondsToLinkCanBeDragged = _bits.delegateRespondsToLinkCanBeDragged;
    const bool delegateRespondsToDragItemForLink = _bits.delegateRespondsToDragItemForLink;

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
                          if (!delegateRespondsToLinkCanBeDragged
                              && !delegateRespondsToDragItemForLink)
                          {
                            return isDefaultDraggableLinkValue(linkValue);
                          }
                          if (STUTextLink* const link = [links linkClosestToPoint:point
                                                                      maxDistance:0])
                          {
                            STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
                            if (delegateRespondsToLinkCanBeDragged) {
                              return [delegate label:self link:link canBeDraggedFromPoint:point];
                            } else {
                              return [delegate label:self dragItemForLink:link] != nil;
                            }
                            STU_REENABLE_CLANG_WARNING
                          }
                          return false;
                        }
                  linkActivationHandler:^bool(STUTextRange range, id linkValue, CGPoint point)
                        {
                          STUTextLink* link = [links linkClosestToPoint:point maxDistance:0];
                          if (range.type == STURangeInOriginalString
                              && (!link || link.rangeInOriginalString != range.range))
                          { // The truncated string does not contain this link.
                            link = [[STUTextLink alloc]
                                      initWithLinkAttributeValue:linkValue
                                           rangeInOriginalString:range.range
                                          rangeInTruncatedString:
                                            STUTextFrameRangeGetRangeInTruncatedString(
                                              [textFrame rangeForRangeInOriginalString:range.range])
                                                   textRectArray:nil];
                          }
                          if (!link) return false;
                          [self stu_link:link wasTappedAtPoint:point];
                          return true;
                        }
       ];
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
#if !TARGET_OS_MACCATALYST
  if (@available(iOS 10, *)) {
#endif
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
       if (!success) {
       #if STU_DEBUG
         NSLog(@"Failed to open URL %@", url);
       #else
         NSLog(@"Failed to open URL");
       #endif
       }
     }];
#if !TARGET_OS_MACCATALYST
  } else {
    [UIApplication.sharedApplication openURL:url];
  }
#endif
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

#if TARGET_OS_MACCATALYST
// SafariServices are not available with Catalyst.
#else
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
#endif

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
    return url.absoluteString.stringByRemovingPercentEncoding;
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
             copyAction(localized(@"Copy"), url.absoluteString),
             shareAction(localized(@"Share…"), url, presentingViewController, self, link),
           #if TARGET_OS_MACCATALYST
             // SafariServices are not available with Catalyst.
           #else
             addToReadingListAction(localized(@"Add to Reading List"), url),
           #endif
             ];
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
  const CGPoint point = [touch locationInView:self];
  STUTextLink* const link = [_layer.links linkClosestToPoint:point
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
  [self stu_link:link wasTappedAtPoint:point];
}

- (void)stu_link:(STUTextLink*)link wasTappedAtPoint:(CGPoint)point {
  if (_bits.delegateRespondsToLinkWasTapped) {
    [_delegate label:self link:link wasTappedAtPoint:point];
  } else if (NSURL* const url = urlLinkAttribute(link)) {
    openURL(url);
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer {
  if (gestureRecognizer == _longPressGestureRecognizer) {
    if (_ghostingMaskLayer) return false;
    STUTextLink* const link = self.activeLink;
    if (!link) return false;
    return !_bits.delegateRespondsToLinkCanBeLongPressed
        || [_delegate label:self link:link
              canBeLongPressedAtPoint:[_longPressGestureRecognizer locationInView:self]];
  }
  if ([gestureRecognizer isKindOfClass:UITapGestureRecognizer.class]
      // We need to allow _UIDragAddItemsGesture here (and possibly other recognizers too).
      && strncmp(object_getClassName(gestureRecognizer), "_UI", 3) != 0
      && [_layer.links linkClosestToPoint:[gestureRecognizer locationInView:self]
                              maxDistance:_linkTouchAreaExtensionRadius])
  {
    return false;
  }
  return true;
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

static UIViewController* ancestorViewController(UIView* const view) {
  STU_STATIC_CONST_ONCE(Class, viewControllerClass, UIViewController.class);
  UIResponder* r = view;
  while ((r = r.nextResponder)) {
    if ([r isKindOfClass:viewControllerClass]) {
      return static_cast<UIViewController*>(r);
    }
  }
  return nil;
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
    [self stu_presentActionSheetForLink:link fromViewController:ancestorViewController(self)];
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
      attachmentBounds = attachment.typographicBounds;
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
    drawLabelTextFrame(textFrame, range, drawingOrigin, context, ContextBaseCTM_d{0},
                       PixelAlignBaselines{true}, drawingOptions, drawingBlock,
                       cancellationFlag);
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
         .contains(rangeInTruncatedString)
      && highlightStyle.background)
  {
    backgroundColor = highlightStyle.background.color; // May be nil.
  } else if (attributes) {
    id bg = attributes[STUBackgroundAttributeName];
    const bool isBackground = bg != nil;
    if (!isBackground) {
      bg = attributes[NSBackgroundColorAttributeName];
    }
    if (bg) {
      NSRange attributeRange;
      [textFrame.truncatedAttributedString attribute:(isBackground ? STUBackgroundAttributeName
                                                                   : NSBackgroundColorAttributeName)
                                             atIndex:rangeInTruncatedString.location
                               longestEffectiveRange:&attributeRange
                                             inRange:rangeInTruncatedString];
      if (attributeRange.length >= rangeInTruncatedString.length) {
        backgroundColor = isBackground ? static_cast<STUBackgroundAttribute*>(bg).color
                        : static_cast<UIColor*>(bg);
      }
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
  _layer.drawingBlock = drawingBlock;
}

- (STULabelDrawingBlockColorOptions)drawingBlockColorOptions {
  return _layer.drawingBlockColorOptions;
}
- (void)setDrawingBlockColorOptions:(STULabelDrawingBlockColorOptions)colorOptions {
  _layer.drawingBlockColorOptions = colorOptions;
}

- (STULabelDrawingBounds)drawingBlockImageBounds {
  return _layer.drawingBlockImageBounds;
}
- (void)setDrawingBlockImageBounds:(STULabelDrawingBounds)drawingBounds {
  _layer.drawingBlockImageBounds = drawingBounds;
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
  _layer.text = text;
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

- (STUShapedString*)shapedText {
  return _layer.shapedText;
}
- (void)setShapedText:(STUShapedString*)shapedText {
  _layer.shapedText = shapedText;
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

- (NSInteger)maximumNumberOfLines {
  return _layer.maximumNumberOfLines;
}
- (void)setMaximumNumberOfLines:(NSInteger)maximumNumberOfLines {
  _layer.maximumNumberOfLines = maximumNumberOfLines;
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
  const LabelParameters& params = STULabelLayerGetParams(_layer);
  UIColor* const overrideTextColor = params.overrideTextColor().unretained;
  UIColor* const overrideLinkColor = params.overrideLinkColor().unretained;
  [_layer configureWithPrerenderer:prerenderer];
  if (!equal(params.overrideTextColor().unretained, overrideTextColor)) {
    _layer.overrideTextColor = overrideTextColor;
  }
  if (!equal(params.overrideLinkColor().unretained, overrideLinkColor)) {
    _layer.overrideLinkColor = overrideLinkColor;
  }
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
  STULabel* const label = self.label;
  STUTextLink* const link = [label.links linkMatchingLink:self.mostRecentNonNullLink];
  if (!link) return;
  *rect = popoverSourceRect(label, link);
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
