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

  // UILabel adds the line spacing to the bottom of the content if the text has only a single line,
  // but not if it has multiple lines. If the line height is constant, we can fix this inconsistency
  // by adjusting the rect returned from textRect(...).

  var expectedLineHeight: CGFloat = 0
  var expectedLineSpacing: CGFloat = 0
  var lineSpaceAdjustedHeight: CGFloat = -1

  override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int)
             -> CGRect
  {
    var rect = CGRect(x: bounds.origin.x + contentInsets.left,
                      y: bounds.origin.y + contentInsets.top,
                      width: max(0, bounds.size.width - (  contentInsets.left
                                                         + contentInsets.right)),
                      height: max(0, bounds.size.height - (  contentInsets.top
                                                           + contentInsets.bottom)))
    rect = super.textRect(forBounds: rect, limitedToNumberOfLines: numberOfLines)
    let innerHeight = rect.size.height
    rect = CGRect(x: rect.origin.x - contentInsets.left,
                  y: rect.origin.y - contentInsets.top,
                  width: rect.size.width + (contentInsets.left + contentInsets.right),
                  height: rect.size.height + (contentInsets.top + contentInsets.bottom))
    if expectedLineSpacing > 0 {
      let n = round(innerHeight/(expectedLineHeight + expectedLineSpacing))
      if n == 1 && innerHeight >= expectedLineHeight + expectedLineSpacing/2 {
        rect.size.height -= expectedLineSpacing
        lineSpaceAdjustedHeight = rect.size.height
      } else {
        lineSpaceAdjustedHeight = -1
      }
    }
    return rect
  }

  override func drawText(in bounds: CGRect) {
    var bounds = bounds
    if bounds.size.height == lineSpaceAdjustedHeight {
      bounds.size.height += expectedLineSpacing
    }
    let innerRect = CGRect(x: bounds.origin.x + contentInsets.left,
                           y: bounds.origin.y + contentInsets.top,
                           width: max(0, bounds.size.width - (  contentInsets.left
                                                              + contentInsets.right)),
                           height: max(0, bounds.size.height - (  contentInsets.top
                                                                + contentInsets.bottom)))
    super.drawText(in: innerRect)
  }
}
