// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import XCTest

// Note: We're using ../Demo/Utils/AutoLayoutUtils.swift here.

let suffix = "@\(Int(stu_mainScreenScale()))"

class AutoLayoutTests: SnapshotTestCase {
  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  func newView(_ name: String) -> UIView {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.accessibilityIdentifier = name
    return view
  }

  func newContainer(_ suffix: String = "") -> UIView {
    let container = newView("container" + suffix)
    [constrain(container, .width, eq, 0, priority: .fittingSizeLevel),
     constrain(container, .height, eq, 0, priority: .fittingSizeLevel)].activate()
    return container
  }

  func newLabel(_ suffix: String = "") -> STULabel {
    let label = STULabel()
    label.textLayoutMode = .textKit
    label.maximumNumberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    label.accessibilityIdentifier = "label" + suffix
    return label
  }

  func font(size: CGFloat) -> UIFont {
    return UIFont(name: "HelveticaNeue", size: size)!
  }

  func testContentLayoutGuide() {
    let label = newLabel()
    label.font = font(size: 20)
    label.text = "Lj"
    label.contentInsets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

    let overlay = newView("contentOverlay")
    label.addSubview(overlay)

    overlay.backgroundColor = UIColor.orange.withAlphaComponent(0.25)
    constrain(overlay, toEdgesOf: label.contentLayoutGuide).activate()

    checkSnapshot(of: label, suffix: "_1" + suffix)

    label.contentInsets = UIEdgeInsets(top: 4, left: 3, bottom: 2, right: 1)
    checkSnapshot(of: label, suffix: "_2" + suffix)
  }

  func testBaselineAnchors() {
    let container = newContainer()
    let labelA = newLabel("A")
    let labelB = newLabel("B")
    container.addSubview(labelA)
    container.addSubview(labelB)

    labelA.attributedText = NSAttributedString([("Lj 1A\n", [.font: font(size: 36)]),
                                                ("Lj 2A", [.font: font(size: 20)])])

    labelB.attributedText = NSAttributedString([("Lj 1B\n", [.font: font(size: 11.6)]),
                                                ("Lj 2B", [.font: font(size: 23)])])

    var cs = [NSLayoutConstraint]()
    constrain(&cs, labelA, within: container)
    constrain(&cs, labelB, within: container)
    constrain(&cs, labelA, .right, eq, labelB, .left, plus: -20)
    constrain(&cs, labelA, .top, eq, container, .top, priority: .fittingSizeLevel)

    cs.activate();

    {
      let c = constrain(labelA, .lastBaseline, eq, labelB, .firstBaseline)
      c.isActive = true
      checkSnapshot(of: container, suffix: "_last_first" + suffix)
      c.isActive = false
    }()

    if #available(iOS 10, tvOS 10, *) {
      let c = NSLayoutConstraint(item: labelA, attribute: .lastBaseline, relatedBy: .equal,
                                 toItem: labelB, attribute: .firstBaseline,
                                 multiplier: 1, constant: 0)
      c.isActive = true
      checkSnapshot(of: container, suffix: "_last_first" + suffix)
      c.isActive = false
    }

    {
      let c = constrain(labelA, .firstBaseline, eq, labelB, .lastBaseline)
      c.isActive = true
      checkSnapshot(of: container, suffix: "_first_last" + suffix)

      swap(&labelA.attributedText, &labelB.attributedText)
      checkSnapshot(of: container, suffix: "_swapped_first_last" + suffix)
    }()
  }

  func testSpacingConstraints() {
    let container = newContainer()
    let labelA = newLabel("A")
    let labelB = newLabel("B")
    let labelC = newLabel("C")

    container.addSubview(labelA)
    container.addSubview(labelB)
    container.addSubview(labelC)

    var cs = [NSLayoutConstraint]()
    constrain(&cs, labelA, within: container)
    constrain(&cs, labelB, within: container)
    constrain(&cs, labelC, within: container)

    constrain(&cs, labelA, .right, eq, labelB, .left, plus: -20)
    constrain(&cs, labelB, .leading, eq, labelC, .leading)

    cs.activate()

    let c0 = constrain(labelA, .firstBaseline, eq, labelB, .firstBaseline)
    XCTAssertEqual(c0.stu_isLabelSpacingConstraint, false)
    XCTAssertEqual(c0.stu_labelSpacingConstraintMultiplier, 0)
    XCTAssertEqual(c0.stu_labelSpacingConstraintOffset, 0)

    c0.isActive = true

    labelA.attributedText = NSAttributedString([("Lj 1A\n", [.font: font(size: 36)]),
                                                ("Lj 2A", [.font: font(size: 16)])])

    labelB.attributedText = NSAttributedString("Lj 1B\n", [.font: font(size: 36)])
    labelC.attributedText = NSAttributedString("Lj 1B\n", [.font: font(size: 16)])


    ({
      let c = constrain(labelB, .lastBaseline, eq, positionAbove: labelC, .firstBaseline)
      c.isActive = true
      defer { c.isActive = false }

      checkSnapshot(of: container, suffix: "_1" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 1)
      c.stu_labelSpacingConstraintMultiplier = 2
      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 2)
      checkSnapshot(of: container, suffix: "_2" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, 0)
      c.stu_labelSpacingConstraintOffset = -3
      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, -3)
      checkSnapshot(of: container, suffix: "_3" + suffix)
    }())

    ({
      let c = constrain(labelB, .lastBaseline, eq, positionAbove: labelC, .firstBaseline,
                        spacingMultipliedBy: 2, plus: -3)
      c.isActive = true
      defer { c.isActive = false }
      checkSnapshot(of: container, suffix: "_3" + suffix)
    }())

    ({
      let c = constrain(labelC, .firstBaseline, eq, positionBelow: labelB, .lastBaseline,
                        spacingMultipliedBy: 1)
      c.isActive = true
      defer { c.isActive = false }

      checkSnapshot(of: container, suffix: "_1" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 1)
      c.stu_labelSpacingConstraintMultiplier = 2
      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 2)
      checkSnapshot(of: container, suffix: "_2" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, 0)
      c.stu_labelSpacingConstraintOffset = 3
      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, 3)
      checkSnapshot(of: container, suffix: "_3" + suffix)

      let c2 = constrain(labelC, .firstBaseline, leq, positionBelow: labelB, .lastBaseline,
                        spacingMultipliedBy: 3)
      c2.isActive = true
      defer { c2.isActive = false }

      let c3 = constrain(labelC, .firstBaseline, geq, positionBelow: labelB, .lastBaseline,
                        spacingMultipliedBy: 1.5)
      c2.isActive = true
      defer { c2.isActive = false }

      checkSnapshot(of: container, suffix: "_3" + suffix)
    }())

    ({
      let c = constrain(labelC, .firstBaseline, eq, positionBelow: labelB, .lastBaseline,
                        spacingMultipliedBy: 2, plus: 3)
      c.isActive = true
      defer { c.isActive = false }
      checkSnapshot(of: container, suffix: "_3" + suffix)
    }())

    labelA.attributedText = NSAttributedString([("Lj 1A\n", [.font: font(size: 36)]),
                                                ("Lj 2A", [.font: font(size: 36)])])

    ({
      let c = constrain(labelC, .firstBaseline, eq, labelB, .lastBaseline,
                        plusLineHeightMultipliedBy: 1)
      c.isActive = true
      defer { c.isActive = false }

      checkSnapshot(of: container, suffix: "_lineHeight_1" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 1)
      c.stu_labelSpacingConstraintMultiplier = 2
      XCTAssertEqual(c.stu_labelSpacingConstraintMultiplier, 2)
      checkSnapshot(of: container, suffix: "_lineHeight_2" + suffix)

      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, 0)
      c.stu_labelSpacingConstraintOffset = 3
      XCTAssertEqual(c.stu_labelSpacingConstraintOffset, 3)
      checkSnapshot(of: container, suffix: "_lineHeight_3" + suffix)

      c.stu_labelSpacingConstraintMultiplier = 1
      c.stu_labelSpacingConstraintOffset = 0

      let view = newView("overlay")
      container.addSubview(view)
      view.backgroundColor = UIColor.orange.withAlphaComponent(0.25)
      [constrain(view, .height, eq, 1/stu_mainScreenScale()),
       constrain(view, .leading, eq, labelC, .leading),
       constrain(view, .width, eq, labelC, .width),
       constrain(view, .top, eq, labelB, .lastBaseline,
                 plusLineHeightMultipliedBy: 1, plus: -1/stu_mainScreenScale())].activate()

      checkSnapshot(of: container, suffix: "_lineHeight_1_overlay" + suffix)
    }())
  }

  func testLabelBaselinesLayoutGuideDestructor() {
    _ = autoreleasepool { () -> NSLayoutConstraint? in
      let container: UIView = newContainer()
      let labelA: STULabel = newLabel("A")
      let labelB: STULabel = newLabel("B")

      container.addSubview(labelA)
      container.addSubview(labelB)
      let c = constrain(labelA, .firstBaseline, eq, positionAbove: labelB, .lastBaseline)
      c.isActive = true
      let c2 = constrain(labelB, .firstBaseline, eq, positionAbove: labelA, .lastBaseline)
      c2.isActive = true
      return c // Trigger destruction of labels and layout guides (because the constraint doesn't
               // retain the items.)
    }
  }

  func testSpacingAboveAndBelowWithNonLabelAnchor() {
    let container = newContainer()
    let label = newLabel()

    let f = UIFont(name: "Helvetica", size: 16)!
    assert(f.leading == 0)
    let size1 = (roundToDisplayScale(f.ascender)/f.ascender)*16
    let size2 = (roundToDisplayScale(f.descender)/f.descender)*16
    label.attributedText = NSAttributedString(
                             [("Lj 1\n", [.font: UIFont(name: "Helvetica", size: size1)!]),
                              ("Lj 2", [.font: UIFont(name: "Helvetica", size: size2)!])])
    let viewAbove = newView("above")
    viewAbove.backgroundColor = .red
    let viewBelow = newView("below")
    viewBelow.backgroundColor = .blue

    container.addSubview(label)
    container.addSubview(viewAbove)
    container.addSubview(viewBelow)

    let onePixel = 1/stu_mainScreenScale()

    var cs = [NSLayoutConstraint]()
    constrain(&cs, label, within: container)
    constrain(&cs, viewAbove, .left, eq, label, .left)
    constrain(&cs, viewBelow, .left, eq, label, .left)
    constrain(&cs, viewAbove, .width, eq, label, .width)
    constrain(&cs, viewBelow, .width, eq, label, .width)
    constrain(&cs, viewAbove, .height, eq, onePixel)
    constrain(&cs, viewBelow, .height, eq, onePixel)
    cs.append(constrain(viewAbove.bottomAnchor, eq, positionAbove: label, .firstBaseline,
                        plus: onePixel))
    cs.append(constrain(viewBelow.topAnchor, eq, positionBelow: label, .lastBaseline,
                        plus: -onePixel))
    cs.activate()

    checkSnapshot(of: container, suffix: suffix)
  }
}
