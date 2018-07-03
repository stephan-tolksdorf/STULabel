// Copyright 2018 Stephan Tolksdorf

#if __has_feature(objc_arc)
  #error This file must be compiled with -fno-objc-arc
#endif

#import "STULabel/STUDefines.h"

#import <Foundation/Foundation.h>

namespace stu_label::detail {

// We don't want to include the header since this is a no-objc-arc file.
STU_DISABLE_CLANG_WARNING("-Wmissing-prototypes")

CFTypeRef objectAtIndex(NSArray* array, id (* method)(NSArray *, SEL, NSUInteger),
                        NSUInteger index)
{
  return method(array, @selector(objectAtIndex:), index);
}

STU_REENABLE_CLANG_WARNING

}
