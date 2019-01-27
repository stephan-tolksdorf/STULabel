// Copyright 2017–2018 Stephan Tolksdorf

@_exported import STULabel

extension STUStartEndRange {
  @inlinable
  public var nsRange: NSRange {
    return NSRange(location: start, length: end &- start)
  }
}

extension STUStartEndRangeI32 {
  @inlinable
  public var nsRange: NSRange {
    return NSRange(location: Int(start), length: Int(end) &- Int(start))
  }
}
