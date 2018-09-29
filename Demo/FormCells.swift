// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

private let defaultDetailLabelColor = UITableViewCell(style: .value1, reuseIdentifier: nil).detailTextLabel?.textColor!

class SwitchCell : UITableViewCell, PropertyObserverProtocol {

  private let switchView = UISwitch()

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var attributedTitle: NSAttributedString? {
    get { return self.textLabel!.attributedText }
    set { self.textLabel!.attributedText = newValue }
  }

  var value: Bool {
    get { return switchView.isOn }
    set {
      if newValue == switchView.isOn { return }
      self.switchView.setOn(newValue, animated: true)
    }
  }

  var isEnabled: Bool {
    get { return switchView.isEnabled }
    set {
      switchView.isEnabled = newValue
      self.textLabel?.isEnabled = newValue
    }
  }

  var onValueChange: ((Bool) -> ())?

  let property: Property<Bool>?

  init(_ title: String, _ property: Property<Bool>) {
    self.property = property
    super.init(style: .value1, reuseIdentifier: nil)
    self.title = title
    initCommon(value: property.value)
    property.addObserver(self)
  }
  init(_ title: NSAttributedString, _ property: Property<Bool>) {
    self.property = property
    super.init(style: .value1, reuseIdentifier: nil)
    self.attributedTitle = title
    initCommon(value: property.value)
    property.addObserver(self)
  }

  deinit {
    if let property = property {
      property.removeObserver(self)
    }
  }

  init(_ title: String, value: Bool) {
    self.property = nil
    super.init(style: .value1, reuseIdentifier: nil)
    self.title = title
    initCommon(value: value)
  }

  init(_ title: NSAttributedString, value: Bool) {
    self.property = nil
    super.init(style: .value1, reuseIdentifier: nil)
    self.attributedTitle = title
    initCommon(value: value)
  }

  private func initCommon(value: Bool) {
    textLabel!.numberOfLines = 0
    switchView.isOn = value
    accessoryView = switchView
    switchView.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    selectionStyle = .none
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }


  func propertyDidChange(_ property: PropertyBase) {
    assert(property === self.property)
    self.value = self.property!.value
  }

  @objc private func switchValueChanged() {
    let value = self.value
    if let property = self.property {
      property.setValue(value)
    }
    self.onValueChange?(self.value)
  }
}

class ButtonCell : UITableViewCell {
  private let button = UIButton(type: .system)

  var title: String? {
    get { return self.button.title(for: .normal) }
    set { self.button.setTitle(newValue, for: .normal) }
  }

  var isEnabled: Bool {
    get { return button.isEnabled }
    set {
      button.isEnabled = newValue
      self.textLabel?.isEnabled = newValue
    }
  }

  var onButtonTap: (() -> ())?

  init(_ title: String) {
    super.init(style: .value1, reuseIdentifier: nil)
    button.layer.borderWidth = 1
    button.layer.borderColor = button.titleColor(for: .normal)?.cgColor
    button.layer.cornerRadius = 10
    self.title = title
    button.translatesAutoresizingMaskIntoConstraints = false
    self.contentView.addSubview(button)
    constrain(button, toEdgesOf: self.contentView.layoutMarginsGuide).activate()
    self.button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    self.selectionStyle = .none
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @objc private func buttonTapped() {
    self.onButtonTap?()
  }
}

protocol BinaryFloatingPointOrInt : Comparable, Codable {
  init(_ value: Float64)

  var asFloat64: Float64 { get }
}

extension Float32 : BinaryFloatingPointOrInt { var asFloat64: Float64 { return Float64(self) } }
extension Float64 : BinaryFloatingPointOrInt { var asFloat64: Float64 { return self } }
extension CGFloat : BinaryFloatingPointOrInt { var asFloat64: Float64 { return Float64(self) } }
extension Int : BinaryFloatingPointOrInt     { var asFloat64: Float64 { return Float64(self) } }

class StepperCell<Value: BinaryFloatingPointOrInt> : UITableViewCell, PropertyObserverProtocol {

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var range: ClosedRange<Value> {
    didSet {
      setStepperRange(range)
      self.value = Value(stepper.value)
    }
  }

  private var _value: Value
  var value: Value {
    get { return _value }
    set {
      _value = Value(newValue.asFloat64)
      if isEnabled {
        stepper.value = _value.asFloat64
        setNeedsDetailTextUpdate()
      } else {
        setStepperRange(newValue...newValue)
      }
    }
  }

  private func setStepperRange(_ range: ClosedRange<Value>) {
    if range.lowerBound.asFloat64 < stepper.maximumValue {
      stepper.minimumValue = range.lowerBound.asFloat64
      stepper.maximumValue = range.upperBound.asFloat64
    } else {
      stepper.maximumValue = range.upperBound.asFloat64
      stepper.minimumValue = range.lowerBound.asFloat64
    }
    setNeedsDetailTextUpdate()
  }

  var numberFormat: String = "%.0f" {
    didSet {
      setNeedsDetailTextUpdate()
    }
  }

  var step: Value {
    get { return Value(stepper.stepValue) }
    set {
      let step = newValue.asFloat64
      stepper.stepValue = step
      if round(step) == step {
        numberFormat = "%.0f"
      } else if round(step*10)/10 == step {
        numberFormat = "%.1f"
      } else {
        numberFormat = "%.2f"
      }
    }
  }

  var roundsValueToMultipleOfStepSize: Bool = false

  var isEnabled: Bool {
    get { return stepper.isEnabled }
    set {
      stepper.isEnabled = newValue
      setStepperRange(newValue ? range : value...value)
      textLabel?.isEnabled = newValue
      detailTextLabel?.isEnabled = newValue
    }
  }

  var unit: String {
    didSet {
      setNeedsDetailTextUpdate()
    }
  }

  var detailText: String {
    if needsDetailTextUpdate {
      updateDetailText()
    }
    return detailTextLabel?.text ?? ""
  }

  var isContinuous: Bool = false

  var onValueChange: ((Value) -> ())?

  let property: Property<Value>?

  init(_ title: String, _ range: ClosedRange<Value>, step: Value, _ property: Property<Value>,
       unit: String = "")
  {
    self.range = range
    self._value = property.value
    self.unit = unit
    self.property = property
    super.init(style: .value1, reuseIdentifier: nil)
    initCommon(title, step: step)
    property.addObserver(self)
  }

  deinit {
    if let property = property {
      property.removeObserver(self)
    }
  }

  init(_ title: String, _ range: ClosedRange<Value>, step: Value, value: Value, unit: String = "") {
    self.range = range
    self._value = value
    self.unit = unit
    self.property = nil
    super.init(style: .value1, reuseIdentifier: nil)
    initCommon(title, step: step)
  }
  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func initCommon(_ title: String, step: Value) {
    self.textLabel?.adjustsFontSizeToFitWidth = true
    self.textLabel?.minimumScaleFactor = 0.1
    self.title = title
    self.step = step
    setStepperRange(range)
    self.value = _value
    self.stepper.addTarget(self, action: #selector(stepperValueChanged), for: .valueChanged)
    self.stepper.addTarget(self, action: #selector(touchUp), for: .touchUpInside)
    self.stepper.addTarget(self, action: #selector(touchUp), for: .touchUpOutside)
    self.selectionStyle = .none
    self.contentView.layoutMargins.right = 10
    self.accessoryView = stepperContainer
  }

  func propertyDidChange(_ property: PropertyBase) {
    assert(self.property === property)
    self.value = self.property!.value
  }

  private var delayedNotification: Bool = false

  @objc private func stepperValueChanged() {
    var value = Value(self.stepper.value)
    if roundsValueToMultipleOfStepSize {
      let step = self.stepper.stepValue
      let roundedValue = Value(round(value.asFloat64/step)*step)
      if range.contains(roundedValue) {
        value = roundedValue
        self.stepper.value = value.asFloat64
      }
    }
    if _value == value { return }
    _value = value
    setNeedsDetailTextUpdate()
    if !isContinuous {
      delayedNotification = true
    } else {
      notifyObservers()
    }
  }

  @objc private func touchUp()  {
    if delayedNotification {
      notifyObservers()
    }
  }

  private func notifyObservers() {
    delayedNotification = false
    if let property = self.property {
      property.setValue(value)
    }
    onValueChange?(value)
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    detailTextLabel?.font = preferredFontWithMonospacedDigits(.body, traitCollection)
  }

  private var needsDetailTextUpdate: Bool = false
  private func setNeedsDetailTextUpdate() {
    if needsDetailTextUpdate { return }
    needsDetailTextUpdate = true
    setNeedsLayout()
  }

  private func updateDetailText() {
    needsDetailTextUpdate = false
    let valueString = String(format: numberFormat, value.asFloat64)
    detailTextLabel?.text = unit.isEmpty ? valueString : "\(valueString) \(unit)"
  }

  override func layoutSubviews() {
    if needsDetailTextUpdate {
      updateDetailText()
    }
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

  private var stepper: UIStepper { return stepperContainer.stepper }

  private let stepperContainer = StepperContainer()
  private class StepperContainer : UIView {
    let stepper = UIStepper()
    init() {
      let size = stepper.intrinsicContentSize
      let x: CGFloat = 10 // padding
      stepper.frame = CGRect(origin: CGPoint(x: x, y: 0), size: size)
      stepper.autoresizingMask = [.flexibleHeight, .flexibleWidth]
      super.init(frame: CGRect(origin: .zero,
                               size: CGSize(width: size.width + x, height: size.height)))
      self.addSubview(stepper)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  }
}

class SelectCell<Value> : UITableViewCell {

  var title: String? {
    get { return self.textLabel!.text }
    set { self.textLabel!.text = newValue }
  }

  var navigationItemTitle: String?

  private(set) var values: [(name: String, value: Value)]

  var index: Int {
    didSet {
      updateLabel()
      tableViewController?.tableView.reloadData()
    }
  }

  var value: Value { return values[index].value }

  var valueName: String { return values[index].name }

  var detailText: String {
    get { return detailTextLabel?.text ?? "" }
    set {
      detailTextLabel?.text = newValue
    }
  }

  var detailTextColor: UIColor? {
    get { return detailTextLabel?.textColor }
    set {
      detailTextLabel?.textColor = newValue?.withAlphaComponent(2/3.0) ?? defaultDetailLabelColor
    }
  }

  private func updateLabel() {
     self.detailTextLabel!.text = 0 <= index && index < values.count ? values[index].name : ""
  }

  func set(values: [(name: String, value: Value)], index: Int) {
    precondition(0 <= index && index < values.count)
    self.values = values
    self.index = index
  }

  var valueLabelStyler: ((_ index: Int, _ value: Value, _ label: UILabel) -> ())?

  fileprivate(set) var property: Property<Value>?

  var onIndexChange: ((_ index: Int, _ value: Value) -> ())?

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

  deinit {
    property?.removeObserver(self)
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    let oldValue = self.isSelected
    if selected == oldValue { return }
    super.setSelected(selected, animated: animated)
    if selected {
      let tvc = SelectionViewController(self)
      if let title = navigationItemTitle {
        tvc.navigationItem.title = title
      }
      tableViewController = tvc
      self.stu_viewController?.navigationController!.pushViewController(tvc, animated: true)
    }
  }

  private weak var tableViewController: SelectionViewController?

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
      if let styler = selectCell.valueLabelStyler {
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
      selectCell.tableViewController = nil
      if selectCell.index != index {
        selectCell.index = index
        let value = selectCell.values[index].value
        selectCell.property?.setChangedValue(value)
        selectCell.onIndexChange?(index, value)
      }
      self.navigationController?.popViewController(animated: true)
    }
  }
}

extension SelectCell : PropertyObserverProtocol where Value : Equatable {
  func setValue(_ value: Value) {
    if value == self.value { return }
    self.index = self.values.index { $0.value == value }!
  }

  func propertyDidChange(_ property: PropertyBase) {
    assert(property === self.property)
    self.setValue(self.property!.value)
  }

  convenience init(_ title: String, _ values: [(name: String, value: Value)], value: Value) {
    self.init(title, values, index: values.index { $0.value == value}!)
  }

  convenience init(_ title: String, _ values: [(name: String, value: Value)],
                   _ property: Property<Value>)
  {
    self.init(title, values, value: property.value)
    self.property = property
    property.addObserver(self)
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
    set {
      detailTextLabel?.textColor = newValue?.withAlphaComponent(2/3.0) ?? defaultDetailLabelColor
    }
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
    let footerContentMargins = footerContentView.layoutMarginsGuide

    [constrain(footerLabel, .top, eq, footerContentMargins, .top),
     constrain(footerLabel, .bottom, leq, footerContentMargins, .bottom),
     constrain(footerLabel, .leading, eq, footerContentMargins, .leading),
     constrain(footerLabel, .trailing, leq, footerContentMargins, .trailing)].activate()

    footerCell.separatorInset = .init(top: 0, left: 4096, bottom: 0, right: 0)
    footerCell.selectionStyle = .none
    footerCell.contentView.preservesSuperviewLayoutMargins = true
    footerCell.contentView.layoutMargins.top *= 2
    footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    if #available(iOS 10, tvOS 10, *) {
      footerLabel.adjustsFontForContentSizeCategory = true
    }
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
