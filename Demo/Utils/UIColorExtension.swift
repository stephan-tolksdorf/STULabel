// Copyright 2018 Stephan Tolksdorf

import UIKit

extension UIColor {

  struct RGBA {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
  }

  var rgba: RGBA {
    var result = RGBA(red: 0, green: 0, blue: 0, alpha: 1)
    getRed(&result.red, green: &result.green, blue: &result.blue, alpha: &result.alpha)
    return result
  }

}
