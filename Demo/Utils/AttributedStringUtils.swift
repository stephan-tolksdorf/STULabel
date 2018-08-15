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
#if !swift(>=4.2)
  typealias Key = NSAttributedStringKey;
#endif

  convenience init(_ string: String, _ attributes: [Key: Any]) {
    self.init(string: string, attributes: attributes)
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
}
#endif
