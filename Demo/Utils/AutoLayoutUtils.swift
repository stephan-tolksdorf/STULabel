// Copyright 2017–2018 Stephan Tolksdorf

import STULabelSwift

func roundToDisplayScale(_ value: CGFloat) -> CGFloat {
  let displayScale = stu_mainScreenScale()
  return round(displayScale*value)/displayScale
}

public protocol ViewOrLayoutGuide : NSObjectProtocol {
  var layoutViewAndBounds: (view: UIView, bounds: CGRect) { get }
  var leadingAnchor: NSLayoutXAxisAnchor { get }
  var trailingAnchor: NSLayoutXAxisAnchor { get }
  var leftAnchor: NSLayoutXAxisAnchor { get }
  var rightAnchor: NSLayoutXAxisAnchor { get }
  var topAnchor: NSLayoutYAxisAnchor { get }
  var bottomAnchor: NSLayoutYAxisAnchor { get }
  var widthAnchor: NSLayoutDimension { get }
  var heightAnchor: NSLayoutDimension { get }
  var centerXAnchor: NSLayoutXAxisAnchor { get }
  var centerYAnchor: NSLayoutYAxisAnchor { get }
}

extension UIView : ViewOrLayoutGuide {
  public var layoutViewAndBounds: (view: UIView, bounds: CGRect) {
    return (self, self.bounds)
  }
}

extension UILayoutGuide : ViewOrLayoutGuide {
  public var layoutViewAndBounds: (view: UIView, bounds: CGRect) {
    return (owningView!, layoutFrame)
  }
}

extension UILayoutPriority {
  public static func +(lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
    let raw = lhs.rawValue + rhs
    return UILayoutPriority(rawValue:raw)
  }
  public static func -(lhs: UILayoutPriority, rhs: Float) -> UILayoutPriority {
    let raw = lhs.rawValue - rhs
    return UILayoutPriority(rawValue:raw)
  }
}

let leq: NSLayoutConstraint.Relation = .lessThanOrEqual
let geq: NSLayoutConstraint.Relation = .greaterThanOrEqual
let eq: NSLayoutConstraint.Relation = .equal

extension Array where Element == NSLayoutConstraint {
  @inline(__always)
  func activate() { NSLayoutConstraint.activate(self) }
  @inline(__always)
  func deactivate() { NSLayoutConstraint.deactivate(self) }
}

extension Sequence where Element == [NSLayoutConstraint] {
  @inline(__always)
  func activate() { NSLayoutConstraint.activate([NSLayoutConstraint](self.joined()))  }
  @inline(__always)
  func deactivate() { NSLayoutConstraint.deactivate([NSLayoutConstraint](self.joined())) }
}

extension Array {
  public mutating func ensureFreeCapacity(_ n: Int) {
    let neededCapacity = self.count + n
    let capacity = self.capacity
    if neededCapacity > capacity {
      reserveCapacity(Swift.max(2*capacity, neededCapacity))
    }
  }
}

// MARK: - Compound constraints

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, horizontallyWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .leading,  .greaterThanOrEqual, item2, .leading)
  constrain(&constraints, item2, .trailing, .greaterThanOrEqual, item1, .trailing)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, leadingWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .leading,  .equal,              item2, .leading)
  constrain(&constraints, item2, .trailing, .greaterThanOrEqual, item1, .trailing)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, trailingWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .leading,  .greaterThanOrEqual, item2, .leading)
  constrain(&constraints, item2, .trailing, .equal,              item1, .trailing)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, verticallyWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .top,    .greaterThanOrEqual, item2, .top)
  constrain(&constraints, item2, .bottom, .greaterThanOrEqual, item1, .bottom)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, topWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .top,    .equal,              item2, .top)
  constrain(&constraints, item2, .bottom, .greaterThanOrEqual, item1, .bottom)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, bottomWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .top,    .greaterThanOrEqual, item2, .top)
  constrain(&constraints, item2, .bottom, .equal,              item1, .bottom)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      horizontallyCenteredWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .centerX, .equal,              item2, .centerX)
  constrain(&constraints, item2, .width,   .greaterThanOrEqual, item1, .width)
}


public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      verticallyCenteredWithin item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .centerY, .equal,              item2, .centerY)
  constrain(&constraints, item2, .height,  .greaterThanOrEqual, item1, .height)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, within item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(4)
  constrain(&constraints, item1, horizontallyWithin: item2)
  constrain(&constraints, item1, verticallyWithin: item2)
}
public func constrain(_ item1: ViewOrLayoutGuide, within item2: ViewOrLayoutGuide)
  -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, within: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toHorizontalEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .leading,  .equal, item2, .leading)
  constrain(&constraints, item2, .trailing, .equal, item1, .trailing)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toVerticalEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(2)
  constrain(&constraints, item1, .top,    .equal, item2, .top)
  constrain(&constraints, item2, .bottom, .equal, item1, .bottom)
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.ensureFreeCapacity(4)
  constrain(&constraints, item1, toHorizontalEdgesOf: item2)
  constrain(&constraints, item1, toVerticalEdgesOf: item2)
}
public func constrain(_ item1: ViewOrLayoutGuide, toEdgesOf item2: ViewOrLayoutGuide)
  -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, toEdgesOf: item2)
  return cs
}


enum HorizontalAlignmentWithinContainer {
  case leading
  case trailing
  case center
  case any
}

@inline(__always)
func constrain(_ constraints: inout [NSLayoutConstraint],
               topToBottom items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
               loose: Bool = false,
               within container:ViewOrLayoutGuide? = nil,
               horizontalAlignment: HorizontalAlignmentWithinContainer? = nil)
{
  guard !items.isEmpty else { return }
  constraints.ensureFreeCapacity(items.count
                                 + (container == nil ? -1
                                    : 1 + (horizontalAlignment != nil ? items.count : 0)))
  let rel: NSLayoutConstraint.Relation = loose ? .greaterThanOrEqual : .equal
  if let c = container {
    if let alignment = horizontalAlignment {
      for item in items {
        switch alignment {
        case .leading:
          constrain(&constraints, item, leadingWithin: c)
        case .trailing:
          constrain(&constraints, item, trailingWithin: c)
        case .center:
          constrain(&constraints, item, horizontallyCenteredWithin: c)
        case .any:
          constrain(&constraints, item, horizontallyWithin: c)
        }
      }
    }
    constrain(&constraints, items.first!, .top, rel, c, .top)
  }
  for i in 1..<items.count {
    constrain(&constraints, items[i], .top, rel, items[i - 1], .bottom, plus: spacing)
  }
  if let c = container {
    constrain(&constraints, c, .bottom, .greaterThanOrEqual, items.last!, .bottom)
  }
}


enum VerticalAlignmentWithinContainer {
  case top
  case bottom
  case center
  case any
}


@inline(__always)
func constrain(_ constraints: inout [NSLayoutConstraint],
               leadingToTrailing items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
               loose: Bool = false,
               within container: ViewOrLayoutGuide? = nil,
               verticalAlignment: VerticalAlignmentWithinContainer? = nil)
{
  guard !items.isEmpty else { return }
  constraints.ensureFreeCapacity(items.count
                                  + (container == nil ? -1
                                     : 1 + (verticalAlignment != nil ? items.count : 0)))
  let rel: NSLayoutConstraint.Relation = loose ? .greaterThanOrEqual : .equal
  if let c = container {
    if let alignment = verticalAlignment {
      for item in items {
        switch alignment {
        case .top:
          constrain(&constraints, item, topWithin: c)
        case .bottom:
          constrain(&constraints, item, bottomWithin: c)
        case .center:
          constrain(&constraints, item, verticallyCenteredWithin: c)
        case .any:
          constrain(&constraints, item, verticallyWithin: c)
        }
      }
    }
    constrain(&constraints, items.first!, .leading, rel,  c, .leading)
  }
  for i in 1..<items.count {
    constrain(&constraints, items[i], .leading, rel, items[i - 1], .trailing, plus: spacing)
  }
  if let c = container {
    constrain(&constraints, c, .trailing, .greaterThanOrEqual, items.last!, .trailing)
  }
}

// MARK: - LayoutAnchor constraint helpers

@inline(__always)
public func constrain<T>(_ anchor1: NSLayoutAnchor<T>,
                         _ relation: NSLayoutConstraint.Relation,
                         _ anchor2: NSLayoutAnchor<T>,
                         plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  let c: NSLayoutConstraint
  switch relation {
  case .equal: c = anchor1.constraint(equalTo: anchor2, constant: offset)
  case .lessThanOrEqual: c = anchor1.constraint(lessThanOrEqualTo: anchor2, constant: offset)
  case .greaterThanOrEqual: c = anchor1.constraint(greaterThanOrEqualTo: anchor2, constant: offset)
  @unknown case _: fatalError()
  }
  if priority != .required {
    c.priority = priority
  }
  return c
}

@inline(__always)
public func constrain(_ anchor: NSLayoutDimension,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  let c: NSLayoutConstraint
  switch relation {
  case .equal: c = anchor.constraint(equalToConstant: constant)
  case .lessThanOrEqual: c = anchor.constraint(lessThanOrEqualToConstant: constant)
  case .greaterThanOrEqual: c = anchor.constraint(greaterThanOrEqualToConstant: constant)
  @unknown case _: fatalError()
  }
  if priority != .required {
    c.priority = priority
  }
  return c
}

@inline(__always)
public func constrain(_ anchor1: NSLayoutDimension,
                      _ relation: NSLayoutConstraint.Relation,
                      _ anchor2: NSLayoutDimension,
                      multipliedBy multiplier: CGFloat, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  let c: NSLayoutConstraint
  switch relation {
  case .equal:
    c = anchor1.constraint(equalTo: anchor2, multiplier: multiplier, constant: offset)
  case .lessThanOrEqual:
    c = anchor1.constraint(lessThanOrEqualTo: anchor2, multiplier: multiplier, constant: offset)
  case .greaterThanOrEqual:
    c = anchor1.constraint(greaterThanOrEqualTo: anchor2, multiplier: multiplier, constant: offset)
  @unknown case _:
    fatalError()
  }
  if priority != .required {
    c.priority = priority
  }
  return c
}

@inline(__always)
public func constrain(_ anchor: NSLayoutYAxisAnchor,
                      _ relation: NSLayoutConstraint.Relation,
                      _ label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      plusLineHeightMultipliedBy lineHeightMultiple: CGFloat,
                      plus offset: CGFloat, priority: UILayoutPriority = .required)
   -> NSLayoutConstraint
{
  let c = anchor.stu_constraint(relation, to: baseline, of: label,
                                 plusLineHeightMultipliedBy: lineHeightMultiple, plus: offset)
  if priority != .required {
    c.priority = priority
  }
  return c
}

@inline(__always)
public func constrain(_ anchor: NSLayoutYAxisAnchor,
                      _ relation: NSLayoutConstraint.Relation,
                      positionAbove label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy multiplier: CGFloat = 1,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
   -> NSLayoutConstraint
{
  let c = anchor.stu_constraint(relation, toPositionAbove: baseline, of: label,
                                spacingMultiplier: multiplier, offset: offset)
  if priority != .required {
    c.priority = priority
  }
  return c
}

@inline(__always)
public func constrain(_ anchor: NSLayoutYAxisAnchor,
                      _ relation: NSLayoutConstraint.Relation,
                      positionBelow label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy multiplier: CGFloat = 1,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
   -> NSLayoutConstraint
{
  let c = anchor.stu_constraint(relation, toPositionBelow: baseline, of: label,
                                spacingMultiplier: multiplier, offset: offset)
  if priority != .required {
    c.priority = priority
  }
  return c
}

// MARK: - Simple constraints

// We need so many different overloads here because we want to enforce all preconditions at the
// type level (including e.g. that a leading/trailing attribute must only be constrained to
// a second leading/trailing attribute) and do that in a way that doesn't hinder's Xcode's auto
// completion.

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutLeftRightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutLeftRightCenterXAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutCenterXAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutXAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute2.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutLeadingTrailingAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutLeadingTrailingCenterXAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UILayoutSupport, _ attribute2: LayoutTopBottomAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UILayoutSupport, _ attribute1: LayoutTopBottomAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutDimensionAttribute,
                      multipliedBy multiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   multipliedBy: multiplier, plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item: ViewOrLayoutGuide, _ attribute: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute.anchor(item), relation, constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
        -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ attribute2: LayoutBaselineAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
        -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ attribute2: LayoutBaselineAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, attribute2.anchor(item2),
                   plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: STULabel, _ attribute2: STUFirstOrLastBaseline,
                      plusLineHeightMultipliedBy lineHeightMultiple: CGFloat,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, item2, attribute2,
                   plusLineHeightMultipliedBy: lineHeightMultiple, plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: STULabel, _ attribute2: STUFirstOrLastBaseline,
                      plusLineHeightMultipliedBy lineHeightMultiple: CGFloat,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute1.anchor(item1), relation, item2, attribute2,
                   plusLineHeightMultipliedBy: lineHeightMultiple, plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item: UIView, _ attribute: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      positionAbove label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy spacingMultiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute.anchor(item), relation, positionAbove: label, baseline,
                   spacingMultipliedBy: spacingMultiplier, plus: offset, priority: priority)
}

@inline(__always)
public func constrain(_ item: UIView, _ attribute: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      positionBelow label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy spacingMultiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
  -> NSLayoutConstraint
{
  return constrain(attribute.anchor(item), relation, positionBelow: label, baseline,
                   spacingMultipliedBy: spacingMultiplier, plus: offset, priority: priority)
}

// MARK: - Simple constraints (inout [NSLayoutConstraint])

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutLeftRightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutLeftRightCenterXAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutCenterXAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutXAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutLeadingTrailingAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutLeadingTrailingCenterXAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UILayoutSupport, _ attribute2: LayoutTopBottomAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UILayoutSupport, _ attribute1: LayoutTopBottomAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutDimensionAttribute,
                      multipliedBy multiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               multipliedBy: multiplier, plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item: ViewOrLayoutGuide, _ attribute: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item, attribute, relation, constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ attribute2: LayoutYAxisAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ attribute2: LayoutBaselineAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ attribute2: LayoutBaselineAttribute,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plus: offset, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute1: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: STULabel, _ attribute2: STUFirstOrLastBaseline,
                      plusLineHeightMultipliedBy lineHeightMultiple: CGFloat,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plusLineHeightMultipliedBy: lineHeightMultiple, plus: offset,
                               priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UIView, _ attribute1: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: STULabel, _ attribute2: STUFirstOrLastBaseline,
                      plusLineHeightMultipliedBy lineHeightMultiple: CGFloat,
                      plus offset: CGFloat = 0, priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute1, relation, item2, attribute2,
                               plusLineHeightMultipliedBy: lineHeightMultiple, plus: offset,
                               priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item: UIView, _ attribute: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      positionAbove label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy spacingMultiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  return constraints.append(constrain(item, attribute, relation,
                                      positionAbove: label, baseline,
                                      spacingMultipliedBy: spacingMultiplier, plus: offset,
                                      priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item: UIView, _ attribute: LayoutBaselineAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      positionBelow label: STULabel, _ baseline: STUFirstOrLastBaseline,
                      spacingMultipliedBy spacingMultiplier: CGFloat = 1, plus offset: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  return constraints.append(constrain(item, attribute, relation,
                                      positionBelow: label, baseline,
                                      spacingMultipliedBy: spacingMultiplier, plus: offset,
                                      priority: priority))
}


// MARK: - Layout attribute enums

public enum LayoutXAxisAttribute  {
  case left
  case right
  case leading
  case trailing
  case centerX

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .left: return item.leftAnchor
    case .right: return item.rightAnchor
    case .leading: return item.leadingAnchor
    case .trailing: return item.trailingAnchor
    case .centerX: return item.centerXAnchor
    }
  }
}

public enum LayoutCenterXAttribute  {
  case centerX

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .centerX: return item.centerXAnchor
    }
  }
}

public enum LayoutLeftRightAttribute {
  case left
  case right

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .left: return item.leftAnchor
    case .right: return item.rightAnchor
    }
  }
}

public enum LayoutLeftRightCenterXAttribute {
  case left
  case right
  case centerX

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .left: return item.leftAnchor
    case .right: return item.rightAnchor
    case .centerX: return item.centerXAnchor
    }
  }
}

public enum LayoutLeadingTrailingAttribute  {
  case leading
  case trailing

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .leading: return item.leadingAnchor
    case .trailing: return item.trailingAnchor
    }
  }
}

public enum LayoutLeadingTrailingCenterXAttribute  {
  case leading
  case trailing
  case centerX

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutXAxisAnchor {
    switch self {
    case .leading: return item.leadingAnchor
    case .trailing: return item.trailingAnchor
    case .centerX: return item.centerXAnchor
    }
  }
}

public enum LayoutYAxisAttribute  {
  case top
  case bottom
  case centerY

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutYAxisAnchor {
    switch self {
    case .top: return item.topAnchor
    case .bottom: return item.bottomAnchor
    case .centerY: return item.centerYAnchor
    }
  }
}

public enum LayoutTopBottomAttribute  {
  case top
  case bottom

  @inline(__always)
  public func anchor(_ item: UILayoutSupport) -> NSLayoutYAxisAnchor {
    switch self {
    case .top: return item.topAnchor
    case .bottom: return item.bottomAnchor
    }
  }
}

public enum LayoutBaselineAttribute  {
  case firstBaseline
  case lastBaseline

  @inline(__always)
  public func anchor(_ item: UIView) -> NSLayoutYAxisAnchor {
    switch self {
    case .firstBaseline: return item.firstBaselineAnchor
    case .lastBaseline: return item.lastBaselineAnchor
    }
  }
}

public enum LayoutDimensionAttribute  {
  case width
  case height

  @inline(__always)
  public func anchor(_ item: ViewOrLayoutGuide) -> NSLayoutDimension {
    switch self {
    case .width: return item.widthAnchor
    case .height: return item.heightAnchor
    }
  }
}
