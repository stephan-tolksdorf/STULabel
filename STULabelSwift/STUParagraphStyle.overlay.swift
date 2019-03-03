// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public enum STUFirstLineOffset : Equatable {
  /// Offset of the first baseline from the default position.
  case offsetOfFirstBaselineFromDefault(_: CGFloat)

  /// Offset of the first baseline from the top of the paragraph.
  ///
  /// The offset value must be non-negative.
  case offsetOfFirstBaselineFromTop(_: CGFloat)

  /// Offset from the top of the paragraph to the vertical center of the first text line's layout
  /// bounds.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY
  ///        + (line.heightBelowBaseline - line.heightAboveBaseline)/2
  ///        - paragraph.minY
  /// @endcode
  ///
  /// See the documentation for the `STUTextLayoutMode` cases for a definition of a line's
  /// `heightAboveBaseline` and `heightBelowBaseline`.
  ///
  /// The offset value must be non-negative.
  case offsetOfFirstLineCenterFromTop(_: CGFloat)

  /// Offset from the top of the paragraph to the the vertical center above the baseline of the
  /// first text line's (largest) uppercase letters.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY - line.maxCapHeight/2 - paragraph.minY
  /// @endcode
  ///
  /// The offset value must be non-negative.
  case offsetOfFirstLineCapHeightCenterFromTop(_: CGFloat)

  /// Offset from the top of the paragraph to the vertical center above the baseline of the first
  /// text line's (largest) lowercase letters.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY - line.maxXHeight/2 - paragraph.minY
  /// @endcode
  ///
  /// The offset value must be non-negative.
  case offsetOfFirstLineXHeightCenterFromTop(_: CGFloat)

  public var typeAndValue: (STUFirstLineOffsetType, CGFloat) {
    switch self {
    case      .offsetOfFirstBaselineFromDefault(let value):
      return (.offsetOfFirstBaselineFromDefault, value)
    case      .offsetOfFirstBaselineFromTop(let value):
      return (.offsetOfFirstBaselineFromTop, value)
    case      .offsetOfFirstLineCenterFromTop(let value):
      return (.offsetOfFirstLineCenterFromTop, value)
    case      .offsetOfFirstLineCapHeightCenterFromTop(let value):
      return (.offsetOfFirstLineCapHeightCenterFromTop, value)
    case      .offsetOfFirstLineXHeightCenterFromTop(let value):
      return (.offsetOfFirstLineXHeightCenterFromTop, value)
    }
  }

  @inlinable
  public init(_ typeAndValue: (STUFirstLineOffsetType, CGFloat)) {
    self.init(typeAndValue.0, typeAndValue.1)
  }
  public init(_ type: STUFirstLineOffsetType, _ value: CGFloat) {
    switch type {
    case     .offsetOfFirstBaselineFromDefault:
      self = .offsetOfFirstBaselineFromDefault(value)
    case     .offsetOfFirstBaselineFromTop:
      self = .offsetOfFirstBaselineFromTop(value)
    case     .offsetOfFirstLineCenterFromTop:
      self = .offsetOfFirstLineCenterFromTop(value)
    case     .offsetOfFirstLineCapHeightCenterFromTop:
      self = .offsetOfFirstLineCapHeightCenterFromTop(value)
    case     .offsetOfFirstLineXHeightCenterFromTop:
      self = .offsetOfFirstLineXHeightCenterFromTop(value)
    }
  }
}


extension STUParagraphStyle {
  @inlinable
  public var firstLineOffset: STUFirstLineOffset {
    return STUFirstLineOffset(__firstLineOffsetType, __firstLineOffset)
  }
}


extension STUParagraphStyleBuilder {
  @inlinable
  public var firstLineOffset: STUFirstLineOffset {
    get { return STUFirstLineOffset(__firstLineOffsetType, __firstLineOffset) }
    set {
      let (type, value) = newValue.typeAndValue
      __setFirstLineOffset(value, type: type)
    }
  }
}
