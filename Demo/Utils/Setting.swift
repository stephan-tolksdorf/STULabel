// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

// The classes here are *not* thread-safe.

protocol PropertyObserverProtocol : AnyObject {
  func propertyDidChange(_ property: PropertyBase)
}

class PropertyBase {
  fileprivate init() {}

  /// Does not retain the observer. The observer should deregister itself in its deinitializer.
  func addObserver(_ observer: PropertyObserverProtocol) {
    if observers.updateValue(ObserverRef(observer), forKey: ObjectIdentifier(observer)) != nil {
      fatalError("The observer was already registered")
    }
  }

  func removeObserver(_ observer: AnyObject) {
    if observers.removeValue(forKey: ObjectIdentifier(observer)) == nil {
      fatalError("The observer was not registered")
    }
  }

  func notifyObservers() {
    for observerRef in observers.values {
      observerRef.observer.propertyDidChange(self)
    }
  }

  private var observers = [ObjectIdentifier: ObserverRef]()

  private struct ObserverRef {
    unowned let observer: PropertyObserverProtocol

    init(_ observer: PropertyObserverProtocol) {
      self.observer = observer
    }
  }
}

class Property<Value> : PropertyBase {
  private(set) var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func setValueWithoutNotifyingObservers(_ value: Value) {
    self.value = value
  }

  func setChangedValue(_ newValue: Value) {
    setValueWithoutNotifyingObservers(newValue)
    notifyObservers()
  }

  func observe(onChange: @escaping () -> ()) -> PropertyObserver<Value> {
    return PropertyObserver(self, onChange: onChange)
  }

  func observe(onChange: @escaping (_ newValue: Value) -> ()) -> PropertyObserver<Value> {
    return observe { [unowned self] in
      onChange(self.value)
    }
  }
}

extension Property where Value : Equatable {
  func setValue(_ value: Value) {
    if self.value == value { return }
    setChangedValue(value)
  }
}

class PropertyObserver<Value> : PropertyObserverProtocol {
  let property: Property<Value>
  let onChange: () -> ()

  init(_ property: Property<Value>, onChange: @escaping () -> ()) {
    self.property = property
    self.onChange = onChange
    property.addObserver(self)
  }

  func propertyDidChange(_ property: PropertyBase) {
    onChange()
  }

  deinit {
    let retainedSelf = self
    property.removeObserver(retainedSelf)
  }
}

class ProjectedProperty<Value, ProjectedValue : Equatable>
    : Property<ProjectedValue>, PropertyObserverProtocol
{

  let property: Property<Value>
  let getter: (Value) -> ProjectedValue
  let setter: (inout Value, ProjectedValue) -> ()

  init(_ property: Property<Value>,
       getter: @escaping (Value) -> ProjectedValue,
       setter: @escaping (inout Value, ProjectedValue) -> ())
  {
    self.property = property
    self.getter = getter
    self.setter = setter
    super.init(self.getter(property.value))
    property.addObserver(self)
  }

  deinit {
    property.removeObserver(self)
  }

  private var isSettingValueDueToParentPropertyChange: Bool = false

  func propertyDidChange(_ property: PropertyBase) {
    assert(property === self.property)
    isSettingValueDueToParentPropertyChange = true
    self.value = getter(self.property.value)
  }

  override var value: ProjectedValue {
    get { return super.value }
    set { setValue(newValue) }
  }

  override func setChangedValue(_ newValue: ProjectedValue) {
    if isSettingValueDueToParentPropertyChange {
      super.setChangedValue(newValue)
    } else {
      var value = property.value
      setter(&value, newValue)
      property.setChangedValue(value) // Will call propertyDidChange.
    }
  }

  override func notifyObservers() {
    let shouldNotifyPropertyObservers = !isSettingValueDueToParentPropertyChange
    isSettingValueDueToParentPropertyChange = false
    super.notifyObservers()
    if shouldNotifyPropertyObservers {
      property.notifyObservers()
    }
  }
}

class PropertyObserverContainer {
  private var observers = [AnyObject]()

  func observe<Value>(_ property: Property<Value>, _ onChange: @escaping () -> ()) {
    observers.append(property.observe(onChange: onChange))
  }

  func observe<Value>(_ property: Property<Value>, _ onChange: @escaping (Value) -> ()) {
    observers.append(property.observe(onChange: onChange))
  }

  func observe<Value, ProjectedValue: Equatable>(_ property: Property<Value>,
                                                 _ getter: @escaping (Value) -> ProjectedValue,
                                                 _ onChange: @escaping (ProjectedValue) -> ())
  {
    var lastProjectedValue = getter(property.value)
    observers.append(property.observe { value in
      let projectedValue = getter(value)
      if projectedValue != lastProjectedValue {
        lastProjectedValue = projectedValue
        onChange(projectedValue)
      }
    })
  }
}

protocol UserDefaultsStorable {
  func save(to userDefaults: UserDefaults, key: String)

  static func load(from userDefaults: UserDefaults, key: String) -> Self?
}

class Setting<Value : UserDefaultsStorable & Equatable> : Property<Value> {
  let id: String
  let defaultValue: Value

  init(id: String, default defaultValue: Value) {
    self.id = id
    self.defaultValue = defaultValue
    super.init(Value.load(from: UserDefaults.standard, key: id) ?? defaultValue)
  }

  override var value: Value {
    get { return super.value }
    set { setValue(newValue) }
  }

  func resetValue() {
    if value != defaultValue {
      setChangedValue(defaultValue)
    }
  }

  var onChange: (() -> ())?

  override func notifyObservers() {
    if value != defaultValue {
      value.save(to: UserDefaults.standard, key: id)
    } else {
      UserDefaults.standard.removeObject(forKey: id)
    }
    onChange?()
    super.notifyObservers()
  }
}


protocol PropertyListType {}
extension Bool       : PropertyListType {}
extension CGFloat    : PropertyListType {}
extension Float32    : PropertyListType {}
extension Float64    : PropertyListType {}
extension Int        : PropertyListType {}
extension Int8       : PropertyListType {}
extension Int16      : PropertyListType {}
extension Int32      : PropertyListType {}
extension Int64      : PropertyListType {}
extension UInt       : PropertyListType {}
extension UInt8      : PropertyListType {}
extension UInt16     : PropertyListType {}
extension UInt32     : PropertyListType {}
extension UInt64     : PropertyListType {}
extension String     : PropertyListType {}
extension Data       : PropertyListType {}
extension Array      : PropertyListType where Element : PropertyListType {}
extension Dictionary : PropertyListType where Key : PropertyListType, Value : PropertyListType {}

// Swift doesn't support adding a protocol conformance in a protocol extension, so we first add
// the methods in a protocol extension and then individually add the protocol conformances to
// individual types.

extension PropertyListType {
  func save(to userDefaults: UserDefaults, key: String) {
    userDefaults.setValue(self, forKey: key)
  }

  static func load(from userDefaults: UserDefaults, key: String) -> Self? {
    return userDefaults.object(forKey: key) as? Self
  }
}

extension Bool       : UserDefaultsStorable {}
extension CGFloat    : UserDefaultsStorable {}
extension Float32    : UserDefaultsStorable {}
extension Float64    : UserDefaultsStorable {}
extension Int        : UserDefaultsStorable {}
extension Int8       : UserDefaultsStorable {}
extension Int16      : UserDefaultsStorable {}
extension Int32      : UserDefaultsStorable {}
extension Int64      : UserDefaultsStorable {}
extension UInt       : UserDefaultsStorable {}
extension UInt8      : UserDefaultsStorable {}
extension UInt16     : UserDefaultsStorable {}
extension UInt32     : UserDefaultsStorable {}
extension UInt64     : UserDefaultsStorable {}
extension String     : UserDefaultsStorable {}
extension Data       : UserDefaultsStorable {}
extension Array      : UserDefaultsStorable where Element : PropertyListType {}
extension Dictionary : UserDefaultsStorable where Key : PropertyListType, Value : PropertyListType {}


extension Optional : UserDefaultsStorable where Wrapped : UserDefaultsStorable {
  func save(to userDefaults: UserDefaults, key: String) {
    if let value = self {
      value.save(to: userDefaults, key: key)
    } else {
      userDefaults.removeObject(forKey: key)
    }
  }

  static func load(from userDefaults: UserDefaults, key: String) -> Optional<Wrapped>? {
    return Wrapped.load(from: userDefaults, key: key)
  }
}

extension NSSecureCoding {
  func save(to userDefaults: UserDefaults, key: String) {
    let data = NSKeyedArchiver.archivedData(withRootObject: self)
    userDefaults.set(data, forKey: key)
  }

  static func load(from userDefaults: UserDefaults, key: String) -> Self? {
    if let data = userDefaults.object(forKey: key) as? NSData {
      return NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? Self
    }
    return nil
  }
}

extension UIColor : UserDefaultsStorable {}

extension UIFont : UserDefaultsStorable {}

extension RawRepresentable where RawValue : UserDefaultsStorable {
  func save(to userDefaults: UserDefaults, key: String) {
    rawValue.save(to: userDefaults, key: key)
  }

  static func load(from userDefaults: UserDefaults, key: String) -> Self? {
    if let value = RawValue.load(from: userDefaults, key: key) {
      return Self(rawValue: value)
    }
    return nil
  }
}

extension NSUnderlineStyle : UserDefaultsStorable {}
extension STULastLineTruncationMode : UserDefaultsStorable {}
extension STUTextLayoutMode : UserDefaultsStorable {}
extension UIFont.TextStyle : UserDefaultsStorable {}
extension UIContentSizeCategory : UserDefaultsStorable {}

extension UDHR.Translation : Equatable, UserDefaultsStorable {
  static func ==(_ lhs: UDHR.Translation, _ rhs: UDHR.Translation) -> Bool {
    return lhs === rhs
  }

  func save(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(languageCode, forKey: key)
  }

  static func load(from userDefaults: UserDefaults, key: String) -> UDHR.Translation? {
    if let code = userDefaults.string(forKey: key) {
      return udhr.translationsByLanguageCode[code]
    }
    return nil
  }
}
