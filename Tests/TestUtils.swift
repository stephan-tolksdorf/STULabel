// Copyright 2018 Stephan Tolksdorf


import STULabel.ImageUtils
import STULabelSwift

#if !swift(>=4.2)
extension NSAttributedString {
  typealias Key = NSAttributedStringKey
}

extension UIImage {
  func pngData() -> Data? { return UIImagePNGRepresentation(self) }
}
#endif

typealias StringAttributes = [NSAttributedString.Key: Any]

extension NSAttributedString {
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
extension NSUnderlineStyle {
  static var single: NSUnderlineStyle { return .styleSingle }
  static var thick: NSUnderlineStyle { return .styleThick }
  static var double: NSUnderlineStyle { return .styleDouble }
}
#endif

func createImage(_ size: CGSize, scale: CGFloat, backgroundColor: UIColor? = nil,
                 _ format: STUCGImageFormat.Predefined,
                 _ closure: @convention(block) (CGContext) -> ())
  -> UIImage
{
  
  let options : STUCGImageFormat.Options = backgroundColor == nil ? [] : [.withoutAlphaChannel]
  let cgImage = stu_createCGImage(size: size, scale: scale, backgroundColor: backgroundColor?.cgColor,
                                  STUCGImageFormat(format, options), closure)!
  return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
}



extension CGPoint {
  static prefix func -(_ point: CGPoint) -> CGPoint {
    return CGPoint(x: -point.x, y: -point.y)
  }
}

extension CGRect {
  func insetBy(_ value: CGFloat) -> CGRect {
    return self.insetBy(dx: value, dy: value)
  }
}

func ceilToScale(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
  return ceil(value*scale)/scale
}


func floorToScale(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
  return floor(value*scale)/scale
}

func ceilToScale(_ rect: CGRect, _ scale: CGFloat) -> CGRect {
  let minX = floorToScale(rect.origin.x, scale)
  let minY = floorToScale(rect.origin.y, scale)
  let maxX = ceilToScale(rect.origin.x + rect.size.width, scale)
  let maxY = ceilToScale(rect.origin.y + rect.size.height, scale)
  return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

