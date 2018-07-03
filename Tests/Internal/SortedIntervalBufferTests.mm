// Copyright 2018 Stephan Tolksdorf

#import "SortedIntervalBuffer.hpp"

#import "TestUtils.h"

using namespace stu_label;

@interface SortedIntervalBufferTests : XCTestCase
@end

@implementation SortedIntervalBufferTests

- (void)testAdd {
  ThreadLocalArenaAllocator::InitialBuffer<1024> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  SortedIntervalBuffer<int> sib{freeCapacityInCurrentThreadLocalAllocatorBuffer};
  sib.add({1, 1});
  XCTAssert(sib.intervals().isEmpty());
  sib.add({1, 0});
  XCTAssert(sib.intervals().isEmpty());
  sib.add({1, 2});
  XCTAssertEqual(sib.intervals()[0], range(1, 2));
  sib.add({1, 2});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(1, 2));
  sib.add({0, 2});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(0, 2));
  sib.add({1, 3});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(0, 3));
  sib.add({4, 5});
  XCTAssertEqual(sib.intervals().count(), 2);
  XCTAssertEqual(sib.intervals()[1], range(4, 5));
  sib.add({3, 4});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(0, 5));
  sib.add({8, 9});
  XCTAssertEqual(sib.intervals().count(), 2);
  XCTAssertEqual(sib.intervals()[1], range(8, 9));
  sib.add({6, 7});
  XCTAssertEqual(sib.intervals().count(), 3);
  XCTAssertEqual(sib.intervals()[1], range(6, 7));
  sib.add({5, 8});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(0, 9));
  sib.add({10, 11});
  XCTAssertEqual(sib.intervals().count(), 2);
  XCTAssertEqual(sib.intervals()[1], range(10, 11));
  sib.add({12, 13});
  XCTAssertEqual(sib.intervals()[2], range(12, 13));
  sib.add({-2, -1});
  XCTAssertEqual(sib.intervals()[0], range(-2, -1));
  sib.add({-3, -1});
  XCTAssertEqual(sib.intervals()[0], range(-3, -1));
  sib.add({-2, -0});
  XCTAssertEqual(sib.intervals()[0], range(-3, 9));
  sib.add({11, 12});
  XCTAssertEqual(sib.intervals()[1], range(10, 13));
  sib.add({-4, 14});
  XCTAssertEqual(sib.intervals().count(), 1);
  XCTAssertEqual(sib.intervals()[0], range(-4, 14));
}

@end
