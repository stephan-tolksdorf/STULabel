// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension STULabelLayer {
  @inlinable
  public var textFrame: STUTextFrameWithOrigin {
    return STUTextFrameWithOrigin(__STULabelLayerGetTextFrameWithOrigin(self))
  }
}
