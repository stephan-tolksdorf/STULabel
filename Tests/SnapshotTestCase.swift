// Copyright 2018 Stephan Tolksdorf

func pathRelativeToCurrentSourceDir(_ path: String, sourceFile: StaticString = #file) -> String {
  return (sourceFile.withUTF8Buffer { String(decoding: $0, as: UTF8.self) as NSString }
         .deletingLastPathComponent as NSString).appendingPathComponent(path)
}

extension SnapshotTestCase {
  func checkSnapshot(of view: UIView, suffix: String? = nil,
                     testFilePath: String = #file, testFileLine: Int = #line,
                     referenceImage: UIImage? = nil)
  {
    testFilePath.withCString {
      self.checkSnapshot(of: view, testNameSuffix: suffix,
                         testFilePath: $0, testFileLine: testFileLine)
    }
  }

  func checkSnapshot(of layer: CALayer, suffix: String? = nil,
                     testFilePath: String = #file, testFileLine: Int = #line)
  {
    testFilePath.withCString {
      self.checkSnapshot(of: layer, testNameSuffix: suffix,
                         testFilePath: $0, testFileLine: testFileLine)
    }
  }

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
