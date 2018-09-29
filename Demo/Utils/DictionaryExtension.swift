// Copyright 2018 Stephan Tolksdorf

extension Dictionary {
  mutating func update(with other: Dictionary) {
    for (key, value) in other {
      self[key] = value
    }
  }

  func updated(with other: Dictionary) -> Dictionary {
    var dict = self
    dict.update(with: other)
    return dict
  }

  func updated(with value: Value, forKey key: Key) -> Dictionary {
    var dict = self
    dict[key] = value
    return dict
  }
}
