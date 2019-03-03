// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

class TimingResultView<SampleView : UIView> : UIView {
  typealias LabelView = STULabel

  let titleLabel = LabelView()

  class SampleViewWithLabel : Equatable, Hashable {
    let label = LabelView()
    let view: SampleView

    init(_ view: SampleView) {
      self.view = view
      label.font = UIFont.preferredFont(forTextStyle: .footnote)
      label.minimumTextScaleFactor = 0.01
      label.verticalAlignment = .center
      if #available(iOS 10, *) {
        label.adjustsFontForContentSizeCategory = true
      }
    }

    fileprivate let layoutGuide = UILayoutGuide()

    static func ==(_ lhs: SampleViewWithLabel, _ rhs: SampleViewWithLabel) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    func hash(into hasher: inout Hasher) {
      ObjectIdentifier(self).hash(into: &hasher)
    }
    
  }

  class TimingRow : UIView {
    
    let column1Label = STULabel()
    let column2Label = STULabel()
    let secondLineLabel = STULabel()

    init() {
      super.init(frame: .zero)
      self.translatesAutoresizingMaskIntoConstraints = false
      layoutMargins = .zero
      column1Label.maximumNumberOfLines = 0
      column2Label.maximumNumberOfLines = 0
      secondLineLabel.maximumNumberOfLines = 0
      column1Label.font = UIFont.preferredFont(forTextStyle: .body)
      column2Label.font = preferredFontWithMonospacedDigits(.body)
      secondLineLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
      if #available(iOS 10, *) {
        column1Label.adjustsFontForContentSizeCategory = true
        column2Label.adjustsFontForContentSizeCategory = true
        secondLineLabel.adjustsFontForContentSizeCategory = true
      }
      column1Label.translatesAutoresizingMaskIntoConstraints = false
      column2Label.translatesAutoresizingMaskIntoConstraints = false
      secondLineLabel.translatesAutoresizingMaskIntoConstraints = false
      column1Label.setContentCompressionResistancePriority(
                     column2Label.contentCompressionResistancePriority(for: .horizontal) + 1,
                     for: .horizontal)

      self.addSubview(column1Label)
      self.addSubview(column2Label)
      self.addSubview(secondLineLabel)

      var cs = [NSLayoutConstraint]()
      constrain(&cs, column1Label, within: self)
      constrain(&cs, column2Label, within: self)
      constrain(&cs, column1Label, .firstBaseline, eq, column2Label, .firstBaseline)

      constrain(&cs, secondLineLabel, verticallyWithin: self)
      constrain(&cs, secondLineLabel, .firstBaseline, geq, positionBelow: column1Label, .lastBaseline,
                spacingMultipliedBy: 0.9)
      constrain(&cs, secondLineLabel, .firstBaseline, geq, positionBelow: column2Label, .lastBaseline,
                spacingMultipliedBy: 0.9)

      constrain(&cs, column1Label, .leading,   eq, secondLineLabel, .leading)
      constrain(&cs, column2Label, .trailing, geq, secondLineLabel, .trailing)

      cs.activate()
    }
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

  private func removeAllConstraints() {
    if !ourConstraints.isEmpty {
      ourConstraints.deactivate()
      ourConstraints.removeAll(keepingCapacity: true)
    }
  }

  var sampleViews: [SampleViewWithLabel] = [] {
    didSet {
      removeAllConstraints()
      for sv in oldValue {
        guard sampleViews.firstIndex(where: {$0.label == sv.label}) == nil else { continue }
        sv.label.removeFromSuperview()
        sv.view.removeFromSuperview()
        self.removeLayoutGuide(sv.layoutGuide)
      }
      for sv in sampleViews {
        sv.label.translatesAutoresizingMaskIntoConstraints = false
        sv.view.translatesAutoresizingMaskIntoConstraints = false
        if sv.label.superview != self { self.addSubview(sv.label) }
        if sv.view.superview != self { self.addSubview(sv.view) }
        if sv.layoutGuide.owningView != self { self.addLayoutGuide(sv.layoutGuide) }
      }
      setNeedsUpdateConstraints()
    }
  }

  var timingRows: [TimingRow] = [] {
    didSet {
      removeAllConstraints()
      for row in oldValue {
        guard timingRows.firstIndex(of: row) == nil else { continue }
        row.removeFromSuperview()
      }
      for row in timingRows {
        if row.superview != self { self.addSubview(row) }
      }
      setNeedsUpdateConstraints()
    }
  }

  let button = UIButton(type: .system)

  var onButtonTap: (() -> ())?

  @objc private func buttonTouchUpInside() { onButtonTap?() }

  var padding: CGFloat = 10 {
    didSet {
      setNeedsUpdateConstraints()
    }
  }

  var timingsColumnMinWidth: CGFloat {
    get { return timingsColumn2MinWidthConstraint.constant }
    set { timingsColumn2MinWidthConstraint.constant = newValue }
  }

  private let sampleViewsLayoutGuide = UILayoutGuide()
  private let sampleViewsColumn1 = UILayoutGuide()
  private let sampleViewsColumn2 = UILayoutGuide()

  private let timingsLayoutGuide = UILayoutGuide()
  private let timingsColumn1 = UILayoutGuide()
  private let timingsColumn2 = UILayoutGuide()

  private let timingsColumn2MinWidthConstraint: NSLayoutConstraint
  private var sampleViewsColumnSpacingConstraint: NSLayoutConstraint!
  private var timingsColumnSpacingConstraint: NSLayoutConstraint!

  init() {
    timingsColumn2MinWidthConstraint = constrain(timingsColumn2, .width, .greaterThanOrEqual, 0)
    super.init(frame: .zero)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.maximumNumberOfLines = 0
    titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
    self.addSubview(titleLabel)

    button.translatesAutoresizingMaskIntoConstraints = false
    button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    button.layer.borderWidth = 1
    button.layer.cornerRadius = 5
    button.layer.borderColor = self.tintColor.cgColor
    button.titleLabel!.font = UIFont.preferredFont(forTextStyle: .body)
    button.titleLabel!.adjustsFontSizeToFitWidth = true
    button.titleLabel!.minimumScaleFactor = 0.25
    button.addTarget(self, action: #selector(buttonTouchUpInside), for: .touchUpInside)
    self.addSubview(button)

    if #available(iOS 10, *) {
      titleLabel.adjustsFontForContentSizeCategory = true
      button.titleLabel!.adjustsFontForContentSizeCategory = true
    }

    addLayoutGuide(sampleViewsLayoutGuide)
    addLayoutGuide(sampleViewsColumn1)
    addLayoutGuide(sampleViewsColumn2)

    addLayoutGuide(timingsLayoutGuide)
    addLayoutGuide(timingsColumn1)
    addLayoutGuide(timingsColumn2)

    var cs = [timingsColumn2MinWidthConstraint]

    constrain(&cs, leadingToTrailing: [sampleViewsColumn1, sampleViewsColumn2],
              within: sampleViewsLayoutGuide, verticalAlignment: .top)
    sampleViewsColumnSpacingConstraint = cs[cs.count - 2]

    constrain(&cs, sampleViewsLayoutGuide, .width, eq, 0, priority: .fittingSizeLevel)

    constrain(&cs, leadingToTrailing: [timingsColumn1, timingsColumn2],
              within: timingsLayoutGuide, verticalAlignment: .top)
    constrain(&cs, timingsColumn1, .width, geq, 150, priority: .defaultLow - 1)
    timingsColumnSpacingConstraint = cs[cs.count - 2]

    cs.activate()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private var ourConstraints = [NSLayoutConstraint]()

  private var shouldPlaceLabelsAboveSampleViews: Bool = false

  private func updateShouldPlaceLabelsAboveSampleViews() -> Bool {
    guard let superview = self.superview else { return false }
    // This is just a "quick and dirty" implementation.
    let availableWidth = superview.bounds.width == 0 ? 0
                       : superview.readableContentGuide.layoutFrame.width
    var newValue = false
    for sv in sampleViews {
      if sv.label.intrinsicContentSize.width + padding + sv.view.frame.size.width > availableWidth {
        newValue = true
        break
      }
    }
    let oldValue = shouldPlaceLabelsAboveSampleViews
    shouldPlaceLabelsAboveSampleViews = newValue
    return oldValue != newValue
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if updateShouldPlaceLabelsAboveSampleViews() {
      self.setNeedsUpdateConstraints()
    }
  }

  override func updateConstraints() {
    ourConstraints.deactivate()
    ourConstraints.removeAll()
    var cs = [NSLayoutConstraint]()

    let margin = self.layoutMarginsGuide

    sampleViewsColumnSpacingConstraint.constant = padding
    timingsColumnSpacingConstraint.constant = padding

    let verticalStack: [ViewOrLayoutGuide] = [
      titleLabel, sampleViewsLayoutGuide, timingsLayoutGuide, button
    ]

    constrain(&cs, topToBottom: verticalStack, spacing: padding, within: margin)
    if !timingRows.isEmpty {
      cs[cs.count - 3].constant = 2*padding // The spacing after the sample views.
    }
    for item in verticalStack {
      constrain(&cs, item, leadingWithin: margin)
    }

    constrain(&cs, topToBottom: sampleViews.lazy.map { $0.layoutGuide }, spacing: padding,
              within: sampleViewsLayoutGuide)

    _ = updateShouldPlaceLabelsAboveSampleViews()

    for sv in sampleViews {
      constrain(&cs, sv.layoutGuide, toHorizontalEdgesOf: timingsLayoutGuide)

      if shouldPlaceLabelsAboveSampleViews {
        constrain(&cs, topToBottom:[sv.label, sv.view], within:sv.layoutGuide,
                  horizontalAlignment: .leading)
      } else {
        constrain(&cs, sv.label, leadingWithin: sampleViewsColumn1)
        constrain(&cs, sv.view,  leadingWithin: sampleViewsColumn2)

        constrain(&cs, sv.label, verticallyCenteredWithin: sv.layoutGuide)
        constrain(&cs, sv.view,  verticallyCenteredWithin: sv.layoutGuide)
      }
    }

    constrain(&cs, topToBottom: timingRows, spacing: padding, within: timingsLayoutGuide)
    for r in timingRows {
      constrain(&cs, r, toHorizontalEdgesOf: timingsLayoutGuide)
      constrain(&cs, r.column1Label, leadingWithin: timingsColumn1)
      constrain(&cs, r.column2Label, leadingWithin: timingsColumn2)
    }

    ourConstraints = cs
    ourConstraints.activate()

    super.updateConstraints()
  }
}
