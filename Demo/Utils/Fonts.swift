// Copyright 2018 Stephan Tolksdorf

#if !swift(>=4.2)
extension UIFont {
  typealias TextStyle = UIFontTextStyle;
}
#endif

func preferredFontWithMonospacedDigits(_ textStyle: UIFont.TextStyle,
                                       _ traitCollection: UITraitCollection? = nil)
  -> UIFont
{
  let font: UIFont
  if #available(iOS 11, *) {
    let mediumTraitCollection = UITraitCollection(preferredContentSizeCategory: .medium)
    font = UIFont.preferredFont(
            forTextStyle: textStyle,
             compatibleWith: traitCollection == nil ? mediumTraitCollection
                             : UITraitCollection(traitsFrom: [traitCollection!,
                                                              mediumTraitCollection]))
  } else if #available(iOS 10, *) {
    font = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
  } else {
    font = UIFont.preferredFont(forTextStyle: textStyle)
  }
  let weight = (font.fontDescriptor.fontAttributes[.traits]
                as! [UIFontDescriptor.TraitKey: Any]?)?[.weight] as! UIFont.Weight?
  let mfont = UIFont.monospacedDigitSystemFont(ofSize: font.pointSize,
                                               weight: weight ?? .regular)
  if #available(iOS 11, *) {
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: mfont,
                                                             compatibleWith: traitCollection)
  } else {
    return mfont
  }
}

func styleName(fontName: String) -> String {
  guard let i = fontName.index(of: "-") else {
    if fontName.hasPrefix("Damascus") {    
      return fontName == "Damascus" ? "Regular"
           : String(fontName.dropFirst(8))
    }
    return "Regular"
  }
  return String(fontName[fontName.index(after: i)...])
}

private func italicFontName(fontName: String) -> String {
  return fontName + (fontName.index(of: "-") != nil ? "Italic" : "-Italic")
}

private let uiFontWeights: [UIFont.Weight] = [
  .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black
]

struct SystemFontStyle {
  let weight: UIFont.Weight
  let italic: Bool

  var name: String {
    let suffix = italic ? "Italic" : ""
    switch weight {
    case .ultraLight: return "Ultralight" + suffix
    case .thin:       return "Thin" + suffix
    case .light:      return "Light" + suffix
    case .regular:    return "Regular" + suffix
    case .medium:     return "Medium" + suffix
    case .semibold:   return "Semibold" + suffix
    case .bold:       return "Bold" + suffix
    case .heavy:      return "Heavy" + suffix
    case .black:      return "Black" + suffix
    default: fatalError()
    }
  }

  func font(size: CGFloat) -> UIFont {
    let font = UIFont.systemFont(ofSize: size, weight: weight)
    if !italic { return font }
    return CTFontCreateCopyWithSymbolicTraits(font as CTFont, 0, nil,
                                              [.italicTrait], [.italicTrait])! as UIFont
  }
}

let systemFontStyles: [SystemFontStyle] =
  uiFontWeights.flatMap{ return [SystemFontStyle(weight: $0, italic: false),
                                 SystemFontStyle(weight: $0, italic: true)] }

private let lowercaseFontWeightNames = [
  "ultralight", "thin", "light", "book", "regular", "medium",
  "demibold", "semibold", "bold", "extrabold", "heavy", "black"
]

private func fontSortOrder(f1: String, f2: String) -> Bool {
  var s1 = styleName(fontName: f1).lowercased()
  var s2 = styleName(fontName: f2).lowercased()

  func stripMT(_ s: inout String) {
    if s.hasSuffix("mt") {
      s = String(s.dropLast(2))
    }
  }
  func stripRoman(_ s: inout String) {
    if s.hasPrefix("roman") {
      s = String(s.dropFirst(5))
    }
  }

  func stripCondensed(_ s: inout String) -> Bool {
    let isCondensed = s.hasPrefix("condensed")
    guard isCondensed else { return false }
    s = String(s.dropFirst(9))
    return true
  }

  func stripItalic(_ s: inout String) -> Bool {
    if s.hasSuffix("italic") {
      s = String(s.dropLast(6))
      return true
    }
    if s.hasSuffix("it") {
      s = String(s.dropLast(2))
      return true
    }
    if s.hasSuffix("ita") {
      s = String(s.dropLast(2))
      return true
    }
    if s.hasSuffix("oblique") {
      s = String(s.dropLast(7))
      return true
    }
    return false
  }

  stripRoman(&s1)
  stripRoman(&s2)

  stripMT(&s1)
  stripMT(&s2)

  let isItalic1 = stripItalic(&s1)
  let isItalic2 = stripItalic(&s2)

  let isCondensed1 = stripCondensed(&s1)
  let isCondensed2 = stripCondensed(&s2)

  if s1.isEmpty {
    s1 = "regular"
  }
  if s2.isEmpty {
    s2 = "regular"
  }

  switch (lowercaseFontWeightNames.index(of: s1), lowercaseFontWeightNames.index(of: s2)) {
   case let (index1?, index2?):
     return isCondensed1 != isCondensed2 ? isCondensed1
          : index1 < index2
            || (index1 == index2 && !isItalic1 && isItalic2)
   case (_?, nil): return true
   case (nil, _?): return false
   case (nil, nil): return s1 < s2
  }
}

struct FontStyle : Equatable {
  let name: String
  let fontName: String

  init(fontName: String) {
    self.name = styleName(fontName: fontName)
    self.fontName = fontName
  }

  static func ==(_ lhs: FontStyle, _ rhs: FontStyle) -> Bool {
    return lhs.fontName == rhs.fontName
  }
}

struct FontFamily : Equatable {
  let name: String
  let styles: [FontStyle]

  static func ==(_ lhs: FontFamily, _ rhs: FontFamily) -> Bool {
    return lhs.name == rhs.name
  }
}

let fontFamilies: [FontFamily] =
      UIFont.familyNames.sorted().map { familyName in
        FontFamily(name: familyName,
                   styles: UIFont.fontNames(forFamilyName: familyName)
                           .sorted(by: fontSortOrder)
                           .map { FontStyle(fontName: $0) })
      }.filter { !$0.styles.isEmpty }

