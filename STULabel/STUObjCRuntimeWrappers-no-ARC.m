// Copyright 2017–2018 Stephan Tolksdorf

#if __has_feature(objc_arc)
  #error This file must be compiled with -fno-objc-arc
#endif

#import "STUObjCRuntimeWrappers.h"

#import "stu/Assert.h"

#import <objc/runtime.h>

STU_EXPORT STU_NO_INLINE
id stu_createClassInstance(Class cls, size_t extraBytes) NS_RETURNS_RETAINED {
  void * const instance = class_createInstance(cls, extraBytes);
  STU_CHECK_MSG(instance != nil, "Failed to allocate class instance.");
  return instance;
}

STU_EXPORT STU_NO_INLINE
id stu_constructClassInstance(Class cls, void *storage) NS_RETURNS_RETAINED {
  const id instance = objc_constructInstance(cls, storage);
  STU_CHECK_MSG(instance != nil, "Failed to construct class instance.");
  return instance;
}

STU_EXPORT
void *stu_getObjectIndexedIvars(id object) {
  return object_getIndexedIvars(object);
}
