// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyleBuffer.hpp"

#import "STULabel/STUTextAttributes-Internal.hpp"

#import "Color.hpp"
#import "InputClamping.hpp"
#import "Hash.hpp"
#import "NSAttributedStringRef.hpp"
#import "Once.hpp"
#import "UnicodeCodePointProperties.hpp"

#import <stddef.h>

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

NSString* const STUOriginalFontAttributeName = @"STUOriginalFont";

static Class uiColorClass;
static UIColor* uiColorBlack;
static Class uiFontClass;

STU_INLINE
void ensureConstantsAreInitialized() {
  static dispatch_once_t once;
  dispatch_once_f(&once, nullptr, [](void *) {
    uiColorClass = UIColor.class;
    uiColorBlack = UIColor.blackColor;
    uiFontClass = UIFont.class;
  });
}

struct AttributeScanContext {
  enum Flags {
    hasFont               = 1 <<  0,
    hasBackground         = 1 <<  1,
    hasBackgroundColor    = 1 <<  2,
    hasBaselineOffset     = 1 <<  3,
    hasForegroundColor    = 1 <<  4,
    hasLink               = 1 <<  5,
    hasNSTextAttachment   = 1 <<  6,
    hasRunDelegate        = 1 <<  7,
    hasShadow             = 1 <<  8,
    hasStrikethroughStyle = 1 <<  9,
    hasStrikethroughColor = 1 << 10,
    hasStrokeColor        = 1 << 11,
    hasStrokeWidth        = 1 << 12,
    hasTextAttachment     = 1 << 13,
    hasUnderlineStyle     = 1 << 14,
    hasUnderlineColor     = 1 << 15,

    hasFixForRdar36622225 = 1 << 16
  };

  Flags flags;
  TextStyleBuffer::ParagraphAttributes* paraAttributes;

  UIFont*  __unsafe_unretained                font;
  UIColor* __unsafe_unretained                foregroundColor;
  UIColor* __unsafe_unretained                backgroundColor;
  STUBackgroundAttribute* __unsafe_unretained background;
  Float32                                     baselineOffset;
  NSShadow* __unsafe_unretained               shadow;
  NSUnderlineStyle                            underlineStyle;
  UIColor* __unsafe_unretained                underlineColor;
  NSUnderlineStyle                            strikethroughStyle;
  UIColor* __unsafe_unretained                strikethroughColor;
  CGFloat                                     strokeWidth;
  UIColor* __unsafe_unretained                strokeColor;
  STUTextAttachment* __unsafe_unretained      textAttachment;
  CTRunDelegateRef                            runDelegate;
  NSTextAttachment* __unsafe_unretained       nsTextAttachment;
  id __unsafe_unretained                      link;

  static void scanAttribute(const void* key, const void* value, void* context);

  void scan(NSDictionary<NSString*, id>* __unsafe_unretained __nullable attributes) {
    if (attributes) {
      CFDictionaryApplyFunction((__bridge CFDictionaryRef)attributes, scanAttribute, this);
    }
  }
};

} // namespace stu_label

template <> struct stu::IsOptionsEnum<stu_label::AttributeScanContext::Flags> : stu::True {};

namespace stu_label {

// The NSAttributedStringKey instances are usually the static contants defined by UIKit, so we can
// often avoid a string comparison by doing some pointer comparisons first.

STU_INLINE
bool equal(NSString* __unsafe_unretained key, NSString* __unsafe_unretained string) {
  return key == string
      || CFEqual((__bridge CFStringRef)key, (__bridge CFStringRef)string);
}

STU_INLINE
bool equalAndNot(NSString* __unsafe_unretained key,
                 NSString* __unsafe_unretained equalKey,
                 NSString* __unsafe_unretained unequalKey)
{
  return key == equalKey
      || (key != unequalKey
          && CFEqual((__bridge CFStringRef)key, (__bridge CFStringRef)equalKey));
}

STU_INLINE
bool equalAndNot(NSString* __unsafe_unretained key,
                 NSString* __unsafe_unretained equalKey,
                 NSString* __unsafe_unretained unequalKey1,
                 NSString* __unsafe_unretained unequalKey2)
{
  return key == equalKey
      || (key != unequalKey1 && key != unequalKey2
          && CFEqual((__bridge CFStringRef)key, (__bridge CFStringRef)equalKey));
}

STU_INLINE
bool equalAndNot(NSString* __unsafe_unretained key,
                 NSString* __unsafe_unretained equalKey,
                 NSString* __unsafe_unretained unequalKey1,
                 NSString* __unsafe_unretained unequalKey2,
                 NSString* __unsafe_unretained unequalKey3)
{
  return key == equalKey
      || (key != unequalKey1 && key != unequalKey2 && key != unequalKey3
          && CFEqual((__bridge CFStringRef)key, (__bridge CFStringRef)equalKey));
}

void AttributeScanContext::scanAttribute(const void* keyPointer, const void* value, void* ctx) {
  using Context = AttributeScanContext;
  AttributeScanContext& context = *down_cast<AttributeScanContext*>(ctx);
  if (!value) return;
  NSString* __unsafe_unretained const key = (__bridge NSString*)keyPointer;
  const Int keyLength = CFStringGetLength((__bridge CFStringRef)key);
  switch (keyLength) {
  case 6: // NSFont
          // NSLink
    if (equalAndNot(key, NSFontAttributeName, NSLinkAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiFontClass],
                    "Invalid attribute value for NSFontAttributeName in NSAttributedString.");
      if (!(context.flags & Context::hasFont)) { // STUOriginalFont takes precedence.
        context.flags |= Context::hasFont;
        context.font = (__bridge UIFont*)value;
      }
      return;
    }
    if (equal(key, NSLinkAttributeName)) {
      context.flags |= Context::hasLink;
      context.link = (__bridge id)value;
      return;
    }
    break;
  case 7: // NSColor
    if (equal(key, NSForegroundColorAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiColorClass],
                    "Invalid attribute value for NSForegroundColorAttributeName in NSAttributedString.");
      context.flags |= Context::hasForegroundColor;
      context.foregroundColor = (__bridge UIColor*)value;
      return;
    }
    break;
  case 8: // NSShadow
    if (equal(key, NSShadowAttributeName)) {
      STU_STATIC_CONST_ONCE(Class, nsShadowClass, NSShadow.class);
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:nsShadowClass],
                    "Invalid attribute value for NSShadowAttributeName in NSAttributedString.");
      context.flags |= Context::hasShadow;
      context.shadow = (__bridge NSShadow*)value;
      return;
    }
    break;
  case 11: // NSUnderline
    if (equal(key, NSUnderlineStyleAttributeName)) {
      STU_CHECK_MSG(CFNumberGetValue((CFNumberRef)value, kCFNumberNSIntegerType,
                                     &context.underlineStyle),
                    "Invalid attribute value for NSUnderlineStyleAttributeName in NSAttributedString.");
      context.flags |= Context::hasUnderlineStyle;
      return;
    }
    break;
  case 12: // NSAttachment
    if (equal(key, NSAttachmentAttributeName)) {
      STU_STATIC_CONST_ONCE(Class, nsTextAttachmentClass, NSTextAttachment.class);
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:nsTextAttachmentClass],
                    "Invalid attribute value for NSAttachmentAttributeName in NSAttributedString.");
      context.flags |= Context::hasNSTextAttachment;
      context.nsTextAttachment = (__bridge NSTextAttachment*)value;
      return;
    }
    break;
  case 13: // STUBackground
           // CTRunDelegate
           // NSStrokeWidth
           // NSStrokeColor
    if (equalAndNot(key, STUBackgroundAttributeName,
                    (__bridge NSString*)kCTRunDelegateAttributeName,
                    NSStrokeWidthAttributeName, NSStrokeColorAttributeName))
    {
      STU_STATIC_CONST_ONCE(Class, stuBackgroundAttributeClass, STUBackgroundAttribute.class);
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:stuBackgroundAttributeClass],
                    "Invalid attribute value for STUBackgroundAttributeName in NSAttributedString.");
      context.flags |= Context::hasBackground;
      context.background = (__bridge STUBackgroundAttribute*)value;
      return;
    }
    if (equalAndNot(key, (__bridge NSString*)kCTRunDelegateAttributeName,
                    NSStrokeWidthAttributeName, NSStrokeColorAttributeName))
    {
      STU_STATIC_CONST_ONCE(CFTypeID, ctRunDelegateTypeID, CTRunDelegateGetTypeID());
      STU_CHECK_MSG(CFGetTypeID(value) == ctRunDelegateTypeID,
                    "Invalid attribute value for kCTRunDelegateAttributeName in NSAttributedString.");
      context.flags |= Context::hasRunDelegate;
      context.runDelegate = (CTRunDelegateRef)value;
      return;
    }

    if (equalAndNot(key, NSStrokeWidthAttributeName, NSStrokeColorAttributeName)) {
      context.flags |= Context::hasStrokeWidth;
      context.strokeWidth = cgFloatFromNumber((__bridge NSNumber*)value);
      return;
    }
    if (equal(key, NSStrokeColorAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiColorClass],
                    "Invalid attribute value for NSStrokeColorAttributeName in NSAttributedString.");
      context.flags |= Context::hasStrokeColor;
      context.strokeColor = (__bridge UIColor*)value;
      return;
    }
    break;
  case 15: // STUOriginalFont
           // NSStrikethrough
    if (key == STUOriginalFontAttributeName) {
      // This attribute is only internally generated, so we shouldn't need a type check here.
      STU_DEBUG_ASSERT([(__bridge id)value isKindOfClass:uiFontClass]);
      context.flags |= Context::hasFont;
      context.font = (__bridge UIFont*)value;
      return;
    }
    if (equal(key, NSStrikethroughStyleAttributeName)) {
      STU_CHECK_MSG(CFNumberGetValue((CFNumberRef)value, kCFNumberNSIntegerType,
                                     &context.strikethroughStyle),
                    "Invalid attribute value for NSStrikethroughStyleAttributeName in NSAttributedString.");
      context.flags |= Context::hasStrikethroughStyle;
      return;
    }
    break;
  case 16: // NSParagraphStyle
           // NSUnderlineColor
           // NSBaselineOffset
    if (equalAndNot(key, NSParagraphStyleAttributeName,
                    NSUnderlineColorAttributeName, NSBaselineOffsetAttributeName)) {
      if (context.paraAttributes) {
        STU_STATIC_CONST_ONCE(Class, nsParagraphStyleClass, NSParagraphStyle.class);
        STU_CHECK_MSG([(__bridge id)value isKindOfClass:nsParagraphStyleClass],
                      "Invalid attribute value for NSParagraphStyleAttributeName in NSAttributedString.");
        context.paraAttributes->style = (__bridge NSParagraphStyle*)value;
      }
      return;
    }
    if (equalAndNot(key, NSUnderlineColorAttributeName, NSBaselineOffsetAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiColorClass],
                    "Invalid attribute value for NSUnderlineColorAttributeName in NSAttributedString.");
      context.flags |= Context::hasUnderlineColor;
      context.underlineColor = (__bridge UIColor*)value;
      return;
    }
    if (equal(key, NSBaselineOffsetAttributeName)) {
      context.baselineOffset = [(__bridge NSNumber*)value floatValue];
      context.flags |= Context::hasBaselineOffset;
      return;
    }
    break;
  case 17: // NSBackgroundColor
           // STUTextAttachment
    if (equalAndNot(key, NSBackgroundColorAttributeName, STUAttachmentAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiColorClass],
                    "Invalid object for NSBackgroundColorAttributeName in NSAttributedString.");
      context.flags |= Context::hasBackgroundColor;
      context.backgroundColor = (__bridge UIColor*)value;
      return;
    }
    if (equal(key, STUAttachmentAttributeName)) {
      STU_STATIC_CONST_ONCE(Class, stuTextAttachmentClass, STUTextAttachment.class);
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:stuTextAttachmentClass],
                    "Invalid object for STUAttachmentAttributeName in NSAttributedString.");
      context.flags |= Context::hasTextAttachment;
      context.textAttachment = (__bridge STUTextAttachment*)value;
      return;
    }
    break;
  case 18: // STUTruncationScope
           // NSWritingDirection
    if (equalAndNot(key, STUTruncationScopeAttributeName, NSWritingDirectionAttributeName)) {
      if (context.paraAttributes) {
        STU_STATIC_CONST_ONCE(Class, stuTruncationScopeClass, STUTruncationScope.class);
        STU_CHECK_MSG([(__bridge id)value isKindOfClass:stuTruncationScopeClass],
                      "Invalid object for STUTruncationScopeAttributeName in NSAttributedString.");
        context.paraAttributes->truncationScope = (__bridge STUTruncationScope*)value;
      }
      return;
    }
    if (equal(key, NSWritingDirectionAttributeName)) {
      if (context.paraAttributes) {
        context.paraAttributes->hasWritingDirectionAttribute = true;
      }
      return;
    }
    break;  
  case 20: // NSStrikethroughColor
    if (equal(key, NSStrikethroughColorAttributeName)) {
      STU_CHECK_MSG([(__bridge id)value isKindOfClass:uiColorClass],
                    "Invalid strikethrough color object in NSAttributedString.");
      context.flags |= Context::hasStrikethroughColor;
      context.strikethroughColor = (__bridge UIColor*)value;
      return;
    }
    break;
  case 22: // STUParagraphExtraStyle
    if (equal(key, STUParagraphStyleAttributeName)) {
      if (context.paraAttributes) {
        STU_STATIC_CONST_ONCE(Class, stuParagraphStyleAttributeClass, STUParagraphStyle.class);
        STU_CHECK_MSG([(__bridge id)value isKindOfClass:stuParagraphStyleAttributeClass],
                      "Invalid object for STUParagraphStyleAttribute in NSAttributedString.");
        context.paraAttributes->extraStyle = &((__bridge STUParagraphStyle*)value)->_style;
      }
      return;
    }
    break;
  case 23: // Fix for rdar://36622225
    if (equal(key, fixForRDAR36622225AttributeName)) {
      context.flags |= hasFixForRdar36622225;
      return;
    }
    break;
  default:
    break;
  }
}

STU_NO_INLINE
FontIndex TextStyleBuffer::addFont(FontRef font) {
  // We use the pointer identity here, but we don't rely on the uniqueness of the fonts identified
  // by font indices, so this should be a safe optimization.
  const CTFont* const ctFont = font.ctFont();
  UInt16 newIndex;
  if (fontIndices_.count() == 0) {
    UInt16 i = 0;
    for (const FontRef& f : fonts_) {
      if (ctFont == f.ctFont()) return FontIndex{i};
      ++i;
    }
    newIndex = narrow_cast<UInt16>(fonts_.count());
    if (fonts_.count() == 15) {
      fontIndices_.initializeWithBucketCount(64);
      i = 0;
      for (const FontRef& f : fonts_) {
        fontIndices_.insertNew(hashPointer(f.ctFont()), i);
        ++i;
      }
      fontIndices_.insertNew(hashPointer(ctFont), newIndex);
    }
  } else {
    newIndex = narrow_cast<UInt16>(fontIndices_.count());
    if (STU_UNLIKELY(newIndex == maxFontCount)) { // This shouldn't happen in practice.
      return FontIndex{};
    }
    if (const auto [i, inserted] = fontIndices_.insert(hashPointer(ctFont), newIndex,
                                     [&](UInt16 index) { return fonts_[index].ctFont() == ctFont; });
        !inserted)
    {
      return FontIndex{i};
    }
  }
  fonts_.append(font);
  return FontIndex{newIndex};
}

STU_NO_INLINE
ColorIndex TextStyleBuffer::addColor(UIColor* __unsafe_unretained uiColor) {
  if (uiColor == uiColorBlack) { // UIKit caches UIColor.blackColor
    return ColorIndex::black;
  }
  const UInt16 offset = ColorIndex::fixedColorIndexRange.end;
  CGColor* const cgColor = stu_label::cgColor(uiColor);
  if (colors_.count() <= 16) {
    UInt16 i1 = offset;
    for (const ColorRef& c : colors()) { // May iterate over oldColors_.
      // Only compares pointers.
      if (cgColor == c.cgColor()) return ColorIndex{i1};
      ++i1;
    }
  }
  Optional<RGBA> rgba = RGBA::of(uiColor);
  const ColorFlags colorFlags = rgba ? stu_label::colorFlags(*rgba) : ColorFlags::isNotGray;
  if (colorFlags & ColorFlags::isBlack) {
    return ColorIndex::black;
  }
  if (STU_UNLIKELY(colorIndices_.count() == 0)) {
    if (oldColors_.first.isEmpty()) {
      colorIndices_.initializeWithBucketCount(16);
    } else {
      colorIndices_.initializeWithExistingBuckets(oldColors_.second);
      colors_.append(oldColors_.first);
      oldColors_ = pair(ArrayRef<ColorRef>{}, ArrayRef<const ColorHashBucket>{});
    }
  }
  if (STU_UNLIKELY(colorIndices_.count() == maxFontCount)) { // Shouldn't happen in practice.
    return ColorIndex::black;
  }
  static_assert(maxFontCount <= maxValue<UInt16> - offset);
  const UInt16 newIndex = narrow_cast<UInt16>(colorIndices_.count() + offset);
  const auto hashCode = rgba ? hash(rgba->red, rgba->green, rgba->blue, rgba->alpha)
                             : HashCode{static_cast<UInt64>(colorFlags)};
  if (const auto [i, inserted] = colorIndices_.insert(hashCode, newIndex,
                                   [&](UInt16 index) { return CGColorEqualToColor(
                                                            cgColor, colors_[index - offset].cgColor());
                                                 });
      !inserted)
  {
    return ColorIndex{i};
  }
  colors_.append(ColorRef{cgColor, colorFlags});
  return ColorIndex{newIndex};
}

STU_INLINE
TextFlags TextStyleBuffer::colorFlags(ColorIndex colorIndex) const {
  return colorIndex == ColorIndex::black ? TextFlags{}
       : colors()[colorIndex.value - ColorIndex::fixedColorIndexRange.end].textFlags();
}

TextFlags TextStyleBuffer::encodeStringRangeStyle(
            Range<Int> range,
            NSDictionary<NSAttributedStringKey, id>* __unsafe_unretained __nullable attributes,
            Optional<Out<ParagraphAttributes>> outParaAttributes)
{
  STU_ASSERT(range.start == nextUTF16Index_ && range.start < range.end);
  nextUTF16Index_ = narrow_cast<Int32>(range.end);

  ensureConstantsAreInitialized();

  using Context = AttributeScanContext;

  Context context;
  // Only zero-initialize fields that may be accessed without checking the corresponding flag.
  context.flags = Context::Flags{};
  context.paraAttributes = static_cast<ParagraphAttributes*>(outParaAttributes);
  context.background = nil;
  context.link = nil;
  context.textAttachment = nil;
  if (outParaAttributes) {
    *outParaAttributes = ParagraphAttributes{};
  }

  context.scan(attributes);

  if (STU_UNLIKELY(data_.capacity() == 0)) {
    fonts_.setCapacity(8);
    colors_.setCapacity(8);
    data_.setCapacity(256);
  }

  STU_DEBUG_ASSERT(lastStyleSize_ == 0
                   || reinterpret_cast<const Byte*>(lastStyle_) + lastStyleSize_ == data().end());
  void* next = data_.append(repeat(uninitialized, TextStyle::maxSize));
  lastStyle_ = reinterpret_cast<const TextStyle*>(reinterpret_cast<const Byte*>(next)
                                                  - lastStyleSize_);

  UIFont* __unsafe_unretained font = STU_LIKELY(context.flags & Context::hasFont)
                                   ? context.font : (__bridge UIFont*)defaultCoreTextFont();
  const FontIndex fontIndex = addFont(font);
  const ColorIndex textColorIndex = !(context.flags & Context::hasForegroundColor)
                                  ? ColorIndex::black
                                  : addColor(context.foregroundColor);
  TextFlags flags = colorFlags(textColorIndex);
                   // We use range.end here, so that the string index later can be safely
                   // adjusted upwards within the original range.
  const bool isBig = range.end > TextStyle::maxSmallStringIndex
                  || fontIndex.value > TextStyle::maxSmallFontIndex
                  || textColorIndex.value > TextStyle::maxSmallColorIndex;
  TextStyle* style;
  if (!isBig) {
    style = new (next) TextStyle{0};
    next = style + 1;
  } else {
    TextStyle::Big* const bigStyle = new (next) TextStyle::Big{0, fontIndex, textColorIndex};
    style = bigStyle;
    next = bigStyle + 1;
  }
  const Int firstInfoOffset = reinterpret_cast<Byte*>(next) - reinterpret_cast<Byte*>(style);
  if (context.flags & ~(Context::hasFont | Context::hasForegroundColor)) {

    if (context.flags & Context::hasLink) {
      flags |= TextFlags::hasLink;
      auto* const info = new (next) TextStyle::LinkInfo{context.link};
      next = info + 1;
    }

    // The style info data has to be written in ascending order of the associated flag's value.
    static_assert(TextFlags::hasBackground > TextFlags::hasLink);

    // STUBackground takes precedence over NSBackgroundColor
    if (context.flags & Context::hasBackground) {
      if (STU_UNLIKELY(context.background->_color == nil
                       && (context.background->_borderColor == nil
                           || context.background->_borderWidth <= 0)))
      {
        context.background = nil;
      } else {
        flags |= TextFlags::hasBackground;
        Optional<ColorIndex> colorIndex;
        if (context.background->_color) {
          colorIndex = addColor(context.background->_color);
          flags |= colorFlags(*colorIndex);
        }
        Optional<ColorIndex> borderColorIndex;
        if (context.background->_borderColor && context.background->_borderWidth > 0) {
          borderColorIndex = addColor(context.background->_borderColor);
          flags |= colorFlags(*borderColorIndex);
        }
        auto* const info = new (next) TextStyle::BackgroundInfo{
                                        .stuAttribute = context.background,
                                        .colorIndex = colorIndex,
                                        .borderColorIndex = borderColorIndex};
        next = info + 1;
      }
    } else if (context.flags & Context::hasBackgroundColor) {
      flags |= TextFlags::hasBackground;
      const ColorIndex colorIndex = addColor(context.backgroundColor);
      flags |= colorFlags(colorIndex);
      auto* const info = new (next) TextStyle::BackgroundInfo{.colorIndex = colorIndex};
      next = info + 1;
    }

    static_assert(TextFlags::hasShadow > TextFlags::hasBackground);

    if (context.flags & Context::hasShadow) {
      UIColor* const color = context.shadow.shadowColor;
      if (color) {
        flags |= TextFlags::hasShadow;
        const CGSize offset = context.shadow.shadowOffset;
        const CGFloat radius = context.shadow.shadowBlurRadius;
        const ColorIndex colorIndex = addColor(color);
        flags |= colorFlags(colorIndex);
        auto* const info = new (next) TextStyle::ShadowInfo{
                             .offsetX = narrow_cast<Float32>(clampFloatInput(offset.width)),
                             .offsetY = narrow_cast<Float32>(clampFloatInput(offset.height)),
                             .blurRadius = narrow_cast<Float32>(clampNonNegativeFloatInput(radius)),
                             .colorIndex = colorIndex};
        next = info + 1;
      }
    }

    static_assert(TextFlags::hasUnderline > TextFlags::hasShadow);

    const CachedFontInfo* cachedFontInfo = nullptr;
    if (context.flags & (Context::hasUnderlineStyle | Context::hasStrikethroughStyle)) {
      cachedFontInfo = &localFontInfoCache_[(__bridge CTFont*)font];
    }

    if ((context.flags & Context::hasUnderlineStyle) && (context.underlineStyle & 0xf)) {
      flags |= TextFlags::hasUnderline;
      Optional<ColorIndex> colorIndex;
      if (context.flags & Context::hasUnderlineColor) {
        colorIndex = addColor(context.underlineColor);
        flags |= colorFlags(*colorIndex);
      }
      auto* const info = new (next) TextStyle::UnderlineInfo{context.underlineStyle, colorIndex,
                                                             *cachedFontInfo};
      next = info + 1;
    }

    static_assert(TextFlags::hasStrikethrough > TextFlags::hasUnderline);

    if ((context.flags & Context::hasStrikethroughStyle) && (context.strikethroughStyle & 0xf)) {
      flags |= TextFlags::hasStrikethrough;
      Optional<ColorIndex> colorIndex;
      if (context.flags & Context::hasStrikethroughColor) {
        colorIndex = addColor(context.strikethroughColor);
        flags |= colorFlags(*colorIndex);
      }
      auto* const info = new (next) TextStyle::StrikethroughInfo{
                                      .colorIndex = colorIndex,
                                      .style = context.strikethroughStyle,
                                      .originalFontStrikethroughThickness =
                                         cachedFontInfo->strikethroughThickness
                                    };
      next = info + 1;
    }

    static_assert(TextFlags::hasStroke > TextFlags::hasStrikethrough);

    if (context.flags & Context::hasStrokeWidth) {
      const Float32 strokeWidth = narrow_cast<Float32>(
                                    (1/CGFloat(100))*clampFloatInput(context.strokeWidth)
                                    * CTFontGetSize((__bridge CTFont*)font));
      if (strokeWidth != 0) {
        flags |= TextFlags::hasStroke;
        Optional<ColorIndex> colorIndex;
        if (context.flags & Context::hasStrokeColor) {
          colorIndex = addColor(context.strokeColor);
          flags |= colorFlags(*colorIndex);
        }
        const bool doNotFill = strokeWidth >= 0;
        auto* const info = new (next) TextStyle::StrokeInfo{
                                        .strokeWidth = doNotFill ? strokeWidth : -strokeWidth,
                                        .doNotFill = doNotFill,
                                        .colorIndex = colorIndex};
        next = info + 1;
      }
    }

    static_assert(TextFlags::hasAttachment > TextFlags::hasStroke);


    if (context.flags & (Context::hasTextAttachment | Context::hasNSTextAttachment)) {
      if (!(context.flags & Context::hasTextAttachment)) {
        STUImageTextAttachment* const imageAttachment =
          [[STUImageTextAttachment alloc] initWithNSTextAttachment:context.nsTextAttachment
                                              stringRepresentation:nil];
        if (imageAttachment) {
          // This increment keeps the attachment alive until we insert it into the fixed
          // attributed string, see the fixAttachmentAttributesIn method below.
          incrementRefCount(imageAttachment); // ***
          context.textAttachment = imageAttachment;
          context.flags |= Context::hasTextAttachment;
          needToFixAttachmentAttributes_ = true;
        }
      }
      if (context.flags & Context::hasTextAttachment) {
        if (!(context.flags & Context::hasRunDelegate)
            || range.count() > 1) // rdar://36622225
        {
          needToFixAttachmentAttributes_ = true;
        }
        flags |= TextFlags::hasAttachment;
        const auto colorInfo = context.textAttachment->_colorInfo;
        if (!(colorInfo & STUTextAttachmentIsGrayscale)) {
          flags |= TextFlags::mayNotBeGrayscale;
          if (colorInfo & STUTextAttachmentUsesExtendedColors) {
            flags |= TextFlags::usesExtendedColor;
          }
        }
        auto* const info = new (next) TextStyle::AttachmentInfo{context.textAttachment};
        next = info + 1;
      }
    }

    static_assert(TextFlags::hasBaselineOffset > TextFlags::hasAttachment);

    if ((context.flags & Context::hasBaselineOffset)) {
      const Float32 baselineOffset = clampFloatInput(context.baselineOffset);
      if (baselineOffset != 0) {
        flags |= TextFlags::hasBaselineOffset;
        auto* const info = new (next) TextStyle::BaselineOffsetInfo{baselineOffset};
        next = info + 1;
      }
    }

  }
  const Int size = reinterpret_cast<Byte*>(next) - reinterpret_cast<Byte*>(style);
  STU_ASSERT(size <= TextStyle::maxSize);
  if (size == lastStyleSize_
      && flags == lastStyle_->flags()
      && fontIndex == lastStyle_->fontIndex()
      && textColorIndex == lastStyle_->colorIndex())
  {
    if (firstInfoOffset == size
        || memcmp(reinterpret_cast<Byte*>(style) + firstInfoOffset,
                  reinterpret_cast<const Byte*>(lastStyle_) + firstInfoOffset,
                  sign_cast(size - firstInfoOffset)) == 0)
    {
      data_.removeLast(TextStyle::maxSize);
      if ((flags & TextFlags::hasAttachment) && !context.hasFixForRdar36622225) {
        needToFixAttachmentAttributes_ = true; // rdar://36622225
      }
      return flags;
    }
  }
  data_.removeLast(TextStyle::maxSize - size);

  const UInt offsetToNextDiv4 = sign_cast(size)/4;
  const UInt offsetFromPreviousDiv4 = lastStyleSize_/4;

  style->bits = isBig
              | (static_cast<UInt64>(flags) << TextStyle::BitIndex::flags)
              | (UInt64{offsetFromPreviousDiv4} << TextStyle::BitIndex::offsetFromPreviousDiv4)
              | (UInt64{offsetToNextDiv4} << TextStyle::BitIndex::offsetToNextDiv4)
              | (UInt64(range.start) << TextStyle::BitIndex::stringIndex)
              | (isBig ? 0 : (UInt64{fontIndex.value} << TextStyle::BitIndex::Small::font))
              | (isBig ? 0 : (UInt64{textColorIndex.value} << TextStyle::BitIndex::Small::color));

  lastStyle_ = style;
  lastStyleSize_ = narrow_cast<UInt8>(size);

  return flags;
}

void TextStyleBuffer::addStringTerminatorStyle() {
  const Int32 index = nextUTF16Index_;
  const Int size = TextStyle::sizeOfTerminatorWithStringIndex(index);
  const UInt8 offsetFromPreviousDiv4 = lastStyleSize_/4;
  Byte* p = data_.append(repeat(uninitialized, size));
  TextStyle::writeTerminatorWithStringIndex(index, p - offsetFromPreviousDiv4*4, ArrayRef{p, size});
  lastStyle_ = nil;
  lastStyleSize_ = 0;
  nextUTF16Index_ = 0;
}

TextFlags TextStyleBuffer::encode(NSAttributedString* __unsafe_unretained nsAttributedString) {
  const NSAttributedStringRef attributedString{nsAttributedString};
  TextFlags flags = {};
  for (Range<Int> range = {}; range.end < attributedString.string.count();) {
    NSDictionary<NSString*, id>* const attributes =
      attributedString.attributesAtIndex(range.end, OutEffectiveRange{range});
    flags |= encodeStringRangeStyle(range, attributes, none);
  }
  addStringTerminatorStyle();
  return flags;
}

STU_NO_INLINE
void TextStyleBuffer
     ::fixAttachmentAttributesIn(NSMutableAttributedString* __nonnull attributedString)
{
  STU_DEBUG_ASSERT(needToFixAttachmentAttributes_);
  __unsafe_unretained NSAttributedStringKey const runDelegateKey =
    (__bridge NSAttributedStringKey)kCTRunDelegateAttributeName;

  needToFixAttachmentAttributes_ = false;
  const TextStyle* style = reinterpret_cast<const TextStyle*>(data().begin());
  for (;;) {
    const TextStyle& nextStyle = style->next();
    if (style == &nextStyle) break;
    if (auto* info = style->attachmentInfo()) {
      const NSRange stringRange = NSRange(Range{style->stringIndex(), nextStyle.stringIndex()});
      const STUTextAttachment* __unsafe_unretained const attachment = info->attribute;
      const auto attributes = [attributedString attributesAtIndex:stringRange.location
                                                   effectiveRange:nil];
      if (![attributes objectForKey:STUAttachmentAttributeName]) {
        [attributedString addAttributes:@{STUAttachmentAttributeName: attachment,
                                          runDelegateKey: [attachment newCTRunDelegate]}
                                  range:stringRange];
        decrementRefCount(attachment); // See the line above marked with ***.
      } else if (![attributes objectForKey:runDelegateKey]) {
        [attributedString addAttribute:runDelegateKey value:[attachment newCTRunDelegate]
                                 range:Range{stringRange.location, Count{1u}}];
      }
      for (UInt i = 1; i < stringRange.length; ++i) {
        [attributedString addAttributes:@{runDelegateKey: [attachment newCTRunDelegate],
                                          fixForRDAR36622225AttributeName: @(i)}
                                  range:Range{stringRange.location + i, Count{1u}}];
      }
    }
    style = &nextStyle;
  }
}

} // namespace stu_label
