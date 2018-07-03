// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import CoreText

import XCTest

class TextFrameImageBoundsTests: SnapshotTestCase {

  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  func testCTRunAndCTLineImageBoundsDoNotAccuntForStrokeAndUnderlineDecorations() {
    func ctLine(_ string: String, _ attributes: [NSAttributedStringKey: Any]) -> CTLine {
      return CTLineCreateWithAttributedString(NSAttributedString(string, attributes))
    }

    let line  = ctLine("x", [:])
    let strokedLine = ctLine("x", [.strokeColor: UIColor.black, .strokeWidth: 100])
    let underlinedLine = ctLine("x", [.underlineStyle: NSUnderlineStyle.styleThick.rawValue])

    XCTAssertEqual(CTLineGetImageBounds(line, nil), CTLineGetImageBounds(strokedLine, nil))
    XCTAssertEqual(CTLineGetImageBounds(line, nil), CTLineGetImageBounds(underlinedLine, nil))
  }

  // TODO

}
