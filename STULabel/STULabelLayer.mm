// Copyright 2016–2018 Stephan Tolksdorf

#import "STULabelLayer-Internal.hpp"
#import "STULabelSwiftExtensions.h"

#import "STUMainScreenProperties.h"

#import "STULabelDrawingBlock-Internal.hpp"
#import "STULabelLayoutInfo-Internal.hpp"
#import "STULabelPrerenderer-Internal.hpp"
#import "STUTextFrameOptions-Internal.hpp"
#import "STUTextFrame-Internal.hpp"
#import "STUTextLink-Internal.hpp"

#import "Internal/CoreAnimationUtils.hpp"
#import "Internal/CoreGraphicsUtils.hpp"
#import "Internal/Equal.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/LabelPrerenderer.hpp"
#import "Internal/LabelRenderTask.hpp"
#import "Internal/LabelRendering.hpp"
#import "Internal/Once.hpp"
#import "Internal/ShapedString.hpp"
#import "Internal/STULabelTiledLayer.h"
#import "Internal/TextFrame.hpp"

#import <objc/runtime.h>

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

@interface STULabelImageContentLayer : STULayerWithNullDefaultActions
@end
@implementation STULabelImageContentLayer

- (void)display {
  // CoreAnimation will call this method when a CABackingStore that we had moved from the parent
  // STULabelLayer into this layer has been purged while the app was in the background.
  [self.superlayer setNeedsDisplay];
}
@end

typedef void (* LabelLayerDelegateMethod)(NSObject<STULabelLayerDelegate>* __nonnull,
                                          __nonnull SEL, STULabelLayer* __nonnull);

typedef bool (* LabelLayerShouldDisplayAsyncMethod)
                 (NSObject<STULabelLayerDelegate>* __nonnull, __nonnull SEL,
                  STULabelLayer* __nonnull, bool);

typedef void (* LabelLayerDidDisplayTextMethod)
                 (NSObject<STULabelLayerDelegate>* __nonnull, __nonnull SEL,
                  STULabelLayer* __nonnull, STUTextFrameFlags, CGRect);

typedef void (* LabelLayerDidMoveDisplayedTextMethod)
                (NSObject<STULabelLayerDelegate>* __nonnull, __nonnull SEL,
                 STULabelLayer* __nonnull, CGRect);

namespace stu_label {
  enum class InvalidatedStringAttributes : uint8_t {
    string        = 1 << 0,
    font          = 1 << 1,
    textColor     = 1 << 2,
    textAlignment = 1 << 3
  };

  enum class LayerHasWindowStatus : uint8_t {
    unknown = 0,
    noWindow = 1,
    hasWindow = 2
  };
}
template <> struct stu::IsOptionsEnum<stu_label::InvalidatedStringAttributes> : stu::True {};

constexpr STUPredefinedCGImageFormat unknownCGImageFormat =
  STUPredefinedCGImageFormat{1 << STUPredefinedCGImageFormatBitSize};

namespace stu_label {

/// Must be zero-initialized.
class LabelLayer : public LabelPropertiesCRTPBase<LabelLayer> {
  friend LabelPropertiesCRTPBase<LabelLayer>;
  friend LabelRenderTask;
  friend LabelPrerenderer::WaitingLabelSetNode;

  STULabelLayer* __unsafe_unretained self;

  bool isInvalidated_;
  bool hasContent_;
  bool textFrameInfoIsValidForCurrentSize_;
  bool taskIsStale_;
  bool textFrameOptionsIsPrivate_;
  bool stringIsEmpty_;
  bool displaysAsynchronously_;
  bool prefersSynchronousDrawingForNextDisplay_;

  STUDisplayGamut screenDisplayGamut_ : 8;
  InvalidatedStringAttributes invalidatedStringAttributes_;
  LabelRenderMode renderMode_ : LabelRenderModeBitSize;
  STUPredefinedCGImageFormat imageFormat_ : STUPredefinedCGImageFormatBitSize;
                                                    // +1 for unknownCGImageFormat
  STUPredefinedCGImageFormat layerContentsFormat_ : STUPredefinedCGImageFormatBitSize + 1;
  LayerHasWindowStatus hasWindowStatus_ : 2;
  bool contentInsetsAreDirectional_ : 1;
  bool layerIsOpaque_ : 1;
  bool layerHasBackgroundColor_ : 1;
  bool contentLayerClipsToBounds_ : 1;
  bool contentHasBackgroundColor_ : 1;
  bool contentMayBeClipped_ : 1;
  bool contentsIsNotNil_ : 1;
  bool isRegisteredAsLayerThatMayHaveImage_ : 1;
  bool imageMayHaveBeenPurged_ : 1;

  LabelLayer* previousLayerThatHasImage_;
  LabelLayer* nextLayerThatHasImage_;

  CGSize size_;
  UIEdgeInsets contentInsets_;
  LabelParameters params_;
  CGFloat screenScale_{0};
  DisplayScale sizeThatFitsDisplayScale_{DisplayScale::one()};

  /// May be an invalid pointer.
  NSString* __unsafe_unretained layerContentsGravity_doNotDereference_;

  LabelLayerShouldDisplayAsyncMethod shouldDisplayAsyncMethod_;
  LabelLayerDidDisplayTextMethod didDisplayTextMethod_;
  LabelLayerDidMoveDisplayedTextMethod didMoveDisplayedTextMethod_;
  LabelLayerDelegateMethod textLayoutWasInvalidatedMethod_;

  LabelTextFrameInfo textFrameInfo_;
  CGPoint textFrameOrigin_;
  LabelTextFrameInfo measuringTextFrameInfo_;

  /// The bounds of the drawn content within the text frame.
  CGRect contentBoundsInTextFrame_;

  STUTextFrameOptions* textFrameOptions_;

  NSObject<STULabelLayerDelegate>* __weak labelLayerDelegate_;

  NSString* string_;
  UIFont* font_;
  UIColor* textColor_;
  NSTextAlignment textAlignment_;
  NSDictionary<NSAttributedStringKey, id>* cachedAttributesDictionary_;

  NSAttributedString* attributedString_;

  STUShapedString* shapedString_;

  STUTextFrame* textFrame_;
  STUTextFrame* measuringTextFrame_;
  CALayer* contentLayer_;

  LabelRenderTask* task_;
  LabelPrerenderer::WaitingLabelSetNode waitingSetNode_;

  STUTextLinkArrayWithTextFrameOrigin* links_;

  PurgeableImage image_;

  friend const CGSize& ::STULabelLayerGetSize(const STULabelLayer*);

public:
  void init(STULabelLayer* __unsafe_unretained thisSelf) {
    this->self = thisSelf;
    params_.defaultBaseWritingDirection = stu_defaultBaseWritingDirection();
    textFrameOptions_ = defaultLabelTextFrameOptions().unretained;
    STU_CHECK(textFrameOptions_ != nil);
    layerIsOpaque_ = false;
    stringIsEmpty_ = true;
    textAlignment_ = NSTextAlignmentNatural;

    layerContentsGravity_doNotDereference_ = kCAGravityBottomLeft;
    super_setContentsGravity(kCAGravityBottomLeft);

    params_.setDisplayScale_assumingSizeAndEdgeInsetsAreAlreadyCorrectlyRounded(
              *DisplayScale::create(stu_mainScreenScale()));
    sizeThatFitsDisplayScale_ = params_.displayScale();
    super_setContentsScale(params_.displayScale());

    isInvalidated_ = true;
    [self setNeedsDisplay];
  }

  STU_INLINE_T const LabelParameters& params() const { return params_; }

  void checkNotFrozen() {
    // do nothing
  }

  ~LabelLayer() {
    STU_ASSERT(is_main_thread());
    removeTask();
    deregisterAsLabelLayerThatHasImage();
  }

  /// MARK: - hasWindow and screen scale

  void didMoveToWindow(UIWindow* window) {
    hasWindowStatus_ = window ? LayerHasWindowStatus::hasWindow : LayerHasWindowStatus::noWindow;
    if (window && displaysAsynchronously_ && !hasContent_ && inUIViewAnimation()) {
      prefersSynchronousDrawingForNextDisplay_ = true;
    }
    updateScreenProperties(window ? window : nil);
  }

private:
  bool hasWindow() const {
    if (hasWindowStatus_ != LayerHasWindowStatus::unknown) {
      return hasWindowStatus_ == LayerHasWindowStatus::hasWindow;
    }
    return window(self) != nil;
  }

  void updateScreenProperties(UIWindow* __unsafe_unretained window) {
    if (UIScreen* const screen = window.screen) {
      screenScale_ = screen.scale;
      if (@available(iOS 10, tvOS 10, *)) {
        screenDisplayGamut_ = static_cast<STUDisplayGamut>(screen.traitCollection.displayGamut);
      }
    } else {
      screenScale_ = 0;
      screenDisplayGamut_ = STUDisplayGamutUnspecified;
    }
  }
  void updateScreenProperties() {
    if (hasWindowStatus_ == LayerHasWindowStatus::noWindow) return;
    updateScreenProperties(window(self));
  }

public:
  CGFloat screenScale() const { return screenScale_; }

  /// MARK: - STULabelLayerDelegate

  NSObject<STULabelLayerDelegate>* delegate() const {
    return labelLayerDelegate_;
  }

  void setDelegate(NSObject<STULabelLayerDelegate>* delegate) {
    if (delegate) {
      labelLayerDelegate_ = delegate;
      SEL sel = @selector(labelLayer:shouldDisplayAsynchronouslyWithProposedValue:);
      shouldDisplayAsyncMethod_ = ![delegate respondsToSelector:sel] ? nil
                                : (LabelLayerShouldDisplayAsyncMethod)[delegate methodForSelector:sel];

      sel = @selector(labelLayer:didDisplayTextWithFlags:inRect:);
      didDisplayTextMethod_ = ![delegate respondsToSelector:sel] ? nil
                            : (LabelLayerDidDisplayTextMethod)[delegate methodForSelector:sel];

      sel = @selector(labelLayer:didMoveDisplayedTextToRect:);
      didMoveDisplayedTextMethod_ =
        ![delegate respondsToSelector:sel] ? nil
        : (LabelLayerDidMoveDisplayedTextMethod)[delegate methodForSelector:sel];

      sel = @selector(labelLayerTextLayoutWasInvalidated:);
      textLayoutWasInvalidatedMethod_ = ![delegate respondsToSelector:sel] ? nil
                                        : (LabelLayerDelegateMethod)[delegate methodForSelector:sel];
    } else {
      labelLayerDelegate_ = nil;
      shouldDisplayAsyncMethod_ = nil;
      didDisplayTextMethod_ = nil;
      didMoveDisplayedTextMethod_ = nil;
      textLayoutWasInvalidatedMethod_ = nil;
    }
  }

private:
  bool shouldDisplayAsync(NSObject<STULabelLayerDelegate>* delegate, bool proposedValue) {
    if (delegate && shouldDisplayAsyncMethod_) {
      return shouldDisplayAsyncMethod_(
               delegate, @selector(labelLayer:shouldDisplayAsynchronouslyWithProposedValue:),
               self, proposedValue);
    }
    return proposedValue;
  }

  void didDisplayText(NSObject<STULabelLayerDelegate>* delegate) {
    if (!delegate || !didDisplayTextMethod_) return;
    didDisplayTextMethod_(delegate, @selector(labelLayer:didDisplayTextWithFlags:inRect:),
                          self, textFrameInfo_.flags, contentBounds());
  }

  void didMoveDisplayedText(NSObject<STULabelLayerDelegate>* delegate) {
    if (!delegate || !didMoveDisplayedTextMethod_) return;
    didMoveDisplayedTextMethod_(delegate, @selector(labelLayer:didMoveDisplayedTextToRect:),
                                self, contentBounds());
  }

  void textLayoutWasInvalidated(NSObject<STULabelLayerDelegate>* delegate) {
    if (!delegate || !textLayoutWasInvalidatedMethod_) return;
    textLayoutWasInvalidatedMethod_(delegate, @selector(labelLayerTextLayoutWasInvalidated:),
                                    self);
  }

private:

  /// MARK: - Superclass method call helpers

  Unretained<__nonnull Class> stuLabelLayerSuperClass() {
    STU_STATIC_CONST_ONCE_PRESERVE_MOST(Class, value, STULabelLayer.superclass);
    return value;
  }

  void super_display() {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL)>(objc_msgSendSuper)
                    (&super, @selector(display));
    contentsIsNotNil_ = true;
  }

  void super_setBackgroundColor(CGColor* color) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, CGColorRef)>(objc_msgSendSuper)
                    (&super, @selector(setBackgroundColor:), color);
  }

  void super_setBounds(CGRect bounds) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, CGRect)>(objc_msgSendSuper)
                    (&super, @selector(setBounds:), bounds);
  }

  void super_setContentsFormat(NSString* __unsafe_unretained format) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, NSString*)>(objc_msgSendSuper)
                    (&super, @selector(setContentsFormat:), format);
  }

  void super_setContentsGravity(NSString* __unsafe_unretained gravity) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, NSString*)>(objc_msgSendSuper)
                    (&super, @selector(setContentsGravity:), gravity);
  }

  void super_setContentsScale(CGFloat scale) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, CGFloat)>(objc_msgSendSuper)
                    (&super, @selector(setContentsScale:), scale);
  }

  void super_setOpaque(BOOL value) {
    objc_super super{self, stuLabelLayerSuperClass().unretained};
    reinterpret_cast<void (*)(objc_super*, SEL, BOOL)>(objc_msgSendSuper)
                    (&super, @selector(setOpaque:), value);
  }

  /// MARK: - Text properties
public:
  bool isAttributed() const {
    return string_ == nil && attributedString_ != nil;
  }

  NSString* text() const {
    return string_ ?: (attributedString_ ? attributedString_.string : @"");
  }
  void setText(NSString* __unsafe_unretained __nullable string) {
    if (string == string_ || [string isEqualToString:string_]) return;
    const bool needToCopyAttributes = string_ == nil && attributedString_ != nil;
    string_ = [string copy];
    if (needToCopyAttributes) {
      NSDictionary<NSAttributedStringKey, id>* const attributes =
        stringIsEmpty_ ? nil : [attributedString_ attributesAtIndex:0 effectiveRange:nil];
      if (!font_) {
        font_ = [attributes objectForKey:NSFontAttributeName]
                ?: (__bridge UIFont*)defaultCoreTextFont();
      }
      if (!textColor_) {
        textColor_ = [attributes objectForKey:NSForegroundColorAttributeName];
      }
      if (textAlignment_ == NSTextAlignment{-1}) {
        if (NSParagraphStyle* const style = [attributes objectForKey:NSParagraphStyleAttributeName]) {
          textAlignment_ = clampTextAlignment(style.alignment);
        } else {
          textAlignment_ = NSTextAlignmentNatural;
        }
      }
      cachedAttributesDictionary_ = nil;
    }
    attributedString_ = nil;
    stringIsEmpty_ = string_ == nil || string_.length == 0;
    invalidatedStringAttributes_ |= InvalidatedStringAttributes::string;
    invalidateShapedString();
  }

private:
  STU_NO_INLINE
  static Unretained<UIFont* __nonnull> defaultFont() {
    STU_STATIC_CONST_ONCE(UIFont*, value, [[UILabel alloc] init].font);
    STU_ANALYZER_ASSUME(value != nil);
    return value;
  }

public:
  UIFont* font() {
    if (font_) {
      return font_;
    }
    if (stringIsEmpty_ || string_) {
      return defaultFont().unretained;
    }
    if (UIFont* const font = [[attributedString_ attributesAtIndex:0 effectiveRange:nil]
                                objectForKey:NSFontAttributeName])
    {
      return font;
    }
    return (__bridge UIFont*)defaultCoreTextFont();
  }
  void setFont(UIFont* __unsafe_unretained font) {
    if (!font) {
      font = defaultFont().unretained;
    }
    if (font == font_) return;
    font_ = font;
    invalidatedStringAttributes_ |= InvalidatedStringAttributes::font;
    if (cachedAttributesDictionary_) {
      cachedAttributesDictionary_ = nil;
    }
    invalidateShapedString();
  }

  UIColor* textColor() const {
    if (textColor_) {
      return textColor_;
    }
    if (!stringIsEmpty_ && attributedString_ && !string_) {
      if (UIColor* const color = [[attributedString_ attributesAtIndex:0 effectiveRange:nil]
                                    objectForKey:NSForegroundColorAttributeName])
      {
        return color;
      }
    }
    return UIColor.blackColor;
  }
  void setTextColor(UIColor* __unsafe_unretained textColor) {
    if (textColor == textColor_) return;
    textColor_ = textColor;
    invalidatedStringAttributes_ |= InvalidatedStringAttributes::textColor;
    if (cachedAttributesDictionary_) {
      cachedAttributesDictionary_ = nil;
    }
    invalidateShapedString();
  }

  NSTextAlignment textAlignment() const {
    if (textAlignment_ != NSTextAlignment{-1}) {
      return textAlignment_;
    }
    if (!stringIsEmpty_ && attributedString_ && !string_) {
      if (NSParagraphStyle* const style = [[attributedString_ attributesAtIndex:0 effectiveRange:nil]
                                             objectForKey:NSParagraphStyleAttributeName])
      {
        return style.alignment;
      }
    }
    return NSTextAlignmentNatural;
  }
  void setTextAlignment(NSTextAlignment textAlignment) {
    textAlignment = clampTextAlignment(textAlignment);
    if (textAlignment == textAlignment_) return;
    textAlignment_ = textAlignment;
    invalidatedStringAttributes_ |= InvalidatedStringAttributes::textAlignment;
    if (cachedAttributesDictionary_) {
      cachedAttributesDictionary_ = nil;
    }
    invalidateShapedString();
  }

  NSAttributedString* attributedText() {
    updateAttributedStringIfNecessary();
    return attributedString_ ?: stu_emptyAttributedString();
  }
  void setAttributedText(NSAttributedString* __unsafe_unretained attributedString) {
    if (attributedString == attributedString_) return;
    attributedString_ = [attributedString copy];
    stringIsEmpty_ = attributedString_ == nil || attributedString_.length == 0;
    clearStringProperties();
    invalidateShapedString();
  }

private:
  STU_NO_INLINE
  void clearStringProperties() {
    invalidatedStringAttributes_ = InvalidatedStringAttributes{};
    if (string_) {
      string_ = nil;
    }
    if (font_) {
      font_ = nil;
    }
    if (textColor_) {
      textColor_  = nil;
    }
    if (cachedAttributesDictionary_) {
      cachedAttributesDictionary_ = nil;
    }
    textAlignment_ = NSTextAlignment{-1};
  }


  static STU_NO_INLINE
  Unretained<NSParagraphStyle* __nonnull> defaultParagraphStyle(NSTextAlignment textAlignment) {
    const UInt n = 5;
    static std::atomic<CFTypeRef> styles[n];
    const UInt index = static_cast<UInt>(textAlignment);
    STU_CHECK(index < n);
    if (CFTypeRef const style = styles[index].load(std::memory_order_acquire)) {
      return (__bridge NSMutableParagraphStyle*)style;
    }

    NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = textAlignment;
    paragraphStyle = [paragraphStyle copy];

    CFTypeRef style = nullptr;
    if (styles[index].compare_exchange_strong(style, (__bridge CFTypeRef)paragraphStyle,
                                              std::memory_order_release, std::memory_order_acquire))
    {
      incrementRefCount(paragraphStyle);
      return paragraphStyle;
    } else {
      return (__bridge NSParagraphStyle*)style;
    }
  }

  void updateAttributedStringIfNecessary() {
    if (!!invalidatedStringAttributes_) {
      updateAttributedString();
    }
  }
  STU_NO_INLINE
  void updateAttributedString() {
    const auto invalidatedAttributes = invalidatedStringAttributes_;
    invalidatedStringAttributes_ = InvalidatedStringAttributes{};
    if (STU_UNLIKELY(stringIsEmpty_)) return;
    if (cachedAttributesDictionary_) {
      STU_DEBUG_ASSERT(invalidatedAttributes == InvalidatedStringAttributes::string);
      attributedString_ = [[NSAttributedString alloc]
                             initWithString:string_ attributes:cachedAttributesDictionary_];
      return;
    }
    const auto textAlignment = textAlignment_ == NSTextAlignment{-1}
                             ? NSTextAlignmentNatural : textAlignment_;
    NSParagraphStyle* __unsafe_unretained const defaultParaStyle =
                                                  textAlignment == NSTextAlignmentNatural ? nil
                                                  : defaultParagraphStyle(textAlignment).unretained;
    if (string_) {
      UIFont* __unsafe_unretained font = font_ ?: defaultFont().unretained;
      NSDictionary<NSAttributedStringKey, id>* attributes;
      if (!defaultParaStyle) {
        if (!textColor_) {
          attributes = @{NSFontAttributeName: font};
        } else {
          attributes = @{NSFontAttributeName: font,
                         NSForegroundColorAttributeName: textColor_};
        }
      } else {
        if (!textColor_) {
          attributes = @{NSFontAttributeName: font,
                         NSParagraphStyleAttributeName: defaultParaStyle};
        } else {
          attributes = @{NSFontAttributeName: font,
                         NSParagraphStyleAttributeName: defaultParaStyle,
                         NSForegroundColorAttributeName: textColor_};
        }
      }
      attributedString_ = [[NSAttributedString alloc] initWithString:string_
                                                               attributes:attributes];
      cachedAttributesDictionary_ = [attributedString_ attributesAtIndex:0 effectiveRange:nullptr];
    } else if (!stringIsEmpty_) {
      NSMutableAttributedString* const attributedString = [attributedString_ mutableCopy];
      [attributedString enumerateAttributesInRange:NSRange{0, attributedString_.length}
           options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
        usingBlock:^(NSDictionary<NSAttributedStringKey, id>* const __unsafe_unretained attributes,
                     NSRange range, BOOL*)
      {
        if (invalidatedAttributes & InvalidatedStringAttributes::font) {
          [attributedString addAttribute:NSFontAttributeName value:font_ range:range];
        }
        if (invalidatedAttributes & InvalidatedStringAttributes::textColor) {
          if (textColor_) {
            [attributedString addAttribute:NSForegroundColorAttributeName value:textColor_
                                     range:range];
          } else {
            [attributedString removeAttribute:NSForegroundColorAttributeName range:range];
          }
        }
        if (invalidatedAttributes & InvalidatedStringAttributes::textAlignment) {
          NSParagraphStyle* const style = [attributes objectForKey:NSParagraphStyleAttributeName];
          if (style) {
            if (style.alignment != textAlignment) {
              NSMutableParagraphStyle* const mutableStyle = [style mutableCopy];
              mutableStyle.alignment = textAlignment;
              [attributedString addAttribute:NSParagraphStyleAttributeName value:mutableStyle
                                       range:range];
            }
          } else if (defaultParaStyle) {
            [attributedString addAttribute:NSParagraphStyleAttributeName value:defaultParaStyle
                                     range:range];
          }
        }
      }];
      attributedString_ = [attributedString copy];
    }
  }

public:
  Unretained<STUShapedString* __nonnull> shapedText() {
    if (!shapedString_) {
      if (stringIsEmpty_) {
        return emptyShapedString(params_.defaultBaseWritingDirection);
      }
      updateAttributedStringIfNecessary();
      shapedString_ = STUShapedStringCreate(nil, attributedString_,
                                            params_.defaultBaseWritingDirection, nullptr);
    }
    return shapedString_;
  }
  void setShapedText(STUShapedString* __unsafe_unretained __nullable shapedString) {
    if (shapedString == shapedString_) {
      if (shapedString != nil) return;
      // Assigning nil to the shapedText property should force invalidation.
    } else {
      shapedString_ = shapedString;
      attributedString_ = shapedString ? shapedString->shapedString->attributedString : nil;
      stringIsEmpty_ = attributedString_ == nil || attributedString_.length == 0;
      clearStringProperties();
    }
    invalidateLayout();
  }

  /// MARK: - Size, content insets and vertical alignment
private:
  void setContentInsets(bool directional, UIEdgeInsets contentInsets) {
    contentInsetsAreDirectional_ = directional;
    contentInsets = clampNonNegativeEdgeInsetsInput(contentInsets);
    if (!UIEdgeInsetsEqualToEdgeInsets(contentInsets, contentInsets_)) {
      contentInsets_ = contentInsets;
      const auto changeStatus = params_.setEdgeInsets(contentInsets);
      if (!!changeStatus) {
        sizeOrEdgeInsetsChanged(changeStatus);
      }
    }
  }

public:
  void setContentInsets(UIEdgeInsets contentInsets) {
    setContentInsets(false, contentInsets);
  }

  void setDirectionalContentInsets(STUDirectionalEdgeInsets directionalInsets) {
    setContentInsets(true, edgeInsets(directionalInsets, params_.defaultBaseWritingDirection));
  }

  void setBounds(CGRect bounds) {
    STU_ASSERT(is_main_thread());
    bounds = clampRectInput(bounds);
    super_setBounds(bounds);
    size_ = CGSize{max(0.f, min(0.f, bounds.origin.x) + bounds.size.width),
                   max(0.f, min(0.f, bounds.origin.y) + bounds.size.height)};
    const auto status = params_.setSizeAndIfChangedUpdateEdgeInsets(size_, contentInsets_);
    if (!status) return;
    sizeOrEdgeInsetsChanged(status);
  }

  void setContentsScale(CGFloat scale) {
    scale = clampDisplayScaleInput(scale);
    if (!params_.setDisplayScaleAndIfChangedUpdateSizeAndEdgeInsets(
                   DisplayScale::createOrIfInvalidGetMainSceenScale(scale), size_, contentInsets_))
    {
      return;
    }
    super_setContentsScale(scale);
    updateScreenProperties();
    displayScaleOrVerticalAlignmentChanged(true);
  }

  void setVerticalAlignment(STULabelVerticalAlignment verticalAlignment) {
    verticalAlignment = clampVerticalAlignmentInput(verticalAlignment);
    if (params_.verticalAlignment == verticalAlignment) return;
    params_.verticalAlignment = verticalAlignment;
    displayScaleOrVerticalAlignmentChanged(false);
  }

  /// MARK: - Layout info

  CGSize sizeThatFits(CGSize size) {
    STU_ASSERT(is_main_thread());
    size = clampSizeInput(size);
    const CGSize innerSize = maxTextFrameSizeForLabelSize(size, contentInsets_,
                                                          params_.displayScale());
    const LabelTextFrameInfo* info;
    if (textFrameInfo_.isValidForSize(innerSize, params_.displayScale())) {
      info = &textFrameInfo_;
    } else {
      info = &measuringTextFrameInfo_;
      if (!measuringTextFrameInfo_.isValidForSize(innerSize, params_.displayScale())) {
        if (measuringTextFrameInfo_.isValid && !textFrameInfoIsValidForCurrentSize_) {
          textFrame_ = measuringTextFrame_;
          textFrameInfo_ = measuringTextFrameInfo_;
        } else {
          isInvalidated_ = false;
        }
        if (stringIsEmpty_) {
          measuringTextFrame_ = nil;
          measuringTextFrameInfo_ = LabelTextFrameInfo::empty;
        } else {
          if (!shapedString_) {
            updateAttributedStringIfNecessary();
            shapedString_ = STUShapedStringCreate(nil, attributedString_,
                                                  params_.defaultBaseWritingDirection, nullptr);
          }
          measuringTextFrame_ = STUTextFrameCreateWithShapedString(nil, shapedString_, innerSize,
                                                                   params_.displayScale(),
                                                                   textFrameOptions_);
          measuringTextFrameInfo_ = labelTextFrameInfo(textFrameRef(measuringTextFrame_),
                                                       params_.verticalAlignment,
                                                       params_.displayScale());
        }
        if (!textFrameInfoIsValidForCurrentSize_
            && measuringTextFrameInfo_.isValidForSize(params_.maxTextFrameSize(),
                                                      params_.displayScale()))
        {
          std::swap(textFrame_, measuringTextFrame_);
          std::swap(textFrameInfo_, measuringTextFrameInfo_);
          textFrameInfoIsValidForCurrentSize_ = true;
          updateTextFrameOrigin();
          info = &textFrameInfo_;
        }
      }
    }
    // We assume that the screen scale stays constants until the next call to `setContentScale`
    // or `didMoveToWindow`.
    if (screenScale_ == 0) {
      updateScreenProperties();
    }
    // We want to avoid having to recompute the layout information when the content scale is changed
    // after the label is zoomed in or out on in a ScrollView or similar view.
    const CGFloat scale = screenScale_ >= 1 ? min(params_.displayScale(), screenScale_)
                        : params_.displayScale();
    if (sizeThatFitsDisplayScale_ != scale) {
      sizeThatFitsDisplayScale_ = params_.displayScale();
      if (sizeThatFitsDisplayScale_ != scale) {
        if (const auto optDS = DisplayScale::create(scale)) {
          sizeThatFitsDisplayScale_ = *optDS;
        }
      }
    }
    return info->sizeThatFits(contentInsets_, sizeThatFitsDisplayScale_);
  }

  Unretained<STUTextFrame* __nonnull> textFrame() {
    if (stringIsEmpty_) {
      return emptySTUTextFrame().unretained;
    }
    createTextFrameIfNecessary();
    return textFrame_;
  }

  CGPoint textFrameOrigin() {
    updateTextFrameInfoIfNecessary();
    return textFrameOrigin_;
  }

private:
  void updateTextFrameInfoIfNecessary() {
    if (!textFrameInfoIsValidForCurrentSize_) {
      updateTextFrameInfo();
    }
  }

  void createTextFrameIfNecessary() {
    if (!stringIsEmpty_ && (!textFrameInfoIsValidForCurrentSize_ || !textFrame_)) {
      updateTextFrameInfo();
    }
  }

  STU_NO_INLINE
  void updateTextFrameInfo() {
    isInvalidated_ = false;
    if (stringIsEmpty_) {
      textFrameInfo_ = LabelTextFrameInfo::empty;
      textFrameInfoIsValidForCurrentSize_ = true;
      textFrameOrigin_ = CGPointZero;
    } else {
      // This function is also called by createTextFrameIfNecessary, so we have to ensure here that
      // textFrame_ is nonnull even if textFrameInfoIsValidForCurrentSize_.
      if (!textFrameInfoIsValidForCurrentSize_ || !textFrame_) {
        if (task_ && task_->tryCopyLayoutInfoTo(*this)) return;
        if (!shapedString_) {
          updateAttributedStringIfNecessary();
          shapedString_ = [[STUShapedString alloc]
                             initWithAttributedString:attributedString_
                          defaultBaseWritingDirection:params_.defaultBaseWritingDirection];
        }
        textFrame_ = STUTextFrameCreateWithShapedString(nil, shapedString_,
                                                        params_.maxTextFrameSize(),
                                                        params_.displayScale(),
                                                        textFrameOptions_);
      }
      textFrameInfo_ = labelTextFrameInfo(textFrameRef(textFrame_),
                                          params_.verticalAlignment,
                                          params_.displayScale());
      textFrameInfoIsValidForCurrentSize_ = true;
      updateTextFrameOrigin();
    }
  }

  void updateTextFrameOrigin() {
    STU_DEBUG_ASSERT(textFrameInfoIsValidForCurrentSize_);
    textFrameOrigin_ = textFrameOriginInLayer(textFrameInfo_, params_);
  }

public:
  const LabelTextFrameInfo& currentTextFrameInfo() {
    updateTextFrameInfoIfNecessary();
    return textFrameInfo_;
  }

  STULabelLayoutInfo layoutInfo() {
    updateTextFrameInfoIfNecessary();
    return stuLabelLayoutInfo(textFrameInfo_, textFrameOrigin_, params_.displayScale());
  }

  CGFloat firstBaseline() {
    updateTextFrameInfoIfNecessary();
    return textFrameInfo_.firstBaseline;
  }

  CGFloat lastBaseline() {
    updateTextFrameInfoIfNecessary();
    return textFrameInfo_.lastBaseline;
  }

  Unretained<STUTextLinkArray* __nonnull> links() {
    updateTextFrameInfoIfNecessary();
    if (!(textFrameInfo_.flags & STUTextFrameHasLink)) {
      return emptySTUTextLinkArray();
    }
    if (links_ == nil) {
      STU_ASSERT(textFrame_ != nil); // We never clear the frame without setting links_ if necessary.
      const TextFrame& textFrame = textFrameRef(textFrame_);
      links_ = STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
                 textFrameRef(textFrame_), textFrameOrigin_,
                 TextFrameScaleAndDisplayScale{textFrame, params_.displayScale()});
    } else if (textFrameOrigin_ != STUTextLinkArrayGetTextFrameOrigin(links_)) {
      links_ = STUTextLinkArrayCopyWithShiftedTextFrameOrigin(links_, textFrameOrigin_);
    }
    return links_;
  }

  /// MARK: - Properties not affecting layout

  void setOpaque(bool opaque) {
    super_setOpaque(opaque);
    layerIsOpaque_ = opaque;
  }

  void setDisplayedBackgroundColor(CGColor* backgroundColor) {
    if (backgroundColor == params_.backgroundColor()) return;
    params_.setBackgroundColor(backgroundColor);
    if (layerHasBackgroundColor_) {
      super_setBackgroundColor(backgroundColor);
    }
    if (contentHasBackgroundColor_) {
      clearContent();
      invalidateImage();
    }
  }

  void setIsHighlighted(bool highlighted) {
    if (highlighted == params_.isHighlighted()) return;
    params_.setIsHighlighted(highlighted);
    if (!isInvalidated_ && params_.highlightStyle()) {
      if (hasContent_ && displaysAsynchronously_) {
        prefersSynchronousDrawingForNextDisplay_ = true;
      }
      invalidateImage();
    }
  }

  void setHighlightStyle(STUTextHighlightStyle* __unsafe_unretained highlightStyle) {
    if (params_.setHighlightStyle(highlightStyle)) {
      if (!isInvalidated_ && params_.isHighlighted()) {
        invalidateImage();
      }
    }
  }

  void setHighlightRange(NSRange range, STUTextRangeType rangeType) {
    if (params_.setHighlightRange(range, rangeType)) {
      if (!isInvalidated_ && params_.isHighlighted()) {
        invalidateImage();
      }
    }
  }

  void setOverrideColorsApplyToHighlightedText(bool value) {
    if (params_.setOverrideColorsApplyToHighlightedText(value)) {
      if (!isInvalidated_ && params_.isEffectivelyHighlighted()) {
        invalidateImage();
      }
    }
  }

  void setOverrideTextColor(UIColor* __unsafe_unretained color) {
    if (params_.setOverrideTextColor(color)) {
      invalidateImage();
    }
  }

  void setOverrideLinkColor(UIColor* __unsafe_unretained color) {
    if (params_.setOverrideLinkColor(color)) {
      if (textFrameInfoIsValidForCurrentSize_ && (textFrameInfo_.flags & STUTextFrameHasLink)) {
        invalidateImage();
      }
    }
  }

  void setReleasesShapedStringAfterRendering(bool releasesShapedStringAfterRendering) {
    params_.releasesShapedStringAfterRendering = releasesShapedStringAfterRendering;
    params_.releasesShapedStringAfterRenderingWasExplicitlySet = true;
    if (releasesShapedStringAfterRendering && shapedString_ && !isInvalidated_ && hasContent_) {
      shapedString_ = nil;
    }
  }

  void setReleasesTextFrameAfterRendering(bool releasesTextFrameAfterRendering) {
    params_.releasesTextFrameAfterRendering = releasesTextFrameAfterRendering;
    params_.releasesTextFrameAfterRenderingWasExplicitlySet = true;
    if (releasesTextFrameAfterRendering && textFrame_ && !isInvalidated_ && hasContent_) {
      textFrame_ = nil;
    }
  }

  void setNeverUsesGrayscaleBitmapFormat(bool neverUsesGrayscaleBitmapFormat) {
    if (params_.neverUseGrayscaleBitmapFormat == neverUsesGrayscaleBitmapFormat) return;
    params_.neverUseGrayscaleBitmapFormat = neverUsesGrayscaleBitmapFormat;
    if (neverUsesGrayscaleBitmapFormat
        && hasContent_ && imageFormat_ == STUPredefinedCGImageFormatGrayscale)
    {
      invalidateImage();
    }
  }

  void setNeverUsesExtendedRGBBitmapFormat(bool neverUsesExtendedRGBBitmapFormat) {
    params_.neverUsesExtendedRGBBitmapFormatWasExplicitlySet = true;
    if (params_.neverUsesExtendedRGBBitmapFormat == neverUsesExtendedRGBBitmapFormat) return;
    params_.neverUsesExtendedRGBBitmapFormat = neverUsesExtendedRGBBitmapFormat;
    if (neverUsesExtendedRGBBitmapFormat
        && hasContent_ && imageFormat_ == STUPredefinedCGImageFormatExtendedRGB)
    {
      invalidateImage();
    }
  }

  void setContentsFormat(NSString* __unsafe_unretained contentsFormat) {
    if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
      layerContentsFormat_ = contentsImageFormat(contentsFormat, unknownCGImageFormat);
      super_setContentsFormat(contentsFormat);
    }
  }

  void setContentsGravity(NSString* __unsafe_unretained gravity) {
    if (layerContentsGravity_doNotDereference_ == gravity) return;
    layerContentsGravity_doNotDereference_ = gravity;
    super_setContentsGravity(gravity);
  }

  void setDrawingBlock(STULabelDrawingBlock __unsafe_unretained drawingBlock) {
    if (params_.drawingBlock == drawingBlock) return;
    params_.drawingBlock = drawingBlock;
    invalidateImage();
  }

  void setDrawingBlockColorOptions(STULabelDrawingBlockColorOptions colorOptions) {
    colorOptions = clampLabelDrawingBlockColorOptions(colorOptions);
    if (params_.drawingBlockColorOptions == colorOptions) return;
    params_.drawingBlockColorOptions = colorOptions;
    invalidateImage();
  }

  void setDrawingBlockImageBounds(STULabelDrawingBounds drawingBounds) {
    drawingBounds = clampLabelDrawingBounds(drawingBounds);
    if (params_.drawingBlockImageBounds == drawingBounds) return;
    params_.drawingBlockImageBounds = drawingBounds;
    invalidateImage();
  }

  void setClipsContentToBounds(bool clipsContentToBounds) {
    if (params_.clipsContentToBounds == clipsContentToBounds) return;
    params_.clipsContentToBounds = clipsContentToBounds;
    invalidateImage();
  }

  bool displaysAsynchronously() const {
    return displaysAsynchronously_;
  }
  void setDisplaysAsynchronously(bool displaysAsynchronously) {
    if (displaysAsynchronously_ == displaysAsynchronously) return;
    displaysAsynchronously_ = displaysAsynchronously;
    if (!displaysAsynchronously) {
      if (task_) {
        invalidateImage();
      }
    } else {
      if (!hasContent_ && contentsIsNotNil_) {
        // When !displaysAsynchronously_, clearContent() doesn't assign nil to self.contents,
        // so let's make sure there really is no content.
        self.contents = nil; // Clears needsDisplay flag.
        contentsIsNotNil_ = false;
        [self setNeedsDisplay];
      }
    }
  }

  /// MARK: - configureWithPrerenderer

  void configureWithPrerenderer(STULabelPrerenderer* NS_VALID_UNTIL_END_OF_SCOPE stuPrerenderer) {
    LabelPrerenderer& prerenderer = *stuPrerenderer->prerenderer;
    STU_CHECK_MSG(prerenderer.isFrozen() || !displaysAsynchronously_,
                  "You must call one of the render methods on the STULabelPrerenderer instance before"
                  " passing it to a STULabel(Layer) with displaysAsynchronously=true.");
    if (!isInvalidated_) {
      invalidateLayout_slowPath_main(false);
      shapedString_ = nil;
    } else {
      STU_DEBUG_ASSERT(!task_);
    }

    // Copy over configuration from prerenderer.
    clearStringProperties();
    isInvalidated_ = false;
    attributedString_ = prerenderer.attributedString();
    stringIsEmpty_ = prerenderer.stringIsEmpty();
    if (!prerenderer.stringIsEmpty() && prerenderer.hasShapedString()) {
      shapedString_ = prerenderer.shapedString().unretained;
    }
    textFrameOptions_ = prerenderer.textFrameOptions().unretained;
    textFrameOptionsIsPrivate_ = false;

    const bool neverUsesExtendedRGBBitmapFormat =
        !params_.neverUsesExtendedRGBBitmapFormatWasExplicitlySet
        && prerenderer.params().neverUsesExtendedRGBBitmapFormatWasExplicitlySet
        ? prerenderer.params().neverUsesExtendedRGBBitmapFormat
        : params_.neverUsesExtendedRGBBitmapFormat;

    const bool releasesShapedStringAfterRendering =
        !params_.releasesShapedStringAfterRenderingWasExplicitlySet
        && prerenderer.params().releasesShapedStringAfterRenderingWasExplicitlySet
        ? prerenderer.params().releasesShapedStringAfterRendering
        : params_.releasesShapedStringAfterRendering;

    const bool releasesTextFrameAfterRendering =
        !params_.releasesTextFrameAfterRenderingWasExplicitlySet
        && prerenderer.params().releasesTextFrameAfterRenderingWasExplicitlySet
        ? prerenderer.params().releasesTextFrameAfterRendering
        : params_.releasesTextFrameAfterRendering;

    if (layerHasBackgroundColor_
        && params_.backgroundColor() != prerenderer.params().backgroundColor())
    {
      super_setBackgroundColor(prerenderer.params().backgroundColor());
    }
    if (params_.displayScale() != prerenderer.params().displayScale()) {
      super_setContentsScale(prerenderer.params().displayScale());
    }
    contentInsets_ = prerenderer.contentInsets();
    implicit_cast<LabelParametersWithoutSize&>(params_) =
      implicit_cast<const LabelParametersWithoutSize&>(prerenderer.params());
    params_.neverUsesExtendedRGBBitmapFormat = neverUsesExtendedRGBBitmapFormat;
    params_.releasesShapedStringAfterRendering = releasesShapedStringAfterRendering;
    params_.releasesTextFrameAfterRendering = releasesTextFrameAfterRendering;
    if (!prerenderer.sizeOptions() || prerenderer.completedLayout()) {
      params_.setSize_afterBaseAssignment_alreadyCeiledToScale(prerenderer.params().size());
    } else {
      params_.setSize_afterBaseAssignment_alreadyCeiledToScale(ceilToScale(prerenderer.size(),
                                                                           params_.displayScale()));
      updateTextFrameInfo();
      params_.shrinkSizeToFitTextBounds(textFrameInfo_.layoutBounds, prerenderer.sizeOptions());
    }
    if (size_ != params_.size()) {
      size_ = params_.size();
      super_setBounds(CGRect{CGPoint{}, size_});
    }
    setHasBackgroundColor(true);

    // Assign task or task result.

    if (!prerenderer.isFinished()) {
      if (prerenderer.isFrozen()) {
        taskIsStale_ = false;
        task_ = &prerenderer;
        prerenderer.registerWaitingLabelLayer(*this);
      } else {
        prerenderer.tryCopyLayoutInfoTo(*this);
      }
      if (!displaysAsynchronously_) {
        [self setNeedsDisplay];
      }
    } else {
      if (prerenderer.stringIsEmpty()) {
        updateTextFrameInfo();
        contentBoundsInTextFrame_ = CGRectZero;
        contentMayBeClipped_ = false;
        contentHasBackgroundColor_ = false;
      } else {
        taskIsStale_ = false;
        prerenderer.assignResultTo(*this);
      }
    }
    auto* const delegate = labelLayerDelegate_;
    textLayoutWasInvalidated(delegate); // May invalidate this layer again.
    if (prerenderer.isFinished() && !isInvalidated_) {
      didDisplayText(delegate);
    }
  }

  /// MARK: - Displaying

  void display() {
    if (task_ != nil && !taskIsStale_ && displaysAsynchronously_ && !enteredBackground) return;
    auto* const delegate = labelLayerDelegate_;
    const bool suggestedAsync = displaysAsynchronously_ && !enteredBackground
                                && !prefersSynchronousDrawingForNextDisplay_;
    const bool async = shouldDisplayAsync(delegate, suggestedAsync) && !enteredBackground;
    if (task_) {
      if (!textFrameInfoIsValidForCurrentSize_) {
        task_->tryCopyLayoutInfoTo(*this);
      }
      removeTask();
    }
    isInvalidated_ = false;
    prefersSynchronousDrawingForNextDisplay_ = enteredBackground;
    if (!async || stringIsEmpty_) {
      updateTextFrameInfoIfNecessary();
    }
    if (textFrameInfoIsValidForCurrentSize_ && textFrameInfo_.layoutBounds.x.isEmpty()) {
      clearContent();
      if (contentsIsNotNil_) {
        self.contents = nil;
        contentsIsNotNil_ = false;
      }
      contentBoundsInTextFrame_ = CGRectZero;
      contentMayBeClipped_ = false;
      contentHasBackgroundColor_ = false;
      setHasBackgroundColor(true);
      didDisplayText(delegate);
      return;
    }
    const bool allowExtendedRGBBitmapFormat = screenDisplayGamut_ != STUDisplayGamutSRGB;
    if (!async) {
      createTextFrameIfNecessary();
      const auto renderInfo = labelTextFrameRenderInfo(textFrame_, textFrameInfo_,
                                                       textFrameOrigin_, params_,
                                                       allowExtendedRGBBitmapFormat,
                                                       false, nullptr);
      if (params_.drawingBlock) {
        params_.freezeDrawingOptions();
      }
      setContents(renderInfo, nil);
      const bool releaseFrame = renderInfo.mode != LabelRenderMode::tiledSublayer
                             && params_.releasesTextFrameAfterRendering;
      if (releaseFrame) {
        if ((textFrameInfo_.flags & STUTextFrameHasLink) && !links_) {
          const TextFrame& textFrame = textFrameRef(textFrame_);
          links_ = STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
                     textFrame, textFrameOrigin_,
                     TextFrameScaleAndDisplayScale{textFrame, params_.displayScale()});
        }
        textFrame_ = nil;
        measuringTextFrame_ = nil;
      }
      if (params_.releasesShapedStringAfterRendering) {
        shapedString_ = nil;
      }
      didDisplayText(delegate);
      return;
    }
    // async
    taskIsStale_ = false;
    setHasBackgroundColor(true);
    params_.freezeDrawingOptions();
    const dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    if (textFrameInfoIsValidForCurrentSize_) {
      task_ = LabelRenderTask::dispatchAsync(queue, *this, params_, allowExtendedRGBBitmapFormat,
                                             textFrame_, textFrameInfo_, textFrameOrigin_);
    } else {
      textFrameOptionsIsPrivate_ = false;
      if (!shapedString_) {
        updateAttributedStringIfNecessary();
        task_ = LabelTextShapingAndLayoutAndRenderTask::dispatchAsync(
                  queue, *this, params_, allowExtendedRGBBitmapFormat, textFrameOptions_,
                  attributedString_);
      } else {
        task_ = LabelLayoutAndRenderTask::dispatchAsync(
                  queue, *this, params_, allowExtendedRGBBitmapFormat, textFrameOptions_,
                  shapedString_);
      }
    }
  }

  void drawInContext(CGContext* context) const {
    if (!textFrame_) return;
    if (contentHasBackgroundColor_) {
      CGContextSetFillColorWithColor(context, params_.backgroundColor());
      CGContextFillRect(context, CGRect{CGPoint{}, contentBoundsInTextFrame_.size});
    }
    drawLabelTextFrame(
      textFrame_, STUTextFrameGetRange(textFrame_), -contentBoundsInTextFrame_.origin,
      context, ContextBaseCTM_d{0}, PixelAlignBaselines{true}, params_.drawingOptions,
      params_.drawingBlock, nullptr);
  }

private:
  CGRect contentBounds() {
    return contentBoundsInTextFrame_ + textFrameOrigin_;
  }

  void setContents(const LabelTextFrameRenderInfo& renderInfo, CGImage* __nullable image) {
    STU_ASSERT(textFrameInfoIsValidForCurrentSize_);
    hasContent_ = true;
    imageFormat_ = renderInfo.imageFormat;
    contentHasBackgroundColor_ = renderInfo.shouldDrawBackgroundColor;
    contentBoundsInTextFrame_ = renderInfo.bounds;
    contentMayBeClipped_ = renderInfo.mayBeClipped;
    if (renderInfo.mode <= LabelRenderMode::image) {
      if (contentLayer_) {
        removeContentLayer();
      }
      renderMode_ = renderInfo.mode;
      setContentsGravity(textFrameInfo_.horizontalAlignment, textFrameInfo_.verticalAlignment);
    }
    if (renderInfo.mode == LabelRenderMode::drawInCAContext) {
      STU_DEBUG_ASSERT(!image);
      setHasBackgroundColor(!contentHasBackgroundColor_);
      if (renderInfo.isOpaque != layerIsOpaque_) {
        layerIsOpaque_ = renderInfo.isOpaque;
        super_setOpaque(renderInfo.isOpaque);
      }
      if (renderInfo.imageFormat != layerContentsFormat_) {
        if (@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
          setContentsImageFormat(self, renderInfo.imageFormat);
        }
      }
      super_display();
    } else if (renderInfo.mode != LabelRenderMode::tiledSublayer) {
      bool needToReleaseImage = false;
      if (!image && textFrame_) {
        image_ = createLabelTextFrameImage(textFrame_, renderInfo, params_, nullptr);
        imageMayHaveBeenPurged_ = false;
        image = image_.createCGImage().toRawPointer();
        needToReleaseImage = true;
        registerAsLabelLayerThatHasImage();
      }
      STU_DEBUG_ASSERT(image != nullptr);
      if (renderInfo.mode == LabelRenderMode::image) {
        setHasBackgroundColor(!contentHasBackgroundColor_);
        self.contents = (__bridge id)image;
        contentsIsNotNil_ = true;
      } else {
        STU_ASSERT(renderInfo.mode == LabelRenderMode::imageInSublayer);
        setContentLayerContents((__bridge id)image);
      }
      if (needToReleaseImage) {
        decrementRefCount(image);
      }
    } else {
      STU_DEBUG_ASSERT(!image);
      installTiledContentLayer(renderInfo);
    }
  }

  void setHasBackgroundColor(bool hasBackgroundColor) {
    if (layerHasBackgroundColor_ == hasBackgroundColor) return;
    layerHasBackgroundColor_ = hasBackgroundColor;
    if (params_.backgroundColor()) {
      super_setBackgroundColor(hasBackgroundColor ? params_.backgroundColor() : nil);
    }
  }

  /// Returns a static constant.
  STU_NO_INLINE
  static __nonnull CFStringRef contentsGravity(
                                 STULabelHorizontalAlignment horizontalAlignment,
                                 STULabelVerticalAlignment verticalAlignment)
  {
    switch (verticalAlignment) {
    case STULabelVerticalAlignmentTop:
      switch (horizontalAlignment) {
      case STULabelHorizontalAlignmentLeft:   return (__bridge CFStringRef)kCAGravityBottomLeft;
      case STULabelHorizontalAlignmentRight:  return (__bridge CFStringRef)kCAGravityBottomRight;
      case STULabelHorizontalAlignmentCenter: return (__bridge CFStringRef)kCAGravityBottom;
      }
    case STULabelVerticalAlignmentBottom:
      switch (horizontalAlignment) {
      case STULabelHorizontalAlignmentLeft:   return (__bridge CFStringRef)kCAGravityTopLeft;
      case STULabelHorizontalAlignmentRight:  return (__bridge CFStringRef)kCAGravityTopRight;
      case STULabelHorizontalAlignmentCenter: return (__bridge CFStringRef)kCAGravityTop;
      }
    case STULabelVerticalAlignmentCenter:
    case STULabelVerticalAlignmentCenterCapHeight:
    case STULabelVerticalAlignmentCenterXHeight:
      switch (horizontalAlignment) {
      case STULabelHorizontalAlignmentLeft:   return (__bridge CFStringRef)kCAGravityLeft;
      case STULabelHorizontalAlignmentRight:  return (__bridge CFStringRef)kCAGravityRight;
      case STULabelHorizontalAlignmentCenter: return (__bridge CFStringRef)kCAGravityCenter;
      }
    }
    return (__bridge CFStringRef)kCAGravityResize;
  }

  void setContentsGravity(STULabelHorizontalAlignment horizontalAlignment,
                          STULabelVerticalAlignment verticalAlignment)
  {
    const CFStringRef gravity = contentsGravity(horizontalAlignment, verticalAlignment);
    if (layerContentsGravity_doNotDereference_ == (__bridge NSString*)gravity) return;
    // Cast to supertype to circumvent "unavailable" error.
    static_cast<CALayer*>(self).contentsGravity = (__bridge NSString*)gravity;
  }

  STU_INLINE
  void clearContent() {
    if (hasContent_) {
      clearContent_slowPath();
    }
  }
  STU_NO_INLINE
  void clearContent_slowPath() {
    hasContent_ = false;
    switch (renderMode_) {
    case LabelRenderMode::drawInCAContext:
      break;
    case LabelRenderMode::image:
      if (contentsIsNotNil_) {
        self.contents = nil; // This also seems to clear the "needsDisplay" flag.
        contentsIsNotNil_ = false;
      }
      image_ = PurgeableImage();
      imageMayHaveBeenPurged_ = false;
      deregisterAsLabelLayerThatHasImage();
      break;
    case LabelRenderMode::imageInSublayer:
      contentLayer_.contents = nil;
      image_ = PurgeableImage();
      imageMayHaveBeenPurged_ = false;
      deregisterAsLabelLayerThatHasImage();
      break;
    case LabelRenderMode::tiledSublayer:
      ((STULabelTiledLayer*)contentLayer_).drawingBlock = nil;
      break;
    }
  }

  /// MARK: - Content sublayer

  void moveContentImageToContentLayer() {
    STU_ASSERT(renderMode_ <= LabelRenderMode::image);
    const id content = self.contents; // This may also be a CABackingStore.
    if (!content) return;
    setContentLayerContents(content);
  }

  void removeContentLayer() {
    [contentLayer_ removeFromSuperlayer];
    contentLayer_ = nil;
  }

  void installTiledContentLayer(const LabelTextFrameRenderInfo& renderInfo) {
    STU_ASSERT(textFrame_ != nil);

    if (contentLayer_ && renderMode_ != LabelRenderMode::tiledSublayer) {
      removeContentLayer();
    }
    if (!contentLayer_) {
      self.contents = nil;
      contentsIsNotNil_ = false;
      contentLayer_ = [[STULabelTiledLayer alloc] init];
      [self insertSublayer:contentLayer_ atIndex:0];
      renderMode_ = LabelRenderMode::tiledSublayer;
      contentLayerClipsToBounds_ = false;
    }
    prefersSynchronousDrawingForNextDisplay_ = true;

    setContentLayerFrame();
    contentLayer_.contentsScale = params_.displayScale();
    ((STULabelTiledLayer*)contentLayer_).imageFormat = renderInfo.imageFormat;

    STUTextFrame* const textFrame = textFrame_;
    const STUTextFrameRange range = STUTextFrameGetRange(textFrame);
    CGPoint const textFrameOrigin = -contentBoundsInTextFrame_.origin;
    STUTextFrameDrawingOptions* const drawingOptions = params_.frozenDrawingOptions().unretained;
    STULabelDrawingBlock const drawingBlock = params_.drawingBlock;
    ((STULabelTiledLayer*)contentLayer_).drawingBlock =
      ^(CGContext* context, CGRect __unused rect, const STUCancellationFlag* cancellationFlag) {
        drawLabelTextFrame(textFrame, range, textFrameOrigin, context,
                           ContextBaseCTM_d{1}, PixelAlignBaselines{true}, drawingOptions,
                           drawingBlock, cancellationFlag);
      };
  }

  void setContentLayerContents(id contents) {
    if (contentLayer_ && renderMode_ != LabelRenderMode::imageInSublayer) {
      removeContentLayer();
    }
    if (!contentLayer_) {
      contentLayer_ = [[STULabelImageContentLayer alloc] init];
      contentLayerClipsToBounds_ = false;
    }
    if (renderMode_ != LabelRenderMode::imageInSublayer) {
      renderMode_ = LabelRenderMode::imageInSublayer;
      self.contents = nil;
      contentsIsNotNil_ = false;
      [self insertSublayer:contentLayer_ atIndex:0];
    }
    contentLayer_.contentsScale = params_.displayScale();
    contentLayer_.contentsGravity = (__bridge NSString*)contentsGravity(
                                                          textFrameInfo_.horizontalAlignment,
                                                          textFrameInfo_.verticalAlignment);
    setContentLayerFrame();
    contentLayer_.contents = contents;
  }

  void setContentLayerFrame() {
    STU_ASSERT(textFrameInfoIsValidForCurrentSize_);
    const CGRect bounds = {{}, params_.size()};
    CGRect contentFrame = contentBounds();
    if (renderMode_ != LabelRenderMode::tiledSublayer) {
      const bool clipToBounds = (params_.clipsContentToBounds || contentHasBackgroundColor_)
                             && !CGRectContainsRect(bounds, contentFrame);
      if (clipToBounds) {
        contentFrame = CGRectIntersection(contentFrame, bounds);
      }
      if (clipToBounds != contentLayerClipsToBounds_) {
        contentLayerClipsToBounds_ = clipToBounds;
        contentLayer_.masksToBounds = clipToBounds;
        // The layer already has the necessary contentsGravity.
      }
    }
    contentLayer_.frame = contentFrame;
    setHasBackgroundColor(!contentHasBackgroundColor_
                          || contentFrame.size.width  < params_.size().width
                          || contentFrame.size.height < params_.size().height);
  }

public:
  void setAlwaysUsesContentSublayer(bool alwaysUsesContentSublayer) {
    if (params_.alwaysUsesContentSublayer == alwaysUsesContentSublayer) return;
    params_.alwaysUsesContentSublayer = alwaysUsesContentSublayer;
    if (alwaysUsesContentSublayer && !isInvalidated_ && hasContent_
        && renderMode_ <= LabelRenderMode::image)
    {
      if (!contentHasBackgroundColor_) {
        moveContentImageToContentLayer();
      } else {
        invalidateImage();
      }
    }
  }

  CALayer* __nullable contentSublayer() const {
    return renderMode_ >= LabelRenderMode::imageInSublayer ? contentLayer_ : nil;
  }

private:
  /// MARK: - Render task

  void cancelAsyncRendering() {
    if (!task_) return;
    LabelRenderTask& task = *task_;
    taskIsStale_ = true;
    // Prerender tasks may be used again.
    if (task.type() != LabelRenderTask::Type::prerender) {
      task.cancelRendering();
    }
  }

  STU_INLINE
  void removeTask() {
    if (!task_) return;
    LabelRenderTask& task = *task_;
    task.abandonedByLabel(*this);
    task_ = nullptr;
  }


  /// MARK: - Invalidation

  /// If the image shouldn't stay until a new one is drawn, call clearContent() before calling this
  /// function.
  STU_INLINE
  void invalidateImage() {
    if (isInvalidated_) return;
    invalidateImage_slowPath();
  }
  STU_NO_INLINE
  void invalidateImage_slowPath() {
    cancelAsyncRendering();
    [self setNeedsDisplay];
  }

  /// Layout invalidation may call a delegate method that may then call back into a method of this
  /// class. Hence, to preserve invariants, invalidations should should happen at the end of a
  /// method implementation.

  void invalidateShapedString() {
    if (shapedString_) {
      shapedString_ = nil;
    }
    invalidateLayout();
  }

  void invalidateLayout() {
    if (isInvalidated_) return;
    invalidateLayout_slowPath(false);
  }

  STU_NO_INLINE
  void invalidateLayout_slowPath(bool preserveTextFrames) {
    invalidateLayout_slowPath_main(preserveTextFrames);
    [self setNeedsDisplay];
    textLayoutWasInvalidated(labelLayerDelegate_);
  }
  STU_NO_INLINE
  void invalidateLayout_slowPath_main(bool preserveTextFrames) {
    removeTask();
    if (!preserveTextFrames) {
      links_ = nil;
      textFrame_ = nil;
      textFrameInfo_.isValid = false;
      textFrameInfoIsValidForCurrentSize_ = false;
      measuringTextFrame_ = nil;
      measuringTextFrameInfo_.isValid = false;
      isInvalidated_ = true;
    }
    prefersSynchronousDrawingForNextDisplay_ = displaysAsynchronously_ && inUIViewAnimation();
    clearContent();
  }

  void sizeOrEdgeInsetsChanged(const LabelParameters::ChangeStatus changeStatus) {
    if (isInvalidated_) return;
    const CGSize size = params_.size();
    const CGSize innerSize = params_.maxTextFrameSize();
    textFrameInfoIsValidForCurrentSize_ = textFrameInfo_.isValidForSize(innerSize,
                                                                        params_.displayScale());
    if (textFrameInfoIsValidForCurrentSize_) {
      const CGPoint oldTextFrameOrigin = textFrameOrigin_;
      updateTextFrameOrigin();
      if (!hasContent_ && !task_) return;
      if (task_ // Preserving the task when possible doesn't seem worth the additional complexity.
          || (changeStatus & LabelParameters::ChangeStatus::edgeInsetsChanged)
          || (contentMayBeClipped_
               && (   contentBoundsInTextFrame_.size.width  < size.width
                   || contentBoundsInTextFrame_.size.height < size.height)))
      {
        invalidateImage();
        return;
      }
      switch (renderMode_) {
      case LabelRenderMode::drawInCAContext:
      case LabelRenderMode::image:
        if (   contentBoundsInTextFrame_.size.width  <= size.width
            && contentBoundsInTextFrame_.size.height <= size.height)
        {
          if (contentHasBackgroundColor_ && !layerHasBackgroundColor_
              && (   contentBoundsInTextFrame_.size.width  < size.width
                  || contentBoundsInTextFrame_.size.height < size.height))
          {
            setHasBackgroundColor(true);
          }
          break;
        } else {
          if (contentHasBackgroundColor_ && !params_.clipsContentToBounds) {
            invalidateImage();
            return;
          }
          moveContentImageToContentLayer();
        }
        break;
      case LabelRenderMode::tiledSublayer:
        if ((params_.clipsContentToBounds || contentHasBackgroundColor_)
            && !Rect{{}, params_.size()}.contains(contentBounds()))
        {
          invalidateImage();
          return;
        }
        [[fallthrough]];
      case LabelRenderMode::imageInSublayer:
        setContentLayerFrame();
        break;
      }
      if (oldTextFrameOrigin != textFrameOrigin_) {
        didMoveDisplayedText(labelLayerDelegate_);
      }
      return;
    }
    if (measuringTextFrameInfo_.isValidForSize(innerSize, params_.displayScale())) {
      std::swap(textFrame_, measuringTextFrame_);
      std::swap(textFrameInfo_, measuringTextFrameInfo_);
      textFrameInfoIsValidForCurrentSize_ = true;
      updateTextFrameOrigin();
    }
    links_ = nil;
    invalidateLayout_slowPath(true);
  }

  void displayScaleOrVerticalAlignmentChanged(bool displayScaleChanged) {
    if (isInvalidated_) return;
    if (textFrame_) {
      textFrameInfo_ = labelTextFrameInfo(textFrameRef(textFrame_), params_.verticalAlignment,
                                          params_.displayScale());
      textFrameInfoIsValidForCurrentSize_ =
        textFrameInfo_.isValidForSize(params_.maxTextFrameSize(), params_.displayScale());
      if (textFrameInfoIsValidForCurrentSize_) {
        updateTextFrameOrigin();
      }
    } else {
      textFrameInfo_.isValid = false;
      textFrameInfoIsValidForCurrentSize_ = false;
    }
    if (!textFrameInfoIsValidForCurrentSize_ || displayScaleChanged) {
      links_ = nil;
    }
    if (measuringTextFrame_) {
      measuringTextFrameInfo_ = labelTextFrameInfo(textFrameRef(measuringTextFrame_),
                                                   params_.verticalAlignment,
                                                   params_.displayScale());
    } else {
      measuringTextFrameInfo_.isValid = false;
    }
    invalidateLayout_slowPath(true);
  }

  /// MARK: - Tracking of layers with content images

  static LabelLayer* lastLabelLayerThatHasImage;

  static UInt enteredBackground;

  void registerAsLabelLayerThatHasImage() {
    if (isRegisteredAsLayerThatMayHaveImage_) return;
    registerAsLabelLayerThatHasImage_slowPath();
  }
  STU_NO_INLINE
  void registerAsLabelLayerThatHasImage_slowPath() {
    static bool didRegisterForNotifications = false;
    if (STU_UNLIKELY(!didRegisterForNotifications)) {
      STU_ASSERT(is_main_thread());
      didRegisterForNotifications = true;
      NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
      NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
      [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        clearContentImagesOfLabelLayersWithoutWindow();
      }];
      [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        enteredBackground += 1;
        removeContentCGImagesOfLabelLayersWithoutWindow();
      }];
      [notificationCenter addObserverForName:UIApplicationWillEnterForegroundNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        enteredBackground -= 1;
        restoreContentCGImagesOfLabelLayersWithoutWindowWhereNotPurged();
      }];
    }
    if (lastLabelLayerThatHasImage) {
      STU_ASSERT(lastLabelLayerThatHasImage->nextLayerThatHasImage_ == nil);
      lastLabelLayerThatHasImage->nextLayerThatHasImage_ = this;
      previousLayerThatHasImage_ = lastLabelLayerThatHasImage;
    }
    STU_ASSERT(nextLayerThatHasImage_ == nil);
    lastLabelLayerThatHasImage = this;
    isRegisteredAsLayerThatMayHaveImage_ = true;
  }

  void deregisterAsLabelLayerThatHasImage() {
    if (!isRegisteredAsLayerThatMayHaveImage_) return;
    deregisterAsLabelLayerThatHasImage_slowPath();
  }
  STU_NO_INLINE
  void deregisterAsLabelLayerThatHasImage_slowPath() {
    LabelLayer* const previous = previousLayerThatHasImage_;
    LabelLayer* const next = nextLayerThatHasImage_;
    if (previous) {
      previous->nextLayerThatHasImage_ = next;
    }
    if (next) {
      next->previousLayerThatHasImage_ = previous;
    } else {
      STU_ASSERT(lastLabelLayerThatHasImage == this);
      lastLabelLayerThatHasImage = previous;
    }
    previousLayerThatHasImage_  = nil;
    nextLayerThatHasImage_ = nil;
    isRegisteredAsLayerThatMayHaveImage_ = false;
  }

  static void clearContentImagesOfLabelLayersWithoutWindow() {
    STU_ASSERT(is_main_thread());
    LabelLayer* layer = lastLabelLayerThatHasImage;
    while (layer) {
      LabelLayer* const previous = layer->previousLayerThatHasImage_;
      if (!layer->hasWindow()) {
        layer->clearContent(); // Also removes layer from labelLayerThatHasImage list.
        [layer->self setNeedsDisplay];
        layer->prefersSynchronousDrawingForNextDisplay_ = true;
      }
      layer = previous;
    }
  }

  /// Removing the CGImages makes the LabelLayer's image_ purgeable (if there are no other
  /// references left to the image data).
  static void removeContentCGImagesOfLabelLayersWithoutWindow() {
    STU_ASSERT(is_main_thread());
    for (LabelLayer* layer = lastLabelLayerThatHasImage;
         layer != nil; layer = layer->previousLayerThatHasImage_)
    {
      if (layer->hasWindow()) continue;
      if (layer->renderMode_ == LabelRenderMode::image) {
        layer->self.contents = nil;
        layer->contentsIsNotNil_ = false;
      } else {
        STU_ASSERT(layer->renderMode_ == LabelRenderMode::imageInSublayer);
        layer->contentLayer_.contents = nil;
      }
      layer->imageMayHaveBeenPurged_ = true;
    }
  }

  static void restoreContentCGImagesOfLabelLayersWithoutWindowWhereNotPurged() {
    STU_ASSERT(is_main_thread());
    LabelLayer* layer = lastLabelLayerThatHasImage;
    while (layer) {
      LabelLayer* const previous = layer->previousLayerThatHasImage_;
      if (layer->imageMayHaveBeenPurged_) {
        layer->imageMayHaveBeenPurged_ = false;
        if (const RC<CGImage> cgImage = layer->image_.createCGImage()) {
          if (layer->renderMode_ == LabelRenderMode::image) {
            layer->self.contents = (__bridge id)cgImage.get();
            layer->contentsIsNotNil_ = true;
          } else {
            STU_ASSERT(layer->renderMode_ == LabelRenderMode::imageInSublayer);
            layer->contentLayer_.contents = (__bridge id)cgImage.get();
          }
        } else { // The image was purged.
          layer->clearContent(); // Also removes layer from labelLayerThatHasImage list.
          [layer->self setNeedsDisplay];
          layer->prefersSynchronousDrawingForNextDisplay_ = true;
        }
      }
      layer = previous;
    }
  }
};

UInt LabelLayer::enteredBackground;
LabelLayer* LabelLayer::lastLabelLayerThatHasImage;

void LabelRenderTask::copyLayoutInfoTo(LabelLayer& label) const {
  STU_ASSERT(textFrameInfo_.isValid);
  label.textFrameInfo_ = textFrameInfo_;
  label.textFrameInfoIsValidForCurrentSize_ = true;
  label.updateTextFrameOrigin();
  label.textFrame_ = textFrame_;
  if (type_ != Type::render) {
    auto& self = down_cast<const LabelLayoutAndRenderTask&>(*this);
    if (!label.shapedString_) {
      label.shapedString_ = self.shapedString_;
    }
    if (!label.links_ && self.links_) {
      label.links_ = self.links_;
    }
  }
}

/// MARK: - LabelRenderTask methods

void LabelRenderTask::assignResultTo(LabelLayer& label) {
  STU_DEBUG_ASSERT(isFinished_);
  STU_DEBUG_ASSERT(textFrameInfo_.isValid);

  label.textFrameInfo_ = textFrameInfo_;
  label.textFrameInfoIsValidForCurrentSize_ = true;
  label.updateTextFrameOrigin();

  if ((textFrameInfo_.flags & STUTextFrameHasLink)) {
    if (type_ != Type::render && down_cast<const LabelLayoutAndRenderTask&>(*this).links_) {
      label.links_ = down_cast<const LabelLayoutAndRenderTask&>(*this).links_;
    }
  }

  if (!label.params_.releasesShapedStringAfterRendering) {
    if (!label.shapedString_ && type_ != Type::render) {
      auto& self = down_cast<const LabelLayoutAndRenderTask&>(*this);
      if (self.shapedString_) {
        label.shapedString_ = self.shapedString_;
      }
    }
  } else if (label.shapedString_) {
    label.shapedString_ = nil;
  }

  const bool keepTextFrame = !label.params_.releasesTextFrameAfterRendering
                           || renderInfo_.mode == LabelRenderMode::tiledSublayer;
  if (keepTextFrame && textFrame_) {
    label.textFrame_ = textFrame_;
  }
  if (!keepTextFrame) {
    label.measuringTextFrame_ = nil;
  }

  STU_ASSERT(renderInfo_.mode != LabelRenderMode::drawInCAContext
             && (image_ || renderInfo_.mode == LabelRenderMode::tiledSublayer));

  RC<CGImage> cgImage;
  if (image_) {
    cgImage = image_.createCGImage();
    label.imageMayHaveBeenPurged_ = false;
    if (type() != Type::prerender) {
      label.image_ = std::move(image_);
    } else {
      label.image_ = image_;
    }
    label.registerAsLabelLayerThatHasImage();
  }
  label.setContents(renderInfo_, cgImage.get());

  if (!keepTextFrame) {
    if ((textFrameInfo_.flags & STUTextFrameHasLink) && !label.links_) {
      if (STUTextFrame* __unsafe_unretained const tf = textFrame_ ?: label.textFrame_) {
        const TextFrame& textFrame = textFrameRef(tf);
        label.links_ = STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
                         textFrame, label.textFrameOrigin_,
                         TextFrameScaleAndDisplayScale{textFrame, label.params_.displayScale()});
      }
    }
    if (label.textFrame_) {
      label.textFrame_ = nil;
    }
  }
}

void LabelRenderTask::finish_onMainThread(void* taskPointer) {
  STU_DEBUG_ASSERT(is_main_thread());
  LabelRenderTask& task = *down_cast<LabelRenderTask*>(taskPointer);
  task.isFinished_ = true;

  const auto assignTaskTo = [&task](LabelLayer& label) {
    STU_ASSERT(&task == label.task_);
    label.task_ = nullptr;
    if (!label.taskIsStale_) {
      STULabelLayer* NS_VALID_UNTIL_END_OF_SCOPE layer = label.self;
      task.assignResultTo(label);
      auto* const delegate = label.labelLayerDelegate_;
      label.didDisplayText(delegate);
    } else {
      task.copyLayoutInfoTo(label);
    }
  };

  if (task.type_ != Type::prerender) {
    if (LabelLayer* const label = task.label_) {
      assignTaskTo(*label);
    }
    task.destroyAndDeallocateNonPrerenderTask();
  } else {
    auto& prerender = down_cast<LabelPrerenderer&>(task);
    while (Optional<LabelLayer&> const optLabel = prerender.popLabelFromWaitingSet()) {
      assignTaskTo(*optLabel);
    }
    if (prerender.releaseReferenceAndReturnTrueIfItWasTheLast(Referers::task)) {
      prerender.destroyAndDeallocate();
    }
  }
}

} // namespace stu_label

/// MARK: - STULabelLayer

@implementation STULabelLayer {
  stu_label::LabelLayer impl;
};

bool STULabelLayerIsAttributed(const STULabelLayer* __nonnull self) {
  return self->impl.isAttributed();
}

auto LabelPrerenderer::WaitingLabelSetNode::get(LabelLayer& layer) -> WaitingLabelSetNode& {
  return layer.waitingSetNode_;
}

- (void)stu_didMoveToWindow:(UIWindow*)window {
  impl.didMoveToWindow(window);
}

const CGSize& STULabelLayerGetSize(const STULabelLayer* self) {
  return self->impl.size_;
}

CGFloat STULabelLayerGetScreenScale(const STULabelLayer* self) {
  return self->impl.screenScale();
}

const LabelParameters& STULabelLayerGetParams(const STULabelLayer* __nonnull self) {
  return self->impl.params();
}

NSInteger STULabelLayerGetMaximumNumberOfLines(const STULabelLayer* __nonnull self) {
  return self->impl.maxLineCount();
}

const LabelTextFrameInfo& STULabelLayerGetCurrentTextFrameInfo(STULabelLayer* __nonnull self) {
  return self->impl.currentTextFrameInfo();
}

Unretained<STUTextFrameOptions* __nonnull> stu_label::defaultLabelTextFrameOptions() {
  STU_STATIC_CONST_ONCE(STUTextFrameOptions*, defaultOptions,
                        [[STUTextFrameOptions alloc]
                            initWithBlock:^(STUTextFrameOptionsBuilder* builder) {
                              builder.maximumNumberOfLines = 1;
                              builder.textScalingBaselineAdjustment =
                                        STUBaselineAdjustmentAlignFirstBaseline;
                            }]);
  STU_ANALYZER_ASSUME(defaultOptions != nil);
  return defaultOptions;
}

- (bool)stu_alwaysUsesContentSublayer {
  return impl.params().alwaysUsesContentSublayer;
}
- (void)stu_setAlwaysUsesContentSublayer:(bool)alwaysUsesContentSublayer {
  impl.setAlwaysUsesContentSublayer(alwaysUsesContentSublayer);
}

- (nullable CALayer*)stu_contentSublayer {
  return impl.contentSublayer();
}

/// MARK: - Overridden methods

- (instancetype)init {
  if ((self = [super init])) {
    impl.init(self);
  }
  return self;
}

- (instancetype)initWithLayer:(id)layer {
  if ((self = [super initWithLayer:layer])) {
    impl.init(self);
  }
  return self;
}

STU_DISABLE_CLANG_WARNING("-Wimplicit-atomic-properties")
// These properties were declared as unavailable in the header.
@dynamic drawsAsynchronously;
@dynamic contentsGravity;
STU_REENABLE_CLANG_WARNING

- (void)setBounds:(CGRect)bounds {
  impl.setBounds(bounds);
}

- (void)setContentsGravity:(NSString* __unsafe_unretained)contentsGravity {
  impl.setContentsGravity(contentsGravity);
}

- (CGFloat)contentsScale {
  return impl.params().displayScale();
}
- (void)setContentsScale:(CGFloat)scale {
  impl.setContentsScale(scale);
}

- (void)setContentsFormat:(NSString* __unsafe_unretained)contentsFormat {
  impl.setContentsFormat(contentsFormat);
}

- (void)setOpaque:(BOOL)opaque {
  impl.setOpaque(opaque);
}

@dynamic backgroundColor;

- (void)setBackgroundColor:(CGColorRef)backgroundColor {
  [self setDisplayedBackgroundColor:backgroundColor];
}

- (void)display {
  STU_ASSERT(is_main_thread());
  impl.display();
}

- (void)drawInContext:(CGContextRef)context {
  STU_ASSERT(is_main_thread());
  impl.drawInContext(context);
}

/// MARK: - Non-overridden methods

- (nullable NSObject<STULabelLayerDelegate>*)labelLayerDelegate {
  return impl.delegate();
}
- (void)setLabelLayerDelegate:(nullable NSObject<STULabelLayerDelegate>*)delegate {
  impl.setDelegate(delegate);
}

- (bool)displaysAsynchronously{
  return impl.displaysAsynchronously();
}
- (void)setDisplaysAsynchronously:(bool)displaysAsynchronously {
  impl.setDisplaysAsynchronously(displaysAsynchronously);
}

- (void)configureWithPrerenderer:(nonnull STULabelPrerenderer*)stuPrerenderer {
  STU_ASSERT(is_main_thread());
  impl.configureWithPrerenderer(stuPrerenderer);
}

- (NSAttributedString*)attributedText {
  return impl.attributedText();
}
- (void)setAttributedText:(nullable NSAttributedString*)attributedString {
  impl.setAttributedText(attributedString);
}

- (NSString*)text {
  return impl.text();
}
- (void)setText:(nullable NSString*)string {
  impl.setText(string);
}

- (UIFont*)font {
  return impl.font();
}
- (void)setFont:(nullable UIFont*)font {
  impl.setFont(font);
}

- (UIColor*)textColor {
  return impl.textColor();
}
- (void)setTextColor:(nullable UIColor* __unsafe_unretained)textColor {
  impl.setTextColor(textColor);
}

- (NSTextAlignment)textAlignment {
  return impl.textAlignment();
}
- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  impl.setTextAlignment(textAlignment);
}

- (STULabelDefaultTextAlignment)defaultTextAlignment {
  return impl.defaultTextAlignment();
}
- (void)setDefaultTextAlignment:(STULabelDefaultTextAlignment)defaultTextAlignment {
  impl.setDefaultTextAlignment(defaultTextAlignment);
}

- (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirection {
  return impl.userInterfaceLayoutDirection();
}
- (void)setUserInterfaceLayoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection {
  impl.setUserInterfaceLayoutDirection(layoutDirection);
}

- (STUShapedString*)shapedText {
  return impl.shapedText().unretained;
}
- (void)setShapedText:(nullable STUShapedString*)shapedString {
  impl.setShapedText(shapedString);
}

- (STULabelVerticalAlignment)verticalAlignment {
  return impl.params().verticalAlignment;
}
- (void)setVerticalAlignment:(STULabelVerticalAlignment)verticalAlignment {
  impl.setVerticalAlignment(verticalAlignment);
}

- (UIEdgeInsets)contentInsets {
  return impl.contentInsets();
}
- (void)setContentInsets:(UIEdgeInsets)contentInsets {
  impl.setContentInsets(contentInsets);
}

- (STUDirectionalEdgeInsets)directionalContentInsets {
  return impl.directionalContentInsets();
}
- (void)setDirectionalContentInsets:(STUDirectionalEdgeInsets)directionalInsets {
  impl.setDirectionalContentInsets(directionalInsets);
}

- (bool)clipsContentToBounds {
  return impl.params().clipsContentToBounds;
}
- (void)setClipsContentToBounds:(bool)clipsContentToBounds {
  impl.setClipsContentToBounds(clipsContentToBounds);
}

- (void)setTextFrameOptions:(nullable STUTextFrameOptions*)options {
  impl.setTextFrameOptions(options);
}

- (STUTextLayoutMode)textLayoutMode {
  return impl.textLayoutMode();
}
- (void)setTextLayoutMode:(STUTextLayoutMode)textLayoutMode {
  impl.setTextLayoutMode(textLayoutMode);
}

- (NSInteger)maximumNumberOfLines {
  return impl.maxLineCount();
}
- (void)setMaximumNumberOfLines:(NSInteger)maximumNumberOfLines {
  impl.setMaxLineCount(maximumNumberOfLines);
}

- (STULastLineTruncationMode)lastLineTruncationMode {
  return impl.lastLineTruncationMode();
}
- (void)setLastLineTruncationMode:(STULastLineTruncationMode)lastLineTruncationMode {
   impl.setLastLineTruncationMode(lastLineTruncationMode);
}

- (nullable NSAttributedString*)truncationToken {
  return impl.truncationToken();
}
- (void)setTruncationToken:(nullable NSAttributedString* __unsafe_unretained)truncationToken {
  impl.setTruncationToken(truncationToken);
}

- (nullable STUTruncationRangeAdjuster)truncationRangeAdjuster {
  return impl.truncationRangeAdjuster();
}
- (void)setTruncationRangeAdjuster:(nullable STUTruncationRangeAdjuster)truncationRangeAdjuster {
  impl.setTruncationRangeAdjuster(truncationRangeAdjuster);
}

- (CGFloat)minimumTextScaleFactor {
  return impl.minTextScaleFactor();
}
- (void)setMinimumTextScaleFactor:(CGFloat)minimumTextScaleFactor {
  impl.setMinTextScaleFactor(minimumTextScaleFactor);
}

- (CGFloat)textScaleFactorStepSize {
  return impl.textScaleFactorStepSize();
}
- (void)setTextScaleFactorStepSize:(CGFloat)textScaleFactorStepSize {
  impl.setTextScaleFactorStepSize(textScaleFactorStepSize);
}

- (STUBaselineAdjustment)textScalingBaselineAdjustment {
  return impl.textScalingBaselineAdjustment();
}
- (void)setTextScalingBaselineAdjustment:(STUBaselineAdjustment)baselineAdjustment {
  impl.setTextScalingBaselineAdjustment(baselineAdjustment);
}

- (nullable STULastHyphenationLocationInRangeFinder)lastHyphenationLocationInRangeFinder {
  return impl.lastHyphenationLocationInRangeFinder();
}
- (void)setLastHyphenationLocationInRangeFinder:(nullable STULastHyphenationLocationInRangeFinder)
                                                   finder
{
  impl.setLastHyphenationLocationInRangeFinder(finder);
}

- (nullable CGColorRef)displayedBackgroundColor {
  return impl.params().backgroundColor();
}
- (void)setDisplayedBackgroundColor:(nullable CGColorRef)backgroundColor {
  impl.setDisplayedBackgroundColor(backgroundColor);
}

- (bool)isHighlighted {
  return impl.params().isHighlighted();
}
- (void)setHighlighted:(bool)highlighted {
  impl.setIsHighlighted(highlighted);
}

- (nullable STUTextHighlightStyle*)highlightStyle {
  return impl.params().highlightStyle().unretained;
}
- (void)setHighlightStyle:(nullable STUTextHighlightStyle*)highlightStyle {
  impl.setHighlightStyle(highlightStyle);
}

- (STUTextRange)highlightRange {
  return impl.params().highlightRange();
}
- (void)setHighlightRange:(STUTextRange)highlightRange {
  return impl.setHighlightRange(highlightRange.range, highlightRange.type);
}
- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType {
  impl.setHighlightRange(range, rangeType);
}

- (bool)overrideColorsApplyToHighlightedText {
  return impl.params().overrideColorsApplyToHighlightedText();
}
- (void)setOverrideColorsApplyToHighlightedText:(bool)overrideColorsApplyToHighlightedText {
  impl.setOverrideColorsApplyToHighlightedText(overrideColorsApplyToHighlightedText);
}

- (nullable UIColor*)overrideTextColor {
  return impl.params().overrideTextColor().unretained;
}
- (void)setOverrideTextColor:(nullable UIColor* __unsafe_unretained)overrideTextColor {
  impl.setOverrideTextColor(overrideTextColor);
}

- (nullable UIColor*)overrideLinkColor {
  return impl.params().overrideLinkColor().unretained;
}
- (void)setOverrideLinkColor:(nullable UIColor* __unsafe_unretained)overrideLinkColor {
  impl.setOverrideLinkColor(overrideLinkColor);
}

- (nullable STULabelDrawingBlock)drawingBlock {
  return impl.params().drawingBlock;
}
- (void)setDrawingBlock:(nullable STULabelDrawingBlock __unsafe_unretained)drawingBlock {
  impl.setDrawingBlock(drawingBlock);
}

- (STULabelDrawingBlockColorOptions)drawingBlockColorOptions {
  return impl.params().drawingBlockColorOptions;
}
- (void)setDrawingBlockColorOptions:(STULabelDrawingBlockColorOptions)drawingBlockColorOptions {
  impl.setDrawingBlockColorOptions(drawingBlockColorOptions);
}

- (STULabelDrawingBounds)drawingBlockImageBounds {
  return impl.params().drawingBlockImageBounds;
}
- (void)setDrawingBlockImageBounds:(STULabelDrawingBounds)drawingBounds {
  impl.setDrawingBlockImageBounds(drawingBounds);
}

- (bool)neverUsesGrayscaleBitmapFormat {
  return impl.params().neverUseGrayscaleBitmapFormat;
}
- (void)setNeverUsesGrayscaleBitmapFormat:(bool)neverUsesGrayscaleBitmapFormat {
  impl.setNeverUsesGrayscaleBitmapFormat(neverUsesGrayscaleBitmapFormat);
}

- (bool)neverUsesExtendedRGBBitmapFormat {
  return impl.params().neverUsesExtendedRGBBitmapFormat;
}
- (void)setNeverUsesExtendedRGBBitmapFormat:(bool)neverUsesExtendedRGBBitmapFormat {
  impl.setNeverUsesExtendedRGBBitmapFormat(neverUsesExtendedRGBBitmapFormat);
}

- (bool)releasesShapedStringAfterRendering {
  return impl.params().releasesShapedStringAfterRendering;
}
- (void)setReleasesShapedStringAfterRendering:(bool)releasesShapedStringAfterRendering  {
  impl.setReleasesShapedStringAfterRendering(releasesShapedStringAfterRendering);
}

- (bool)releasesTextFrameAfterRendering {
  return impl.params().releasesTextFrameAfterRendering;
}
- (void)setReleasesTextFrameAfterRendering:(bool)releasesTextFrameAfterRendering {
  impl.setReleasesTextFrameAfterRendering(releasesTextFrameAfterRendering);
}

- (CGSize)sizeThatFits:(CGSize)size {
  return impl.sizeThatFits(size);
}

- (STULabelLayoutInfo)layoutInfo {
  return impl.layoutInfo();
}

- (STUTextLinkArray*)links {
  return impl.links().unretained;
}

- (STUTextFrame*)textFrame {
  return impl.textFrame().unretained;
}

- (CGPoint)textFrameOrigin {
  return impl.textFrameOrigin();
}

STU_EXPORT
STUTextFrameWithOrigin STULabelLayerGetTextFrameWithOrigin(STULabelLayer* __unsafe_unretained self) {
  return {self->impl.textFrame().unretained, self->impl.textFrameOrigin(),
          .displayScale = self->impl.params().displayScale()};
};

@end
