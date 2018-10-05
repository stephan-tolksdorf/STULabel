// Copyright 2018 Stephan Tolksdorf

import CoreGraphics

func +(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
  return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
func -(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
  return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func += (_ lhs: inout CGPoint, _ rhs: CGPoint) {
  lhs = lhs + rhs
}
func -=(_ lhs: inout CGPoint, _ rhs: CGPoint) {
  lhs = lhs - rhs
}

func *(_ s: CGFloat, _ p: CGPoint) -> CGPoint {
  return CGPoint(x: s*p.x, y: s*p.y)
}
func *( p: CGPoint, _ s: CGFloat) -> CGPoint {
  return s*p
}
func /(_ p: CGPoint, _ s: CGFloat) -> CGPoint {
  return CGPoint(x: p.x/s, y: p.y/s)
}

func *(_ f: CGFloat, _ s: CGSize) -> CGSize {
  return CGSize(width: f*s.width, height: f*s.height)
}
func *(_ s: CGSize, _ f: CGFloat) -> CGSize {
  return f*s
}
func /(_ s: CGSize, _ f: CGFloat) -> CGSize {
  return CGSize(width: s.width/f, height: s.height/f)
}


extension CGRect {
  var center: CGPoint {
    return CGPoint(x: self.origin.x + self.size.width/2,
                   y: self.origin.y + self.size.height/2)
  }
}
