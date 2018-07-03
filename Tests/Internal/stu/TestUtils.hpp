// Copyright 2018 Stephan Tolksdorf

#pragma once

#import <XCTest/XCTest.h>

#import <stdatomic.h>

#define TEST_CASE_START(name) \
@interface stu_##name : XCTestCase \
@end \
@implementation stu_##name \
- (void)setUp { \
  [super setUp]; \
  self.continueAfterFailure = false; \
}

#define TEST_CASE_END @end

#define TEST(name) - (void)test##name

#define CHECK(expr) XCTAssertTrue(expr)

#define CHECK_EQ(a, b) XCTAssertEqual(a, b)

#define CHECK_FAILS_ASSERT(expr) \
{ \
  atomic_store_explicit(&stu_assertion_test, true, memory_order_relaxed); \
  XCTAssertThrows(expr); \
  atomic_store_explicit(&stu_assertion_test, false, memory_order_relaxed); \
}

#define CHECK_THROWS_BAD_ALLOC(expr) \
  try { \
    (void)(expr); \
    CHECK(false && "expression did not throw std::bad_alloc"); \
  } catch (const std::bad_alloc&) {}

#define CHECK_THROWS(expr, Exception) \
  try { \
    (void)(expr); \
    CHECK(false && "expression did not throw" STU_STRINGIZE(Exception)); \
  } catch (const Exception&) {}
