// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

STU_EXTERN_C_BEGIN

/// A simple wrapper of @c class_createInstance callable from ARC code.
id stu_createClassInstance(Class cls, size_t extraBytes) NS_RETURNS_RETAINED;

/// A simple wrapper of @c objc_constructInstance callable from ARC code.
id stu_constructClassInstance(Class cls, void *storage) NS_RETURNS_RETAINED;

/// A simple wrapper of @c object_getIndexedIvars callable from ARC code.
void *stu_getObjectIndexedIvars(id object);

STU_EXTERN_C_END

NS_ASSUME_NONNULL_END
