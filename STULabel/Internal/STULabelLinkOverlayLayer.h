// Copyright 2017 Stephan Tolksdorf

#import "STULabel/STULabelOverlayStyle.h"
#import "STULabel/STULayerWithNullDefaultActions.h"
#import "STULabel/STUTextLink.h"

/// The bounds are always CGRectZero, but the shape extends beyond the bounds.
@interface STULabelLinkOverlayLayer : STUShapeLayerWithNullDefaultActions

/// The layer's initial `hidden` value is false.
- (null_unspecified instancetype)initWithStyle:(nonnull STULabelOverlayStyle*)style
                                          link:(nonnull STUTextLink *)link
  NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, nonnull) STUTextLink *link;

@property (nonatomic, strong, nonnull) STULabelOverlayStyle *overlayStyle;

- (void)setHidden:(BOOL)hidden;

- (void)setHidden:(BOOL)hidden
withAnimationCompletion:(void ( ^ __nullable)(STULabelLinkOverlayLayer * __nonnull))completion;

@end



