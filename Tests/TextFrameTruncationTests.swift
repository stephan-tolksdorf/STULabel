// Copyright 2018 Stephan Tolksdorf

import STULabel

import XCTest

class TruncationTests: XCTestCase {

  let displayScale: CGFloat = 2

  let font = UIFont(name: "HelveticaNeue", size: 18)!

  @nonobjc
  func textFrame(_ attributedString: NSAttributedString, width: CGFloat = 1000,
                 maxLineCount: Int = 0, lastLineTruncationMode: STULastLineTruncationMode = .end)
    -> STUTextFrame
  {
    let options = STUTextFrameOptions({ builder in
                                          builder.defaultTextAlignment = .start
                                          builder.lastLineTruncationMode = lastLineTruncationMode
                                          builder.maximumNumberOfLines = maxLineCount })
    let frame = STUTextFrame(STUShapedString(attributedString,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 10000),
                             displayScale: displayScale,
                             options: options)
    return frame
  }

  @nonobjc
  func textFrame(_ string: String, width: CGFloat = 1000, maxLineCount: Int = 0,
                 lastLineTruncationMode: STULastLineTruncationMode = .end)
    -> STUTextFrame
  {
    let attributes: [NSAttributedStringKey: Any] = [.font: font]
    return textFrame(NSAttributedString(string, attributes), width: width, maxLineCount: maxLineCount)
  }

  @nonobjc
  func typographicWidth(_ attributedString: NSAttributedString, width: CGFloat = 1000) -> CGFloat {
    return textFrame(attributedString, width: width).layoutInfo.layoutBounds.size.width
  }

  @nonobjc
  func typographicWidth(_ string: String, width: CGFloat = 1000) -> CGFloat {
    return textFrame(string, width: width).layoutInfo.layoutBounds.size.width
  }

  func image(_ textFrame: STUTextFrame) -> UIImage {
    var bounds = textFrame.layoutInfo.layoutBounds
    bounds.origin.x    = floor(bounds.origin.x*2)/2
    bounds.origin.y    = floor(bounds.origin.y*2)/2
    bounds.size.width  = ceil(bounds.size.width*2)/2
    bounds.size.height = ceil(bounds.size.height*2)/2
    bounds = bounds.insetBy(dx: -5, dy: -5)
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

}
