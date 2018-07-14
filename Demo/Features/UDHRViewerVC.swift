// Copyright 2018 Stephan Tolksdorf

import STULabelSwift
import STULabel.MainScreenProperties
import STULabel.Unsafe


let underlineStyles: [(name: String, style: NSUnderlineStyle)] = [
  ("None", NSUnderlineStyle(rawValue: 0)!),
  ("Single", .styleSingle),
  ("Single thick", NSUnderlineStyle(rawValue: NSUnderlineStyle.styleSingle.rawValue
                                            | NSUnderlineStyle.styleThick.rawValue)!),
  ("Double", .styleDouble),
  ("Double thick", NSUnderlineStyle(rawValue: NSUnderlineStyle.styleDouble.rawValue
                                            | NSUnderlineStyle.styleThick.rawValue)!)
]

let underlinePatterns: [(name: String, style: NSUnderlineStyle)] = [
  ("Solid", NSUnderlineStyle.patternSolid),
  ("Dot", NSUnderlineStyle.patternDot),
  ("Dash dot", NSUnderlineStyle.patternDashDot),
  ("Dash dot dot", NSUnderlineStyle.patternDashDotDot)
]

class UDHRViewerVC : UIViewController, STULabelDelegate, UIScrollViewDelegate,
                     UIPopoverPresentationControllerDelegate
{
  private enum Mode : Int {
    case stuLabel_vs_UITextView
    case stuLabel
    case zoomableSTULabel
    case uiTextView

    var description: String {
      switch self {
      case .stuLabel_vs_UITextView: return "STULabel vs UITextView"
      case .stuLabel:               return "STULabel in UIScrollView"
      case .zoomableSTULabel:       return "STULabel in zoomable UIScrollView"
      case .uiTextView:             return "UITextView"
      }
    }

    var isSingleLabelMode: Bool {
      switch self {
      case .stuLabel_vs_UITextView: return false
      case .stuLabel, .zoomableSTULabel, .uiTextView: return true
      }
    }

    static let allCases: [Mode] = [.stuLabel_vs_UITextView, .stuLabel, .zoomableSTULabel,
                                   .uiTextView]
  }

  private class MultiLabelScrollView : UIScrollView {
    var dynamicallyAddedSubviews = [UIView]()

    override func layoutSubviews() {
      let add_bounds = self.bounds.insetBy(dx: -50, dy: -50)
      let keep_bounds = add_bounds.insetBy(dx: -add_bounds.width*0.5,
                                           dy: -add_bounds.height*0.5)
      for subview in dynamicallyAddedSubviews {
        if subview.superview == nil {
          if subview.frame.intersects(add_bounds) {
            addSubview(subview)
          }
        } else {
          if !subview.frame.intersects(keep_bounds) {
            subview.removeFromSuperview()
          }
        }
      }
      super.layoutSubviews()
    }
  }

  private let copyrightFooter = STULabel()

  private var multiLabelScrollView = MultiLabelScrollView()
  private let stuLabelColumnHeader = STULabel()
  private let textViewColumnHeader = STULabel()
  private var stuLabels = [STULabel]()
  private var textViews = [UITextView]()

  private let largeSTULabel = STULabel()
  private var largeSTULabelScrollViewContentView = UIView()
  private var largeSTULabelScrollView = UIScrollView()

  private var largeTextView = UITextView()

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.navigationItem.title = "Universal Declaration of Human Rights"
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "toggle-icon"), style: .plain, target: self,
                                                             action: #selector(showSettings))

    stuLabelColumnHeader.text = "STULabel"
    stuLabelColumnHeader.font = UIFont.preferredFont(forTextStyle: .caption2)
    stuLabelColumnHeader.textColor = UIColor.darkGray

    textViewColumnHeader.text = "UITextView"
    textViewColumnHeader.font = UIFont.preferredFont(forTextStyle: .caption2)
    textViewColumnHeader.textColor = UIColor.darkGray

    copyrightFooter.text = "© 1996 – 2009 The Office of the High Commissioner for Human Rights"
    copyrightFooter.font = UIFont.preferredFont(forTextStyle: .caption2)
    copyrightFooter.textAlignment = .center
    copyrightFooter.maximumLineCount = 0
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let padding: CGFloat = 10

  private let usesAutoLayoutForLargeSTULabel = false

  private func scrollViewForMode(_ mode: Mode) -> UIScrollView {
    switch (mode) {
    case .stuLabel_vs_UITextView: return multiLabelScrollView
    case .stuLabel:               return largeSTULabelScrollView
    case .zoomableSTULabel:       return largeSTULabelScrollView
    case .uiTextView:             return largeTextView
    }
  }

  override func viewDidLoad() {
    view.backgroundColor = .white
    automaticallyAdjustsScrollViewInsets = false

    if #available(iOS 11.0, *) {
      multiLabelScrollView.contentInsetAdjustmentBehavior = .never
      largeSTULabelScrollView.contentInsetAdjustmentBehavior = .never
      largeTextView.contentInsetAdjustmentBehavior = .never
    }

    multiLabelScrollView.alwaysBounceVertical = false
    multiLabelScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    largeSTULabelScrollView.alwaysBounceVertical = false
    largeSTULabelScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    largeTextView.alwaysBounceVertical = false
    largeTextView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    multiLabelScrollView.delegate = self
    multiLabelScrollView.addSubview(stuLabelColumnHeader)
    multiLabelScrollView.addSubview(textViewColumnHeader)
    multiLabelScrollView.addSubview(copyrightFooter)

    largeTextView.isEditable = false
    largeTextView.textContainerInset = .zero
    largeTextView.textContainer.lineBreakMode = .byTruncatingTail
    largeTextView.textContainer.lineFragmentPadding = 0
    (largeTextView as UIScrollView).delegate = self

    largeSTULabelScrollView.maximumZoomScale = 10
    largeSTULabelScrollView.delegate = self
    largeSTULabelScrollView.addSubview(largeSTULabel)
    largeSTULabelScrollView.addSubview(largeSTULabelScrollViewContentView)
    largeSTULabelScrollViewContentView.addSubview(largeSTULabel)

    largeSTULabel.dragInteractionEnabled = true
    largeSTULabel.maximumLineCount = 0
    largeSTULabel.textLayoutMode = .textKit
    largeSTULabel.contentInsets = UIEdgeInsets(top: padding, left: padding,
                                            bottom: padding, right: padding)

    largeSTULabel.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(largeLabelWasTapped(_:))))

    largeSTULabel.highlightStyle = STUTextHighlightStyle({ b in
                                      b.background = STUBackgroundAttribute({ b in
                                                       b.color = UIColor.orange
                                                                 .withAlphaComponent(0.4)})
                                   })

    if usesAutoLayoutForLargeSTULabel {
      let container = largeSTULabelScrollViewContentView
      container.translatesAutoresizingMaskIntoConstraints = false
      largeSTULabel.translatesAutoresizingMaskIntoConstraints = false

      var cs = [NSLayoutConstraint]()

      constrain(&cs, container, toEdgesOf: largeSTULabelScrollView)
      constrain(&cs, container, .width, eq, largeSTULabelScrollView, .width)

      constrain(&cs, largeSTULabel, .centerX, eq, container, .centerX)
      constrain(&cs, largeSTULabel, .top,     eq, container, .top,    constant:  padding)
      constrain(&cs, largeSTULabel, .bottom,  eq, container, .bottom, constant: -padding)

      constrain(&cs, largeSTULabel, .width, leq, container.readableContentGuide, .width,
                constant: 2*padding)
      constrain(&cs, largeSTULabel, .width, leq, container, .width, constant: -2*padding,
                priority: .required)

      cs.activate()
    }

    updateText(removeSavedScrollStates: false)
  }

  func updateText(removeSavedScrollStates: Bool) {
    if removeSavedScrollStates {
      self.removeSavedScrollStates()
    }

    var n = 0
    func labelViews(topInset: CGFloat, bottomInset: CGFloat) -> (STULabel, UITextView) {
      let i = n
      n += 1
      let label: STULabel
      let textView: UITextView
      if i < stuLabels.count {
        label = stuLabels[i]
        textView = textViews[i]
        label.removeFromSuperview()
        textView.removeFromSuperview()
      } else  {
        assert(i == stuLabels.count)
        label = STULabel()
        textView = UITextView()
        if #available(iOS 11, *) {
          textView.textDragInteraction?.isEnabled = label.dragInteractionEnabled
        }
        multiLabelScrollView.dynamicallyAddedSubviews.append(label)
        multiLabelScrollView.dynamicallyAddedSubviews.append(textView)
        stuLabels.append(label)
        textViews.append(textView)
        label.textLayoutMode = .textKit
        label.maximumLineCount = 0
        label.defaultTextAlignment = .textStart
        label.clipsContentToBounds = false
        textView.configureForUseAsLabel()
        textView.maximumLineCount = 0
      }
      label.drawingBlock = { arg in print("Drawing article \(i)"); arg.draw() }
      label.contentInsets = UIEdgeInsets(top: topInset, left: padding,
                                         bottom: bottomInset, right: padding)
      textView.textContainerInset = UIEdgeInsets(top: topInset, left: padding,
                                                 bottom: bottomInset, right: padding)
      return (label, textView)
    }

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.baseWritingDirection = translation.writingDirection == .leftToRight
                                   ? .leftToRight : .rightToLeft
    paraStyle.lineSpacing = self.lineSpacing
    paraStyle.hyphenationFactor = hyphenate ? hyphenationFactor : 0
    if justify {
      paraStyle.alignment = .justified
    }

    let locale = NSLocale(localeIdentifier: translation.languageCode) as CFLocale

    var attributes: [NSAttributedStringKey: Any] = [
      .font: font,
      .paragraphStyle: paraStyle,
      kCTLanguageAttributeName as NSAttributedStringKey: translation.languageCode,
      NSAttributedStringKey("NSHyphenationLanguage"): translation.languageCode,
      .stuHyphenationLocaleIdentifier: translation.languageCode,
      NSAttributedStringKey(UIAccessibilitySpeechAttributeLanguage): translation.languageCode
    ]

    if underlineStyle.rawValue != 0 {
      attributes[.underlineStyle] = underlineStyle.rawValue
    }
    if strikethroughStyle.rawValue != 0 {
      attributes[.strikethroughStyle] = strikethroughStyle.rawValue
    }

    let lineSpacing = max(font.leading, self.lineSpacing)
    let lineHeight = font.ascender - font.descender + lineSpacing
    let bottomInset = max(0, lineHeight/2 - lineSpacing)
    let topInset = lineHeight - bottomInset;

    let text = NSMutableAttributedString()

    let title = NSAttributedString(translation.title, attributes)
    if mode.isSingleLabelMode {
      text.append(title)
    } else {
      let (label, textView) = labelViews(topInset: padding, bottomInset: bottomInset)
      label.attributedText = title
      textView.attributedText = title
    }

    let articles = translation.articles

    let hasPreamble = articles[0].paragraphs.count > 2

    let titleAttributes: [NSAttributedStringKey: Any] =
      attributes.merging([.font: font,
                          .foregroundColor: UIColor.darkGray,
                          .paragraphStyle: paraStyle],
                         uniquingKeysWith: { $1 })

    seedRand(1)

    let i0 = !hasPreamble ? articles.startIndex
           : translation.articles.index(after: articles.startIndex)
    for article in translation.articles[i0...] /*[i0...]  [i0+1..<i0+2] */ {

      let articleText = NSMutableAttributedString()

      if mode.isSingleLabelMode {
        articleText.append(NSAttributedString("\n\n", titleAttributes))
      }
      articleText.append(NSAttributedString(article.title, titleAttributes))
      for para in article.paragraphs {
        articleText.append(NSAttributedString("\n" + para, attributes))
      }

      let string = articleText.string as NSString

      for r in randomWordRanges(string as CFString, locale, 1, 3) {
        //var url = URLComponents(string: "tel:1234")!
        //var url = URLComponents(string: "mailto:STULabel@quanttec.com?Subject=Hello")!
        var url = URLComponents(string: "https://www.google.com/search")!
        url.queryItems = [URLQueryItem(name: "q", value: string.substring(with: r))]
        articleText.addAttribute(.link, value: url.url! as NSURL, range: r)
      }

      if mode.isSingleLabelMode {
        text.append(articleText)
      } else {
        let (label, textView) = labelViews(topInset: topInset, bottomInset: bottomInset)
        label.attributedText = articleText
        textView.attributedText = articleText
      }
    }
    for i in n..<stuLabels.count {
      stuLabels[i].removeFromSuperview()
      textViews[i].removeFromSuperview()
    }
    let d = stuLabels.count - n
    stuLabels.removeLast(d)
    textViews.removeLast(d)
    multiLabelScrollView.dynamicallyAddedSubviews.removeLast(2*d)

    if mode.isSingleLabelMode {
      if mode == .uiTextView {
        largeTextView.attributedText = text
      } else {
        largeSTULabel.attributedText = text
      }
    }

    lastLayoutWidth = nil
    view.setNeedsLayout()
  }

  private var lastLayoutWidth: CGFloat?

  override func viewWillLayoutSubviews() {
    let viewBounds = view.bounds
    let viewWidth = viewBounds.size.width

    // Will be set to false in viewDidLayoutSubviews.
    doNotRemoveSavedScrollStatesOnContentOffsetChanges = true

    if viewWidth == lastLayoutWidth { return }
    lastLayoutWidth = viewWidth
    defer {
      restoreScrollState()
    }

    let scrollView = scrollViewForMode(mode)
    if scrollView.superview == nil {
      scrollView.frame = viewBounds
      view.insertSubview(scrollView, at: 0)
    }

    let readableWidth = scrollView.readableContentGuide.layoutFrame.size.width

    let scale = UIScreen.main.scale
    func floorToScale(_ x: CGFloat) -> CGFloat { return floor(x*scale)/scale }
    func ceilToScale(_ x: CGFloat) -> CGFloat { return ceil(x*scale)/scale }


    if mode.isSingleLabelMode {
      if !usesAutoLayoutForLargeSTULabel {
        if mode == .uiTextView {
          largeTextView.frame = viewBounds
          let sidePadding = max(2*padding, floorToScale((viewWidth - readableWidth)/2))
          largeTextView.textContainerInset = UIEdgeInsets(top: 2*padding, left: sidePadding,
                                                          bottom: 2*padding, right: sidePadding)
          if !isSettingsPopoverVisible {
            // UITextView's lazy layout is too slow for smooth scrolling, even on modern devices.
            largeTextView.layoutManager.ensureLayout(forCharacterRange: NSRange(0..<100000))
          }
          return
        }
        let maxPadding = ceilToScale(max(CTFontGetBoundingBox(font as CTFont).size.width, padding))
        let width = min(viewWidth, readableWidth + 2*maxPadding)
        let sidePadding = max(2*padding, floorToScale((width - readableWidth)/2))
        largeSTULabel.contentInsets = UIEdgeInsets(top: 2*padding, left: sidePadding,
                                                bottom: 2*padding, right: sidePadding)

        let height = largeSTULabel.sizeThatFits(CGSize(width: width, height: 100000)).height
        let x = floorToScale((viewWidth - width)/2)
        largeSTULabel.frame = CGRect(x: x, y: 0, width: width, height: height)

        let zoomScale = scrollView.zoomScale
        let position = zoomScale/2 * CGPoint(x: viewWidth, y: height)

        let contentSize = zoomScale*CGSize(width: viewWidth, height: height)
        scrollView.contentSize = contentSize
        largeSTULabelScrollViewContentView.layer.bounds = CGRect(x: 0, y: 0,
                                                                width: viewWidth, height: height)
        largeSTULabelScrollViewContentView.layer.position = position
      }
      return
    }

    let p = padding

    let width = floorToScale(min(viewWidth/2 - p, readableWidth + 2*p));

    var y: CGFloat = p;

    {
      let isRTL = translation.writingDirection  == .rightToLeft
      let w = width - 2*p
      let size1 = stuLabelColumnHeader.sizeThatFits(CGSize(width: w, height: 1000))
      let xOffset1 = isRTL ? w  - size1.width : 0
      stuLabelColumnHeader.frame = CGRect(origin: CGPoint(x: 2*p + xOffset1, y: y), size: size1)

      let size2 = textViewColumnHeader.sizeThatFits(CGSize(width: w, height: 1000))
      let xOffset2 = isRTL ? w - size2.width : 0
      textViewColumnHeader.frame = CGRect(origin: CGPoint(x: p + width + p + xOffset2, y: y),
                                          size: size2)
      y += max(size1.height, size2.height)
    }()

    for i in 0..<stuLabels.count {
      let label = stuLabels[i]
      let height = label.sizeThatFits(CGSize(width: width, height: 100000)).height
      label.frame = CGRect(x: p, y: y, width: width, height: height)
      let textView = textViews[i]
      let height2 = textView.sizeThatFits(CGSize(width: width, height: 100000)).height
      textView.frame = CGRect(x: p + width, y: y, width: width, height: height2)
      y = y + max(height, height2)
    }
    y += p;

    {
      let size = copyrightFooter.sizeThatFits(CGSize(width: viewWidth, height: 1000))
      let x = ceilToScale((viewWidth - size.width)/2)
      copyrightFooter.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
      y += size.height
    }()

    y += p
    scrollView.contentSize = CGSize(width: viewWidth, height: y)
  }

  override func viewDidLayoutSubviews() {
    let scrollView = self.scrollViewForMode(mode)
    let topInset = self.topLayoutGuide.length
    let oldTopInset = scrollView.contentInset.top
    if topInset != oldTopInset {
      scrollView.contentInset.top = topInset
      scrollView.contentOffset.y += oldTopInset - topInset
    }
    restoreScrollState()
    doNotRemoveSavedScrollStatesOnContentOffsetChanges = false
  }

  // MARK: - Grapheme cluster highlighting

  @objc
  func largeLabelWasTapped(_ gestureRecognizer: UITapGestureRecognizer) {
    if gestureRecognizer.state == .ended {
      let point = gestureRecognizer.location(in: largeSTULabel)
      let textFrame = largeSTULabel.textFrame
      let r = textFrame.rangeOfGraphemeCluster(closestTo: point,
                                               ignoringTrailingWhitespace: true)
      largeSTULabel.isHighlighted = true
      largeSTULabel.setHighlight(r.range.rangeInTruncatedString, type: .rangeInTruncatedString)
      print("point in label: \(point), text frame origin: \(textFrame.origin)")
      print("grapheme cluster center: \(r.bounds.center)")
      print("grapheme cluster bounds: \(r.bounds)")
      print("grapheme cluster UTF-16 string range: \(r.range.rangeInTruncatedString) "
            + "'\((largeSTULabel.textFrame.truncatedAttributedString.string as NSString).substring(with: r.range.rangeInTruncatedString))'")
    }
  }

  // MARK: - Zooming

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    if mode == .zoomableSTULabel && scrollView == largeSTULabelScrollView {
      return largeSTULabelScrollViewContentView
    }
    return nil
  }

  func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?,
                               atScale scale: CGFloat)
  {
    if !doNotRemoveSavedScrollStatesOnContentOffsetChanges {
      removeSavedScrollStates()
    }
    if scrollView == largeSTULabelScrollView {
      largeSTULabel.contentScaleFactor = stu_mainScreenScale()*scale
      self.view.setNeedsLayout()
    }
  }

  // MARK: - Scroll offset preservation on mode changes and rotations

  private struct ScrollState {
    let mode: Mode
    let width: CGFloat
    let contentOffset: CGPoint
    let centerGraphemeClusterRange: STUTextRange?
  }

  private var scrollStates: [ScrollState] = []
  private var doNotRemoveSavedScrollStatesOnContentOffsetChanges: Bool = true

  private func saveScrollState() {
    doNotRemoveSavedScrollStatesOnContentOffsetChanges = true
    let width = self.view.bounds.size.width
    guard scrollStates.first(where: { $0.mode == mode && $0.width == width }) == nil
    else { return }
    var gcr: STUTextRange? = nil
    switch mode {
    case .stuLabel_vs_UITextView, .uiTextView: break
    case .stuLabel, .zoomableSTULabel:
      let view = self.view!
      let label = self.largeSTULabel
      let center = view.bounds.center + CGPoint(x: 0, y: self.topLayoutGuide.length/2)
      let textFrame = label.textFrame
      let p = label.convert(center, from: view)
      gcr = STUTextRange(textFrame.rangeOfGraphemeCluster(
                                     closestTo: p,
                                     ignoringTrailingWhitespace: true).range)
    }
    if mode == .uiTextView {
      // This is necessary to get the correct contentOffset (though it shouldn't be).
      largeTextView.layoutManager.ensureLayout(forCharacterRange: NSRange(0..<100000))
    }
    scrollStates.append(ScrollState(mode: mode,
                                    width: width,
                                    contentOffset: scrollViewForMode(mode).contentOffset,
                                    centerGraphemeClusterRange: gcr))
  }

  func restoreScrollState() {
    let viewBounds = self.view.bounds
    let width = viewBounds.size.width
    let height = viewBounds.size.height
    let scrollView = self.scrollViewForMode(mode)

    let topInset = scrollView.contentInset.top
    if mode == .uiTextView {
      // Setting the contentOffset doesn't work reliably without making sure that the text layout is
      // complete.
      largeTextView.layoutManager.ensureLayout(forCharacterRange: NSRange(0..<100000))
    }
    if let scrollState = scrollStates.first(where: { $0.mode == mode && $0.width == width })
                         ?? (!mode.isSingleLabelMode ? nil
                             : scrollStates.last(where: { $0.width == width && $0.mode.isSingleLabelMode }))
    {
      scrollView.setContentOffset(scrollState.contentOffset, animated: false)
      return
    }
    guard scrollView == largeSTULabelScrollView,
          let scrollState = scrollStates.last(where: { $0.centerGraphemeClusterRange != nil })
    else { return }
    let gcr = scrollState.centerGraphemeClusterRange!
    let textFrame = largeSTULabel.textFrame

    let labelFrame = largeSTULabel.frame

    let p = textFrame.rects(for: textFrame.range(for: gcr)).bounds.center + labelFrame.origin
    var contentOffset = p*scrollView.zoomScale
    contentOffset.x -= width/2
    contentOffset.y -= (height + topInset)/2
    let contentSize = scrollView.contentSize
    contentOffset.x = max(0, min(contentOffset.x, contentSize.width - width))
    contentOffset.y = max(-topInset,
                          min(contentOffset.y, contentSize.height - height))
    scrollView.setContentOffset(contentOffset, animated: false)
  }

  func removeSavedScrollStates() {
    scrollStates.removeAll()
  }

  override func viewWillTransition(to size: CGSize,
                                   with coordinator: UIViewControllerTransitionCoordinator)
  {
    saveScrollState()
    super.viewWillTransition(to: size, with: coordinator)
  }

  @objc
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if !doNotRemoveSavedScrollStatesOnContentOffsetChanges {
      removeSavedScrollStates()
    }
  }

  // MARK: - Settings

  private var mode: Mode = .stuLabel_vs_UITextView {
    willSet {
      if newValue == mode { return }
      if mode == .zoomableSTULabel {
        largeSTULabel.contentScaleFactor = stu_mainScreenScale()
        largeSTULabelScrollView.setZoomScale(1, animated: false)
      }
      saveScrollState()
      switch (mode) {
      case .stuLabel_vs_UITextView:
        for label in stuLabels { label.attributedText = nil }
        for label in textViews { label.attributedText = nil }
        multiLabelScrollView.removeFromSuperview()
      case .stuLabel, .zoomableSTULabel:
        largeSTULabel.attributedText = nil
        largeSTULabelScrollView.removeFromSuperview()
      case .uiTextView:
        largeTextView.attributedText = nil
        largeTextView.removeFromSuperview()
      }
    }
  }

  private var translation = udhr.translationsByLanguageCode["en"]!

  private var font: UIFont = UIFont.systemFont(ofSize: 16)

  private var lineSpacing: CGFloat = 0

  private var hyphenate: Bool = false

  private var hyphenationFactor: Float32 = 1

  private var justify: Bool = false

  private var isHyphenationAvailable: Bool {
    return CFStringIsHyphenationAvailableForLocale(
            NSLocale(localeIdentifier: translation.languageCode) as CFLocale)
  }

  private var underlineStyle = NSUnderlineStyle(rawValue: 0)!
  private var strikethroughStyle = NSUnderlineStyle(rawValue: 0)!

  private var isSettingsPopoverVisible = false {
    didSet {
      if isSettingsPopoverVisible == false && mode == .uiTextView {
        largeTextView.layoutManager.ensureLayout(forCharacterRange: NSRange(0..<100000))
      }
    }
  }

  @objc
  private func showSettings() {
    isSettingsPopoverVisible = true
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

  private class SettingsViewController : UITableViewController {
    var cells: [UITableViewCell]

    private weak var viewerVC: UDHRViewerVC?

    deinit {
      viewerVC?.isSettingsPopoverVisible = false
    }

    init(_ vc: UDHRViewerVC) {
      viewerVC = vc
      
      let modes = Mode.allCases.map({ $0.description })
      let modeCell = SelectCell("Mode", modes, index: vc.mode.rawValue)

      let currentLanguageIndex = udhr.translations.index{ $0 === vc.translation }!
      let languages = udhr.translations.map{ $0.language }

      let languageCell = SelectCell("Language", languages, index: currentLanguageIndex)
      let familyName = vc.font.familyName

      let fontFamilyIndex = fontFamilies.index(where: { $0.familyName == familyName })!
      let styles = fontFamilies[fontFamilyIndex].styles
      let fontName = vc.font.fontName
      let fontStyleIndex = styles.index(where: {$0.fontName == fontName})!

      let fontFamilyCell = SelectCell("Font", fontFamilies.map{ $0.familyName },
                                      index: fontFamilyIndex)

      let fontStyleCell = SelectCell("Font style", styles.map{ $0.styleName },
                                     index: fontStyleIndex)

      func fontSizeRange(fontName: String) -> ClosedRange<Double> {
        switch fontName {
        //  case ".SFUIText": return 1...19.5
        //  case ".SFUIDisplay":  return 20...200
          default: return 1...200
        }
      }

      let fontSizeCell = StepperCell("Font size", fontSizeRange(fontName: fontName), step: 0.5,
                                     value: Double(vc.font.pointSize), unit: "pt")
      fontSizeCell.isContinuous = false

      let lineSpacingCell = StepperCell("Line spacing", 0...200, step: 0.5,
                                        value: Double(vc.lineSpacing), unit: "pt")
      lineSpacingCell.isContinuous = false

      let hyphenateCell = SwitchCell("Hyphenate", value: vc.hyphenate)
      hyphenateCell.isEnabled = vc.isHyphenationAvailable

      let hyphenationFactorCell = StepperCell("Hyphen. factor", 0...1, step: 0.01,
                                              value: Double(vc.hyphenationFactor))
      hyphenationFactorCell.isEnabled = hyphenateCell.value

      let justifyCell = SwitchCell("Justify", value: vc.justify)

      let underlineStyle = vc.underlineStyle

      let underlineStyleIndex = underlineStyles.index {
                                   $0.style.rawValue == (underlineStyle.rawValue & 0xf)
                                }!

      let underlinePatternIndex = underlinePatterns.index {
                                    $0.style.rawValue == (underlineStyle.rawValue & 0x700)
                                  }!

      let underlineStyleCell = SelectCell("Underline style", underlineStyles.map{ $0.name },
                                          index: underlineStyleIndex)

      let underlinePatternCell = SelectCell("Underline pattern", underlinePatterns.map{ $0.name },
                                            index: underlinePatternIndex)

      let strikethroughStyleCell = SelectCell("Strikethrough style", underlineStyles.map{ $0.name },
                                              index: underlineStyleIndex)

      let strikethroughPatternCell = SelectCell("Strikethrough pattern",
                                                underlinePatterns.map{ $0.name },
                                                index: underlinePatternIndex)

      cells = [modeCell, languageCell, fontFamilyCell, fontStyleCell, fontSizeCell, lineSpacingCell,
               hyphenateCell, hyphenationFactorCell, justifyCell,
               underlineStyleCell, underlinePatternCell,
               strikethroughStyleCell, strikethroughPatternCell]

      modeCell.didChangeIndex = { value in
        vc.mode = Mode(rawValue: value)!
        vc.updateText(removeSavedScrollStates: false)
      }

      languageCell.didChangeIndex =  { value in
        vc.translation = udhr.translations[value]
        if !vc.isHyphenationAvailable {
          vc.hyphenate = false
          hyphenateCell.value = false
          hyphenateCell.isEnabled = false
          hyphenationFactorCell.isEnabled = false
        } else {
          hyphenateCell.isEnabled = true
        }
        vc.updateText(removeSavedScrollStates: true)
      }

      let updateFont = { [unowned fontFamilyCell, unowned fontStyleCell, unowned fontSizeCell] in
        let fontName = fontFamilies[fontFamilyCell.index].styles[fontStyleCell.index].fontName
        fontSizeCell.range = fontSizeRange(fontName: fontName)
        let size = CGFloat(fontSizeCell.value)
        let font = UIFont(name: fontName, size: size)!
        vc.font = font
        vc.updateText(removeSavedScrollStates: true)
      }
      fontFamilyCell.didChangeIndex = { fontFamilyIndex in
        let styles = fontFamilies[fontFamilyIndex].styles.map { $0.styleName}
        let oldStyleName = styleName(fontName: vc.font.fontName)
        let styleIndex = styles.index(where: { $0 == oldStyleName })
                      ?? styles.index(where: { $0 == "Regular" || $0 == "Medium"  }) ?? 0
        fontStyleCell.set(options: styles, index: styleIndex)
        updateFont()
      }
      fontStyleCell.didChangeIndex = { _ in updateFont() }
      fontSizeCell.didChangeValue = { _ in updateFont() }
      lineSpacingCell.didChangeValue = { newValue in
        vc.lineSpacing = CGFloat(newValue)
        vc.updateText(removeSavedScrollStates: true)
      }

      hyphenateCell.didChangeValue = { newValue in
        vc.hyphenate = newValue
        hyphenationFactorCell.isEnabled = newValue
        vc.updateText(removeSavedScrollStates: true)
      }
      hyphenationFactorCell.didChangeValue = { newValue in
        vc.hyphenationFactor = Float32(newValue)
        vc.updateText(removeSavedScrollStates: true)
      }
      justifyCell.didChangeValue = { newValue in
        vc.justify = newValue
        vc.updateText(removeSavedScrollStates: true)
      }

      let updateUnderlineStyle = {
        vc.underlineStyle = NSUnderlineStyle(rawValue:
                              underlineStyles[underlineStyleCell.index].style.rawValue
                            | underlinePatterns[underlinePatternCell.index].style.rawValue)!
        vc.updateText(removeSavedScrollStates: false)
      }
      underlineStyleCell.didChangeIndex = { _ in updateUnderlineStyle() }
      underlinePatternCell.didChangeIndex = { _ in updateUnderlineStyle() }

      let updateStrikethroughStyle = {
        vc.strikethroughStyle = NSUnderlineStyle(rawValue:
                                  underlineStyles[strikethroughStyleCell.index].style.rawValue
                                | underlinePatterns[strikethroughPatternCell.index].style.rawValue)!
        vc.updateText(removeSavedScrollStates: false)
      }
      strikethroughStyleCell.didChangeIndex = { _ in updateStrikethroughStyle() }
      strikethroughPatternCell.didChangeIndex = { _ in updateStrikethroughStyle() }

      super.init(style: .plain)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
      self.tableView.alwaysBounceVertical = false
      self.tableView.backgroundColor = .gray
    }

    override func viewDidLayoutSubviews() {
      let contentSize = self.tableView.contentSize
      let preferredSize = self.parent?.preferredContentSize
      if contentSize != preferredSize {
        self.parent?.preferredContentSize = contentSize
      }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return section == 0 ? cells.count : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
               -> UITableViewCell
    {
      return cells[indexPath.row]
    }
  }
}
