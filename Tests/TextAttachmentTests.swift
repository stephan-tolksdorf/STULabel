import STULabelSwift

class TextAttachmentTests: SnapshotTestCase {
  override func setUp() {
    super.setUp()
    self.imageBaseDirectory = pathRelativeToCurrentSourceDir("ReferenceImages")
  }

  func createTestImage(_ size: CGSize,
                       _ color1: UIColor = UIColor.yellow,
                       _ color2: UIColor = UIColor.blue,
                       format: STUCGImageFormat.Predefined = .rgb) -> UIImage
  {
    return createImage(size, scale: displayScale, backgroundColor: color1, format) { (context) in
      context.setFillColor(color2.cgColor)
      context.fill(CGRect(x: 0, y: size.height/2, width: size.width, height: size.height/2))
    }
  }

  let displayScale: CGFloat = 2

  func image(_ tf: STUTextFrame) -> UIImage {
    let bounds = ceilToScale(tf.layoutBounds, displayScale)
    let format: STUCGImageFormat.Predefined = !tf.flags.contains(.mayNotBeGrayscale) ? .grayscale
                                            : tf.flags.contains(.usesExtendedColor) ? .extendedRGB
                                            : .rgb
    print(bounds, tf.imageBounds(frameOrigin: .zero, displayScale: 2))

    return createImage(bounds.size, scale: displayScale, backgroundColor: .white, format, { context in
              tf.draw(at: -bounds.origin, in: context, contextBaseCTM_d: 1,
                      pixelAlignBaselines: true)
           })
  }

  let font = UIFont(name: "HelveticaNeue", size: 20)!

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
    let grayscaleImage = createTestImage(imageSize, format: .grayscale)
    let extendedRGBImage = createTestImage(imageSize,
                                           UIColor(red: 1.5, green: 0, blue: 0, alpha: 1),
                                           UIColor(red: 0, green: 0, blue: 1.5, alpha: 1),
                                           format: .extendedRGB)

    let attachment1 = STUImageTextAttachment(image: grayscaleImage, verticalOffset: 0,
                                             stringRepresentation: "test")
    XCTAssertEqual(attachment1.width, imageSize.width)
    XCTAssertEqual(attachment1.ascent, imageSize.height)
    XCTAssertEqual(attachment1.descent, 0)
    XCTAssertEqual(attachment1.leading, 0)
    XCTAssertEqual(attachment1.imageBounds, CGRect(origin: CGPoint(x: 0, y: -imageSize.height),
                                                   size: imageSize))
    XCTAssertEqual(attachment1.colorInfo, [.isGrayscale])
    XCTAssertEqual(attachment1.stringRepresentation, "test")
    XCTAssertEqual(attachment1.image, grayscaleImage);

    let offset = imageSize.height/2

    let attachment2 = STUImageTextAttachment(image: extendedRGBImage,
                                             imageSize: imageSize,
                                             verticalOffset: offset,
                                             padding: UIEdgeInsets(top: 1, left: 2,
                                                                   bottom: 3, right: 4),
                                             leading: 5,
                                             stringRepresentation: "test 2")
    XCTAssertEqual(attachment2.width, imageSize.width + 2 + 4)
    XCTAssertEqual(attachment2.ascent, imageSize.height + 1 - offset)
    XCTAssertEqual(attachment2.descent, 3 + offset)
    XCTAssertEqual(attachment2.leading, 5)
    XCTAssertEqual(attachment2.imageBounds, CGRect(origin: CGPoint(x: 2, y: offset - imageSize.height),
                                                   size: imageSize))
    if #available(iOS 10, tvOS 10, macOS 10.12, *) {
      XCTAssertEqual(attachment2.colorInfo, [.usesExtendedColors])
    } else {
      XCTAssertEqual(attachment2.colorInfo, [])
    }
    XCTAssertEqual(attachment2.stringRepresentation, "test 2")
    XCTAssertEqual(attachment2.image, extendedRGBImage);

    let data = NSKeyedArchiver.archivedData(withRootObject: attachment2)
    let attachment3 = NSKeyedUnarchiver.unarchiveObject(with: data) as! STUImageTextAttachment

    XCTAssertEqual(attachment3.width, imageSize.width + 2 + 4)
    XCTAssertEqual(attachment3.ascent, imageSize.height + 1 - offset)
    XCTAssertEqual(attachment3.descent, 3 + offset)
    XCTAssertEqual(attachment3.leading, 5)
    XCTAssertEqual(attachment3.imageBounds, CGRect(origin: CGPoint(x: 2, y: offset - imageSize.height),
                                                   size: imageSize))
    if #available(iOS 10, tvOS 10, macOS 10.12, *) {
      XCTAssertEqual(attachment3.colorInfo, [.usesExtendedColors])
    } else {
      XCTAssertEqual(attachment3.colorInfo, [])
    }
    XCTAssertEqual(attachment3.stringRepresentation, "test 2")
    XCTAssertEqual(attachment3.image.pngData(), extendedRGBImage.pngData())

    let tf = STUTextFrame(STUShapedString(NSAttributedString(stu_attachment: attachment3),
                                          defaultBaseWritingDirection: .leftToRight),
                          size: CGSize(width: 100, height: 100), displayScale: 0)
    XCTAssertEqual(tf.lines.count, 1)
    XCTAssert(tf.lines[0].nonTokenTextFlags.contains(.hasAttachment))
    if #available(iOS 10, tvOS 10, macOS 10.12, *) {
      XCTAssert(tf.flags.contains(.usesExtendedColor))
    }
    XCTAssertEqual(tf.lines[0].rangeInOriginalString, NSRange(0..<1))
    XCTAssertEqual(tf.lines[0].ascent, imageSize.height + 1 - offset)
    XCTAssertEqual(tf.lines[0].descent, 3 + offset)
    XCTAssertEqual(tf.lines[0].leading, 5)
    XCTAssertEqual(tf.lines[0].width, imageSize.width + 2 + 4)
    XCTAssertEqual(tf.imageBounds(frameOrigin: .zero),
                   CGRect(origin: CGPoint(x: 2,
                                          y: offset - imageSize.height
                                             + tf.lines[0].baselineOrigin.y),
                          size: imageSize))
    let suffix: String
    if #available(iOS 11, tvOS 11, macOS 10.13, *) {
      suffix = ""
    } else if #available(iOS 10, tvOS 10, macOS 10.12, *) {
      // TODO: Find out why we need a different image for iOS 10.
      suffix = "_iOS10"
    } else {
      suffix = "_iOS9"
    }
    checkSnapshotImage(self.image(tf), suffix: suffix);
  }

  func testAttachmentConversion() {
    let attachmentImage = createTestImage(CGSize(width: 10, height: 10))
    let attachment = NSTextAttachment()
    attachment.image = attachmentImage
    let attachmentString = NSAttributedString(attachment: attachment)
    let text = NSMutableAttributedString()
    text.append(attachmentString)
    text.append(NSAttributedString("L", [.font: font]))
    text.append(attachmentString)
    text.append(attachmentString)
    let shapedString = STUShapedString(text)
    XCTAssertEqual(shapedString.attributedString.attribute(fixForRDAR36622225Key, at: 3,
                                                           effectiveRange: nil) as! Int,
                   1)
    let tf = STUTextFrame(STUShapedString(text), size: CGSize(width: 100, height: 50),
                          displayScale: displayScale, options: nil)
    let suffix = MemoryLayout<Int>.size == 4 ? "_32bit" : ""
    self.checkSnapshotImage(image(tf), suffix: suffix)
  }

  func testAttachmentsInTruncationToken() {
    let attachmentImage = createTestImage(CGSize(width: 10, height: 10))
    let attachment = NSTextAttachment()
    attachment.image = attachmentImage
    let attachmentString = NSAttributedString(attachment: attachment)
    let token = NSMutableAttributedString()
    token.append(attachmentString)
    token.append(NSAttributedString("L", [.font: font]))
    token.append(attachmentString)
    token.append(attachmentString)
    let text = NSAttributedString("This text doesn't fit", [.font: font])
    let options = STUTextFrameOptions({ b in
      b.maximumNumberOfLines = 1
      b.truncationToken = token
    })
    let tf = STUTextFrame(STUShapedString(text), size: CGSize(width: 100, height: 50),
                          displayScale: displayScale, options: options)
    let suffix = MemoryLayout<Int>.size == 4 ? "_32bit" : ""
    self.checkSnapshotImage(image(tf), suffix: suffix)
  }

  let ctRunDelegateKey = kCTRunDelegateAttributeName as NSAttributedString.Key
  let fixForRDAR36622225Key = NSAttributedString.Key(rawValue: "Fix for rdar://36622225");

  func testAttributedStringByConvertingNSTextAttachmentsToSTUTextAttachments() {
    {
      let string = NSAttributedString()
      XCTAssert(string.stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments()
                === string);
    }();

    {
      let string = NSMutableAttributedString(string: "test")
      let result = string.stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments()
      XCTAssertEqual(result, string);
      XCTAssert(string !== result)
    }();
    {
      let nsAttachment = NSTextAttachment()
      let string = NSAttributedString(attachment: nsAttachment)
      XCTAssertEqual(string.stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments(),
                     string);

      nsAttachment.image = createTestImage(CGSize(width: 1, height: 1))
      let result = string.stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments()
      XCTAssert(result.attribute(.stuAttachment, at: 0, effectiveRange: nil) != nil)
      XCTAssert(result.attribute(ctRunDelegateKey, at: 0, effectiveRange: nil) != nil)
    }();
    {
      let nsAttachment = NSTextAttachment()
      nsAttachment.image = createTestImage(CGSize(width: 1, height: 1))
      let string = NSMutableAttributedString()
      string.append(NSAttributedString("abc", [.attachment: nsAttachment]))
      string.append(NSAttributedString("d", [:]))
      string.append(NSAttributedString("e", [.attachment: nsAttachment]))
      string.append(NSAttributedString("f", [.attachment: nsAttachment]))
      let result = string.stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments()
      for i in [0, 1, 2, 4, 5] {
        XCTAssert(result.attribute(.stuAttachment, at: i, effectiveRange: nil) != nil)
        XCTAssert(result.attribute(ctRunDelegateKey, at: i, effectiveRange: nil) != nil)
      }
      XCTAssert(result.attribute(fixForRDAR36622225Key, at: 1, effectiveRange: nil) as! Int == 1)
      XCTAssert(result.attribute(fixForRDAR36622225Key, at: 2, effectiveRange: nil) as! Int == 2)
      XCTAssert(result.attribute(fixForRDAR36622225Key, at: 5, effectiveRange: nil) as! Int == 1)
    }();
  }

  func testAttributedStringByAddingCTRunDelegatesForSTUTextAttachments() {
    {
      let string = NSAttributedString()
      XCTAssert(string.stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments()
                === string);
    }();

    {
      let string = NSMutableAttributedString(string: "test")
      let result = string.stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments()
      XCTAssertEqual(result, string);
      XCTAssert(string !== result)
    }();

    let attachment = STUTextAttachment(width: 1, ascent: 1, descent: 1, leading: 1,
                                       imageBounds: CGRect(), colorInfo: [],
                                       stringRepresentation: nil)
    let string = NSAttributedString([("a", [.stuAttachment: attachment]),
                                     ("b", [:]),
                                     ("cde", [.stuAttachment: attachment,
                                              fixForRDAR36622225Key: 0])])
    let result = string.stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments()
    let expected = NSAttributedString([("a", [.stuAttachment: attachment,
                                              ctRunDelegateKey: attachment.newCTRunDelegate()]),
                                       ("b", [:]),
                                       ("c", [.stuAttachment: attachment,
                                              ctRunDelegateKey: attachment.newCTRunDelegate()]),
                                       ("d", [.stuAttachment: attachment,
                                              ctRunDelegateKey: attachment.newCTRunDelegate(),
                                              fixForRDAR36622225Key: 1]),
                                       ("e", [.stuAttachment: attachment,
                                              ctRunDelegateKey: attachment.newCTRunDelegate(),
                                              fixForRDAR36622225Key: 2])])
    XCTAssertEqual(result.string, expected.string)
    for i in 0..<expected.length {
      let attributes = expected.attributes(at: i, effectiveRange: nil)
      for (key, value) in attributes {
        XCTAssertEqual(result.attribute(key, at: i, effectiveRange: nil) as! NSObject,
                       value as! NSObject)
      }
    }
  }

  func testAttributedStringByRemovingCTRunDelegates() {
    {
      let string = NSAttributedString()
      XCTAssert(string.stu_attributedStringByRemovingCTRunDelegates()
                === string);
    }();

    {
      let string = NSMutableAttributedString(string: "test")
      let result = string.stu_attributedStringByRemovingCTRunDelegates()
      XCTAssertEqual(result, string);
      XCTAssert(string !== result)
    }();

    let attachment = STUTextAttachment(width: 1, ascent: 1, descent: 1, leading: 1,
                                       imageBounds: CGRect(), colorInfo: [],
                                       stringRepresentation: nil)
    let delegate = attachment.newCTRunDelegate

    let string = NSAttributedString([("a", [ctRunDelegateKey: delegate]),
                                     ("b", [:]),
                                     ("cde", [ctRunDelegateKey: delegate])])
    XCTAssertEqual(string.stu_attributedStringByRemovingCTRunDelegates(),
                   NSAttributedString(string: "abcde"))
  }

  func testAttributedStringByReplacingSTUAttachmentsWithStringRepresentations() {
    {
      let string = NSAttributedString()
      XCTAssert(string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
                === string);
    }();

    {
      let string = NSMutableAttributedString(string: "test")
      let result = string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
      XCTAssertEqual(result, string);
      XCTAssert(string !== result)
    }();

    func attachment(_ stringRepresentation: String?) -> NSAttributedString {
      return NSAttributedString(stu_attachment:
               STUTextAttachment(width: 10, ascent: 5, descent: 5, leading: 0,
                                 imageBounds: CGRect(), colorInfo: [],
                                 stringRepresentation: stringRepresentation))
    }
    {
      let string = attachment(nil)
      XCTAssertEqual(string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations(),
                     NSAttributedString())
    }();
    {
      let string = NSMutableAttributedString()
      let a = attachment(nil)
      string.append(a)
      string.append(a)
      string.append(a)
      string.append(NSAttributedString("x", [.font: font]))
      string.append(a)
      string.append(a)
      string.append(a)
      let result = string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
      let expected = NSAttributedString("x", [.font: font])
      XCTAssertEqual(result.string, expected.string)
      XCTAssertEqual(result, expected)
    }();
    {
      let string = NSMutableAttributedString()
      let a = attachment("a")
      string.append(a)
      string.append(a)
      string.append(a)
      string.append(NSAttributedString("test", [.font: font]))
      let result = string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
      let expected = NSAttributedString("aaatest", [.font: font])
      XCTAssertEqual(result, expected)
    }();
    {
      let string = NSMutableAttributedString()
      let a = attachment("a")
      let b = attachment("b")
      string.append(a)
      string.append(a)
      string.append(a)
      string.append(b)
      string.append(b)
      string.append(b)
      let result = string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
      let expected = NSAttributedString(string: "aaabbb")
      XCTAssertEqual(result, expected)
    }();
    {
      let string = NSMutableAttributedString()
      string.append(NSAttributedString("a", [.font: font]))
      string.append(attachment(nil))
      string.append(NSAttributedString("b ", [.font: font]))
      string.append(attachment(nil))
      string.append(NSAttributedString("c", [.font: font]))
      string.append(attachment(nil))
      string.append(NSAttributedString(" d", [.font: font]))
      string.append(attachment(nil))
      string.append(attachment(nil))
      string.append(NSAttributedString("e", [.font: font]))
      string.append(attachment("<"))
      string.append(attachment(">"))
      string.append(NSAttributedString("f", [.font: font]))
      let result = string.stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations()
      let expected = NSAttributedString("a b c d e<>f", [.font: font])
      XCTAssertEqual(result.string, expected.string)
      XCTAssertEqual(result, expected)
    }();

  }
}
