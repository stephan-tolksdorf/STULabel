// Copyright 2018 Stephan Tolksdorf

import Foundation

func paragraphStyle(_ configure: (NSMutableParagraphStyle) -> ()) -> NSParagraphStyle {
  let style = NSMutableParagraphStyle()
  configure(style)
  return style.copy() as! NSParagraphStyle
}

let ltrParaStyle = paragraphStyle({b in b.baseWritingDirection = .leftToRight})

let rtlParaStyle = paragraphStyle({b in b.baseWritingDirection = .rightToLeft})

typealias StringAttributes = [NSAttributedString.Key: Any]


extension NSAttributedString {
#if !swift(>=4.2)
  typealias Key = NSAttributedStringKey;
#endif

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
#if !swift(>=4.2)
extension NSAttributedStringKey {
  static var accessibilitySpeechLanguage: NSAttributedStringKey {
    return NSAttributedStringKey(rawValue: UIAccessibilitySpeechAttributeLanguage)
  }
}
#endif

#if !swift(>=4.2)
extension NSUnderlineStyle {
  init() {
    self = NSUnderlineStyle(rawValue: 0)!
  }
  static var single: NSUnderlineStyle { return .styleSingle }
  static var thick: NSUnderlineStyle { return .styleThick }
  static var double: NSUnderlineStyle { return .styleDouble }

  func union(_ other: NSUnderlineStyle) -> NSUnderlineStyle {
    return NSUnderlineStyle(rawValue: self.rawValue | other.rawValue)!
  }
}
#endif
