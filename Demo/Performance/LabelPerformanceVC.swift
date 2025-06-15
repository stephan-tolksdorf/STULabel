// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

import STULabel.DynamicTypeFontScaling

class LabelPerformanceTestCase {
  let title: String
  let attributedString1: NSAttributedString
  let attributedString2: NSAttributedString
  let attributedString1WithTailTruncationParaStyle: NSAttributedString
  let attributedString2WithTailTruncationParaStyle: NSAttributedString
  let needsAttributes: Bool
  let string1: NSString
  let string2: NSString
  let font: UIFont
  let isRightToLeft: Bool
  let maxSize: CGSize
  let size: CGSize
  let hasFixedHeight: Bool
  let layoutMode: STUTextLayoutMode
  let heightSTULabel: CGFloat
  let heightUILabel: CGFloat
  let maxLineCount: Int
  let minTextScaleFactor: CGFloat

  static func measureSize<Label: UIView & LabelView>
                           (_ type: Label.Type, maxSize: CGSize,
                            textLayoutMode: STUTextLayoutMode,
                            maxLineCount: Int,
                            minTextScaleFactor: CGFloat = 1,
                            _ attributedString1: NSAttributedString,
                            _ attributedString2: NSAttributedString) -> CGSize
  {
    let label = Label()
    label.configureForUseAsLabel()
    if let label = label as? STULabel {
      label.textLayoutMode = textLayoutMode
    }
    label.maximumNumberOfLines = maxLineCount
    if minTextScaleFactor < 1 {
      label.minimumTextScaleFactor = minTextScaleFactor
      if label.maximumNumberOfLines != 1 {
        if let label = label as? STULabel {
          label.textScalingBaselineAdjustment = .none
          label.verticalAlignment = .center
        } else if let label = label as? UILabel {
          label.baselineAdjustment = .none
        }
      }
    }

    UIApplication.shared.keyWindow!.addSubview(label)
    label.attributedString = attributedString1
    let size1 = label.sizeThatFits(maxSize)
    label.attributedString = attributedString2
    let size2 = label.sizeThatFits(maxSize)
    label.removeFromSuperview()

    return CGSize(width: min(max(size1.width, size2.width), maxSize.width),
                  height: min(max(size1.height, size2.height), maxSize.height))
  }

  init(title: String, _ attributedString: NSAttributedString,
       needsAttributes: Bool = false,
       width: CGFloat? = nil, height: CGFloat? = nil,
       fixHeight: Bool = false,
       textLayoutMode: STUTextLayoutMode = .textKit,
       maxLineCount: Int = 0,
       minTextScaleFactor: CGFloat = 1)
  {
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

    mutableString1.enumerateAttribute(.paragraphStyle, in: NSRange(0..<mutableString1.length),
                                      options: []) { (style, range, stop) in
      let mutableStyle: NSMutableParagraphStyle
      if let style = style as! NSParagraphStyle? {
        mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle
      } else {
        mutableStyle = NSMutableParagraphStyle()
      }
      mutableStyle.lineBreakMode = .byTruncatingTail
      let newStyle = mutableStyle.copy() as! NSParagraphStyle
      mutableString1.addAttribute(.paragraphStyle, value: newStyle, range: range)
      mutableString2.addAttribute(.paragraphStyle, value: newStyle, range: range)
    }
    self.attributedString1WithTailTruncationParaStyle =
           NSAttributedString(attributedString: mutableString1)
    self.attributedString2WithTailTruncationParaStyle =
           NSAttributedString(attributedString: mutableString2)

    self.title = title
    self.needsAttributes = needsAttributes
    self.string1 = attributedString1.string as NSString
    self.string2 = attributedString2.string as NSString
    self.layoutMode = textLayoutMode
    self.maxLineCount = maxLineCount
    self.minTextScaleFactor = minTextScaleFactor

    self.font = attributedString1.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
    let paraStyle = attributedString1.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                    as! NSParagraphStyle?
    self.isRightToLeft = paraStyle?.baseWritingDirection == .rightToLeft

    self.hasFixedHeight = fixHeight
    self.maxSize = CGSize(width: width ?? 1000, height: height ?? 1000)
    if fixHeight {
      assert(width != nil && height != nil)
      self.size = self.maxSize
      self.heightSTULabel = self.size.height
      self.heightUILabel = self.size.height
    } else {
      let size1 = LabelPerformanceTestCase.measureSize(STULabel.self, maxSize: self.maxSize,
                                                       textLayoutMode: textLayoutMode,
                                                       maxLineCount: maxLineCount,
                                                       minTextScaleFactor: minTextScaleFactor,
                                                       attributedString1, attributedString2)
      self.heightSTULabel = size1.height
      let size2 = LabelPerformanceTestCase.measureSize(UILabel.self, maxSize: self.maxSize,
                                                       textLayoutMode: textLayoutMode,
                                                       maxLineCount: maxLineCount,
                                                       attributedString1WithTailTruncationParaStyle,
                                                       attributedString2WithTailTruncationParaStyle)
      self.heightUILabel = size2.height
      let size3 = minTextScaleFactor < 1 ? size2
                : LabelPerformanceTestCase.measureSize(UITextView.self, maxSize: self.maxSize,
                                                       textLayoutMode: textLayoutMode,
                                                       maxLineCount: maxLineCount,
                                                       minTextScaleFactor: minTextScaleFactor,
                                                       attributedString1, attributedString2)
      self.size = CGSize(width: ceil(max(size1.width, size2.width, size3.width)),
                         height: ceil(max(size1.height, size2.height, size3.height)))

    }
  }
}

private class LabelContainer : UIView {
  let label: LabelView & UIView

  init(_ testCase: LabelPerformanceTestCase, label: LabelView & UIView, autoLayout: Bool) {
    self.label = label
    let frame = CGRect(origin: .zero, size: testCase.size)
    label.frame = frame
    super.init(frame: frame)
    addSubview(label)
    if autoLayout {
      label.translatesAutoresizingMaskIntoConstraints = false
      var cs = [NSLayoutConstraint]()
      constrain(&cs, label, .left,   eq, self, .left)
      constrain(&cs, label, .top,    eq, self, .top)
      constrain(&cs, label, .width,  eq, frame.size.width)
      if testCase.hasFixedHeight {
        constrain(&cs, label, .height, geq, frame.size.height)
      } else if testCase.minTextScaleFactor < 1 && testCase.maxLineCount != 1 {
        constrain(&cs, label, .height, leq, frame.size.height)
      }
      cs.activate()
    }
  }

  required init?(coder aDecoder: NSCoder) { fatalError() }
}

private typealias LabelPerformanceTestCaseDisplayer =
  (LabelPerformanceTestCase) -> (LabelContainer, (_ index: Int) -> Void)

private func timeExecution(_ function: (_ iteration: Int) -> Void,
                           measurementTime: CFTimeInterval = 2, warmupIterationCount: Int = 8,
                           iterationCountModulo2: Int = 0)
          -> Stats
{
  assert(measurementTime > 0)
  assert(iterationCountModulo2 == iterationCountModulo2%2)
  var sc = IncremantalStatsCalculator()
  var i = 0
  var deadline = CACurrentMediaTime() + measurementTime
  let fixedIterationCount: Int? = nil // 10000
  var warmup = true
  while true {
    let t0 = CACurrentMediaTime()
    autoreleasepool {
      function(i)
    }
    let t1 = CACurrentMediaTime()
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
  return sc.stats
}

// MARK: - layout and display functions

private func displaySimpleString<Label: LabelView & UIView>
                                (_ label: Label, _ string: NSString, _ maxSize: CGSize)
          -> Int
{
  label.string = string
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}

private func displayAttributedString<Label: LabelView & UIView>
                                    (_ label: Label, _ string: NSAttributedString, _ maxSize: CGSize)
          -> Int
{
  label.attributedString = string
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}

private func sizeThatFitsAndDisplaySimpleString<Label: LabelView & UIView>
                                               (_ label: Label, _ string: NSString,
                                                _ maxSize: CGSize)
          -> Int
{
  label.string = string
  let size = label.sizeThatFits(maxSize)
  label.frame = CGRect(origin: .zero, size: CGSize(width: maxSize.width,
                                                   height: min(size.height, maxSize.height)))
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}

private func sizeThatFitsAndDisplayAttributedString<Label: LabelView & UIView>
                                                   (_ label: Label, _ string: NSAttributedString,
                                                    _ maxSize: CGSize)
          -> Int
{
  label.attributedString = string
  let size = label.sizeThatFits(maxSize)
  label.frame = CGRect(origin: .zero, size: CGSize(width: maxSize.width,
                                                   height: min(size.height, maxSize.height)))
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}

// MARK: - Label creation

private func createSTULabel(_ testCase: LabelPerformanceTestCase) -> STULabel {
  let label = STULabel()
  label.textLayoutMode = testCase.layoutMode
  label.font = testCase.font
  label.textAlignment = testCase.isRightToLeft ? .right : .left
  label.maximumNumberOfLines = testCase.maxLineCount
  if testCase.minTextScaleFactor < 1 {
    label.minimumTextScaleFactor = testCase.minTextScaleFactor
    if testCase.maxLineCount != 1 {
      // For maximum comparability with UILabel:
      label.textScalingBaselineAdjustment = .none
      label.verticalAlignment = .center
    }
  }
  return label
}

private func createUILabel(_ testCase: LabelPerformanceTestCase) -> UILabel {
  let label = UILabel()
  label.font = testCase.font
  label.textAlignment = testCase.isRightToLeft ? .right : .left
  label.maximumNumberOfLines = testCase.maxLineCount
  if testCase.minTextScaleFactor < 1 {
    label.minimumScaleFactor = testCase.minTextScaleFactor
    label.adjustsFontSizeToFitWidth = true
    if testCase.maxLineCount != 1 {
      label.baselineAdjustment = .none
    }
  }
  return label
}

// clipsToBounds doesn't seem to make a difference for our test cases.
private func createUILabelWithClipsToBounds(_ testCase: LabelPerformanceTestCase) -> UILabel {
  let label = createUILabel(testCase)
  label.clipsToBounds = true
  return label
}

private func createUITextView(_ testCase: LabelPerformanceTestCase) -> UITextView {
  let label = UITextView()
  label.isScrollEnabled = false
  label.isEditable = false
  label.textContainer.lineFragmentPadding = 0
  label.textContainerInset = .zero
  label.textContainer.lineBreakMode = .byTruncatingTail
  label.backgroundColor = .clear
  label.font = testCase.font
  label.textAlignment = testCase.isRightToLeft ? .right : .left
  label.textContainer.maximumNumberOfLines = testCase.maxLineCount
  // UITextView has no built-in support for font scaling
  return label
}

private func createSTULabelWithClipsContentToBounds(_ testCase: LabelPerformanceTestCase) -> STULabel {
  let label = createSTULabel(testCase)
  label.clipsContentToBounds = true
  return label
}

// MARK: - createDisplayer

private func createDisplayer<Label: LabelView & UIView>(
               autoLayout: Bool = false,
               _ createLabel:  @escaping (LabelPerformanceTestCase) -> Label,
               _ display: @escaping (Label, NSString, CGSize) -> Int)
  -> LabelPerformanceTestCaseDisplayer
{
  return { (_ testCase: LabelPerformanceTestCase) in
    let label = createLabel(testCase)
    let container = LabelContainer(testCase, label: label, autoLayout: autoLayout)
    let maxSize = CGSize(width: testCase.size.width, height: testCase.maxSize.height)
    return (container, {(index: Int) in
             _ = display(label, (index & 1) == 0 ? testCase.string1 : testCase.string2, maxSize)
           })
  }
}

private func createDisplayer<Label: LabelView & UIView>(
               autoLayout: Bool = false,
               _ createLabel:  @escaping (LabelPerformanceTestCase) -> Label,
               _ display: @escaping (Label, NSAttributedString, CGSize) -> Int)
  -> LabelPerformanceTestCaseDisplayer
{
  return { (_ testCase: LabelPerformanceTestCase) in
    let label = createLabel(testCase)
    let container = LabelContainer(testCase, label: label, autoLayout: autoLayout)
    let attributedString1: NSAttributedString
    let attributedString2: NSAttributedString
    // When assigning an attributed string to a UILabel and the first character has a paragraph
    // style, the label's lineBreakMode will be overwritten by the paragraph style's lineBreakMode.
    // In order to ensure tail truncation when necessary, we always use a paragraph styles with
    // with a tail truncation lineBreakMode for UILabel views. We also use these variants for the
    // single line UITextViews, because that significantly improves performance for some reason.
    if label is UILabel || (testCase.maxLineCount == 1 && label is UITextView) {
      attributedString1 = testCase.attributedString1WithTailTruncationParaStyle
      attributedString2 = testCase.attributedString2WithTailTruncationParaStyle
    } else {
      attributedString1 = testCase.attributedString1
      attributedString2 = testCase.attributedString2
    }
    let maxSize = CGSize(width: testCase.size.width, height: testCase.maxSize.height)
    return (container, {(index: Int) in
             _ = display(label, (index & 1) == 0 ? attributedString1 : attributedString2, maxSize)
           })
  }
}

private func setting<Value: UserDefaultsStorable>(_ id: String, _ defaultValue: Value)
          -> Setting<Value>
{
  return Setting(id: "LabelPerformance." + id, default: defaultValue)
}

class LabelPerformanceVC : UIViewController, UIPopoverPresentationControllerDelegate {

  typealias TestCase = LabelPerformanceTestCase
  private typealias Displayer = LabelPerformanceTestCaseDisplayer

  private class NamedDisplayer : Equatable, Hashable {
    let name: String
    let features: String
    let displayer: Displayer
    let enabled: Setting<Bool>

    init(_ name: String, _ features: String, _ displayer: @escaping Displayer,
         enabledByDefault: Bool = false)
    {
      self.name = name
      self.features = features
      self.displayer = displayer
      self.enabled = setting(name + " " + features, enabledByDefault)
    }

    static func ==(_ lhs: NamedDisplayer, _ rhs: NamedDisplayer) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    func hash(into hasher: inout Hasher) {
      ObjectIdentifier(self).hash(into: &hasher)
    }
  }

  private struct Result {
    let displayer: NamedDisplayer
    let container: LabelContainer?
    let stats: Stats?

    init(_ displayer: NamedDisplayer) {
      self.displayer = displayer
      self.container = nil
      self.stats = nil
    }

    init(_ displayer: NamedDisplayer, _ container: LabelContainer, _ stats: Stats) {
      self.displayer = displayer
      self.container = container
      self.stats = stats
    }
  }

  private class SampleView: UIView {

    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!

    init() {
      super.init(frame: .zero)
      widthConstraint = constrain(self, .width, .equal, 0)
      heightConstraint = constrain(self, .height, .equal, 0)
      [widthConstraint, heightConstraint].activate()
    }

    required init?(coder aDecoder: NSCoder) { fatalError()}

    var labelContainer: LabelContainer? {
      didSet {
        if labelContainer === oldValue { return }
        oldValue?.removeFromSuperview()
        if let newValue = labelContainer {
          self.addSubview(newValue)
          let frame = newValue.subviews[0].frame
          let size = CGSize(width: frame.maxX, height: frame.maxY)
          widthConstraint.constant = size.width
          heightConstraint.constant = size.height
          self.frame.size = size
        } else {
          widthConstraint.constant = 0
          heightConstraint.constant = 0
          self.frame.size = .zero
        }
      }
    }
  }

  private class ResultView: TimingResultView<SampleView> {
    let testCase: TestCase
    let displayers: [NamedDisplayer]
    let sampleViewsByDisplayer: [NamedDisplayer : SampleViewWithLabel]
    let timingRowsByDisplayer: [NamedDisplayer : TimingRow]

    init(_ testCase: TestCase, _ displayers: [NamedDisplayer]) {
      self.testCase = testCase
      self.displayers = displayers

      var sampleViews = [SampleViewWithLabel]()
      var sampleViewsByLabel = [String: SampleViewWithLabel]()
      var sampleViewsByDisplayer = [NamedDisplayer : SampleViewWithLabel]()

      for (_, d) in displayers.enumerated().sorted(by: { ed1, ed2 in
                      let (i1, d1) = ed1
                      let (i2, d2) = ed2
                      let d1IsSimple = d1.features.contains("simple")
                      let d2IsSimple = d2.features.contains("simple")
                      if d1IsSimple != d2IsSimple { return !d1IsSimple }
                      let d1Clips = d1.features.contains("clips")
                      let d2Clips = d2.features.contains("clips")
                      if d1Clips != d2Clips { return !d1Clips }
                      return  i1 < i2
                   })
      {
        if let svl = sampleViewsByLabel[d.name] {
          sampleViewsByDisplayer[d] = svl
          continue
        }
        let (container, display) = d.displayer(testCase)
        display(0)

        let sv = SampleView()
        sv.backgroundColor = UIColor(rgb: 0xffff4d)
        sv.labelContainer = container

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
        r.secondLineLabel.text = "(" + d.features + ")"
        timingRowsByDisplayer[d] = r
      }

      self.sampleViewsByDisplayer = sampleViewsByDisplayer
      self.timingRowsByDisplayer = timingRowsByDisplayer
      self.results = results
      super.init()
      self.layoutMargins = .zero
      self.sampleViews = sampleViews
      self.titleLabel.text = testCase.title
      self.button.setTitle("Measure drawing times", for: .normal)
    }

    private static func formatDuration(_ duration: CFTimeInterval, factor: Double) -> String {
      return String(format: "%.3f\u{202F}ms (%.2f\u{202F}x)", duration*1000, factor)
    }

    static let measurementLabelPlaceholderText = ResultView.formatDuration(2.0/1000, factor: 1)

    func updateTimingRows() {
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
              sampleViewsByDisplayer[r.displayer]!.view.labelContainer = r.container
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

    let font17 = UIFont.systemFont(ofSize: 17)
    let font16 = UIFont.systemFont(ofSize: 16)
    let font15 = UIFont.systemFont(ofSize: 15)

    let enFont   = font16
    let en15Font = font15
    let zhFont   = font17
    let arFont   = font17

    let en:   [NSAttributedString.Key: AnyObject] = [.font: enFont,   .paragraphStyle: ltrParaStyle]
    let en15: [NSAttributedString.Key: AnyObject] = [.font: en15Font, .paragraphStyle: ltrParaStyle]
    let zh:   [NSAttributedString.Key: AnyObject] = [.font: zhFont,   .paragraphStyle: ltrParaStyle]
    let ar:   [NSAttributedString.Key: AnyObject] = [.font: arFont,   .paragraphStyle: rtlParaStyle]

    let arHeight: CGFloat = 23

    let enUnderlined = en.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let zhUnderlined = zh.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let arUnderlined = ar.updated(with: NSUnderlineStyle.single.rawValue as NSNumber,
                                  forKey: .underlineStyle)

    let tests: [TestCase] = [
      TestCase(title: "Short English text ",
               NSAttributedString("John Appleseed", en),
               maxLineCount: 1),

      TestCase(title: "Longer English text ",
               NSAttributedString("All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.",
                                  en15),
               width: 258, maxLineCount: 0),

      TestCase(title: "Short truncated English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights.",
                                  en),
               width: 250, maxLineCount: 1),

      TestCase(title: "Longer truncated English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.",
                                  en15),
               width: 258, maxLineCount: 2),

      TestCase(title: "Autoscaled single-line English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights.",
                                  en),
               width: 288, maxLineCount: 1, minTextScaleFactor: 0.5),

      TestCase(title: "Autoscaled two-paragraph English text",
               NSAttributedString("All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.\nEveryone is entitled to all the rights and freedoms set forth in this Declaration, without distinction of any kind, such as race, colour, sex, language, religion, political or other opinion, national or social origin, property, birth or other status.",
                                  en15),
               width: 274, height: 135, maxLineCount: 0, minTextScaleFactor: 0.5),

      TestCase(title: "Short underlined English text",
               NSAttributedString("John Appleseed", enUnderlined),
               needsAttributes: true),

      TestCase(title: "Short Chinese text",
               NSAttributedString("简短的中文文本", zh)),

      TestCase(title: "Longer Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。他们赋有理性和良心,并应以兄弟关系的精神相对待。",
                                  zh),
               width: 250, maxLineCount: 0),

      TestCase(title: "Short truncated Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。",
                                  zh),
               width: 243, maxLineCount: 1),

      TestCase(title: "Longer truncated Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。他们赋有理性和良心,并应以兄弟关系的精神相对待。",
                                  zh),
               width: 288, maxLineCount: 2),

      TestCase(title: "Autoscaled single-line Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。", zh),
               width: 270, maxLineCount: 1, minTextScaleFactor: 0.5),

      TestCase(title: "Autoscaled two-paragraph Chinese text",
               NSAttributedString("人人生而自由,在尊严和权利上一律平等。他们赋有理性和良心,并应以兄弟关系的精神相对待。\n人人有资格享有本宣言所载的一切权利和自由,不分种族、肤色、性别、语言、宗教、政治或其他见解、国籍或社会出身、财产、出生或其他身分等任何区别。",
                                  zh),
               width: 270, height: 135, maxLineCount: 0, minTextScaleFactor: 0.5),

      TestCase(title: "Short underlined Chinese text",
               NSAttributedString("简短的中文文本", zhUnderlined),
               needsAttributes: true),

      TestCase(title: "Short Arabic text",
               NSAttributedString("نص عربي قصير", ar),
               width: 122, height: arHeight, fixHeight: true),

       TestCase(title: "Longer Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق. وقد وهبوا عقلاً وضميرًا وعليهم أن يعامل بعضهم بعضًا بروح الإخاء.",
                                  ar),
               width: 288, height: arHeight*3 - 5, fixHeight: true, maxLineCount: 0),

      TestCase(title: "Short truncated Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق.", ar),
               width: 235, height: arHeight, fixHeight: true, maxLineCount: 1),

      TestCase(title: "Longer truncated Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق. وقد وهبوا عقلاً وضميرًا وعليهم أن يعامل بعضهم بعضًا بروح الإخاء.",
                                  ar),
               width: 280, height: 2*arHeight - 3, fixHeight: true, maxLineCount: 2),

      TestCase(title: "Autoscaled single-line Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق.", ar),
               width: 288, height: arHeight, fixHeight: true, maxLineCount: 1,
               minTextScaleFactor: 0.5),

      TestCase(title: "Autoscaled two-paragraph Arabic text",
               NSAttributedString("يولد جميع الناس أحرارًا متساوين في الكرامة والحقوق. وقد وهبوا عقلاً وضميرًا وعليهم أن يعامل بعضهم بعضًا بروح الإخاء.\nلكل إنسان حق التمتع بكافة الحقوق والحريات الواردة في هذا الإعلان، دون أي تمييز، كالتمييز بسبب العنصر أو اللون أو الجنس أو اللغة أو الدين أو الرأي السياسي أو أي رأي آخر، أو الأصل الوطني أو الإجتماعي أو الثروة أو الميلاد أو أي وضع آخر، دون أية تفرقة بين الرجال والنساء.",
                                  ar),
               width: 270, height: 150, maxLineCount: 0, minTextScaleFactor: 0.5),

      TestCase(title: "Short underlined Arabic text",
               NSAttributedString("نص عربي قصير", arUnderlined), needsAttributes: true,
               width: 122, height: arHeight, fixHeight: true)
    ]



    let displayers: [NamedDisplayer] = [
      // Fixed layout

      .init("STULabel", "fixed layout, simple string, clipsContentToBounds",
            createDisplayer(createSTULabelWithClipsContentToBounds, displaySimpleString),
            enabledByDefault: false),
      .init("STULabel", "fixed layout, simple string",
            createDisplayer(createSTULabel, displaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "fixed layout, simple string, clipsToBounds",
            createDisplayer(createUILabelWithClipsToBounds, displaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "fixed layout, simple string",
            createDisplayer(createUILabel, displaySimpleString),
            enabledByDefault: false),
      .init("UITextView", "fixed layout, simple string",
            createDisplayer(createUITextView, displaySimpleString),
            enabledByDefault: false),

      .init("STULabel", "fixed layout, attrib. string, clipsContentToBounds",
            createDisplayer(createSTULabelWithClipsContentToBounds, displayAttributedString),
            enabledByDefault: true),
      .init("STULabel", "fixed layout, attrib. string",
            createDisplayer(createSTULabel, displayAttributedString),
            enabledByDefault: false),
      .init("UILabel", "fixed layout, attrib. string, clipsToBounds",
            createDisplayer(createUILabelWithClipsToBounds, displayAttributedString),
            enabledByDefault: true),
      .init("UILabel", "fixed layout, attrib. string",
            createDisplayer(createUILabel, displayAttributedString),
            enabledByDefault: false),
      .init("UITextView", "fixed layout, attrib. string",
            createDisplayer(createUITextView, displayAttributedString),
            enabledByDefault: true),

      // Size that fits

      .init("STULabel", "sizeThatFits, simple string, clipsContentToBounds",
            createDisplayer(createSTULabelWithClipsContentToBounds,
                            sizeThatFitsAndDisplaySimpleString),
            enabledByDefault: false),
      .init("STULabel", "sizeThatFits, simple. string",
            createDisplayer(createSTULabel, sizeThatFitsAndDisplaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "sizeThatFits, simple. string, clipsToBounds",
            createDisplayer(createUILabelWithClipsToBounds, sizeThatFitsAndDisplaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "sizeThatFits, simple. string",
            createDisplayer(createUILabel, sizeThatFitsAndDisplaySimpleString),
            enabledByDefault: false),
      .init("UITextView", "sizeThatFits, simple string",
            createDisplayer(createUITextView, sizeThatFitsAndDisplaySimpleString),
            enabledByDefault: false),

      .init("STULabel", "sizeThatFits, attrib. string, clipsContentToBounds",
            createDisplayer(createSTULabelWithClipsContentToBounds,
                            sizeThatFitsAndDisplayAttributedString),
            enabledByDefault: false),
      .init("STULabel", "sizeThatFits, attrib. string",
            createDisplayer(createSTULabel, sizeThatFitsAndDisplayAttributedString),
            enabledByDefault: false),
      .init("UILabel", "sizeThatFits, attrib. string, clipsToBounds",
            createDisplayer(createUILabelWithClipsToBounds, sizeThatFitsAndDisplayAttributedString),
            enabledByDefault: false),
      .init("UILabel", "sizeThatFits, attrib. string",
            createDisplayer(createUILabel, sizeThatFitsAndDisplayAttributedString),
            enabledByDefault: false),
      .init("UITextView", "sizeThatFits, attrib. string",
            createDisplayer(createUITextView, sizeThatFitsAndDisplayAttributedString),
            enabledByDefault: false),

      // Auto layout

      .init("STULabel", "auto layout, simple string, clipsContentToBounds",
            createDisplayer(autoLayout: true, createSTULabelWithClipsContentToBounds,
                            displaySimpleString),
            enabledByDefault: false),
      .init("STULabel", "auto layout, simple string",
            createDisplayer(autoLayout: true, createSTULabel, displaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "auto layout, simple string, clipsToBounds",
            createDisplayer(autoLayout: true, createUILabelWithClipsToBounds, displaySimpleString),
            enabledByDefault: false),
      .init("UILabel", "auto layout, simple string",
            createDisplayer(autoLayout: true, createUILabel, displaySimpleString),
            enabledByDefault: false),
      .init("UITextView", "auto layout, simple string",
            createDisplayer(autoLayout: true, createUITextView, displaySimpleString),
            enabledByDefault: false),

      .init("STULabel", "auto layout, attrib. string, clipsContentToBounds",
            createDisplayer(autoLayout: true, createSTULabelWithClipsContentToBounds,
                            displayAttributedString),
            enabledByDefault: true),
      .init("STULabel", "auto layout, attrib. string",
            createDisplayer(autoLayout: true, createSTULabel, displayAttributedString),
            enabledByDefault: false),
      .init("UILabel", "auto layout, attrib. string, clipsToBounds",
            createDisplayer(autoLayout: true, createUILabelWithClipsToBounds, displayAttributedString),
            enabledByDefault: true),
      .init("UILabel", "auto layout, attrib. string",
            createDisplayer(autoLayout: true, createUILabel, displayAttributedString),
            enabledByDefault: false),
      .init("UITextView", "auto layout, attrib. string",
            createDisplayer(autoLayout: true, createUITextView, displayAttributedString),
            enabledByDefault: true),

    ]

    self.displayers = displayers

    let nonUITextViewDisplayers = displayers.filter { $0.name != "UITextView" }
    let attributedStringDisplayers = displayers.filter { $0.features.contains("attrib") }
    let nonUITextViewAttributedStringDisplayers =
          nonUITextViewDisplayers.filter { $0.features.contains("attrib") }
    var views = [ResultView]()

    for test in tests {
      views.append(ResultView(test,
                              test.minTextScaleFactor == 1
                              ? (test.needsAttributes ? attributedStringDisplayers : displayers)
                              : (test.needsAttributes ? nonUITextViewAttributedStringDisplayers
                                                      : nonUITextViewDisplayers)))
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
    notes.text = "The goal here is to measure the best case performance under ideal conditions, i.e. with hot caches, pre-trained branch predictors and a minimum of other code running. For this purpose we run each test scenario in a loop for a fixed amount of time (after a small fixed number of warmup iterations) and record the minimum time it takes.\n\nThe measured times will depend on the device type and the iOS version. If you're seeing unstable measurements, it's probably because of background activity and/or dynamic CPU scaling. \n\nWe only benchmark synchronous layout and drawing on the main thread here, and only up to the point where the view has been drawn into the graphics context provided by Core Animation. In order to force a text relayout, we switch between two strings in each loop iteration (prefixed by a \"1\" or \"2\"). When a measurement ends, the corresponding sample view at the top of the test case (with a yellow background) will be replaced with result from the last iteration. This gives you a chance to inspect the render result.\n\nSTULabel is fastest with an attributed string as the input and with \"clipsContentToBounds\" enabled. UILabel is fastest with a simple string as the input and with \"clipsToBounds\" enabled (though clipsToBounds only seems to make a difference for the non-English test cases)."

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

  let cancelButton = UIBarButtonItem(title: "Cancel", style: .done, target: nil, action: nil)

  private var measurementCancelled: Bool = false

  @objc
  private func cancelMeasurement() {
    measurementCancelled = true
    cancelButton.isEnabled = false
  }

  private func measureDrawingTimes(_ view: ResultView) {
    let testCase = view.testCase
    let displayers = view.displayers.enumerated().filter{ (i, d) in d.enabled.value }
    guard displayers.count > 0
    else {
      let ac = UIAlertController(title: "Error", message: "No compatible label view is enabled. Please select one.",
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
        let (container, display) = d.displayer(testCase)
        display(0)
        sv.labelContainer = container
      }
    }

    var results = view.results
    for i in results.indices {
      results[i] = Result(results[i].displayer)
    }
    view.results = results

    let measurementWindow = UIWindow(frame: self.view.window!.screen.bounds)
    measurementWindow.rootViewController = UIViewController(nibName: nil, bundle: nil)
    measurementWindow.isUserInteractionEnabled = false
    measurementWindow.isHidden = false

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
        let (displayerIndex, displayer) = displayers[index]
        let (container, display) = displayer.displayer(testCase)
        assert(container.label.maximumNumberOfLines == testCase.maxLineCount)

        measurementWindow.addSubview(container)

        // We want the sample view to change after each measurement, so we switch between
        // odd and even iteration counts.
        let iterCountModulo2 = ((iterationCountModulo2ByDisplayerName[displayer.name] ?? 1) + 1)%2
        iterationCountModulo2ByDisplayerName[displayer.name] = iterCountModulo2
        let stats = timeExecution(display,
                                  measurementTime: CFTimeInterval(self.measureDurationMS.value)/1000,
                                  iterationCountModulo2: iterCountModulo2)

        print(container.subviews.first!.frame)

        container.removeFromSuperview()

        assert(container.label.maximumNumberOfLines == testCase.maxLineCount)
        assert(results[displayerIndex].displayer == displayer)
        results[displayerIndex] = Result(displayer, container, stats)
        view.results = results

        print("\(displayer.name) (\(displayer.features)),",
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
    init(_ vc: LabelPerformanceVC) {
      super.init()
      shouldUpdatePreferredContentSize = true
      minPreferredContentWidth = 400
      let font1 = UIFont.preferredFont(forTextStyle: .headline)
      let font2 = UIFont.preferredFont(forTextStyle: .callout)
      cells = [StepperCell("Measure", 100...10000, step: 100, vc.measureDurationMS, unit: "ms"),
               StepperCell("Pause", 100...10000, step: 100, vc.pauseDurationMS, unit: "ms")]
            + vc.displayers.map { d in
                let text = NSAttributedString([(d.name, [.font: font1]),
                                               (" (" + d.features + ")", [.font: font2])])
                return SwitchCell(text, d.enabled)
              }
    }
  }
}





