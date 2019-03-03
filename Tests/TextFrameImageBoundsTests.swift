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
    func ctLine(_ string: String, _ attributes: StringAttributes) -> CTLine {
      return CTLineCreateWithAttributedString(NSAttributedString(string, attributes))
    }

    let line  = ctLine("x", [:])
    let strokedLine = ctLine("x", [.strokeColor: UIColor.black, .strokeWidth: 100])
    let underlinedLine = ctLine("x", [.underlineStyle: NSUnderlineStyle.thick.rawValue])

    XCTAssertEqual(CTLineGetImageBounds(line, nil), CTLineGetImageBounds(strokedLine, nil))
    XCTAssertEqual(CTLineGetImageBounds(line, nil), CTLineGetImageBounds(underlinedLine, nil))
  }

  func image(_ textFrame: STUTextFrame,
             _ range: Range<STUTextFrame.Index>? = nil,
             _ options: STUTextFrame.DrawingOptions? = nil,
             displayScale: CGFloat = 2) -> UIImage
  {
    let bounds = ceilToScale(textFrame.imageBounds(for: range, frameOrigin: .zero,
                                                   displayScale: displayScale, options: options),
                             displayScale)
                 .insetBy(-1)
    return createImage(bounds.size, scale: displayScale, backgroundColor: .white, .rgb, { context in
             context.addRect(CGRect(origin: .zero, size: bounds.size).insetBy(1 - 0.5/displayScale))
             context.setLineWidth(1/displayScale)
             context.setStrokeColor(UIColor.red.withAlphaComponent(1/3.0).cgColor)
             context.drawPath(using: .stroke)
             textFrame.draw(range: range, at: -bounds.origin, in: context, contextBaseCTM_d: 1,
                            pixelAlignBaselines: true, options: options)
           })
  }

  func testUnderlineImageBounds() {

    let font1 = UIFont(name: "HelveticaNeue", size: 17)!
    let font2 = UIFont(name: "HelveticaNeue", size: 32)!;

    {
      let string = NSMutableAttributedString()
      string.append(NSAttributedString(". ", [.font: font1,
                                              .underlineStyle: NSUnderlineStyle.double.rawValue]))
      string.append(NSAttributedString(" .", [.font: font2,
                                              .underlineStyle: NSUnderlineStyle.double.rawValue]))
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                            size: CGSize(width: 100, height: 100), displayScale: 2)
      self.checkSnapshotImage(self.image(tf, tf.range(forRangeInOriginalString: NSRange(1...2))),
                              suffix: "_double")
    }();

    {
      let string = NSMutableAttributedString()
      let shadow = NSShadow()
      shadow.shadowOffset = CGSize(width: 5, height: 2)
      string.append(NSAttributedString(". ", [.font: font1,
                                              .underlineStyle: NSUnderlineStyle.thick.rawValue,
                                              .shadow: shadow]))
      string.append(NSAttributedString(" .", [.font: font2,
                                              .underlineStyle: NSUnderlineStyle.thick.rawValue,
                                              .underlineColor: UIColor.blue,
                                              .shadow: shadow]))
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                            size: CGSize(width: 100, height: 100), displayScale: 2)
      self.checkSnapshotImage(self.image(tf, tf.range(forRangeInOriginalString: NSRange(1...2))),
                              suffix: "_thick_black_blue_shadow")
    }();

    {
      let string = NSMutableAttributedString()
      let shadow = NSShadow()
      shadow.shadowOffset = CGSize(width: -5, height: -2)
      shadow.shadowBlurRadius = 0.5
      string.append(NSAttributedString(". ", [.font: font2,
                                              .underlineStyle: NSUnderlineStyle.single.rawValue,
                                              .shadow: shadow]))
      string.append(NSAttributedString(" .", [.font: font2,
                                              .underlineStyle: NSUnderlineStyle.thick.rawValue]))
      let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                            size: CGSize(width: 100, height: 100), displayScale: 2)
      self.checkSnapshotImage(self.image(tf, tf.range(forRangeInOriginalString: NSRange(1...2))),
                              suffix: "_shadow_single_thick")
    }();
  }

  func testPartialLigatureImageBounds() {
    let font = UIFont(name: "HoeflerText-Regular", size: 18)!
    // Let's use the opportunity to also test highlighting the partial ligatures with a shadow.
    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 3, height: 3)
    shadow.shadowBlurRadius = 0
    let options = STUTextFrame.DrawingOptions()
    options.highlightStyle = STUTextHighlightStyle { b in
                                b.setShadow(offset: CGSize(width: 3, height: 3),
                                            blurRadius: 0, color: nil)
                             }
    let tf = STUTextFrame(STUShapedString(NSAttributedString("ffiffk", [.font: font])),
                          size: CGSize(width: 100, height: 100), displayScale: nil)
    self.checkSnapshotImage(self.image(tf, tf.range(forRangeInOriginalString: NSRange(2...3)),
                                       options),
                            suffix: "_if_with_shadow")
  }

  func testStrokeImageBounds() {
    let font = UIFont(name: "HelveticaNeue", size: 32)!
    let string = NSAttributedString("LL", [.font: font,
                                           .foregroundColor: UIColor.lightGray,
                                           .strokeWidth: -1,
                                           .strokeColor: UIColor.blue])
    let tf = STUTextFrame(STUShapedString(string, defaultBaseWritingDirection: .leftToRight),
                          size: CGSize(width: 100, height: 100), displayScale: 2)

    self.checkSnapshotImage(self.image(tf), suffix: "_LL_stroked")

    let options = STUTextFrame.DrawingOptions()
    options.highlightStyle = STUTextHighlightStyle { b in
                               b.setStroke(width: 0, color: UIColor.clear, doNotFill: false)
                             }
    self.checkSnapshotImage(self.image(tf, nil, options), suffix: "_LL_unstroked")

    options.highlightRange = STUTextRange(range: NSRange(1...1), type: .rangeInOriginalString)
    options.highlightStyle = STUTextHighlightStyle { b in
                               b.setStroke(width: 1.5, color: UIColor.cyan, doNotFill: true)
                             }
    self.checkSnapshotImage(self.image(tf, nil, options), suffix: "_LL_differently_stroked")
  }

  // TODO
}
