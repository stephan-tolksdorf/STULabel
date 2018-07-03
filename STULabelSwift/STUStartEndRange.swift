// Copyright 2017–2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUStartEndRange {
  @_transparent
  public var nsRange: NSRange {
    return NSRange(location: start, length: end &- start)
  }
}

public extension STUStartEndRangeI32 {
  @_transparent
  public var nsRange: NSRange {
    return NSRange(location: Int(start), length: Int(end) &- Int(start))
  }
}
