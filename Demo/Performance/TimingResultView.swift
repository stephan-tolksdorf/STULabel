// Copyright 2018 Stephan Tolksdorf

import STULabel

func preferredFontWithMonospacedDigits(_ textStyle: UIFontTextStyle,
                                       _ traitCollection: UITraitCollection? = nil)
      -> UIFont
{
  let font: UIFont
  if #available(iOS 11, *) {
    let mediumTraitCollection = UITraitCollection(preferredContentSizeCategory: .medium)
    font = UIFont.preferredFont(
            forTextStyle: textStyle,
             compatibleWith: traitCollection == nil ? mediumTraitCollection
                             : UITraitCollection(traitsFrom: [traitCollection!,
                                                              mediumTraitCollection]))
  } else if #available(iOS 10, *) {
    font = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
  } else {
    font = UIFont.preferredFont(forTextStyle: textStyle)
  }
  let weight = (font.fontDescriptor.fontAttributes[.traits]
                as! [UIFontDescriptor.TraitKey: Any]?)?[.weight]
               as! UIFont.Weight?
  let mfont = UIFont.monospacedDigitSystemFont(ofSize: font.pointSize,
                                               weight: weight ?? .regular)
  if #available(iOS 11, *) {
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: mfont,
                                                             compatibleWith: traitCollection)
  } else {
    return mfont
  }
}


class TimingResultView<SampleView : UIView> : UIView {
  let titleLabel  = STULabel()

  class SampleViewWithLabel {
    let label = STULabel()
    let view: SampleView

    init(_ view: SampleView) {
      self.view = view
      label.minTextScaleFactor = 0.25
      label.font = UIFont.preferredFont(forTextStyle: .body)
      label.textScalingBaselineAdjustment = .none
      label.verticalAlignment = .center
      if #available(iOS 10, *) {
        label.adjustsFontForContentSizeCategory = true
      }
    }

    fileprivate let layoutGuide = UILayoutGuide()
  }

  class TimingRow : UIView {
    
    let column1Label = STULabel()
    let column2Label = STULabel()

    init() {
      super.init(frame: .zero)
      layoutMargins = .zero
      column1Label.maxLineCount = 0
      column2Label.maxLineCount = 0
      column1Label.font = UIFont.preferredFont(forTextStyle: .body)
      column2Label.font = preferredFontWithMonospacedDigits(.body)
      if #available(iOS 10, *) {
        column1Label.adjustsFontForContentSizeCategory = true
        column2Label.adjustsFontForContentSizeCategory = true
      }
      column1Label.translatesAutoresizingMaskIntoConstraints = false
      column2Label.translatesAutoresizingMaskIntoConstraints = false
      column1Label.setContentCompressionResistancePriority(
                     column2Label.contentCompressionResistancePriority(for: .horizontal) + 1,
                     for: .horizontal)

      self.addSubview(column1Label)
      self.addSubview(column2Label)

      var cs = [NSLayoutConstraint]()
      constrain(&cs, column1Label, within: self)
      constrain(&cs, column2Label, within: self)
      constrain(&cs, column1Label, .firstBaseline, .equal, column2Label, .firstBaseline)
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
        guard sampleViews.index(where: {$0.label == sv.label}) == nil else { continue }
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
      if !ourConstraints.isEmpty {
        ourConstraints.deactivate()
        ourConstraints.removeAll(keepingCapacity: true)
      }
      for row in oldValue {
        guard timingRows.index(of: row) == nil else { continue }
        row.removeFromSuperview()
      }
      for row in timingRows {
        row.translatesAutoresizingMaskIntoConstraints = false
        if row.superview != self { self.addSubview(row) }
      }
      setNeedsUpdateConstraints()
    }
  }

  let button = UIButton(type: .system)

  var buttonTapped: (() -> ())?

  @objc private func buttonTouchUpInside() { buttonTapped?() }

  var padding: CGFloat = 10 {
    didSet {
      setNeedsUpdateConstraints()
    }
  }

  var timingsColumnMinWidth: CGFloat {
    get { return timingsColumn2MinWidthConstrain.constant }
    set { timingsColumn2MinWidthConstrain.constant = newValue }
  }

  private let sampleViewLabelGuide = UILayoutGuide()

  private let timingsLayoutGuide = UILayoutGuide()
  private let timingsColumn1 = UILayoutGuide()
  private let timingsColumn2 = UILayoutGuide()
  private let timingsVerticalSpacer = UILayoutGuide()
  private let timingsColumn2MinWidthConstrain: NSLayoutConstraint



  init() {
    timingsColumn2MinWidthConstrain = constrain(timingsColumn2, .width, .greaterThanOrEqual, 0)
    super.init(frame: .zero)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.maxLineCount = 0
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

    addLayoutGuide(sampleViewLabelGuide)
    addLayoutGuide(timingsLayoutGuide)
    addLayoutGuide(timingsColumn1)
    addLayoutGuide(timingsVerticalSpacer)
    addLayoutGuide(timingsColumn2)


    var cs = [timingsColumn2MinWidthConstrain]
    constrain(&cs, sampleViewLabelGuide, .leading, .equal, self, .leadingMargin)
    constrain(&cs, leadingToTrailing:[timingsColumn1, timingsVerticalSpacer, timingsColumn2],
              within: timingsLayoutGuide)
    for column in [timingsColumn1, timingsColumn2] {
      constrain(&cs, column, toVerticalEdgesOf: timingsLayoutGuide)
    }

    cs.activate()
  }

  private var timingsColumnsHorizontalSpacingConstraints: [NSLayoutConstraint] = []

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }


  private var ourConstraints = [NSLayoutConstraint]()

  override func updateConstraints() {
    ourConstraints.deactivate()
    var cs = ourConstraints
    ourConstraints.removeAll(keepingCapacity: false)

    var verticalStack = [ViewOrLayoutGuide]()
    verticalStack.reserveCapacity(2 + sampleViews.count + timingRows.count)
    verticalStack.append(titleLabel)
    for sv in sampleViews { verticalStack.append(sv.layoutGuide) }
    verticalStack.append(timingsLayoutGuide)
    verticalStack.append(button)

    let s = padding

    constrain(&cs, topToBottom: verticalStack, spacing: s, withinMarginsOf: self)
    cs[cs.count - 3].constant = 2*s

    for item in verticalStack {
      constrain(&cs, item, .leading,  .equal,           self, .leadingMargin)
      constrain(&cs, item, .trailing, .lessThanOrEqual, self, .trailingMargin)
    }

    for sv in sampleViews {
      constrain(&cs, leadingToTrailing: [sv.label, sv.view], spacing: s, within: sv.layoutGuide)
      constrain(&cs, sv.label, verticallyCenteredWithin: sv.layoutGuide)
      constrain(&cs, sv.view, verticallyCenteredWithin: sv.layoutGuide)
      constrain(&cs, sv.label, toHorizontalEdgesOf: sampleViewLabelGuide)
    }

    constrain(&cs, timingsVerticalSpacer, .width, .equal, s, priority:.defaultHigh)

    constrain(&cs, topToBottom: timingRows, spacing: 5, within: timingsLayoutGuide)
    for r in timingRows {
      constrain(&cs, r, toHorizontalEdgesOf: timingsLayoutGuide)
      constrain(&cs, r.column1Label, toHorizontalEdgesOf: timingsColumn1)
      constrain(&cs, r.column2Label, toHorizontalEdgesOf: timingsColumn2)
    }

    ourConstraints = cs
    ourConstraints.activate()

    super.updateConstraints()
  }

}
