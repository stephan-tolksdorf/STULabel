// Copyright 2018 Stephan Tolksdorf

#import "DisplayScaleRounding.hpp"

#import "TestUtils.h"

#import <limits>
#import <random>

using namespace stu_label;

STU_NO_INLINE
static double naiveFloorToScale(double x, double scale) {
  return floor(x*scale)/scale;
}

STU_NO_INLINE
static double naiveCeilToScale(double x, double scale) {
  return ceil(x*scale)/scale;
}

@interface DisplayScaleRounding : XCTestCase
@end

@implementation DisplayScaleRounding


- (void)testDocumentationClaims {
  XCTAssertEqual(naiveFloorToScale(1 + 4/3.0, 3), 2);
  XCTAssertEqual(naiveCeilToScale(6/3.0 + 7/3.0, 3), (6 + 8)/3.0);

  const DisplayScale scale{*DisplayScale::create(3)};
  XCTAssertEqual(floorToScale(1 + 4/3.0, scale), 7*(1/3.0));
  XCTAssertEqual(ceilToScale(6/3.0 + 7/3.0, scale), (6 + 7)*(1/3.0));
}

- (void)testCreate {
  XCTAssertEqual(DisplayScale::create(1), 1);
  XCTAssertTrue(!DisplayScale::create(0));
  XCTAssertTrue(!DisplayScale::create(-1));
  XCTAssertTrue(!DisplayScale::create(std::numeric_limits<Float32>::denorm_min()));
  XCTAssertTrue(!DisplayScale::create(infinity<Float32>));
#if CGFLOAT_IS_DOUBLE
  XCTAssertTrue(!DisplayScale::create(std::numeric_limits<Float64>::denorm_min()));
  XCTAssertTrue(!DisplayScale::create(maxValue<Float64>));
  XCTAssertTrue(!DisplayScale::create(infinity<Float64>));
#endif
  XCTAssertTrue(!DisplayScale::create(NAN));
}

- (void)testCreateOrIfInvalidGetMainSceenScale {
  XCTAssertEqual(DisplayScale::createOrIfInvalidGetMainSceenScale(2), 2);
  XCTAssertEqual(DisplayScale::createOrIfInvalidGetMainSceenScale(0), UIScreen.mainScreen.scale);
  XCTAssertEqual(DisplayScale::createOrIfInvalidGetMainSceenScale(infinity<Float64>),
                 UIScreen.mainScreen.scale);
}

- (void)testDisplayScaleOptional {
  Optional<DisplayScale> scale = DisplayScale::oneAsOptional();
  XCTAssertTrue(scale);
  XCTAssertEqual(scale, 1);
  scale = none;
  XCTAssertFalse(scale);
  scale = DisplayScale::create(3);
  XCTAssertEqual(scale, 3);
}

- (void)testRounding {
  self.continueAfterFailure = false;
  auto test = [&](auto scaleValue, int n) {
    using Float = decltype(scaleValue);
    using stu_label::detail::maxRelDiffForRounding;
    std::mt19937 rng{123};
    std::uniform_real_distribution<Float> ud(-2, 2);
    const DisplayScale scale{*DisplayScale::create(scaleValue)};
    const Float inverseScale = 1/scaleValue;
    for (int i = 0; i < n; ++i) {
      const Float xe = i*inverseScale*(1 + ud(rng)*maxRelDiffForRounding<Float>);
      const Float x = nearbyint(xe*scaleValue)*inverseScale;
      XCTAssertEqual(roundToScale(xe, scale), x);
      const Float e = abs(x - xe);
      const Float maxError = xe*maxRelDiffForRounding<Float>;
      if (e <= maxError || xe > x) {
        XCTAssertEqual(floorToScale(xe, scale), x);
      } else {
        XCTAssertEqual(floorToScale(xe, scale), floor(xe*scaleValue)*inverseScale);
      }
      if (e <= maxError || xe < x) {
        XCTAssertEqual(ceilToScale(xe, scale), x);
      } else {
        XCTAssertEqual(ceilToScale(xe, scale), ceil(xe*scaleValue)*inverseScale);
      }
    }
  };

  test(CGFloat{2}, 100000);
  test(CGFloat{3}, 100000);
  test(float{2}, 100000);
  test(float{3}, 100000);
  test(CGFloat{8}/9, 100000);
}

- (void)testCeilSize {
  const CGSize r = ceilToScale(CGSize{CGFloat(0.1), CGFloat(1.6)}, *DisplayScale::create(2));
  XCTAssertEqual(r.width, 0.5);
  XCTAssertEqual(r.height, 2);
}

- (void)testCeilRect {
  const CGRect r = ceilToScale(CGRect{{.x = 0.375, .y = 0.875}, {.width = 1, .height = 2}},
                               *DisplayScale::create(2));
  XCTAssertEqual(r.origin.x, 0);
  XCTAssertEqual(r.origin.y, 0.5);
  XCTAssertEqual(r.size.width, 1.5);
  XCTAssertEqual(r.size.height, 2.5);
}

@end
