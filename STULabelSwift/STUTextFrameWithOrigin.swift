// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel
@_exported import STULabel.SwiftExtensions

public extension STULabel {
  @inlinable
  public var textFrame: STUTextFrameWithOrigin {
    return STUTextFrameWithOrigin(__STULabelGetTextFrameWithOrigin(self))
  }
}

public extension STULabelLayer {
  @inlinable
  public var textFrame: STUTextFrameWithOrigin {
    return STUTextFrameWithOrigin(__STULabelLayerGetTextFrameWithOrigin(self))
  }
}

public struct STUTextFrameWithOrigin {
  public let textFrame: STUTextFrame
  public let origin: CGPoint

  @inlinable
  public init(_ shapedString: STUShapedString, stringRange: NSRange? = nil,
              rect: CGRect, displayScale: CGFloat?, options: STUTextFrameOptions? = nil)
  {
    self.textFrame = STUTextFrame(shapedString, stringRange: stringRange,
                                  size: rect.size, displayScale: displayScale, options: options)
    self.origin = rect.origin
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
  }

  @inlinable
  public init(_ textFrame: STUTextFrame, _ origin: CGPoint) {
    self.textFrame = textFrame
    self.origin = origin
  }

  @inlinable
  internal init(_ other: __STUTextFrameWithOrigin) {
    self.init(other.textFrame.takeUnretainedValue(), other.origin)
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


  @inlinable
  public var size: CGSize { return textFrame.size }

  @inlinable
  public var rect: CGRect { return CGRect(origin: origin, size: size) }

  /// The displayScale that was specified when the `STUTextFrame` instance was initialized,
  /// or `nil` if the specified value was outside the valid range.
  @inlinable
  public var displayScale: CGFloat? { return textFrame.displayScale }

  // TODO
  // public var layoutInfo: STUTextFrame.LayoutInfo { return textFrame.layoutInfo }

  /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  public var firstLineHeight: CGFloat { return textFrame.firstLineHeight }

  /// The value that the text layout algorithm would calculate for the ideal distance between the
  /// baseline of the last text line in the text frame and the baseline of a (hypothetical)
  /// adjacent text line that has the same typographic metrics and is in the same paragraph.
  public var lastLineHeight: CGFloat { return textFrame.lastLineHeight }

  /// The `self.rangeInOriginalString` substring of `self.originalAttributedString`, truncated in the
  /// same way it is truncated when the text is drawn, i.e. with truncation tokens replacing text that
  /// doesn't fit the frame size.
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
                                            frameOrigin: origin)
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

  @inlinable
  public func rects(for range: Range<Index>) -> STUTextRectArray {
    return textFrame.rects(for: range, frameOrigin: origin)
  }

  @inlinable
  public func rectsForAllLinksInTruncatedString() -> STUTextLinkArray {
    return textFrame.rectsForAllLinksInTruncatedString(frameOrigin: origin)
  }

  public typealias DrawingOptions = STUTextFrame.DrawingOptions

  @inlinable
  public func imageBounds(for range: Range<Index>? = nil,
                          options: DrawingOptions? = nil,
                          cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
            -> CGRect
  {
    return textFrame.imageBounds(for: range, frameOrigin: origin, options: options,
                                 cancellationFlag: cancellationFlag)
  }

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
  public var paragraphs: Paragraphs { return Paragraphs(textFrame, textFrameOrigin: origin) }

  @inlinable
  public var lines: Lines { return Lines(textFrame, textFrameOrigin: origin) }

  public struct Paragraphs : RandomAccessCollection {
    public let paragraphs: STUTextFrame.Paragraphs
    public let textFrameOrigin: CGPoint

    @inlinable
    public init(_ paragraphs: STUTextFrame, textFrameOrigin: CGPoint) {
      self.paragraphs = STUTextFrame.Paragraphs(paragraphs)
      self.textFrameOrigin = textFrameOrigin
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(paragraphs.textFrame, textFrameOrigin)
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
      return Paragraph(paragraphs[index], textFrameOrigin: textFrameOrigin)
    }
  }

  public struct Lines : RandomAccessCollection {
    public let lines: STUTextFrame.Lines
    public let textFrameOrigin: CGPoint

    @inlinable
    public init(_ textFrame: STUTextFrame, textFrameOrigin: CGPoint) {
      self.lines = STUTextFrame.Lines(textFrame)
      self.textFrameOrigin = textFrameOrigin
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(lines.textFrame, textFrameOrigin)
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
      return Line(lines[index], textFrameOrigin: textFrameOrigin)
    }
  }

  public struct Paragraph {
    public let paragraph: STUTextFrame.Paragraph
    public let textFrameOrigin: CGPoint

    @inlinable
    public init(_ paragraph: STUTextFrame.Paragraph, textFrameOrigin: CGPoint) {
      self.paragraph = paragraph
      self.textFrameOrigin = textFrameOrigin
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(paragraph.textFrame, textFrameOrigin)
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

    @inlinable
    public init(_ line: STUTextFrame.Line, textFrameOrigin: CGPoint) {
      self.line = line
      self.textFrameOrigin = textFrameOrigin
    }

    @inlinable
    public var textFrame: STUTextFrameWithOrigin  {
      return STUTextFrameWithOrigin(line.textFrame, textFrameOrigin)
    }

    /// The 0-based index of the line in the text frame.
    @inlinable
    public var lineIndex: Int { return line.lineIndex }

    /// Indicates whether this is the first line in the text frame.
    @inlinable
    public var isFirstLine: Bool { return line.isLastLine }

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
      return Paragraph(line.paragraph, textFrameOrigin: textFrameOrigin)
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

    /// Does not take into account display scale rounding.
    @inlinable
    public var baselineOrigin: CGPoint {
      let point = line.baselineOriginInTextFrame
      return CGPoint(x: textFrameOrigin.x + point.x,
                     y: textFrameOrigin.y + point.y)
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
      let bounds = line.typographicBoundsInTextFrame
      return CGRect(origin: CGPoint(x: textFrameOrigin.x + bounds.origin.x,
                                    y: textFrameOrigin.y + bounds.origin.y),
                    size: bounds.size)
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
