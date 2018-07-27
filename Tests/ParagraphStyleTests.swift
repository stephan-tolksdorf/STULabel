import STULabelSwift

class ParagraphStyleTests : XCTestCase {

  func test_init_encode_equal_hash() {
    let style0 = STUParagraphStyle()
    XCTAssertEqual(style0.firstLineOffsetType, .offsetOfFirstBaselineFromDefault)
    XCTAssertEqual(style0.firstLineOffset, 0)
    XCTAssertEqual(style0.minimumBaselineDistance, 0)
    XCTAssertEqual(style0.numberOfInitialLines, 0)
    XCTAssertEqual(style0.initialLinesHeadIndent, 0)
    XCTAssertEqual(style0.initialLinesTailIndent, 0)

    let style1 = STUParagraphStyle { (builder) in
      builder.setFirstLineOffset(1, type: .offsetOfFirstBaselineFromTop)
      builder.minimumBaselineDistance = 1.5
      builder.numberOfInitialLines = 2
      builder.initialLinesHeadIndent = 3.5
      builder.initialLinesTailIndent = -4.5
    }
    XCTAssertEqual(style1.firstLineOffsetType, .offsetOfFirstBaselineFromTop)
    XCTAssertEqual(style1.firstLineOffset, 1)
    XCTAssertEqual(style1.minimumBaselineDistance, 1.5)
    XCTAssertEqual(style1.numberOfInitialLines, 2)
    XCTAssertEqual(style1.initialLinesHeadIndent, 3.5)
    XCTAssertEqual(style1.initialLinesTailIndent, -4.5)

    let style1b = style1.copy(updates: { _ in })
    XCTAssertEqual(style1b.firstLineOffsetType, .offsetOfFirstBaselineFromTop)
    XCTAssertEqual(style1b.firstLineOffset, 1)
    XCTAssertEqual(style1b.minimumBaselineDistance, 1.5)
    XCTAssertEqual(style1b.numberOfInitialLines, 2)
    XCTAssertEqual(style1b.initialLinesHeadIndent, 3.5)
    XCTAssertEqual(style1b.initialLinesTailIndent, -4.5)

    XCTAssert(style1 !== style1b)
    XCTAssertEqual(style1, style1b)
    XCTAssertEqual(style1.hash, style1b.hash)
    XCTAssertNotEqual(style1 as NSObject, "Test" as NSObject)

    let style2 = style1b.copy { (builder) in builder.initialLinesTailIndent -= 1 }
    XCTAssertEqual(style2.firstLineOffsetType, .offsetOfFirstBaselineFromTop)
    XCTAssertEqual(style2.firstLineOffset, 1)
    XCTAssertEqual(style2.minimumBaselineDistance, 1.5)
    XCTAssertEqual(style2.numberOfInitialLines, 2)
    XCTAssertEqual(style2.initialLinesHeadIndent, 3.5)
    XCTAssertEqual(style2.initialLinesTailIndent, -5.5)
    XCTAssertNotEqual(style1.hash, style2.hash)
    XCTAssertNotEqual(style1, style2)

    let data1 = NSKeyedArchiver.archivedData(withRootObject: style1)
    let style1c = NSKeyedUnarchiver.unarchiveObject(with: data1) as! STUParagraphStyle
    XCTAssertEqual(style1, style1c)
  }

  func testInputClamping() {
    let builder = STUParagraphStyleBuilder()
    builder.setFirstLineOffset(-1, type: .offsetOfFirstBaselineFromDefault)
    XCTAssertEqual(builder.firstLineOffset, -1)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstBaselineFromDefault)

    builder.setFirstLineOffset(-1, type: .offsetOfFirstBaselineFromTop)
    XCTAssertEqual(builder.firstLineOffset, 0)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstBaselineFromTop)

    builder.setFirstLineOffset(-1, type: .offsetOfFirstLineCenterFromTop)
    XCTAssertEqual(builder.firstLineOffset, 0)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstLineCenterFromTop)

    builder.setFirstLineOffset(-1, type: .offsetOfFirstLineCapHeightCenterFromTop)
    XCTAssertEqual(builder.firstLineOffset, 0)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstLineCapHeightCenterFromTop)

    builder.setFirstLineOffset(-1, type: .offsetOfFirstLineXHeightCenterFromTop)
    XCTAssertEqual(builder.firstLineOffset, 0)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstLineXHeightCenterFromTop)

    builder.setFirstLineOffset(1, type: .offsetOfFirstBaselineFromDefault)
    XCTAssertEqual(builder.firstLineOffset, 1)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstBaselineFromDefault)

    builder.setFirstLineOffset(1, type: unsafeBitCast(UInt8(123), to: STUFirstLineOffsetType.self))
    XCTAssertEqual(builder.firstLineOffset, 0)
    XCTAssertEqual(builder.firstLineOffsetType, .offsetOfFirstBaselineFromDefault)

    builder.minimumBaselineDistance = -1
    XCTAssertEqual(builder.minimumBaselineDistance, 0)

    builder.numberOfInitialLines = -1
    XCTAssertEqual(builder.numberOfInitialLines, 0)

    builder.initialLinesHeadIndent = -CGFloat.infinity
    XCTAssertEqual(builder.initialLinesHeadIndent, 0)

    builder.initialLinesTailIndent = 1
    XCTAssertEqual(builder.initialLinesTailIndent, 0)
  }

  func testFirstLineOffset() {
    let font = UIFont(name: "HelveticaNeue", size: 20)!

    func secondLineBaseline(_ offset: (STUFirstLineOffsetType, CGFloat)? = nil) -> CGFloat {
      let style = NSMutableParagraphStyle()
      style.paragraphSpacingBefore = 10

      var attribs: Attributes = [.paragraphStyle: style]
      if let (type, offset) = offset {
        attribs[.stuParagraphStyle] = STUParagraphStyle({ b in
                                         b.setFirstLineOffset(offset, type: type) })
      }
      let string = NSAttributedString([("L\n", [:]), ("L", attribs)], [.font: font])
      let tf = STUTextFrame(STUShapedString(string), size: CGSize(width: 100, height: 100),
                            displayScale: 0)
      return tf.lines[1].baselineOriginInTextFrame.y
    }

    let ascent = font.ascender
    let descent = -font.descender
    let leading = font.leading
    let capHeight = font.capHeight
    let xHeight = font.xHeight
    let lineHeight = ascent + descent + leading
    let paragraphTop = lineHeight + 10

    let y0 = paragraphTop + leading/2 + ascent
    XCTAssertEqual(secondLineBaseline(), y0, accuracy: CGFloat(Float32(y0).ulp))

    let y1 = y0 - 3
    XCTAssertEqual(secondLineBaseline((.offsetOfFirstBaselineFromDefault, -3)),
                   y1, accuracy: CGFloat(Float32(y1).ulp))

    let y2 = paragraphTop + 13
    XCTAssertEqual(secondLineBaseline((.offsetOfFirstBaselineFromTop, 13)),
                   y2, accuracy: CGFloat(Float32(y2).ulp))

    let y3 = paragraphTop + 13 - lineHeight/2 + leading/2 + ascent
    XCTAssertEqual(secondLineBaseline((.offsetOfFirstLineCenterFromTop, 13)),
                   y3, accuracy: CGFloat(Float32(y3).ulp))

    let y4 = paragraphTop + capHeight/2 + 13
    XCTAssertEqual(secondLineBaseline((.offsetOfFirstLineCapHeightCenterFromTop, 13)),
                   y4, accuracy: CGFloat(Float32(y4).ulp))

    let y5 = paragraphTop + xHeight/2 + 13
    XCTAssertEqual(secondLineBaseline((.offsetOfFirstLineXHeightCenterFromTop, 13)),
                   y5, accuracy: CGFloat(Float32(y5).ulp))
  }

  func testMinimumBaselineDistance() {
    let font = UIFont(name: "HelveticaNeue", size: 20)!;

    {
      let string = NSAttributedString("Test", [.font: font,
                                               .stuParagraphStyle: STUParagraphStyle({ b in
                                                                     b.minimumBaselineDistance = 30
                                                                   })]);
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 1)
      print(tf.layoutInfo.layoutBounds)
      XCTAssertEqual(tf.layoutInfo.layoutBounds.height, CGFloat(30),
                     accuracy: CGFloat(Float32(30).ulp))
    }();
    {
      let string = NSAttributedString("1\u{2028}2", [.font: font]);
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 2)
      XCTAssert(tf.lines[1].baselineOriginInTextFrame.y
                - tf.lines[0].baselineOriginInTextFrame.y < 30)
    }();
    {
      let string = NSAttributedString("1\u{2028}2",
                                      [.font: font,
                                       .stuParagraphStyle: STUParagraphStyle({ b in
                                         b.minimumBaselineDistance = 30
                                       })]);
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 2)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.y
                     - tf.lines[0].baselineOriginInTextFrame.y, 30)
    }();
    {
      let string = NSAttributedString([("1\n", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                                      b.minimumBaselineDistance = 30
                                                                    })]),
                                       ("2", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                                    b.minimumBaselineDistance = 50
                                                                   })])])
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 2)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.y
                     - tf.lines[0].baselineOriginInTextFrame.y, 50)
    }();
    {
      let string = NSAttributedString([("1\n", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                                      b.minimumBaselineDistance = 50
                                                                    })]),
                                       ("2", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                                    b.minimumBaselineDistance = 30
                                                                   })])])
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 2)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.y
                     - tf.lines[0].baselineOriginInTextFrame.y, 50)
    }();
    {
      let string = NSAttributedString([("1\n", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                                      b.minimumBaselineDistance = 50
                                                                    })]),
                                       ("2", [.stuParagraphStyle: STUParagraphStyle({ b in
                                                b.minimumBaselineDistance = 30
                                                b.setFirstLineOffset(
                                                  -10, type: .offsetOfFirstBaselineFromDefault)
                                              })])])
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 2)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.y
                     - tf.lines[0].baselineOriginInTextFrame.y, 40)
    }();
  }

  func testInitialLinesIndent() {
    let font = UIFont(name: "HelveticaNeue", size: 20)!

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.firstLineHeadIndent = 7
    paraStyle.headIndent = 3
    paraStyle.tailIndent = -13


    let string0 = NSAttributedString("1\u{2028}2\u{2028}3\u{2028}4", [.font: font]);
    {
      let tf = STUTextFrame(STUShapedString(string0, defaultBaseWritingDirection: .leftToRight),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 0)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 0)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 0)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 0)
    }()

    let string1 = NSAttributedString("1\u{2028}2\u{2028}3\u{2028}4",
                                     [.font: font, .paragraphStyle: paraStyle,
                                      .stuParagraphStyle: STUParagraphStyle()]);
    {
      let tf = STUTextFrame(STUShapedString(string1, defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 7)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 3)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 3)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 3)
    }();

    {
      paraStyle.alignment = .right
      let tf = STUTextFrame(STUShapedString(string1, defaultBaseWritingDirection: .leftToRight),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[0].width)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[1].width)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[2].width)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[3].width)
    }();

    {
      let tf = STUTextFrame(STUShapedString(string1, defaultBaseWritingDirection: .rightToLeft),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 50 - 7 - tf.lines[0].width)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 50 - 3 - tf.lines[1].width)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 50 - 3 - tf.lines[2].width)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 50 - 3 - tf.lines[3].width)
    }()

    paraStyle.alignment = .left
    let string2 = NSAttributedString("1\u{2028}2\u{2028}3\u{2028}4",
                                     [.font: font, .paragraphStyle: paraStyle,
                                      .stuParagraphStyle: STUParagraphStyle({b in
                                          b.numberOfInitialLines = 2
                                          b.initialLinesHeadIndent = 5
                                          b.initialLinesTailIndent = -11
                                        })]);
    {
      let tf = STUTextFrame(STUShapedString(string2, defaultBaseWritingDirection: .leftToRight),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 5)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 5)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 3)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 3)
    }()

    paraStyle.alignment = .right;
    {
      let tf = STUTextFrame(STUShapedString(string2, defaultBaseWritingDirection: .leftToRight),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 50 - 11 - tf.lines[0].width)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 50 - 11 - tf.lines[1].width)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[2].width)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 50 - 13 - tf.lines[3].width)
    }();

    {
      let tf = STUTextFrame(STUShapedString(string2, defaultBaseWritingDirection: .rightToLeft),
                              size: CGSize(width: 50, height: 100), displayScale: 0)
      XCTAssertEqual(tf.lines.count, 4)
      XCTAssertEqual(tf.lines[0].baselineOriginInTextFrame.x, 50 - 5 - tf.lines[0].width)
      XCTAssertEqual(tf.lines[1].baselineOriginInTextFrame.x, 50 - 5 - tf.lines[1].width)
      XCTAssertEqual(tf.lines[2].baselineOriginInTextFrame.x, 50 - 3 - tf.lines[2].width)
      XCTAssertEqual(tf.lines[3].baselineOriginInTextFrame.x, 50 - 3 - tf.lines[3].width)
    }()
  }
}
