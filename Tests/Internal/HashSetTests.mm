// Copyright 2017–2018 Stephan Tolksdorf

#import "HashTable.hpp"

#import "AllocatorUtils.hpp"
#import "TestUtils.h"

#import <random>
#import <unordered_set>

using namespace stu_label;

@interface HashSetTests : XCTestCase
@end

@implementation HashSetTests

- (void)testInitializeWithBucketCount {
  HashSet<UInt16, Malloc> hs{uninitialized};
  XCTAssert(hs.buckets().isEmpty());
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(hs.initializeWithBucketCount(2));
  CHECK_FAILS_ASSERT(hs.initializeWithBucketCount(7));
#endif
  XCTAssertEqual(hs.count(), 0);
  hs.initializeWithBucketCount(8);
  XCTAssertEqual(hs.count(), 0);
  XCTAssertEqual(hs.buckets().count(), 8);
  for (auto& bucket : hs.buckets()) {
    XCTAssert(bucket.isEmpty());
  }
  hs.insertNew(HashCode{narrow_cast<UInt16>(~1u)}, 1u);
  XCTAssertEqual(hs.buckets()[6].hashCode.value, narrow_cast<UInt16>(~1u));
  XCTAssertEqual(hs.buckets()[6].keyPlus1, 2);
  for (Int i = 0; i < hs.buckets().count(); ++i) {
    if (i != 6) {
      XCTAssertTrue(hs.buckets()[i].isEmpty());
    }
  }
}

- (void)testInitializeWithExistingBuckets {
  HashSet<UInt16, Malloc> hs{uninitialized};
  using Bucket = HashSet<UInt16, Malloc>::Bucket;
  Array<Bucket> array{zeroInitialized, Count{6}};
  UInt16 value = 1;
  std::unordered_set<UInt16> set;
  for (auto& bucket : array) {
    set.insert(value);
    bucket.keyPlus1 = value + 1;
    bucket.hashCode = HashCode{narrow_cast<UInt16>(~value)};
    ++value;
  }
  hs.initializeWithExistingBuckets(array);
  XCTAssertEqual(hs.count(), 6);
  XCTAssertEqual(hs.buckets().count(), 16);
  for (UInt16 i = 1; i <= 6; ++i) {
    XCTAssertTrue(hs.find(HashCode{narrow_cast<UInt16>(~i)},
                          [i](UInt16 value) { return i == value; }));
  }
  for (auto& bucket : hs.buckets()) {
    if (!bucket.isEmpty()) {
      XCTAssertEqual(set.erase(bucket.keyPlus1 - 1), 1u);
    }
  }
  XCTAssertEqual(set.size(), 0u);
  hs.removeAll();
  XCTAssertEqual(hs.count(), 0);
  for (auto& bucket : hs.buckets()) {
    XCTAssertTrue(bucket.isEmpty());
  }
}

- (void)testInsertAndFind {
  self.continueAfterFailure = false;
  std::mt19937 mt{123};
  std::uniform_int_distribution<UInt16> d16{0, 15};
  std::uniform_int_distribution<int> d32{0, 31};
  std::unordered_set<UInt16> set;
  set.reserve(64);
  for (int i = 0; i < 10000; ++i) {
    set.clear();
    ValidatingMalloc alloc;
    HashSet<UInt16, Ref<ValidatingMalloc>> hs{uninitialized, Ref{alloc}};
    hs.initializeWithBucketCount(4);
    const int n = d32(mt);
    for (int j = 0; j < n; ++j) {
      const UInt16 r = d16(mt);
      const auto isEqual = [r](UInt16 value) { return value == r; };
      const Optional<UInt> optValue = hs.find(HashCode{narrow_cast<UInt16>(~r)}, isEqual);
      if (optValue) {
        XCTAssertEqual(*optValue, r);
      }
      const auto [value, inserted] = hs.insert(HashCode{narrow_cast<UInt16>(~r)}, r, isEqual);
      XCTAssertEqual(inserted, !optValue);
      XCTAssertEqual(value, r);
      if (inserted) {
        const auto [iter, inserted2] = set.insert(r);
        XCTAssert(inserted2);
      } else {
        XCTAssertNotEqual(set.find(r), set.end());
      }
    }
    XCTAssertEqual((size_t)hs.count(), set.size());
    for (auto value : set) {
      XCTAssertTrue(hs.find(HashCode{narrow_cast<UInt16>(~value)},
                            [value](UInt16 other) { return value == other; }));
    }
  }
}

@end
