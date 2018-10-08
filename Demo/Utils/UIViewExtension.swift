// Copyright 2018 Stephan Tolksdorf

import UIKit

extension UIView {
  /// Returns the first `UIViewController` in the view's responder chain, or `nil` if there's none.
  var stu_viewController: UIViewController? {
    var r: UIResponder = self
    while let next = r.next {
      if let vc = next as? UIViewController {
        return vc
      }
      r = next
    }
    return nil
  }

  func convertBounds(of view: UIView) -> CGRect {
    return self.convert(view.bounds, from: view)
  }
}

