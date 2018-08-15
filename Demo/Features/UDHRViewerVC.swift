// Copyright 2018 Stephan Tolksdorf

import STULabelSwift
import STULabel.MainScreenProperties
import STULabel.Unsafe

let fontTextStyles: [(name: String, value: UIFont.TextStyle)] = {
  var styles: [(name: String, value:  UIFont.TextStyle)] = [
    ("Title 1", .title1),
    ("Title 2", .title2),
    ("Title 3", .title3),
    ("Headline", .headline),
    ("Subheadline", .subheadline),
    ("Body", .body),
    ("Callout", .callout),
    ("Footnote", .footnote),
    ("Caption 1", .caption1),
    ("Caption 2", .caption2),
  ]
  if #available(iOS 11, *) {
    styles.insert(("Large title", .largeTitle), at: 0)
  }
  return styles
}()

let contentSizeCategories: [(name: String, value: UIContentSizeCategory)] = [
  ("Extra small", .extraSmall),
  ("Small", .small),
  ("Medium", .medium),
  ("Large", .large),
  ("Extra Large", .extraLarge),
  ("Extra Extra Large", .extraExtraLarge),
  ("XXXL", .extraExtraExtraLarge),
  ("Accessibilty M", .accessibilityMedium),
  ("Accessibilty L", .accessibilityLarge),
  ("Accessibilty XL", .accessibilityExtraLarge),
  ("Accessibilty XXl", .accessibilityExtraExtraLarge),
  ("Accessibilty XXXL", .accessibilityExtraExtraExtraLarge),
]

#if swift(>=4.2)

let underlineStyles: [(name: String, value: NSUnderlineStyle)] = [
  ("Single", .single),
  ("Single thick", [.single, .thick]),
  ("Double", .double),
  ("Double thick", [.double, .thick])
]

#else

let underlineStyles: [(name: String, value: NSUnderlineStyle)] = [
  ("Single", .styleSingle),
  ("Single thick", NSUnderlineStyle(rawValue: NSUnderlineStyle.styleSingle.rawValue
                                            | NSUnderlineStyle.styleThick.rawValue)!),
  ("Double", .styleDouble),
  ("Double thick", NSUnderlineStyle(rawValue: NSUnderlineStyle.styleDouble.rawValue
                                            | NSUnderlineStyle.styleThick.rawValue)!)
]

#endif

let underlinePatterns: [(name: String, value: NSUnderlineStyle)] = [
  ("Solid", NSUnderlineStyle()),
  ("Dot", .patternDot),
  ("Dash dot", .patternDashDot),
  ("Dash dot dot", .patternDashDotDot)
]

private enum RandomTextRanges : Int {
  case everything
  case someWordsA
  case someWordsB
  case manyWordsA
  case manyWordsB
  case someCharactersA
  case someCharactersB
  case manyCharactersA
  case manyCharactersB

  var name: String {
    switch self {
    case .everything: return "Everything"
    case .someWordsA: return "Some words (a)"
    case .someWordsB: return "Some words (b)"
    case .manyWordsA: return "Many words (a)"
    case .manyWordsB: return "Many words (b)"
    case .someCharactersA: return "Some characters (a)"
    case .someCharactersB: return "Some characters (b)"
    case .manyCharactersA: return "Many characters (a)"
    case .manyCharactersB: return "Many characters (b)"
    }
  }

  static var allCases: [RandomTextRanges] = [
    .everything, .someWordsA, .someWordsB, .manyWordsA, .manyWordsB,
    .someCharactersA, .someCharactersB, .manyCharactersA, .manyCharactersB
  ]
}

private let colors: [(name: String, value: UIColor)] = [
  ("Black", .black),
  ("Dark gray", .darkGray),
  ("Gray", .gray),
  ("Light gray", .lightGray),
  ("Red", .red),
  ("Green", .green),
  ("Blue", .blue),
  ("Cyan", .cyan),
  ("Yellow", .yellow),
  ("Magenta", .magenta),
  ("Orange", .orange),
  ("Purple", .purple),
  ("Brown", .brown)
]

private let truncationModes: [(String, STULastLineTruncationMode)] = [
  ("End", .end),
  ("Start", .start),
  ("Middle", .middle)
]

private func addAttributes(_ string: NSMutableAttributedString, _ locale: CFLocale,
                           _ ranges: RandomTextRanges,
                           _ attributes: (NSAttributedString, NSRange) -> Attributes)
{
  func addWordRanges(_ p0: Double, _ p1: Double,
                     _ attributes: (NSAttributedString, NSRange) -> Attributes)
  {
    for r in randomWordRanges(string.string as CFString, locale, p0, p1) {
      string.addAttributes(attributes(string, r), range: r)
    }
  }

  func addCharacterRanges(_ p0: Double, _ p1: Double,
                          _ attributes: (NSAttributedString, NSRange) -> Attributes)
  {
    for r in randomCharacterRanges(string.string, p0, p1) {
      string.addAttributes(attributes(string, r), range: r)
    }
  }

  func switchToB() -> Int32 {
    let state = randState()
    seedRand((~state &+ 123456789) & 0x7fffffff)
    return state
  }

  switch ranges {
  case .everything:
    let r = NSRange(location: 0, length: string.length)
    string.addAttributes(attributes(string, r), range: r)
  case .someWordsA:
    addWordRanges(0.3, 0.1, attributes)
  case .someWordsB:
    let state = switchToB()
    addWordRanges(0.3, 0.1, attributes)
    seedRand(state)
  case .manyWordsA:
    addWordRanges(0.3, 0.9, attributes)
  case .manyWordsB:
    let state = switchToB()
    addWordRanges(0.3, 0.9, attributes)
    seedRand(state)
  case .someCharactersA:
    addCharacterRanges(0.1, 0.1, attributes)
  case .someCharactersB:
    let state = switchToB()
    addCharacterRanges(0.1, 0.1, attributes)
    seedRand(state)
  case .manyCharactersA:
    addCharacterRanges(0.3, 0.75, attributes)
  case .manyCharactersB:
    let state = switchToB()
    addCharacterRanges(0.3, 0.75, attributes)
    seedRand(state)
  }
}

private func addAttributes(_ string: NSMutableAttributedString, _ locale: CFLocale,
                           _ ranges: RandomTextRanges,  _ attributes: Attributes)
{
  addAttributes(string, locale, ranges, { (_, _) in attributes })
}


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
    self.navigationItem.title = "Human Rights"
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
    copyrightFooter.maximumNumberOfLines = 0
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
    largeSTULabel.maximumNumberOfLines = 0
    largeSTULabel.textLayoutMode = textLayoutMode
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
        multiLabelScrollView.dynamicallyAddedSubviews.append(label)
        multiLabelScrollView.dynamicallyAddedSubviews.append(textView)
        stuLabels.append(label)
        textViews.append(textView)
        label.maximumNumberOfLines = 0
        label.defaultTextAlignment = .textStart
        textView.configureForUseAsLabel()
        textView.maximumNumberOfLines = 0
      }
      // label.drawingBlock = { arg in print("Drawing article \(i)"); arg.draw() }

      label.contentInsets = UIEdgeInsets(top: topInset, left: padding,
                                         bottom: bottomInset, right: padding)
      textView.textContainerInset = UIEdgeInsets(top: topInset, left: padding,
                                                 bottom: bottomInset, right: padding)

      label.textLayoutMode = textLayoutMode

      if #available(iOS 11, *) {
        label.dragInteractionEnabled = linkDragInteractionEnabled
        textView.textDragInteraction?.isEnabled = linkDragInteractionEnabled
      }

      label.maximumNumberOfLines = maxLineCount
      textView.textContainer.maximumNumberOfLines = maxLineCount

      label.lastLineTruncationMode = lastLineTruncationMode
      switch lastLineTruncationMode {
      case .start:
        textView.textContainer.lineBreakMode = .byTruncatingHead
      case .middle:
        textView.textContainer.lineBreakMode = .byTruncatingMiddle
      case .end:
        textView.textContainer.lineBreakMode = .byTruncatingTail
      case .clip:
        textView.textContainer.lineBreakMode = .byClipping
      }

      label.accessibilityElementParagraphSeparationCharacterThreshold =
        accessibilitySeparateParagraphs ? 0 : .max
      label.accessibilityElementSeparatesLinkElements = accessibilitySeparateLinks

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

    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .paragraphStyle: paraStyle,
      kCTLanguageAttributeName as NSAttributedString.Key: translation.languageCode,
      NSAttributedString.Key("NSHyphenationLanguage"): translation.languageCode,
      .stuHyphenationLocaleIdentifier: translation.languageCode,
      .accessibilitySpeechLanguage: translation.languageCode,
    ]

    let lineSpacing = max(font.leading, self.lineSpacing)
    let lineHeight = font.ascender - font.descender + lineSpacing
    let bottomInset = max(0, lineHeight/2 - lineSpacing)
    let topInset = lineHeight - bottomInset

    let shadow = self.shadow.copy() as! NSShadow

    func addOptionalAttributes(_ text: NSMutableAttributedString, randSeed seedIndex: Int) {
      let oldRandState = randState()
      let seed = Int32(seedIndex)
      if let underlineRanges = self.underlineRanges {
        seedRand(seed)
        let attributes: Attributes = underlineColor == .black
                                   ? [.underlineStyle: underlineStyle.rawValue]
                                   : [.underlineStyle: underlineStyle.rawValue,
                                      .underlineColor: underlineColor]
        addAttributes(text, locale, underlineRanges, attributes)
      }
      if let strikethroughRanges = self.strikethroughRanges {
        seedRand(seed)
        let attributes: Attributes = strikethroughColor == .black
                                   ? [.strikethroughStyle: strikethroughStyle.rawValue]
                                   : [.strikethroughStyle: strikethroughStyle.rawValue,
                                      .strikethroughColor: strikethroughColor]
        addAttributes(text, locale, strikethroughRanges, attributes)
      }
      if background.color != nil || background.borderWidth > 0 {
        seedRand(seed)
        let attributes: Attributes = background.color == nil
                                   ? [.stuBackground: background]
                                   : [.stuBackground: background,
                                      .backgroundColor: background.color!]
        addAttributes(text, locale, backgroundRanges, attributes)
      }
      if let linkRanges = linkRanges {
        seedRand(seed)
        addAttributes(text, locale, linkRanges) { (text, range) -> Attributes in
          let substring = (text.string as NSString).substring(with: range)
          var onlyDigits: Bool = false
          var onlyLettersOrDigits: Bool = false
          if range.length < 10 {
            onlyDigits = true
            onlyLettersOrDigits = true
            for c in substring.utf16 {
              if 0x30 <= c && c <= 0x39 { continue }
              onlyDigits = false;
              let cc = c | 0x20
              if 0x61 <= cc && cc <= 0x7a { continue }
              onlyLettersOrDigits = false
              break
            }
          }
          var url: URLComponents
          if onlyDigits {
            url = URLComponents(string: "tel:\(substring)" )!
          } else if onlyLettersOrDigits {
            url = URLComponents(string: "mailto:\(substring)@stulabel-test-domain.com")!
          } else {
            url = URLComponents(string: "https://www.google.com/search")!
            let query = "\"\(substring.replacingOccurrences(of: "\n", with: " "))\""
            url.queryItems = [URLQueryItem(name: "q", value: query)]
          }
          return [.link: url.url!]
        }
      }
      if let shadowRanges = shadowRanges {
        seedRand(seed)
        addAttributes(text, locale, shadowRanges, [.shadow: shadow])
      }
      if strokeWidth > 0 {
        seedRand(seed)
        let width = 100*strokeWidth/font.pointSize
        if let fillColor = strokeFillColor {
          addAttributes(text, locale, strokeRanges, [.foregroundColor: fillColor,
                                                     .strokeWidth: -width,
                                                     .strokeColor: strokeColor])
        } else {
          addAttributes(text, locale, strokeRanges, [.strokeWidth: width,
                                                     .strokeColor: strokeColor])
        }
      }
      seedRand(oldRandState)
    }

    let text = NSMutableAttributedString()

    let title = NSMutableAttributedString(translation.title, attributes)
    addOptionalAttributes(title, randSeed: 0)
    if mode.isSingleLabelMode {
      text.append(title)
    } else {
      let (label, textView) = labelViews(topInset: padding, bottomInset: bottomInset)
      label.attributedText = title
      textView.attributedText = title
    }

    let articles = translation.articles

    let hasPreamble = articles[0].paragraphs.count > 2

    let titleAttributes: [NSAttributedString.Key: Any] =
      attributes.merging([.font: font,
                          .foregroundColor: UIColor.darkGray,
                          .paragraphStyle: paraStyle],
                         uniquingKeysWith: { $1 })

    seedRand(1)

    let i0 = !hasPreamble ? articles.startIndex
           : translation.articles.index(after: articles.startIndex)
    for i in i0..<translation.articles.count {
      let article = translation.articles[i]

      let articleText = NSMutableAttributedString()

      articleText.append(NSAttributedString(article.title, titleAttributes))
      for para in article.paragraphs {
        articleText.append(NSAttributedString("\n" + para, attributes))
      }

      addOptionalAttributes(articleText, randSeed: 1 + i)

      if mode.isSingleLabelMode {
        if maxLineCount > 0 && mode.isSingleLabelMode  {
          let mode: CTLineTruncationType
          switch lastLineTruncationMode {
          case .start: mode = .start
          case .middle: mode = .middle
          case .end, .clip: mode = .end
          }
          articleText.addAttribute(.stuTruncationScope,
                                   value: STUTruncationScope(maximumNumberOfLines: Int32(maxLineCount),
                                                             lastLineTruncationMode: mode,
                                                             truncationToken: nil),
                                   range: NSRange(0..<articleText.length))
        }
        text.append(NSAttributedString("\n\n", titleAttributes))
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
        largeSTULabel.accessibilityElementSeparatesLinkElements = accessibilitySeparateLinks
        largeSTULabel.accessibilityElementParagraphSeparationCharacterThreshold = 0
        largeSTULabel.textLayoutMode = textLayoutMode
        largeSTULabel.dragInteractionEnabled = linkDragInteractionEnabled
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

    let safeWidth: CGFloat
    if #available(iOS 11.0, *) {
      safeWidth = scrollView.safeAreaLayoutGuide.layoutFrame.size.width
    } else {
      safeWidth = viewWidth
    }

    let width = floorToScale(min(viewWidth/2 - p, safeWidth/2 + p, readableWidth + 2*p));

    let x = viewWidth/2 - width
    var y: CGFloat = p;

    {
      let isRTL = translation.writingDirection  == .rightToLeft
      let w = width - 2*p
      let size1 = stuLabelColumnHeader.sizeThatFits(CGSize(width: w, height: 1000))
      let x1 = x + p + (isRTL ? w  - size1.width : 0)
      stuLabelColumnHeader.frame = CGRect(origin: CGPoint(x: x1, y: y), size: size1)

      let size2 = textViewColumnHeader.sizeThatFits(CGSize(width: w, height: 1000))
      let x2 = x + width + p + (isRTL ? w - size2.width : 0)
      textViewColumnHeader.frame = CGRect(origin: CGPoint(x: x2, y: y), size: size2)
      y += max(size1.height, size2.height)
    }()

    for i in 0..<stuLabels.count {
      let label = stuLabels[i]
      let height = label.sizeThatFits(CGSize(width: width, height: 100000)).height
      label.frame = CGRect(x: x, y: y, width: width, height: height)
      let textView = textViews[i]
      let height2 = textView.sizeThatFits(CGSize(width: width, height: 100000)).height
      textView.frame = CGRect(x: x + width, y: y, width: width, height: height2)
      y = y + max(height, height2)
    }
    y += p;

    {
      let size = copyrightFooter.sizeThatFits(CGSize(width: safeWidth, height: 1000))
      let x = ceilToScale((viewWidth - size.width)/2)
      copyrightFooter.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
      y += size.height
    }()

    y += 3*p
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

  private var font = UIFont.preferredFont(forTextStyle: .body)

  private var isPreferredFont: Bool = true

  private var preferredFontStyle: UIFont.TextStyle = .body

  private var preferredFontSizeCategory = UIApplication.shared.preferredContentSizeCategory

  private var lineSpacing: CGFloat = 0

  private var textLayoutMode: STUTextLayoutMode = .textKit

  private var hyphenate: Bool = false

  private var hyphenationFactor: Float32 = 1

  private var justify: Bool = false

  private var isHyphenationAvailable: Bool {
    return CFStringIsHyphenationAvailableForLocale(
            NSLocale(localeIdentifier: translation.languageCode) as CFLocale)
  }

  private var linkRanges: RandomTextRanges? = nil
  private var linkDragInteractionEnabled: Bool = STULabel().dragInteractionEnabled

  private var background = STUBackgroundAttribute({ b in b.borderColor = .black })
  private var backgroundRanges: RandomTextRanges = .everything

  private var underlineRanges: RandomTextRanges? = nil
  private var underlineStyle: NSUnderlineStyle = .single
  private var underlineColor = UIColor.black

  private var strikethroughRanges: RandomTextRanges? = nil
  private var strikethroughStyle: NSUnderlineStyle = .single
  private var strikethroughColor = UIColor.black

  private var shadowRanges: RandomTextRanges?
  private var shadow: NSShadow = UDHRViewerVC.defaultShadow

  private static var defaultShadow: NSShadow {
    let s = NSShadow()
    s.shadowColor = UIColor.black.withAlphaComponent(0.33)
    s.shadowOffset = CGSize(width: 2, height: 2)
    s.shadowBlurRadius = 2
    return s
  }

  private var strokeWidth: CGFloat = 0
  private var strokeColor = UIColor.black
  private var strokeFillColor: UIColor? = nil
  private var strokeRanges: RandomTextRanges = .everything

  private var maxLineCount: Int = 0
  private var lastLineTruncationMode: STULastLineTruncationMode = .end

  private var accessibilitySeparateParagraphs: Bool = true
  private var accessibilitySeparateLinks = STULabel().accessibilityElementSeparatesLinkElements

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
    private let viewerVC: UDHRViewerVC

    deinit {
      viewerVC.isSettingsPopoverVisible = false
    }

    private let modeCell: SelectCell<Mode>
    private let languageCell: SelectCell<()>
    private let fontFamilyCell: SelectCell<FontFamily>
    private let fontTextStyleCell: SelectCell<UIFont.TextStyle>
    private let fontSizeCategoryCell: SelectCell<UIContentSizeCategory>
    private let fontStyleCell: SelectCell<FontStyle>
    private let fontSizeCell: StepperCell
    private let lineSpacingCell: StepperCell
    private let textLayoutModeCell: SelectCell<STUTextLayoutMode>

    private let hyphenationTableCell: SubtableCell
    private let hyphenateCell: SwitchCell
    private let hyphenationFactorCell: StepperCell

    private let justifyCell: SwitchCell

    private let linkTableCell: SubtableCell
    private let linkRangesCell: SelectCell<RandomTextRanges?>
    private let linkDraggableCell: SwitchCell

    private let backgroundTableCell: SubtableCell
    private let backgroundColorCell: SelectCell<UIColor?>
    private let backgroundRangesCell: SelectCell<RandomTextRanges>
    private let backgroundFillLineGapsCell: SwitchCell
    private let backgroundExtendToCommonBoundsCell: SwitchCell
    private let backgroundOutsetCell: StepperCell
    private let backgroundCornerRadiusCell: StepperCell
    private let backgroundBorderWidthCell: StepperCell
    private let backgroundBorderColorCell: SelectCell<UIColor>

    private let underlineTableCell: SubtableCell
    private let underlineRangesCell: SelectCell<RandomTextRanges?>
    private let underlineStyleCell: SelectCell<NSUnderlineStyle>
    private let underlinePatternCell: SelectCell<NSUnderlineStyle>
    private let underlineColorCell: SelectCell<UIColor>

    private let strikethroughTableCell: SubtableCell
    private let strikethroughRangesCell: SelectCell<RandomTextRanges?>
    private let strikethroughStyleCell: SelectCell<NSUnderlineStyle>
    private let strikethroughPatternCell: SelectCell<NSUnderlineStyle>
    private let strikethroughColorCell: SelectCell<UIColor>

    private let shadowTableCell: SubtableCell
    private let shadowColorCell: SelectCell<UIColor>
    private let shadowColorAlphaCell: StepperCell
    private let shadowRangesCell: SelectCell<RandomTextRanges?>
    private let shadowOffsetXCell: StepperCell
    private let shadowOffsetYCell: StepperCell
    private let shadowBlurRadiusCell: StepperCell

    private let strokeTableCell: SubtableCell
    private let strokeWidthCell: StepperCell
    private let strokeColorCell: SelectCell<UIColor>
    private let strokeFillColorCell: SelectCell<UIColor?>
    private let strokeRangesCell: SelectCell<RandomTextRanges>

    private let truncationTableCell: SubtableCell
    private let maxLineCountCell: StepperCell
    private let lastLineTruncationModeCell: SelectCell<STULastLineTruncationMode>

    private let accessibilityTableCell: SubtableCell
    private let accessibilitySeparateParagraphsCell: SwitchCell
    private let accessibilitySeparateLinksCell: SwitchCell

    private let preferredFontCells: [UITableViewCell]
    private let nonPreferredFontCells: [UITableViewCell]

    private var cells: [UITableViewCell]

    private func languageDidChange(newIndex: Int) {
      viewerVC.translation = udhr.translations[newIndex]
      if !viewerVC.isHyphenationAvailable {
        viewerVC.hyphenate = false
        hyphenateCell.value = false
        hyphenateCell.isEnabled = false
        hyphenationFactorCell.isEnabled = false
      } else {
        hyphenateCell.isEnabled = true
      }
      viewerVC.updateText(removeSavedScrollStates: true)
    }

    private func setFontFamilyLabelFont(_ label: UILabel,
                                        _ fontFamilyIndex: Int, _ fontFamily: FontFamily) {
      if fontFamilyIndex <= 2 {
        label.font = nil
      } else {
        let size = label.font.pointSize
        let styles = fontFamily.styles
        let index = styles.index(where: {    $0.name == "Regular"
                                          || $0.name == "Medium"
                                          || $0.name == "Roman" })
                    ?? 0
        let name = styles[index].fontName
        label.font = UIFont(name: name, size: size)
      }
    }

    private func fontFamilyDidChange(newIndex: Int, newFamily: FontFamily) {
      setFontFamilyLabelFont(fontFamilyCell.detailTextLabel!, newIndex, newFamily)
      if newIndex == 0 {
        viewerVC.isPreferredFont = true
        cells = preferredFontCells
      } else {
        viewerVC.isPreferredFont = false
        cells = nonPreferredFontCells
        let styles = newFamily.styles
        let oldStyleName = styleName(fontName: viewerVC.font.fontName)
        let styleIndex = styles.index(where: { $0.name == oldStyleName })
                      ?? styles.index(where: {   $0.name == "Regular"
                                              || $0.name == "Medium"
                                              || $0.name == "Roman" })
                      ?? 0
        fontStyleCell.set(values: styles.map { ($0.name, $0) }, index: styleIndex)
      }
      self.tableView.reloadData()
      updateFont()
    }

    private let maxLineSpacing = 200

    private func updateFont() {
      let font: UIFont
      if viewerVC.isPreferredFont {
        let style = fontTextStyleCell.value
        if #available(iOS 10.0, *) {
          let sizeCategory = fontSizeCategoryCell.value
          let tc = UITraitCollection(preferredContentSizeCategory: sizeCategory)
          font = UIFont.preferredFont(forTextStyle: style, compatibleWith: tc)
        } else {
          font = UIFont.preferredFont(forTextStyle: style)
        }
      } else {
        let fontName = fontFamilies[fontFamilyCell.index - 1].styles[fontStyleCell.index].fontName
        let size = CGFloat(fontSizeCell.value)
        font = UIFont(name: fontName, size: size)!
      }
      viewerVC.font = font
      print("Font: \(font.fontName), size: \(font.pointSize), leading: \(font.leading)")
      viewerVC.updateText(removeSavedScrollStates: true)
    }

    init(_ viewerVC: UDHRViewerVC) {
      self.viewerVC = viewerVC

      modeCell = SelectCell("Mode", Mode.allCases.map({ ($0.description, $0) }),
                            index: viewerVC.mode.rawValue)

      languageCell = SelectCell("Language", udhr.translations.map{ ($0.language, ()) },
                                index: udhr.translations.index{ $0 === viewerVC.translation }!)

      let isPreferredFont = viewerVC.isPreferredFont
      let fontName = viewerVC.font.fontName
      let familyName = viewerVC.font.familyName

      fontFamilyCell = SelectCell("Font", [("Preferred UIFont", FontFamily(name: "Preferred UIFont",
                                                                           styles: []))]
                                          + fontFamilies.map { ($0.name, $0) },
                                  index: viewerVC.isPreferredFont ? 0
                                          : 1 + fontFamilies.index(where: {
                                                  $0.name == familyName })!)

      fontTextStyleCell = SelectCell("Font style", fontTextStyles,
                                     index: fontTextStyles.index(where: {
                                              $0.value == viewerVC.preferredFontStyle })!)

      fontSizeCategoryCell = SelectCell("Font size", contentSizeCategories,
                                        index: contentSizeCategories.index(where: {
                                                 $0.value == viewerVC.preferredFontSizeCategory })!)

      let styles = fontFamilies[max(0, fontFamilyCell.index - 1)].styles
      fontStyleCell = SelectCell("Font style", styles.map{ ($0.name, $0) },
                                  index: styles.index(where: {$0.fontName == fontName}) ?? 0)

      fontSizeCell = StepperCell("Font size", 1...200, step: 0.5,
                                  value: Double(viewerVC.font.pointSize), unit: "pt")
      fontSizeCell.isContinuous = false

      lineSpacingCell = StepperCell("Line spacing", 0...200, step: 0.5,
                                        value: Double(viewerVC.lineSpacing), unit: "pt")
      lineSpacingCell.isContinuous = false

      textLayoutModeCell = SelectCell("Layout mode",
                                      [("Default", .default), ("Text Kit", .textKit)],
                                      index: Int(viewerVC.textLayoutMode.rawValue))

      hyphenateCell = SwitchCell("Hyphenate", value: viewerVC.hyphenate)
      hyphenateCell.isEnabled = viewerVC.isHyphenationAvailable

      hyphenationFactorCell = StepperCell("Factor", 0...1, step: 0.01,
                                          value: Double(viewerVC.hyphenationFactor))
      hyphenationFactorCell.isEnabled = hyphenateCell.value

      hyphenationTableCell = SubtableCell("Hyphenation", [hyphenateCell, hyphenationFactorCell])

      justifyCell = SwitchCell("Justify", value: viewerVC.justify)

      let colorNames = colors.map { $0.name }
      let textColorNames = colors.map { $0.name == "Black" ? "Text color (Black/Gray)" : $0.name }
      let randomRangesNames = RandomTextRanges.allCases.map { $0.name }

      func newUnderlineStyleCell(_ section: String, _ value: NSUnderlineStyle )
        -> SelectCell<NSUnderlineStyle>
      {
        let cell = SelectCell("Style", underlineStyles,
                              index: underlineStyles.index {
                                       $0.value.rawValue == (value.rawValue & 0xf)
                                     }!)
        cell.navigationItemTitle = section + " style"
        return cell
      }

      func newUnderlinePatternCell(_ section: String, _ value: NSUnderlineStyle )
        -> SelectCell<NSUnderlineStyle>
      {
        let cell = SelectCell("Pattern", underlinePatterns,
                              index: underlinePatterns.index {
                                       $0.value.rawValue == (value.rawValue & 0x700)
                                     }!)
        cell.navigationItemTitle = section + " pattern"
        return cell
      }

      func newColorCell(_ section: String, _ value: UIColor, title: String = "Color",
                        blackName: String = "Black")
        -> SelectCell<UIColor>
      {
        let cs = blackName == "Black" ? colors
               : [(name: blackName, value: UIColor.black)] + colors[1...]
        let cell = SelectCell(title, cs, index: colors.index { $0.value == value }!)
        cell.labelStyler = { (index: Int, color: UIColor, label: UILabel) in
          label.textColor = color
        }
        cell.navigationItemTitle = section + " " + title.lowercased()
        return cell
      }

      func newOptionalColorCell(_ section: String, _ value: UIColor?, title: String = "Color")
        -> SelectCell<UIColor?>
      {
        let cell = SelectCell(title, [(name: "None", value: nil)]
                                     + colors.map { (name: $0.0, value: $0.1 as UIColor?) },
                              index: value == nil ? 0 : 1 + colors.index { $0.value == value }!)
        cell.labelStyler = { (index: Int, color: UIColor?, label: UILabel) in
          label.textColor = color ?? .black
        }
        cell.navigationItemTitle = section + " " + title.lowercased()
        return cell
      }

      func newTextColorCell(_ section: String, _ value: UIColor) -> SelectCell<UIColor> {
        return newColorCell(section, value, blackName: "Text color (Black/Gray)")
      }

      func newRangesCell(_ section: String, _ value: RandomTextRanges)
        -> SelectCell<RandomTextRanges>
      {
        let cell = SelectCell("Ranges", RandomTextRanges.allCases.map { ($0.name, $0)},
                              index: value.rawValue)
        cell.navigationItemTitle = section + " ranges"
        return cell
      }

      func newOptionalRangesCell(_ section: String, _ value: RandomTextRanges?)
        -> SelectCell<RandomTextRanges?>
      {
        let cell = SelectCell("Ranges", [(name: "None", value: nil)]
                                        + RandomTextRanges.allCases.map {
                                            (name: $0.name, value: $0 as RandomTextRanges?)
                                          },
                              index: value == nil ? 0 : 1 + value!.rawValue)
        cell.navigationItemTitle = section + " ranges"
        return cell
      }

      linkRangesCell = newOptionalRangesCell("Link", viewerVC.linkRanges)
      linkDraggableCell = SwitchCell("Draggable", value: viewerVC.linkDragInteractionEnabled)

      if #available(iOS 11, *) {
        linkTableCell = SubtableCell("Links", [linkRangesCell, linkDraggableCell])
      } else {
        linkTableCell = SubtableCell("Links", [linkRangesCell])
      }

      backgroundColorCell = newOptionalColorCell("Background", viewerVC.background.color)
      backgroundRangesCell = newRangesCell("Background", viewerVC.backgroundRanges)
      backgroundFillLineGapsCell = SwitchCell("Fill line gaps",
                                              value: viewerVC.background.fillTextLineGaps)
      backgroundExtendToCommonBoundsCell =
          SwitchCell("Extend to common bounds",
                     value: viewerVC.background.extendTextLinesToCommonHorizontalBounds)
      backgroundOutsetCell = StepperCell("Outset", -100...100, step: 0.5,
                                         value: -Double(viewerVC.background.edgeInsets.top))
      backgroundCornerRadiusCell = StepperCell("Corner radius", 0...100, step: 0.5,
                                               value: Double(viewerVC.background.cornerRadius))
      backgroundBorderWidthCell = StepperCell("Border width", 0...100, step: 0.5,
                                              value: Double(viewerVC.background.borderWidth))
      backgroundBorderColorCell = newColorCell("Background",
                                               viewerVC.background.borderColor ?? .black,
                                               title: "Border color")

      backgroundTableCell = SubtableCell("Background",
                                         [backgroundColorCell,
                                          backgroundRangesCell,
                                          backgroundFillLineGapsCell,
                                          backgroundExtendToCommonBoundsCell,
                                          backgroundOutsetCell,
                                          backgroundCornerRadiusCell,
                                          backgroundBorderWidthCell,
                                          backgroundBorderColorCell])

      let underlineStyle = viewerVC.underlineStyle
      underlineRangesCell = newOptionalRangesCell("Underline", viewerVC.underlineRanges)
      underlineStyleCell = newUnderlineStyleCell("Underline", viewerVC.underlineStyle)
      underlinePatternCell = newUnderlinePatternCell("Underline", viewerVC.underlineStyle)
      underlineColorCell = newTextColorCell("Underline", viewerVC.underlineColor)

      underlineTableCell = SubtableCell("Underlining",
                                        [underlineRangesCell, underlineStyleCell,
                                         underlinePatternCell, underlineColorCell])

      let strikethroughStyle = viewerVC.strikethroughStyle
      strikethroughRangesCell = newOptionalRangesCell("Strikethrough", viewerVC.strikethroughRanges)
      strikethroughStyleCell = newUnderlineStyleCell("Strikethrough", viewerVC.strikethroughStyle)
      strikethroughPatternCell = newUnderlinePatternCell("Strikethrough", viewerVC.strikethroughStyle)
      strikethroughColorCell = newTextColorCell("Strikethrough", viewerVC.strikethroughColor)
      strikethroughTableCell = SubtableCell("Strikethrough",
                                            [strikethroughRangesCell, strikethroughStyleCell,
                                             strikethroughPatternCell, strikethroughColorCell])

      shadowRangesCell = newOptionalRangesCell("Shadow", viewerVC.shadowRanges )

      let shadowColor = viewerVC.shadow.shadowColor as! UIColor
      var shadowColorAlpha: CGFloat = 0
      shadowColor.getRed(nil, green: nil, blue: nil, alpha: &shadowColorAlpha)

      shadowColorCell = newColorCell("Shadow",
                                     (viewerVC.shadow.shadowColor as! UIColor).withAlphaComponent(1))

      shadowColorAlphaCell = StepperCell("Color alpha", 0...1, step: 0.01,
                                         value: Double(shadowColorAlpha))

      shadowOffsetXCell = StepperCell("X-offset", -1000...1000, step: 0.5,
                                         value: Double(viewerVC.shadow.shadowOffset.width))
      shadowOffsetYCell = StepperCell("Y-offset", -1000...1000, step: 0.5,
                                         value: Double(viewerVC.shadow.shadowOffset.height))
      shadowBlurRadiusCell = StepperCell("blur radius", 0...1000, step: 0.5,
                                         value: Double(viewerVC.shadow.shadowBlurRadius))


      shadowTableCell = SubtableCell("Shadow", [shadowRangesCell, shadowColorCell,
                                                shadowColorAlphaCell,
                                                shadowOffsetXCell, shadowOffsetYCell,
                                                shadowBlurRadiusCell])

      strokeWidthCell = StepperCell("Width", 0...1000, step: 0.5,
                                    value: Double(viewerVC.strokeWidth), unit: "pt")
      strokeColorCell = newColorCell("Stroke", viewerVC.strokeColor)
      strokeFillColorCell = newOptionalColorCell("Text", viewerVC.strokeFillColor,
                                                 title: "Fill color")
      strokeRangesCell = newRangesCell("Stroke", viewerVC.strokeRanges)
      strokeTableCell = SubtableCell("Stroke", [strokeWidthCell, strokeColorCell,
                                                strokeFillColorCell, strokeRangesCell])

      maxLineCountCell = StepperCell("Max number of lines", 0...1000, step: 1,
                                     value: Double(viewerVC.maxLineCount))

      lastLineTruncationModeCell = SelectCell("Last line truncation", truncationModes,
                                              value: viewerVC.lastLineTruncationMode)

      truncationTableCell  = SubtableCell("Truncation", [maxLineCountCell,
                                                         lastLineTruncationModeCell])
      truncationTableCell.footerLabel.text = "Note that a STULabel view will always use 'end' truncation if it has to remove text from more than a single paragraph."

      accessibilitySeparateParagraphsCell = SwitchCell("Separate paragraphs",
                                                       value: viewerVC.accessibilitySeparateParagraphs)

      accessibilitySeparateLinksCell = SwitchCell("Separate links",
                                                  value: viewerVC.accessibilitySeparateLinks)

      accessibilityTableCell = SubtableCell("STULabel accessibility",
                                            [accessibilitySeparateParagraphsCell,
                                             accessibilitySeparateLinksCell])

      var preferredFontCells: [UITableViewCell] = [modeCell, languageCell, fontFamilyCell]
      var normalFontCells = preferredFontCells

      preferredFontCells.append(contentsOf: [fontTextStyleCell])
      if #available(iOS 10, *) {
        preferredFontCells.append(fontSizeCategoryCell)
      }
      normalFontCells.append(contentsOf: [fontStyleCell, fontSizeCell])

      let otherCells = [lineSpacingCell, textLayoutModeCell, hyphenationTableCell,
                        justifyCell, linkTableCell, backgroundTableCell, underlineTableCell,
                        strikethroughTableCell, shadowTableCell, strokeTableCell,
                        truncationTableCell, accessibilityTableCell]

      preferredFontCells.append(contentsOf: otherCells)
      normalFontCells.append(contentsOf: otherCells)

      self.preferredFontCells = preferredFontCells
      self.nonPreferredFontCells = normalFontCells

      cells = isPreferredFont ? preferredFontCells : normalFontCells

      super.init(style: .plain)

      let updateCellsForMode = { (mode: Mode) in
        let isNotIOS9 = NSFoundationVersionNumber > Double(NSFoundationVersionNumber_iOS_9_x_Max)
        switch mode {
        case .stuLabel_vs_UITextView:
          self.accessibilitySeparateParagraphsCell.isEnabled = true
          self.accessibilitySeparateLinksCell.isEnabled = isNotIOS9
        case .stuLabel, .zoomableSTULabel:
          self.accessibilitySeparateParagraphsCell.isEnabled = false
          self.accessibilitySeparateLinksCell.isEnabled = isNotIOS9
        case .uiTextView:
          self.accessibilitySeparateParagraphsCell.isEnabled = false
          self.accessibilitySeparateLinksCell.isEnabled = false
        }
      }
      updateCellsForMode(viewerVC.mode)

      modeCell.didChangeIndex = { (_, newValue) in
        viewerVC.mode = newValue
        updateCellsForMode(newValue)
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      languageCell.didChangeIndex =  { [unowned self] (newIndex, _) in
        self.languageDidChange(newIndex: newIndex)
      }

      setFontFamilyLabelFont(fontFamilyCell.detailTextLabel!,
                             fontFamilyCell.index, fontFamilyCell.value)
      fontFamilyCell.labelStyler = { [unowned self] (index, family, label) in
        self.setFontFamilyLabelFont(label, index, family)
      }

      fontFamilyCell.didChangeIndex = { [unowned self] (newIndex, newFamily) in
        self.fontFamilyDidChange(newIndex: newIndex, newFamily: newFamily)
      }

      fontTextStyleCell.didChangeIndex = { [unowned self] (newIndex, value) in
        viewerVC.preferredFontStyle = value
        self.updateFont()
      }

      let updateFontSizeCategoryLabel = { [unowned self] in
        let category = self.fontSizeCategoryCell.values[self.fontSizeCategoryCell.index].name
        self.fontSizeCategoryCell.detailText = "\(category), \(viewerVC.font.pointSize)pt"
      }
      updateFontSizeCategoryLabel()
      fontSizeCategoryCell.didChangeIndex = { [unowned self] (_,  value) in
        viewerVC.preferredFontSizeCategory = value
        self.updateFont()
        updateFontSizeCategoryLabel()
      }
      fontStyleCell.didChangeIndex = { [unowned self] (_, _) in self.updateFont() }
      fontSizeCell.didChangeValue = { [unowned self] (_) in self.updateFont() }

      lineSpacingCell.didChangeValue = { newValue in
        viewerVC.lineSpacing = CGFloat(newValue)
        viewerVC.updateText(removeSavedScrollStates: true)
      }

      textLayoutModeCell.didChangeIndex = { (_, newValue) in
        viewerVC.textLayoutMode = newValue
        viewerVC.updateText(removeSavedScrollStates: true)
      }

      let updateHyphenationLabel = { [unowned self] in
        self.hyphenationTableCell.detailText = !self.hyphenateCell.value ? "Disabled"
                                             : self.hyphenationFactorCell.detailText
      }
      updateHyphenationLabel()

      hyphenateCell.didChangeValue = { [unowned hyphenationFactorCell] newValue in
        updateHyphenationLabel()
        viewerVC.hyphenate = newValue
        hyphenationFactorCell.isEnabled = newValue
        viewerVC.updateText(removeSavedScrollStates: true)
      }
      hyphenationFactorCell.didChangeValue = { newValue in
        updateHyphenationLabel()
        viewerVC.hyphenationFactor = Float32(newValue)
        viewerVC.updateText(removeSavedScrollStates: true)
      }

      justifyCell.didChangeValue = { newValue in
        viewerVC.justify = newValue
        viewerVC.updateText(removeSavedScrollStates: true)
      }

      let linkColor = viewerVC.view.tintColor

      let updateLinkTableCellDetailLabel = { [unowned self] in
        self.linkTableCell.detailText = viewerVC.linkRanges?.name ?? "None"
        self.linkTableCell.detailTextColor = viewerVC.linkRanges == nil ? nil : linkColor
      }

      updateLinkTableCellDetailLabel()

      linkRangesCell.didChangeIndex = { (_, newValue) in
        viewerVC.linkRanges = newValue
        updateLinkTableCellDetailLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      linkDraggableCell.didChangeValue = { newValue in
        viewerVC.linkDragInteractionEnabled = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }


      let updateBackgroundTableCellDetailLabel = { [unowned self] in
        let color = viewerVC.background.color
        let borderWidth = viewerVC.background.borderWidth
        let text: String
        if color == nil && borderWidth == 0 {
          text = "None"
        } else {
          text = (color == nil ? "Clear" : self.backgroundColorCell.detailText)
               + (borderWidth == 0 ? "" : " with border")
        }
        self.backgroundTableCell.detailText = text
        self.backgroundTableCell.detailTextColor = color
      }

      updateBackgroundTableCellDetailLabel()

      backgroundColorCell.didChangeIndex = { [unowned self] (_, newValue) in
        self.backgroundColorCell.detailTextColor = newValue ?? .black
        viewerVC.background = viewerVC.background.copy { b in
          b.color = newValue
        }
        updateBackgroundTableCellDetailLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      backgroundRangesCell.didChangeIndex = { (_, newValue) in
        viewerVC.backgroundRanges = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      backgroundFillLineGapsCell.didChangeValue = { newValue in
        viewerVC.background = viewerVC.background.copy { b in
          b.fillTextLineGaps = newValue
        }
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      backgroundExtendToCommonBoundsCell.didChangeValue = { newValue in
        viewerVC.background = viewerVC.background.copy { b in
          b.extendTextLinesToCommonHorizontalBounds = newValue
        }
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      backgroundCornerRadiusCell.didChangeValue = { newValue in
        viewerVC.background = viewerVC.background.copy { b in
          b.cornerRadius = CGFloat(newValue)
        }
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      backgroundOutsetCell.didChangeValue = { newValue in
        viewerVC.background = viewerVC.background.copy { b in
          let v = -CGFloat(newValue)
          b.edgeInsets = UIEdgeInsets(top: v, left: v, bottom: v, right: v)
        }
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      backgroundBorderWidthCell.didChangeValue = { newValue in
        viewerVC.background = viewerVC.background.copy { b in
          b.borderWidth = CGFloat(newValue)
        }
        updateBackgroundTableCellDetailLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      backgroundBorderColorCell.didChangeIndex = { [unowned backgroundBorderColorCell] (_, newValue) in
        backgroundBorderColorCell.detailTextColor = newValue
        viewerVC.background = viewerVC.background.copy { b in
          b.borderColor = newValue
        }
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      func underlineLabel(style: String, pattern: String) -> String {
        if style == "None" {
          return "None"
        }
        if pattern == "Solid" {
          return style
        }
        return style + ", " + pattern
      }

      let updateUnderlineStyle = { [unowned underlineStyleCell, unowned underlinePatternCell] in
      #if swift(>=4.2)
        viewerVC.underlineStyle = underlineStyleCell.value
                                  .union(underlinePatternCell.value)
      #else
        viewerVC.underlineStyle =
          NSUnderlineStyle(rawValue: underlineStyleCell.value.rawValue
                                   | underlinePatternCell.value.rawValue)!
      #endif
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateStrikethroughStyle = { [unowned strikethroughStyleCell,
                                        unowned strikethroughPatternCell] in
      #if swift(>=4.2)
        viewerVC.strikethroughStyle = strikethroughStyleCell.value
                                      .union(strikethroughPatternCell.value)
      #else
        viewerVC.strikethroughStyle =
          NSUnderlineStyle(rawValue: strikethroughStyleCell.value.rawValue
                                   | strikethroughPatternCell.value.rawValue)!
      #endif
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateUnderlineTableCellLabel = { [unowned self] in
        let hasUnderline = viewerVC.underlineRanges != nil
        let style = underlineStyles[self.underlineStyleCell.index].name
        let pattern = underlinePatterns[self.underlinePatternCell.index].name
        self.underlineTableCell.detailText = !hasUnderline ? "None"
                                           : underlineLabel(style: style, pattern: pattern)
        self.underlineTableCell.detailTextColor = !hasUnderline ? nil
                                                : viewerVC.underlineColor
      }

      let updateStrikethroughTableCellLabel = { [unowned self] in
        let hasStrikethrough = viewerVC.strikethroughRanges != nil
        let style = underlineStyles[self.strikethroughStyleCell.index].name
        let pattern = underlinePatterns[self.strikethroughPatternCell.index].name
        self.strikethroughTableCell.detailText = !hasStrikethrough ? "None"
                                               : underlineLabel(style: style, pattern: pattern)
        self.strikethroughTableCell.detailTextColor = !hasStrikethrough ? nil
                                                    : viewerVC.strikethroughColor
      }

      updateUnderlineTableCellLabel()
      updateStrikethroughTableCellLabel()

      underlineStyleCell.didChangeIndex = { (_, _) in
        updateUnderlineTableCellLabel()
        updateUnderlineStyle()
      }
      underlinePatternCell.didChangeIndex = { (_, _) in
        updateUnderlineTableCellLabel()
        updateUnderlineStyle()
      }
      underlineColorCell.didChangeIndex = { [unowned underlineColorCell] (_, newValue) in
        underlineColorCell.detailTextColor = newValue
        viewerVC.underlineColor = newValue
        updateUnderlineTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      underlineRangesCell.didChangeIndex = { (_, newValue) in
        viewerVC.underlineRanges = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      strikethroughStyleCell.didChangeIndex = { (_, _) in
        updateStrikethroughTableCellLabel()
        updateStrikethroughStyle()
      }
      strikethroughPatternCell.didChangeIndex = { (_, _) in
        updateStrikethroughTableCellLabel()
        updateStrikethroughStyle()
      }
      strikethroughColorCell.didChangeIndex = { [unowned strikethroughColorCell] (_, newValue) in
        strikethroughColorCell.detailTextColor = newValue
        viewerVC.strikethroughColor = newValue
        updateStrikethroughTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      strikethroughRangesCell.didChangeIndex = { (_, newValue) in
        viewerVC.strikethroughRanges = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateShadowTableCellLabel = { [unowned self] in
        self.shadowTableCell.detailText = viewerVC.shadowRanges?.name ?? "None"
        self.shadowTableCell.detailTextColor = viewerVC.shadowRanges == nil ? nil
                                             : self.shadowColorCell.value
      }
      updateShadowTableCellLabel()

      shadowRangesCell.didChangeIndex = { [unowned self] (_, newValue) in
        self.shadowTableCell.detailText  = newValue?.name ?? "None"
        viewerVC.shadowRanges = newValue
        updateShadowTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateShadowColor = { [unowned self] in
        let color = self.shadowColorCell.value
        let alpha = self.shadowColorAlphaCell.value
        self.shadowColorCell.detailTextColor = color
        viewerVC.shadow.shadowColor = color.withAlphaComponent(CGFloat(alpha))
      }

      shadowColorCell.didChangeIndex = { (_, _) in
        updateShadowColor()
        updateShadowTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      shadowColorAlphaCell.didChangeValue = { _ in
        updateShadowColor()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      shadowOffsetXCell.didChangeValue = { newValue in
        viewerVC.shadow.shadowOffset.width = CGFloat(newValue)
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      shadowOffsetYCell.didChangeValue = { newValue in
        viewerVC.shadow.shadowOffset.height = CGFloat(newValue)
        viewerVC.updateText(removeSavedScrollStates: false)
      }
      shadowBlurRadiusCell.didChangeValue = { newValue in
        viewerVC.shadow.shadowBlurRadius = CGFloat(newValue)
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateStrokeTableCellLabel = { [unowned self] in
        let hasStroke = viewerVC.strokeWidth > 0
        self.strokeTableCell.detailText =
            !hasStroke ? "None"
          : "\(self.strokeWidthCell.detailText.lowercased()), \(self.strokeColorCell.detailText.lowercased())"
            + (viewerVC.strokeFillColor == nil ? "" : " " + self.strokeFillColorCell.detailText.lowercased())
        self.strokeTableCell.detailTextColor = !hasStroke ? nil
                                             : viewerVC.strokeFillColor ?? viewerVC.strokeColor
      }
      updateStrokeTableCellLabel()

      strokeWidthCell.didChangeValue = { newValue in
        viewerVC.strokeWidth = CGFloat(newValue)
        updateStrokeTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      strokeRangesCell.didChangeIndex = { (_, newValue) in
        viewerVC.strokeRanges = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      strokeColorCell.didChangeIndex = { (_, newValue) in
        viewerVC.strokeColor = newValue
        updateStrokeTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      strokeFillColorCell.didChangeIndex = { (_, newValue) in
        viewerVC.strokeFillColor = newValue
        updateStrokeTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      let updateTruncationTableCellLabel = { [unowned self] in
        let mode = self.lastLineTruncationModeCell.detailText.lowercased()
        self.truncationTableCell.detailText = viewerVC.maxLineCount == 0 ? "None"
                                            : "\(viewerVC.maxLineCount) lines, \(mode)"
      }
      updateTruncationTableCellLabel()

      maxLineCountCell.didChangeValue = { newValue in
        viewerVC.maxLineCount = Int(newValue)
        updateTruncationTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      lastLineTruncationModeCell.didChangeIndex = { (_,  newValue) in
        viewerVC.lastLineTruncationMode = newValue
        updateTruncationTableCellLabel()
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      accessibilitySeparateParagraphsCell.didChangeValue = { (newValue) in
        viewerVC.accessibilitySeparateParagraphs = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }

      accessibilitySeparateLinksCell.didChangeValue = { (newValue) in
        viewerVC.accessibilitySeparateLinks = newValue
        viewerVC.updateText(removeSavedScrollStates: false)
      }
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
      self.tableView.alwaysBounceVertical = false
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
