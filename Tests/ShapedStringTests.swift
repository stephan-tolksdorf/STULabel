// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import XCTest

private func createTypesetter(_ string: NSAttributedString) -> CTTypesetter {
  if #available(iOS 12, *) {
    let ts = CTTypesetterCreateWithAttributedStringAndOptions(
               string, [kCTTypesetterOptionAllowUnboundedLayout: true] as CFDictionary)
    return ts!
  }
  return CTTypesetterCreateWithAttributedString(string as CFAttributedString)
}

class ShapedStringTests : XCTestCase {

  // The CoreText headers state that all functions are thread-safe, but the online documentation
  // states that "layout objects (CTTypesetter, CTFramesetter, CTRun, CTLine, CTFrame,
  // and associated objects) should be used in a single operation, work queue, or thread."
  // Some cursory reverse-engineering suggests that the layout objects are essentially immutable and
  // that lazily computed values are cached in a thread-safe way. This suggests that the online
  // documentation is out-of-date (apparently CoreText had some thread-safety bugs in old versions
  // of iOS). To buy us some further peace of mind, we test the thread-safety of CTTypesetter a bit.
  func testCTTypesetterThreadSafety() {

    seedRand(123)

    for translation in [udhr.translationsByLanguageCode["en"]!,
                        udhr.translationsByLanguageCode["ar"]!,
                        udhr.translationsByLanguageCode["hi"]!,
                        udhr.translationsByLanguageCode["zh-Hant"]!]
    {
      let attributedString =
          translation.asAttributedString(titleAttributes: [.font: UIFont.systemFont(ofSize: 32)],
                                         bodyAttributes: [.font: UIFont(name: "HoeflerText-Regular",
                                                                        size: 16)!],
                                         paragraphSeparator: " ")

      let string = attributedString.string
      let indices = Array(string.indices)
      let indicesCount = Int32(indices.count)

      struct TestCase {
        let index: Int
        let maxWidth: Double
        let length: Int
        let length2: Int
        let width: Double
        let width2: Double
      }

      let typesetter0 = createTypesetter(attributedString)

      func randomTestCase() -> TestCase {
        while true {
          let index = indices[rand(Int32(indices.count))].encodedOffset
          let maxWidth = randU01()*1000
          let length = CTTypesetterSuggestLineBreak(typesetter0, index, maxWidth)
          if length < 0 {
            if CTGetCoreTextVersion() <= kCTVersionNumber10_12 { // CoreText bug
              continue
            }
            fatalError()
          }
          let length2 = CTTypesetterSuggestClusterBreak(typesetter0, index, maxWidth)
          let line = CTTypesetterCreateLine(typesetter0, CFRangeMake(index, length))
          let width = CTLineGetTypographicBounds(line, nil, nil, nil)
          let line2 = CTTypesetterCreateLine(typesetter0, CFRangeMake(index, length2))
          let width2 = CTLineGetTypographicBounds(line2, nil, nil, nil)
          return TestCase(index: index, maxWidth: maxWidth, length: length, length2: length2,
                          width: width, width2: width2)
        }

      }

      for j in 0..<10 {
        let testCases = Array(0..<1000).map({_ in randomTestCase()})
        let typesetter = createTypesetter(attributedString)
        DispatchQueue.concurrentPerform(iterations: testCases.count) { testCaseIndex in
        //for testCaseIndex in 0..<testCases.count {
          let tc = testCases[testCaseIndex]
          let c = (j + testCaseIndex)%5
          switch c {
          case 0, 1:
            let length = CTTypesetterSuggestLineBreak(typesetter, tc.index, tc.maxWidth)
            if length != tc.length {
              fatalError()
            }
            let line = CTTypesetterCreateLine(typesetter0, CFRangeMake(tc.index, tc.length))
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width != tc.width {
              fatalError()
            }
            if c == 0 { break }
            fallthrough
          case 2:
            let length2 = CTTypesetterSuggestClusterBreak(typesetter, tc.index, tc.maxWidth)
            if length2 != tc.length2 {
              fatalError()
            }
            let line = CTTypesetterCreateLine(typesetter0, CFRangeMake(tc.index, tc.length2))
            let width2 = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width2 != tc.width2 {
              fatalError()
            }
          case 3:
            let line = CTTypesetterCreateLine(typesetter0, CFRangeMake(tc.index, tc.length))
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width != tc.width {
              fatalError()
            }
          case 4:
            let line = CTTypesetterCreateLine(typesetter0, CFRangeMake(tc.index, tc.length2))
            let width2 = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width2 != tc.width2 {
              fatalError()
            }
          default: break
          }
        }
      }
    }
  }
}
