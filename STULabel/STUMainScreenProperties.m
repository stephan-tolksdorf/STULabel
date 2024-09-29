// Copyright 2016–2018 Stephan Tolksdorf

#import "STUMainScreenProperties.h"

#import "stu/Assert.h"

#import <pthread.h>

#import <stdatomic.h>

#if TARGET_OS_IOS
  #define STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT 1
#else
  #define STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT 0
#endif

#if STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT
  #define STU_ATOMIC_IF_NOT_CONSTANT(Type) Type
#else
  #define STU_ATOMIC_IF_NOT_CONSTANT(Type) _Atomic(Type)
#endif

static STU_ATOMIC_IF_NOT_CONSTANT(CGFloat) mainScreenPortraitSizeWidth;
static STU_ATOMIC_IF_NOT_CONSTANT(CGFloat) mainScreenPortraitSizeHeight;
static STU_ATOMIC_IF_NOT_CONSTANT(CGFloat) mainScreenScale;
static STU_ATOMIC_IF_NOT_CONSTANT(STUDisplayGamut) mainScreenDisplayGamut;

static void updateMainScreenProperties(void) {
  STU_DEBUG_ASSERT(pthread_main_np());
  UIScreen * const mainScreen = UIScreen.mainScreen;
  STU_ASSERT(mainScreen || !STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT);
  CGSize portraitSize;
  CGFloat scale;
  STUDisplayGamut displayGamut;
  if (mainScreen) {
    portraitSize = mainScreen.fixedCoordinateSpace.bounds.size;
    scale = mainScreen.scale;
    if (@available(iOS 10, tvOS 10, *)) {
      displayGamut = (STUDisplayGamut)mainScreen.traitCollection.displayGamut;
    } else { // We don't try to support wide colors on an old iPad Pro running iOS 9.
      displayGamut = STUDisplayGamutSRGB;
    }
  } else {
    portraitSize = CGSizeZero;
    scale = 1;
    displayGamut = STUDisplayGamutSRGB;
  }
#if STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT
  #define store(var, value) var = value
#else
  #define store(var, value) atomic_store_explicit(&var, value, memory_order_relaxed)
#endif
  store(mainScreenPortraitSizeWidth, portraitSize.width);
  store(mainScreenPortraitSizeHeight, portraitSize.height);
  store(mainScreenScale, scale);
  store(mainScreenDisplayGamut, displayGamut);
#undef store
}

void stu_initializeMainScreenProperties(void) {
  static bool initialized = false;
  if (initialized) {
      return;
  }
  initialized = true;
  updateMainScreenProperties();
#if !STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT
  NSNotificationCenter * const notificationCenter = NSNotificationCenter.defaultCenter;
  NSOperationQueue * const mainQueue = NSOperationQueue.mainQueue;
  const __auto_type updateMainScreenPropertiesBlock = ^(NSNotification *note __unused) {
                                                         updateMainScreenProperties();
                                                       };
  [notificationCenter addObserverForName:UIScreenDidConnectNotification
                                  object:nil queue:mainQueue
                              usingBlock:updateMainScreenPropertiesBlock];
  [notificationCenter addObserverForName:UIScreenDidDisconnectNotification
                                  object:nil queue:mainQueue
                              usingBlock:updateMainScreenPropertiesBlock];
#endif
}

@interface UIScreen (STUMainScreenProperties)
+ (void)load;
@end
@implementation UIScreen (STUMainScreenProperties)
+ (void)load {
  // We can't do this initialization lazily, because UIScreen must only be accessed on the
  // main thread. (Using `dispatch_sync(dispatch_get_main_queue(), ...)` would lead to a
  // deadlock when the main thread is waiting for the thread in which stu_mainScreen... is called
  // for the first time.)
  // However, when executing this `load` method when a test bundle is loaded,
  // calling stu_initializeMainScreenProperties synchronously leads to a deadlock in UIScreen.mainScreen,
  // so for that special case we just invoke stu_initializeMainScreenProperties asynchronously,
  // relying on the main screen properties not beeing used before stu_initializeMainScreenProperties has run.
  NSDictionary* env = NSProcessInfo.processInfo.environment;
  if ([env valueForKey:@"STULabel_NoMainScreenPropertiesInitializationOnLoad"]) {
    return;
  }
  if ([env valueForKey:@"XCTestBundlePath"]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      stu_initializeMainScreenProperties();
    });
    return;
  }
  stu_initializeMainScreenProperties();
}
@end

#if STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT
  #define load(var) var
#else
  #define load(var) atomic_load_explicit(&var, memory_order_relaxed)
#endif

STU_EXPORT
CGSize stu_mainScreenPortraitSize(void) {
  return (CGSize){load(mainScreenPortraitSizeWidth), load(mainScreenPortraitSizeHeight)};
}

STU_EXPORT
CGFloat stu_mainScreenScale(void) {
  return load(mainScreenScale);
}

STU_EXPORT
STUDisplayGamut stu_mainScreenDisplayGamut(void) {
  return load(mainScreenDisplayGamut);
}

#undef load
