// Copyright 2018 Stephan Tolksdorf

func pathRelativeToCurrentSourceDir(_ path: String, sourceFile: StaticString = #file) -> String {
  return (sourceFile.withUTF8Buffer { String(decoding: $0, as: UTF8.self) as NSString }
         .deletingLastPathComponent as NSString).appendingPathComponent(path)
}

extension SnapshotTestCase {
  @nonobjc
  public func checkSnapshot(of view: UIView, contentsScale: CGFloat = 0,
                            beforeLayoutAction: (() -> ())? = nil, suffix: String? = nil,
                            testFilePath: String = #file, testFileLine: Int = #line)
  {
    testFilePath.withCString {
      self.__checkSnapshot(of: view, contentsScale: contentsScale,
                           beforeLayoutAction: beforeLayoutAction, testNameSuffix: suffix,
                           testFilePath: $0, testFileLine: testFileLine)
    }
  }

  @nonobjc
  public func checkSnapshot(of layer: CALayer, contentsScale: CGFloat = 0,
                            beforeLayoutAction: (() -> ())? = nil, suffix: String? = nil,
                            testFilePath: String = #file, testFileLine: Int = #line)
  {
    testFilePath.withCString {
      self.__checkSnapshot(of: layer, contentsScale: contentsScale,
                           beforeLayoutAction: beforeLayoutAction, testNameSuffix: suffix,
                           testFilePath: $0, testFileLine: testFileLine)
    }
  }

  @nonobjc
  public func checkSnapshotImage(_ image: UIImage, suffix: String? = nil,
                                 testFilePath: String = #file, testFileLine: Int = #line,
                                 referenceImage: UIImage? = nil)
  {
    testFilePath.withCString {
      self.__checkSnapshotImage(image, testNameSuffix: suffix, testFilePath: $0,
                                testFileLine: testFileLine, referenceImage: referenceImage)
    }
  }
}
