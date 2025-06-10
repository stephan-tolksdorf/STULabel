// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttachment-Internal.hpp"

#import "Internal/InputClamping.hpp"
#import "Internal/NSAttributedStringRef.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"
#import "Internal/Rect.hpp"

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

STU_EXPORT
const NSAttributedStringKey STUAttachmentAttributeName = @"STUTextAttachment";

// https://openradar.appspot.com/radar?id=6173057961951232
const NSAttributedStringKey stu_label::fixForRDAR36622225AttributeName = @"Fix for rdar://36622225";

typedef void (* DrawMethod)(const STUTextAttachment*, SEL, CGContextRef, CGRect);

@implementation STUTextAttachment {
  DrawMethod _drawMethod;
}

- (nonnull instancetype)init NS_UNAVAILABLE  {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

static void clampTextAttachmentParameters(STUTextAttachment* __unsafe_unretained self) {
  self->_width = clampNonNegativeFloatInput(self->_width);
  self->_ascent = clampFloatInput(self->_ascent);
  self->_descent = clampFloatInput(self->_descent);
  if (STU_UNLIKELY(self->_ascent < -self->_descent)) {
    self->_ascent = (self->_ascent - self->_descent)/2;
    self->_descent = -self->_ascent;
  }
  self->_leading = clampNonNegativeFloatInput(self->_leading);
  self->_imageBounds = clampRectInput(self->_imageBounds);
  self->_colorInfo = self->_colorInfo & (  STUTextAttachmentIsGrayscale
                                         | STUTextAttachmentUsesExtendedColors);
}

static void initCommon(STUTextAttachment* __unsafe_unretained self) {
  clampTextAttachmentParameters(self);
  self->_metrics = FontMetrics{self->_ascent, self->_descent, self->_leading};
  const SEL selector = @selector(drawInContext:imageBounds:);
  self->_drawMethod = (DrawMethod)[self methodForSelector:selector];
  STU_STATIC_CONST_ONCE(DrawMethod, trivialDrawMethod,
                        (DrawMethod)class_getInstanceMethod(STUTextAttachment.class,
                                                            @selector(drawInContext:imageBounds:)));
  if (self->_drawMethod == trivialDrawMethod) {
    self->_drawMethod = nullptr;
  }
}


- (void)drawInContext:(CGContextRef __unused)context imageBounds:(CGRect __unused)imageBounds {
  // The base class draw method does nothing.
}

- (nonnull instancetype)initWithWidth:(CGFloat)width
                               ascent:(CGFloat)ascent
                              descent:(CGFloat)descent
                              leading:(CGFloat)leading
                          imageBounds:(CGRect)imageBounds
                            colorInfo:(STUTextAttachmentColorInfo)colorInfo
                 stringRepresentation:(nullable NSString*)stringRepresentation
{
  _width = width;
  _ascent = ascent;
  _descent = descent;
  _leading = leading;
  _imageBounds = imageBounds;
  _colorInfo = colorInfo;
  _stringRepresentation = stringRepresentation;
  initCommon(self);
  return self;
}

#define FOR_ALL_FIELD_NAMES(f) \
  f(width) \
  f(ascent) \
  f(descent) \
  f(leading) \
  f(imageBounds) \
  f(colorInfo) \
  f(stringRepresentation)

- (void)encodeWithCoder:(NSCoder*)coder {
#define ENCODE(name) encode(coder, @STU_STRINGIZE(name), _ ## name);
  FOR_ALL_FIELD_NAMES(ENCODE)
#undef ENCODE
  const bool isAccessible = self.isAccessibilityElement;
  encode(coder, @"isAccessibilityElement", isAccessible);
  if (isAccessible) {
    bool isAttributed = false;
    if (@available(iOS 11, tvOS 11, *)) {
      isAttributed = true;
    };
    encode(coder, @"hasAttributedAccessibilityStrings", isAttributed);
  #define ENCODE(name, attributedName) \
    if (isAttributed) { \
      if (NSAttributedString* const attributedString = self.attributedName) { \
        encode(coder, @STU_STRINGIZE(attributedName), attributedString); \
      } \
    } else { \
      if (NSString* const string = self.name) { \
        encode(coder, @STU_STRINGIZE(name), string); \
      } \
    }
    STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
    ENCODE(accessibilityLabel, accessibilityAttributedLabel)
    ENCODE(accessibilityHint, accessibilityAttributedHint)
    ENCODE(accessibilityValue, accessibilityAttributedValue)
    STU_REENABLE_CLANG_WARNING
  #undef ENCODE
    if (NSString* const string = self.accessibilityLanguage) {
      encode(coder, @"accessibilityLanguage", string);
    }
  }
}

+ (BOOL)supportsSecureCoding { return true; }

- (instancetype)initWithCoder:(NSCoder*)coder {
#define DECODE(name) decode(coder, @STU_STRINGIZE(name), Out{_ ## name});
  FOR_ALL_FIELD_NAMES(DECODE)
#undef DECODE
  bool isAccessible;
  decode(coder, @"isAccessibilityElement", Out{isAccessible});
  if (isAccessible) {
    self.isAccessibilityElement = true;
    bool isAttributed;
    decode(coder, @"hasAttributedAccessibilityStrings", Out{isAttributed});
    bool isIOS11 = false;
    if (@available(iOS 11, tvOS 11, *)) {
      isIOS11 = true;
    };

  #define DECODE(name, attributedName) \
    if (!isAttributed) { \
      NSString* string = nil; \
      decode(coder, @STU_STRINGIZE(name), Out{string}); \
      if (string) { \
        self.name = string; \
      } \
    } else { \
      NSAttributedString* attributedString = nil; \
      decode(coder, @STU_STRINGIZE(attributedName), Out{attributedString}); \
      if (attributedString) {\
        if (isIOS11) { \
          self.attributedName = attributedString; \
        } else { \
          self.name = attributedString.string; \
        } \
      } \
    }
    STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
    DECODE(accessibilityLabel, accessibilityAttributedLabel)
    DECODE(accessibilityHint, accessibilityAttributedHint)
    DECODE(accessibilityValue, accessibilityAttributedValue)
    STU_REENABLE_CLANG_WARNING
    {
      NSString* string = nil;
      decode(coder, @"accessibilityLanguage", Out{string});
      if (string) {
        self.accessibilityLanguage = string;
      }
    }
  #undef DECODE
  }
  initCommon(self);
  return self;
}

#undef FOR_ALL_FIELD_NAMES

- (CGFloat)width { return _width; }
- (CGFloat)ascent { return _ascent; }
- (CGFloat)descent { return _descent; }
- (CGFloat)leading { return _leading; }
- (CGRect)typographicBounds { return CGRect{{0, -(_ascent + _leading/2)},
                                            {_width, _ascent + _descent + _leading}}; }
- (CGRect)imageBounds { return _imageBounds; }
- (STUTextAttachmentColorInfo)colorInfo { return _colorInfo; }
- (nullable NSString*)stringRepresentation { return _stringRepresentation; }

static void STUTextAttachmentRunDelegateDealloc(void* attachment) {
  (void)(__bridge_transfer STUTextAttachment*)attachment; // Releases the attachment.
}

// Why does CoreText want separate functions for the ascent, descent and width?
// This seems both inefficient and inconvenient.

static CGFloat STUTextAttachmentRunDelegateGetAscent(void* attachment) {
  return ((__bridge STUTextAttachment*)attachment)->_ascent;
}

static CGFloat STUTextAttachmentRunDelegateGetDescent(void* attachment) {
  return ((__bridge STUTextAttachment*)attachment)->_descent;
}

static CGFloat STUTextAttachmentRunDelegateGetWidth(void* attachment) {
  return ((__bridge STUTextAttachment*)attachment)->_width;
}

static const CTRunDelegateCallbacks stuTextAttachmentRunDelegateCallbacks = {
  .version = kCTRunDelegateCurrentVersion,
  .dealloc = STUTextAttachmentRunDelegateDealloc,
  .getAscent = STUTextAttachmentRunDelegateGetAscent,
  .getDescent = STUTextAttachmentRunDelegateGetDescent,
  .getWidth = STUTextAttachmentRunDelegateGetWidth
};

- (nonnull id)newCTRunDelegate NS_RETURNS_RETAINED {
  return (__bridge_transfer id)CTRunDelegateCreate(&stuTextAttachmentRunDelegateCallbacks,
                                                   (void*)(__bridge_retained CFTypeRef)self);
}

void stu_label::drawAttachment(const STUTextAttachment* __unsafe_unretained self,
                               CGFloat xOffset, CGFloat baselineOffset, Int glyphCount,
                               DrawingContext& context)
{
  if (!self->_drawMethod) return;
  CGContext* const cgContext = context.cgContext();
  CGContextScaleCTM(cgContext, 1, -1);
  const auto guard = ScopeGuard{[&]{
    CGContextScaleCTM(cgContext, 1, -1);
  }};
  // We've already pushed the CGContext on the UIKit context stack in STUTextFrameDraw.
  STU_DEBUG_ASSERT(UIGraphicsGetCurrentContext() == cgContext);
  Point origin = context.lineOrigin();
  origin.x += xOffset;
  origin.y += baselineOffset;
  origin.y *= -1;
  origin += self->_imageBounds.origin();
  for (Int i = 0; i < glyphCount; ++i, origin.x += self->_width) {
    self->_drawMethod(self, @selector(drawInContext:imageBounds:), cgContext,
                      CGRect{origin, self->_imageBounds.size()});
  }
  context.currentCGContextColorsMayHaveChanged();
}

@end

@implementation STUImageTextAttachment {
  UIImage* _image;
}

- (nonnull instancetype)initWithImage:(nonnull UIImage*)image
                       verticalOffset:(CGFloat)baselineOffset
                 stringRepresentation:(nullable NSString*)stringRepresentation
{
  return [self initWithImage:image
                   imageSize:image.size
              verticalOffset:baselineOffset
                     padding:UIEdgeInsetsZero
                     leading:0
        stringRepresentation:stringRepresentation];
}

static STUTextAttachmentColorInfo attachmentColorInfoForColorSpace(CGColorSpaceRef colorSpace) {
  switch (CGColorSpaceGetModel(colorSpace)) {
  case kCGColorSpaceModelMonochrome:
    return STUTextAttachmentIsGrayscale;
  case kCGColorSpaceModelCMYK:
  case kCGColorSpaceModelLab:
    return STUTextAttachmentUsesExtendedColors;
  default:
    break;
  }
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wunguarded-availability"
  if (&CGColorSpaceIsWideGamutRGB && CGColorSpaceIsWideGamutRGB(colorSpace)) {
    return STUTextAttachmentUsesExtendedColors;
  }
  #pragma clang diagnostic pop
  return STUTextAttachmentColorInfo{};
}

- (nonnull instancetype)initWithImage:(nonnull UIImage*)image
                            imageSize:(CGSize)imageSize
                       verticalOffset:(CGFloat)verticalOffset
                              padding:(UIEdgeInsets)padding
                              leading:(CGFloat)leading
                 stringRepresentation:(nullable NSString*)stringRepresentation
{
  if (image == nil) return nil;

  imageSize = clampSizeInput(imageSize);
  verticalOffset = clampFloatInput(verticalOffset);
  padding = clampEdgeInsetsInput(padding);
  padding.left  = max(0.f, padding.left);
  padding.right = max(0.f, padding.right);
  const CGFloat minVerticalPadding = -imageSize.height/2;
  padding.top    = max(padding.top,    minVerticalPadding);
  padding.bottom = max(padding.bottom, minVerticalPadding);
  leading = clampNonNegativeFloatInput(leading);

  STUTextAttachmentColorInfo colorInfo{};
  if (const CGImageRef cgImage = image.CGImage) {
    if (const CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage)) {
      colorInfo = attachmentColorInfoForColorSpace(colorSpace);
    }
    if (CGImageGetBitsPerComponent(cgImage) > 8) {
      colorInfo |= STUTextAttachmentUsesExtendedColors;
    }
  } else if (CIImage* const ciImage = image.CIImage) {
    if (const CGColorSpaceRef colorSpace = ciImage.colorSpace) {
      colorInfo = attachmentColorInfoForColorSpace(colorSpace);
    }
  }
  self = [super initWithWidth:imageSize.width + padding.left + padding.right
                       ascent:imageSize.height + padding.top - verticalOffset
                      descent:padding.bottom + verticalOffset
                      leading:leading
                  imageBounds:CGRect{{padding.left, verticalOffset - imageSize.height}, imageSize}
                    colorInfo:colorInfo
         stringRepresentation:stringRepresentation];
  _image = image;
  return self;
}

- (nullable instancetype)initWithNSTextAttachment:(NSTextAttachment*)attachment
                             stringRepresentation:(nullable NSString*)stringRepresentation
{
  UIImage* const image = attachment.image;
  if (!image) return nil;
  CGRect bounds = clampRectInput(attachment.bounds);
  if (bounds == CGRect{}) {
    bounds.size = image.size;
  }
  self = [self initWithImage:image imageSize:bounds.size verticalOffset:-bounds.origin.y
                     padding:UIEdgeInsetsZero leading:0 stringRepresentation:stringRepresentation];
  if (attachment.isAccessibilityElement) {
    self.isAccessibilityElement = true;
    if (@available(iOS 11, tvOS 11, *)) {
      if (NSAttributedString* const label = attachment.accessibilityAttributedLabel) {
        self.accessibilityAttributedLabel = label;
      }
      if (NSAttributedString* const hint = attachment.accessibilityAttributedHint) {
        self.accessibilityAttributedHint = hint;
      }
      if (NSAttributedString* const value = attachment.accessibilityAttributedValue) {
        self.accessibilityAttributedValue = value;
      }
    } else {
      if (NSString* const label = attachment.accessibilityLabel) {
        self.accessibilityLabel = label;
      }
      if (NSString* const hint = attachment.accessibilityHint) {
        self.accessibilityHint = hint;
      }
      if (NSString* const value = attachment.accessibilityValue) {
        self.accessibilityValue = value;
      }
    }
    if (NSString* const value = attachment.accessibilityLanguage) {
      self.accessibilityLanguage = value;
    }
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
  [super encodeWithCoder:coder];
  encode(coder, @"image", _image);
}

- (nullable instancetype)initWithCoder:(NSCoder*)decoder {
  if ((self = [super initWithCoder:decoder])) {
    if (!(_image = [decoder decodeObjectOfClass:UIImage.class forKey:@"image"])) {
      return nil;
    }
  }
  return self;
}

- (UIImage*)image { return _image; }

- (void)drawInContext:(CGContextRef __unused)context imageBounds:(CGRect)imageBounds {
  [self->_image drawInRect:imageBounds];
}

- (nonnull instancetype)initWithWidth:(CGFloat __unused)width
                               ascent:(CGFloat __unused)ascent
                              descent:(CGFloat __unused)descent
                              leading:(CGFloat __unused)leading
                          imageBounds:(CGRect __unused)imageBounds
                            colorInfo:(STUTextAttachmentColorInfo __unused)colorInfo
                 stringRepresentation:(nullable NSString* __unused)stringRepresentation
  NS_UNAVAILABLE
{
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

@end

@implementation NSAttributedString (STUTextAttachment)

+ (instancetype)stu_newWithSTUAttachment:(nonnull STUTextAttachment*)attachment NS_RETURNS_RETAINED {
  return [[self alloc] initWithString:@"\uFFFC"
                           attributes:@{STUAttachmentAttributeName: attachment,
                                        (__bridge NSString*)kCTRunDelegateAttributeName:
                                          [attachment newCTRunDelegate]}];
}

namespace stu_label {
  STU_INLINE
  Class stuTextAttachmentClass() {
    STU_STATIC_CONST_ONCE(Class, value, STUTextAttachment.class);
    return value;
  }

  struct AttachmentRange : NSRange {
    STUTextAttachment* __unsafe_unretained attachment;

    UInt end() const { return location + length; }
  };

  template <int n>
  static void addRange(Vector<AttachmentRange, n>& ranges,
                       STUTextAttachment* __unsafe_unretained attachment, NSRange range)
  {
    if (!ranges.isEmpty() && ranges[$ - 1].attachment == attachment
        && ranges[$ - 1].end() == range.location)
    {
      ranges[$ - 1].length += range.length;
      return;
    }
    ranges.append(AttachmentRange{range, attachment});
  }
}

static
void addRunDelegatesIfNecessary(NSAttributedString* __unsafe_unretained attributedString,
                                InOut<NSMutableAttributedString* __strong> inOutNewAttributedString,
                                ArrayRef<const AttachmentRange> ranges)
{
  NSMutableAttributedString* __strong & newAttributedString = inOutNewAttributedString.get();
  const auto initializeNewAttributedStringIfNeccessary = [&]() {
    if (!newAttributedString) {
      newAttributedString = [attributedString mutableCopy];
    }
  };
  const UInt length = attributedString.length;
  for (const AttachmentRange& range : ranges) {
    NSRange effectiveRange;
    if (![attributedString attribute:(__bridge NSAttributedStringKey)kCTRunDelegateAttributeName
                             atIndex:range.location longestEffectiveRange:&effectiveRange
                             inRange:range]
        || effectiveRange.length < range.length)
    {
      initializeNewAttributedStringIfNeccessary();
      [newAttributedString addAttribute:(__bridge NSAttributedStringKey)kCTRunDelegateAttributeName
                                  value:[range.attachment newCTRunDelegate]
                                  range:range];
    }
    if ([attributedString attribute:fixForRDAR36622225AttributeName atIndex:range.location
                       effectiveRange:nil])
    {
      initializeNewAttributedStringIfNeccessary();
      [newAttributedString removeAttribute:fixForRDAR36622225AttributeName
                                     range:NSRange{range.location, 1}];
    }
    for (UInt i = 1; i < range.length; ++i) {
      id value = [attributedString attribute:fixForRDAR36622225AttributeName
                                     atIndex:range.location + i
                       longestEffectiveRange:&effectiveRange
                                     inRange:Range{range.location + i, length}];
      NSInteger n;
      if (!value || effectiveRange.length > 1
          || ((void)CFNumberGetValue((__bridge CFNumberRef)value, kCFNumberNSIntegerType, &n),
              n != sign_cast(i)))
      {
        initializeNewAttributedStringIfNeccessary();
        [newAttributedString addAttribute:fixForRDAR36622225AttributeName
                                    value:@(i) range:NSRange{range.location + i, 1}];
      }
    }
  }
}

- (NSAttributedString *)stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments {
  const Class stuTextAttachmentClass = stu_label::stuTextAttachmentClass();

  Vector<AttachmentRange, 7> rangesVector;
  auto& ranges = rangesVector; // Prevents the block from copying the vector.

  NSMutableAttributedString* __block newAttributedString = nil;
  [self enumerateAttributesInRange:NSRange{0, self.length}
                           options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                        usingBlock:^(NSDictionary<NSAttributedStringKey, id>* __unsafe_unretained
                                        attributes,
                                     NSRange range, BOOL* shouldStop __unused)
  {
    if (STUTextAttachment* const attachment = [attributes objectForKey:STUAttachmentAttributeName];
        attachment && [attachment isKindOfClass:stuTextAttachmentClass])
    {
      addRange(ranges, attachment, range);
      return;
    }
    NSTextAttachment* const attachment = [attributes objectForKey:NSAttachmentAttributeName];
    if (!attachment) return;
    auto* const imageAttachment = [[STUImageTextAttachment alloc]
                                    initWithNSTextAttachment:attachment
                                        stringRepresentation:nil];
    if (!imageAttachment) return;
    if (!newAttributedString) {
      newAttributedString = [self mutableCopy];
    }
    [newAttributedString addAttributes:@{STUAttachmentAttributeName: imageAttachment,
                                         (__bridge NSAttributedStringKey)kCTRunDelegateAttributeName:
                                          [imageAttachment newCTRunDelegate]}
                                 range:range];
    for (UInt i = 1; i < range.length; ++i) {
      [newAttributedString addAttribute:fixForRDAR36622225AttributeName
                                  value:@(i) range:NSRange{range.location + i, 1}];
    }
  }];
  if (!ranges.isEmpty()) {
    addRunDelegatesIfNecessary(self, InOut{newAttributedString}, ranges);
  }
  if (!newAttributedString) {
    return [self copy];
  }
  return [newAttributedString copy];
}

- (NSAttributedString*)stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments {
  const Class stuTextAttachmentClass = stu_label::stuTextAttachmentClass();
  Vector<AttachmentRange, 7> rangesVector;
  auto& ranges = rangesVector; // Prevents the block from copying the vector.
  [self enumerateAttribute:STUAttachmentAttributeName
                   inRange:NSRange{0, self.length}
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL*)
  {
    if (!value) return;
    if (![value isKindOfClass:stuTextAttachmentClass]) return;
    addRange(ranges, static_cast<STUTextAttachment*>(value), range);
  }];
  if (!ranges.isEmpty()) {
    NSMutableAttributedString* newAttributedString;
    addRunDelegatesIfNecessary(self, InOut{newAttributedString}, ranges);
    if (newAttributedString) {
      return [newAttributedString copy];
    }
  }
  return [self copy];
}

- (NSAttributedString*)stu_attributedStringByRemovingCTRunDelegates {
  __block NSMutableAttributedString* newAttributedString = nil;
  [self enumerateAttribute:(__bridge NSAttributedStringKey)kCTRunDelegateAttributeName
                   inRange:NSRange{0, self.length}
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL*)
  {
    if (!value) return;
    if (!newAttributedString) {
      newAttributedString = [self mutableCopy];
    }
    [newAttributedString removeAttribute:(__bridge NSAttributedStringKey)kCTRunDelegateAttributeName
                                   range:range];
  }];
  if (!newAttributedString) {
    return [self copy];
  }
  return [newAttributedString copy];
}

- (NSAttributedString*)stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations {
  const Class stuTextAttachmentClass = stu_label::stuTextAttachmentClass();
  const UInt length = self.length;
  __block NSMutableAttributedString* newAttributedString = nil;
  __block NSMutableString* newString = nil;
  __block UInt indexOffset = 0;
  [self enumerateAttribute:STUAttachmentAttributeName inRange:NSRange{0, length}
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange stringRange, BOOL*)
  {
    if (!value) return;
    if (![value isKindOfClass:stuTextAttachmentClass]) return;
    STUTextAttachment* const attachment = value;
    if (!newAttributedString) {
      newAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:self];
      newString = newAttributedString.mutableString;
    }
    // We replace each char in the range individually. We don't bother checking whether each char
    // actually equals 0xFFFC.
    for (const UInt indexWithoutOffset : Range{stringRange}.iter()) {
      const UInt index = indexWithoutOffset + indexOffset;
      NSString* stringRepresention = attachment.stringRepresentation;
      UInt n;
      if (stringRepresention != nil) {
        n = stringRepresention.length;
      } else {
        if (index == 0 || index + 1 == length + indexOffset
            || isUnicodeWhitespace([newString characterAtIndex:index - 1])
            || (isUnicodeWhitespace([newString characterAtIndex:index + 1])
                || [newAttributedString attribute:STUAttachmentAttributeName atIndex:index + 1
                                   effectiveRange:nil]))
        {
          n = 0;
        } else {
          stringRepresention = @" ";
          n = 1;
        }
      }
      if (n == 0) {
        [newAttributedString deleteCharactersInRange:Range{index, Count{1u}}];
      } else {
        NSDictionary* attributes = nil;
        if (STU_LIKELY(index != 0)) {
          attributes = [newAttributedString attributesAtIndex:index - 1 effectiveRange:nil];
        } else {
          __block UInt indexAfterAttachments = 0;
          [newAttributedString
             enumerateAttribute:STUAttachmentAttributeName
                        inRange:Range{stringRange.length, length}
                        options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                     usingBlock:^(id attachmentValue, NSRange range, BOOL* shouldStop)
          {
            if (!attachmentValue) {
              indexAfterAttachments = range.location;
              *shouldStop = true;
            }
          }];
          if (indexAfterAttachments != 0) {
            attributes = [newAttributedString attributesAtIndex:indexAfterAttachments
                                                 effectiveRange:nil];
          } else {
            NSMutableDictionary<NSAttributedStringKey, id>* const mutableAttributes =
              [[self attributesAtIndex:stringRange.location effectiveRange:nil] mutableCopy];
            [mutableAttributes removeObjectForKey:STUAttachmentAttributeName];
            [mutableAttributes removeObjectForKey:NSAttachmentAttributeName];
            [mutableAttributes removeObjectForKey:(__bridge NSString*)kCTRunDelegateAttributeName];
            attributes = mutableAttributes;
          }
        }
        [newAttributedString setAttributes:attributes range:Range{index, Count{1u}}];
        [newAttributedString replaceCharactersInRange:Range{index, Count{1u}}
                                           withString:stringRepresention];
      }
      indexOffset += n - 1;
    }
  }];
  if (!newAttributedString) {
    return [self copy];
  }
  return [newAttributedString copy];
}

@end

