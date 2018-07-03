// Copyright 2018 Stephan Tolksdorf

import Foundation

func paragraphStyle(_ configure: (NSMutableParagraphStyle) -> ()) -> NSParagraphStyle {
  let style = NSMutableParagraphStyle()
  configure(style)
  return style.copy() as! NSParagraphStyle
}

let ltrParaStyle = paragraphStyle({b in b.baseWritingDirection = .leftToRight})

let rtlParaStyle = paragraphStyle({b in b.baseWritingDirection = .rightToLeft})


extension NSAttributedString {
  convenience init(_ string: String, _ attributes: [NSAttributedStringKey: Any]) {
    self.init(string: string, attributes: attributes)
  }
}
