// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import XCTest

extension NSAttributedString {
  convenience init(_ string: String, _ attributes: StringAttributes) {
    self.init(string: string, attributes: attributes)
  }
}


class TextFrameLineBreakingTests: SnapshotTestCase {

  let displayScale: CGFloat = 2

  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  let font = UIFont(name: "HelveticaNeue", size: 18)!
  
  @nonobjc
  func textFrame(_ attributedString: NSAttributedString, width: CGFloat = 1000,
                 _ options: STUTextFrameOptions? = nil) -> STUTextFrame
  {
    let options = options
                  ?? STUTextFrameOptions { builder in builder.defaultTextAlignment = .start }
    let frame = STUTextFrame(STUShapedString(attributedString,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 10000), displayScale: displayScale,
                             options: options)
    return frame
  }

  @nonobjc
  func textFrame(_ string: String, width: CGFloat = 1000) -> STUTextFrame {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    return textFrame(NSAttributedString(string, attributes), width: width)
  }

  @nonobjc
  func typographicWidth(_ attributedString: NSAttributedString, width: CGFloat = 1000) -> CGFloat {
    return textFrame(attributedString, width: width).layoutBounds.size.width
  }

  @nonobjc
  func typographicWidth(_ string: String, width: CGFloat = 1000) -> CGFloat {
    return textFrame(string, width: width).layoutBounds.size.width
  }

  func image(_ textFrame: STUTextFrame) -> UIImage {
    var bounds = textFrame.layoutBounds
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

  func testEmptyLines() {
    let f = textFrame("\n\r\n", width: 0)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<0))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[0].width, 0)
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(1..<1))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 2)
    XCTAssertEqual(lines[1].width, 0)
  }

  func testSimpleLineBreaks() {
    {
      let width = typographicWidth("Test")
      let f = textFrame("Test Test", width: width)
      let lines = f.lines
      XCTAssertEqual(lines.count, 2)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<4))
      XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
      XCTAssertEqual(lines[0].width, width)
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(5..<9))
      XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[1].width, width)
    }();
    {
      let width = typographicWidth("Tes")
      let f = textFrame("Test\r\n", width: width)
      let lines = f.lines
      XCTAssertEqual(lines.count, 2)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<3))
      XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[0].width, width)
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(3..<4))
      XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 2)
      XCTAssertEqual(lines[1].width, typographicWidth("t"))
    }();
  }

  func testLineBreaksForZeroWidthFrames() {
    {
      let f = textFrame("T\u{2028}", width: 0)
      let lines = f.lines
      XCTAssertEqual(lines.count, 1)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<1))
      XCTAssertEqual(lines[0].width, typographicWidth("T"))
      XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    }();
    {
      let f = textFrame("Te😀  \n", width: 0)
      let lines = f.lines
      XCTAssertEqual(lines.count, 3)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<1))
      XCTAssertEqual(lines[0].width, typographicWidth("T"))
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(1..<2))
      XCTAssertEqual(lines[1].width, typographicWidth("e"))
      XCTAssertEqual(lines[2].rangeInOriginalString, NSRange(2..<4))
      XCTAssertEqual(lines[2].width, typographicWidth("😀"))
      XCTAssertEqual(lines[2].trailingWhitespaceInTruncatedStringUTF16Length, 3)
    }();
  }

  func testSoftHyphen() {
    let width = typographicWidth("Test Te‐")
    let f = textFrame("Test Te\u{00AD}st", width: width + 0.01)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<8))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width)

    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(8..<10))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[1].width, typographicWidth("st"))
    self.checkSnapshotImage(image(f))
  }

  func testLineWidthIsCheckedAfterInsertingHyphen() {
    let f = textFrame("Test Te\u{00AD}st", width: typographicWidth("Test Te‐") - 0.1)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<4))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[0].width, typographicWidth("Test"))
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(5..<10))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[1].width, typographicWidth("Test"))
  }

  func testHyphenIsOmittedIfItDoesntFitAndTheresNoOtherLineBreakOpportunity() {
    let f = textFrame("Test\u{00AD}Test", width: typographicWidth("Test") + 1)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssert(!lines[0].hasInsertedHyphen)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<5))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, typographicWidth("Test"))
    XCTAssert(!lines[1].hasInsertedHyphen)
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(5..<9))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[1].width, typographicWidth("Test"))
  }

  func testHyphenInRightToLeftLine() {
    // https://github.com/w3c/alreq/issues/108
    let width = CGFloat(32.8464851 as Float32)
    let f = textFrame("دامي\u{00AD}دى", width: width + 0.01)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssert(lines[0].hasInsertedHyphen)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<5))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width, accuracy: width*(CGFloat(Float32.ulpOfOne)))
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(5..<7))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    // The vertical hyphen position isn't yet optimal.
    self.checkSnapshotImage(image(f))
  }

  func testHyphenInMiddleOfLeftToRightRightToLeftLine() {
    let width = typographicWidth("Test:") +  CGFloat(32.8464851 as Float32)
    let f = textFrame("Test:دامي\u{00AD}دى", width: width + 0.01)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssert(lines[0].hasInsertedHyphen)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<10))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width, accuracy: width*(CGFloat(Float32.ulpOfOne)))
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(10..<12))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    self.checkSnapshotImage(image(f))
  }

  func testLineBreakAfterZeroWidthSpaceInRightToLeftLine() {
    let width = typographicWidth("دامي")
    let f = textFrame("دامي\u{200C}\u{200B}\u{200C}\u{200B}دى\u{200C}", width: width + 0.001)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<8))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width)
    XCTAssertEqual(lines[1].width, typographicWidth("دى"))
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(8..<11))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
  }

  func testHyphenInNonMonotonicRun() {
    let width = typographicWidth("ट्ट्ठि‐")
    let f = textFrame("ट्ट्ठि\u{200C}\u{200C}\u{AD}ट्ट्ठि", width: width + 0.01)
    let lines = f.lines
    XCTAssertEqual(lines.count, 2)
    XCTAssert(lines[0].hasInsertedHyphen)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<9))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width)
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(9..<15))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[1].width, typographicWidth("ट्ट्ठि"))
  }

  func testLocaleBasedHyphenation() {
    let string = NSMutableAttributedString()

    string.append(NSAttributedString("bettler\n", [:]))
    string.append(NSAttributedString("bettler\n", [.stuHyphenationLocaleIdentifier: "en_US"]))
    string.append(NSAttributedString("bettler\n", [.stuHyphenationLocaleIdentifier: "en_US"]))
    string.append(NSAttributedString("bettler\n", [.stuHyphenationLocaleIdentifier: "de_DE"]))
    string.append(NSAttributedString("bettlaken\n", [.stuHyphenationLocaleIdentifier: "de_DE"]))
    string.append(NSAttributedString("bettler\n", [.stuHyphenationLocaleIdentifier: "en_US"]))
    string.append(NSAttributedString("bettler\n", [.stuHyphenationLocaleIdentifier: "ar_EG"]))

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.hyphenationFactor = 1

    string.addAttributes([.font: font, .paragraphStyle: paraStyle],
                         range: NSRange(0..<string.length))

    let width = typographicWidth("bettle")
    let f = textFrame(string, width: width)
    let lines = f.lines
    XCTAssertEqual(lines.count, 14)
    XCTAssert(!lines[0].hasInsertedHyphen)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<6))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[0].width, width)
    XCTAssert(!lines[1].hasInsertedHyphen)
    XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(6..<7))
    XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[1].width, typographicWidth("r"))

    XCTAssert(lines[2].hasInsertedHyphen)
    XCTAssertEqual(lines[2].rangeInOriginalString, NSRange(8..<11))
    XCTAssertEqual(lines[2].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[2].width, typographicWidth("bet‐"))
    XCTAssert(!lines[3].hasInsertedHyphen)
    XCTAssertEqual(lines[3].rangeInOriginalString, NSRange(11..<15))
    XCTAssertEqual(lines[3].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[3].width, typographicWidth("tler"))

    XCTAssert(lines[4].hasInsertedHyphen)
    XCTAssertEqual(lines[4].rangeInOriginalString, NSRange(16..<19))
    XCTAssertEqual(lines[4].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[4].width, typographicWidth("bet‐"))
    XCTAssert(!lines[5].hasInsertedHyphen)
    XCTAssertEqual(lines[5].rangeInOriginalString, NSRange(19..<23))
    XCTAssertEqual(lines[5].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[5].width, typographicWidth("tler"))

    XCTAssert(lines[6].hasInsertedHyphen)
    XCTAssertEqual(lines[6].rangeInOriginalString, NSRange(24..<28))
    XCTAssertEqual(lines[6].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[6].width, typographicWidth("bett‐"))
    XCTAssert(!lines[7].hasInsertedHyphen)
    XCTAssertEqual(lines[7].rangeInOriginalString, NSRange(28..<31))
    XCTAssertEqual(lines[7].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[7].width, typographicWidth("ler"))

    XCTAssert(lines[8].hasInsertedHyphen)
    XCTAssertEqual(lines[8].rangeInOriginalString, NSRange(32..<36))
    XCTAssertEqual(lines[8].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[8].width, typographicWidth("bett‐"))
    XCTAssert(!lines[9].hasInsertedHyphen)
    XCTAssertEqual(lines[9].rangeInOriginalString, NSRange(36..<41))
    XCTAssertEqual(lines[9].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[9].width, typographicWidth("laken"))

    XCTAssert(lines[10].hasInsertedHyphen)
    XCTAssertEqual(lines[10].rangeInOriginalString, NSRange(42..<45))
    XCTAssertEqual(lines[10].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[10].width, typographicWidth("bet‐"))
    XCTAssert(!lines[11].hasInsertedHyphen)
    XCTAssertEqual(lines[11].rangeInOriginalString, NSRange(45..<49))
    XCTAssertEqual(lines[11].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[11].width, typographicWidth("tler"))

    XCTAssert(!lines[12].hasInsertedHyphen)
    XCTAssertEqual(lines[12].rangeInOriginalString, NSRange(50..<56))
    XCTAssertEqual(lines[12].trailingWhitespaceInTruncatedStringUTF16Length, 0)
    XCTAssertEqual(lines[12].width, width)
    XCTAssert(!lines[13].hasInsertedHyphen)
    XCTAssertEqual(lines[13].rangeInOriginalString, NSRange(56..<57))
    XCTAssertEqual(lines[13].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[13].width, typographicWidth("r"))
  }

  func testHyphenationThreshold() {
    let partialWidth = typographicWidth("test")
    let fullWidth = typographicWidth("test success")
    let frameWidth = fullWidth - 0.01
    let threshold = partialWidth/frameWidth

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.hyphenationFactor = Float32(threshold + 0.01)
    

    let string = NSAttributedString("test success",
                                     [.font: font, .paragraphStyle: paraStyle,
                                      .stuHyphenationLocaleIdentifier: "en_US"]);

    {
      let f = textFrame(string, width: frameWidth)
      let lines = f.lines
      XCTAssertEqual(lines.count, 2)
      XCTAssert(lines[0].hasInsertedHyphen)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<8))
      XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[0].width, typographicWidth("test suc‐"))
      XCTAssert(!lines[1].hasInsertedHyphen)
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(8..<12))
      XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[1].width, typographicWidth("cess"))
    }();

    paraStyle.hyphenationFactor = Float32(threshold - 0.01);
    {
      let f = textFrame(string, width: frameWidth)
      let lines = f.lines
      XCTAssertEqual(lines.count, 2)
      XCTAssert(!lines[0].hasInsertedHyphen)
      XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<4))
      XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
      XCTAssertEqual(lines[0].width, partialWidth)
      XCTAssert(!lines[1].hasInsertedHyphen)
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(5..<12))
      XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[1].width, typographicWidth("success"))
    }();
  }

  func testFinderBasedHyphenation() {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.hyphenationFactor = 1
    paraStyle.baseWritingDirection = .leftToRight
    let attributedString = NSAttributedString(string: "\n🐉✊🏿🌈",
                                              attributes: [.font: font,
                                                           .paragraphStyle: paraStyle])
                           .copy() as! NSAttributedString
    var counter = 0
    let options = STUTextFrameOptions { builder in
      builder.lastHyphenationLocationInRangeFinder = { (attributedStringArg, range)
                                                    -> STUHyphenationLocation in
        XCTAssertEqual(attributedStringArg, attributedString)
        let string = attributedString.string
        let index = string.index(string.endIndex, offsetBy: -counter)
        counter += 1
        XCTAssertEqual(range, NSRange(1..<index._utf16Offset(in: string)))
        return STUHyphenationLocation(index: string.index(before: index)._utf16Offset(in: string),
                                      hyphen: UnicodeScalar("🤯")!.value,
                                      options: [])
      }
    };

    let f = textFrame(attributedString, width: typographicWidth("🐉✊🏿🌈") - 0.1, options)
    let lines = f.lines
    XCTAssertEqual(lines.count, 3)
    XCTAssertEqual(lines[0].rangeInOriginalString, NSRange(0..<0))
    XCTAssertEqual(lines[0].trailingWhitespaceInTruncatedStringUTF16Length, 1)
    XCTAssertEqual(lines[0].width, 0)

    if #available(iOS 11, tvOS 11, watchOS 4, *) {
      XCTAssert(lines[1].hasInsertedHyphen)
      XCTAssertEqual(lines[1].rangeInOriginalString, NSRange(1..<3))
      XCTAssertEqual(lines[1].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[1].width, typographicWidth("🐉🤯"))

      XCTAssert(!lines[2].hasInsertedHyphen)
      XCTAssertEqual(lines[2].rangeInOriginalString, NSRange(3..<8))
      XCTAssertEqual(lines[2].trailingWhitespaceInTruncatedStringUTF16Length, 0)
      XCTAssertEqual(lines[2].width, typographicWidth("✊🏿🌈"))
    }
  }

  func testLTRJustification() {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.alignment = .justified
    let string = NSMutableAttributedString("Test TestTest",
                                           [.font: font, .paragraphStyle: paraStyle])
    string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(2..<3))
    let width = typographicWidth("TestTest")
    let f = textFrame(string, width: width)
    self.checkSnapshotImage(image(f))
  }

  func testRTLJustification() {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.alignment = .justified
    let string = NSMutableAttributedString("הבדיקה הבדיקההבדיקה",
                                           [.font: font, .paragraphStyle: paraStyle])
    string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(4..<5))
    let width = typographicWidth("הבדיקההבדיקה")
    let f = textFrame(string, width: width)
    self.checkSnapshotImage(image(f))
  }

  func testJustificationWithHyphenInLeftToRightRightToLeftLine() {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.alignment = .justified
    let string = NSMutableAttributedString("Test: اخ\u{00AD}تباراختباراختبار",
                                           [.font: font, .paragraphStyle: paraStyle])
    string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(6..<7))
    let f = textFrame(string, width: typographicWidth("اختباراختباراختبار"))
    self.checkSnapshotImage(image(f))
  }
}
