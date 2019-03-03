// Copyright 2018 Stephan Tolksdorf

import STULabel

import XCTest

class TruncationTests: SnapshotTestCase {

  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  let displayScale: CGFloat = 2

  let font = UIFont(name: "HelveticaNeue", size: 18)!

  @nonobjc
  func textFrame(_ attributedString: NSAttributedString, width: CGFloat = 1000,
                 maxLineCount: Int = 0,
                 lastLineTruncationMode: STULastLineTruncationMode = .end,
                 truncationToken: NSAttributedString? = nil)
    -> STUTextFrame
  {
    let options = STUTextFrameOptions { builder in
                                          builder.textLayoutMode = .textKit
                                          builder.defaultTextAlignment = .start
                                          builder.lastLineTruncationMode = lastLineTruncationMode
                                          builder.maximumNumberOfLines = maxLineCount
                                          builder.truncationToken = truncationToken
                                       }
    let frame = STUTextFrame(STUShapedString(attributedString,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 10000),
                             displayScale: displayScale,
                             options: options)
    return frame
  }

  @nonobjc
  func textFrame(_ string: String, font: UIFont? = nil, width: CGFloat = 1000, maxLineCount: Int = 0,
                 lastLineTruncationMode: STULastLineTruncationMode = .end,
                 truncationToken: NSAttributedString? = nil)
    -> STUTextFrame
  {
    let attributes: StringAttributes = [.font: font ?? self.font]
    return textFrame(NSAttributedString(string, attributes), width: width,
                     maxLineCount: maxLineCount,
                     lastLineTruncationMode: lastLineTruncationMode,
                     truncationToken: truncationToken)
  }

  @nonobjc
  func typographicWidth(_ attributedString: NSAttributedString, width: CGFloat = 1000) -> CGFloat {
    return textFrame(attributedString, width: width).layoutBounds.size.width
  }

  @nonobjc
  func typographicWidth(_ string: String,  font: UIFont? = nil, width: CGFloat = 1000) -> CGFloat {
    return textFrame(string, font: font, width: width).layoutBounds.size.width
  }

  func image(_ textFrame: STUTextFrame) -> UIImage {
    let bounds = ceilToScale(textFrame.layoutBounds, displayScale).insetBy(-1)
    return createImage(bounds.size, scale: displayScale, backgroundColor: .white, .grayscale,
                       { context in
                         textFrame.draw(at: -bounds.origin, in: context, contextBaseCTM_d: 1,
                                        pixelAlignBaselines: true)
                       })
  }

  func testLTRLineEndTruncation() {
    let width = typographicWidth("Test") + typographicWidth("…")
    let f = textFrame("Testing", width: width + 0.001, maxLineCount: 1)

    XCTAssertEqual(f.truncatedAttributedString, NSAttributedString("Test…", [.font: font]))
    XCTAssertEqual(f.rangeInOriginalString, NSRange(0..<7))
    XCTAssertEqual(f.rangeOfLastTruncationToken, f.range(forRangeInTruncatedString: NSRange(4..<5)))
    let paras = f.paragraphs
    XCTAssertEqual(paras[0].rangeInOriginalString, NSRange(0..<7))
    XCTAssertEqual(paras[0].excisedRangeInOriginalString, NSRange(4..<7))
    XCTAssertEqual(paras[0].rangeInTruncatedString, NSRange(0..<5))
    let lines = f.lines
    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<7))
    XCTAssertEqual(lines[0].excisedRangeInOriginalString, NSRange(4..<7))
    XCTAssertEqual(lines[0].rangeInTruncatedString, NSRange(0..<5))
  }

  func testSingleCharacterTokenFontSelection() {
    let font = UIFont(name: "HoeflerText-Regular", size: 17)!
    let width = typographicWidth("XX", font: font)
              + typographicWidth("…", font: UIFont(name: "PingFangSC-Regular", size: font.pointSize)!);
    {
      let f = textFrame("X测测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_PingFang")
    }();
    {
      let f = textFrame("X测测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle,
                        truncationToken: NSAttributedString("…", [.font: font]))
      self.checkSnapshotImage(image(f), suffix: "_Hoefler")
    }();
    
    {
      let f = textFrame("X测X测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_PingFang")
    }();

    {
      let f = textFrame("X测X测XX", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_PingFang")
    }();

    {
      let f = textFrame("XX测X测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_Hoefler")
    }();

    {
      let f = textFrame("XX测X测X测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_Hoefler")
    }();

    {
      let f = textFrame("XX测测X测X测X", font: font, width: width + 1, maxLineCount: 1,
                        lastLineTruncationMode: .middle)
      self.checkSnapshotImage(image(f), suffix: "_PingFang")
    }();
  }

}
