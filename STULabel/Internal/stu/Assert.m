// Copyright 2017–2018 Stephan Tolksdorf

#include "stu/Assert.h"

#import <Foundation/Foundation.h>

#if STU_DEBUG
#import <stdatomic.h>
#endif

#if STU_ASSERT_MAY_THROW
_Atomic(bool) stu_assertion_test;
#endif

#define handleFailure(fileName, line, functionName, format, ...) \
    [[NSAssertionHandler currentHandler] \
       handleFailureInFunction:(functionName ? [NSString stringWithUTF8String:functionName] \
                                             : @"<Unknown Function>") \
                          file:(fileName ? [NSString stringWithUTF8String:fileName] \
                                         : @"<Unknown File>") \
                    lineNumber:line \
                   description:format, ##__VA_ARGS__];

#ifdef __cplusplus
  extern "C"
#endif
__attribute__((noreturn))
void stu_assertion_failed(const char *fileName, int line, const char *functionName,
                          const char *condition)
{
#if STU_DEBUG
  if (atomic_load_explicit(&stu_assertion_test, memory_order_relaxed)) {
    [NSException raise:NSInternalInconsistencyException format:@"Expected assertion failure"];
  }
#endif
  handleFailure(fileName, line, functionName, @"Condition not satisfied: %s", condition);
  __builtin_trap();
}

