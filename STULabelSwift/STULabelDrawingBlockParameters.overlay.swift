// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension STULabelDrawingBlockParameters {
  @inlinable
  public var textFrame: STUTextFrameWithOrigin {
    return STUTextFrameWithOrigin(__STULabelDrawingBlockParametersGetTextFrameWithOrigin(self))
  }

  @inlinable
  public var range: Range<STUTextFrame.Index> { return Range(__range) }
}


