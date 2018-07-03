// Copyright 2018 Stephan Tolksdorf

import UIKit
import STULabelSwift

protocol LabelView : class {

  func configureForUseAsLabel()

  func displayIfNeeded()

  var firstBaseline: CGFloat { get }

  var maxLineCount: Int { get set }
  var string: NSString { get set }
  var attributedString: NSAttributedString { get set }
}

extension STULabel : LabelView {

  func configureForUseAsLabel() {}

  func displayIfNeeded() {
    layer.displayIfNeeded()
    // We only use this function for testing the synchronous rendering into a CALayer context.
    assert((layer.sublayers?.count ?? 0) == 0)
  }

  var firstBaseline: CGFloat {
    return layoutInfo.firstBaseline
  }

  var string: NSString {
    get { return self.text as NSString }
    set { self.text = newValue as String? }
  }
  var attributedString: NSAttributedString {
    get { return self.attributedText }
    set { self.attributedText = newValue }
  }
}

extension UILabel : LabelView {
  func configureForUseAsLabel() {}

  func displayIfNeeded() {
    if let sublayer = layer.sublayers?.first {
      sublayer.displayIfNeeded()
    } else {
      layer.displayIfNeeded()
    }
  }

  var firstBaseline: CGFloat {
    // Don't do this in a production app.
    let value = self.value(forKey: "_firstLineBaseline") as! CGFloat
    let contentScale = self.contentScaleFactor
    return ceil(value*contentScale)/contentScale
  }

  var string: NSString {
    get { return self.text as NSString? ?? "" }
    set { self.text = newValue as String? }
  }
  var attributedString: NSAttributedString {
    get { return self.attributedText ?? NSAttributedString() }
    set {
      self.attributedText = newValue // Also sets maxLineCount to 0
    }
  }

  var maxLineCount: Int {
    get { return self.numberOfLines }
    set { self.numberOfLines = newValue }
  }
}

extension UITextView : LabelView {

  func configureForUseAsLabel() {
    isScrollEnabled = false
    isEditable = false
    textContainer.lineBreakMode = .byTruncatingTail
    textContainer.lineFragmentPadding = 0
    textContainerInset = .zero
    backgroundColor = .clear
  }

  func displayIfNeeded() {
    layer.sublayers![0].displayIfNeeded()
  }

  var firstBaseline: CGFloat {
    // This isn't a proper implementation.
    let lm = self.layoutManager
    let glyphRange = lm.glyphRange(for: textContainer)
    if glyphRange.length == 0 { return 0}
    let glyphIndex = glyphRange.location
    let rect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil,
                                   withoutAdditionalLayout: false)
    let value = textContainerInset.top +  rect.origin.y + lm.location(forGlyphAt: 0).y
    let contentScale = self.subviews[0].contentScaleFactor
    return ceil(value*contentScale)/contentScale
  }

  var maxLineCount: Int {
    get { return textContainer.maximumNumberOfLines }
    set { textContainer.maximumNumberOfLines = newValue }
  }

  var string: NSString {
    get { return self.text as NSString }
    set { self.text = newValue as String }
  }
  var attributedString: NSAttributedString {
    get { return self.attributedText }
    set { self.attributedText = newValue }
  }
}
