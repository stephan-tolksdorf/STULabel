// Copyright 2018 Stephan Tolksdorf

import UIKit

extension UIColor {
   public convenience init(rgb: Int, alpha: CGFloat = 1) {
    precondition(0 <= rgb && rgb <= 0xFF_FF_FF)
    precondition(0 <= alpha && alpha <= 1)
    let red   = rgb >> 16
    let green = (rgb >> 8) & 0xFF
    let blue  = rgb & 0xFF
    self.init(red: CGFloat(red)/255, green: CGFloat(green)/255, blue: CGFloat(blue)/255,
              alpha: alpha)
  }

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
