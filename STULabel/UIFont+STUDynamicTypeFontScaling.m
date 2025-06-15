// Copyright 2017–2018 Stephan Tolksdorf

#import "UIFont+STUDynamicTypeFontScaling.h"

#import "stu_mutex.h"

#import <dispatch/dispatch.h>

#import <objc/runtime.h>

#import <stdatomic.h>

typedef NS_ENUM(uint8_t, STUContentSizeCategory) {
  STUContentSizeCategoryUnspecified = 0,
  STUContentSizeCategoryExtraSmall,
  STUContentSizeCategorySmall,
  STUContentSizeCategoryMedium,
  STUContentSizeCategoryLarge,
  STUContentSizeCategoryExtraLarge,
  STUContentSizeCategoryExtraExtraLarge,
  STUContentSizeCategoryExtraExtraExtraLarge,
  STUContentSizeCategoryAccessibilityMedium,
  STUContentSizeCategoryAccessibilityLarge,
  STUContentSizeCategoryAccessibilityExtraLarge,
  STUContentSizeCategoryAccessibilityExtraExtraLarge,
  STUContentSizeCategoryAccessibilityExtraExtraExtraLarge
};
const int STUContentSizeCategoryCount = STUContentSizeCategoryAccessibilityExtraExtraExtraLarge + 1;

static
STUContentSizeCategory stuContentSizeCategory(UIContentSizeCategory __unsafe_unretained cat) {
  if (!cat) return STUContentSizeCategoryUnspecified;
  const CFIndex length = CFStringGetLength((__bridge CFStringRef)cat);
  if (length == 0) return STUContentSizeCategoryUnspecified;
  bool unexpectedLength = false;
  switch (length) {
  #define oneCategoryCase(name) \
    if (cat == UIContentSizeCategory ## name \
        || [cat isEqualToString:UIContentSizeCategory ## name]) \
    { \
      return STUContentSizeCategory ## name; \
    } \
    if (!unexpectedLength) goto UnexpectedLength;

  #define twoCategoriesCase(name1, name2) \
    if (cat == UIContentSizeCategory ## name1) return STUContentSizeCategory ## name1; \
    if (cat == UIContentSizeCategory ## name2) return STUContentSizeCategory ## name2;  \
    if ([cat isEqualToString:UIContentSizeCategory ## name1]) return STUContentSizeCategory ## name1; \
    if ([cat isEqualToString:UIContentSizeCategory ## name2]) return STUContentSizeCategory ## name2; \
    if (!unexpectedLength) goto UnexpectedLength;

  #define threeCategoriesCase(name1, name2, name3) \
    if (cat == UIContentSizeCategory ## name1) return STUContentSizeCategory ## name1; \
    if (cat == UIContentSizeCategory ## name2) return STUContentSizeCategory ## name2;  \
    if (cat == UIContentSizeCategory ## name3) return STUContentSizeCategory ## name2;  \
    if ([cat isEqualToString:UIContentSizeCategory ## name1]) return STUContentSizeCategory ## name1; \
    if ([cat isEqualToString:UIContentSizeCategory ## name2]) return STUContentSizeCategory ## name2; \
    if ([cat isEqualToString:UIContentSizeCategory ## name3]) return STUContentSizeCategory ## name3; \
    if (!unexpectedLength) goto UnexpectedLength;

  default:
  UnexpectedLength:
    unexpectedLength = true;
    STU_FALLTHROUGH
  case 24: // UICTContentSizeCategoryS
           // UICTContentSizeCategoryM
           // UICTContentSizeCategoryL
    threeCategoriesCase(Small, Medium, Large)
    STU_FALLTHROUGH
  case 25: // UICTContentSizeCategoryXS
           // UICTContentSizeCategoryXL
    twoCategoriesCase(ExtraSmall, ExtraLarge)
    STU_FALLTHROUGH
  case 26: // UICTContentSizeCategoryXXL
    oneCategoryCase(ExtraExtraLarge)
    STU_FALLTHROUGH
  case 27: // UICTContentSizeCategoryXXXL
    oneCategoryCase(ExtraExtraExtraLarge)
    STU_FALLTHROUGH
  case 37: // UICTContentSizeCategoryAccessibilityM
           // UICTContentSizeCategoryAccessibilityL
    twoCategoriesCase(AccessibilityMedium, AccessibilityLarge)
    STU_FALLTHROUGH
  case 38: // UICTContentSizeCategoryAccessibilityXL
    oneCategoryCase(AccessibilityExtraLarge)
    STU_FALLTHROUGH
  case 39: // UICTContentSizeCategoryAccessibilityXXL
    oneCategoryCase(AccessibilityExtraExtraLarge)
    STU_FALLTHROUGH
  case 40: // UICTContentSizeCategoryAccessibilityXXXL
    oneCategoryCase(AccessibilityExtraExtraExtraLarge)

  #undef oneCategoryCase
  #undef twoCategoriesCase
  #undef threeCategoriesCase
  } // switch
  return STUContentSizeCategoryUnspecified;
}

static Class nsNumberClass;
static Class nsStringClass;

static atomic_bool canScaleNonPreferredFonts;

static
id valueForFontKey(UIFont * __unsafe_unretained font,
                   NSString * __unsafe_unretained key, Class valueClass)
{
  if (atomic_load_explicit(&canScaleNonPreferredFonts, memory_order_relaxed)) {
    @try {
      const id value = [font valueForKey:key];
      if (value && [value isKindOfClass:valueClass]) {
        return value;
      }
    } @catch (NSException * __unused e) {
      atomic_store_explicit(&canScaleNonPreferredFonts, false, memory_order_relaxed);
    }
  }
  return nil;
}

static id stringForFontKey(UIFont * __unsafe_unretained font, NSString * __unsafe_unretained key) {
  return valueForFontKey(font, key, nsStringClass);
}

static
bool floatForFontKey(UIFont * __unsafe_unretained font, NSString * __unsafe_unretained key,
                     CGFloat *outValue)
{
  NSNumber * const number = valueForFontKey(font, key, nsNumberClass);
  if (number != nil) {
  #if CGFLOAT_IS_DOUBLE
    *outValue = number.doubleValue;
  #else
    *outValue = number.floatValue;
  #endif
    return true;
  }
  return false;
}

@interface STUWeakFontReference : NSObject {
@package // fileprivate
  UIFont* font;
}
@end
@implementation STUWeakFontReference
@end

@implementation UIFont (STUDynamicTypeScaling)

- (UIFont *)stu_fontAdjustedForContentSizeCategory:(__unsafe_unretained UIContentSizeCategory)category
  API_AVAILABLE(ios(10.0), tvos(10.0))
{
  const STUContentSizeCategory stuCategory = stuContentSizeCategory(category);
  if (!stuCategory) { // Unknown or unspecified category.
    return self;
  }
  const size_t index = (size_t)stuCategory - 1;

  static Class weakFontReferenceClass;
  static bool fontMetricsIsAvailable;
    
STU_DISABLE_CLANG_WARNING("-Wgnu-folding-constant")
  static dispatch_once_t onces[STUContentSizeCategoryCount - 1];
  static UITraitCollection *traitCollections[STUContentSizeCategoryCount - 1];
STU_REENABLE_CLANG_WARNING

  static dispatch_once_t once;
  dispatch_once(&once, ^{
    nsNumberClass = NSNumber.class;
    nsStringClass = NSString.class;
    weakFontReferenceClass = STUWeakFontReference.class;
    atomic_store_explicit(&canScaleNonPreferredFonts, true, memory_order_relaxed);
    if (@available(iOS 11, tvOS 11, *)) {
      fontMetricsIsAvailable = true;
    }
  });
  dispatch_once(&onces[index], ^{
    traitCollections[index] = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:
                                                   category];
  });

  const void * const associatedObjectKey = &traitCollections[index];

  STUWeakFontReference *weakRef;
  {
    const id cached = objc_getAssociatedObject(self, associatedObjectKey);
    if (cached) {
      if ((__bridge CFTypeRef)cached == kCFNull) {
        return self;
      }
      weakRef = cached;
      UIFont * const font = weakRef->font;
      if (font) return font;
    }
  }


  UIFontTextStyle style = [self.fontDescriptor objectForKey:UIFontDescriptorTextStyleAttribute];
  const bool isPreferredFont = style && [style hasPrefix:@"UICTFontTextStyle"];
  CGFloat sizeForScaling = 0;
  if (!isPreferredFont) {
    if (!fontMetricsIsAvailable
        || !(style = stringForFontKey(self, @"textStyleForScaling")) // assignment
        || !floatForFontKey(self, @"pointSizeForScaling", &sizeForScaling)
        || !(sizeForScaling > 0))
    {
    FontCanNotBeScaled:
      if (atomic_load_explicit(&canScaleNonPreferredFonts, memory_order_relaxed)) {
        objc_setAssociatedObject(self, associatedObjectKey, (__bridge id)kCFNull,
                                 OBJC_ASSOCIATION_ASSIGN);
      }
      return self;
    }
  }

  UIFont *font = !isPreferredFont ? [self fontWithSize:sizeForScaling]
                                  : [UIFont preferredFontForTextStyle:style
                                        compatibleWithTraitCollection:traitCollections[index]];
  if (!font) goto FontCanNotBeScaled;

  if (fontMetricsIsAvailable) {
  STU_DISABLE_CLANG_WARNING("-Wunguarded-availability-new")
    CGFloat maxSize = 0;
    if (!floatForFontKey(self, @"maximumPointSizeAfterScaling", &maxSize)) {
      if (!isPreferredFont) goto FontCanNotBeScaled;
    }
    if (!isPreferredFont || maxSize > 0) {
      UIFontMetrics* const metrics = [[UIFontMetrics alloc] initForTextStyle:style];
      font = [metrics scaledFontForFont:font maximumPointSize:maxSize
          compatibleWithTraitCollection:traitCollections[index]];
    }
  STU_REENABLE_CLANG_WARNING
  }

  if (!weakRef) {
    weakRef = class_createInstance(weakFontReferenceClass, 0);
  }
  weakRef->font = font;
  objc_setAssociatedObject(self, associatedObjectKey, weakRef, OBJC_ASSOCIATION_RETAIN); // atomic

  return font;
}

@end
