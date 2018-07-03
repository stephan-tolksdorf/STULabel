// Copyright 2017–2018 Stephan Tolksdorf

#import "UIFont+STUDynamicTypeFontScaling.h"

#import "stu_mutex.h"

@interface STUDynamicTypeScalingCache : NSObject {
@package
  NSMapTable<UIFont *, UIFont *> *fontMapping;
  UITraitCollection *traitCollection;
}
@end
@implementation STUDynamicTypeScalingCache
@end

static STU_INLINE
CGFloat cgFloatValueForKey(NSObject *object, NSString *key) {
  return ((NSNumber *)[object valueForKey:key])
       #if CGFLOAT_IS_DOUBLE
         .doubleValue;
       #else
         .floatValue;
       #endif
}

@implementation UIFont (STUDynamicTypeScaling)

- (UIFont *)stu_fontAdjustedForContentSizeCategory:(__unsafe_unretained UIContentSizeCategory)category
  API_AVAILABLE(ios(10.0), tvos(10.0))
{
  static stu_mutex mutex = STU_MUTEX_INIT;

  static NSMutableDictionary<UIContentSizeCategory, STUDynamicTypeScalingCache *> *cacheByCategory;

  STU_DISABLE_CLANG_WARNING("-Wunguarded-availability-new")
  static NSMutableDictionary<UIFontTextStyle, UIFontMetrics *> *metricsByStyle;
  STU_REENABLE_CLANG_WARNING

  static bool canScaleNonPreferredFonts = false;

  stu_mutex_lock(&mutex);

  if (STU_UNLIKELY(!cacheByCategory)) {
    cacheByCategory = [[NSMutableDictionary alloc] init];
    if (@available(iOS 11, tvOS 11, *)) {
      @try {
        UIFont * const f = [UIFont systemFontOfSize:20]; // An arbitrary test font.
        const id style = [f valueForKey:@"textStyleForScaling"];
        canScaleNonPreferredFonts =
             (style == nil || [style isKindOfClass:NSString.class])
          && [[f valueForKey:@"pointSizeForScaling"] isKindOfClass:NSNumber.class]
          && [[f valueForKey:@"maximumPointSizeAfterScaling"] isKindOfClass:NSNumber.class];
      } @catch (NSException * __unused e) {}
      if (!canScaleNonPreferredFonts) {
        NSLog(@"ERROR: stu_fontAdjustedForContentSizeCategory does not yet work properly on this OS version.");
      } else {
        metricsByStyle = [[NSMutableDictionary alloc] init];
      }
    }

    NSNotificationCenter * const notificationCenter = NSNotificationCenter.defaultCenter;
    NSOperationQueue * const mainQueue = NSOperationQueue.mainQueue;
    const __auto_type clearCacheBlock = ^(NSNotification * __unused notifcation) {
      stu_mutex_lock(&mutex);
      cacheByCategory = [[NSMutableDictionary alloc] init];
      if (metricsByStyle) {
        metricsByStyle = [[NSMutableDictionary alloc] init];
      }
      stu_mutex_unlock(&mutex);
    };
    [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
    [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
  }

  STUDynamicTypeScalingCache * __unsafe_unretained cache = [cacheByCategory objectForKey:category];
  if (cache) {
    UIFont * const font = [cache->fontMapping objectForKey:self];
    if (font) {
      stu_mutex_unlock(&mutex);
      return font;
    }
  } else { // Create the cache for this content size category.
    __auto_type * const newCache = [[STUDynamicTypeScalingCache alloc] init];
    cache = newCache;
    // We have to use pointer identity for the keys because UIFont.isEqual does not compare
    // the text style and maximum point size.
    newCache->fontMapping = [[NSMapTable alloc]
                               initWithKeyOptions: NSPointerFunctionsObjectPointerPersonality
                                                 | NSPointerFunctionsWeakMemory
                               valueOptions: NSPointerFunctionsObjectPointerPersonality
                                           | NSPointerFunctionsStrongMemory
                                   capacity:16];
    newCache->traitCollection = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:
                                                     category];
    cacheByCategory[category] = newCache;
  }

  UIFontTextStyle style = [self.fontDescriptor objectForKey:UIFontDescriptorTextStyleAttribute];
  const bool isPreferredFont = style && [style hasPrefix:@"UICTFontTextStyle"];
  CGFloat sizeForScaling = 0;
  if (!isPreferredFont
      && !(canScaleNonPreferredFonts
           // The following two lines contain assignments.
           && (style = [self valueForKey:@"textStyleForScaling"])
           && (0 < (sizeForScaling = cgFloatValueForKey(self, @"pointSizeForScaling")))))
  {
    // We can't scale this font.
    [cache->fontMapping setObject:self forKey:self];
    stu_mutex_unlock(&mutex);
    return self;
  }
  UIFont *font = !isPreferredFont ? [self fontWithSize:sizeForScaling]
               : [UIFont preferredFontForTextStyle:style
                     compatibleWithTraitCollection:cache->traitCollection];
  if (canScaleNonPreferredFonts) {
    const CGFloat maxSize = cgFloatValueForKey(self, @"maximumPointSizeAfterScaling");
    if (!isPreferredFont || maxSize > 0) {
      STU_DISABLE_CLANG_WARNING("-Wunguarded-availability-new")
      UIFontMetrics *metrics = metricsByStyle[style];
      if (!metrics) {
        metrics = [[UIFontMetrics alloc] initForTextStyle:style];
        metricsByStyle[style] = metrics;
      }
      font = [metrics scaledFontForFont:font maximumPointSize:maxSize
          compatibleWithTraitCollection:cache->traitCollection];
      STU_REENABLE_CLANG_WARNING
    }
  }
  [cache->fontMapping setObject:font forKey:self];
  stu_mutex_unlock(&mutex);
  return font;
}

@end
