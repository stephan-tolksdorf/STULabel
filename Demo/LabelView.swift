// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

protocol LabelView : class {

  func configureForUseAsLabel()

  func displayIfNeeded()

  var maximumNumberOfLines: Int { get set }
  var string: NSString { get set }
  var attributedString: NSAttributedString { get set }

  var supportsTextScaling: Bool { get }
  var minimumTextScaleFactor: CGFloat { get set }
}

protocol LabelViewWithContentInsets : LabelView {
  var contentInsets: UIEdgeInsets { get set }
}

extension STULabel : LabelViewWithContentInsets {

  func configureForUseAsLabel() {}

  func displayIfNeeded() {
    layer.displayIfNeeded()
  }

  var string: NSString {
    get { return self.text as NSString }
    set { self.text = newValue as String? }
  }
  var attributedString: NSAttributedString {
    get { return self.attributedText }
    set { self.attributedText = newValue }
  }

  var supportsTextScaling: Bool { return true }
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

  var string: NSString {
    get { return self.text as NSString? ?? "" }
    set { self.text = newValue as String? }
  }
  var attributedString: NSAttributedString {
    get { return self.attributedText ?? NSAttributedString() }
    set { self.attributedText = newValue }
  }

  var maximumNumberOfLines: Int {
    get { return self.numberOfLines }
    set { self.numberOfLines = newValue }
  }

  var supportsTextScaling: Bool { return true }

  var minimumTextScaleFactor: CGFloat {
    get { return adjustsFontSizeToFitWidth ? minimumScaleFactor : 1 }
    set {
      if 0 < newValue && newValue < 1 {
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor = newValue
      } else {
        adjustsFontSizeToFitWidth = false
        minimumScaleFactor = 1
      }
    }
  }
}

extension UILabelWithContentInsets : LabelViewWithContentInsets { }

extension UITextView : LabelViewWithContentInsets {

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

  var maximumNumberOfLines: Int {
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

  var contentInsets: UIEdgeInsets {
    get { return textContainerInset }
    set {
      if newValue != textContainerInset {
        textContainerInset = newValue
      }
    }
  }

  var supportsTextScaling: Bool { return false }

  var minimumTextScaleFactor: CGFloat {
    get { return 1 }
    set { fatalError("not supported") }
  }
}
