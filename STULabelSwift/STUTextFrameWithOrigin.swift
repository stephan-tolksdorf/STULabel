// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel
@_exported import STULabel.SwiftExtensions

/// A convenience wrapper struct for a `STUTextFrame` with a fixed origin and display scale.
///
/// This wrapper forwards all method calls to the corresponding `STUTextFrame` method,
/// with `self.origin` as the text frame origin argument and `self.displayScale` as the display
/// scale argument where necessary.
public struct STUTextFrameWithOrigin {
  public let textFrame: STUTextFrame
  public let origin: CGPoint
  @usableFromInline
  internal let displayScaleOrZero: CGFloat

  @inlinable
  public var displayScale: CGFloat? { return displayScaleOrZero > 0 ? displayScaleOrZero : nil }

  @inlinable
  public init(_ shapedString: STUShapedString, stringRange: NSRange? = nil,
              rect: CGRect, displayScale: CGFloat?, options: STUTextFrameOptions? = nil)
  {
    self.textFrame = STUTextFrame(shapedString, stringRange: stringRange,
                                  size: rect.size, displayScale: displayScale, options: options)
    self.origin = rect.origin
    self.displayScaleOrZero = textFrame.displayScaleOrZero
  }

  @inlinable
  public init?(_ shapedString: STUShapedString, stringRange: NSRange? = nil,
               rect: CGRect, displayScale: CGFloat?, options: STUTextFrameOptions? = nil,
               cancellationFlag: UnsafePointer<STUCancellationFlag>)
  {
    guard let textFrame = STUTextFrame(shapedString, stringRange: stringRange,
                                       size: rect.size, displayScale: displayScale,
                                       options: options, cancellationFlag: cancellationFlag)
    else { return nil }
    self.textFrame = textFrame
    self.origin = rect.origin
    self.displayScaleOrZero = textFrame.displayScaleOrZero
  }

  @inlinable
  public init(_ textFrame: STUTextFrame, _ origin: CGPoint, displayScale: CGFloat?) {
    self.textFrame = textFrame
    self.origin = origin
    if let displayScale = displayScale, displayScale > 0 {
      self.displayScaleOrZero = displayScale
    } else {
      self.displayScaleOrZero = 0
    }
  }

  @inlinable
  internal init(_ other: __STUTextFrameWithOrigin) {
    self.textFrame = other.textFrame.takeUnretainedValue()
    self.origin = other.origin
    self.displayScaleOrZero = other.displayScale
  }

  @inlinable
  internal init(_ textFrame: STUTextFrame, _ origin: CGPoint, displayScaleOrZero: CGFloat) {
    self.textFrame = textFrame
    self.origin = origin
    self.displayScaleOrZero = displayScaleOrZero
  }

  /// The attributed string of the `STUShapedString` from which the text frame was created.
  @inlinable
  public var originalAttributedString: NSAttributedString {
    return textFrame.originalAttributedString
  }

  /// The UTF-16 range in the original string from which the `STUTextFrame` was created.
  ///
  /// This range equals the string range that was passed to the initializer, except if the
  /// specified `STUTextFrameOptions.lastLineTruncationMode` was `clip` and the full (sub)string
  /// didn't fit the frame size, in which case this range will be shorter.
  @inlinable
  public var rangeInOriginalString: NSRange { return textFrame.rangeInOriginalString }

  @inlinable
  public var rangeInOriginalStringIsFullString: Bool {
    return textFrame.rangeInOriginalStringIsFullString
  }

  /// The size that was specified when the `STUTextFrame` instance was initialized. This size can
  /// be much larger than the layout bounds of the text, particularly if the text frame was created
  /// by a label view.
  @inlinable
  public var size: CGSize { return textFrame.size }

  /// Returns `CGRect(origin: self.origin, size: self.size)`.
  @inlinable
  public var rect: CGRect { return CGRect(origin: origin, size: size) }

  /// The `self.rangeInOriginalString` substring of `self.originalAttributedString`, truncated in
  /// the same way it is truncated when the text is drawn, i.e. with truncation tokens replacing
  /// text that doesn't fit the frame size.
  ///
  /// This value is lazily computed and cached.
  ///
  /// @note This string does NOT contain any hyphens that were automatically during line breaking.
  ///
  /// @note This string contains the text with the original font sizes, even when the text is scaled
  ///       down when it is drawn, i.e. when `layoutInfo.textScaleFactor < 1`.
  ///
  @inlinable
  public var truncatedAttributedString: NSAttributedString {
    return textFrame.truncatedAttributedString
  }

  @inlinable
  public var truncatedStringUTF16Length: Int {
    return textFrame.truncatedStringUTF16Length
  }

  public func attributes(at index: STUTextFrame.Index)  -> [NSAttributedString.Key : Any]? {
    return textFrame.attributes(at: index)
  }

  public func attributes(atUTF16IndexInTruncatedString index: Int)
    -> [NSAttributedString.Key : Any]?
  {
    return textFrame.attributes(atUTF16IndexInTruncatedString: index)
  }

  public typealias Index = STUTextFrame.Index

  @inlinable
  public var startIndex: Index { return textFrame.startIndex }

  @inlinable
  public var endIndex: Index { return textFrame.endIndex }

  @inlinable
  public var indices: Range<Index> { return startIndex..<endIndex }

  public func index(forUTF16IndexInOriginalString indexInOriginalString: Int,
                    indexInTruncationToken: Int) -> Index
  {
    return textFrame.index(forUTF16IndexInOriginalString: indexInOriginalString,
                           indexInTruncationToken: indexInTruncationToken)
  }

  @inlinable
  public func index(forUTF16IndexInTruncatedString indexInTruncatedString: Int) -> Index {
    return textFrame.index(forUTF16IndexInTruncatedString: indexInTruncatedString)
  }

  @inlinable
  public func range(forRangeInOriginalString range: NSRange) -> Range<Index> {
    return textFrame.range(forRangeInOriginalString: range)
  }

  @inlinable
  public func range(forRangeInTruncatedString range: NSRange) -> Range<Index> {
    return textFrame.range(forRangeInTruncatedString: range)
  }

  @inlinable
  public func range(for textRange: STUTextRange) -> Range<Index> {
    return textFrame.range(for: textRange)
  }

  public typealias GraphemeClusterRange = STUTextFrame.GraphemeClusterRange

  @inlinable
  public func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool)
    -> GraphemeClusterRange
  {
    precondition(ignoringTrailingWhitespace,
                 "Currently only ignoringTrailingWhitespace == true is supported.")
    return textFrame.rangeOfGraphemeCluster(closestTo: point,
                                            ignoringTrailingWhitespace: ignoringTrailingWhitespace,
                                            frameOrigin: origin,
                                            displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  public func rangeInOriginalString(for index: Index) -> NSRange {
    return textFrame.rangeInOriginalString(for: index)
  }

  @inlinable
  public func rangeInOriginalString(for range: Range<Index>) -> NSRange {
    return textFrame.rangeInOriginalString(for: range)
  }

  @inlinable
  public func rangeInOriginalStringAndTruncationTokenIndex(for index: Index)
    -> (NSRange, (truncationToken: NSAttributedString, indexInToken: Int)?)
  {
    return textFrame.rangeInOriginalStringAndTruncationTokenIndex(for: index)
  }

  @inlinable
  public var rangeOfLastTruncationToken: Range<Index> {
    return textFrame.rangeOfLastTruncationToken
  }

  public typealias DrawingOptions = STUTextFrame.DrawingOptions

  @inlinable
  public func draw(range: Range<Index>? = nil,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    textFrame.draw(range: range, at: origin, options: options, cancellationFlag: cancellationFlag)
  }

  @inlinable
  public func draw(range: Range<Index>? = nil,
                   in context: CGContext,
                   contextBaseCTM_d: CGFloat,
                   pixelAlignBaselines: Bool,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    textFrame.draw(range: range, at: origin, in: context, contextBaseCTM_d: contextBaseCTM_d,
                   pixelAlignBaselines: pixelAlignBaselines, options: options,
                   cancellationFlag: cancellationFlag)
  }

  @inlinable
  public func imageBounds(for range: Range<Index>? = nil,
                          options: DrawingOptions? = nil,
                          cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
    -> CGRect
  {
    return textFrame.imageBounds(for: range, frameOrigin: origin,
                                 displayScaleOrZero: displayScaleOrZero,
                                 options: options, cancellationFlag: cancellationFlag)
  }

  @inlinable
  public var layoutInfo: STUTextFrame.LayoutInfo {
    return textFrame.layoutInfo(frameOrigin: origin)
  }

  @inlinable
  public var flags: STUTextFrame.Flags { return textFrame.flags }

  @inlinable
  public var layoutMode: STUTextLayoutMode { return textFrame.layoutMode }

  @inlinable
  public var consistentAlignment: STUTextFrame.ConsistentAlignment {
    return textFrame.consistentAlignment
  }

  @inlinable
  public var textScaleFactor: CGFloat { return textFrame.textScaleFactor }

  /// Returns the union of the layout bounds of all text lines, including all vertical line spacing
  /// and all horizontal paragraph insets.
  ///
  /// - Note: The returned rectangle is not rounded.
  @inlinable
  public var layoutBounds: CGRect {
    return textFrame.layoutBounds(frameOrigin: origin, displayScaleOrZero: displayScaleOrZero)
  }

  /// The Y-coordinate of the first baseline.
  @inlinable
  public var firstBaseline: CGFloat {
    return textFrame.firstBaseline(frameOriginY: origin.y, displayScaleOrZero: displayScaleOrZero)
  }

  /// The Y-coordinate of the last baseline.
  @inlinable
  public var lastBaseline: CGFloat {
    return textFrame.lastBaseline(frameOriginY: origin.y, displayScaleOrZero: displayScaleOrZero)
  }

   /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  @inlinable
  public var firstLineHeight: CGFloat { return textFrame.firstLineHeight }

  /// The part of the first line's layout height that lies above the baseline.
  @inlinable
  public var firstLineHeightAboveBaseline: CGFloat { return textFrame.firstLineHeightAboveBaseline }

  /// The value that the text layout algorithm would calculate for the ideal distance between the
  /// baseline of the last text line in the text frame and the baseline of a (hypothetical)
  /// adjacent text line that has the same typographic metrics and is in the same paragraph.
  @inlinable
  public var lastLineHeight: CGFloat { return textFrame.lastLineHeight }

  /// The part of the last line's layout height that lies below the baseline.
  @inlinable
  public var lastLineHeightBelowBaseline: CGFloat { return textFrame.lastLineHeightBelowBaseline }

  /// The part of the last line's layout height that lies below the baseline, excluding any line
  /// spacing. This is the height below the baseline that is assumed when deciding whether the
  /// line fits the text frame's size.
  @inlinable
  public var lastLineHeightBelowBaselineWithoutSpacing: CGFloat {
    return textFrame.lastLineHeightBelowBaselineWithoutSpacing
  }

  /// The part of the last line's layout height that lies below the baseline, with only a minimal
  /// layout-mode-dependent amount of spacing included. This is the height below the baseline
  /// assumed for a label's intrinsic content height.
  @inlinable
  public var lastLineHeightBelowBaselineWithMinimalSpacing: CGFloat {
    return textFrame.lastLineHeightBelowBaselineWithMinimalSpacing
  }

  @inlinable
  public func rects(for range: Range<Index>) -> STUTextRectArray {
    return textFrame.rects(for: range, frameOrigin: origin, displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  public func rectsForAllLinksInTruncatedString() -> STUTextLinkArray {
    return textFrame.rectsForAllLinksInTruncatedString(frameOrigin: origin,
                                                       displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  public var paragraphs: Paragraphs {
    return Paragraphs(textFrame, textFrameOrigin: origin, displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  public var lines: Lines {
    return Lines(textFrame, textFrameOrigin: origin, displayScaleOrZero: displayScaleOrZero)
  }

  public struct Paragraphs : RandomAccessCollection {
    public let paragraphs: STUTextFrame.Paragraphs
    public let textFrameOrigin: CGPoint
    @usableFromInline internal let displayScaleOrZero: CGFloat

    @inlinable
    public var displayScale: CGFloat? { return displayScaleOrZero > 0 ? displayScaleOrZero : nil }

    @inlinable
    internal init(_ paragraphs: STUTextFrame, textFrameOrigin: CGPoint,
                  displayScaleOrZero: CGFloat)
    {
      self.paragraphs = STUTextFrame.Paragraphs(paragraphs)
      self.textFrameOrigin = textFrameOrigin
      self.displayScaleOrZero = displayScaleOrZero
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(paragraphs.textFrame, textFrameOrigin,
                                    displayScaleOrZero: displayScaleOrZero)
    }

    @inlinable
    public var count: Int { return paragraphs.count }

    public typealias Index = STUTextFrame.Paragraphs.Index

    @inlinable
    public var startIndex: Index { return paragraphs.startIndex }

    @inlinable
    public var endIndex: Index { return paragraphs.endIndex }

    @inlinable
    public subscript(index: Index) -> Paragraph {
      return Paragraph(paragraphs[index], textFrameOrigin: textFrameOrigin,
                       displayScaleOrZero: displayScaleOrZero)
    }
  }

  public struct Lines : RandomAccessCollection {
    public let lines: STUTextFrame.Lines
    public let textFrameOrigin: CGPoint
    @usableFromInline internal let displayScaleOrZero: CGFloat

    @inlinable
    public var displayScale: CGFloat? { return displayScaleOrZero > 0 ? displayScaleOrZero : nil }

    @inlinable
    internal init(_ textFrame: STUTextFrame, textFrameOrigin: CGPoint, displayScaleOrZero: CGFloat) {
      self.lines = STUTextFrame.Lines(textFrame)
      self.textFrameOrigin = textFrameOrigin
      self.displayScaleOrZero = displayScaleOrZero
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(lines.textFrame, textFrameOrigin,
                                    displayScaleOrZero: displayScaleOrZero)
    }

    @inlinable
    public var count: Int { return lines.count }

    public typealias Index = STUTextFrame.Paragraphs.Index

    @inlinable
    public var startIndex: Index { return lines.startIndex }

    @inlinable
    public var endIndex: Index { return lines.endIndex }

    @inlinable
    public subscript(index: Index) -> Line {
      return Line(lines[index], textFrameOrigin: textFrameOrigin,
                  displayScaleOrZero: displayScaleOrZero)
    }
  }

  public struct Paragraph {
    public let paragraph: STUTextFrame.Paragraph
    public let textFrameOrigin: CGPoint
    @usableFromInline internal let displayScaleOrZero: CGFloat

    @inlinable
    public var displayScale: CGFloat? { return displayScaleOrZero > 0 ? displayScaleOrZero : nil }

    @inlinable
    public init(_ paragraph: STUTextFrame.Paragraph, textFrameOrigin: CGPoint,
                displayScale: CGFloat?)
    {
      self.paragraph = paragraph
      self.textFrameOrigin = textFrameOrigin
      if let displayScale = displayScale, displayScale > 0 {
        self.displayScaleOrZero = displayScale
      } else {
        self.displayScaleOrZero = 0
      }
    }

    @inlinable
    internal init(_ paragraph: STUTextFrame.Paragraph, textFrameOrigin: CGPoint,
                  displayScaleOrZero: CGFloat)
    {
      self.paragraph = paragraph
      self.textFrameOrigin = textFrameOrigin
      self.displayScaleOrZero = displayScaleOrZero
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(paragraph.textFrame, textFrameOrigin,
                                    displayScaleOrZero: displayScaleOrZero)
    }

    /// The 0-based index of the paragraph in the text frame.
    @inlinable
    public var paragraphIndex: Int { return paragraph.paragraphIndex }

    @inlinable
    public var isFirstParagraph: Bool { return paragraph.isFirstParagraph }

    @inlinable
    public var isLastParagraph: Bool { return paragraph.isLastParagraph }

    @inlinable
    public var lineIndexRange: Range<Int> { return paragraph.lineIndexRange }

    @inlinable
    public var lines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: lineIndexRange)
    }

    /// The text frame range corresponding to the paragraphs's text.
    @inlinable
    public var range: Range<STUTextFrame.Index> { return paragraph.range }

    /// The range in `self.textFrame.truncatedAttributedString` corresponding to the paragraphs's
    /// text.
    @inlinable
    public var rangeInOriginalString: NSRange { return paragraph.rangeInOriginalString }

    /// The paragraph's range in `self.textFrame.originalAttributedString`.
    ///
    /// This range includes any trailing whitespace of the paragraph, including the paragraph
    /// terminator (unless the paragraph is the last paragraph and has no terminator)
    @inlinable
    public var rangeInTruncatedString: NSRange { return paragraph.rangeInTruncatedString }

    /// The UTF-16 code unit length of the paragraph terminator (`"\r"`, `"\n"`, `"\r\n"` or
    /// `"\u{2029}"`). The value is between 0 and 2 (inclusive).
    @inlinable
    public var paragraphTerminatorInOriginalStringUTF16Length: Int  {
      return paragraph.paragraphTerminatorInOriginalStringUTF16Length
    }

    /// The subrange of `self.rangeInOriginalString` that was replaced by a truncation token,
    /// or the empty range with the lower bound `self.rangeInOriginalString.end` if the paragraph
    /// was not truncated.
    ///
    /// - Note: If the range in the original string replaced with a truncation token spans multiple
    ///         paragraphs, only the first paragraph will have a truncation token. The other
    ///         paragraphs will have no text lines.
    ///
    /// - Note: If the last line of the paragraph is not truncated but contains a truncation token
    ///         because the following text from the next paragraph was removed during truncation,
    ///         this range will only contain the last line's trailing whitespace, including
    ///         the paragraph terminator.
    @inlinable
    public var excisedRangeInOriginalString: NSRange {
      return paragraph.excisedRangeInOriginalString
    }

    @inlinable
    public var excisedStringRangeIsContinuedInNextParagraph: Bool {
      return paragraph.excisedStringRangeIsContinuedInNextParagraph
    }

    @inlinable
    public var excisedStringRangeIsContinuationFromLastParagraph: Bool {
      return paragraph.excisedStringRangeIsContinuationFromLastParagraph
    }

    /// The truncation token in the last line of this paragraph,
    /// or `nil` if the paragraph is not truncated.
    ///
    /// - Note: If `self.excisedStringRangeIsContinuationFromLastParagraph`,
    ///         the paragraph has no text lines and no truncation token
    ///         even though `self.excisedRangeInOriginalString` is not empty.
    @inlinable
    public var truncationToken: NSAttributedString? {
      return paragraph.truncationToken
    }

    @inlinable
    public var truncationTokenUTF16Length: Int {
      return paragraph.truncationTokenUTF16Length
    }

    /// The range of the truncation token in the text frame,
    /// or the empty range with the lower bound `self.range.end` if `self.truncationToken` is `nil`.
    @inlinable
    public var rangeOfTruncationToken: Range<STUTextFrame.Index> {
      return paragraph.rangeOfTruncationToken
    }

    /// The range of the truncation token in the text frame's truncated string,
    /// or the empty range with the lower bound `self.rangeInTruncatedString.end`
    /// if `self.truncationToken` is `nil`.
    @inlinable
    public var rangeOfTruncationTokenInTruncatedString: NSRange {
      return paragraph.rangeOfTruncationTokenInTruncatedString
    }

    @inlinable
    public var alignment: STUParagraphAlignment { return paragraph.alignment }

    @inlinable
    public var baseWritingDirection: STUWritingDirection { return paragraph.baseWritingDirection }

    @inlinable
    public var textFlags: STUTextFlags { return paragraph.textFlags }

    @inlinable
    public var isIndented: Bool { return paragraph.isIndented }

    @inlinable
    public var initialLinesIndexRange: Range<Int> { return paragraph.initialLinesIndexRange }

    @inlinable
    public var nonInitialLinesIndexRange: Range<Int> { return paragraph.nonInitialLinesIndexRange }

    @inlinable
    public var initialLines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: initialLinesIndexRange)
    }

    @inlinable
    public var nonInitialLines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: nonInitialLinesIndexRange)
    }

    @inlinable
    public var initialLinesLeftIndent: CGFloat { return paragraph.initialLinesLeftIndent }

    @inlinable
    public var initialLinesRightIndent: CGFloat { return paragraph.initialLinesRightIndent }

    @inlinable
    public var nonInitialLinesLeftIndent: CGFloat { return paragraph.nonInitialLinesLeftIndent }

    @inlinable
    public var nonInitialLinesRightIndent: CGFloat { return paragraph.nonInitialLinesRightIndent }
  }

  public struct Line {
    public let line: STUTextFrame.Line
    public let textFrameOrigin: CGPoint
    @usableFromInline internal let displayScaleOrZero: CGFloat

    @inlinable
    public var displayScale: CGFloat? { return displayScaleOrZero > 0 ? displayScaleOrZero : nil }


    public init(_ line: STUTextFrame.Line, textFrameOrigin: CGPoint, displayScale: CGFloat?) {
      self.line = line
      self.textFrameOrigin = textFrameOrigin
      if let displayScale = displayScale, displayScale > 0 {
        self.displayScaleOrZero = displayScale
      } else {
        self.displayScaleOrZero = 0
      }
    }

    @inlinable
    internal init(_ line: STUTextFrame.Line, textFrameOrigin: CGPoint, displayScaleOrZero: CGFloat) {
      self.line = line
      self.textFrameOrigin = textFrameOrigin
      self.displayScaleOrZero = displayScaleOrZero
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(line.textFrame, textFrameOrigin,
                                    displayScaleOrZero: displayScaleOrZero)
    }

    /// The 0-based index of the line in the text frame.
    @inlinable
    public var lineIndex: Int { return line.lineIndex }

    /// Indicates whether this is the first line in the text frame.
    @inlinable
    public var isFirstLine: Bool { return line.isFirstLine }

    /// Indicates whether this is the last line in the text frame.
    @inlinable
    public var isLastLine: Bool { return line.isLastLine }

    @inlinable
    public var isFirstLineInParagraph: Bool { return line.isFirstLineInParagraph }

    @inlinable
    public var isLastLineInParagraph: Bool { return line.isLastLineInParagraph }

    @inlinable
    public var isInitialLineInParagrah: Bool { return line.isInitialLineInParagraph }


    /// The 0-based index of the line's paragraph in the text frame.
    @inlinable
    public var paragraphIndex: Int { return line.paragraphIndex }

    @inlinable
    public var paragraph: Paragraph {
      return Paragraph(line.paragraph, textFrameOrigin: textFrameOrigin,
                       displayScaleOrZero: displayScaleOrZero)
    }

    @inlinable
    public var range: Range<STUTextFrame.Index> { return line.range }

    @inlinable
    public var rangeInTruncatedString: NSRange { return line.rangeInTruncatedString }

    @inlinable
    public var trailingWhitespaceInTruncatedStringUTF16Length: Int {
      return line.trailingWhitespaceInTruncatedStringUTF16Length
    }


    @inlinable
    public var rangeInOriginalString: NSRange { return line.rangeInOriginalString }

    @inlinable
    public var excisedRangeInOriginalString: NSRange? { return line.excisedRangeInOriginalString }

    @inlinable
    public var isFollowedByTerminatorInOriginalString: Bool {
      return line.isFollowedByTerminatorInOriginalString
    }

    @inlinable
    public var baselineOrigin: CGPoint {
      return line.baselineOrigin(textFrameOrigin: textFrameOrigin,
                                 displayScaleOrZero: displayScaleOrZero)
    }

    @inlinable
    public var width: CGFloat { return line.width }

    /// The line's ascent after font substitution.
    @inlinable
    public var ascent: CGFloat { return line.ascent }

    /// The line's descent after font substitution.
    @inlinable
    public var descent: CGFloat { return line.descent }

    /// The line's leading after font substitution.
    @inlinable
    public var leading: CGFloat { return line.leading }

    @inlinable
    public var typographicBounds: CGRect {
      return line.typographicBounds(textFrameOrigin: textFrameOrigin,
                                    displayScaleOrZero: displayScaleOrZero)
    }

    /// Indicates whether the line contains a truncation token.
    /// - Note: A line may have a truncation token even though the line itself wasn't truncated.
    ///         In that case the truncation token indicates that one or more following lines were
    ///         removed.
    @inlinable
    public var hasTruncationToken: Bool { return line.hasTruncationToken }

    @inlinable
    public var isTruncatedAsRightToLeftLine: Bool {
      return line.isTruncatedAsRightToLeftLine
    }

    /// Indicates whether a hyphen was inserted during line breaking.
    @inlinable
    public var hasInsertedHyphen: Bool { return line.hasInsertedHyphen }


    @inlinable
    public var paragraphBaseWritingDirection: STUWritingDirection {
      return line.paragraphBaseWritingDirection
    }

    @inlinable
    public var textFlags: STUTextFlags  { return line.textFlags }

    @inlinable
    public var nonTokenTextFlags: STUTextFlags { return line.nonTokenTextFlags }

    @inlinable
    public var tokenTextFlags: STUTextFlags { return line.tokenTextFlags }

    /// The typographic width of the part of the line left of the inserted token. Equals `width` if
    /// there is no token.

    @inlinable
    public var leftPartWidth: CGFloat { return line.leftPartWidth }

    /// The typographic width of the inserted truncation token or hyphen.
    @inlinable
    public var tokenWidth: CGFloat { return line.tokenWidth }
  }

}
