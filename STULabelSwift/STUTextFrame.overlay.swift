// Copyright 2017–2018 Stephan Tolksdorf

@_exported import STULabel
@_exported import STULabel.SwiftExtensions

import STULabel.Unsafe

extension STUTextFrame {

  @inlinable
  public convenience init(_ shapedString: STUShapedString, stringRange: NSRange? = nil,
                          size: CGSize, displayScale: CGFloat?,
                          options: STUTextFrameOptions? = nil)
  {
    self.init(shapedString, stringRange: stringRange ?? NSRange(0..<shapedString.length),
              size: size, displayScaleOrZero: displayScale ?? 0, options: options,
              cancellationFlag: nil)!
  }

  @inlinable
  public convenience init?(_ shapedString: STUShapedString, stringRange: NSRange? = nil,
                           size: CGSize, displayScale: CGFloat?,
                           options: STUTextFrameOptions? = nil,
                           cancellationFlag: UnsafePointer<STUCancellationFlag>)
  {
    self.init(shapedString, stringRange: stringRange ?? NSRange(0..<shapedString.length),
              size: size, displayScaleOrZero: displayScale ?? 0, options: options,
              cancellationFlag: cancellationFlag)
  }

  /// The size that was specified when the `STUTextFrame` instance was initialized. This size can
  /// be much larger than the layout bounds of the text, particularly if the text frame was created
  /// by a label view.
  @inlinable
  public var size: CGSize {
    return withExtendedLifetime(self) { self.__data.pointee.size }
  }

  @usableFromInline
  internal var displayScaleOrZero: CGFloat {
    return withExtendedLifetime(self) { self.__data.pointee.displayScaleOrZero }
  }

  /// The displayScale that was specified when the `STUTextFrame` instance was initialized,
  /// or `nil` if the specified value was outside the valid range.
  @inlinable
  public var displayScale: CGFloat? {
    let value = displayScaleOrZero
    return value > 0 ? value : nil
  }

  @inlinable
  public var startIndex: Index { return Index() }

  @inlinable
  public var endIndex: Index {
    return withExtendedLifetime(self) { __STUTextFrameDataGetEndIndex(self.__data) }
  }

  @inlinable
  public var indices: Range<Index> { return startIndex..<endIndex }

  @inlinable
  public func range(forRangeInOriginalString range: NSRange) -> Range<Index> {
    return Range<Index>(__range(forRangeInOriginalString: range))
  }

  @inlinable
  public func range(forRangeInTruncatedString range: NSRange) -> Range<Index> {
    return Range<Index>(__range(forRangeInTruncatedString: range))
  }

  @inlinable
  public func range(for textRange: STUTextRange) -> Range<Index> {
    return textRange.type == .rangeInOriginalString
         ? range(forRangeInOriginalString: textRange.range)
         : range(forRangeInTruncatedString: textRange.range)
  }

  @inlinable
  public func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool,
                                     frameOrigin: CGPoint, displayScale: CGFloat?)
    -> GraphemeClusterRange
  {
    return rangeOfGraphemeCluster(closestTo: point,
                                  ignoringTrailingWhitespace: ignoringTrailingWhitespace,
                                  frameOrigin: frameOrigin,
                                  displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to the other `rangeOfGraphemeCluster` overload
  /// with `self.displayScale` as the `displayScale` argument.
  @inlinable
  public func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool,
                                     frameOrigin: CGPoint)
    -> GraphemeClusterRange
  {
    return rangeOfGraphemeCluster(closestTo: point,
                                  ignoringTrailingWhitespace: ignoringTrailingWhitespace,
                                  frameOrigin: frameOrigin,
                                  displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  internal func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool,
                                       frameOrigin: CGPoint, displayScaleOrZero: CGFloat)
    -> GraphemeClusterRange
  {
    return __rangeOfGraphemeCluster(closestTo: point,
                                    ignoringTrailingWhitespace: ignoringTrailingWhitespace,
                                    frameOrigin: frameOrigin,
                                    displayScale: displayScaleOrZero)
  }

  @inlinable
  public var rangeInOriginalStringIsFullString: Bool {
    return withExtendedLifetime(self) { self.__data.pointee.rangeInOriginalStringIsFullString }
  }

  @inlinable
  public func rangeInOriginalString(for range: Range<Index>) -> NSRange {
    return __rangeInOriginalString(for: __STUTextFrameRange(range))
  }

  @inlinable
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

  @inlinable
  public var rangeOfLastTruncationToken: Range<Index> {
    return Range<Index>(__rangeOfLastTruncationToken);
  }

  @inlinable
  public var truncatedStringUTF16Length: Int {
    return withExtendedLifetime(self) { Int(self.__data.pointee.truncatedStringUTF16Length) }
  }

  @inlinable
  public func draw(range: Range<Index>? = nil,
                   at frameOrigin: CGPoint = .zero,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    __draw(range: __STUTextFrameRange(range ?? self.indices),
           at: frameOrigin, in: UIGraphicsGetCurrentContext(), contextBaseCTM_d: 0,
           pixelAlignBaselines: true, options: options, cancellationFlag: cancellationFlag)
  }

  @inlinable
  public func draw(range: Range<Index>? = nil,
                   at frameOrigin: CGPoint = .zero,
                   in context: CGContext,
                   contextBaseCTM_d: CGFloat,
                   pixelAlignBaselines: Bool,
                   options: DrawingOptions? = nil,
                   cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
  {
    __draw(range: __STUTextFrameRange(range ?? self.indices),
           at: frameOrigin, in: context, contextBaseCTM_d: contextBaseCTM_d,
           pixelAlignBaselines: pixelAlignBaselines, options: options,
           cancellationFlag: cancellationFlag)
  }

  @inlinable
  public func imageBounds(for range: Range<Index>? = nil,
                          frameOrigin: CGPoint,
                          displayScale: CGFloat?,
                          options: STUTextFrame.DrawingOptions? = nil,
                          cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
    -> CGRect
  {
    return  imageBounds(for: range, frameOrigin: frameOrigin, displayScaleOrZero: displayScale ?? 0,
                        options: options, cancellationFlag: cancellationFlag)
  }

  /// Equivalent to the other `imageBounds` overload
  /// with `self.displayScale` as the `displayScale` argument.
  @inlinable
  public func imageBounds(for range: Range<Index>? = nil,
                          frameOrigin: CGPoint,
                          options: STUTextFrame.DrawingOptions? = nil,
                          cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
    -> CGRect
  {
   return  imageBounds(for: range, frameOrigin: frameOrigin, displayScaleOrZero: displayScaleOrZero,
                       options: options, cancellationFlag: cancellationFlag)
  }

  @inlinable
  internal func imageBounds(for range: Range<Index>? = nil,
                            frameOrigin: CGPoint,
                            displayScaleOrZero: CGFloat,
                            options: STUTextFrame.DrawingOptions? = nil,
                            cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)
    -> CGRect
  {
    return  __imageBounds(__STUTextFrameRange(range ?? self.indices), frameOrigin: frameOrigin,
                          displayScale: displayScaleOrZero, options, cancellationFlag)
  }


  /// - Note: In the returned layout info only `minX`, `maxX`, `firstBaseline` and
  ///         `lastBaseline` depend on the specified `frameOrigin`.
  ///         Only `firstBaseline` and `lastBaseline` depend on the specified `displayScale`.
  @inlinable
  public func layoutInfo(frameOrigin: CGPoint, displayScale: CGFloat?) -> LayoutInfo {
    return layoutInfo(frameOrigin: frameOrigin, displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to the other `layoutInfo` overload with `self.displayScale` as the
  /// `displayScale argument.
  @inlinable
  public func layoutInfo(frameOrigin: CGPoint) -> LayoutInfo {
    return layoutInfo(frameOrigin: frameOrigin, displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  internal func layoutInfo(frameOrigin: CGPoint, displayScaleOrZero: CGFloat) -> LayoutInfo {
    return __layoutInfo(frameOrigin: frameOrigin, displayScale: displayScaleOrZero)
  }

  @inlinable
  public var flags: Flags {
    return withExtendedLifetime(self) { self.__data.pointee.flags }
  }

  @inlinable
  public var layoutMode: STUTextLayoutMode {
    return withExtendedLifetime(self) { self.__data.pointee.layoutMode }
  }

  @inlinable
  public var consistentAlignment: ConsistentAlignment {
    return withExtendedLifetime(self) { self.__data.pointee.consistentAlignment }
  }

  @inlinable
  public var textScaleFactor: CGFloat {
    return withExtendedLifetime(self) { self.__data.pointee.textScaleFactor }
  }

  /// Returns the union of the layout bounds of all text lines, including all vertical line spacing
  /// and all horizontal paragraph insets.
  ///
  /// - Note: A non-null displayScale is used for calculating the pixel-accurate position of the
  ///         first and last baseline, but *the returned rectangle is not rounded.*
  @inlinable
  public func layoutBounds(frameOrigin: CGPoint, displayScale: CGFloat?) -> CGRect {
    return layoutBounds(frameOrigin: frameOrigin, displayScaleOrZero: displayScale ?? 0)
  }

  /// Returns the union of the layout bounds of all text lines, including all vertical line spacing
  /// and all horizontal paragraph insets.
  ///
  /// Equivalent to the other `layoutBounds` overload
  /// with `self.displayScale` as the `displayScale` argument.
  @inlinable
  public func layoutBounds(frameOrigin: CGPoint) -> CGRect {
    return layoutBounds(frameOrigin: frameOrigin, displayScaleOrZero: displayScaleOrZero)
  }

  /// The union of the layout bounds of all text lines, including all vertical line spacing
  /// and all horizontal paragraph insets, in the coordinate system of the text frame,
  /// assuming a display scale equal to `self.displayScale`.
  ///
  /// Equivalent to `layoutBounds(frameOrigin: .zero, displayScale: self.displayScale)`.
  @inlinable
  public var layoutBounds: CGRect {
    return layoutBounds(frameOrigin: .zero, displayScaleOrZero: 0)
  }

  @inlinable
  internal func layoutBounds(frameOrigin: CGPoint, displayScaleOrZero: CGFloat) -> CGRect {
    let data = self.__data
    var firstBaseline = withExtendedLifetime(self) { data.pointee.firstBaseline }
    var lastBaseline = withExtendedLifetime(self) { data.pointee.lastBaseline }
    firstBaseline += Float64(frameOrigin.y)
    lastBaseline  += Float64(frameOrigin.y)
    if displayScaleOrZero > 0
      && (displayScaleOrZero != self.displayScaleOrZero || frameOrigin.y != 0)
    {
      let scale = Float64(displayScaleOrZero)
      firstBaseline = ceilToScale(firstBaseline, scale)
      lastBaseline = ceilToScale(lastBaseline, scale)
    }
    let minY = firstBaseline
             - withExtendedLifetime(self) { Float64(data.pointee.firstLineHeightAboveBaseline) }
    let maxY = lastBaseline
             + withExtendedLifetime(self) { Float64(data.pointee.lastLineHeightBelowBaseline) }
    var minX = withExtendedLifetime(self) { data.pointee.minX }
    var maxX = withExtendedLifetime(self) { data.pointee.maxX }
    minX += Float64(frameOrigin.x)
    maxX += Float64(frameOrigin.x)
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  @inlinable
  public func firstBaseline(frameOriginY: CGFloat, displayScale: CGFloat?) -> CGFloat {
    return self.firstBaseline(frameOriginY: frameOriginY, displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to `firstBaseline(frameOriginY: frameOriginY, displayScale: self.displayScale)`.
  @inlinable
  public func firstBaseline(frameOriginY: CGFloat) -> CGFloat {
    return self.firstBaseline(frameOriginY: frameOriginY, displayScaleOrZero: displayScaleOrZero)
  }

  /// Equivalent to `firstBaseline(frameOriginY: 0, displayScale: self.displayScale)`.
  @inlinable
  public var firstBaseline: CGFloat {
    return self.firstBaseline(frameOriginY: 0, displayScaleOrZero: 0)
  }

  @inlinable
  internal func firstBaseline(frameOriginY: CGFloat, displayScaleOrZero: CGFloat) -> CGFloat {
    let value = frameOriginY
              + withExtendedLifetime(self) { CGFloat(self.__data.pointee.firstBaseline) }
    if displayScaleOrZero > 0
       && (displayScaleOrZero != self.displayScaleOrZero || frameOriginY != 0)
    {
      return ceilToScale(value, displayScaleOrZero)
    }
    return value
  }

  @inlinable
  public func lastBaseline(frameOriginY: CGFloat, displayScale: CGFloat?) -> CGFloat {
    return lastBaseline(frameOriginY: frameOriginY, displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to `lastBaseline(frameOriginY: frameOriginY, displayScale: self.displayScale)`
  @inlinable
  public func lastBaseline(frameOriginY: CGFloat) -> CGFloat {
    return lastBaseline(frameOriginY: frameOriginY, displayScaleOrZero: displayScaleOrZero)
  }

  /// Equivalent to `lastBaseline(frameOriginY: 0, displayScale: self.displayScale)`
  @inlinable
  public var lastBaseline: CGFloat {
    return lastBaseline(frameOriginY: 0, displayScaleOrZero: 0)
  }

  @inlinable
  internal func lastBaseline(frameOriginY: CGFloat, displayScaleOrZero: CGFloat) -> CGFloat {
    let value = frameOriginY
              + withExtendedLifetime(self) { CGFloat(self.__data.pointee.lastBaseline) }
    if displayScaleOrZero > 0
       && (displayScaleOrZero != self.displayScaleOrZero || frameOriginY != 0)
    {
      return ceilToScale(value, displayScaleOrZero)
    }
    return value
  }

  /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  @inlinable
  public var firstLineHeight: CGFloat {
    return withExtendedLifetime(self) { CGFloat(self.__data.pointee.firstLineHeight) }
  }

  /// The part of the first line's layout height that lies above the baseline.
  @inlinable
  public var firstLineHeightAboveBaseline: CGFloat {
    return withExtendedLifetime(self) { CGFloat(self.__data.pointee.firstLineHeightAboveBaseline) }
  }

  /// The value that the text layout algorithm would calculate for the ideal distance between the
  /// baseline of the last text line in the text frame and the baseline of a (hypothetical)
  /// adjacent text line that has the same typographic metrics and is in the same paragraph.
  @inlinable
  public var lastLineHeight: CGFloat {
    return withExtendedLifetime(self) { CGFloat(self.__data.pointee.lastLineHeight) }
  }

  /// The part of the last line's layout height that lies below the baseline.
  @inlinable
  public var lastLineHeightBelowBaseline: CGFloat {
    return withExtendedLifetime(self) { CGFloat(self.__data.pointee.lastLineHeightBelowBaseline) }
  }

  /// The part of the last line's layout height that lies below the baseline, excluding any line
  /// spacing. This is the height below the baseline that is assumed when deciding whether the
  /// line fits the text frame's size.
  @inlinable
  public var lastLineHeightBelowBaselineWithoutSpacing: CGFloat {
    return withExtendedLifetime(self) {
              CGFloat(self.__data.pointee.lastLineHeightBelowBaselineWithoutSpacing)
           }
  }

  /// The part of the last line's layout height that lies below the baseline, with only a minimal
  /// layout-mode-dependent amount of spacing included. This is the height below the baseline
  /// assumed for a label's intrinsic content height.
  @inlinable
  public var lastLineHeightBelowBaselineWithMinimalSpacing: CGFloat {
    return withExtendedLifetime(self) {
              CGFloat(self.__data.pointee.lastLineHeightBelowBaselineWithMinimalSpacing)
           }
  }

  @inlinable
  public func rects(for range: Range<Index>, frameOrigin: CGPoint, displayScale: CGFloat?)
    -> STUTextRectArray
  {
    return rects(for: range, frameOrigin: frameOrigin, displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to the other `rects` overload
  /// with `self.displayScale` as the `displayScale` argument.
  @inlinable
  public func rects(for range: Range<Index>, frameOrigin: CGPoint) -> STUTextRectArray {
    return rects(for: range, frameOrigin: frameOrigin, displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  internal func rects(for range: Range<Index>, frameOrigin: CGPoint, displayScaleOrZero: CGFloat)
    -> STUTextRectArray
  {
    return __rects(__STUTextFrameRange(range), frameOrigin: frameOrigin,
                   displayScale: displayScaleOrZero)
  }

  @inlinable
  public func rectsForAllLinksInTruncatedString(frameOrigin: CGPoint, displayScale: CGFloat?)
    -> STUTextLinkArray
  {
    return rectsForAllLinksInTruncatedString(frameOrigin: frameOrigin,
                                             displayScaleOrZero: displayScale ?? 0)
  }

  /// Equivalent to the other `rectsForAllLinksInTruncatedString` overload
  /// with `self.displayScale` as the `displayScale` argument.
  @inlinable
  public func rectsForAllLinksInTruncatedString(frameOrigin: CGPoint) -> STUTextLinkArray {
    return rectsForAllLinksInTruncatedString(frameOrigin: frameOrigin,
                                             displayScaleOrZero: displayScaleOrZero)
  }

  @inlinable
  internal func rectsForAllLinksInTruncatedString(frameOrigin: CGPoint, displayScaleOrZero: CGFloat)
    -> STUTextLinkArray
  {
    return __rectsForAllLinksInTruncatedString(frameOrigin: frameOrigin,
                                               displayScale: displayScale ?? 0)
  }

  @inlinable
  public var paragraphs: Paragraphs { return Paragraphs(self) }

  @inlinable
  public var lines: Lines { return Lines(self) }

  public struct Paragraphs : RandomAccessCollection {
    @usableFromInline internal let textFrame: STUTextFrame
    @usableFromInline internal let textFrameParagraphs: UnsafePointer<__STUTextFrameParagraph>
    public let count: Int

    @inlinable
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

    @inlinable
    public var startIndex: Int { return 0 }

    @inlinable
    public var endIndex: Int { return count }

    @inlinable
    public subscript(index: Index) -> Paragraph {
      precondition(0 <= index && index < count, "Paragraph index out of bounds")
      return Paragraph(textFrame, textFrameParagraphs.advanced(by: index))
    }
  }

  public struct Lines : RandomAccessCollection {
    @usableFromInline internal let textFrame: STUTextFrame
    @usableFromInline internal let textFrameLines: UnsafePointer<__STUTextFrameLine>
    public let count: Int
    @usableFromInline internal let textScaleFactor: CGFloat

    @inlinable
    internal init(_ textFrame: STUTextFrame) {
      let (lines, count, textScaleFactor): (UnsafePointer<__STUTextFrameLine>, Int, CGFloat) =
        withExtendedLifetime(textFrame) {
          let data = textFrame.__data
          return (__STUTextFrameDataGetLines(data),
                  Int(data.pointee.lineCount),
                  data.pointee.textScaleFactor)
      }
      self.textFrame = textFrame
      self.textFrameLines = lines
      self.count = count
      self.textScaleFactor = textScaleFactor
    }

    public typealias Index = Int

    @inlinable
    public var startIndex: Int { return 0 }

    @inlinable
    public var endIndex: Int { return count }

    @inlinable
    public subscript(index: Index) -> Line {
      precondition(0 <= index && index < count, "Line index out of bounds")
      return Line(textFrame, textFrameLines.advanced(by: index), textScaleFactor: textScaleFactor)
    }
  }

  /// Text paragraphs are separated by any of the following characters (grapheme clusters):
  /// `"\r"`, `"\n"`, `"\r\n"`,`"\u{2029}"`
  public struct Paragraph {
    public let textFrame: STUTextFrame

    @usableFromInline internal let paragraph: UnsafePointer<__STUTextFrameParagraph>

    @inlinable
    internal init(_ textFrame: STUTextFrame,
                  _ para: UnsafePointer<__STUTextFrameParagraph>)
    {
      self.textFrame = textFrame
      self.paragraph = para
    }
    @inlinable
    internal init(_ textFrame: STUTextFrame, _ index: Int32) {
      let para = withExtendedLifetime(textFrame) {
        return __STUTextFrameDataGetParagraphs(textFrame.__data).advanced(by: Int(index))
      }
      self.init(textFrame, para)
    }

    /// The 0-based index of the paragraph in the text frame.
    @inlinable
    public var paragraphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(paragraph.pointee.paragraphIndex) }
    }

    @inlinable
    public var isFirstParagraph: Bool {
      return withExtendedLifetime(textFrame) { paragraph.pointee.paragraphIndex == 0 }
    }

    // @inlinable // swift inlining bug
    public var isLastParagraph: Bool {
      return withExtendedLifetime(textFrame) { paragraph.pointee.isLastParagraph }
    }

    @inlinable
    public var lineIndexRange: Range<Int> {
      return withExtendedLifetime(textFrame) {
        let range = paragraph.pointee.lineIndexRange
        return Range(uncheckedBounds: (Int(range.start), Int(range.end)))
      }
    }

    @inlinable
    public var lines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: lineIndexRange)
    }

    /// The text frame range corresponding to the paragraphs's text.
    @inlinable
    public var range: Range<STUTextFrame.Index> {
      let rangeInTruncatedString = self.rangeInTruncatedString
      let lineIndexRange = self.lineIndexRange
      return Range(uncheckedBounds:
                     (Index(utf16IndexInTruncatedString: rangeInTruncatedString.lowerBound,
                            lineIndex: lineIndexRange.lowerBound),
                      Index(utf16IndexInTruncatedString: rangeInTruncatedString.upperBound,
                            lineIndex: lineIndexRange.upperBound)))
    }

    /// The range in `self.textFrame.truncatedAttributedString` corresponding to the paragraphs's
    /// text.
    @inlinable
    public var rangeInTruncatedString: NSRange {
      return withExtendedLifetime(textFrame) { paragraph.pointee.rangeInTruncatedString.nsRange }
    }

    /// The paragraph's range in `self.textFrame.originalAttributedString`.
    ///
    /// This range includes any trailing whitespace of the paragraph, including the paragraph
    /// terminator (unless the paragraph is the last paragraph and has no terminator)
    @inlinable
    public var rangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) { paragraph.pointee.rangeInOriginalString.nsRange }
    }

    /// The UTF-16 code unit length of the paragraph terminator (`"\r"`, `"\n"`, `"\r\n"` or
    /// `"\u{2029}"`). The value is between 0 and 2 (inclusive).
    // @inlinable // swift inlining bug
    public var paragraphTerminatorInOriginalStringUTF16Length: Int  {
      return withExtendedLifetime(textFrame) {
               return Int(paragraph.pointee.paragraphTerminatorInOriginalStringUTF16Length)
             }
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
      return withExtendedLifetime(textFrame) {
        return paragraph.pointee.excisedRangeInOriginalString.nsRange
      }
    }

    // @inlinable // swift inlining bug
    public var excisedStringRangeIsContinuedInNextParagraph: Bool {
      return withExtendedLifetime(textFrame) {
        return paragraph.pointee.excisedStringRangeIsContinuedInNextParagraph
      }
    }

    // @inlinable // swift inlining bug
    public var excisedStringRangeIsContinuationFromLastParagraph: Bool {
      return withExtendedLifetime(textFrame) {
        return paragraph.pointee.excisedStringRangeIsContinuationFromLastParagraph
      }
    }

    /// The truncation token in the last line of this paragraph,
    /// or `nil` if the paragraph is not truncated.
    ///
    /// - Note: If `self.excisedStringRangeIsContinuationFromLastParagraph`,
    ///         the paragraph has no text lines and no truncation token
    ///         even though `self.excisedRangeInOriginalString` is not empty.
    @inlinable
    public var truncationToken: NSAttributedString? {
      return withExtendedLifetime(textFrame) {
               paragraph.pointee.truncationToken?.takeUnretainedValue()
             }
    }

    @inlinable
    public var truncationTokenUTF16Length: Int {
      return withExtendedLifetime(textFrame) { Int(paragraph.pointee.truncationTokenUTF16Length) }
    }

    /// The range of the truncation token in the text frame,
    /// or the empty range with the lower bound `self.range.end` if `self.truncationToken` is `nil`.
    @inlinable
    public var rangeOfTruncationToken: Range<STUTextFrame.Index> {
      let range = self.rangeOfTruncationTokenInTruncatedString
      let lineIndexRange = self.lineIndexRange
      let lineIndex = max(lineIndexRange.lowerBound, lineIndexRange.upperBound &- 1)
      return Range(uncheckedBounds:
                     (Index(utf16IndexInTruncatedString: range.lowerBound, lineIndex: lineIndex),
                      Index(utf16IndexInTruncatedString: range.upperBound, lineIndex: lineIndex)))
    }

    /// The range of the truncation token in the text frame's truncated string,
    /// or the empty range with the lower bound `self.rangeInTruncatedString.end`
    /// if `self.truncationToken` is `nil`.
    @inlinable
    public var rangeOfTruncationTokenInTruncatedString: NSRange {
      return withExtendedLifetime(textFrame) {
               let start = __STUTextFrameParagraphGetStartIndexOfTruncationTokenInTruncatedString(
                               paragraph)
               let length = paragraph.pointee.truncationTokenUTF16Length
               return NSRange(location: Int(start), length: Int(length))
            }
    }

    @inlinable
    public var alignment: STUParagraphAlignment  {
      return withExtendedLifetime(textFrame) { paragraph.pointee.alignment }
    }

    // @inlinable // swift inlining bug
    public var baseWritingDirection: STUWritingDirection {
      return withExtendedLifetime(textFrame) { paragraph.pointee.baseWritingDirection }
    }

    @inlinable
    public var textFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { paragraph.pointee.textFlags }
    }

    //@inlinable // swift inlining bug
    public var isIndented: Bool {
      return withExtendedLifetime(textFrame) { paragraph.pointee.isIndented }
    }

    @inlinable
    public var initialLinesIndexRange: Range<Int> {
      return withExtendedLifetime(textFrame) {
        let start = paragraph.pointee.lineIndexRange.start
        let end = paragraph.pointee.initialLinesEndIndex
        return Range(uncheckedBounds: (Int(start), Int(end)))
      }
    }

    @inlinable
    public var nonInitialLinesIndexRange: Range<Int> {
      return withExtendedLifetime(textFrame) {
        let start = paragraph.pointee.initialLinesEndIndex
        let end = paragraph.pointee.lineIndexRange.end
        return Range(uncheckedBounds: (Int(start), Int(end)))
      }
    }

    @inlinable
    public var initialLines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: initialLinesIndexRange)
    }

    @inlinable
    public var nonInitialLines: Lines.SubSequence {
      return Lines.SubSequence(base: textFrame.lines, bounds: nonInitialLinesIndexRange)
    }


    @inlinable
    public var initialLinesLeftIndent: CGFloat {
      return withExtendedLifetime(textFrame) { paragraph.pointee.initialLinesLeftIndent }
    }

    @inlinable
    public var initialLinesRightIndent: CGFloat {
      return withExtendedLifetime(textFrame) { paragraph.pointee.initialLinesRightIndent }
    }

    @inlinable
    public var nonInitialLinesLeftIndent: CGFloat {
      return withExtendedLifetime(textFrame) { paragraph.pointee.nonInitialLinesLeftIndent }
    }

    @inlinable
    public var nonInitialLinesRightIndent: CGFloat {
      return withExtendedLifetime(textFrame) { paragraph.pointee.nonInitialLinesRightIndent }
    }
  }

  public struct Line {
    public let textFrame: STUTextFrame
    @usableFromInline internal let line: UnsafePointer<__STUTextFrameLine>
    @usableFromInline internal let textScaleFactor: CGFloat

    @inlinable
    internal init(_ textFrame: STUTextFrame, _ line: UnsafePointer<__STUTextFrameLine>,
                  textScaleFactor: CGFloat)
    {
      self.textFrame = textFrame
      self.line = line
      self.textScaleFactor = textScaleFactor
    }

    /// The 0-based index of the line in the text frame.
    @inlinable
    public var lineIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee.lineIndex) }
    }

    // Indicates whether this is the first line in the text frame.
   // @inlinable // swift inlining bug
    public var isFirstLine: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.lineIndex == 0 }
    }

    /// Indicates whether this is the last line in the text frame.
    // @inlinable // swift inlining bug
    public var isLastLine: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isLastLine }
    }

    // @inlinable // swift inlining bug
    public var isFirstLineInParagraph: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isFirstLineInParagraph }
    }

    @inlinable
    public var isLastLineInParagraph: Bool {
      return withExtendedLifetime(textFrame) {
               line.pointee.lineIndex &+ 1
               == __STUTextFrameLineGetParagraph(line).pointee.lineIndexRange.end
             }
    }

    @inlinable
    public var isInitialLineInParagraph: Bool {
      return withExtendedLifetime(textFrame) {
               line.pointee.lineIndex
               < __STUTextFrameLineGetParagraph(line).pointee.initialLinesEndIndex
             }
    }

    // The 0-based index of the line's paragraph in the text frame.
    @inlinable
    public var paragraphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee.paragraphIndex) }
    }

    @inlinable
    public var paragraph: Paragraph {
      let paragraph = withExtendedLifetime(textFrame) { __STUTextFrameLineGetParagraph(line) }
      return Paragraph(textFrame, paragraph)
    }

    @inlinable
    public var range: Range<STUTextFrame.Index> {
      return withExtendedLifetime(textFrame) { Range(__STUTextFrameLineGetRange(line)) }
    }

    @inlinable
    public var rangeInTruncatedString: NSRange {
      return withExtendedLifetime(textFrame) { line.pointee.rangeInTruncatedString.nsRange }
    }

    @inlinable
    public var trailingWhitespaceInTruncatedStringUTF16Length: Int {
      return withExtendedLifetime(textFrame) {
        return Int(UInt32(line.pointee.trailingWhitespaceInTruncatedStringUTF16Length))
      }
    }

    @inlinable
    public var rangeInOriginalString: NSRange {
      return withExtendedLifetime(textFrame) { line.pointee.rangeInOriginalString.nsRange }
    }

    // @inlinable // swift inlining bug
    public var excisedRangeInOriginalString: NSRange? {
      return withExtendedLifetime(textFrame) {
               if !line.pointee.hasTruncationToken { return nil }
               let paragraph = __STUTextFrameLineGetParagraph(line)
               return paragraph.pointee.excisedRangeInOriginalString.nsRange
             }
    }

    // @inlinable // swift inlining bug
    public var isFollowedByTerminatorInOriginalString: Bool  {
      return withExtendedLifetime(textFrame) { line.pointee.isFollowedByTerminatorInOriginalString }
    }

    @inlinable
    public func baselineOrigin(textFrameOrigin: CGPoint, displayScale: CGFloat?) -> CGPoint {
      return baselineOrigin(textFrameOrigin: textFrameOrigin, displayScaleOrZero: displayScale ?? 0)
    }
    /// Equivalent to baselineOrigin(textFrameOrigin: .zero, displayScale: nil)
    @inlinable
    public var baselineOrigin: CGPoint {
      return baselineOrigin(textFrameOrigin: .zero, displayScaleOrZero: 0)
    }

    @inlinable
    internal func baselineOrigin(textFrameOrigin: CGPoint, displayScaleOrZero: CGFloat) -> CGPoint {
      var (x, y) = withExtendedLifetime(textFrame) { (line.pointee.originX, line.pointee.originY) }
      let textScaleFactor = Float64(self.textScaleFactor)
      x *= textScaleFactor
      y *= textScaleFactor
      x += Float64(textFrameOrigin.x)
      y += Float64(textFrameOrigin.y)
      if displayScaleOrZero > 0 {
        return CGPoint(x: CGFloat(x), y: ceilToScale(CGFloat(y), displayScaleOrZero))
      }
      return CGPoint(x: x, y: y)
    }

    @inlinable
    public var width: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.width) }
    }

    /// The line's ascent after font substitution.
    @inlinable
    public var ascent: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.ascent) }
    }

    /// The line's descent after font substitution.
    @inlinable
    public var descent: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.descent) }
    }

    /// The line's leading after font substitution.
    @inlinable
    public var leading: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.leading) }
    }

    @inlinable
    public func typographicBounds(textFrameOrigin: CGPoint, displayScale: CGFloat?) -> CGRect
    {
      return typographicBounds(textFrameOrigin: textFrameOrigin,
                               displayScaleOrZero: displayScale ?? 0)
    }

    /// Equivalent to typographicBounds(textFrameOrigin: .zero, displayScale: nil)
    @inlinable
    public var typographicBounds: CGRect {
      return typographicBounds(textFrameOrigin: .zero, displayScaleOrZero: 0)
    }

    @inlinable
    internal func typographicBounds(textFrameOrigin: CGPoint, displayScaleOrZero: CGFloat) -> CGRect {
      return withExtendedLifetime(textFrame) {
               let textScaleFactor_f64 = Float64(self.textScaleFactor)
               let x = Float64(textFrameOrigin.x) + textScaleFactor_f64*line.pointee.originX
               var y = Float64(textFrameOrigin.y) + textScaleFactor_f64*line.pointee.originY
               if displayScaleOrZero > 0 {
                 y = ceilToScale(y, Float64(displayScaleOrZero))
               }
               let width   = line.pointee.width
               let ascent  = line.pointee.ascent
               let descent = line.pointee.descent
               let leading = line.pointee.leading
               return CGRect(x: CGFloat(x),
                             y: CGFloat(y - textScaleFactor_f64*Float64(ascent + leading/2)),
                             width: textScaleFactor*CGFloat(width),
                             height: textScaleFactor*CGFloat(ascent + descent + leading))
             }
    }

    /// Indicates whether the line contains a truncation token.
    /// - Note: A line may have a truncation token even though the line itself wasn't truncated.
    ///         In that case the truncation token indicates that one or more following lines were
    ///         removed.
    // @inlinable // swift inlining bug
    public var hasTruncationToken: Bool {
      return withExtendedLifetime(textFrame) { line.pointee.hasTruncationToken }
    }

    // @inlinable // swift inlining bug
    public var isTruncatedAsRightToLeftLine: Bool {
      return withExtendedLifetime(textFrame) {
               line.pointee.isTruncatedAsRightToLeftLine
             }
    }

    /// Indicates whether a hyphen was inserted during line breaking.
    // @inlinable // swift inlining bug
    public var hasInsertedHyphen: Bool {
      return withExtendedLifetime(textFrame) { line.pointee.hasInsertedHyphen }
    }

    // @inlinable // swift inlining bug
    public var paragraphBaseWritingDirection: STUWritingDirection  {
      return withExtendedLifetime(textFrame) { line.pointee.paragraphBaseWritingDirection }
    }

    // @inlinable // swift inlining bug
    public var textFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.textFlags }
    }

    // @inlinable // swift inlining bug
    public var nonTokenTextFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.nonTokenTextFlags }
    }

    // @inlinable // swift inlining bug
    public var tokenTextFlags: STUTextFlags  {
      return withExtendedLifetime(textFrame) { line.pointee.tokenTextFlags }
    }

    /// The typographic width of the part of the line left of the inserted token. Equals `width` if
    /// there is no token.
    @inlinable
    public var leftPartWidth: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.leftPartWidth) }
    }

    /// The typographic width of the inserted truncation token or hyphen.
    @inlinable
    public var tokenWidth: CGFloat {
      return withExtendedLifetime(textFrame) { textScaleFactor*CGFloat(line.pointee.tokenWidth) }
    }

    @inlinable
    public var _hyphenRunIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee._hyphenRunIndex) }
    }

    @inlinable
    public var _hyphenGlyphIndex: Int {
      return withExtendedLifetime(textFrame) { Int(line.pointee._hyphenGlyphIndex) }
    }

    @inlinable
    public var _hyphenXOffset: Float32 {
      return withExtendedLifetime(textFrame) { Float32(line.pointee._hyphenXOffset) }
    }

    @inlinable
    public var _ctLine: CTLine? {
      return withExtendedLifetime(textFrame) { line.pointee._ctLine?.takeUnretainedValue() }
    }

    @inlinable
    public var _tokenCTLine: CTLine? {
      return withExtendedLifetime(textFrame) { line.pointee._tokenCTLine?.takeUnretainedValue() }
    }

    @inlinable
    public var _leftPartEnd: STURunGlyphIndex {
      return withExtendedLifetime(textFrame) { line.pointee._leftPartEnd }
    }

    @inlinable
    public var _rightPartStart: STURunGlyphIndex {
      return withExtendedLifetime(textFrame) { line.pointee._rightPartStart }
    }
  }
}

extension STUTextFrame.Index {
  /// The UTF-16 code unit index in the truncated string.
  /// This value must be less than or equal to `UInt32.max`.
  @inlinable
  public var utf16IndexInTruncatedString: Int {
    get { return Int(__indexInTruncatedString); }
    set { __indexInTruncatedString = UInt32(newValue) }
  }

  /// The (0-based) index of the line in the text frame corresponding to the character identified
  /// by `utf16IndexInTruncatedString`.
  /// This value must be less than or equal to `UInt32.max`.
  @inlinable
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
  @inlinable
  public init(utf16IndexInTruncatedString: Int, isIndexOfInsertedHyphen: Bool = false,
              lineIndex: Int)
  {
    self = .init(isIndexOfInsertedHyphen: isIndexOfInsertedHyphen,
                 __indexInTruncatedString: UInt32(utf16IndexInTruncatedString),
                 __lineIndex: UInt32(lineIndex))
  }
}

extension STUTextFrame.Index : @retroactive Comparable {
  @inlinable
  public static func ==(lhs: STUTextFrame.Index, rhs: STUTextFrame.Index) -> Bool {
    return __STUTextFrameIndexEqualToIndex(lhs, rhs)
  }

  @inlinable
  public static func <(lhs: STUTextFrame.Index, rhs: STUTextFrame.Index) -> Bool {
    return __STUTextFrameIndexLessThanIndex(lhs, rhs)
  }
}

extension Range where Bound == STUTextFrame.Index {
  @inlinable
  public init(_ range: __STUTextFrameRange) {
    self = range.start..<range.end
  }

  @inlinable
  public var rangeInTruncatedString: NSRange {
    return __STUTextFrameRange(self).rangeInTruncatedString
  }
}

extension __STUTextFrameRange {
  @inlinable
  public init(_ range: Range<STUTextFrame.Index>) {
    self.init(start: range.lowerBound, end: range.upperBound)
  }
}

extension STUTextRange {
  @inlinable
  public init(_ range: Range<STUTextFrame.Index>) {
    self.init(range: range.rangeInTruncatedString, type: .rangeInTruncatedString)
  }
}

extension STUTextFrame.GraphemeClusterRange {
  @inlinable
  public var range: Range<STUTextFrame.Index> {
    return Range<STUTextFrame.Index>(self.__range)
  }
}

extension STUTextFrame.LayoutInfo {
  /// The union of the layout bounds of all text lines, including all vertical line spacing
  /// and all horizontal paragraph insets.
  @inlinable
  public var layoutBounds: CGRect {
    let minY = firstBaseline - Float64(firstLineHeightAboveBaseline)
    let maxY = lastBaseline + Float64(lastLineHeightBelowBaseline)
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }
}


