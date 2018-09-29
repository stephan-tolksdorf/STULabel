// Copyright 2018 Stephan Tolksdorf

import UIKit

class AutoHeightTableViewCell : UITableViewCell {
  public override
  func systemLayoutSizeFitting(_ targetSize: CGSize,
                               withHorizontalFittingPriority hPriority: UILayoutPriority,
                               verticalFittingPriority vPriority: UILayoutPriority) -> CGSize
  {
    let oldBounds = self.bounds
    let needToSetBounds = oldBounds.size.width != targetSize.width
    if needToSetBounds {
      var bounds = oldBounds
      bounds.size.width = targetSize.width
      self.bounds = bounds
    }
    self.layoutIfNeeded()
    if needToSetBounds {
      self.bounds = oldBounds
    }
    let size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: hPriority,
                                             verticalFittingPriority: vPriority)
    return size
  }
}
