// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension STULabel {
  @inlinable
  public var textFrame: STUTextFrameWithOrigin {
    return STUTextFrameWithOrigin(__STULabelGetTextFrameWithOrigin(self))
  }
}

