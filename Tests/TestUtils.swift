// Copyright 2018 Stephan Tolksdorf


import STULabel.ImageUtils
import STULabelSwift

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
