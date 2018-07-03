// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUTextFrame.DrawingOptions {

  /// Sets the specified STUTextFrameRange as the highlight range.
  ///
  /// - note: A `STUTextFrameDrawingOptions` instance with a `STUTextFrameRange` highlight range
  ///         must only be used together with `STUTextFrame` instances for which the range is valid.
  /// - postcondition: `highlightTextFrameRange == textFrameRange`
  @_transparent
  public func setHighlightRange(_ textFrameRange: Range<STUTextFrame.Index>) {
    __setHighlightRange(__STUTextFrameRange(textFrameRange))
  }

  @_transparent
  public var highlightTextFrameRange: Optional<Range<STUTextFrame.Index>> {
    var range = __STUTextFrameRange()
    if __getHighlightTextFrameRange(&range) {
      return Range<STUTextFrame.Index>(range)
    }
    return nil
  }
}
