// Copyright 2018 Stephan Tolksdorf

#import "Hash.hpp"

#import "TestUtils.h"

using namespace stu_label;

@interface HashTests : XCTestCase
@end

@implementation HashTests

- (void)testHash {
  static_assert(hash(0u, 0u).value == 0);
  static_assert(hash(0xffffffffffffffff, 0xffffffffffffffff).value == 0xe286fb3ae0b4292f);
  static_assert(hash(0xfedcba9876543210u, 0x7654321089abcdefu).value == 0x3d9dc4e3bde6427d);
  static_assert(hash(0xfedcba9876543210u) == hash(0x76543210u, 0xfedcba98u));
#if __cpp_constexpr >= 201603
  static_assert(hash(1, 2, 3) == hash(hash(1, 2), 3));
  static_assert(hash(1, 2, 3, 4) == hash(hash(1, 2), hash(3, 4)));
  static_assert(hash(1, 2, 3, 4, 5) == hash(hash(hash(1, 2), hash(3, 4)), 5));
  static_assert(hash(1, 2, 3, 4, 5, 6) == hash(hash(hash(1, 2), hash(3, 4)), hash(5, 6)));
  static_assert(hash(1, 2, 3, 4, 5, 6, 7) == hash(hash(hash(1, 2), hash(3, 4)), hash(hash(5, 6), 7)));
#else
  XCTAssertEqual(hash(0, 0).value, 0);
  XCTAssertEqual(hash(0xffffffffffffffff, 0xffffffffffffffff).value, 0xe286fb3ae0b4292f);
  XCTAssertEqual(hash(0xfedcba9876543210, 0x7654321089abcdef).value, 0x3d9dc4e3bde6427d);
  XCTAssertEqual(hash(0xfedcba9876543210).value, hash(0x76543210, 0xfedcba98));
  XCTAssertEqual(hash(1, 2, 3), hash(hash(1, 2), 3));
  XCTAssertEqual(hash(1, 2, 3, 4), hash(hash(1, 2), hash(3, 4)));
  XCTAssertEqual(hash(1, 2, 3, 4, 5), hash(hash(hash(1, 2), hash(3, 4)), 5));
  XCTAssertEqual(hash(1, 2, 3, 4, 5, 6), hash(hash(hash(1, 2), hash(3, 4)), hash(5, 6)));
  XCTAssertEqual(hash(1, 2, 3, 4, 5, 6, 7), hash(hash(hash(1, 2), hash(3, 4)), hash(hash(5, 6), 7)));
#endif
  XCTAssertEqual(hash(0.f).value, 0u);
  XCTAssertEqual(hash(-0.f).value, 0u);
  XCTAssertEqual(hash(0.0).value, 0u);
  XCTAssertEqual(hash(-0.0).value, 0u);
  XCTAssertEqual(hash(@"test"), hash(@"test".hash));
  XCTAssertEqual(hash(CGSize{1, 2}), hash(CGFloat{1}, CGFloat{2}));
  XCTAssertEqual(hash(CGPoint{1, 2}), hash(CGFloat{1}, CGFloat{2}));
  XCTAssertEqual(hash(UIEdgeInsets{1, 2, 3, 4}), hash(CGFloat{1}, CGFloat{2}, CGFloat{3}, CGFloat{4}));
}

@end
