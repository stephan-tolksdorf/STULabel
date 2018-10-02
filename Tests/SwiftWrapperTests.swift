// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

class SwiftWrapperTests: XCTestCase {

  let font = UIFont(name: "HelveticaNeue", size: 20)!

  // Currently we just test here that these properties are actually callable (without causing a
  // linker error) and return the correct value in the simplest situation.
  func testTextFrameParagraphAndLineProperties() {
    let string = NSAttributedString("Test \r\n", [.font: font,
                                              .underlineStyle: NSUnderlineStyle.single.rawValue])
    let tf = STUTextFrame(STUShapedString(string),
                          size: CGSize(width: 100, height: 50),
                          displayScale: 0)

    let para = tf.paragraphs[0]
    XCTAssertEqual(para.paragraphIndex, 0)
    XCTAssertEqual(para.lineIndexRange, 0..<1)
    XCTAssertEqual(para.initialLinesIndexRange, 0..<1)
    XCTAssertEqual(para.nonInitialLinesIndexRange, 1..<1)
    XCTAssertEqual(para.lines.indices, para.lineIndexRange)
    XCTAssertEqual(para.initialLines.indices, para.initialLinesIndexRange)
    XCTAssertEqual(para.nonInitialLines.indices, para.nonInitialLinesIndexRange)
    XCTAssertEqual(para.rangeInOriginalString, NSRange(0..<7))
    XCTAssertEqual(para.excisedRangeInOriginalString, NSRange(7..<7))
    XCTAssertEqual(para.rangeInTruncatedString, NSRange(0..<7))
    XCTAssertEqual(para.truncationTokenUTF16Length, 0)
    XCTAssertEqual(para.textFlags, [.hasUnderline])
    XCTAssertEqual(para.alignment, .left)
    XCTAssertEqual(para.baseWritingDirection, .leftToRight)
    XCTAssertEqual(para.isFirstParagraph, true)
    XCTAssertEqual(para.isLastParagraph, true)
    XCTAssertEqual(para.excisedStringRangeIsContinuedInNextParagraph, false)
    XCTAssertEqual(para.excisedStringRangeIsContinuationFromLastParagraph, false)
    XCTAssertEqual(para.paragraphTerminatorInOriginalStringUTF16Length, 2)
    XCTAssertEqual(para.isIndented, false)
    XCTAssertEqual(para.initialLinesLeftIndent, 0)
    XCTAssertEqual(para.initialLinesRightIndent, 0)
    XCTAssertEqual(para.nonInitialLinesLeftIndent, 0)
    XCTAssertEqual(para.nonInitialLinesRightIndent, 0)

    let line = tf.lines[0]
    XCTAssertEqual(line.lineIndex, 0)
    XCTAssertEqual(line.paragraphIndex, 0)
    XCTAssertEqual(line.rangeInOriginalString, NSRange(0..<4))
    XCTAssertEqual(line.rangeInTruncatedString, NSRange(0..<4))
    XCTAssertEqual(line.trailingWhitespaceInTruncatedStringUTF16Length, 3)
    XCTAssertEqual(line.isFollowedByTerminatorInOriginalString, true)
    XCTAssertEqual(line.textFlags, [.hasUnderline])
    XCTAssertEqual(line.nonTokenTextFlags, [.hasUnderline])
    XCTAssertEqual(line.tokenTextFlags, [])
    XCTAssertEqual(line.paragraphBaseWritingDirection, .leftToRight)
    XCTAssertEqual(line.isFirstLine, true)
    XCTAssertEqual(line.isLastLine, true)
    XCTAssertEqual(line.isFirstLineInParagraph, true)
    XCTAssertEqual(line.isLastLineInParagraph, true)
    XCTAssertEqual(line.isInitialLineInParagraph, true)
    XCTAssertEqual(line.hasInsertedHyphen, false)
    XCTAssertEqual(line.isTruncatedAsRightToLeftLine, false)
    XCTAssertEqual(line.width,
                   tf.rects(for: tf.indices, frameOrigin: .zero).bounds.width)
    XCTAssertEqual(line.baselineOrigin.x, 0)

    let expectedLeading = 2*max(CGFloat(Float64(line.ascent) + Float64(line.leading)/2
                                        - Float64(line.ascent)),
                                CGFloat(Float64(line.descent) + Float64(line.leading)/2
                                        - Float64(line.descent)))

    let expectedOriginY = CGFloat(Float32(font.ascender + expectedLeading/2))
    XCTAssertEqual(line.baselineOrigin.y, expectedOriginY)

    XCTAssertEqual(line.ascent, CGFloat(Float32(font.ascender)))
    XCTAssertEqual(line.descent, CGFloat(Float32(-font.descender)))
    XCTAssertEqual(line.leading, expectedLeading)
  }
}
