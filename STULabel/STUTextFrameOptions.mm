// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUTextFrameOptions-Internal.hpp"

#import "STULabel/STUShapedString.h"

#import "Internal/InputClamping.hpp"
#import "Internal/Once.hpp"

using namespace stu;
using namespace stu_label;

#define FOR_ALL_FIELDS(f) \
  f(NSInteger, maximumLineCount) \
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

- (instancetype)init {
  return [self initWithOptions:nil];
}
- (instancetype)initWithOptions:(nullable STUTextFrameOptions*)options {
  if (!options) {
    _minimumTextScaleFactor = 1;
    _textScaleFactorStepSize = 1/128.f;
    static_assert((int)STUDefaultTextAlignmentLeft == (int)STUWritingDirectionLeftToRight);
    static_assert((int)STUDefaultTextAlignmentRight == (int)STUWritingDirectionRightToLeft);
    _defaultTextAlignment = STUDefaultTextAlignment(stu_defaultBaseWritingDirection());
  } else {
  #define ASSIGN(Type, name) _##name = options->_##name;
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

- (void)setMaximumLineCount:(NSInteger)maximumLineCount {
  _maximumLineCount = clampMaxLineCount(maximumLineCount);
}

- (void)setLastLineTruncationMode:(STULastLineTruncationMode)lastLineTruncationMode {
  _lastLineTruncationMode = clampLastLineTruncationMode(lastLineTruncationMode);
}

- (void)setTruncationToken:(NSAttributedString*)truncationToken {
  // TODO: Convert NSTextAttachments.
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
#define DEFINE_GETTER(Type, name) - (Type)name { return _##name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

- (instancetype)init {
  return [self initWithBuilder:nil];
}
- (instancetype)initWithBuilder:(nullable STUTextFrameOptionsBuilder*)builder {
  if (!builder) {
    _minimumTextScaleFactor = 1;
    static_assert((int)STUDefaultTextAlignmentLeft == (int)STUWritingDirectionLeftToRight);
    static_assert((int)STUDefaultTextAlignmentRight == (int)STUWritingDirectionRightToLeft);
    _defaultTextAlignment = STUDefaultTextAlignment(stu_defaultBaseWritingDirection());
  } else {
  #define ASSIGN(Type, name) _##name = builder->_##name;
    FOR_ALL_FIELDS(ASSIGN)
  #undef ASSIGN
  }
  return self;
}

STUTextFrameOptions*
  STUTextFrameOptionsCopy(STUTextFrameOptions* __unsafe_unretained options) NS_RETURNS_RETAINED
{
  STUTextFrameOptions* const newOptions = [[STUTextFrameOptions alloc] init];
  #define ASSIGN(Type, name) newOptions->_##name = options->_##name;
    FOR_ALL_FIELDS(ASSIGN)
  #undef ASSIGN
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
