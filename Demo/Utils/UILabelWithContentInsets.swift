// Copyright 2018 Stephan Tolksdorf

import UIKit

/// The Auto Layout baseline anchors don't work properly for non-zero edge insets, and other
/// functionality may break too, particularly for attributed strings.
class UILabelWithContentInsets : UILabel {

  /// Should be rounded to the display scale.
  var contentInsets: UIEdgeInsets = .zero {
    didSet {
      if contentInsets != oldValue {
        invalidateIntrinsicContentSize()
      }
    }
  }

  override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int)
             -> CGRect
  {
    let innerRect = CGRect(x: bounds.origin.x + contentInsets.left,
                           y: bounds.origin.y + contentInsets.top,
                           width: max(0, bounds.size.width - (  contentInsets.left
                                                              + contentInsets.right)),
                           height: max(0, bounds.size.height - (  contentInsets.top
                                                                + contentInsets.bottom)))
    let rect = super.textRect(forBounds: innerRect, limitedToNumberOfLines: numberOfLines)
    return CGRect(x: rect.origin.x - contentInsets.left,
                  y: rect.origin.y - contentInsets.top,
                  width: max(0, rect.size.width + (contentInsets.left + contentInsets.right)),
                  height: max(0, rect.size.height + (contentInsets.top + contentInsets.bottom)))
  }

  override func drawText(in rect: CGRect) {
    let innerRect = CGRect(x: bounds.origin.x + contentInsets.left,
                           y: bounds.origin.y + contentInsets.top,
                           width: max(0, bounds.size.width - (  contentInsets.left
                                                              + contentInsets.right)),
                           height: max(0, bounds.size.height - (  contentInsets.top
                                                                + contentInsets.bottom)))
    super.drawText(in: innerRect)
  }
}
