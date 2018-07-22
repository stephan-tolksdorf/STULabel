/// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTruncationScope-Internal.h"

#import "STUTextAttachment.h"

#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"

using namespace stu;
using namespace stu_label;


@implementation STUTruncationScopeAttribute

- (instancetype)init {
  return [self initWithMaximumLineCount:0 lastLineTruncationMode:kCTLineTruncationEnd
                        truncationToken:nil];
}

- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount {
  return [self initWithMaximumLineCount:maximumLineCount
                 lastLineTruncationMode:kCTLineTruncationEnd
                        truncationToken:nil];
}

static void clampTruncationScopeParameters(STUTruncationScopeAttribute& self) {
  if (self._maximumLineCount < 0) {
    self._maximumLineCount = 0;
  }
  switch (self._lastLineTruncationMode) {
  case kCTLineTruncationStart:
  case kCTLineTruncationEnd:
   break;
  case kCTLineTruncationMiddle:
    self._truncatableStringRange.length = 0;
    break;
  default:
    self._lastLineTruncationMode = kCTLineTruncationEnd;
  }
}

- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount
                  lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                         truncationToken:(nullable NSAttributedString*)truncationToken
{
  return [self initWithMaximumLineCount:maximumLineCount
                 lastLineTruncationMode:lastLineTruncationMode
                        truncationToken:truncationToken
                 truncatableStringRange:NSRange{NSNotFound, 0}];
}


- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount
                  lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                         truncationToken:(nullable NSAttributedString*)truncationToken
                  truncatableStringRange:(NSRange)truncatableStringRange
{
  STU_CHECK_MSG(truncatableStringRange.length == 0
                || lastLineTruncationMode != kCTLineTruncationMiddle,
                "With kCTLineTruncationMiddle as the truncation mode, truncatableStringRange.length must be 0.");
  _truncatableStringRange = truncatableStringRange;
  _maximumLineCount = maximumLineCount;
  _lastLineTruncationMode = lastLineTruncationMode;
  _truncationToken = [truncationToken copy];
  _fixedTruncationToken =
    [_truncationToken stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments];
  clampTruncationScopeParameters(*self);
  return self;
}

#define FOR_ALL_FIELDS(f) \
  f(NSRange, truncatableStringRange) \
  f(int32_t, maximumLineCount) \
  f(CTLineTruncationType, lastLineTruncationMode) \
  f(NSAttributedString*, truncationToken)
  // _fixedTruncationToken is a derived and purely internal property

#define DEFINE_GETTER(Type, name) - (Type)name { return _##name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

+ (BOOL)supportsSecureCoding { return true; }

- (void)encodeWithCoder:(NSCoder*)encoder {
#define ENCODE(Type, name) encode(encoder, @STU_STRINGIZE(name), _ ## name);
  FOR_ALL_FIELDS(ENCODE)
#undef ENCODE
}

- (nullable instancetype)initWithCoder:(NSCoder*)decoder {
#define DECODE(Type, name) decode(decoder, @STU_STRINGIZE(name), Out{_##name});
  FOR_ALL_FIELDS(DECODE)
#undef DECODE
  clampTruncationScopeParameters(*self);
  return self;
}

#undef FOR_ALL_FIELDS

@end
