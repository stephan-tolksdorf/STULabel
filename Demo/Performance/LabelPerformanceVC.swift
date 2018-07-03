// Copyright 2018 Stephan Tolksdorf

import STULabel

class LabelPerformanceTestCase {
  let title: String
  let attributedString1: NSAttributedString
  let attributedString2: NSAttributedString
  let string1: NSString
  let string2: NSString
  let font: UIFont
  let isRightToLeft: Bool
  let isSimple: Bool
  let size: CGSize
  let lineCount: Int
  let minTextScaleFactor: CGFloat

  init(title: String,
       _ attributedString1: NSAttributedString, _ attributedString2: NSAttributedString,
       width: CGFloat,
       maxLineCount: Int = 0,
       minTextScaleFactor: CGFloat = 1)
  {
    self.title = title
    self.attributedString1 = NSAttributedString(attributedString: attributedString1)
    self.attributedString2 = NSAttributedString(attributedString: attributedString2)
    self.string1 = attributedString1.string as NSString
    self.string2 = attributedString2.string as NSString
    self.minTextScaleFactor = minTextScaleFactor

    self.font = attributedString1.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
    let paraStyle = attributedString1.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                    as! NSParagraphStyle?
    self.isRightToLeft = paraStyle?.baseWritingDirection == .rightToLeft

    let attribs: [NSAttributedStringKey: Any] = [
      .font: self.font,
      .paragraphStyle: self.isRightToLeft ? rtlParaStyle : ltrParaStyle
    ]
    self.isSimple = attributedString1 == NSAttributedString(attributedString1.string, attribs)
                 && attributedString2 == NSAttributedString(attributedString2.string, attribs)

    let options = STUTextFrameOptions({b in b.maxLineCount = maxLineCount })

    let info1 = STUTextFrame(STUShapedString(attributedString1,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 1000),
                             options: options).layoutInfo
    let info2 = STUTextFrame(STUShapedString(attributedString2,
                                             defaultBaseWritingDirection: .leftToRight),
                             size: CGSize(width: width, height: 1000),
                             options: options).layoutInfo
    self.lineCount = Int(max(info1.lineCount, info2.lineCount))
    self.size = CGSize(width: width, height: ceil(max(info1.layoutBounds.maxY,
                                                      info2.layoutBounds.maxY)))
    print(size, info1.scaleFactor)

  }
}

class LabelContainer : UIView {
  fileprivate let label: LabelView & UIView

  fileprivate init(_ testCase: LabelPerformanceTestCase, label: LabelView & UIView, autoLayout: Bool) {
    self.label = label
    let frame = CGRect(origin: .zero, size: testCase.size)
    label.frame = frame
    super.init(frame: frame)
    addSubview(label)
    if autoLayout {
      label.translatesAutoresizingMaskIntoConstraints = false
      [constrain(label, .left,  .equal, self, .left, constant: frame.origin.x),
       constrain(label, .top,   .equal, self, .top, constant: frame.origin.y),
       constrain(label, .width, .lessThanOrEqual, frame.size.width)
      ].activate()
    }
  }

  required init?(coder aDecoder: NSCoder) { fatalError() }

  override func layoutSubviews() {
    super.layoutSubviews()
  }

  override class var requiresConstraintBasedLayout: Bool { return true }
}

typealias LabelPerformanceTestCaseDisplayer =
  (LabelPerformanceTestCase) -> (LabelContainer, (_ index: Int) -> Void)



private func timeExecution(_ function: (_ iteration: Int) -> Void,  iterations: Int = 10000)
          -> (minDuration: CFTimeInterval, avgDuration: CFTimeInterval)
{
  var minDuration: CFTimeInterval = .infinity
  var totalDuration: CFTimeInterval = 0
  if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
    kdebug_signpost_start(0, 0, 0, 0, 0);
  }
  for i in 0..<iterations {
    let t0 = CACurrentMediaTime()
    autoreleasepool {
      function(i)
    }
    let t1 = CACurrentMediaTime()
    let d = t1 - t0
    // We ignore the first two iterations.
    if i > 1 {
      minDuration = min(minDuration, d)
      totalDuration += d
    }
  }
  if #available(iOS 10, tvOS 10, watchOS 3, macOS 10.12, *) {
    kdebug_signpost_end(0, 0, 0, 0, 0);
  }
  let avgDuration = totalDuration/Double(iterations)
  return (minDuration, avgDuration)
}





private
func displaySimpleString<Label: LabelView & UIView>(_ label: Label, _ string: NSString) -> Int {
  label.string = string
  label.layer.displayIfNeeded()
  return 0
}

private
func sizeThatFitsAndDisplaySimpleString<Label: LabelView & UIView>(_ label: Label, _ string: NSString)
  -> Int
{
  label.string = string
  let width = label.superview!.bounds.width
  _ = label.sizeThatFits(CGSize(width: width, height: 10000))
  label.displayIfNeeded()
  return 0
}

private
func autoLayoutAndDisplaySimpleString<Label: LabelView & UIView>(_ label: Label, _ string: NSString)
  -> Int
{
  label.string = string
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}



private
func displayAttributedString<Label: LabelView & UIView>(_ label: Label,
                                                        _ string: NSAttributedString) -> Int {
  label.attributedString = string
  label.displayIfNeeded()
  return 0
}

private
func autoLayoutAndDisplayAttributedString<Label: LabelView & UIView>(_ label: Label, _ string: NSAttributedString)
  -> Int
{
  label.attributedString = string
  label.superview!.layoutIfNeeded()
  label.displayIfNeeded()
  return 0
}



private func createSTULabel(_ testCase: LabelPerformanceTestCase) -> STULabel {
  let label = STULabel()
  label.font = testCase.font
  if testCase.lineCount > 1 {
    label.maxLineCount = testCase.lineCount
  }
  if testCase.minTextScaleFactor < 1 {
    label.minTextScaleFactor = testCase.minTextScaleFactor
  }

  return label
}

private func createUILabel(_ testCase: LabelPerformanceTestCase) -> UILabel {
  let label = UILabel()
  label.font = testCase.font
  if testCase.lineCount > 1 {
    label.maxLineCount = testCase.lineCount
  }
  if testCase.minTextScaleFactor < 1 {
    label.minimumScaleFactor = testCase.minTextScaleFactor
    label.adjustsFontSizeToFitWidth = true
  }
  return label
}

private func createUITextView(_ testCase: LabelPerformanceTestCase) -> UITextView {
  let label = UITextView()
  label.isScrollEnabled = false
  label.textContainer.lineFragmentPadding = 0
  label.textContainerInset = .zero
  label.textContainer.lineBreakMode = .byTruncatingTail
  label.backgroundColor = .clear
  label.font = testCase.font
  if testCase.lineCount == 1 {
    label.textContainer.maximumNumberOfLines = 1
  }
  // UITextView has no built-in support for font scaling
  return label
}

private func createDisplayer<Label: LabelView & UIView>(
               autoLayout: Bool = false,
               _ createLabel:  @escaping (LabelPerformanceTestCase) -> Label,
               _ display: @escaping (Label, NSString) -> Int)
  -> LabelPerformanceTestCaseDisplayer
{
  return { (_ testCase: LabelPerformanceTestCase) in
    let label = createLabel(testCase)
    //label.backgroundColor = UIColor.white
    let container = LabelContainer(testCase, label: label, autoLayout: autoLayout)
    return (container, {(index: Int) in
             _ = display(label, index & 1  == 0 ? testCase.string1 : testCase.string2)
           })
  }
}

private func createDisplayer<Label: LabelView & UIView>(
               autoLayout: Bool = false,
               _ createLabel:  @escaping (LabelPerformanceTestCase) -> Label,
               _ display: @escaping (Label, NSAttributedString) -> Int)
  -> LabelPerformanceTestCaseDisplayer
{
  return { (_ testCase: LabelPerformanceTestCase) in
    let label = createLabel(testCase)
   // label.backgroundColor = UIColor.white
    let container = LabelContainer(testCase, label: label, autoLayout: autoLayout)
    return (container, {(index: Int) in
             _ = display(label,
                         index & 1 == 0 ? testCase.attributedString1
                                        : testCase.attributedString2)
           })
  }
}


class LabelPerformanceVC : UIViewController {
  typealias TestCase = LabelPerformanceTestCase

  typealias Displayer = LabelPerformanceTestCaseDisplayer

  class NamedDisplayer : Equatable, Hashable {
    let title: String
    let subtitle: String?
    let displayer: LabelPerformanceTestCaseDisplayer

    init(_ title: String, _ subtitle: String? = nil,
         _ displayer: @escaping LabelPerformanceTestCaseDisplayer)
    {
      self.title = title
      self.subtitle = subtitle
      self.displayer = displayer
    }

    static func ==(_ lhs: NamedDisplayer, _ rhs: NamedDisplayer) -> Bool {
      return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    var hashValue: Int { return ObjectIdentifier(self).hashValue }
  }

  private typealias Result = (displayer: NamedDisplayer, container: LabelContainer,
                              time: CFTimeInterval?)


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
          widthConstraint.constant = frame.maxX
          heightConstraint.constant = frame.maxY
        } else {
          widthConstraint.constant = 0
          heightConstraint.constant = 0
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

      func sampleView(_ title: String, _ labelContainer: LabelContainer) -> SampleViewWithLabel {
        if let sv = sampleViewsByLabel[title] { return sv }
        let sv = SampleView()
        sv.backgroundColor = .yellow
        sv.labelContainer = labelContainer
        let svl = SampleViewWithLabel(sv)
        svl.label.text = title
        sampleViews.append(svl)
        sampleViewsByLabel[title] = svl
        return svl
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

      var sampleViewsByDisplayer = [NamedDisplayer : SampleViewWithLabel]()
      var timingRowsByDisplayer = [NamedDisplayer : TimingRow]()
      var results = [Result]()
      for d in displayers {
        let (container, display) = d.displayer(testCase)
        display(0)
        results.append((d, container, nil))
        sampleViewsByDisplayer[d] = sampleView(d.title, container)
        let r = TimingRow()
        r.column1Label.attributedText = column1Label(d.title, d.subtitle)
        timingRowsByDisplayer[d] = r
      }
      self.sampleViewsByDisplayer = sampleViewsByDisplayer
      self.timingRowsByDisplayer = timingRowsByDisplayer
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
      timingRows = displayers.map({ timingRowsByDisplayer[$0]! })
    }

    var results: [Result] {
      didSet {
        var firstTime: CFTimeInterval?
        for (d, container, time) in results {
          let timeLabel = timingRowsByDisplayer[d]!.column2Label
          let factor: Double
          if let time = time {
            sampleViewsByDisplayer[d]!.view.labelContainer = container
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

    let ltr: [NSAttributedStringKey: AnyObject] = [.font: font, .paragraphStyle: ltrParaStyle /*, .foregroundColor: UIColor.blue */]
    let rtl: [NSAttributedStringKey: AnyObject] = [.font: font, .paragraphStyle: rtlParaStyle]

    var tests = [TestCase]()

    tests.append(TestCase(title: "Short English text ",
                          NSAttributedString("John Appleseed 1", ltr),
                          NSAttributedString("John Appleseed 2", ltr),
                          width: 200, maxLineCount: 1, minTextScaleFactor: 0.5))

    tests.append(TestCase(title: "Longer English text ",
                          NSAttributedString("John Appleseed 1 John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed", ltr),
                          NSAttributedString("John Appleseed 2 John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed John Appleseed", ltr),
                          width: 200, maxLineCount: 0/*, minTextScaleFactor: 0.1*/))

    tests.append(TestCase(title: "Short Chinese text",
                          NSAttributedString("至前研家样真般并 林解采音四题关子 1", ltr),
                          NSAttributedString("至前研家样真般并 林解采音四题关子 2", ltr),
                          width: 300, maxLineCount: 1))

    tests.append(TestCase(title: "Longer Chinese text",
                          NSAttributedString("１ 至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子", ltr),
                          NSAttributedString("２ 至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子  至前研家样真般并 林解采音四题关子", ltr),
                          width: 300))

    tests.append(TestCase(title: "Short Arabic text ",
                          NSAttributedString("نص عربي قصير 1", rtl),
                          NSAttributedString("نص عربي قصير 2", rtl),
                          width: 200, maxLineCount: 1, minTextScaleFactor: 0.5))


    let displayers: [NamedDisplayer] = [ // https://bugs.swift.org/browse/SR-7875

/*
      .init("STULabel", "simple string",
            createDisplayer(autoLayout: true, createSTULabel,
                            displaySimpleString as ((STULabel, NSString) -> Int))),
*/

      .init("STULabel", "simple string",
            createDisplayer(createSTULabel, displaySimpleString as ((STULabel, NSString) -> Int))),

      .init("UILabel", "simple string",
            createDisplayer(createUILabel, displaySimpleString as ((UILabel, NSString) -> Int))),
/*
      .init("UILabel", "attributed string",
            createDisplayer(createUILabel, displayAttributedString as ((UILabel, NSAttributedString) -> Int))),
*/
      .init("UITextView", "simple string",
            createDisplayer(createUITextView, displaySimpleString as ((UITextView, NSString) -> Int))),
/*
      .init("UITextView", "attributed string",
            createDisplayer(createUITextView, displayAttributedString as ((UITextView, NSAttributedString) -> Int))),
*/
/*
      .init("UILabel", "attributed string",
            createDisplayer(createUILabel, displayAttributedString)),
      .init("UITextView", "attributed string",
            createDisplayer(createUITextView, displayAttributedString)),
*/
/*
      .init("STULabel", "sizeThatFits string",
            createDisplayer(createSTULabel, sizeThatFitsAndDisplaySimpleString)),
      .init("UILabel", "sizeThatFits string",
            createDisplayer(createUILabel, sizeThatFitsAndDisplaySimpleString)),
      .init("UITextView", "sizeThatFits string",
            createDisplayer(createUITextView, sizeThatFitsAndDisplaySimpleString)),
 */
/*
      .init("STULabel", "auto layout string",
            createDisplayer(createSTULabel, autoLayoutAndDisplaySimpleString)),
      .init("UILabel", "auto layout string",
            createDisplayer(createUILabel, autoLayoutAndDisplaySimpleString)),
      .init("UITextView", "auto layout string",
            createDisplayer(createUITextView, autoLayoutAndDisplaySimpleString))
 */

      .init("STULabel", "auto layout attributed string",
            createDisplayer(createSTULabel, autoLayoutAndDisplayAttributedString as (STULabel, NSAttributedString) -> Int)),
      .init("UILabel", "auto layout attributed string",
            createDisplayer(createUILabel, autoLayoutAndDisplayAttributedString as (UILabel, NSAttributedString) -> Int)),
      .init("UITextView", "auto layout attributed string",
            createDisplayer(createUITextView, autoLayoutAndDisplayAttributedString as (UITextView, NSAttributedString) -> Int))

    ]

    var views = [ResultView]()

    for test in tests {
      views.append(ResultView(test, displayers))
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
    let displayers = view.displayers

    view.window?.isUserInteractionEnabled = false
    view.window?.tintAdjustmentMode = .dimmed

    view.button.isEnabled = false

    func setButtonTitle(measurementIndex: Int) {
      view.button.setTitle("Measuring... \(measurementIndex + 1)/\(displayers.count)", for: .normal)
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
        let displayer = displayers[index]
        let (container, display) = displayer.displayer(test)
        let (minDuration, avgDuration) = timeExecution(display)
        _ = avgDuration
        results[index] = (displayer, container, minDuration)
        view.results = results
        if index + 1 < displayers.count {
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





