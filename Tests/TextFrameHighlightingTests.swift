// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import XCTest

class TextFrameHighlightingTests: SnapshotTestCase {
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
                  ?? STUTextFrameOptions({ builder in builder.defaultTextAlignment = .start })
    let frame = STUTextFrame(STUShapedString(attributedString,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 10000),
                             displayScale: displayScale,
                             options: options)
    return frame
  }

  @nonobjc
  func textFrame(_ string: String, width: CGFloat = 1000,
                 attributes: [NSAttributedStringKey: Any] = [:]) -> STUTextFrame
  {
    var attributes = attributes
    if attributes[.font] == nil {
      attributes[.font] = font
    }
    return textFrame(NSAttributedString(string, attributes), width: width)
  }

  @nonobjc
  func typographicWidth(_ string: String, width: CGFloat = 1000) -> CGFloat {
    return textFrame(string, width: width).layoutInfo.layoutBounds.size.width
  }


  func image(_ textFrame: STUTextFrame,
             _ range: Range<STUTextFrame.Index>? = nil,
             _ highlight: (Range<STUTextFrame.Index>, STUTextHighlightStyle)? = nil) -> UIImage
  {
    var bounds = textFrame.layoutInfo.layoutBounds
    bounds.origin.x    = floor(bounds.origin.x*2)/2
    bounds.origin.y    = floor(bounds.origin.y*2)/2
    bounds.size.width  = ceil(bounds.size.width*2)/2
    bounds.size.height = ceil(bounds.size.height*2)/2
    bounds = bounds.insetBy(dx: -5, dy: -5)
    return createImage(bounds.size, scale: displayScale, backgroundColor: .white, .rgb, { context in
             let range = range ?? textFrame.indices
             if let (highlightRange, style) = highlight {
              let options = STUTextFrame.DrawingOptions()
              options.setHighlightRange(highlightRange)
              options.highlightStyle = style
              textFrame.draw(range: range, at: -bounds.origin, in: context, isVectorContext: false,
                             contextBaseCTM_d: 1, options: options)
             } else {
              textFrame.draw(range: range, at: -bounds.origin, in: context, isVectorContext: false,
                             contextBaseCTM_d: 1)
             }
           })
  }
  
  func testTruncatedLineHighlighting() {
    let string = NSMutableAttributedString()
    string.append(NSAttributedString("012", [.font: font, .foregroundColor: UIColor.magenta]))
    string.append(NSAttributedString("345____", [.font: font, .foregroundColor: UIColor.green]))
    string.append(NSAttributedString("abc", [.font: font, .foregroundColor: UIColor.cyan]))
    string.append(NSAttributedString("def", [.font: font, .foregroundColor: UIColor.blue]))
    let token = NSMutableAttributedString()
    token.append(NSAttributedString("6", [.font: font, .foregroundColor: UIColor.black]))
    token.append(NSAttributedString("78", [.font: font, .foregroundColor: UIColor.black]))
    let frameWidth = typographicWidth("012345678abcdef") + 2
    let f = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                         size: CGSize(width: frameWidth, height: 100),
                         displayScale: displayScale,
                         options: STUTextFrameOptions({b in
                                                         b.maxLineCount = 1
                                                         b.lastLineTruncationMode = .middle
                                                         b.truncationToken = token}))
    self.checkSnapshotImage(image(f), suffix: "_no-highlighting")
    let hs = STUTextHighlightStyle({b in b.setUnderlineStyle(.styleSingle, color: nil)
                                         b.textColor = .red})
    self.checkSnapshotImage(image(f, nil, (f.indices, hs)), suffix: "_all-red")
    self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(0...1)), hs)),
                                           suffix: "_0-1-red")
    self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(4...4)), hs)),
                                           suffix: "_4-red")
    self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString:NSRange(2...4)),
                                  (f.range(forRangeInOriginalString: NSRange(4...4)), hs)),
                                  suffix: "_2-4-drawn_4-red")
    self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString:NSRange(5...10)),
                                  (f.range(forRangeInTruncatedString: NSRange(7...7)), hs)),
                                  suffix: "_5-a-drawn_7-red")
    self.checkSnapshotImage(image(f, nil, (f.range(forRangeInTruncatedString: NSRange(12...12)), hs)),
                            suffix: "_d-red")
  }

  func testHyphenHighlighting() {
    let f = textFrame("Te\u{ad}st", width: typographicWidth("Test") - 1)
    let hyphenIndex = STUTextFrame.Index(utf16IndexInTruncatedString: 2,
                                         isIndexOfInsertedHyphen: true,
                                         lineIndex: 0)
    let indexAfterHyphen = STUTextFrame.Index(utf16IndexInTruncatedString: 3,
                                              isIndexOfInsertedHyphen: false,
                                              lineIndex: 0)
    let hs = STUTextHighlightStyle({b in b.setUnderlineStyle(.styleSingle, color: nil)
                                         b.textColor = .red})
    self.checkSnapshotImage(image(f, nil, (f.indices, hs)), suffix: "_all-red")
    self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString:NSRange(1...3)),
                                  (hyphenIndex..<indexAfterHyphen, hs)),
                            suffix: "_1-3-drawn_hyphen-red")
    self.checkSnapshotImage(image(f, hyphenIndex..<indexAfterHyphen, nil),
                            suffix: "_black-hyphen-only")
  }

  func testNonMonotonicRunHighlighting() {
    let f = textFrame("ट्ट्ठिट्ट्ठि")
    let hs = STUTextHighlightStyle({b in b.setUnderlineStyle(.styleSingle, color: nil)
                                         b.textColor = .red})
    let ctVersion = CTGetCoreTextVersion()
    let suffix = kCTVersionNumber10_12 <= ctVersion && ctVersion <= kCTVersionNumber10_13
               ? "_iOS10" : ""
    self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(0...4)), hs)),
                            suffix: "_0-4-red" + suffix)
    self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString: NSRange(4...9)),
                                  (f.range(forRangeInOriginalString: NSRange(5...6)), hs)),
                            suffix: "_4-9-drawn_5-6-red" + suffix)
  }

  func testPartialLigatureHighlighting() {
    let hs = STUTextHighlightStyle({b in b.setUnderlineStyle(.styleSingle, color: nil)
                                         b.textColor = .red});
    {
      // Hoefler Text contains caret positions for ligatures.
      let f = textFrame(NSAttributedString("ffiffk", [.font: UIFont(name: "HoeflerText-Regular", size: 18)!]))

      let suffix = MemoryLayout<Int>.size == 4 ? "_32bit" : ""
      self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(1...1)), hs)),
                              suffix: "_1-red" + suffix)
      self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(1...4)), hs)),
                              suffix: "_1-4-red" + suffix)
      self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString: NSRange(2...3)),
                                    (f.range(forRangeInOriginalString: NSRange(2...2)), hs)), suffix: "_2-3-drawn_2-red")
    }();
    {
      // Helvetica Neue does not contains caret positions for ligatures.
      let f = textFrame(NSAttributedString("fi\u{2060}fi", [.font: UIFont(name: "HelveticaNeue", size: 18)!]))
      self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(1...3)), hs)), suffix: "_1-2-red")
      self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(3...4)), hs)), suffix: "_2-3-red")
    }();
  }

  func testRightToLeftLineHighlighting() {
    let f = textFrame("עִברִית")
    let hs = STUTextHighlightStyle({b in b.setUnderlineStyle(.styleSingle, color: nil)
                                         b.textColor = .red})
    self.checkSnapshotImage(image(f, nil, (f.range(forRangeInOriginalString: NSRange(2...4)), hs)), suffix: "_2-4-red")
    self.checkSnapshotImage(image(f, f.range(forRangeInOriginalString: NSRange(2...6)),
                                  (f.range(forRangeInOriginalString: NSRange(5...6)), hs)),
                            suffix: "_2-6-drawn_5-6-red")  }
}
