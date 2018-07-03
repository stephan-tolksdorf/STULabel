// Copyright 2016–2017 Stephan Tolksdorf

#import "STUDefines.h"

#import <QuartzCore/QuartzCore.h>

/// CALayer subclass with a `defaultActionForKey:` implementation that always returns `NSNull`
/// in order to suppress implicit animations.
STU_EXPORT
@interface STULayerWithNullDefaultActions : CALayer
@end

/// CAShapeLayer subclass with a `defaultActionForKey:` implementation that always returns `NSNull`
/// in order to suppress implicit animations.
STU_EXPORT
@interface STUShapeLayerWithNullDefaultActions : CAShapeLayer
@end

