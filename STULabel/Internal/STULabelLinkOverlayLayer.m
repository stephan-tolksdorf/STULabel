// Copyright 2017 Stephan Tolksdorf

#import "STULabelLinkOverlayLayer.h"

#import "stu/Assert.h"

typedef void (^ FadeCompletion)(STULabelLinkOverlayLayer * __nonnull);

@interface STULabelLinkOverlayFadeAnimationDelegate : NSObject <CAAnimationDelegate> {
@package
  STULabelLinkOverlayLayer * __weak _layer;
  FadeCompletion _completion;
}
@end

@implementation STULabelLinkOverlayLayer {
  STULabelOverlayStyle *_style;
  STUTextLink *_link;
@package // Accessed from STULabelLinkOverlayFadeAnimationDelegate too.
  STULabelLinkOverlayFadeAnimationDelegate *_fadeDelegate;
}

- (void)setBounds:(CGRect __unused)bounds {
  [super setBounds:CGRectZero];
}

- (instancetype)initWithStyle:(STULabelOverlayStyle *)style
                         link:(STUTextLink *)link
{
  if (self = [super init]) {
    super.opacity = 0;
    _link = link;
    self.overlayStyle = style;
  }
  return self;
}

- (STUTextLink *)link { return _link; }

- (void)setLink:(STUTextLink *)link {
  if (_link == link) return;
  if (_fadeDelegate) {
    _fadeDelegate = nil;
    [self removeAnimationForKey:fadeAnimationKey];
  }
  _link = link;
  [self setNeedsDisplay];
}

- (STULabelOverlayStyle *)overlayStyle { return _style; }

- (void)setOverlayStyle:(STULabelOverlayStyle *)style {
  if (style == _style) return;
  _style = style;
  self.strokeColor = style.borderColor.CGColor;
  self.lineWidth = style.borderWidth;
  self.fillColor = style.color.CGColor;
  [self setNeedsDisplay];
}


- (void)display {
  CGPathRef path = [_link createPathWithEdgeInsets:_style.edgeInsets
                                      cornerRadius:_style.cornerRadius
           extendTextLinesToCommonHorizontalBounds:_style.extendTextLinesToCommonHorizontalBounds
                                  fillTextLineGaps:true
                                         transform:nil];
  self.path = path;
  CFRelease(path);
}


- (BOOL)isHidden {
  return self.opacity == 0;
}

static NSString * const fadeAnimationKey = @"stuFade";

- (void)setHidden:(BOOL)hidden {
  [self setHidden:hidden withAnimationCompletion:nil];
}
- (void)setHidden:(BOOL)hidden
withAnimationCompletion:(void (^)(STULabelLinkOverlayLayer * _Nonnull))completion
{
  const CFTimeInterval duration = !hidden ? _style.fadeInDuration : _style.fadeOutDuration;
  if (duration == 0) {
    self.opacity = hidden ? 0 : 1;
    if (_fadeDelegate) {
       _fadeDelegate = nil;
       [self removeAnimationForKey:fadeAnimationKey];
    }
    if (completion) {
      completion(self);
    }
    return;
  }
  const Float32 opacity = _fadeDelegate ? self.presentationLayer.opacity  : self.opacity;
  self.opacity = hidden ? 0 : 1;
  const Float32 progress = !hidden ? opacity : 1 - opacity;
  __auto_type * const delegate = [[STULabelLinkOverlayFadeAnimationDelegate alloc] init];
  _fadeDelegate = delegate;
  delegate->_layer = self;
  delegate->_completion = completion;
  CABasicAnimation * const animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
  animation.timingFunction = (hidden ? _style.fadeOutTimingFunction : _style.fadeInTimingFunction)
                             ?: [CAMediaTimingFunction
                                  functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  animation.delegate = delegate;
  animation.fromValue = @(opacity);
  animation.toValue = @(hidden ? 0 : 1);
  animation.duration = (1 - progress)*duration;
  [self addAnimation:animation forKey:fadeAnimationKey];
}

@end

@implementation STULabelLinkOverlayFadeAnimationDelegate

- (void)animationDidStop:(CAAnimation * __unused)animation finished:(BOOL __unused)flag {
  STULabelLinkOverlayLayer * const layer = self->_layer;
  const FadeCompletion completion = self->_completion;
  self->_completion = nil;
  if (layer && self == layer->_fadeDelegate) {
    layer->_fadeDelegate = nil;
    if (completion) {
      completion(layer);
    }
  }
}

@end


