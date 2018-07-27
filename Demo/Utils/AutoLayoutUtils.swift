// Copyright 2017–2018 Stephan Tolksdorf

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

#if !swift(>=4.2)
  extension NSLayoutConstraint {
    public typealias Attribute = NSLayoutAttribute
    public typealias Relation = NSLayoutRelation
  }
#endif

let leq: NSLayoutConstraint.Relation = .lessThanOrEqual
let geq: NSLayoutConstraint.Relation = .greaterThanOrEqual
let eq: NSLayoutConstraint.Relation = .equal

public protocol ViewOrLayoutOrLayoutSupport : class {}

public protocol ViewOrLayoutGuide : ViewOrLayoutOrLayoutSupport {
  var layoutViewAndBounds: (view: UIView, bounds: CGRect) { get }
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
  public mutating func reserveFreeCapacity(_ n: Int) {
    reserveCapacity(count + n)
  }
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, within item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(4)
  constrain(&constraints, item1, .left,   .greaterThanOrEqual, item2, .left)
  constrain(&constraints, item1, .right,  .lessThanOrEqual,    item2, .right)
  constrain(&constraints, item1, .top,    .greaterThanOrEqual, item2, .top)
  constrain(&constraints, item1, .bottom, .lessThanOrEqual,    item2, .bottom)
}
public func constrain(_ item1: ViewOrLayoutGuide, within item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, within: item2)
  return cs
}


public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(4)
  constrain(&constraints, item1, .left,   .equal, item2, .left)
  constrain(&constraints, item1, .right,  .equal, item2, .right)
  constrain(&constraints, item1, .top,    .equal, item2, .top)
  constrain(&constraints, item1, .bottom, .equal, item2, .bottom)
}
public func constrain(_ item1: ViewOrLayoutGuide, toEdgesOf item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, toEdgesOf: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toMarginsOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(4)
  constrain(&constraints, item1, .left,   .equal, item2, .leftMargin)
  constrain(&constraints, item1, .right,  .equal, item2, .rightMargin)
  constrain(&constraints, item1, .top,    .equal, item2, .topMargin)
  constrain(&constraints, item1, .bottom, .equal, item2, .bottomMargin)
}
public func constrain(_ item1: ViewOrLayoutGuide, toMarginsOf item2: ViewOrLayoutGuide)
            -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, toMarginsOf: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toHorizontalEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(2)
  constrain(&constraints, item1, .left,   .equal, item2, .left)
  constrain(&constraints, item1, .right,  .equal, item2, .right)
}
public func constrain(_ item1: ViewOrLayoutGuide, toHorizontalEdgesOf item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, toHorizontalEdgesOf: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, toVerticalEdgesOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(2)
  constrain(&constraints, item1, .top,   .equal, item2, .top)
  constrain(&constraints, item1, .bottom,  .equal, item2, .bottom)
}
public func constrain(_ item1: ViewOrLayoutGuide, toVerticalEdgesOf item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, toVerticalEdgesOf: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      horizontallyCenteredWithin item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(2)
  constrain(&constraints, item1, .centerX, .equal,           item2, .centerX)
  constrain(&constraints, item1, .width,   .lessThanOrEqual, item2, .width)
}
public func constrain(_ item1: ViewOrLayoutGuide,
                      horizontallyCenteredWithin item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, horizontallyCenteredWithin: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      horizontallyCenteredWithinMarginsOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(3)
  constrain(&constraints, item1, .centerX, .equal,              item2, .centerXWithinMargins)
  constrain(&constraints, item1, .left,    .greaterThanOrEqual, item2, .leftMargin)
  constrain(&constraints, item1, .right,   .lessThanOrEqual,    item2, .rightMargin)
}
public func constrain(_ item1: ViewOrLayoutGuide,
                      horizontallyCenteredWithinMarginsOf item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, horizontallyCenteredWithinMarginsOf: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      verticallyCenteredWithin item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(2)
  constrain(&constraints, item1, .centerY, .equal,           item2, .centerY)
  constrain(&constraints, item1, .height,  .lessThanOrEqual, item2, .height)
}
public func constrain(_ item1: ViewOrLayoutGuide,
                      verticallyCenteredWithin item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, verticallyCenteredWithin: item2)
  return cs
}

public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide,
                      verticallyCenteredWithinMarginsOf item2: ViewOrLayoutGuide)
{
  constraints.reserveFreeCapacity(3)
  constrain(&constraints, item1, .centerY, .equal,              item2, .centerYWithinMargins)
  constrain(&constraints, item1, .top,     .greaterThanOrEqual, item2, .topMargin)
  constrain(&constraints, item1, .bottom,  .lessThanOrEqual,    item2, .bottomMargin)
}
public func constrain(_ item1: ViewOrLayoutGuide,
                      verticallyCenteredWithinMarginsOf item2: ViewOrLayoutGuide)
              -> [NSLayoutConstraint]
{
  var cs = [NSLayoutConstraint]()
  constrain(&cs, item1, verticallyCenteredWithinMarginsOf: item2)
  return cs
}

@inline(__always)
func constrain(_ constraints: inout [NSLayoutConstraint],
               topToBottom items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
               within container:ViewOrLayoutGuide? = nil,
               loose: Bool = true)
{
  guard !items.isEmpty else { return }
  constraints.reserveFreeCapacity(items.count + (container != nil ? 1 : -1))
  if let c = container {
    constrain(&constraints, items.first!, .top, .equal, c, .top)
  }
  for i in 1..<items.count {
    constrain(&constraints, items[i], .top, .equal, items[i - 1], .bottom, constant: spacing)
  }
  if let c = container {
    constrain(&constraints, c, .bottom, .greaterThanOrEqual, items.last!, .bottom)
  }
}

@inline(__always)
func constrain(_ constraints: inout [NSLayoutConstraint],
               topToBottom items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
               withinMarginsOf view: UIView,
               loose: Bool = true)
{
  guard !items.isEmpty else { return }
  constraints.reserveFreeCapacity(items.count + 1)
  constrain(&constraints, items.first!, .top, .equal, view, .topMargin)
  for i in 1..<items.count {
    constrain(&constraints, items[i], .top, .equal, items[i - 1], .bottom, constant: spacing)
  }
  constrain(&constraints, view, .bottomMargin, .greaterThanOrEqual, items.last!, .bottom)
}

@inline(__always)
func constrain(_ constraints: inout [NSLayoutConstraint],
               leadingToTrailing items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
               within container:ViewOrLayoutGuide? = nil)
{
  guard !items.isEmpty else { return }
  constraints.reserveFreeCapacity(items.count + (container != nil ? 1 : -1))
  if let c = container {
    constrain(&constraints, items.first!, .leading, .equal, c, .leading)
  }
  for i in 1..<items.count {
    constrain(&constraints, items[i], .leading, .equal, items[i - 1], .trailing,
              constant: spacing)
  }
  if let c = container {
    constrain(&constraints, c, .trailing, .greaterThanOrEqual, items.last!, .trailing)
  }
}


@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      leadingToTrailing items: [ViewOrLayoutGuide], spacing: CGFloat = 0,
                      withinMarginsOf view: UIView)
{
  guard !items.isEmpty else { return }
  constraints.reserveFreeCapacity(items.count + 1)
  constrain(&constraints, items.first!, .leading, .equal, view, .leadingMargin)
  for i in 1..<items.count {
    constrain(&constraints, items[i], .leading, .equal, items[i - 1], .trailing,
              constant: spacing)
  }
  constrain(&constraints, view, .trailingMargin, .greaterThanOrEqual, items.last!, .trailing)
}

extension NSLayoutConstraint {
  @inline(__always) @_versioned
  internal convenience init(_ item1: AnyObject, _ attr1: NSLayoutConstraint.Attribute,
                            _ relation: NSLayoutConstraint.Relation,
                            _ item2: AnyObject?, _ attr2: NSLayoutConstraint.Attribute,
                            multiplier: CGFloat = 1,
                            constant: CGFloat = 0,
                            priority: UILayoutPriority = UILayoutPriority.required)
  {
    self.init(item: item1, attribute: attr1, relatedBy: relation, toItem: item2, attribute: attr2,
              multiplier: multiplier, constant: constant)
    if priority != UILayoutPriority.required {
      self.priority = priority
    }
  }
}

// These definitions allow for a more compact (and safer) specification of layout constraints:

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutCenterXAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutXAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutLeftRightAttribute,
                      _ relation: NSLayoutConstraint.Relation, _ item2: ViewOrLayoutGuide,
                      _ otherAttribute: LayoutLeftRightCenterXAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutLeadingTrailingAttribute,
                      _ relation: NSLayoutConstraint.Relation, _ item2: ViewOrLayoutGuide,
                      _ otherAttribute: LayoutLeadingTrailingCenterXAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UIView, _ attribute: LayoutYAxisViewAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ otherAttribute: LayoutYAxisViewAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UIView, _ attribute: LayoutYAxisViewAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ otherAttribute: LayoutYAxisViewAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UILayoutSupport, _ otherAttribute: LayoutTopBottomAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UILayoutSupport, _ attribute: LayoutTopBottomAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: ViewOrLayoutGuide, _ attribute: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutDimensionAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item: ViewOrLayoutGuide, _ attribute: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item, attribute.value, relation, nil, .notAnAttribute,
                            multiplier: 1, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item1: UILayoutSupport, _ attribute: LayoutHeightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutDimensionAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item1, attribute.value, relation, item2, otherAttribute.value,
                            multiplier: multiplier, constant: constant, priority: priority)
}

@inline(__always)
public func constrain(_ item: UILayoutSupport, _ attribute: LayoutHeightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat,
                      priority: UILayoutPriority = .required)
                -> NSLayoutConstraint
{
  return NSLayoutConstraint(item, attribute.value, relation, nil, .notAnAttribute,
                            multiplier: 1, constant: constant, priority: priority)
}



@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutCenterXAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutXAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}
@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutLeftRightAttribute,
                      _ relation: NSLayoutConstraint.Relation, _ item2: ViewOrLayoutGuide,
                      _ otherAttribute: LayoutLeftRightCenterXAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutLeadingTrailingAttribute,
                      _ relation: NSLayoutConstraint.Relation, _ item2: ViewOrLayoutGuide,
                      _ otherAttribute: LayoutLeadingTrailingCenterXAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UIView, _ attribute: LayoutYAxisViewAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
   constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ otherAttribute: LayoutYAxisViewAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UIView, _ attribute: LayoutYAxisViewAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UIView, _ otherAttribute: LayoutYAxisViewAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutYAxisAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: UILayoutSupport, _ otherAttribute: LayoutTopBottomAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: UILayoutSupport, _ attribute: LayoutTopBottomAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutYAxisAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item1: ViewOrLayoutGuide, _ attribute: LayoutDimensionAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutDimensionAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority =  .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
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
                      _ item1: UILayoutSupport, _ attribute: LayoutHeightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ item2: ViewOrLayoutGuide, _ otherAttribute: LayoutDimensionAttribute,
                      multiplier: CGFloat = 1, constant: CGFloat = 0,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item1, attribute, relation, item2, otherAttribute,
                               multiplier: multiplier, constant: constant, priority: priority))
}

@inline(__always)
public func constrain(_ constraints: inout [NSLayoutConstraint],
                      _ item: UILayoutSupport, _ attribute: LayoutHeightAttribute,
                      _ relation: NSLayoutConstraint.Relation,
                      _ constant: CGFloat,
                      priority: UILayoutPriority = .required)
{
  constraints.append(constrain(item, attribute, relation, constant, priority: priority))
}


public protocol LayoutAttribute {
  var value: NSLayoutConstraint.Attribute { get }
}

public struct LayoutXAxisAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var left: LayoutXAxisAttribute { return .init(.left) }
  public static var right: LayoutXAxisAttribute { return .init(.right) }
  public static var leading: LayoutXAxisAttribute { return .init(.leading) }
  public static var trailing: LayoutXAxisAttribute { return .init(.trailing) }
  public static var centerX: LayoutXAxisAttribute { return .init(.centerX) }

  public static var leftMargin: LayoutXAxisAttribute { return .init(.leftMargin) }
  public static var rightMargin: LayoutXAxisAttribute { return .init(.rightMargin) }
  public static var leadingMargin: LayoutXAxisAttribute { return .init(.leadingMargin) }
  public static var trailingMargin: LayoutXAxisAttribute { return .init(.trailingMargin) }
  public static var centerXWithinMargins: LayoutXAxisAttribute {
    return .init(.centerXWithinMargins)
  }
}

public struct LayoutCenterXAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var centerX: LayoutCenterXAttribute { return .init(.centerX) }

  public static var centerXWithinMargins: LayoutCenterXAttribute {
    return .init(.centerXWithinMargins)
  }
}


public struct LayoutLeftRightAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var left: LayoutLeftRightAttribute { return .init(.left) }
  public static var right: LayoutLeftRightAttribute { return .init(.right) }
  public static var leftMargin: LayoutLeftRightAttribute { return .init(.leftMargin) }
  public static var rightMargin: LayoutLeftRightAttribute { return .init(.rightMargin) }
}

public struct LayoutLeftRightCenterXAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var left: LayoutLeftRightCenterXAttribute { return .init(.left) }
  public static var right: LayoutLeftRightCenterXAttribute { return .init(.right) }
  public static var leftMargin: LayoutLeftRightCenterXAttribute { return .init(.leftMargin) }
  public static var rightMargin: LayoutLeftRightCenterXAttribute { return .init(.rightMargin) }
  public static var centerX: LayoutLeftRightCenterXAttribute { return .init(.centerX) }
  public static var centerXWithinMargins: LayoutLeftRightCenterXAttribute { return .init(.centerXWithinMargins) }
}


public struct LayoutLeadingTrailingAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var leading: LayoutLeadingTrailingAttribute { return .init(.leading) }
  public static var trailing: LayoutLeadingTrailingAttribute { return .init(.trailing) }

  public static var leadingMargin: LayoutLeadingTrailingAttribute { return .init(.leadingMargin) }
  public static var trailingMargin: LayoutLeadingTrailingAttribute { return .init(.trailingMargin) }

  public struct ViewAttribute : LayoutAttribute  {
    public var value: NSLayoutConstraint.Attribute { return .notAnAttribute }
  }
}

public struct LayoutLeadingTrailingCenterXAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var leading: LayoutLeadingTrailingCenterXAttribute { return .init(.leading) }
  public static var trailing: LayoutLeadingTrailingCenterXAttribute { return .init(.trailing) }
  public static var centerX: LayoutLeadingTrailingCenterXAttribute { return .init(.centerX) }

  public static var leadingMargin: LayoutLeadingTrailingCenterXAttribute { return .init(.leadingMargin) }
  public static var trailingMargin: LayoutLeadingTrailingCenterXAttribute { return .init(.trailingMargin) }
  public static var centerXWithinMargins: LayoutLeadingTrailingCenterXAttribute { return .init(.centerXWithinMargins) }
}

public struct LayoutTopBottomAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var top: LayoutTopBottomAttribute { return .init(.top) }
  public static var bottom: LayoutTopBottomAttribute { return .init(.bottom) }
}

public struct LayoutHeightAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var height: LayoutHeightAttribute { return .init(.height) }
}


public struct LayoutYAxisAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var top: LayoutYAxisAttribute { return .init(.top) }
  public static var bottom: LayoutYAxisAttribute { return .init(.bottom) }
  public static var centerY: LayoutYAxisAttribute { return .init(.centerY) }

  public static var topMargin: LayoutYAxisAttribute { return .init(.topMargin) }
  public static var bottomMargin: LayoutYAxisAttribute { return .init(.bottomMargin) }
  public static var centerYWithinMargins: LayoutYAxisAttribute {
    return .init(.centerYWithinMargins)
  }

  public typealias ViewAttribute = LayoutYAxisViewAttribute
}

public struct LayoutYAxisViewAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var firstBaseline: LayoutYAxisViewAttribute { return .init(.firstBaseline) }
  public static var lastBaseline: LayoutYAxisViewAttribute { return .init(.lastBaseline) }
}

public struct LayoutDimensionAttribute : LayoutAttribute {
  public var value: NSLayoutConstraint.Attribute
  private init(_ value: NSLayoutConstraint.Attribute) { self.value = value }

  public static var width: LayoutDimensionAttribute { return .init(.width) }
  public static var height: LayoutDimensionAttribute { return .init(.height) }
}
