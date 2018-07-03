// Copyright 2018 Stephan Tolksdorf

#include "stu/NSFoundationSupport.hpp"

#include "TestUtils.hpp"

#if __has_feature(objc_arc)
  #error This file should be compiled with -fno-objc-arc
#endif

using namespace stu;

TEST_CASE_START(NSFoundationSupportNoARCTests)

TEST(RefCountTraits) {
  static_assert(isRefCountable<RemovePointer<CFArrayRef>>);
  static_assert(isRefCountable<NSArray>);
  const CFArrayRef obj = CFArrayCreateMutable(nullptr, 1, nullptr);
  XCTAssertEqual(CFGetRetainCount(obj), 1);
  incrementRefCount(obj);
  XCTAssertEqual(CFGetRetainCount(obj), 2);
  decrementRefCount(obj);
  XCTAssertEqual(CFGetRetainCount(obj), 1);
  incrementRefCount((NSArray*)obj);
  XCTAssertEqual(CFGetRetainCount(obj), 2);
  decrementRefCount((NSArray*)obj);
  XCTAssertEqual(CFGetRetainCount(obj), 1);
  decrementRefCount(obj);
}

TEST_CASE_END
