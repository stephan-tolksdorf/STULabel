
#import "STUParagraphStyle-Internal.hpp"

#import "Internal/Equal.hpp"
#import "Internal/Hash.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"

using namespace stu;
using namespace stu_label;

STU_EXPORT
const NSAttributedStringKey STUParagraphStyleAttributeName = @"STUParagraphExtraStyle";


static void clampFirstLineOffset(InOut<CGFloat> inOutOffset,
                                 InOut<STUFirstLineOffsetType> inOutType)
{
  STUFirstLineOffsetType& type = inOutType;
  CGFloat& offset = inOutOffset;
  if (offset < 0 && type != STUOffsetOfFirstBaselineFromDefault) {
    offset = 0;
  }
  offset = clampFloatInput(offset);
  switch (type) {
  case STUOffsetOfFirstBaselineFromDefault:
  case STUOffsetOfFirstBaselineFromTop:
  case STUOffsetOfFirstLineCenterFromTop:
  case STUOffsetOfFirstLineCapHeightCenterFromTop:
  case STUOffsetOfFirstLineXHeightCenterFromTop:
    break;
  default:
    type = STUOffsetOfFirstBaselineFromDefault;
    offset = 0;
  }
}

#define FOR_ALL_FIELDS(f) \
  f(STUFirstLineOffsetType, firstLineOffsetType) \
  f(CGFloat, firstLineOffset) \
  f(CGFloat, minimumBaselineDistance) \
  f(NSInteger, numberOfInitialLines) \
  f(CGFloat, initialLinesHeadIndent) \
  f(CGFloat, initialLinesTailIndent)

@implementation STUParagraphStyleBuilder {
@package // Accessed by the style's initWithBuilder.
  #define DEFINE_FIELD(Type, name) Type _##name;
  FOR_ALL_FIELDS(DEFINE_FIELD)
  #undef DEFINE_FIELD
}

- (instancetype)init {
  return [self initWithParagraphStyle:nil];
}
- (instancetype)initWithParagraphStyle:(STUParagraphStyle *)style {
  if (style) {
  #define ASSIGN_FROM_STYLE(Type, name) _##name = style->_style.name;
    FOR_ALL_FIELDS(ASSIGN_FROM_STYLE)
  #undef ASSIGN_FROM_STYLE
  }
  return self;
}

- (void)setFirstLineOffset:(CGFloat)firstLineOffset
                      type:(STUFirstLineOffsetType)firstLineOffsetType
{
  clampFirstLineOffset(InOut{firstLineOffset}, InOut{firstLineOffsetType});
  _firstLineOffset = firstLineOffset;
  _firstLineOffsetType = firstLineOffsetType;
}

- (void)setMinimumBaselineDistance:(CGFloat)minimumBaselineDistance {
  _minimumBaselineDistance = clampNonNegativeFloatInput(minimumBaselineDistance);
}

- (void)setNumberOfInitialLines:(NSInteger)numberOfInitialLines {
  _numberOfInitialLines = max(0, numberOfInitialLines);
}

- (void)setInitialLinesHeadIndent:(CGFloat)initialLinesHeadIndent {
  _initialLinesHeadIndent = clampNonNegativeFloatInput(initialLinesHeadIndent);
}

- (void)setInitialLinesTailIndent:(CGFloat)initialLinesTailIndent {
  _initialLinesTailIndent = clampNonPositiveFloatInput(initialLinesTailIndent);
}

@end

@implementation STUParagraphStyle

// Manually define getter methods, so that the properties don't have to be declared as "nonatomic".
#define DEFINE_GETTER(Type, name) - (Type)name { return _style.name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

+ (BOOL)supportsSecureCoding { return true; }

- (void)encodeWithCoder:(NSCoder *)encoder {
#define ENCODE(Type, name) encode(encoder, @STU_STRINGIZE(name), _style.name);
  FOR_ALL_FIELDS(ENCODE);
#undef ENCODE
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  ParagraphExtraStyle& style = _style;
#define DECODE(Type, name) decode(decoder, @STU_STRINGIZE(name), Out{style.name});
  FOR_ALL_FIELDS(DECODE);
#undef DECODE
  clampFirstLineOffset(InOut{style.firstLineOffset}, InOut{style.firstLineOffsetType});
  style.minimumBaselineDistance = clampNonNegativeFloatInput(style.minimumBaselineDistance);
  style.numberOfInitialLines = max(0, style.numberOfInitialLines);
  style.initialLinesHeadIndent = clampNonNegativeFloatInput(style.initialLinesHeadIndent);
  style.initialLinesTailIndent = clampNonPositiveFloatInput(style.initialLinesTailIndent);
  return self;
}

- (instancetype)init {
  return [self initWithBuilder:nil];
}
- (instancetype)initWithBuilder:(nullable STUParagraphStyleBuilder *)builder {
#ifdef __clang_analyzer__
  self = [super init]; // Since the superclass is NSObject, this call is unnecesary.
#endif
  if (builder) {
    ParagraphExtraStyle& style = _style;
  #define ASSIGN_FROM_BUILDER(Type, name) style.name = builder->_##name;
    FOR_ALL_FIELDS(ASSIGN_FROM_BUILDER) // clang analyzer bug
  #undef ASSIGN_FROM_BUILDER
  }
  return self;
}

- (id)copyWithZone:(NSZone * __unused)zone {
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  STU_STATIC_CONST_ONCE(Class, stuParagraphStyleClass, STUParagraphStyle.class);
  if (![object isKindOfClass:stuParagraphStyleClass]) return false;
  STUParagraphStyle* const other = object;
#define IF_NOT_EQUAL_RETURN_FALSE(Type, name) if (!equal(_style.name, other->_style.name)) return false;
  FOR_ALL_FIELDS(IF_NOT_EQUAL_RETURN_FALSE)
#undef IF_NOT_EQUAL_RETURN_FALSE
  return true;
}

- (NSUInteger)hash {
  ParagraphExtraStyle& style = _style;
  const auto h = hash(style.firstLineOffsetType, style.firstLineOffset,
                      style.numberOfInitialLines,
                      hashableBits(style.initialLinesHeadIndent)
                      ^ hashableBits(style.initialLinesTailIndent));
  return narrow_cast<NSUInteger>(h);
}

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUParagraphStyleBuilder *))block {
  auto* const builder = [[STUParagraphStyleBuilder alloc] init];
  block(builder);
  return [self initWithBuilder:builder];
}

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUParagraphStyleBuilder *))block {
  auto* const builder = [[STUParagraphStyleBuilder alloc] initWithParagraphStyle:self];
  block(builder);
  return [(STUParagraphStyle *)[self.class alloc] initWithBuilder:builder];
}

@end
