// Copyright 2018 Stephan Tolksdorf

#if swift(>=4.2)
#else
extension UIViewController {
  var isMovingToParent: Bool { return isMovingToParentViewController }
  var isMovingFromParent: Bool { return isMovingFromParentViewController }
}
#endif
