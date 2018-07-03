// Copyright 2018 Stephan Tolksdorf

import STULabel.MainScreenProperties

import XCTest

class MainScreenPropertiesTests: XCTestCase {

  func testMainScreenPortraitSize() {
    var size: CGSize?
    let item = DispatchWorkItem(block: { size = stu_mainScreenPortraitSize() })
    DispatchQueue.global(qos: .default).async(execute: item)
    item.wait()
    XCTAssertEqual(size, UIScreen.main.fixedCoordinateSpace.bounds.size);
  }

  func testMainScreenScale() {
    var scale: CGFloat?
    let item = DispatchWorkItem(block: { scale = stu_mainScreenScale() })
    DispatchQueue.global(qos: .default).async(execute: item)
    item.wait()
    XCTAssertEqual(scale, UIScreen.main.scale);
  }

  func testMainScreenDisplayGamut() { if #available(iOS 10, tvOS 10, *) {
    var gamut: STUDisplayGamut?
    let item = DispatchWorkItem(block: { gamut = stu_mainScreenDisplayGamut() })
    DispatchQueue.global(qos: .default).async(execute: item)
    item.wait()
    XCTAssertEqual(gamut,
                   STUDisplayGamut(rawValue: UIScreen.main.traitCollection.displayGamut.rawValue));
  } }

}
