// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import STULabel.ImageUtils

class TextFramePerformanceTestCase {
  let title: String
  let attributedString1: NSAttributedString
  let attributedString2: NSAttributedString
  let size: CGSize
  let needsTruncation: Bool
  let lineCount: Int

  init(title: String, _ attributedString: NSAttributedString,
       width: CGFloat? = nil, height: CGFloat? = nil,
       needsTruncation: Bool = false)
  {
    self.title = title
    self.needsTruncation = needsTruncation
    let mutableString1 = NSMutableAttributedString(attributedString: attributedString)
    let attribs0 = mutableString1.attributes(at: 0, effectiveRange: nil)
    mutableString1.insert(NSAttributedString("1 ", attribs0), at: 0)
    self.attributedString1 = NSAttributedString(attributedString: mutableString1)

    let mutableString2 = NSMutableAttributedString(attributedString: mutableString1)
    mutableString2.mutableString.replaceCharacters(in: NSRange(0..<1), with: "2")
    // Prevents trivial caching of the attribute dictionary.
    mutableString2.addAttribute(.foregroundColor, value: UIColor.black,
                                range: NSRange(0..<mutableString2.length))
    self.attributedString2 = NSAttributedString(attributedString: mutableString2)

    let info1 = STUTextFrame(STUShapedString(attributedString1,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width ?? 1000, height: height ?? 1000),
                             displayScale: scale,
                             options: nil).layoutInfo(frameOrigin: .zero)
    let info2 = STUTextFrame(STUShapedString(attributedString2,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width ?? 1000, height: height ?? 1000),
                             displayScale: scale,
                             options: nil).layoutInfo(frameOrigin: .zero)
    self.size = CGSize(width: width ?? ceil(max(info1.layoutBounds.size.width,
                                                info2.layoutBounds.size.width)),
                       height: height ?? ceil(max(info1.layoutBounds.size.height,
                                                  info2.layoutBounds.size.height)))
    self.lineCount = Int(max(info1.lineCount, info2.lineCount))
  }
}

private let scale = stu_mainScreenScale()

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
let yInset: CGFloat = 2

private func timeExecution(_ draw: @convention(c) (NSAttributedString, CGSize, CGPoint) -> (),
                           _ attributedString1: NSAttributedString,
                           _ attributedString2: NSAttributedString,
                           size: CGSize,
                           measurementTime: CFTimeInterval = 2, warmupIterationCount: Int = 8,
                           iterationCountModulo2: Int = 0)
          -> (Stats, UIImage)
{
  assert(measurementTime > 0)
  assert(iterationCountModulo2 == iterationCountModulo2%2)
  let contextSize = CGSize(width: size.width + 2*xInset, height: size.height + 2*yInset)
  var sc = IncremantalStatsCalculator()
  var i = 0
  var deadline = CACurrentMediaTime() + measurementTime
  let fixedIterationCount: Int? = nil // 10000 // Makes it easier to compare profiling data.
  var warmup = true
  while true {
    var t0: CFTimeInterval = 0
    var t1: CFTimeInterval = 0
    autoreleasepool {
      let context = createContext(contextSize)
      context.clear(CGRect(origin: .zero, size: contextSize))
      UIGraphicsPushContext(context)
      t0 = CACurrentMediaTime()
      autoreleasepool {
        draw((i & 1) == 0 ? attributedString1 : attributedString2,
             size, CGPoint(x: xInset, y: yInset))
        context.flush()
      }
      t1 = CACurrentMediaTime()
      UIGraphicsPopContext()
    }
    let d = t1 - t0
    i += 1
    if !warmup {
      sc.addMeasurement(d)
      if let n = fixedIterationCount {
        if i == n + warmupIterationCount { break}
      } else {
        if i%2 == iterationCountModulo2 && t1 > deadline { break }
      }
    } else if i == warmupIterationCount  {
      warmup = false
      if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
        // The new os_signpost API in iOS 12 doesn't yet seem to work reliably.
        kdebug_signpost_start(0, 0, 0, 0, 0);
      }
      deadline = CACurrentMediaTime() + measurementTime
    }
  }
  if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
    kdebug_signpost_end(0, 0, 0, 0, 0);
  }
  let image = UIImage(cgImage: createContext(contextSize).makeImage()!, scale: scale,
                      orientation: .up)
  return (sc.stats, image)
}


private func setting<Value: UserDefaultsStorable>(_ id: String, _ defaultValue: Value)
          -> Setting<Value>
{
  return Setting(id: "TextFramePerformance." + id, default: defaultValue)
}

class TextFramePerformanceVC : UIViewController, UIPopoverPresentationControllerDelegate {
  typealias TestCase = TextFramePerformanceTestCase

  typealias DrawingFunction = @convention(c) (NSAttributedString, CGSize, CGPoint) -> Void

  class NamedDisplayer : Equatable, Hashable {
    let drawingFunction: DrawingFunction
    let name: String
    let features: String
    let enabled: Setting<Bool>

    init(_ function: @escaping DrawingFunction,
         _ name: String, _ features: String = "",
         singleLineOnly: Bool = false,
         enabledByDefault: Bool = true)
    {
      self.drawingFunction = function
      self.name = name
      self.features = features
      self.enabled = setting(name + (features.isEmpty ? "" : " " + features), enabledByDefault)
    }

    static func ==(_ lhs: NamedDisplayer, _ rhs: NamedDisplayer) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    var hashValue: Int { return ObjectIdentifier(self).hashValue }


    func createImage(_ testCase: TextFramePerformanceTestCase) -> UIImage {
      let size = CGSize(width: testCase.size.width + 2*xInset,
                        height: testCase.size.height + 2*yInset)
      UIGraphicsBeginImageContextWithOptions(size, false, scale)
      autoreleasepool {
        drawingFunction(testCase.attributedString1, testCase.size, CGPoint(x: xInset, y: yInset))
      }
      let image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
      return image
    }
  }

  private struct Result {
    let displayer: NamedDisplayer
    let image: UIImage?
    let stats: Stats?

    init(_ displayer: NamedDisplayer) {
      self.displayer = displayer
      self.image = nil
      self.stats = nil
    }

    init(_ displayer: NamedDisplayer, _ image: UIImage, _ stats: Stats) {
      self.displayer = displayer
      self.image = image
      self.stats = stats
    }
  }

  private class ResultView: TimingResultView<UIImageView> {
    let testCase: TestCase
    let displayers: [NamedDisplayer]
    let allSampleViews: [SampleViewWithLabel]
    let sampleViewsByDisplayer: [NamedDisplayer : SampleViewWithLabel]
    let timingRowsByDisplayer: [NamedDisplayer : TimingRow]

    init(_ testCase: TestCase, _ displayers: [NamedDisplayer]) {
      self.testCase = testCase
      self.displayers = displayers

      var sampleViews = [SampleViewWithLabel]()
      var sampleViewsByLabel = [String: SampleViewWithLabel]()
      var sampleViewsByDisplayer = [NamedDisplayer : SampleViewWithLabel]()

      for d in displayers {
        if let svl = sampleViewsByLabel[d.name] {
          sampleViewsByDisplayer[d] = svl
          continue
        }

        let sv = UIImageView()
        sv.image = d.createImage(testCase)
        sv.backgroundColor = UIColor(rgb: 0xffff4d)

        let svl = SampleViewWithLabel(sv)
        svl.label.text = d.name
        sampleViews.append(svl)
        sampleViewsByLabel[d.name] = svl
        sampleViewsByDisplayer[d] = svl
      }

      let results = displayers.map { Result($0) }

      var timingRowsByDisplayer = [NamedDisplayer : TimingRow]()
      for d in displayers {
        let r = TimingRow()
        r.column1Label.text = d.name
        r.secondLineLabel.text = d.features.isEmpty ? "" : "(" + d.features + ")"
        timingRowsByDisplayer[d] = r
      }

      self.sampleViewsByDisplayer = sampleViewsByDisplayer
      self.timingRowsByDisplayer = timingRowsByDisplayer
      self.allSampleViews = sampleViews
      self.results = results
      super.init()
      self.layoutMargins = .zero
      self.titleLabel.text = testCase.title
      self.button.setTitle("Measure drawing times", for: .normal)
      updateSampleViews()
    }

    private static func formatDuration(_ duration: CFTimeInterval, factor: Double) -> String {
      return String(format: "%.3f\u{202F}ms (%.2f\u{202F}x)", duration*1000, factor)
    }

    static let measurementLabelPlaceholderText = ResultView.formatDuration(2.0/1000, factor: 1)

    func updateSampleViews() {
      let activeSampleViews = Set(sampleViewsByDisplayer.lazy.filter{ $0.key.enabled.value }
                                  .map{ $0.value})
      self.sampleViews = allSampleViews.filter { activeSampleViews.contains($0) }
    }

    func updateTimingRows() {
      updateSampleViews()
      if !shouldShowTimingRows {
        self.timingRows = []
      } else {
        timingRows = displayers.filter{ $0.enabled.value }.map{ timingRowsByDisplayer[$0]! }
      }
    }

    var shouldShowTimingRows: Bool = false {
      didSet {
        updateTimingRows()
      }
    }

    var results: [Result] {
      didSet {
        assert(results.count == displayers.count)
        if let minTime = results.lazy.compactMap({ $0.stats?.min }).min() {
          for r in results {
            let measurementLabel = timingRowsByDisplayer[r.displayer]!.column2Label
            if let time = r.stats?.min {
              sampleViewsByDisplayer[r.displayer]!.view.image = r.image
              measurementLabel.text = ResultView.formatDuration(time, factor: time/minTime)
              measurementLabel.isHidden = false
            } else {
              measurementLabel.text = ResultView.measurementLabelPlaceholderText
              measurementLabel.isHidden = true
            }
          }
        } else {
          for row in timingRows {
            row.column2Label.text = ResultView.measurementLabelPlaceholderText
            row.column2Label.isHidden = true
          }
        }
      }
    }
  }

  let measureDurationMS = setting("measureDurationMS", 2000)
  let pauseDurationMS = setting("pauseDurationMS", 1000)

  private let resultViews: [ResultView]
  private let displayers: [NamedDisplayer]

  init() {

    let enFont   = UIFont.systemFont(ofSize: 16)
    let en15Font = UIFont.systemFont(ofSize: 15)

    // Using the system font for the non-Latin test cases woud complicate the comparison with
    // the Core Text implementation (since Core Text uses the substituted font's metrics while
    // Text Kit doesn't.)

    let zhFont   = UIFont(name: "PingFangSC-Regular", size: 17)!
    let arFont   = UIFont(name: "GeezaPro", size: 17)!

    let enLineHeight   = enFont.lineHeight + enFont.leading
    let en15LineHeight = en15Font.lineHeight + en15Font.leading
    let zhLineHeight   = zhFont.lineHeight + zhFont.leading
    let arLineHeight   = arFont.lineHeight + arFont.leading

    let en:   [NSAttributedString.Key: AnyObject] = [.font: enFont,   .paragraphStyle: ltrParaStyle]
    let en15: [NSAttributedString.Key: AnyObject] = [.font: en15Font, .paragraphStyle: ltrParaStyle]
    let zh:   [NSAttributedString.Key: AnyObject] = [.font: zhFont,   .paragraphStyle: ltrParaStyle]
    let ar:   [NSAttributedString.Key: AnyObject] = [.font: arFont,   .paragraphStyle: rtlParaStyle]

    let enUnderlined = en.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let zhUnderlined = zh.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let arUnderlined = ar.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let tests: [TestCase] = [
      TestCase(title: "Short English text ",
               NSAttributedString("John Appleseed", en)),

      TestCase(title: "Longer English text ",
               NSAttributedString("All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.",
                                  en15),
               width: 258),

      TestCase(title: "Short truncated English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights.",
                                  en),
               width: 250, height: ceil(enLineHeight), needsTruncation: true),

      TestCase(title: "Longer truncated English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.",
                                  en15),
               width: 258, height: ceil(en15LineHeight*2), needsTruncation: true),


      TestCase(title: "Short underlined English text",
               NSAttributedString("John Appleseed", enUnderlined)),

      TestCase(title: "Short Chinese text",
               NSAttributedString("简短的中文文本", zh)),

      TestCase(title: "Longer Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。他们赋有理性和良心,并应以兄弟关系的精神相对待。",
                                  zh),
               width: 250),

      TestCase(title: "Short truncated Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。",
                                  zh),
               width: 243, height: ceil(zhLineHeight), needsTruncation: true),

      TestCase(title: "Longer truncated Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。他们赋有理性和良心,并应以兄弟关系的精神相对待。",
                                  zh),
               width: 288, height: ceil(2*zhLineHeight), needsTruncation: true),

      TestCase(title: "Short underlined Chinese text",
               NSAttributedString("简短的中文文本", zhUnderlined)),

      TestCase(title: "Short Arabic text",
               NSAttributedString("نص عربي قصير", ar)),

       TestCase(title: "Longer Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق. وقد وهبوا عقلاً وضميرًا وعليهم أن يعامل بعضهم بعضًا بروح الإخاء.",
                                  ar),
               width: 288),

      TestCase(title: "Short truncated Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق.", ar),
               width: 235, height: ceil(arLineHeight), needsTruncation: true),

      TestCase(title: "Longer truncated Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق. وقد وهبوا عقلاً وضميرًا وعليهم أن يعامل بعضهم بعضًا بروح الإخاء.",
                                  ar),
               width: 280, height: ceil(2*arLineHeight), needsTruncation: true),

      TestCase(title: "Short underlined Arabic text",
               NSAttributedString("نص عربي قصير", arUnderlined))
    ]

    let multiLineDisplayers: [NamedDisplayer] = [
      .init(drawUsingCTTypesetter, "CTTypesetter",
            enabledByDefault: true),
      .init(drawUsingCTFrame, "CTFrame",
            enabledByDefault: false),
      .init(drawUsingSTUTextFrame, "STUTextFrame",
            enabledByDefault: true),
      .init(measureAndDrawUsingNSStringDrawing, "NSStringDrawing", "measuring & drawing",
            enabledByDefault: true),
      .init(drawUsingNSStringDrawing, "NSStringDrawing", "drawing only",
            enabledByDefault: true),
      .init(drawUsingTextKit, "TextKit",
            enabledByDefault: true),
    ]
    let displayers : [NamedDisplayer] = [
      .init(drawUsingCTLine, "CTLine", singleLineOnly: true, enabledByDefault: false)
    ] + multiLineDisplayers

    self.displayers = displayers

    var views = [ResultView]()
    for test in tests {
      views.append(ResultView(test, test.lineCount == 1 && !test.needsTruncation ? displayers
                                    : multiLineDisplayers))
    }
    self.resultViews = views
    super.init(nibName: nil, bundle: nil)

    for view in views  {
      view.onButtonTap = { [weak self, weak view] in
        if let view = view {
          self?.measureDrawingTimes(view)
        }
      }
    }

    self.navigationItem.titleView = debugBuildTitleLabel()
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "toggle-icon"),
                                                             style: .plain, target: self,
                                                             action: #selector(showSettings))

    let displayerWasEnabledOrDisabled = { [unowned self] in
      self.displayerWasEnabledOrDisabled()
    }

    for d in displayers {
      d.enabled.onChange = displayerWasEnabledOrDisabled
    }

    cancelButton.target = self
    cancelButton.action = #selector(cancelMeasurement)
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

    var cs: [NSLayoutConstraint] = []

    constrain(&cs, contentView, toEdgesOf: scrollView)
    constrain(&cs, contentView, .width, eq, scrollView, .width)

    let container = UILayoutGuide()
    container.identifier = "Content"
    contentView.addLayoutGuide(container)

    constrain(&cs, container, within: contentView.layoutMarginsGuide)
    constrain(&cs, container, horizontallyCenteredWithin: scrollView.readableContentGuide)
    constrain(&cs, container, .width, eq, 0, priority: .fittingSizeLevel)

    var views: [UIView] = resultViews
    let notes = STULabel()
    views.insert(notes, at: 0)

    for view in views {
      contentView.addSubview(view)
      view.translatesAutoresizingMaskIntoConstraints = false
      constrain(&cs, view, .leading,  eq,  container, .leading)
      constrain(&cs, view, .width,    leq, container, .width)
    }
    constrain(&cs, topToBottom: views, spacing: 20, within: container)

    cs.activate()

    notes.maximumNumberOfLines = 0
    notes.font = UIFont.preferredFont(forTextStyle: .footnote)
    notes.adjustsFontForContentSizeCategory = true
    notes.setContentCompressionResistancePriority(.fittingSizeLevel - 1, for: .horizontal)
    notes.text = "The goal here is to measure the best case performance under ideal conditions, i.e. with hot caches, pre-trained branch predictors and a minimum of other code running. For this purpose we run each test scenario in a loop for a fixed amount of time (after a small fixed number of warmup iterations) and record the minimum time it takes.\n\nThe measured times will depend on the device type and the iOS version. If you're seeing unstable measurements, it's probably because of background activity and/or because of dynamic CPU scaling. \n\nWe only benchmark synchronous text layout and drawing into an 32-bit RGB bitmap context on the main thread here, excluding the time to create and destroy the context. In order to prevent any simple caching, we switch between two strings in each loop iteration (prefixed by a \"1\" or \"2\"). When a measurement ends, the corresponding sample view at the top of the test case (with a yellow background) will be replaced with result from the last iteration. This gives you a chance to inspect the render result.\n\nThe \"CTTypesetter\" implementation is a simplistic multiline layout routine implemented with CTTypesetter. The measured time for this implementation represents an approximate lower bound for the time that any general purpose text layout routine built on top of the public Core Text API could achieve (though the truncation logic is suboptimal)."

    #if DEBUG
      notes.text += "\n\nNote that you're currently running a slow debug build of STULabel!"
    #endif
  }

  private func displayerWasEnabledOrDisabled() {
    for view in resultViews {
      view.updateTimingRows()
    }
  }

  var scrollView: UIScrollView { return self.view as! UIScrollView }

  private var timingFont: UIFont?
  private var minTimingColumWidth: CGFloat = 0

  private func updateMinTimingColumnWidth() {
    guard let font = timingFont else { return }
    let testString = NSAttributedString(string: "1.000 ms", attributes: [.font: font])
    let tf = STUTextFrame(STUShapedString(testString, defaultBaseWritingDirection: .leftToRight),
                          size: CGSize(width: 1000, height: 1000), displayScale: nil)
    minTimingColumWidth = ceil(tf.layoutBounds.width)
    for view in resultViews {
      view.timingsColumnMinWidth = minTimingColumWidth
    }
  }


  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #available(iOS 10, tvOS 10, *) {
      if let timingFont = self.timingFont,
         let previousTraitCollection = previousTraitCollection,
         traitCollection.preferredContentSizeCategory
         != previousTraitCollection.preferredContentSizeCategory
      {
        self.timingFont = timingFont.stu_fontAdjusted(forContentSizeCategory:
                                                       traitCollection.preferredContentSizeCategory)
        updateMinTimingColumnWidth()
      }
    }
  }

  // MARK: - Measurement

  let cancelButton = UIBarButtonItem(title: "Cancel", style: .done,
                                     target: self, action: #selector(cancelMeasurement))

  private var measurementCancelled: Bool = false

  @objc
  private func cancelMeasurement() {
    measurementCancelled = true
    cancelButton.isEnabled = false
  }

  private func measureDrawingTimes(_ view: ResultView) {
    let testCase = view.testCase
    let displayers = view.displayers.enumerated().filter{ (i, d) in d.enabled.value }
    guard !displayers.isEmpty
    else {
      let ac = UIAlertController(title: "Error", message: "No compatible drawing function is enabled. Please select one.",
                                 preferredStyle: .alert)
      ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.showSettings() })
      present(ac, animated: true, completion: nil)
      return
    }

    measurementCancelled = false

    let oldNavigationItemTitleView = navigationItem.titleView
    navigationItem.titleView = nil
    navigationItem.setHidesBackButton(true, animated: true)
    let oldRightBarButton = navigationItem.rightBarButtonItem
    cancelButton.isEnabled = true
    navigationItem.rightBarButtonItem = cancelButton

    scrollView.isUserInteractionEnabled = false
    scrollView.tintAdjustmentMode = .dimmed

    view.button.isEnabled = false
    view.shouldShowTimingRows = true

    if timingFont == nil {
      timingFont = view.timingRows[0].column2Label.font
      updateMinTimingColumnWidth()
    }

    func finished() {
      view.button.isEnabled = true
      view.button.setTitle("Measure again", for: .normal)

      self.scrollView.isUserInteractionEnabled = true
      self.scrollView.tintAdjustmentMode = .normal

      self.navigationItem.title = nil
      self.navigationItem.titleView = oldNavigationItemTitleView
      self.navigationItem.rightBarButtonItem = oldRightBarButton
      self.navigationItem.setHidesBackButton(false, animated: true)

      if !self.measurementCancelled {
        self.scrollView.layoutIfNeeded()
        self.scrollView.scrollRectToVisible(self.scrollView.convertBounds(of: view.button),
                                            animated: true)
      }
    }

    var oldSampleViews = Set(view.sampleViews.map { $0.view })
    for (_, d) in displayers {
      if let sv = oldSampleViews.remove(view.sampleViewsByDisplayer[d]!.view) {
        sv.image = d.createImage(testCase)
      }
    }

    var results = view.results
    for i in results.indices {
      results[i] = Result(results[i].displayer)
    }
    view.results = results

    let pause = CFTimeInterval(self.pauseDurationMS.value)/1000
    var iterationCountModulo2ByDisplayerName = [String : Int]()

    func measure(_ index: Int) {
      if self.measurementCancelled {
        finished()
        return
      }

      let measuringTitle = "Measuring... \(index + 1)/\(displayers.count)"
      view.button.setTitle(measuringTitle, for: .normal)
      self.navigationItem.title = measuringTitle

      self.scrollView.layoutIfNeeded()
      var rect = scrollView.convertBounds(of: view.timingRows[index])
      if index == 0 {
        rect = rect.union(scrollView.convertBounds(of: view.titleLabel))
      }
      self.scrollView.scrollRectToVisible(rect, animated: true)

      DispatchQueue.main.asyncAfter(deadline: .now() + max(pause, index == 0 ? 0.5 : 0.1)) {
        if self.measurementCancelled {
          finished()
          return
        }
        let (functionIndex, function) = displayers[index]

        // We want the sample view to change after each measurement, so we switch between
        // odd and even iteration counts.
        let iterCountModulo2 = ((iterationCountModulo2ByDisplayerName[function.name] ?? 1) + 1)%2
        iterationCountModulo2ByDisplayerName[function.name] = iterCountModulo2

        let (stats, image) = timeExecution(
                               function.drawingFunction,
                               testCase.attributedString1,
                               testCase.attributedString2,
                               size: testCase.size,
                               measurementTime: CFTimeInterval(self.measureDurationMS.value)/1000,
                               iterationCountModulo2: iterCountModulo2)

        assert(results[functionIndex].displayer == function)
        results[functionIndex] = Result(function, image, stats)
        view.results = results

        print(function.name + (function.features.isEmpty ? "" : " (" + function.features + ")"),
              "min: \(String(format: "%0.4f", stats.min*1000))ms",
              "mean: \(String(format: "%0.3f", stats.mean*1000))ms",
              "stddev: \(String(format: "%0.1f", 100*stats.stddev/stats.mean))%")

        if index + 1 < displayers.count {
          DispatchQueue.main.async { measure(index + 1) }
        } else {
          finished()
        }
      }
    }
    measure(0)
  }


  // MARK: - Settings popover

  @objc
  private func showSettings() {
    let navigationVC = UINavigationController(rootViewController: SettingsViewController(self))
    navigationVC.modalPresentationStyle = .popover
    navigationVC.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
    navigationVC.popoverPresentationController?.delegate = self
    navigationVC.setNavigationBarHidden(true, animated: false)
    self.present(navigationVC, animated: false, completion: nil)
  }

  func adaptivePresentationStyle(for controller: UIPresentationController,
                                 traitCollection: UITraitCollection) -> UIModalPresentationStyle
  {
    return .none
  }

  private class SettingsViewController : StaticTableViewController {
    init(_ vc: TextFramePerformanceVC) {
      super.init()
      shouldUpdatePreferredContentSize = true
     // minPreferredContentWidth = 400
      let font1 = UIFont.preferredFont(forTextStyle: .body)
      let font2 = UIFont.preferredFont(forTextStyle: .callout)
      cells = [StepperCell("Measure", 100...10000, step: 100, vc.measureDurationMS, unit: "ms"),
               StepperCell("Pause", 100...10000, step: 100, vc.pauseDurationMS, unit: "ms")]
            + vc.displayers.map { d in
                let text = NSAttributedString([(d.name, [.font: font1]),
                                              (d.features.isEmpty ? "" : "\n(" + d.features + ")",
                                               [.font: font2])])
                return SwitchCell(text, d.enabled)
              }
    }
  }
}
