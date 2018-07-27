import STULabelSwift

class TextAttachmentTests: SnapshotTestCase {
  func testInitializerAndEncode() {
    let attachment = STUTextAttachment(width: 1.25, ascent: 2, descent: 3, leading: 4,
                                       imageBounds: CGRect(x: 5, y: 6, width: 7, height: 8),
                                       colorInfo: [.isGrayscale,  .usesExtendedColors],
                                       stringRepresentation: "test")
    XCTAssertEqual(attachment.width, 1.25)
    XCTAssertEqual(attachment.ascent, 2)
    XCTAssertEqual(attachment.descent, 3)
    XCTAssertEqual(attachment.leading, 4)
    XCTAssertEqual(attachment.typographicBounds, CGRect(x: 0, y: -4, width: 1.25, height: 9))
    XCTAssertEqual(attachment.imageBounds, CGRect(x: 5, y: 6, width: 7, height: 8))
    XCTAssertEqual(attachment.colorInfo, [.isGrayscale,  .usesExtendedColors])
    XCTAssertEqual(attachment.stringRepresentation, "test")

    let data = NSKeyedArchiver.archivedData(withRootObject: attachment)
    let attachment2 = NSKeyedUnarchiver.unarchiveObject(with: data) as! STUTextAttachment

    XCTAssertEqual(attachment2.width, 1.25)
    XCTAssertEqual(attachment2.ascent, 2)
    XCTAssertEqual(attachment2.descent, 3)
    XCTAssertEqual(attachment2.leading, 4)
    XCTAssertEqual(attachment2.imageBounds, CGRect(x: 5, y: 6, width: 7, height: 8))
    XCTAssertEqual(attachment2.colorInfo, [.isGrayscale,  .usesExtendedColors])
    XCTAssertEqual(attachment2.stringRepresentation, "test")

    XCTAssert(!attachment2.isAccessibilityElement)

    attachment2.isAccessibilityElement = true
    if #available(iOS 11, tvOS 11, *) {
      attachment2.accessibilityAttributedLabel = NSAttributedString("label", [.baselineOffset:1])
      attachment2.accessibilityAttributedHint = NSAttributedString("hint", [.baselineOffset:2])
      attachment2.accessibilityAttributedValue = NSAttributedString("value", [.baselineOffset:3])
    } else {
      attachment2.accessibilityLabel = "label"
      attachment2.accessibilityHint = "hint"
      attachment2.accessibilityValue = "value"
    }
    attachment2.accessibilityLanguage = "language"

    let data2 = NSKeyedArchiver.archivedData(withRootObject: attachment2)
    let attachment3 = NSKeyedUnarchiver.unarchiveObject(with: data2) as! STUTextAttachment


    XCTAssertEqual(attachment3.isAccessibilityElement, true)

    if #available(iOS 11, tvOS 11, *) {
      XCTAssertEqual(attachment3.accessibilityAttributedLabel,
                     NSAttributedString("label", [.baselineOffset:1]))
      XCTAssertEqual(attachment3.accessibilityAttributedHint,
                     NSAttributedString("hint", [.baselineOffset:2]))
      XCTAssertEqual(attachment3.accessibilityAttributedValue,
                     NSAttributedString("value", [.baselineOffset:3]))
    } else {
      XCTAssertEqual(attachment3.accessibilityLabel, "label")
      XCTAssertEqual(attachment3.accessibilityHint, "hint")
      XCTAssertEqual(attachment3.accessibilityValue, "value")
    }
    XCTAssertEqual(attachment3.accessibilityLanguage, "language")
  }

  func testImageAttachmentInitializerAndEncode() {
    let imageSize = CGSize(width: 30, height: 20)
    let image = createTestImage(imageSize)

    let attachment1 = STUImageTextAttachment(image: image, verticalOffset: 0,
                                             stringRepresentation: "test")
    XCTAssertEqual(attachment1.width, imageSize.width)
    XCTAssertEqual(attachment1.ascent, imageSize.height)
    XCTAssertEqual(attachment1.descent, 0)
    XCTAssertEqual(attachment1.leading, 0)
    XCTAssertEqual(attachment1.imageBounds, CGRect(origin: CGPoint(x: 0, y: -imageSize.height),
                                                   size: imageSize))
    XCTAssertEqual(attachment1.colorInfo, STUTextAttachmentColorInfo())
  }

  let displayScale: CGFloat = 2

  func textFrame(_ attributedString: NSAttributedString, width: CGFloat = 1000) -> STUTextFrame {
    let options = STUTextFrameOptions({ builder in builder.defaultTextAlignment = .left })
    let frame = STUTextFrame(STUShapedString(attributedString,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 10000),
                             displayScale: displayScale,
                             options: options)
    return frame
  }

  func textFrame(_ string: String, width: CGFloat = 1000,
                 attributes: StringAttributes = [:]) -> STUTextFrame
  {
    var attributes = attributes
    if attributes[.font] == nil {
      attributes[.font] = UIFont(name: "HelveticaNeue", size: 20)!
    }
    return textFrame(NSAttributedString(string, attributes), width: width)
  }

  func typographicWidth(_ string: String, width: CGFloat = 1000) -> CGFloat {
    return textFrame(string, width: width).layoutInfo.layoutBounds.size.width
  }

  func image(_ textFrame: STUTextFrame, padding: CGFloat = 5) -> UIImage {
    let bounds = ceilToScale(textFrame.layoutInfo.layoutBounds, displayScale).insetBy(-padding)
    return createImage(bounds.size, scale: displayScale, backgroundColor: .white, .rgb, { context in
              textFrame.draw(at: -bounds.origin, in: context, contextBaseCTM_d: 1,
                             pixelAlignBaselines: true)
           })
  }

  func createTestImage(_ size: CGSize,
                       _ color1: UIColor = UIColor.yellow,
                       _ color2: UIColor = UIColor.blue,
                       format: STUCGImageFormat.Predefined = .rgb) -> UIImage
  {
    return createImage(size, scale: displayScale, format) { (context) in
      context.setFillColor(color1.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height/2))
      context.setFillColor(color2.cgColor)
      context.fill(CGRect(x: 0, y: size.height/2, width: size.width, height: size.height/2))
    }
  }
}
