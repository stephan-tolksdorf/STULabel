// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelOverlayStyle.h"

#import "Internal/Equal.hpp"
#import "Internal/Hash.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"
#import "Internal/STUMediaTimingFunctionUtils.h"
#import "Internal/STUMediaTimingFunctionUtils.h"

using namespace stu;
using namespace stu_label;

#define FOR_ALL_FIELDS(f) \
  f(bool, extendTextLinesToCommonHorizontalBounds) \
  f(UIEdgeInsets, edgeInsets) \
  f(CGFloat, cornerRadius) \
  f(CGFloat, borderWidth) \
  f(CFTimeInterval, fadeInDuration) \
  f(CFTimeInterval, fadeOutDuration) \
  f(UIColor*, color) \
  f(UIColor*, borderColor) \
  f(CAMediaTimingFunction*, fadeInTimingFunction) \
  f(CAMediaTimingFunction*, fadeOutTimingFunction)

#define DEFINE_FIELD(Type, name) Type _##name;

@interface STULabelOverlayStyle () {
@package // Accessed by the Builder's initWithStyle.
  FOR_ALL_FIELDS(DEFINE_FIELD)
}
@end

@implementation STULabelOverlayStyleBuilder  {
@package // Accessed by the Style's initWithBuilder.
  FOR_ALL_FIELDS(DEFINE_FIELD)
}

#undef DEFINE_FIELD

- (instancetype)init {
  return [self initWithStyle:nil];
}
- (instancetype)initWithStyle:(nullable STULabelOverlayStyle*)style {
  if (!style) return self;
#define ASSIGN_FROM_STYLE(Type, name) _##name = style->_##name;
  FOR_ALL_FIELDS(ASSIGN_FROM_STYLE)
#undef ASSIGN_FROM_STYLE
  return self;
}

- (void)setExtendTextLinesToCommonHorizontalBounds:(bool)extendTextLinesToCommonHorizontalBounds {
  _extendTextLinesToCommonHorizontalBounds = extendTextLinesToCommonHorizontalBounds;
}

- (void)setEdgeInsets:(UIEdgeInsets)edgeInsets {
  _edgeInsets = clampEdgeInsetsInput(edgeInsets);
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
  _cornerRadius = clampNonNegativeFloatInput(cornerRadius);
}

- (void)setBorderWidth:(CGFloat)borderWidth {
  _borderWidth = clampNonNegativeFloatInput(borderWidth);
}

- (void)setFadeInDuration:(CFTimeInterval)duration {
  _fadeInDuration = clampNonNegativeTimeIntervalInput(duration);
}

- (void)setFadeOutDuration:(CFTimeInterval)duration {
  _fadeOutDuration = clampNonNegativeTimeIntervalInput(duration);
}

@end

@implementation STULabelOverlayStyle

// Manually define getter methods, so that we don't have to declare the properties as "nonatomic".
#define DEFINE_GETTER(Type, name) - (Type)name { return _##name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  if (![object isKindOfClass:STULabelOverlayStyle.class]) return false;
  STULabelOverlayStyle* const other = object;
  return equal(_color, other->_color)
      && _cornerRadius == other->_cornerRadius
      && _extendTextLinesToCommonHorizontalBounds == other->_extendTextLinesToCommonHorizontalBounds
      && UIEdgeInsetsEqualToEdgeInsets(_edgeInsets, other->_edgeInsets)
      && _borderWidth == other->_borderWidth
      && equal(_borderColor, other->_borderColor)
      && _fadeInDuration == other->_fadeInDuration
      && _fadeOutDuration == other->_fadeOutDuration
      && stu_CAMediaTimingFunctionEqualToFunction(_fadeInTimingFunction,
                                                  other->_fadeInTimingFunction)
      && stu_CAMediaTimingFunctionEqualToFunction(_fadeOutTimingFunction,
                                                  other->_fadeOutTimingFunction);
}

- (NSUInteger)hash {
  return (NSUInteger)hash(_color.hash, _cornerRadius, _edgeInsets, _fadeInDuration);
}

- (instancetype)init {
  return [self initWithBuilder:nil];
}

- (instancetype)initWithBuilder:(nullable STULabelOverlayStyleBuilder*)builder {
#ifdef __clang_analyzer__
  self = [super init]; // Since the superclass is NSObject, this call is unnecesary.
#endif
  if (!builder) return self;
#define ASSIGN_FROM_BUILDER(Type, name) _##name = builder->_##name;
  FOR_ALL_FIELDS(ASSIGN_FROM_BUILDER) // clang analyzer bug
#undef ASSIGN_FROM_BUILDER
  return self;
}

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STULabelOverlayStyleBuilder*))block {
  STULabelOverlayStyleBuilder* const builder = [[STULabelOverlayStyleBuilder alloc] init];
  block(builder);
  return [self initWithBuilder:builder];
}

- (id)copyWithZone:(NSZone* __unused)zone {
  return self;
}

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STULabelOverlayStyleBuilder*))block {
  STULabelOverlayStyleBuilder* const builder = [[STULabelOverlayStyleBuilder alloc]
                                                   initWithStyle:self];
  block(builder);
  return [(STULabelOverlayStyle*)[self.class alloc] initWithBuilder:builder];
}

+ (nonnull STULabelOverlayStyle*)defaultStyle {
  STU_STATIC_CONST_ONCE(STULabelOverlayStyle*, style,
                        ([[STULabelOverlayStyle alloc]
                           initWithBlock:^(STULabelOverlayStyleBuilder* b)
                         {
                           b.edgeInsets = UIEdgeInsets{-2, -2, -2, -2};
                           b.cornerRadius = 4;
                           const CGFloat c = ((CGFloat)26)/255;
                           b.color = [UIColor colorWithRed:c green:c blue:c alpha:(CGFloat)0.3];
                           b.fadeInDuration = 0.1;
                           b.fadeOutDuration = 0.15;
                         }]));
  STU_ANALYZER_ASSUME(style != nil);
  return style;
}

@end

