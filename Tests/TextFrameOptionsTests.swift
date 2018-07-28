import STULabelSwift

class TextFrameOptionsTests : XCTestCase {
  func testInitializers() {
    let opts0 = STUTextFrameOptions()
    XCTAssertEqual(opts0.textLayoutMode, .default)
    XCTAssertEqual(opts0.defaultTextAlignment,
                   STUDefaultTextAlignment(rawValue: stu_defaultBaseWritingDirection().rawValue)!)
    XCTAssertEqual(opts0.maximumNumberOfLines, 0)
    XCTAssertEqual(opts0.lastLineTruncationMode, .end)
    XCTAssertEqual(opts0.truncationToken, nil)
    XCTAssert(opts0.truncationRangeAdjuster == nil)
    XCTAssertEqual(opts0.minimumTextScaleFactor, 1)
    XCTAssertEqual(opts0.textScalingBaselineAdjustment, .none)
    XCTAssert(opts0.lastHyphenationLocationInRangeFinder == nil)

    let opts0b = STUTextFrameOptions({ builder in })
    XCTAssertEqual(opts0b.textLayoutMode, .default)
    XCTAssertEqual(opts0b.defaultTextAlignment,
                   STUDefaultTextAlignment(rawValue: stu_defaultBaseWritingDirection().rawValue)!)
    XCTAssertEqual(opts0b.maximumNumberOfLines, 0)
    XCTAssertEqual(opts0b.lastLineTruncationMode, .end)
    XCTAssertEqual(opts0b.truncationToken, nil)
    XCTAssert(opts0b.truncationRangeAdjuster == nil)
    XCTAssertEqual(opts0b.minimumTextScaleFactor, 1)
    XCTAssertEqual(opts0b.textScalingBaselineAdjustment, .none)
    XCTAssert(opts0b.lastHyphenationLocationInRangeFinder == nil)

    let nonDefaultTruncationToken = NSAttributedString(string: "test")
    let nonDefaultTextAlignment =
      STUDefaultTextAlignment(rawValue: stu_defaultBaseWritingDirection().rawValue ^ 1)!

    let dummyTruncationRangeAdjuster: STUTruncationRangeAdjuster = { (_, _, r) in r }
    let dummyHyphenationLocationFinder: STULastHyphenationLocationInRangeFinder = { (_, _) in
      STUHyphenationLocation(index: 0, hyphen: UnicodeScalar("-")!.value, options: [])
    }
    let opts1 = STUTextFrameOptions({ builder in
      builder.textLayoutMode = .textKit
      builder.defaultTextAlignment = nonDefaultTextAlignment
      builder.maximumNumberOfLines = 3
      builder.lastLineTruncationMode = .middle
      builder.truncationToken = nonDefaultTruncationToken
      builder.truncationRangeAdjuster = dummyTruncationRangeAdjuster
      builder.minimumTextScaleFactor = 0.25
      builder.textScalingBaselineAdjustment = .alignFirstLineXHeightCenter
      builder.lastHyphenationLocationInRangeFinder = dummyHyphenationLocationFinder
    })
    XCTAssertEqual(opts1.textLayoutMode, .textKit)
    XCTAssertEqual(opts1.defaultTextAlignment, nonDefaultTextAlignment)
    XCTAssertEqual(opts1.maximumNumberOfLines, 3)
    XCTAssertEqual(opts1.lastLineTruncationMode, .middle)
    XCTAssertEqual(opts1.truncationToken, nonDefaultTruncationToken)
    XCTAssert(opts1.truncationRangeAdjuster != nil)
    XCTAssertEqual(opts1.minimumTextScaleFactor, 0.25)
    XCTAssertEqual(opts1.textScalingBaselineAdjustment, .alignFirstLineXHeightCenter)
    XCTAssert(opts1.lastHyphenationLocationInRangeFinder != nil)

    let opts1b = opts1.copy(updates: { (_: STUTextFrameOptionsBuilder) in })
    XCTAssertEqual(opts1b.textLayoutMode, .textKit)
    XCTAssertEqual(opts1b.defaultTextAlignment, nonDefaultTextAlignment)
    XCTAssertEqual(opts1b.maximumNumberOfLines, 3)
    XCTAssertEqual(opts1b.lastLineTruncationMode, .middle)
    XCTAssertEqual(opts1b.truncationToken, nonDefaultTruncationToken)
    XCTAssert(opts1b.truncationRangeAdjuster != nil)
    XCTAssertEqual(opts1b.minimumTextScaleFactor, 0.25)
    XCTAssertEqual(opts1b.textScalingBaselineAdjustment, .alignFirstLineXHeightCenter)
    XCTAssert(opts1b.lastHyphenationLocationInRangeFinder != nil)

    let opts2 = opts1b.copy { (builder) in builder.maximumNumberOfLines += 1 }
    XCTAssertEqual(opts2.textLayoutMode, .textKit)
    XCTAssertEqual(opts2.defaultTextAlignment, nonDefaultTextAlignment)
    XCTAssertEqual(opts2.maximumNumberOfLines, 4)
    XCTAssertEqual(opts2.lastLineTruncationMode, .middle)
    XCTAssertEqual(opts2.truncationToken, nonDefaultTruncationToken)
    XCTAssert(opts2.truncationRangeAdjuster != nil)
    XCTAssertEqual(opts2.minimumTextScaleFactor, 0.25)
    XCTAssertEqual(opts2.textScalingBaselineAdjustment, .alignFirstLineXHeightCenter)
    XCTAssert(opts2.lastHyphenationLocationInRangeFinder != nil)
  }

  func testParameterClamping() {
    let builder = STUTextFrameOptionsBuilder()
    builder.textLayoutMode = unsafeBitCast(UInt8(255), to: STUTextLayoutMode.self)
    XCTAssertEqual(builder.textLayoutMode, .default)

    builder.defaultTextAlignment = unsafeBitCast(UInt8(255), to: STUDefaultTextAlignment.self)
    XCTAssertEqual(builder.defaultTextAlignment, .left)

    builder.maximumNumberOfLines = .min
    XCTAssertEqual(builder.maximumNumberOfLines, 0)

    builder.maximumNumberOfLines = .max
    XCTAssertEqual(builder.maximumNumberOfLines, .max)

    builder.lastLineTruncationMode = unsafeBitCast(UInt8(255), to: STULastLineTruncationMode.self)
    XCTAssertEqual(builder.lastLineTruncationMode, .end)

    builder.minimumTextScaleFactor = 0
    XCTAssertEqual(builder.minimumTextScaleFactor, 1)
    builder.minimumTextScaleFactor = -1
    XCTAssertEqual(builder.minimumTextScaleFactor, 1)
    builder.minimumTextScaleFactor = 2
    XCTAssertEqual(builder.minimumTextScaleFactor, 1)
    builder.minimumTextScaleFactor = 0.5
    XCTAssertEqual(builder.minimumTextScaleFactor, 0.5)

    builder.textScalingBaselineAdjustment = unsafeBitCast(UInt8(255), to: STUBaselineAdjustment.self)
    XCTAssertEqual(builder.textScalingBaselineAdjustment, .none)

    builder.textScaleFactorStepSize = 0
    XCTAssertEqual(builder.textScaleFactorStepSize, 0)
    builder.textScaleFactorStepSize = -1
    XCTAssertEqual(builder.textScaleFactorStepSize, 0)
    builder.textScaleFactorStepSize = 2
    XCTAssertEqual(builder.textScaleFactorStepSize, 1)
  }

  func testTruncationTokenIsCopied() {
    let string = NSMutableAttributedString(string: "test")
    let builder = STUTextFrameOptionsBuilder()
    builder.truncationToken = string
    XCTAssert(builder.truncationToken !== string)
    XCTAssertEqual(builder.truncationToken, string)
    XCTAssert(!builder.truncationToken!.isKind(of: NSMutableAttributedString.self))
  }
}
