// Copyright 2017 Stephan Tolksdorf

#import "CoreGraphicsUtils.hpp"

#import "Rect.hpp"

namespace stu_label {

void addReversedRectPath(CGPath& path, const CGAffineTransform* __nullable transform, CGRect cgRect) {
  const Rect rect = cgRect;
  CGPathMoveToPoint(&path,    transform, rect.x.start, rect.y.start);
  CGPathAddLineToPoint(&path, transform, rect.x.start, rect.y.end);
  CGPathAddLineToPoint(&path, transform, rect.x.end,   rect.y.end);
  CGPathAddLineToPoint(&path, transform, rect.x.end,   rect.y.start);
  CGPathCloseSubpath(&path);
}

} // namespace stu_label

