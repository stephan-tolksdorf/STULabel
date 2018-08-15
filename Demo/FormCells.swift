// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

private let defaultDetailLabelColor = UITableViewCell(style: .value1, reuseIdentifier: nil).detailTextLabel?.textColor!

class SwitchCell : UITableViewCell {

  private let switchView = UISwitch()

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var value: Bool {
    get { return switchView.isOn }
    set { self.switchView.setOn(newValue, animated: true) }
  }

  var isEnabled: Bool {
    get { return switchView.isEnabled }
    set {
      switchView.isEnabled = newValue
      self.textLabel?.isEnabled = newValue
    }
  }

  var didChangeValue: ((Bool) -> ())?

  init(_ title: String, value: Bool) {
    super.init(style: .value1, reuseIdentifier: nil)
    self.title = title
    self.switchView.isOn = value
    self.accessoryView = switchView
    self.switchView.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    self.selectionStyle = .none

  }
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @objc private func switchValueChanged() {
    self.didChangeValue?(self.value)
  }

}

class StepperCell : UITableViewCell {

  private class StepperContainer : UIView {
    let stepper = UIStepper()
    init() {
      let size = stepper.intrinsicContentSize
      let x: CGFloat = 10 // padding
      stepper.frame = CGRect(origin: CGPoint(x: x, y: 0), size: size)
      stepper.autoresizingMask = [.flexibleHeight, .flexibleWidth]
      super.init(frame: CGRect(origin: .zero, size: CGSize(width: size.width + x, height: size.height)))
      self.addSubview(stepper)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  }

  private let stepper: UIStepper

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var range: ClosedRange<Double> {
    didSet {
      setStepperRange(range)
      if !isEnabled {
        setStepperRange(value...value)
      }
    }
  }

  private func setStepperRange(_ range: ClosedRange<Double>) {
    if range.lowerBound < stepper.maximumValue {
      stepper.minimumValue = range.lowerBound
      stepper.maximumValue = range.upperBound
    } else {
      stepper.maximumValue = range.upperBound
      stepper.minimumValue = range.lowerBound
    }
    updateDetailLabel()
  }

  var numberFormat: String = "%.0f"

  var step: Double  {
    get { return stepper.stepValue }
    set {
      stepper.stepValue = newValue
      if round(step) == step {
        numberFormat = "%.0f"
      } else if round(step*10)/10 == step {
        numberFormat = "%.1f"
      } else {
        numberFormat = "%.2f"
      }
    }
  }

  var unit: String

  var value: Double {
    get { return stepper.value }
    set {
      if isEnabled {
        stepper.value = newValue
        updateDetailLabel()
      } else {
        setStepperRange(newValue...newValue)
      }
    }
  }

  var isEnabled: Bool {
    get { return stepper.isEnabled }
    set {
      stepper.isEnabled = newValue
      setStepperRange(newValue ? range : value...value)
      textLabel?.isEnabled = newValue
      detailTextLabel?.isEnabled = newValue
    }
  }

  var detailText: String {
    return detailTextLabel?.text ?? ""
  }

  var isContinuous: Bool = true

  var didChangeValue: ((Double) -> ())?

  init(_ title: String, _ range: ClosedRange<Double>, step: Double, value: Double, unit: String = "") {
    let stepperContainer = StepperContainer()
    self.stepper = stepperContainer.stepper
    self.range = range
    self.unit = unit
    super.init(style: .value1, reuseIdentifier: nil)
    self.textLabel?.adjustsFontSizeToFitWidth = true
    self.textLabel?.minimumScaleFactor = 0.1
    self.title = title
    setStepperRange(range)
    self.step = step
    self.value = value
    self.stepper.addTarget(self, action: #selector(stepperValueChanged), for: .valueChanged)
    self.stepper.addTarget(self, action: #selector(touchUp), for: .touchUpInside)
    self.stepper.addTarget(self, action: #selector(touchUp), for: .touchUpOutside)
    self.selectionStyle = .none
    self.contentView.layoutMargins.right = 10
    self.accessoryView = stepperContainer
  }
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private var previousValue: Double?

  @objc private func stepperValueChanged() {
    updateDetailLabel()
    let value = self.value
    if isContinuous && value != previousValue {
      previousValue = value
      didChangeValue?(value)
    }
  }

  @objc private func touchUp()  {
    let value = self.value
    if !isContinuous && value != previousValue {
      previousValue = value
      didChangeValue?(value)
    }
  }

  private func updateDetailLabel() {
    let valueString = String(format: numberFormat, value)
    self.detailTextLabel?.text = unit.isEmpty ? valueString : "\(valueString) \(unit)"
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    self.detailTextLabel?.font = preferredFontWithMonospacedDigits(.body, traitCollection)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let label = self.textLabel!
    let detailLabel = self.detailTextLabel!
    var detailLabelFrame = detailLabel.frame
    let detailLabelWidth = detailLabel.sizeThatFits(CGSize(width: 1000, height: 1000)).width
    if detailLabelWidth > detailLabelFrame.width {
      var labelFrame = label.frame
      let d = min(detailLabelWidth - detailLabelFrame.size.width, label.frame.width)
      let isLTR = labelFrame.origin.x <= detailLabelFrame.origin.x
      labelFrame.origin.x += isLTR ? 0 : d
      labelFrame.size.width -= d
      detailLabelFrame.origin.x += isLTR ? -d : 0
      detailLabelFrame.size.width += d
      label.frame = labelFrame
      detailLabel.frame = detailLabelFrame
    }
  }
}

class SelectCell<Value> : UITableViewCell {

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var navigationItemTitle: String?

  private(set) var values: [(name: String, value: Value)]

  private(set) var index: Int {
    didSet {
      updateLabel()
    }
  }

  var value: Value { return values[index].value }

  var detailText: String {
    get { return detailTextLabel?.text ?? "" }
    set {
      detailTextLabel?.text = newValue
    }
  }

  var detailTextColor: UIColor? {
    get { return detailTextLabel?.textColor }
    set { detailTextLabel?.textColor = newValue?.withAlphaComponent(2/3.0) ?? defaultDetailLabelColor }
  }

  private func updateLabel() {
     self.detailTextLabel!.text = 0 <= index && index < values.count ? values[index].name : ""
  }

  func set(values: [(name: String, value: Value)], index: Int) {
    precondition(0 <= index && index < values.count)
    self.values = values
    self.index = index
  }

  var labelStyler: ((_ index: Int, _ value: Value, _ label: UILabel) -> ())?

  var didChangeIndex: ((_ index: Int, _ value: Value) -> ())?

  required init(_ title: String, _ values: [(name: String, value: Value)], index: Int = 0) {
    precondition(0 <= index && index < values.count)
    self.values = values
    self.index = index
    super.init(style: .value1, reuseIdentifier: nil)
    self.detailTextLabel?.adjustsFontSizeToFitWidth = true
    self.detailTextLabel?.minimumScaleFactor = 0.1
    updateLabel()
    self.title = title
    self.accessoryType = .disclosureIndicator
  }
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func setSelected(_ selected: Bool, animated: Bool) {
    let oldValue = self.isSelected
    if selected == oldValue { return }
    super.setSelected(selected, animated: animated)
    if selected {
      let vc = SelectionViewController(self)
      if let title = navigationItemTitle {
        vc.navigationItem.title = title
      }
      self.stu_viewController?.navigationController!
          .pushViewController(vc, animated: true)

    }
  }

  private class SelectionViewController : UITableViewController {
    let selectCell: SelectCell

    init(_ selectCell: SelectCell) {
      self.selectCell = selectCell
      super.init(style: .plain)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
      self.tableView!.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
      self.tableView.alwaysBounceVertical = false
      DispatchQueue.main.async {
        self.tableView.scrollToRow(at: IndexPath(row: self.selectCell.index, section: 0),
                                   at: .middle, animated: false)
      }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return section == 0 ? selectCell.values.count : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
               -> UITableViewCell
    {
      let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
      let index = indexPath.row
      cell.textLabel!.text = selectCell.values[index].name
      cell.textLabel!.numberOfLines = 0
      if let styler = selectCell.labelStyler {
        styler(index, selectCell.values[index].value, cell.textLabel!)
      }
      cell.accessoryType = index == selectCell.index ? .checkmark : .none
      return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath)
               -> IndexPath?
    {
      if let oldIndexPath = tableView.indexPathForSelectedRow, oldIndexPath != indexPath {
        tableView.cellForRow(at: oldIndexPath)?.accessoryType = .none
      }
      return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
      let index = indexPath.row
      selectCell.index = index
      selectCell.didChangeIndex?(index, selectCell.values[index].value)
      self.navigationController?.popViewController(animated: true)
    }
  }
}

extension SelectCell where Value : Equatable {
  convenience init(_ title: String, _ values: [(name: String, value: Value)], value: Value) {
    self.init(title, values, index: values.index { $0.value == value}!)
  }
}


class SubtableCell : UITableViewCell {
  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var cells: [UITableViewCell] {
    didSet {
      tableViewController?.tableView.reloadData()
    }
  }

  var detailText: String {
    get { return detailTextLabel?.text ?? "" }
    set {
      detailTextLabel?.text = newValue
    }
  }

  var detailTextColor: UIColor? {
    get { return detailTextLabel?.textColor }
    set { detailTextLabel?.textColor = newValue?.withAlphaComponent(2/3.0) ?? defaultDetailLabelColor }
  }

  let footerLabel = UILabel()

  private var footerCell = UITableViewCell(style: .value1, reuseIdentifier: nil)

  init(_ title: String, _ cells: [UITableViewCell], value: String = "") {
    self.cells = cells
    super.init(style: .value1, reuseIdentifier: nil)
    self.detailTextLabel?.adjustsFontSizeToFitWidth = true
    self.detailTextLabel?.minimumScaleFactor = 0.1

    self.title = title
    self.accessoryType = .disclosureIndicator

    footerLabel.translatesAutoresizingMaskIntoConstraints = false
    let footerContentView = footerCell.contentView
    footerContentView.addSubview(footerLabel)
    var cs = [NSLayoutConstraint]()
    let font = UIFont.preferredFont(forTextStyle: .footnote)
    constrain(&cs, footerLabel, .top, eq, footerContentView, .top,
              constant: roundToDisplayScale(font.lineHeight))
    constrain(&cs, footerLabel, .bottom, leq, footerContentView, .bottom)
    constrain(&cs, footerLabel, .leading, eq, footerContentView, .leadingMargin)
    constrain(&cs, footerLabel, .trailing, leq, footerContentView, .trailingMargin)

    cs.activate()

    footerCell.separatorInset = .init(top: 0, left: 4096, bottom: 0, right: 0)
    footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    footerLabel.numberOfLines = 0
    footerLabel.textColor = .gray
  }
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }


  private weak var tableViewController: SubtableViewController?

  override func setSelected(_ selected: Bool, animated: Bool) {
    let oldValue = self.isSelected
    if selected == oldValue { return }
    super.setSelected(selected, animated: animated)
    if selected {
      let vc = SubtableViewController(self)
      tableViewController = vc
      self.stu_viewController?.navigationController!.pushViewController(vc, animated: true)
    }
  }

  private class SubtableViewController : UITableViewController {
    let subtableCell: SubtableCell

    let footer = UIView()
    let footerLabel = UILabel()

    init(_ subtableCell: SubtableCell) {
      self.subtableCell = subtableCell
      super.init(style: .plain)
      self.navigationItem.title = subtableCell.title
      if #available(iOS 11, tvOS 11, *) {}
      else {
        tableView.estimatedRowHeight = 57.5
      }
      self.tableView.tableFooterView = UIView()
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
      self.tableView.alwaysBounceVertical = false
    }

    private var navigationBarWasHidden: Bool = false

    override func viewWillAppear(_ animated: Bool) {
      if isMovingToParent {
        navigationBarWasHidden = navigationController?.isNavigationBarHidden ?? true
        navigationController?.setNavigationBarHidden(false, animated: animated)
      }
      super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      if isMovingFromParent && navigationBarWasHidden {
        navigationController?.setNavigationBarHidden(true, animated: animated)
      }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return section == 0 ? subtableCell.cells.count + 1 : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
               -> UITableViewCell
    {
      let index = indexPath.row
      let cell = index < subtableCell.cells.count
               ? subtableCell.cells[indexPath.row]
               : subtableCell.footerCell
      tableView.addSubview(cell)
      return cell
    }
  }
}
