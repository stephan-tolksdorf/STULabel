// Copyright 2017–2018 Stephan Tolksdorf

#if __has_feature(objc_arc)
  #error This file must be compiled with -fno-objc-arc
#endif

#import "STULabelPrerenderer-Internal.hpp"

#import <objc/runtime.h>

@implementation STULabelPrerenderer

+ (instancetype)allocWithZone:(struct _NSZone* __unused)zone {
  return STULabelPrerendererAlloc(self);
}

STU_DISABLE_CLANG_WARNING("-Wobjc-missing-super-calls")
- (void)dealloc {
  stu_label::LabelPrerenderer& p = *self->prerenderer;
  objc_destructInstance(self);
  stu_label::detail::labelPrerendererObjCObjectWasDestroyed(p);
}
STU_REENABLE_CLANG_WARNING

@end

