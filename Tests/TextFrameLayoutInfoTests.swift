// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

class TextFrameLayoutInfoTests : XCTestCase {

  func testLayoutInfoConsistency(_ tf: STUTextFrame, origin: CGPoint) {
    let info0 = tf.layoutInfo(frameOrigin: origin, displayScale: nil)
    let info1 = tf.layoutInfo(frameOrigin: origin)
    let s: CGFloat = 0.5
    let info2 = tf.layoutInfo(frameOrigin: origin, displayScale: s)

    let tfo = STUTextFrameWithOrigin(tf, origin, displayScale: s)
    let info2b = tfo.layoutInfo

    for info in [info1, info2, info2b] {
      XCTAssertEqual(info0.lineCount, info.lineCount)
      XCTAssertEqual(info0.flags, info.flags)
      XCTAssertEqual(info0.layoutMode, info.layoutMode)
      XCTAssertEqual(info0.consistentAlignment, info.consistentAlignment)
      XCTAssertEqual(info0.textScaleFactor, info.textScaleFactor)
      XCTAssertEqual(info0.size, info.size)
      XCTAssertEqual(info0.minX, info.minX)
      XCTAssertEqual(info0.maxX, info.maxX)
      XCTAssertEqual(info0.firstLineHeight, info.firstLineHeight)
      XCTAssertEqual(info0.firstLineHeightAboveBaseline, info.firstLineHeightAboveBaseline)
      XCTAssertEqual(info0.lastLineHeight, info.lastLineHeight)
      XCTAssertEqual(info0.lastLineHeightBelowBaseline, info.lastLineHeightBelowBaseline)
      XCTAssertEqual(info0.lastLineHeightBelowBaselineWithoutSpacing,
                     info.lastLineHeightBelowBaselineWithoutSpacing)
      XCTAssertEqual(info0.lastLineHeightBelowBaselineWithMinimalSpacing,
                     info.lastLineHeightBelowBaselineWithMinimalSpacing)
    }

    XCTAssertEqual(Int(info0.lineCount), tf.lines.count)
    XCTAssertEqual(info0.flags, tf.flags)
    XCTAssertEqual(info0.layoutMode, tf.layoutMode)
    XCTAssertEqual(info0.consistentAlignment, tf.consistentAlignment)
    XCTAssertEqual(info0.textScaleFactor, tf.textScaleFactor)
    XCTAssertEqual(info0.size, tf.size)
    XCTAssertEqual(CGFloat(info0.firstLineHeight), tf.firstLineHeight)
    XCTAssertEqual(CGFloat(info0.firstLineHeightAboveBaseline), tf.firstLineHeightAboveBaseline)
    XCTAssertEqual(CGFloat(info0.lastLineHeight), tf.lastLineHeight)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaseline), tf.lastLineHeightBelowBaseline)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaselineWithoutSpacing),
                   tf.lastLineHeightBelowBaselineWithoutSpacing)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaselineWithMinimalSpacing),
                   tf.lastLineHeightBelowBaselineWithMinimalSpacing)

    XCTAssertEqual(Int(info0.lineCount), tfo.lines.count)
    XCTAssertEqual(info0.flags, tfo.flags)
    XCTAssertEqual(info0.layoutMode, tfo.layoutMode)
    XCTAssertEqual(info0.consistentAlignment, tfo.consistentAlignment)
    XCTAssertEqual(info0.textScaleFactor, tfo.textScaleFactor)
    XCTAssertEqual(info0.size, tf.size)
    XCTAssertEqual(CGFloat(info0.firstLineHeight), tfo.firstLineHeight)
    XCTAssertEqual(CGFloat(info0.firstLineHeightAboveBaseline), tfo.firstLineHeightAboveBaseline)
    XCTAssertEqual(CGFloat(info0.lastLineHeight), tfo.lastLineHeight)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaseline), tfo.lastLineHeightBelowBaseline)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaselineWithoutSpacing),
                   tfo.lastLineHeightBelowBaselineWithoutSpacing)
    XCTAssertEqual(CGFloat(info0.lastLineHeightBelowBaselineWithMinimalSpacing),
                   tfo.lastLineHeightBelowBaselineWithMinimalSpacing)

    XCTAssertEqual(CGFloat(info0.firstBaseline),
                   tf.firstBaseline(frameOriginY: origin.y, displayScale: nil))
    XCTAssertEqual(CGFloat(info0.lastBaseline),
                   tf.lastBaseline(frameOriginY: origin.y, displayScale: nil))
    XCTAssertEqual(CGFloat(info1.firstBaseline),
                   tf.firstBaseline(frameOriginY: origin.y))
    XCTAssertEqual(CGFloat(info1.lastBaseline),
                   tf.lastBaseline(frameOriginY: origin.y))
    XCTAssertEqual(CGFloat(info2.firstBaseline),
                   tf.firstBaseline(frameOriginY: origin.y, displayScale: s))
    XCTAssertEqual(CGFloat(info2.lastBaseline),
                   tf.lastBaseline(frameOriginY: origin.y, displayScale: s))

    if !tf.lines.isEmpty {
      let firstLine = tf.lines.first!
      let lastLine = tf.lines.last!
      XCTAssertEqual(tf.firstBaseline(frameOriginY: origin.y, displayScale: nil),
                     firstLine.baselineOrigin(textFrameOrigin: origin, displayScale: nil).y)
      XCTAssertEqual(tf.firstBaseline(frameOriginY: origin.y, displayScale: s),
                     firstLine.baselineOrigin(textFrameOrigin: origin, displayScale: s).y)

      XCTAssertEqual(tf.lastBaseline(frameOriginY: origin.y, displayScale: nil),
                     lastLine.baselineOrigin(textFrameOrigin: origin, displayScale: nil).y)
      XCTAssertEqual(tf.lastBaseline(frameOriginY: origin.y, displayScale: s),
                     lastLine.baselineOrigin(textFrameOrigin: origin, displayScale: s).y)

      if tf.lines.count == 1 {
        XCTAssertEqual(tf.firstBaseline, tf.lastBaseline)
        XCTAssertEqual(tf.firstLineHeight, tf.lastLineHeight)
      }
    }

    XCTAssertEqual(tf.firstBaseline, tf.firstBaseline(frameOriginY: 0, displayScale: nil))
    XCTAssertEqual(tf.lastBaseline, tf.lastBaseline(frameOriginY: 0, displayScale: nil))

    for line in tf.lines {
      XCTAssertEqual(line.baselineOrigin,
                    line.baselineOrigin(textFrameOrigin: .zero, displayScale: nil))

      XCTAssertEqual(line.typographicBounds,
                     line.typographicBounds(textFrameOrigin: .zero, displayScale: nil))


      let bo = line.baselineOrigin(textFrameOrigin: .zero, displayScale: nil)
      let width = line.width
      let ascent = line.ascent
      let descent = line.descent
      let leading = line.leading

      let bounds0 = line.typographicBounds(textFrameOrigin: origin, displayScale: nil)
      let bounds2 = line.typographicBounds(textFrameOrigin: origin, displayScale: s)

      let minX = origin.x + bo.x
      XCTAssertEqual(minX, bounds0.origin.x, accuracy: minX.ulp)
      let minY = origin.y + bo.y - CGFloat((Float32(ascent) + Float32(leading)/2))
      XCTAssertEqual(minY, bounds0.origin.y, accuracy: 8*minY.ulp)

      XCTAssertEqual(width,  bounds0.size.width, accuracy: width.ulp)
      let height = CGFloat(Float32(ascent) + Float32(descent) + Float32(leading))
      XCTAssertEqual(height, bounds0.size.height, accuracy: height.ulp)

      XCTAssertEqual(minX,   bounds2.origin.x,    accuracy: minX.ulp)
      XCTAssertEqual(width,  bounds2.size.width,  accuracy: width.ulp)
      XCTAssertEqual(height, bounds2.size.height, accuracy: height.ulp)

      let minY2 = ceilToScale(origin.y + bo.y, s) - CGFloat((Float32(ascent) + Float32(leading)/2))
      XCTAssertEqual(minY2, bounds2.origin.y, accuracy: minY2.ulp)
    }

    XCTAssertEqual(tfo.firstBaseline, tf.firstBaseline(frameOriginY: origin.y, displayScale: s))
    XCTAssertEqual(tfo.lastBaseline, tf.lastBaseline(frameOriginY: origin.y, displayScale: s))
    XCTAssertEqual(tfo.layoutBounds, tf.layoutBounds(frameOrigin: origin, displayScale: s))

    XCTAssertEqual(tf.firstBaseline(frameOriginY: origin.y, displayScale: s),
                   ceilToScale(origin.y + tf.firstBaseline(frameOriginY: 0, displayScale: nil), s))

    XCTAssertEqual(tf.lastBaseline(frameOriginY: origin.y, displayScale: s),
                   ceilToScale(origin.y + tf.lastBaseline(frameOriginY: 0, displayScale: nil), s))

    if let ts = tf.displayScale {
      XCTAssertEqual(tf.firstBaseline(frameOriginY: origin.y),
                     ceilToScale(origin.y + tf.firstBaseline(frameOriginY: 0, displayScale: nil),
                                 ts))
      XCTAssertEqual(tf.lastBaseline(frameOriginY: origin.y),
                     ceilToScale(origin.y + tf.lastBaseline(frameOriginY: 0, displayScale: nil),
                                 ts))
    }

    for i in tf.lines.indices {
      let a = tf.lines[i]
      let b = tfo.lines[i]

      XCTAssertEqual(a.lineIndex, b.lineIndex)
      XCTAssertEqual(a.isFirstLine, b.isFirstLine)
      XCTAssertEqual(a.isLastLine, b.isLastLine)
      XCTAssertEqual(a.isFirstLineInParagraph, b.isFirstLineInParagraph)
      XCTAssertEqual(a.isLastLineInParagraph, b.isLastLineInParagraph)
      XCTAssertEqual(a.paragraphIndex, b.paragraphIndex)
      XCTAssertEqual(a.range, b.range)
      XCTAssertEqual(a.rangeInTruncatedString, b.rangeInTruncatedString)
      XCTAssertEqual(a.trailingWhitespaceInTruncatedStringUTF16Length,
                     b.trailingWhitespaceInTruncatedStringUTF16Length)
      XCTAssertEqual(a.rangeInOriginalString, b.rangeInOriginalString)
      XCTAssertEqual(a.excisedRangeInOriginalString, b.excisedRangeInOriginalString)
      XCTAssertEqual(a.isFollowedByTerminatorInOriginalString,
                     b.isFollowedByTerminatorInOriginalString)
      XCTAssertEqual(a.baselineOrigin(textFrameOrigin: origin, displayScale: s),
                     b.baselineOrigin)
      XCTAssertEqual(a.width, b.width)
      XCTAssertEqual(a.ascent, b.ascent)
      XCTAssertEqual(a.descent, b.descent)
      XCTAssertEqual(a.leading, b.leading)
      XCTAssertEqual(a.typographicBounds(textFrameOrigin: origin, displayScale: s),
                     b.typographicBounds)
      XCTAssertEqual(a.hasTruncationToken, b.hasTruncationToken)
      XCTAssertEqual(a.isTruncatedAsRightToLeftLine, b.isTruncatedAsRightToLeftLine)
      XCTAssertEqual(a.hasInsertedHyphen, b.hasInsertedHyphen)
      XCTAssertEqual(a.paragraphBaseWritingDirection, b.paragraphBaseWritingDirection)
      XCTAssertEqual(a.textFlags, b.textFlags)
      XCTAssertEqual(a.nonTokenTextFlags, b.nonTokenTextFlags)
      XCTAssertEqual(a.tokenTextFlags, b.tokenTextFlags)
      XCTAssertEqual(a.leftPartWidth, b.leftPartWidth)
      XCTAssertEqual(a.tokenWidth, b.tokenWidth)
    }

  }

  func testLayoutInfoConsistency(_ tf: STUTextFrame) {
    testLayoutInfoConsistency(tf, origin: .zero)
    testLayoutInfoConsistency(tf, origin: CGPoint(x: 100.25, y: 200))
    testLayoutInfoConsistency(tf, origin: CGPoint(x: 100.25, y: 201.75))
  }

  func testEmptyTextFrame() {
    let tf = STUTextFrame(STUShapedString.empty(withDefaultBaseWritingDirection: .leftToRight),
                          size: CGSize(width: 12, height: 34), displayScale: 5)
    let origin = CGPoint(x: 5, y: 6)
    let info = tf.layoutInfo(frameOrigin: CGPoint(x: 5, y: 6))
    XCTAssertEqual(info.lineCount, 0)
    XCTAssertEqual(tf.lines.count, 0)
    XCTAssertEqual(tf.paragraphs.count, 0)
    XCTAssertEqual(info.flags, [.hasMaxTypographicWidth])
    XCTAssertEqual(tf.flags, [.hasMaxTypographicWidth])
    XCTAssertEqual(info.layoutMode, .default)
    XCTAssertEqual(tf.layoutMode, .default)
    XCTAssertEqual(info.consistentAlignment, .left)
    XCTAssertEqual(tf.consistentAlignment, .left)
    XCTAssertEqual(info.textScaleFactor, 1)
    XCTAssertEqual(tf.textScaleFactor, 1)
    XCTAssertEqual(info.size, CGSize(width: 12, height: 34))
    XCTAssertEqual(tf.size, CGSize(width: 12, height: 34))
    XCTAssertEqual(info.minX, 5)
    XCTAssertEqual(info.maxX, 5)
    XCTAssertEqual(info.firstBaseline, 6)
    XCTAssertEqual(tf.firstBaseline(frameOriginY: origin.y), 6)
    XCTAssertEqual(info.lastBaseline, 6)
    XCTAssertEqual(tf.lastBaseline(frameOriginY: origin.y), 6)
    XCTAssertEqual(info.firstLineHeight, 0)
    XCTAssertEqual(tf.firstLineHeight, 0)
    XCTAssertEqual(info.firstLineHeightAboveBaseline, 0)
    XCTAssertEqual(tf.firstLineHeightAboveBaseline, 0)
    XCTAssertEqual(info.lastLineHeight, 0)
    XCTAssertEqual(tf.lastLineHeight, 0)
    XCTAssertEqual(info.lastLineHeightBelowBaseline, 0)
    XCTAssertEqual(tf.lastLineHeightBelowBaseline, 0)
    XCTAssertEqual(info.lastLineHeightBelowBaselineWithoutSpacing, 0)
    XCTAssertEqual(tf.lastLineHeightBelowBaselineWithoutSpacing, 0)
    XCTAssertEqual(info.lastLineHeightBelowBaselineWithMinimalSpacing, 0)
    XCTAssertEqual(tf.lastLineHeightBelowBaselineWithMinimalSpacing, 0)
    let bounds = tf.layoutBounds(frameOrigin: origin)
    XCTAssertEqual(bounds, info.layoutBounds)
  }


  func testLayoutInfo() {
    let font1  = UIFont(name: "HelveticaNeue", size: 20)!
    let font2  = UIFont(name: "HelveticaNeue", size: 16)!
    let font1b = UIFont(name: "GeezaPro", size: 20)!
    let font2b = UIFont(name: "GeezaPro", size: 16)!

    let g: CGFloat = 3
    assert(g > font1.leading)

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.lineSpacing = g

    let font1LineHeight = font1.ascender - font1.descender + g
    let font2LineHeight = font2.ascender - font2.descender + g


    ({
      let text = NSAttributedString("الاختبار 1", [.font: font1, .paragraphStyle: paraStyle])
      let width = STUTextFrame(STUShapedString(text), size: CGSize(width: 200, height: 100),
                               displayScale: 0, options: nil).layoutBounds.size.width/2
      let tf = STUTextFrame(STUShapedString(text), size: CGSize(width: width, height: 100),
                            displayScale: 3,
                            options: STUTextFrameOptions({ (b) in b.textLayoutMode = .textKit
                                                                  b.minimumTextScaleFactor = 0.1
                                                                  b.maximumNumberOfLines = 1 }))
      let s: CGFloat = 0.5
      XCTAssertEqual(tf.textScaleFactor, s)
      XCTAssertEqual(tf.lines.count, 1)

      XCTAssertEqual(tf.firstLineHeight, s*font1LineHeight, accuracyInFloat32ULP: 2)

      XCTAssertEqual(tf.firstLineHeightAboveBaseline, s*font1.ascender,
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lastLineHeightBelowBaseline, s*(-font1.descender + g),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lastLineHeightBelowBaselineWithMinimalSpacing,
                     s*(-font1.descender + font1.leading),
                     accuracyInFloat32ULP: 3)

      XCTAssertEqual(tf.lastLineHeightBelowBaselineWithoutSpacing, s*(-font1.descender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.firstBaseline, ceilToScale(s*font1.ascender, 3), accuracyInULP: 1)

      XCTAssertEqual(tf.lines.first!.ascent, s*max(font1.ascender, font1b.ascender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.first!.descent, s*max(-font1.descender, -font1b.descender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.first!.leading, s*max(font1.leading, font1b.leading),
                     accuracyInFloat32ULP: 1)

      testLayoutInfoConsistency(tf)
    })()


    ({
      let text = NSAttributedString([("الاختبار 1\n", [.font: font1]), ("الاختبار 2", [.font: font2])],
                                    [.paragraphStyle: paraStyle])

      let width = STUTextFrame(STUShapedString(text), size: CGSize(width: 200, height: 100),
                               displayScale: 0, options: nil).layoutBounds.size.width/2
      let tf = STUTextFrame(STUShapedString(text), size: CGSize(width: width, height: 100),
                            displayScale: 3,
                            options: STUTextFrameOptions({ (b) in b.textLayoutMode = .textKit
                                                                  b.minimumTextScaleFactor = 0.1
                                                                  b.maximumNumberOfLines = 2 }))
      let s: CGFloat = 0.5
      XCTAssertEqual(tf.textScaleFactor, s)
      XCTAssertEqual(tf.lines.count, 2)

      XCTAssertEqual(tf.firstLineHeight, s*font1LineHeight, accuracyInFloat32ULP: 2)
      XCTAssertEqual(tf.lastLineHeight, s*font2LineHeight, accuracyInFloat32ULP: 2)

      XCTAssertEqual(tf.firstLineHeightAboveBaseline, s*font1.ascender,
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lastLineHeightBelowBaseline, s*(-font2.descender + g),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lastLineHeightBelowBaselineWithMinimalSpacing,
                     s*(-font2.descender + font2.leading),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lastLineHeightBelowBaselineWithoutSpacing, s*(-font2.descender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.firstBaseline, ceilToScale(s*font1.ascender, 3), accuracyInULP: 1)

      XCTAssertEqual(tf.lastBaseline, ceilToScale(s*(font1LineHeight + font2.ascender), 3),
                     accuracyInULP: 1)

      XCTAssertEqual(tf.lines.first!.ascent, s*max(font1.ascender, font1b.ascender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.first!.descent, s*max(-font1.descender, -font1b.descender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.first!.leading, s*max(font1.leading, font1b.leading),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.last!.ascent, s*max(font2.ascender, font2b.ascender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.last!.descent, s*max(-font2.descender, -font2b.descender),
                     accuracyInFloat32ULP: 1)

      XCTAssertEqual(tf.lines.last!.leading, s*max(font2.leading, font2b.leading),
                     accuracyInFloat32ULP: 1)

      testLayoutInfoConsistency(tf)
    })()
  }

}
