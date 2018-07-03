// Copyright 2018 Stephan Tolksdorf

#import "STUTextFrameDrawingOptions.h"

#import "Internal/TextFrameDrawingOptions.hpp"

@interface STUTextFrameDrawingOptions() {
@package
  stu_label::TextFrameDrawingOptions impl;
}
@end

STU_EXTERN_C_BEGIN

/// @pre `other.class == STUTextFrameDrawingOptions.class`
STUTextFrameDrawingOptions*
  STUTextFrameDrawingOptionsCopy(STUTextFrameDrawingOptions* __nullable other) NS_RETURNS_RETAINED;

STU_EXTERN_C_END
