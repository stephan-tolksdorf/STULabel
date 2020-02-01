// Copyright 2017–2018 Stephan Tolksdorf

#import "STUBackgroundAttribute-Internal.h"

#import "Internal/Equal.hpp"
#import "Internal/Hash.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

STU_EXPORT
const NSAttributedStringKey STUBackgroundAttributeName = @"STUBackground";

@interface STUBackgroundAttribute() {
@package
  NSInteger _discriminator;
}
@end

#define FOR_ALL_FIELDS(f) \
  f(UIColor *, color) \
  f(bool, fillTextLineGaps) \
  f(bool, extendTextLinesToCommonHorizontalBounds) \
  f(CGFloat, cornerRadius) \
  f(UIEdgeInsets, edgeInsets) \
  f(UIColor *, borderColor) \
  f(CGFloat, borderWidth) \
  f(NSInteger, discriminator)

@implementation STUBackgroundAttributeBuilder {
@package // Accessed by the Attribute's initWithBuilder.
  #define DEFINE_FIELD(Type, name) Type _##name;
  FOR_ALL_FIELDS(DEFINE_FIELD)
  #undef DEFINE_FIELD
}

#define SET_DEFAULT_VALUES() \
  _fillTextLineGaps = true; \
  _extendTextLinesToCommonHorizontalBounds = true \


- (instancetype)init {
  return [self initWithBackgroundAttribute:nil];
}
- (instancetype)initWithBackgroundAttribute:(STUBackgroundAttribute *)attribute {
  if (attribute) {
  #define ASSIGN_FROM_ATTRIBUTE(Type, name) _##name = attribute->_##name;
    FOR_ALL_FIELDS(ASSIGN_FROM_ATTRIBUTE)
  #undef ASSIGN_FROM_ATTRIBUTE
  } else {
    SET_DEFAULT_VALUES();
  }
  return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
  _cornerRadius = clampFloatInput(cornerRadius);
}

- (void)setEdgeInsets:(UIEdgeInsets)edgeInsets {
  _edgeInsets = clampEdgeInsetsInput(edgeInsets);
}

- (void)setBorderWidth:(CGFloat)borderWidth {
  _borderWidth = clampFloatInput(borderWidth);
}

@end

@implementation STUBackgroundAttribute

// Manually define getter methods, so that the properties don't have to be declared as "nonatomic".
#define DEFINE_GETTER(Type, name) - (Type)name { return _##name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

+ (BOOL)supportsSecureCoding { return true; }

- (void)encodeWithCoder:(NSCoder *)encoder {
#define ENCODE(Type, name) encode(encoder, @STU_STRINGIZE(name), _##name);
  FOR_ALL_FIELDS(ENCODE);
#undef ENCODE
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
#define DECODE(Type, name) decode(decoder, @STU_STRINGIZE(name), Out{_##name});
  FOR_ALL_FIELDS(DECODE);
#undef DECODE
  _cornerRadius = clampFloatInput(_cornerRadius);
  _edgeInsets = clampEdgeInsetsInput(_edgeInsets);
  _borderWidth = clampFloatInput(_borderWidth);
  return self;
}

- (instancetype)init {
  return [self initWithBuilder:nil];
}
- (instancetype)initWithBuilder:(nullable STUBackgroundAttributeBuilder *)builder {
#ifdef __clang_analyzer__
  self = [super init]; // Since the superclass is NSObject, this call is unnecesary.
#endif
  if (builder) {
  #define ASSIGN_FROM_BUILDER(Type, name) _##name = builder->_##name;
    FOR_ALL_FIELDS(ASSIGN_FROM_BUILDER) // clang analyzer bug
  #undef ASSIGN_FROM_BUILDER
  } else {
    SET_DEFAULT_VALUES();
  }
  return self;
}

- (id)copyWithZone:(NSZone * __unused)zone {
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  STU_STATIC_CONST_ONCE(Class, stuBackgroundAttributeClass, STUBackgroundAttribute.class);
  if (![object isKindOfClass:stuBackgroundAttributeClass]) return false;
  STUBackgroundAttribute* const other = object;
#define IF_NOT_EQUAL_RETURN_FALSE(Type, name) if (!equal(_##name, other->_##name)) return false;
  FOR_ALL_FIELDS(IF_NOT_EQUAL_RETURN_FALSE)
#undef IF_NOT_EQUAL_RETURN_FALSE
  return true;
}

- (NSUInteger)hash {
  const auto h = hash((UInt{_fillTextLineGaps} << 8) | _extendTextLinesToCommonHorizontalBounds,
                      _discriminator, _cornerRadius, _borderWidth, _color);
                      // Doesn't include borderColor and edgeInsets.
  return narrow_cast<NSUInteger>(h);
}

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUBackgroundAttributeBuilder *))block {
  auto* const builder = [[STUBackgroundAttributeBuilder alloc] init];
  block(builder);
  return [self initWithBuilder:builder];
}

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUBackgroundAttributeBuilder *))block {
  auto* const builder = [[STUBackgroundAttributeBuilder alloc] initWithBackgroundAttribute:self];
  block(builder);
  return [(STUBackgroundAttribute *)[self.class alloc] initWithBuilder:builder];
}

@end


