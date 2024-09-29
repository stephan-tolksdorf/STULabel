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

static void loadMainScreenPropertiesAndObserveIfNeeded(void) {
  void (^load)(void) = ^{
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
  };
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (pthread_main_np()) {
      load();
    } else {
      dispatch_sync(dispatch_get_main_queue(), load);
    }
  });
}

#if STU_MAIN_SCREEN_PROPERTIES_ARE_CONSTANT
  #define load(var) var
#else
  #define load(var) atomic_load_explicit(&var, memory_order_relaxed)
#endif

STU_EXPORT
CGSize stu_mainScreenPortraitSize(void) {
  loadMainScreenPropertiesAndObserveIfNeeded();
  return (CGSize){load(mainScreenPortraitSizeWidth), load(mainScreenPortraitSizeHeight)};
}

STU_EXPORT
CGFloat stu_mainScreenScale(void) {
  loadMainScreenPropertiesAndObserveIfNeeded();
  return load(mainScreenScale);
}

STU_EXPORT
STUDisplayGamut stu_mainScreenDisplayGamut(void) {
  loadMainScreenPropertiesAndObserveIfNeeded();
  return load(mainScreenDisplayGamut);
}

#undef load
