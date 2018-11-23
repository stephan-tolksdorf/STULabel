// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUTextFrameOptions-Internal.hpp"

#import "STULabel/STUObjCRuntimeWrappers.h"
#import "STULabel/STUShapedString.h"

#import "Internal/InputClamping.hpp"
#import "Internal/Once.hpp"

using namespace stu;
using namespace stu_label;

#define FOR_ALL_FIELDS(f) \
  f(NSInteger, maximumNumberOfLines) \
  f(STUTextLayoutMode, textLayoutMode) \
  f(STUDefaultTextAlignment, defaultTextAlignment) \
  f(STULastLineTruncationMode, lastLineTruncationMode) \
  f(NSAttributedString* __nullable, truncationToken) \
  f(__nullable STUTruncationRangeAdjuster, truncationRangeAdjuster) \
  f(CGFloat, minimumTextScaleFactor) \
  f(CGFloat, textScaleFactorStepSize) \
  f(STUBaselineAdjustment, textScalingBaselineAdjustment) \
  f(__nullable STULastHyphenationLocationInRangeFinder, lastHyphenationLocationInRangeFinder)

#define DEFINE_FIELD(Type, name) Type _##name;

@implementation STUTextFrameOptionsBuilder {
@package // fileprivate
  FOR_ALL_FIELDS(DEFINE_FIELD)
}

#undef DEFINE_FIELD

#define SET_DEFAULT_OPTIONS(object, prefix) \
  object prefix##minimumTextScaleFactor = 1; \
  object prefix##textScaleFactorStepSize = 1/128.f; \
  object prefix##defaultTextAlignment = STUDefaultTextAlignment(stu_defaultBaseWritingDirection()); \

static_assert((int)STUDefaultTextAlignmentLeft == (int)STUWritingDirectionLeftToRight);
static_assert((int)STUDefaultTextAlignmentRight == (int)STUWritingDirectionRightToLeft);

- (instancetype)init {
  return [self initWithOptions:nil];
}
- (instancetype)initWithOptions:(nullable STUTextFrameOptions*)options {
  if (!options) {
    SET_DEFAULT_OPTIONS(,_);
  } else {
  #define ASSIGN(Type, name) _##name = options->_options.name;
    FOR_ALL_FIELDS(ASSIGN)
  #undef ASSIGN
  }
  return self;
}

- (void)setTextLayoutMode:(STUTextLayoutMode)textLayoutMode {
  _textLayoutMode = clampTextLayoutMode(textLayoutMode);
}

- (void)setDefaultTextAlignment:(STUDefaultTextAlignment)defaultTextAlignment {
  _defaultTextAlignment = clampDefaultTextAlignment(defaultTextAlignment);
}

- (void)setMaximumNumberOfLines:(NSInteger)maximumNumberOfLines {
  _maximumNumberOfLines = clampMaxLineCount(maximumNumberOfLines);
}

- (void)setLastLineTruncationMode:(STULastLineTruncationMode)lastLineTruncationMode {
  _lastLineTruncationMode = clampLastLineTruncationMode(lastLineTruncationMode);
}

- (void)setTruncationToken:(NSAttributedString*)truncationToken {
  _truncationToken = [truncationToken copy];
}

- (void)setMinimumTextScaleFactor:(CGFloat)minimumTextScaleFactor {
  _minimumTextScaleFactor = clampMinTextScaleFactor(minimumTextScaleFactor);
}

- (void)setTextScaleFactorStepSize:(CGFloat)textScaleFactorStepSize {
  _textScaleFactorStepSize = clampTextScaleFactorStepSize(textScaleFactorStepSize);
}

- (void)setTextScalingBaselineAdjustment:(STUBaselineAdjustment)baselineAdjustment {
  _textScalingBaselineAdjustment = clampBaselineAdjustment(baselineAdjustment);
}

- (void)setLastHyphenationLocationInRangeFinder:(STULastHyphenationLocationInRangeFinder)block {
  _lastHyphenationLocationInRangeFinder = block;
}

@end

@implementation STUTextFrameOptions

// Manually define getter methods, so that we don't have to declare the properties as "nonatomic".
#define DEFINE_GETTER(Type, name) - (Type)name { return _options.name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

- (instancetype)init {
  return [self initWithBuilder:nil];
}

- (instancetype)initWithBuilder:(nullable STUTextFrameOptionsBuilder*)builder {
#ifdef __clang_analyzer__
  self = [super init]; // Since the superclass is NSObject, this call is unnecesary.
#endif
  if (!builder) {
    SET_DEFAULT_OPTIONS(_options.,);
  } else {
  #define ASSIGN(Type, name) self->_options.name = builder->_##name;
    FOR_ALL_FIELDS(ASSIGN) // clang analyzer bug
  #undef ASSIGN
    _options.fixedTruncationToken =
      [_options.truncationToken stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments];
  }
  return self;
}

STU_INLINE Class stuTextFrameOptionsClass() {
  STU_STATIC_CONST_ONCE(Class, value, STUTextFrameOptions.class);
  return value;
}

STUTextFrameOptions*
  STUTextFrameOptionsCopy(STUTextFrameOptions* __unsafe_unretained options) NS_RETURNS_RETAINED
{
  STUTextFrameOptions* const newOptions = stu_createClassInstance(stuTextFrameOptionsClass(), 0);
  newOptions->_options = options->_options;
  return newOptions;
}

- (id)copyWithZone:(NSZone* __unused)zone {
  return self;
}

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUTextFrameOptionsBuilder*))block {
  STUTextFrameOptionsBuilder* const builder = [[STUTextFrameOptionsBuilder alloc] init];
  block(builder);
  return [self initWithBuilder:builder];
}

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUTextFrameOptionsBuilder*))block {
  STUTextFrameOptionsBuilder* const builder = [[STUTextFrameOptionsBuilder alloc]
                                                 initWithOptions:self];
  block(builder);
  return [(STUTextFrameOptions*)[self.class alloc] initWithBuilder:builder];
}

@end
