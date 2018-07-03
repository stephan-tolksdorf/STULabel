// Copyright 2017 Stephan Tolksdorf

#import "STULabel/STUDefines.h"

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
  Float32 c1x, c1y, c2x, c2y;
} STUMediaTimingFunctionControlPoints;

STU_INLINE
STUMediaTimingFunctionControlPoints stuMediaTimingFunctionControlPoints(CAMediaTimingFunction *f) {
  Float32 c1[2];
  [f getControlPointAtIndex:1 values:c1];
  Float32 c2[2];
  [f getControlPointAtIndex:2 values:c2];
  return (STUMediaTimingFunctionControlPoints){c1[0], c1[1], c2[0], c2[1]};
}

STU_INLINE bool stu_CAMediaTimingFunctionEqualToFunction(
                   CAMediaTimingFunction * __nullable a, CAMediaTimingFunction * __nullable b)
{
  if (a == b) return true;
  if (!a || !b) return false;
  const STUMediaTimingFunctionControlPoints cas = stuMediaTimingFunctionControlPoints(a);
  const STUMediaTimingFunctionControlPoints cbs = stuMediaTimingFunctionControlPoints(b);
  return cas.c1x == cbs.c1x && cas.c1y == cbs.c1y
      && cas.c2x == cbs.c2x && cas.c2y == cbs.c2y;
}

NS_ASSUME_NONNULL_END
