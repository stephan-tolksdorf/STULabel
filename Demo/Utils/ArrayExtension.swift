// Copyright 2018 Stephan Tolksdorf

#if swift(>=4.1.5)
#else
extension Array {
  func last(where predicate: (Element) throws -> Bool) rethrows -> Element? {
    for element in self.self.reversed() {
      if try predicate(element) {
        return element
      }
    }
    return nil
  }
}
#endif
