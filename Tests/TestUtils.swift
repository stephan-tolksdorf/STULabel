// Copyright 2018 Stephan Tolksdorf


import STULabel.ImageUtils
import STULabelSwift

public typealias Attributes = [NSAttributedStringKey: Any]

extension NSAttributedString {
  public convenience init(_ strings: [(String, Attributes)],
                          _ attributes: Attributes = [:])
  {
    let string = NSMutableAttributedString()
    for (str, attr) in strings {
      string.append(NSAttributedString(str, attr))
    }
    string.addAttributes(attributes, range: NSRange(0..<string.length))
    self.init(attributedString: string)
  }
}

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

func pathRelativeToCurrentSourceDir(_ path: String, sourceFile: StaticString = #file) -> String {
  return (sourceFile.withUTF8Buffer { String(decoding: $0, as: UTF8.self) as NSString }
         .deletingLastPathComponent as NSString).appendingPathComponent(path)
}

extension SnapshotTestCase {
  func checkSnapshotImage(_ image: UIImage, suffix: String? = nil,
                          testFilePath: String = #file, testFileLine: Int = #line,
                          referenceImage: UIImage? = nil)
  {
    testFilePath.withCString {
      self.checkSnapshotImage(image, testNameSuffix: suffix, testFilePath: $0,
                              testFileLine: testFileLine, referenceImage: referenceImage)
    }
  }
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

