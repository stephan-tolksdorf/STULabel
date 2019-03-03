// Copyright 2018 Stephan Tolksdorf

import UIKit

func paragraphStyle(_ configure: (NSMutableParagraphStyle) -> ()) -> NSParagraphStyle {
  let style = NSMutableParagraphStyle()
  configure(style)
  return style.copy() as! NSParagraphStyle
}

let ltrParaStyle = paragraphStyle({b in b.baseWritingDirection = .leftToRight})

let rtlParaStyle = paragraphStyle({b in b.baseWritingDirection = .rightToLeft})

typealias StringAttributes = [NSAttributedString.Key: Any]


extension NSAttributedString {
  convenience init(_ string: String, _ attributes: [Key: Any]) {
    self.init(string: string, attributes: attributes)
  }

  convenience init(_ strings: [(String, StringAttributes)], _ attributes: StringAttributes = [:]) {
    let string = NSMutableAttributedString()
    for (str, attr) in strings {
      string.append(NSAttributedString(str, attr))
    }
    string.addAttributes(attributes, range: NSRange(0..<string.length))
    self.init(attributedString: string)
  }
}
