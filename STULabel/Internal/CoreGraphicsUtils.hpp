// Copyright 2017–2018 Stephan Tolksdorf

#import "Equal.hpp"

namespace stu_label {

STU_INLINE
CGFloat cgFloatFromNumber(__unsafe_unretained id value) {
#if CGFLOAT_IS_DOUBLE
  return [down_cast<NSNumber*>(value) doubleValue];
#else
  return [down_cast<NSNumber*>(value) floatValue];
#endif
}

template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
Point operator+(Point lhs, Point rhs) {
  return {lhs.x + rhs.x, lhs.y + rhs.y};
}

template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
Point operator-(Point lhs, Point rhs) {
  return {lhs.x - rhs.x, lhs.y - rhs.y};
}

template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
Point operator-(Point p) {
  return {-p.x, -p.y};
}

template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
CGPoint& operator*=(Point& point, CGFloat scale) {
  point.x *= scale;
  point.y *= scale;
  return point;
}
template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
CGPoint operator*(CGFloat scale, Point point) {
  point *= scale;
  return point;
}
template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
CGPoint operator*(Point point, CGFloat scale) {
  point *= scale;
  return point;
}

template <typename Point, EnableIf<isSame<Point, CGPoint>> = 0>
STU_CONSTEXPR
CGPoint operator/(Point point, CGFloat scale) {
  return {point.x/scale, point.y/scale};
}

template <typename Size, EnableIf<isSame<Size, CGSize>> = 0>
STU_CONSTEXPR
CGSize& operator*=(Size& size, CGFloat scale) {
  size.width  *= scale;
  size.height *= scale;
  return size;
}
template <typename Size, EnableIf<isSame<Size, CGSize>> = 0>
STU_CONSTEXPR
CGSize operator*(CGFloat scale, Size size) {
  size *= scale;
  return size;
}
template <typename Size, EnableIf<isSame<Size, CGSize>> = 0>
STU_CONSTEXPR
CGSize operator*(Size size, CGFloat scale) {
  size *= scale;
  return size;
}

template <typename Rect, EnableIf<isSame<Rect, CGRect>> = 0>
STU_CONSTEXPR
CGRect operator+(CGPoint point, Rect rect) {
  return {.origin = rect.origin + point, .size = rect.size};
}

template <typename Rect, EnableIf<isSame<Rect, CGRect>> = 0>
STU_CONSTEXPR
CGRect operator+(Rect rect, CGPoint point) {
  return point + rect;
}

template <typename Rect, EnableIf<isSame<Rect, CGRect>> = 0>
STU_CONSTEXPR
CGRect& operator*=(Rect& rect, CGFloat scale) {
  rect.origin *= scale;
  rect.size *= scale;
  return rect;
}
template <typename Rect, EnableIf<isSame<Rect, CGRect>> = 0>
STU_CONSTEXPR
CGRect operator*(CGFloat scale, Rect rect) {
  rect *= scale;
  return rect;
}
template <typename Rect, EnableIf<isSame<Rect, CGRect>> = 0>
STU_CONSTEXPR
CGRect operator*(Rect rect, CGFloat scale) {
  rect *= scale;
  return rect;
}

STU_CONSTEXPR CGPoint center(CGRect r) {
  return {r.origin.x + r.size.width/2,
          r.origin.y + r.size.height/2};
}

STU_CONSTEXPR CGFloat area(CGRect r) {
  return r.size.width*r.size.height;
}

STU_CONSTEXPR
UIEdgeInsets operator-(UIEdgeInsets insets) {
  return UIEdgeInsets{.top    = -insets.top,
                      .left   = -insets.left,
                      .bottom = -insets.bottom,
                      .right  = -insets.right};
}

void addReversedRectPath(CGPath& path, const CGAffineTransform* __nullable transform, CGRect rect);


// The geometric mean of the aggregate absolute x and y scales that one could obtain by decomposing
// the transform into any sequence of translation, scale, rotation and shear operations.
inline CGFloat scale(const CGAffineTransform& m) {
  return sqrt(abs(m.a*m.d - m.b*m.c)); // sqrt(abs(det([a b; c d])))
}

} // namespace stu_label
