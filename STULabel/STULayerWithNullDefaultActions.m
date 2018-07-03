// Copyright 2016–2017 Stephan Tolksdorf

#import "STULayerWithNullDefaultActions.h"

@implementation STULayerWithNullDefaultActions

+ (id<CAAction>)defaultActionForKey:(NSString *) __unused event {
  return NSNull.null;
}

@end

@implementation STUShapeLayerWithNullDefaultActions

+ (id<CAAction>)defaultActionForKey:(NSString *) __unused event {
  return NSNull.null;
}

@end
