// Copyright 2018 Stephan Tolksdorf

#import <XCTest/XCTest.h>

#import "stu/Assert.h"

#import "stdatomic.h"

#define CHECK_FAILS_ASSERT(expr) \
{ \
  atomic_store_explicit(&stu_assertion_test, true, memory_order_relaxed); \
  XCTAssertThrows(expr); \
  atomic_store_explicit(&stu_assertion_test, false, memory_order_relaxed); \
}

