// Copyright 2017–2018 Stephan Tolksdorf

#import "STUShapedString.h"

#import "Internal/Unretained.hpp"

namespace stu_label {
  class ShapedString;
  Unretained<STUShapedString* __nonnull> emptyShapedString(STUWritingDirection);
}

STU_EXTERN_C_BEGIN

@interface STUShapedString () {
@package
  const stu_label::ShapedString* const shapedString;
}
@end

STUShapedString* __nullable STUShapedStringCreate(__nullable Class cls,
                                                  NSAttributedString*  __nonnull,
                                                  STUWritingDirection,
                                                  const STUCancellationFlag* __nullable)
                              NS_RETURNS_RETAINED;

NSAttributedString* __nonnull stu_emptyAttributedString();

STU_EXTERN_C_END

