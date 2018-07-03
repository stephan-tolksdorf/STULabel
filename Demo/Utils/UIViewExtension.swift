// Copyright 2018 Stephan Tolksdorf

extension UIView {
  /// Returns the first `UIViewController` in the view's responder chain, or `nil` if there's none.
  @nonobjc var stu_viewController: UIViewController? {
    var r: UIResponder = self
    while let next = r.next {
      if let vc = next as? UIViewController {
        return vc
      }
      r = next
    }
    return nil
  }
}

