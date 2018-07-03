// Copyright 2017–2018 Stephan Tolksdorf

@_exported import STULabel

import STULabel.Unsafe

// TODO: Wrap text frame, origin and display scale in a STUPlacedTextFrame type.
// TODO: Make sure all members are accessible from release code (despite Swift inlining bugs).

public extension STUTextFrame.Index {
  /// The UTF-16 code unit index in the truncated string.
  /// This value must be less than or equal to `UInt32.max`.
  @_transparent
  public var utf16IndexInTruncatedString: Int {
    get { return Int(__indexInTruncatedString); }
    set { __indexInTruncatedString = UInt32(newValue) }
  }

  /// The (0-based) index of the line in the text frame corresponding to the character identified
  /// by `utf16IndexInTruncatedString`.
  /// This value must be less than or equal to `UInt32.max`.
  @_transparent
  public var lineIndex: Int {
    get { return Int(__lineIndex) }
    set { __lineIndex = UInt32(newValue) }
  }

  /// Manually constructs a STUTextFrame.Index.
  ///
  /// - Note: STUTextFrame methods check the validity of indices passed as arguments.
  ///
  /// - Parameters:
  ///   - utf16IndexInTruncatedString:
  ///     The UTF-16 code unit index in the truncated string.
  ///   - isIndexOfInsertedHyphen:
  ///     Indicates whether the index is for the hyphen that was inserted inserted immediately after
  ///     `utf16IndexInTruncatedString` during line breaking.
  ///   - lineIndex:
  ///     The (0-based) index of the line in the text frame corresponding to the
  ///     character identified by `utf16IndexInTruncatedString`.
  /// - Precondition:
  ///   - `utf16IndexInTruncatedString <= UInt32.max`
  ///   - `lineIndex <= UInt32.max`
  @_transparent
  public init(utf16IndexInTruncatedString: Int, isIndexOfInsertedHyphen: Bool = false,
              lineIndex: Int)
  {
    self = .init(isIndexOfInsertedHyphen: isIndexOfInsertedHyphen,
                 __indexInTruncatedString: UInt32(utf16IndexInTruncatedString),
                 __lineIndex: UInt32(lineIndex))
  }
}

extension STUTextFrame.Index : Comparable {
  @_transparent
  public static func ==(lhs: STUTextFrame.Index, rhs: STUTextFrame.Index) -> Bool {
    return __STUTextFrameIndexEqualToIndex(lhs, rhs)
  }

  @_transparent
  public static func <(lhs: STUTextFrame.Index, rhs: STUTextFrame.Index) -> Bool {
    return __STUTextFrameIndexLessThanIndex(lhs, rhs)
  }
}

public extension Range where Bound == STUTextFrame.Index {
  @_transparent
  public init(_ range: __STUTextFrameRange) {
    self = range.start..<range.end
  }

  @_transparent
  public var rangeInTruncatedString: NSRange {
    return __STUTextFrameRange(self).rangeInTruncatedString
  }
}

public extension __STUTextFrameRange {
  @_transparent
  public init(_ range: Range<STUTextFrame.Index>) {
    self.init(start: range.lowerBound, end: range.upperBound)
  }
}

public extension STUTextRange {
  @_transparent
  public init(_ range: Range<STUTextFrame.Index>) {
    self.init(range: range.rangeInTruncatedString, type: .rangeInTruncatedString)
  }
}

#if swift(>=4.1.5)
#else // Swift bug workaround.
extension STUTextRangeType : Swift.RawRepresentable {}
#endif

public extension STUTextFrame.GraphemeClusterRange {
  @_transparent
  public var range: Range<STUTextFrame.Index> {
    return Range<STUTextFrame.Index>(self.__range)
  }
}

public extension STUTextFrame {

  @_transparent
  public var startIndex: Index { return Index() }

  @_transparent
  public var endIndex: Index {
    return withExtendedLifetime(self) { __STUTextFrameDataGetEndIndex(self.__data) }
  }

  @_transparent
  public func range(forRangeInOriginalString range: NSRange) -> Range<Index> {
    return Range<Index>(__range(forRangeInOriginalString: range))
  }

  @_transparent
  public func range(forRangeInTruncatedString range: NSRange) -> Range<Index> {
    return Range<Index>(__range(forRangeInTruncatedString: range))
  }

  @_transparent
  public func range(for textRange: STUTextRange) -> Range<Index> {
    return textRange.type == .rangeInOriginalString
         ? range(forRangeInOriginalString: textRange.range)
         : range(forRangeInTruncatedString: textRange.range)
  }

  @_transparent
  var rangeInOriginalStringIsFullString: Bool {
    return withExtendedLifetime(self) { self.__data.pointee.rangeInOriginalStringIsFullString }
  }

  @_transparent
  public func rangeInOriginalString(for range: Range<Index>) -> NSRange {
    return __rangeInOriginalString(for: __STUTextFrameRange(range))
  }

  @_transparent
  public func rangeInOriginalStringAndTruncationTokenIndex(for index: Index)
           -> (NSRange, (truncationToken: NSAttributedString, indexInToken: Int)?)
  {
    var range = NSRange()
    var token: NSAttributedString?
    var indexInToken: UInt = 0
    __getRangeInOriginalString(&range, truncationToken: &token, indexInToken: &indexInToken,
                               for: index)
    if let token = token {
      return (range, (token, Int(bitPattern: indexInToken)))
    } else {
      return (range, nil)
    }
  }

  @_transparent
  public var rangeOfLastTruncationToken: Range<Index> {
    return Range<Index>(__rangeOfLastTruncationToken);
  }

  @_transparent
  public var truncatedStringUTF16Length: Int {
    return withExtendedLifetime(self) { Int(self.__data.pointee.truncatedStringUTF16Length) }
  }

  @_transparent
  public func rects(for range: Range<Index>, frameOrigin: CGPoint, displayScale: CGFloat)
           -> STUTextRectArray
  {
    return __rects( __STUTextFrameRange(range), frameOrigin: frameOrigin,
                   displayScale: displayScale)
  }

  @_transparent
  public func imageBounds(for range: Range<Index>? = nil,
                          frameOrigin: CGPoint,
                          displayScale: CGFloat,
                          options: STUTextFrame.DrawingOptions? = nil,
                          cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
           -> CGRect
  {
    let range = range ?? self.indices
    return  __imageBounds( __STUTextFrameRange(range), frameOrigin: frameOrigin,
                          displayScale: displayScale, options, cancellationFlag)
  }

  @_transparent
  public var indices: Range<Index> { return startIndex..<endIndex }

  @_transparent
  public func draw(range: Range<Index>? = nil,
                   at frameOrigin: CGPoint = .zero,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    let range = range ?? self.indices
    guard let context = UIGraphicsGetCurrentContext() else { return }
    __draw(range: __STUTextFrameRange(range),
           at: frameOrigin, in: context, isVectorContext: false, contextBaseCTM_d: 0,
           options: options, cancellationFlag: cancellationFlag)
  }

  @_transparent
  public func draw(range: Range<Index>? = nil,
                   at frameOrigin: CGPoint = .zero,
                   in context: CGContext, isVectorContext: Bool, contextBaseCTM_d: CGFloat,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    let range = range ?? self.indices
    __draw(range: __STUTextFrameRange(range),
           at: frameOrigin,
           in: context, isVectorContext: isVectorContext, contextBaseCTM_d: contextBaseCTM_d,
           options: options, cancellationFlag: cancellationFlag)
  }

  @_transparent
  public var layoutBounds: CGRect {
    return withExtendedLifetime(self) {
             return self.__data.pointee.layoutBounds
           }
  }

  @_transparent
  public var consistentAlignment: ConsistentAlignment {
    return withExtendedLifetime(self) { self.__data.pointee.consistentAlignment }
  }

  @_transparent
  public var flags: Flags {
    return withExtendedLifetime(self) { self.__data.pointee.flags }
  }

  @_transparent
  public var size: CGSize {
    return withExtendedLifetime(self) { self.__data.pointee.size }
  }

  @_transparent
  public var scaleFactor: CGFloat {
    return withExtendedLifetime(self) { self.__data.pointee.scaleFactor }
  }

  @_transparent
  public var paragraphs: Paragraphs { return Paragraphs(self) }

  @_transparent
  public var lines: Lines { return Lines(self) }

  public struct Paragraphs : RandomAccessCollection {
    @_versioned internal let textFrame: STUTextFrame
    @_versioned internal let textFrameParagraphs: UnsafePointer<__STUTextFrameParagraph>
    public let count: Int

    @_versioned @_transparent
    internal init(_ textFrame: STUTextFrame) {
      let (paragraphs, count): (UnsafePointer<__STUTextFrameParagraph>, Int) =
        withExtendedLifetime(textFrame) {
          let data = textFrame.__data
          return (__STUTextFrameDataGetParagraphs(data), Int(data.pointee.paragraphCount))
        }
      self.textFrame = textFrame
      self.textFrameParagraphs = paragraphs
      self.count = count
    }

    public typealias Index = Int

    @_transparent
    public var startIndex: Int { return 0 }

    @_transparent
    public var endIndex: Int { return count }

    public subscript(index: Index) -> Paragraph {  @_transparent get {
      precondition(0 <= index && index < count, "Paragraph index out of bounds")
      return Paragraph(textFrame, textFrameParagraphs.advanced(by: index))
    } }
  }

  public struct Lines : RandomAccessCollection {
    @_versioned internal let textFrame: STUTextFrame
    @_versioned internal let textFrameLines: UnsafePointer<__STUTextFrameLine>
    public let count: Int
    @_versioned internal let scaleFactor: CGFloat

    @_versioned @_transparent
    internal init(_ textFrame: STUTextFrame) {
      let (lines, count, scaleFactor): (UnsafePointer<__STUTextFrameLine>, Int, CGFloat) =
        withExtendedLifetime(textFrame) {
          let data = textFrame.__data
          return (__STUTextFrameDataGetLines(data),
                  Int(data.pointee.lineCount),
                  data.pointee.scaleFactor)
      }
      self.textFrame = textFrame
      self.textFrameLines = lines
      self.count = count
      self.scaleFactor = scaleFactor
    }

    public typealias Index = Int

    @_transparent
    public var startIndex: Int { return 0 }

    @_transparent
    public var endIndex: Int { return count }

    public subscript(index: Index) -> Line {  @_transparent get {
      precondition(0 <= index && index < count, "Line index out of bounds")
      return Line(textFrame, textFrameLines.advanced(by: index), scaleFactor: scaleFactor)
    } }
  }

  struct Paragraph {
    public let textFrame: STUTextFrame

    @_versioned
    internal let para: UnsafePointer<__STUTextFrameParagraph>

    @_versioned @_transparent
    internal init(_ textFrame: STUTextFrame,
                  _ para: UnsafePointer<__STUTextFrameParagraph>)
    {
      self.textFrame = textFrame
      self.para = para
    }
    @_versioned @_transparent
    internal init(_ textFrame: STUTextFrame, _ index: Int32) {
      let para = withExtendedLifetime(textFrame) {
        return __STUTextFrameDataGetParagraphs(textFrame.__data).advanced(by: Int(index))
      }
      self.init(textFrame, para)
    }

    @_transparent
    public var paragraphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(para.pointee.paragraphIndex) }
    }

    @_transparent
    public var isFirstParagraph: Bool {
      return withExtendedLifetime(textFrame) { para.pointee.isFirstParagraph }
    }

    @_transparent
    public var isLastParagraph: Bool {
      return withExtendedLifetime(textFrame) { para.pointee.isLastParagraph }
    }

    @_transparent
    public var rangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) { para.pointee.rangeInOriginalString.nsRange }
    }

    @_transparent
    public var paragraphTerminatorInOriginalStringUTF16Length: Int  {
      return withExtendedLifetime(textFrame) {
               return Int(para.pointee.paragraphTerminatorInOriginalStringUTF16Length)
             }
    }

    @_transparent
    public var excisedRangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) {
        return para.pointee.excisedRangeInOriginalString.nsRange
      }
    }

    @_transparent
    public var excisedStringRangeContinuesInNextParagraph: Bool {
      return withExtendedLifetime(textFrame) {
        return para.pointee.excisedStringRangeContinuesInNextParagraph
      }
    }

    @_transparent
    public var rangeInTruncatedString: NSRange {
      return withExtendedLifetime(textFrame) { para.pointee.rangeInTruncatedString.nsRange }
    }

    @_transparent
    public var truncationTokenUTF16Length: Int {
      return withExtendedLifetime(textFrame) { Int(para.pointee.truncationTokenUTF16Length) }
    }

    @_transparent
    public var truncationToken: NSAttributedString? {
      return withExtendedLifetime(textFrame) { para.pointee.truncationToken?.takeUnretainedValue() }
    }

    @_transparent
    public var baseWritingDirection: STUWritingDirection {
      return withExtendedLifetime(textFrame) { para.pointee.baseWritingDirection }
    }

    @_transparent
    public var textFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { para.pointee.textFlags }
    }

    @_transparent
    public var alignment: STUParagraphAlignment  {
      return withExtendedLifetime(textFrame) { para.pointee.alignment }
    }

    @_transparent
    public var lines: Lines.SubSequence {
      let bounds: Range<Int> = withExtendedLifetime(textFrame) {
        let startIndex = para.pointee.isFirstParagraph ? 0
                       : Int(para.advanced(by: -1).pointee.endLineIndex)
        return startIndex..<Int(para.pointee.endLineIndex)
      }
      return Lines.SubSequence(base: textFrame.lines, bounds: bounds)
    }
  }

  public struct Line {
    public let textFrame: STUTextFrame
    @_versioned
    internal let line: UnsafePointer<__STUTextFrameLine>
    @_versioned
    internal let scaleFactor: CGFloat

    @_versioned @_transparent
    internal init(_ textFrame: STUTextFrame, _ line: UnsafePointer<__STUTextFrameLine>,
                  scaleFactor: CGFloat)
    {
      self.textFrame = textFrame
      self.line = line
      self.scaleFactor = scaleFactor
    }

    /// The 0-based index of the line in the text frame.
    @_transparent
    public var lineIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee.lineIndex) }
    }

    @_transparent
    public var paragraphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee.paragraphIndex) }
    }

    /// Indicates whether this is the first line in the text frame.
    @_transparent
    public var isFirstLine: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.lineIndex == 0 }
    }

    /// Indicates whether this is the last line in the text frame.
    @_transparent
    public var isLastLine: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isLastLine }
    }

    @_transparent
    public var isFirstLineInParagraph: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isFirstLineInParagraph }
    }

    @_transparent
    public var isFollowedByTerminatorInOriginalString: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isFollowedByTerminatorInOriginalString }
    }

    @_transparent
    public var range: Range<STUTextFrame.Index> {
      return withExtendedLifetime(textFrame) { Range(__STUTextFrameLineGetRange(line)) }
    }

    @_transparent
    public var rangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) { line.pointee.rangeInOriginalString.nsRange }
    }

    @_transparent
    public var excisedRangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) {
        return NSRange(Range(Paragraph(textFrame, line.pointee.paragraphIndex)
                             .excisedRangeInOriginalString)!
                       .clamped(to: Range(line.pointee.rangeInOriginalString.nsRange)!))
      }
    }

    @_transparent
    public var trailingWhitespaceInTruncatedStringUTF16Length: Int {
      return withExtendedLifetime(textFrame) {
        return Int(UInt32(line.pointee.trailingWhitespaceInTruncatedStringUTF16Length))
      }
    }

    @_transparent
    public var rangeInTruncatedString: NSRange {
      return withExtendedLifetime(textFrame) { line.pointee.rangeInTruncatedString.nsRange }
    }

    /// Does not take into account display scale rounding.
    @_transparent
    public var baselineOriginInTextFrame: CGPoint {
      return withExtendedLifetime(textFrame) {
               CGPoint(x: scaleFactor*CGFloat(line.pointee.originX),
                       y: scaleFactor*CGFloat(line.pointee.originY))
             }
    }

    @_transparent
    public var width: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.width) }
    }

    /// Indicates whether the line contains a truncation token.
    /// @note
    /// A line may have a truncation token even though the line itself wasn't truncated.
    /// In that case the truncation token indicates that one or more following line(s) were removed.
    @_transparent
    public var hasTruncationToken: Bool {
      return withExtendedLifetime(textFrame) { line.pointee.hasTruncationToken }
    }

    /// Indicates whether a hyphen was inserted during line breaking.
    // @_inlineable // swift inlining bug
    public var hasInsertedHyphen: Bool {
      return withExtendedLifetime(textFrame) { line.pointee.hasInsertedHyphen }
    }

    /// The line's ascent after font substitution.
    @_transparent
    public var ascent: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.ascent) }
    }

    /// The line's descent after font substitution.
    @_transparent
    public var descent: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.descent) }
    }

    /// The line's leading after font substitution.
    @_transparent
    public var leading: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.leading) }
    }

    @_transparent
    public var paragraphBaseWritingDirection: STUWritingDirection  {
      return withExtendedLifetime(textFrame) { line.pointee.paragraphBaseWritingDirection }
    }

    @_transparent
    public var textFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.textFlags }
    }

    @_transparent
    public var nonTokenTextFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.nonTokenTextFlags }
    }

    @_transparent
    public var tokenTextFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.tokenTextFlags }
    }

    /// The typographic width of the part of the line left of the inserted token. Equals `width` if
    /// there is no token.

    @_transparent
    public var leftPartWidth: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.leftPartWidth) }
    }

    /// The typographic width of the inserted truncation token or hyphen.
    @_transparent
    public var tokenWidth: CGFloat {
      return withExtendedLifetime(textFrame) { scaleFactor*CGFloat(line.pointee.tokenWidth) }
    }

    @_transparent
    internal var _hyphenRunIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee._hyphenRunIndex) }
    }

    @_transparent
    internal var _hyphenGlyphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee._hyphenGlyphIndex) }
    }

    @_transparent
    internal var _hyphenXOffset: Float32 {
      return withExtendedLifetime(textFrame) { Float32(line.pointee._hyphenXOffset) }
    }

    @_transparent
    internal var _ctLine: CTLine? {
      return withExtendedLifetime(textFrame) { line.pointee._ctLine?.takeUnretainedValue() }
    }

    @_transparent
    internal var _tokenCTLine: CTLine? {
      return withExtendedLifetime(textFrame) { line.pointee._tokenCTLine?.takeUnretainedValue() }
    }

    @_transparent
    internal var _leftPartEnd: STURunGlyphIndex {
      return withExtendedLifetime(textFrame) { line.pointee._leftPartEnd }
    }

    @_transparent
    internal var _rightPartStart: STURunGlyphIndex {
      return withExtendedLifetime(textFrame) { line.pointee._rightPartStart }
    }
  }
}

