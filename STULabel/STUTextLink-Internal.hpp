// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextLink.h"

#import "Internal/Common.hpp"
#import "Internal/Unretained.hpp"

namespace stu_label {
  struct TextFrame;
  class TextFrameScaleAndDisplayScale;

  stu_label::Unretained<STUTextLinkArray* __nonnull> emptySTUTextLinkArray();

  Optional<Int> indexOfMatchingLink(NSArray<STUTextLink *>*, STUTextLink*);
}

@interface STUTextLinkArrayWithTextFrameOrigin : STUTextLinkArray
@end

NS_ASSUME_NONNULL_BEGIN

STUTextLinkArrayWithTextFrameOrigin*
  STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
    const stu_label::TextFrame& textFrame, CGPoint textFrameOrigin,
    const stu_label::TextFrameScaleAndDisplayScale& scaleFactors)
  NS_RETURNS_RETAINED;

STU_EXTERN_C_BEGIN

CGPoint STUTextLinkArrayGetTextFrameOrigin(const STUTextLinkArrayWithTextFrameOrigin* self);

STUTextLinkArrayWithTextFrameOrigin*
  STUTextLinkArrayCopyWithShiftedTextFrameOrigin(
    const STUTextLinkArrayWithTextFrameOrigin* self, CGPoint textFrameOrigin)
  NS_RETURNS_RETAINED;

STU_EXTERN_C_END

NS_ASSUME_NONNULL_END
