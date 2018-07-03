// Copyright 2017–2018 Stephan Tolksdorf

#import "GlyphPathIntersectionBounds.hpp"

#import "CoreGraphicsUtils.hpp"

namespace stu_label {

struct PathIntersectionXBoundsState {
  const LowerAndUpperInterval yis;
  LowerAndUpperInterval xis;
  const CGFloat maxErrorSquaredTimes16;
  CGPoint startPoint;
  CGPoint previousPoint;
};

static void addLine(PathIntersectionXBoundsState& s, CGPoint a, CGPoint b) {
  CGFloat stripeMinY = s.yis.lower.start;
  CGFloat stripeMaxY = s.yis.lower.end;
  Range<CGFloat>* xi = &s.xis.lower;
  STU_DISABLE_LOOP_UNROLL
  for (;;) {
    const CGFloat minY = min(a.y, b.y);
    const CGFloat maxY = max(a.y, b.y);
    if (minY <= stripeMaxY && maxY >= stripeMinY) {
      CGFloat minX = xi->start;
      CGFloat maxX = xi->end;
      int n = 2;
      if (stripeMinY <= a.y && a.y <= stripeMaxY) {
        minX = min(minX, a.x);
        maxX = max(maxX, a.x);
        --n;
      }
      if (stripeMinY <= b.y && b.y <= stripeMaxY) {
        minX = min(minX, b.x);
        maxX = max(maxX, b.x);
        --n;
      }
      if (n != 0) {
        STU_DEBUG_ASSERT(a.y != b.y);
        const CGFloat d = (b.x - a.x)/(b.y - a.y);
        const CGFloat x1 = a.x + (stripeMaxY - a.y)*d;
        const CGFloat x2 = a.x + (stripeMinY - a.y)*d;
        if (minY <= stripeMaxY && stripeMaxY <= maxY) {
          minX = min(minX, x1);
          maxX = max(maxX, x1);
        }
        if (minY <= stripeMinY && stripeMinY <= maxY) {
          minX = min(minX, x2);
          maxX = max(maxX, x2);
        }
      }
      xi->start = minX;
      xi->end = maxX;
    }
    if (stripeMinY == s.yis.upper.start) return;
    stripeMinY = s.yis.upper.start;
    stripeMaxY = s.yis.upper.end;
    xi = &s.xis.upper;
  } // for (;;)
}

// To avoid root-finding for non-linear curves we "flatten" the bezier path, i.e. approximate it
// linearly, by recursively subdividing the curves using de Casteljau's algorithm.

static const size_t maxRecursionDepth = 8;

static void addQuadraticCurve(PathIntersectionXBoundsState& s,
                              CGPoint a, CGPoint b, CGPoint c, size_t depth)
{
  const CGFloat maxY = s.yis.upper.end;
  const CGFloat minY = s.yis.lower.start;
  if (a.y > maxY && b.y > maxY && c.y > maxY) return;
  if (a.y < minY && b.y < minY && c.y < minY) return;

  // d is half the second derivative of the quadratic curve.
  const CGPoint d = c - 2*b + a;
  const CGFloat dd = d.x*d.x + d.y*d.y;

  // The error bound for the linear approximation follows directly from the Lagrange error bound:
  // https://en.wikipedia.org/wiki/Polynomial_interpolation#Interpolation_error

  if (dd <= s.maxErrorSquaredTimes16 || depth == maxRecursionDepth) {
    addLine(s, a, c);
    return;
  }

  const CGPoint ab = (a + b)/2;
  const CGPoint bc = (b + c)/2;

  const CGPoint abc = (ab + bc)/2;

  addQuadraticCurve(s, a, ab, abc, depth + 1);
  addQuadraticCurve(s, abc, bc, c, depth + 1);
}

static void addCubicCurve(PathIntersectionXBoundsState& s,
                          CGPoint a, CGPoint b, CGPoint c, CGPoint d, size_t depth)
{
  const CGFloat maxY = s.yis.upper.end;
  const CGFloat minY = s.yis.lower.start;
  if (a.y > maxY && b.y > maxY && c.y > maxY && d.y > maxY) return;
  if (a.y < minY && b.y < minY && c.y < minY && d.y < minY) return;

  // See e.g. https://jeremykun.com/2013/05/11/bezier-curves-and-picasso/ for a derivation
  // of the error bound for the linear approximation.

  const CGPoint e = 3*b - 2*a - d;
  const CGPoint f = 3*c - a - 2*d;
  const CGFloat eeff = max(e.x*e.x, f.x*f.x)
                     + max(e.y*e.y, f.y*f.y);

  if (eeff <= s.maxErrorSquaredTimes16 || depth == maxRecursionDepth) {
    addLine(s, a, d);
    return;
  }

  const CGPoint ab = (a + b)/2;
  const CGPoint bc = (b + c)/2;
  const CGPoint cd = (c + d)/2;

  const CGPoint abc = (ab + bc)/2;
  const CGPoint bcd = (bc + cd)/2;

  const CGPoint abcd = (abc + bcd)/2;

  addCubicCurve(s, a, ab, abc, abcd, depth + 1);
  addCubicCurve(s, abcd, bcd, cd, d, depth + 1);
}

static void findXBoundsOfIntersectionWithHorizontalLine(void* state, const CGPathElement* e) {
  PathIntersectionXBoundsState& s = *stu::down_cast<PathIntersectionXBoundsState*>(state);
  CGPoint lastPoint;
  switch (e->type) {
  case kCGPathElementMoveToPoint:
    lastPoint = e->points[0];
    s.startPoint = lastPoint;
    break;
  case kCGPathElementCloseSubpath:
    lastPoint = s.startPoint;
    addLine(s, s.previousPoint, lastPoint);
    break;
  case kCGPathElementAddLineToPoint:
    lastPoint = e->points[0];
    addLine(s, s.previousPoint, lastPoint);
    break;
  case kCGPathElementAddQuadCurveToPoint:
    lastPoint = e->points[1];
    addQuadraticCurve(s, s.previousPoint, e->points[0], lastPoint, 0);
    break;
  case kCGPathElementAddCurveToPoint:
    lastPoint = e->points[2];
    addCubicCurve(s, s.previousPoint, e->points[0], e->points[1], lastPoint, 0);
    break;
  }
  s.previousPoint = lastPoint;
}

LowerAndUpperInterval findXBoundsOfPathIntersectionWithHorizontalLines(
                        __nonnull CGPathRef path,
                        Range<CGFloat> lowerLineY, Range<CGFloat> upperLineY,
                        CGFloat maxError)
{
  STU_DEBUG_ASSERT(lowerLineY.start <= upperLineY.start);
  STU_DEBUG_ASSERT(lowerLineY.end <= upperLineY.end);
  STU_DEBUG_ASSERT(lowerLineY.start != upperLineY.start || lowerLineY.end == upperLineY.end);
  STU_DEBUG_ASSERT(maxError > 0);

  PathIntersectionXBoundsState state = {.yis  = {.lower = lowerLineY, .upper = upperLineY},
                                        .xis  = {Range<CGFloat>::infinitelyEmpty(),
                                                 Range<CGFloat>::infinitelyEmpty()},
                                        .maxErrorSquaredTimes16 = maxError*maxError*16};
  CGPathApply(path, &state, findXBoundsOfIntersectionWithHorizontalLine);

  return {.lower = state.xis.lower, .upper = state.xis.upper};
}

} // namespace stu_label
