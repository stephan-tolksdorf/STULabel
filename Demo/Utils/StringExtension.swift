extension String.Index {
  /// Temporary compatibility shim for Xcode < 10.2.
  func _utf16Offset(in string: String) -> Int {
  #if swift(>=4.2.5)  // This version number is a guess.
    return utf16Offset(in: string)
  #else
    return string.utf16.distance(from: string.utf16.startIndex, to: self)
  #endif
  }
}
