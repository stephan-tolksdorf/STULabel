// Copyright 2018 Stephan Tolksdorf

import STULabelSwift
import STULabel.ImageUtils

import UIKit

private let scale = UIScreen.main.scale

// To improve the consistency of our measurements we make a single large allocation for the bitmap
// data and then reuse this allocation for all CGContexts that we create.

let cachedContext: CGContext = {
  let format = STUCGImageFormat(.rgb)
  let width = 512
  let height = width
  let intScale = Int(scale)
  let context = CGContext(data: nil, width: width*intScale, height: height*intScale,
                          bitsPerComponent: format.bitsPerComponent,
                          bytesPerRow: 0,
                          space: format.colorSpace,
                          bitmapInfo: format.bitmapInfo.rawValue)!
  return context
}()

func createContext(_ size: CGSize) -> CGContext {
  let width = ceil(size.width*scale)
  let height = ceil(size.height*scale)
  let bitsPerComponent = cachedContext.bitsPerComponent
  let bitmapInfo = cachedContext.bitmapInfo
  let space = cachedContext.colorSpace!
  let bytesPerRow = (4*Int(width) + 31) & ~31
  precondition(bytesPerRow*Int(height) < cachedContext.bytesPerRow*cachedContext.height)
  let context = CGContext(data: cachedContext.data!, width: Int(width), height: Int(height),
                          bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
                          space: space,
                          bitmapInfo: bitmapInfo.rawValue)!
  context.concatenate(CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: 0, ty: height))
  // We want to imitate UIKit and QuartzCore here, so we use the private Core Graphics function
  // CGContextSetBaseCTM. Don't do this in an app submitted to the App Store.
  CGContextSetBaseCTM(context, context.ctm)
  return context
}

let xInset: CGFloat = 2
let yInset: CGFloat = 4


private func timeDrawing(_ originalAttributedString: NSAttributedString,
                         _ size: CGSize,
                         _ draw: @convention(c) (NSAttributedString, CGSize, CGPoint) -> (),
                         iterations: Int = 10000)
  -> (image: UIImage, duration: CFTimeInterval)
{
  func createStringCopy() -> NSAttributedString {
    return NSMutableAttributedString(attributedString: originalAttributedString).copy()
       as! NSAttributedString
  }
  let otherAttributedString = NSAttributedString(string: "clears caches",
                                                 attributes: [.font: UIFont.systemFont(ofSize: 10)])
  var minDuration: CFTimeInterval = .infinity
  var totalDuration: CFTimeInterval = 0
  let tag: UInt = 0 //unsafeBitCast(draw, to: UInt.self)
  let contextSize = CGSize(width: size.width + 2*xInset, height: size.height + 2*yInset)
  var image: UIImage?
  if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
    kdebug_signpost_start(0, tag, 0, 0, 0);
  }
  for i in 0..<iterations {
    autoreleasepool {
      let attributedString = createStringCopy()
      let context = createContext(contextSize)
      UIGraphicsPushContext(context)
      context.clear(CGRect(origin: .zero, size: contextSize))
      let t0 = CACurrentMediaTime()
      autoreleasepool {
        draw(attributedString, size, CGPoint(x: xInset, y: yInset))
        context.flush()
      }
      let t1 = CACurrentMediaTime()
      let d = t1 - t0
      if i > 10 {
        minDuration = min(minDuration, d)
        totalDuration += d
      }
      UIGraphicsPopContext()
      if i == iterations - 1 {
        image = UIImage(cgImage: context.makeImage()!, scale: scale, orientation: .up)
      } else {
        // Prevent simple caching schemes from distorting the measurements.
        UIGraphicsPushContext(context)
        autoreleasepool {
          draw(otherAttributedString, size, CGPoint(x: xInset, y: yInset))
        }
        UIGraphicsPopContext()
      }
    }
  }
  if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
    kdebug_signpost_end(0, 0, 0, 0, 0);
  }
  return (image!, minDuration)
}

private class TestCase {

  let title: String
  let attributedString: NSAttributedString
  let size: CGSize
  let lineCount: Int

  init(title: String, _ attributedString: NSAttributedString, width: CGFloat,
       height: CGFloat? = nil)
  {
    self.title = title
    self.attributedString = attributedString
    let info = STUTextFrame(STUShapedString(attributedString,
                                            defaultBaseWritingDirection: .leftToRight),
                            size: CGSize(width: width, height: height ?? 1000),
                            displayScale: scale,
                            options: nil).layoutInfo
    self.size = CGSize(width: width, height: height ?? ceil(info.layoutBounds.size.height))
    self.lineCount = Int(info.lineCount)
  }
}

private func createImage(_ testCase: TestCase,
                         _ draw: @convention(c) (NSAttributedString, CGSize, CGPoint) -> Void)
  -> UIImage
{
  let size = CGSize(width: testCase.size.width + 2*xInset,
                    height: testCase.size.height + 2*yInset)
  UIGraphicsBeginImageContextWithOptions(size, false, scale)
  autoreleasepool {
    draw(testCase.attributedString, testCase.size, CGPoint(x: xInset, y: yInset))
  }
  let image = UIGraphicsGetImageFromCurrentImageContext()!
  UIGraphicsEndImageContext()
  return image
}

class TextFramePerformanceVC : UIViewController {

  typealias DrawingFunction = @convention(c) (NSAttributedString, CGSize, CGPoint) -> Void

  class NamedDrawingFunction : Equatable, Hashable {
    let function: DrawingFunction
    let title: String
    let subtitle: String?

    init(_ function: @escaping DrawingFunction, _ title: String, _ subtitle: String? = nil) {
      self.function = function
      self.title = title
      self.subtitle = subtitle
    }

    static func ==(_ lhs: NamedDrawingFunction, _ rhs: NamedDrawingFunction) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    var hashValue: Int { return ObjectIdentifier(self).hashValue }
  }

  private typealias Result = (function: NamedDrawingFunction, image: UIImage, time: CFTimeInterval?)

  private class ResultView: TimingResultView<UIImageView> {

    let testCase: TestCase
    let drawingFunctions: [NamedDrawingFunction]
    let sampleViewsByFunction: [NamedDrawingFunction : SampleViewWithLabel]
    let timingRowsByFunction: [NamedDrawingFunction : TimingRow]


    init(_ testCase: TestCase, _ drawingFunctions: [NamedDrawingFunction]) {
      self.testCase = testCase
      self.drawingFunctions = drawingFunctions
      var sampleViews = [SampleViewWithLabel]()
      var sampleViewsByLabel = [String: SampleViewWithLabel]()

      func sampleView(_ title: String, _ image: UIImage) -> SampleViewWithLabel {
        if let v = sampleViewsByLabel[title] { return v }
        let v = SampleViewWithLabel(UIImageView())
        sampleViews.append(v)
        sampleViewsByLabel[title] = v
        v.label.text = title
        v.view.backgroundColor = UIColor.yellow
        v.view.image = image
        return v
      }

      let font1 = UIFont.preferredFont(forTextStyle: .body)
      let font2 = UIFont.preferredFont(forTextStyle: .caption2)
      func column1Label(_ firstLine: String, _ secondLine: String? = nil) -> NSAttributedString {
        let str = NSMutableAttributedString()
        str.append(NSAttributedString(string: firstLine, attributes: [.font: font1]))
        if let secondLine = secondLine {
          str.append(NSAttributedString(string: "\n", attributes: [.font: font1]))
          str.append(NSAttributedString(string: "(" + secondLine + ")", attributes: [.font: font2]))
        }
        return str
      }

      var sampleViewsByFunction = [NamedDrawingFunction : SampleViewWithLabel]()
      var timingRowsByFunction = [NamedDrawingFunction : TimingRow]()
      var results = [Result]()
      for f in drawingFunctions {
        let image = createImage(testCase, f.function)
        results.append((f, image, nil))
        sampleViewsByFunction[f] = sampleView(f.title, image)
        let r = TimingRow()
        r.column1Label.attributedText = column1Label(f.title, f.subtitle)
        timingRowsByFunction[f] = r
      }
      self.sampleViewsByFunction = sampleViewsByFunction
      self.timingRowsByFunction = timingRowsByFunction
      self.results = results
      super.init()
      self.sampleViews = sampleViews
      self.titleLabel.text = testCase.title
      self.button.setTitle("Measure drawing times", for: .normal)
    }

    private static func formatDuration(_ duration: CFTimeInterval, factor: Double) -> String {
      return String(format: "%.3f ms (%.2f\u{202F}x)", duration*1000, factor)
    }

    func showTimingRows() {
      timingRows = drawingFunctions.map({ timingRowsByFunction[$0]! })
    }

    var results: [Result] {
      didSet {
        var firstTime: CFTimeInterval?
        for (f, image, time) in results {
          sampleViewsByFunction[f]!.view.image = image
          let timeLabel = timingRowsByFunction[f]!.column2Label
          let factor: Double
          if let time = time {
            if let firstTime = firstTime {
              factor = time/firstTime
            } else {
              firstTime = time
              factor = 1
            }
            timeLabel.text = ResultView.formatDuration(time, factor: factor)
            timeLabel.isHidden = false
          } else {
            timeLabel.text = ResultView.formatDuration(2.0/1000, factor: 1)
            timeLabel.isHidden = true
          }
        }
      }
    }
  }


  private let resultViews: [ResultView]


  init() {
    let font = UIFont(name: "HelveticaNeue", size: 16)!

    let ltrParaStyle = NSMutableParagraphStyle()
    ltrParaStyle.baseWritingDirection = .leftToRight
    let rtlParaStyle = NSMutableParagraphStyle()
    rtlParaStyle.baseWritingDirection = .rightToLeft

    let shadow = NSShadow()
    shadow.shadowOffset = CGSize(width: 4, height: 4)
    shadow.shadowBlurRadius = 2

    let ltr: [NSAttributedString.Key: AnyObject] = [.font: font, .paragraphStyle: ltrParaStyle]
    let rtl: [NSAttributedString.Key: AnyObject] = [.font: font, .paragraphStyle: rtlParaStyle]

    var tests = [TestCase]()

    let string = NSMutableAttributedString()
    string.append(NSAttributedString(string: "John ", attributes: ltr))
    string.append(NSAttributedString(string: "Appleseed", attributes: ltr))

    tests.append(TestCase(title: "Short English text",
                          NSAttributedString(string: "John Appleseed", attributes: ltr),
                          width: 150))

    tests.append(TestCase(title: "Two line English text",
                          NSAttributedString(string: "A longer English text with multiple words and about 3 lines.", attributes: ltr),
                          width: 180))

    tests.append(TestCase(title: "Short Mandarin text",
                          NSAttributedString(string: "简短的中文文本简短的中文文本简短的中文文本", attributes: ltr),
                          width: 150))
    tests.append(TestCase(title: "Short Arabic text",
                          NSAttributedString(string: "نص عربي قصير", attributes: rtl),
                          width: 150))

    tests.append(TestCase(title: "Short Thai text",
                          NSAttributedString(string: "ข้อความภาษาไทยขนาดเล็ก", attributes: ltr),
                          width: 200))

    let singleLineDrawingFunctions: [NamedDrawingFunction] = [
      .init(drawUsingSTUTextFrame, "STUTextFrame"),
      .init(measureAndDrawUsingNSStringDrawing, "NSStringDrawing", "measuring & drawing"),
      .init(drawUsingNSStringDrawing, "NSStringDrawing", "drawing only"),
      .init(drawUsingCTTypesetter, "CTLine", "via CTTypesetter"),
      // .init(drawUsingCTLine, "CTLine", "directly")
    ]
    let multiLineDrawingFunctions: [NamedDrawingFunction] = [
      singleLineDrawingFunctions[0],
      singleLineDrawingFunctions[1],
      singleLineDrawingFunctions[2],
      // .init(drawUsingCTFrame, "CTFrame")
    ]

    var views = [ResultView]()

    for test in tests {
      views.append(ResultView(test, test.lineCount == 1 ? singleLineDrawingFunctions
                                                        : multiLineDrawingFunctions))
    }
    self.resultViews = views
    super.init(nibName: nil, bundle: nil)
    for view in views  {
      view.buttonTapped = { [weak self, weak view] in
        if let view = view {
          self?.measureDrawingTimes(view)
        }
      }
    }
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let scrollView = UIScrollView()
    self.view = scrollView
    self.view.backgroundColor = UIColor.white

    let contentView = UIView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(contentView)
    constrain(contentView, toEdgesOf: scrollView).activate()
    constrain(contentView, .width, .equal, scrollView, .width).isActive = true

    var cs: [NSLayoutConstraint] = []
    for view in resultViews {
      contentView.addSubview(view)
      view.translatesAutoresizingMaskIntoConstraints = false
      constrain(&cs, view, .leading,  .equal,           contentView, .leading)
      constrain(&cs, view, .width,    .lessThanOrEqual, contentView, .width)
    }
    constrain(&cs, topToBottom: resultViews, spacing: 10, withinMarginsOf:contentView)
    cs.activate()
  }

  var scrollView: UIScrollView { return self.view as! UIScrollView }

  private var timingFont: UIFont?
  private var minTimingColumWidth: CGFloat = 0

  private func updateMinTimingColumnWidth() {
    if let font = timingFont {
      let testString = NSAttributedString(string: "1.000 ms", attributes: [.font: font])
      minTimingColumWidth = ceil(testString.boundingRect(with: CGSize(width: 1000, height: 1000),
                                                         options: [.usesLineFragmentOrigin,
                                                                   .usesFontLeading],
                                                         context: nil).width)
      for view in resultViews {
        view.timingsColumnMinWidth = minTimingColumWidth
      }
    }
  }


  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateMinTimingColumnWidth()
  }


  private func measureDrawingTimes(_ view: ResultView) {
    let test = view.testCase
    let functions = view.drawingFunctions

    view.window?.isUserInteractionEnabled = false
    view.window?.tintAdjustmentMode = .dimmed

    view.button.isEnabled = false

    func setButtonTitle(measurementIndex: Int) {
      view.button.setTitle("Measuring... \(measurementIndex + 1)/\(functions.count)", for: .normal)
    }

    view.showTimingRows()

    if timingFont == nil {
      timingFont = view.timingRows[0].column2Label.font
      updateMinTimingColumnWidth()
    }

    var results = view.results
    for i in 0..<results.count {
      results[i].time = nil
    }
    view.results = results

    let iterations = 5000
    let pause: DispatchTimeInterval = .seconds(2)

    view.superview?.layoutIfNeeded()

    let contentBounds = scrollView.bounds
    let barHeight = self.topLayoutGuide.length
    let frame = scrollView.convert(view.bounds, from: view)
    let y = max(frame.minY, frame.maxY - (contentBounds.size.height - barHeight))
    if contentBounds.minY > y - barHeight {
      scrollView.setContentOffset(CGPoint(x: contentBounds.origin.x, y: y - barHeight),
                                  animated: true)
    }

    func measure(_ index: Int) {
      setButtonTitle(measurementIndex: index)
      DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
        let (image, duration) = timeDrawing(test.attributedString, test.size,
                                            functions[index].function, iterations: iterations)
        results[index] = (results[index].function, image, duration)
        view.results = results
        if index + 1 < functions.count {
          measure(index + 1)
        } else {
          view.button.isEnabled = true
          view.button.setTitle("Measure again", for: .normal)
          view.window?.isUserInteractionEnabled = true
          view.window?.tintAdjustmentMode = .normal
        }
      }
    }
    measure(0)
  }
}
