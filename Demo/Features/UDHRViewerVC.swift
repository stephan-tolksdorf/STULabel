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

private extension UIFont {
  static func preferredFont(_ textStyle: UIFont.TextStyle,
                            _ sizeCategory: UIContentSizeCategory) -> UIFont
  {
    if #available(iOS 10.0, *) {
      return UIFont.preferredFont(forTextStyle: textStyle,
                                  compatibleWith: UITraitCollection(preferredContentSizeCategory:
                                                                      sizeCategory))
    } else {
      return UIFont.preferredFont(forTextStyle: textStyle)
    }
  }
}

let underlineStyles: [(name: String, value: NSUnderlineStyle)] = [
  ("Single", .single),
  ("Single thick", [.single, .thick]),
  ("Double", .double),
  ("Double thick", [.double, .thick])
]

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

extension RandomTextRanges : UserDefaultsStorable {}

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


private func setting<Value: UserDefaultsStorable>(_ id: String, _ defaultValue: Value)
          -> Setting<Value>
{
  return Setting(id: "UDHRViewer." + id, default: defaultValue)
}

private extension NSShadow {
  var shadowUIColor: UIColor? {
    get { return shadowColor as? UIColor }
    set { shadowColor = newValue }
  }
}

class UDHRViewerVC : UIViewController, STULabelDelegate, UIScrollViewDelegate,
                     UIPopoverPresentationControllerDelegate
{
  private enum Mode : Int, UserDefaultsStorable {
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

  enum FontKind {
    case preferred
    case system
    case normal
  }

  private let modeSetting = setting("mode", Mode.stuLabel_vs_UITextView)

  private var translation: UDHR.Translation { return translationSetting.value }
  private let translationSetting = setting("translation", udhr.translationsByLanguageCode["en"]!)

  private let font = setting("font", UIFont.preferredFont(forTextStyle: .body))

  private var fontKind: FontKind

  private let preferredFontStyle = setting("preferredFontStyle", UIFont.TextStyle.body)

  private let preferredFontSizeCategory = setting("preferredFontSizeCategory",
                                                  UIApplication.shared.preferredContentSizeCategory)

  private let lineSpacing = setting("lineSpacing", 0 as CGFloat)

  private let textLayoutMode = setting("textLayoutMode", STUTextLayoutMode.textKit)

  private let hyphenate = setting("hyphenate", false)

  private let hyphenationFactor = setting("hyphenationFactor", 1 as Float32)

  private let justify = setting("justify", false)

  private var isHyphenationAvailable: Bool {
    return CFStringIsHyphenationAvailableForLocale(
            NSLocale(localeIdentifier: translation.languageCode) as CFLocale)
  }

  private let linkRanges = setting("link.ranges", nil as RandomTextRanges?)
  private let linkDragInteractionEnabled = setting("link.dragInteractionEnabled",
                                                   STULabel().dragInteractionEnabled)
  private let linkContextMenuInteractionEnabled = setting("link.contextMenuInteractionEnabled",
                                                   STULabel().contextMenuInteractionEnabled)

  private let backgroundRanges = setting("background.ranges", RandomTextRanges.everything)
  private var background: STUBackgroundAttribute
  private let backgroundColor                = setting("background.color", nil as UIColor?)
  private let backgroundFillLineGaps         = setting("background.fillLineGaps", true)
  private let backgroundExtendToCommonBounds = setting("background.extendToCommonBounds", true)
  private let backgroundOutset               = setting("background.outset", 0 as CGFloat)
  private let backgroundCornerRadius         = setting("background.cornerRadus", 0 as CGFloat)
  private let backgroundBorderWidth          = setting("background.borderWidth", 0 as CGFloat)
  private let backgroundBorderColor          = setting("background.borderColor", UIColor.black)

  private let underlineRanges       = setting("underline.ranges", nil as RandomTextRanges?)
  private var underlineStyle: NSUnderlineStyle
  private let underlineStyleStyle   = setting("underline.style.style", NSUnderlineStyle.single)
  private let underlineStylePattern = setting("underline.style.pattern", NSUnderlineStyle())
  private let underlineColor        = setting("underline.color", UIColor.black)

  private let strikethroughRanges       = setting("strikethrough.ranges", nil as RandomTextRanges?)
  private var strikethroughStyle: NSUnderlineStyle
  private let strikethroughStyleStyle   = setting("strikethrough.style.style",
                                                  NSUnderlineStyle.single)
  private let strikethroughStylePattern = setting("strikethrough.style.pattern", NSUnderlineStyle())
  private let strikethroughColor        = setting("strikethrough.color", UIColor.black)

  private let shadowRanges     = setting("shadow.ranges", nil as RandomTextRanges?)
  private var shadow: NSShadow
  private let shadowColor      = setting("shadow.color", UIColor.black)
  private let shadowColorAlpha = setting("shadow.colorAlpha", 1/3.0 as CGFloat)
  private let shadowOffsetX    = setting("shadow.offsetX", 2 as CGFloat)
  private let shadowOffsetY    = setting("shadow.offsetY", 2 as CGFloat)
  private let shadowBlurRadius = setting("shadow.blurRadius", 2 as CGFloat)

  private let strokeRanges    = setting("stroke.ranges", RandomTextRanges.everything)
  private let strokeWidth     = setting("stroke.width", 0 as CGFloat)
  private let strokeColor     = setting("stroke.color", UIColor.black)
  private let strokeFillColor = setting("stroke.fillColor", nil as UIColor?)

  private let maxLineCount           = setting("maxLineCount", 0)
  private let lastLineTruncationMode = setting("lastLineTruncationMode",
                                               STULastLineTruncationMode.end)

  private let accessibilitySeparateParagraphs = setting("accessibilitySeparateParagraphs", true)
  private let accessibilitySeparateLinks = setting("accessibilitySeparateLinks",
                                                   STULabel().accessibilityElementSeparatesLinkElements)
  private let highlightGraphemeCluster = setting("highlightGraphemeCluster", false)

  private var mode: Mode {
    willSet {
      if mode == .zoomableSTULabel {
        largeSTULabel.contentScaleFactor = stu_mainScreenScale()
        largeSTULabelScrollView.setZoomScale(1, animated: false)
      }
      self.saveScrollState()
      switch (mode) {
      case .stuLabel_vs_UITextView:
        for label in self.stuLabels { label.attributedText = nil }
        for label in self.textViews { label.attributedText = nil }
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

  private var multiLabelScrollView = MultiLabelScrollView()
  private let stuLabelColumnHeader = STULabel()
  private let textViewColumnHeader = STULabel()
  private var stuLabels = [STULabel]()
  private var textViews = [UITextView]()

  private let largeSTULabel = STULabel()
  private var largeSTULabelScrollViewContentView = UIView()
  private var largeSTULabelScrollView = UIScrollView()

  private var largeTextView = UITextView()

  private let copyrightFooter = STULabel()



  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    mode = modeSetting.value

    if font.value == UIFont.preferredFont(preferredFontStyle.value,
                                          preferredFontSizeCategory.value)
    {
      self.fontKind = .preferred
    } else if font.value.fontName.hasPrefix(".") {
      self.fontKind = .system
    } else {
      let familyName = font.value.familyName
      if fontFamilies.contains(where: { $0.name == familyName }) {
        self.fontKind = .normal
      } else {
        self.font.setValueWithoutNotifyingObservers(self.font.defaultValue)
        self.fontKind = .preferred
      }
    }

    let bgColor = backgroundColor.value
    let bgFillLineGaps = backgroundFillLineGaps.value
    let bgExtendToCommonBounds = backgroundExtendToCommonBounds.value
    let bgOutset = backgroundOutset.value
    let bgCornerRadius = backgroundCornerRadius.value
    let bgBorderWidth = backgroundBorderWidth.value
    let bgBorderColor = backgroundBorderColor.value

    background = STUBackgroundAttribute { b in
                   b.color = bgColor
                   b.fillTextLineGaps = bgFillLineGaps
                   b.extendTextLinesToCommonHorizontalBounds = bgExtendToCommonBounds
                   b.edgeInsets = UIEdgeInsets(uniformInset: -bgOutset)
                   b.cornerRadius = bgCornerRadius
                   b.borderColor = bgBorderColor
                   b.borderWidth = bgBorderWidth
                 }
    shadow = NSShadow()
    shadow.shadowColor = shadowColor.value.withAlphaComponent(shadowColorAlpha.value)
    shadow.shadowOffset = CGSize(width: shadowOffsetX.value, height: shadowOffsetY.value)
    shadow.shadowBlurRadius = shadowBlurRadius.value

    underlineStyle = underlineStyleStyle.value.union(underlineStylePattern.value)
    strikethroughStyle = strikethroughStyleStyle.value.union(strikethroughStylePattern.value)

    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

    let setNeedsTextUpdate = { [unowned self] in
      self.setNeedsTextUpdate(removeSavedScrollStates: false)
    }

    let setNeedsTextUpdateAndLayout = { [unowned self] in
      self.setNeedsTextUpdate(removeSavedScrollStates: true)
    }

    modeSetting.onChange = { [unowned self] in
      self.mode = self.modeSetting.value
      setNeedsTextUpdate()
    }

    translationSetting.onChange = setNeedsTextUpdateAndLayout

    font.onChange = setNeedsTextUpdateAndLayout

    lineSpacing.onChange = setNeedsTextUpdateAndLayout
    textLayoutMode.onChange = setNeedsTextUpdateAndLayout

    hyphenate.onChange = setNeedsTextUpdateAndLayout
    hyphenationFactor.onChange = setNeedsTextUpdateAndLayout
    justify.onChange = setNeedsTextUpdateAndLayout

    linkRanges.onChange = setNeedsTextUpdate
    linkDragInteractionEnabled.onChange = setNeedsTextUpdate
    linkContextMenuInteractionEnabled.onChange = setNeedsTextUpdate

    backgroundRanges.onChange = setNeedsTextUpdate

    backgroundColor.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy { $0.color = self.backgroundColor.value }
    }
    backgroundFillLineGaps.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy {
        $0.fillTextLineGaps = self.backgroundFillLineGaps.value
      }
    }
    backgroundExtendToCommonBounds.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy {
        $0.extendTextLinesToCommonHorizontalBounds = self.backgroundExtendToCommonBounds.value
      }
    }
    backgroundOutset.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy { b in
        let v = -self.backgroundOutset.value
        b.edgeInsets = UIEdgeInsets(top: v, left: v, bottom: v, right: v)
      }
    }
    backgroundCornerRadius.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy { $0.cornerRadius = self.backgroundCornerRadius.value }
    }
    backgroundBorderWidth.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy { $0.borderWidth = self.backgroundBorderWidth.value }
    }
    backgroundBorderColor.onChange = { [unowned self] in
      setNeedsTextUpdate()
      self.background = self.background.copy { $0.borderColor = self.backgroundBorderColor.value }
    }

    let updateUnderlineStyle = { [unowned self] in
      setNeedsTextUpdate()
      self.underlineStyle = self.underlineStyleStyle.value
                            .union(self.underlineStylePattern.value)
    }

    let updateStrikethroughStyle = { [unowned self] in
      setNeedsTextUpdate()
      self.strikethroughStyle = self.strikethroughStyleStyle.value
                                .union(self.strikethroughStylePattern.value)
    }

    underlineRanges.onChange = setNeedsTextUpdate
    underlineStyleStyle.onChange = updateUnderlineStyle
    underlineStylePattern.onChange = updateUnderlineStyle
    underlineColor.onChange = setNeedsTextUpdate

    strikethroughRanges.onChange = setNeedsTextUpdate
    strikethroughStyleStyle.onChange = updateStrikethroughStyle
    strikethroughStylePattern.onChange = updateStrikethroughStyle
    strikethroughColor.onChange = setNeedsTextUpdate

    let setNeedsTextUpdateAndCopyShadow = { [unowned self] in
      setNeedsTextUpdate()
      self.shadow = self.shadow.copy() as! NSShadow
    }
    let updateShadowColor = { [unowned self] in
      setNeedsTextUpdateAndCopyShadow()
      self.shadow.shadowColor = self.shadowColor.value.withAlphaComponent(self.shadowColorAlpha.value)
    }
    let updateShadowOffset = { [unowned self] in
      setNeedsTextUpdateAndCopyShadow()
      self.shadow.shadowOffset = CGSize(width: self.shadowOffsetX.value,
                                        height: self.shadowOffsetY.value)
    }

    shadowRanges.onChange = setNeedsTextUpdate
    shadowColor.onChange = updateShadowColor
    shadowColorAlpha.onChange = updateShadowColor
    shadowOffsetX.onChange = updateShadowOffset
    shadowOffsetY.onChange = updateShadowOffset
    shadowBlurRadius.onChange = { [unowned self] in
      setNeedsTextUpdateAndCopyShadow()
      self.shadow.shadowBlurRadius = self.shadowBlurRadius.value
    }

    strokeWidth.onChange = setNeedsTextUpdate
    strokeColor.onChange = setNeedsTextUpdate
    strokeFillColor.onChange = setNeedsTextUpdate
    strokeRanges.onChange = setNeedsTextUpdate

    maxLineCount.onChange = setNeedsTextUpdateAndLayout
    lastLineTruncationMode.onChange = setNeedsTextUpdateAndLayout

    accessibilitySeparateParagraphs.onChange = setNeedsTextUpdate
    accessibilitySeparateLinks.onChange = setNeedsTextUpdate

    highlightGraphemeCluster.onChange = { [unowned self] in
      if self.highlightGraphemeCluster.value == false {
        self.largeSTULabel.isHighlighted = false
      }
    }

    self.navigationItem.title = "Human Rights"
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(image:  UIImage(named: "toggle-icon"),
                                                             style: .plain, target: self,
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
    largeSTULabel.textLayoutMode = textLayoutMode.value
    largeSTULabel.contentInsets = UIEdgeInsets(top: padding, left: padding,
                                               bottom: padding, right: padding)

    largeSTULabel.addGestureRecognizer(UITapGestureRecognizer(
                                        target: self,
                                        action: #selector(largeLabelWasTapped(_:))))
    largeSTULabel.highlightStyle = STUTextHighlightStyle { b in
                                      b.background = STUBackgroundAttribute { b in
                                                       b.color = UIColor.orange
                                                                 .withAlphaComponent(0.4)
                                                     }
                                   }

    if usesAutoLayoutForLargeSTULabel {
      let container = largeSTULabelScrollViewContentView
      container.translatesAutoresizingMaskIntoConstraints = false
      largeSTULabel.translatesAutoresizingMaskIntoConstraints = false

      var cs = [NSLayoutConstraint]()

      constrain(&cs, container, toEdgesOf: largeSTULabelScrollView)
      constrain(&cs, container, .width, eq, largeSTULabelScrollView, .width)

      constrain(&cs, largeSTULabel, .centerX, eq, container, .centerX)
      constrain(&cs, largeSTULabel, .top,     eq, container, .top,    plus:  padding)
      constrain(&cs, largeSTULabel, .bottom,  eq, container, .bottom, plus: -padding)

      constrain(&cs, largeSTULabel, .width, leq, container.readableContentGuide, .width,
                plus: 2*padding)
      constrain(&cs, largeSTULabel, .width, leq, container, .width, plus: -2*padding,
                priority: .required)

      cs.activate()
    }
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

  private var _needsTextUpdate: Bool = true

  private func setNeedsTextUpdate(removeSavedScrollStates: Bool) {
    if removeSavedScrollStates {
      self.removeSavedScrollStates()
    }
    if !_needsTextUpdate {
      _needsTextUpdate = true
      self.view.setNeedsLayout()
    }
  }

  func updateText(removeSavedScrollStates: Bool) {
    if removeSavedScrollStates {
      self.removeSavedScrollStates()
    }
    _needsTextUpdate = false

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
        label.delegate = self
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

      label.textLayoutMode = textLayoutMode.value

      if #available(iOS 13, *) {
        label.contextMenuInteractionEnabled = linkContextMenuInteractionEnabled.value
      }
        
      if #available(iOS 11, *) {
        label.dragInteractionEnabled = linkDragInteractionEnabled.value
        textView.textDragInteraction?.isEnabled = linkDragInteractionEnabled.value
      }

      label.maximumNumberOfLines = maxLineCount.value
      textView.textContainer.maximumNumberOfLines = maxLineCount.value

      label.lastLineTruncationMode = lastLineTruncationMode.value
      switch lastLineTruncationMode.value {
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
              accessibilitySeparateParagraphs.value ? 0 : .max
      label.accessibilityElementSeparatesLinkElements = accessibilitySeparateLinks.value

      return (label, textView)
    }

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.baseWritingDirection = translation.writingDirection == .leftToRight
                                   ? .leftToRight : .rightToLeft
    paraStyle.lineSpacing = self.lineSpacing.value
    paraStyle.hyphenationFactor = hyphenate.value ? hyphenationFactor.value : 0
    if justify.value {
      paraStyle.alignment = .justified
    }

    let locale = NSLocale(localeIdentifier: translation.languageCode) as CFLocale

    let font = self.font.value

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .paragraphStyle: paraStyle,
      kCTLanguageAttributeName as NSAttributedString.Key: translation.languageCode,
      NSAttributedString.Key("NSHyphenationLanguage"): translation.languageCode,
      .stuHyphenationLocaleIdentifier: translation.languageCode,
      .accessibilitySpeechLanguage: translation.languageCode,
    ]

    let lineSpacing = max(font.leading, self.lineSpacing.value)
    let lineHeight = font.ascender - font.descender + lineSpacing
    let bottomInset = max(0, lineHeight/2 - lineSpacing)
    let topInset = lineHeight - bottomInset

    func addOptionalAttributes(_ text: NSMutableAttributedString, randSeed seedIndex: Int) {
      let oldRandState = randState()
      let seed = Int32(seedIndex)
      if let underlineRanges = self.underlineRanges.value {
        seedRand(seed)
        let attributes: Attributes = underlineColor.value == .black
                                   ? [.underlineStyle: underlineStyle.rawValue]
                                   : [.underlineStyle: underlineStyle.rawValue,
                                      .underlineColor: underlineColor.value]
        addAttributes(text, locale, underlineRanges, attributes)
      }
      if let strikethroughRanges = self.strikethroughRanges.value {
        seedRand(seed)
        let attributes: Attributes = strikethroughColor.value == .black
                                   ? [.strikethroughStyle: strikethroughStyle.rawValue]
                                   : [.strikethroughStyle: strikethroughStyle.rawValue,
                                      .strikethroughColor: strikethroughColor.value]
        addAttributes(text, locale, strikethroughRanges, attributes)
      }
      if background.color != nil || background.borderWidth > 0 {
        seedRand(seed)
        let attributes: Attributes = background.color == nil
                                   ? [.stuBackground: background]
                                   : [.stuBackground: background,
                                      .backgroundColor: background.color!]
        addAttributes(text, locale, backgroundRanges.value, attributes)
      }
      if let linkRanges = linkRanges.value {
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
      if let shadowRanges = shadowRanges.value {
        seedRand(seed)
        addAttributes(text, locale, shadowRanges, [.shadow: shadow])
      }
      if strokeWidth.value > 0 {
        seedRand(seed)
        let width = 100*strokeWidth.value/font.pointSize
        if let fillColor = strokeFillColor.value {
          addAttributes(text, locale, strokeRanges.value, [.foregroundColor: fillColor,
                                                           .strokeWidth: -width,
                                                           .strokeColor: strokeColor.value])
        } else {
          addAttributes(text, locale, strokeRanges.value, [.strokeWidth: width,
                                                           .strokeColor: strokeColor.value])
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
        if maxLineCount.value > 0 && mode.isSingleLabelMode  {
          let mode: CTLineTruncationType
          switch lastLineTruncationMode.value {
          case .start: mode = .start
          case .middle: mode = .middle
          case .end, .clip: mode = .end
          }
          articleText.addAttribute(.stuTruncationScope,
                                   value: STUTruncationScope(maximumNumberOfLines: Int32(maxLineCount.value),
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
        largeSTULabel.accessibilityElementSeparatesLinkElements = accessibilitySeparateLinks.value
        largeSTULabel.accessibilityElementParagraphSeparationCharacterThreshold = 0
        largeSTULabel.textLayoutMode = textLayoutMode.value
        largeSTULabel.dragInteractionEnabled = linkDragInteractionEnabled.value
        largeSTULabel.contextMenuInteractionEnabled = linkContextMenuInteractionEnabled.value
        largeSTULabel.attributedText = text
      }
    }

    lastLayoutWidth = nil
    view.setNeedsLayout()
  }

  private var lastLayoutWidth: CGFloat?

  override func viewWillLayoutSubviews() {
    if _needsTextUpdate {
      updateText(removeSavedScrollStates: false)
    }

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
        let font = self.font.value
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
    
  // MARK: - STULabelDelegate
  
  @available(iOS 13.0, *)
  func label(_ label: STULabel, contextMenuActionsFor link: STUTextLink, suggestedActions: [UIMenuElement]) -> UIMenu? {
      guard let url = link.linkAttribute as? URL else { return nil }
      
      let open = UIAction(title: "Open", image: UIImage(systemName: "safari")) { (_) in
          UIApplication.shared.open(url)
      }
      
      let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { (_) in
          UIPasteboard.general.url = url
      }
      
      let share = UIAction(title: "Share...", image: UIImage(systemName: "square.and.arrow.up")) { (_) in
          let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
          activityViewController.popoverPresentationController?.sourceView = label
          activityViewController.popoverPresentationController?.sourceRect = link.bounds
          self.present(activityViewController, animated: true)
      }
      
      return UIMenu(title: url.absoluteString, children: [open, copy, share])
  }

  // MARK: - Grapheme cluster highlighting

  @objc
  func largeLabelWasTapped(_ gestureRecognizer: UITapGestureRecognizer) {
    if gestureRecognizer.state == .ended && highlightGraphemeCluster.value {
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
    private let translationCell: SelectCell<UDHR.Translation>
    private let fontFamilyCell: SelectCell<FontFamily>
    private let fontTextStyleCell: SelectCell<UIFont.TextStyle>
    private let fontSizeCategoryCell: SelectCell<UIContentSizeCategory>
    private let systemFontStyleCell: SelectCell<SystemFontStyle>
    private let fontStyleCell: SelectCell<FontStyle>
    private let fontSizeCell: StepperCell<CGFloat>
    private let lineSpacingCell: StepperCell<CGFloat>
    private let textLayoutModeCell: SelectCell<STUTextLayoutMode>

    private let hyphenationTableCell: SubtableCell
    private let hyphenateCell: SwitchCell
    private let hyphenationFactorCell: StepperCell<Float32>

    private let justifyCell: SwitchCell

    private let linkTableCell: SubtableCell
    private let linkRangesCell: SelectCell<RandomTextRanges?>
    private let linkDraggableCell: SwitchCell
    private let linkContextMenuCell: SwitchCell

    private let backgroundTableCell: SubtableCell
    private let backgroundColorCell: SelectCell<UIColor?>
    private let backgroundRangesCell: SelectCell<RandomTextRanges>
    private let backgroundFillLineGapsCell: SwitchCell
    private let backgroundExtendToCommonBoundsCell: SwitchCell
    private let backgroundOutsetCell: StepperCell<CGFloat>
    private let backgroundCornerRadiusCell: StepperCell<CGFloat>
    private let backgroundBorderWidthCell: StepperCell<CGFloat>
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

    private let shadowTableCell:      SubtableCell
    private let shadowColorCell:      SelectCell<UIColor>
    private let shadowColorAlphaCell: StepperCell<CGFloat>
    private let shadowRangesCell:     SelectCell<RandomTextRanges?>
    private let shadowOffsetXCell:    StepperCell<CGFloat>
    private let shadowOffsetYCell:    StepperCell<CGFloat>
    private let shadowBlurRadiusCell: StepperCell<CGFloat>

    private let strokeRangesCell: SelectCell<RandomTextRanges>
    private let strokeTableCell: SubtableCell
    private let strokeWidthCell: StepperCell<CGFloat>
    private let strokeColorCell: SelectCell<UIColor>
    private let strokeFillColorCell: SelectCell<UIColor?>

    private let truncationTableCell: SubtableCell
    private let maxLineCountCell: StepperCell<Int>
    private let lastLineTruncationModeCell: SelectCell<STULastLineTruncationMode>

    private let accessibilityTableCell: SubtableCell
    private let accessibilitySeparateParagraphsCell: SwitchCell
    private let accessibilitySeparateLinksCell: SwitchCell

    private let extraTableCell: SubtableCell
    private let highlightGraphemeClusterCell: SwitchCell

    private let resetButtonCell: ButtonCell

    private let preferredFontCells: [UITableViewCell]
    private let systemFontCells: [UITableViewCell]
    private let normalFontCells: [UITableViewCell]

    private var cells: [UITableViewCell]

    private func setFontFamilyLabelFont(_ label: UILabel,
                                        _ fontFamilyIndex: Int, _ fontFamily: FontFamily) {
      if fontFamilyIndex <= 1 {
        label.font = nil
      } else {
        let size = label.font.pointSize
        let styles = fontFamily.styles
        let index = styles.firstIndex {    $0.name == "Regular"
                                        || $0.name == "Medium"
                                        || $0.name == "Roman" }
                    ?? 0
        let name = styles[index].fontName
        label.font = UIFont(name: name, size: size)
      }
    }

    private func fontFamilyChanged(newIndex: Int, newFamily: FontFamily) {
      setFontFamilyLabelFont(fontFamilyCell.detailTextLabel!, newIndex, newFamily)
      let oldFontKind = viewerVC.fontKind
      if newIndex == 0 {
        viewerVC.fontKind = .preferred
        cells = preferredFontCells
      } else if newIndex == 1 {
        viewerVC.fontKind = .system
        cells = systemFontCells
        let oldStyleName = styleName(fontName: viewerVC.font.value.fontName)
        let styleIndex = systemFontStyles.firstIndex { $0.name == oldStyleName }
                      ?? systemFontStyles.firstIndex { $0.weight == .regular }
                      ?? 0
        systemFontStyleCell.index = styleIndex
      } else {
        viewerVC.fontKind = .normal
        cells = normalFontCells
        let styles = newFamily.styles
        let oldStyleName = styleName(fontName: viewerVC.font.value.fontName)
        let styleIndex = styles.firstIndex { $0.name == oldStyleName }
                      ?? styles.firstIndex {   $0.name == "Regular"
                                            || $0.name == "Medium"
                                            || $0.name == "Roman" }
                      ?? 0
        fontStyleCell.set(values: styles.map { ($0.name, $0) }, index: styleIndex)
      }
      if viewerVC.fontKind != oldFontKind {
        self.tableView.reloadData()
      }
      updateFont()
    }

    private func updateFont() {
      let font: UIFont
      switch viewerVC.fontKind {
      case .preferred:
        let style = fontTextStyleCell.value
        if #available(iOS 10.0, *) {
          let sizeCategory = fontSizeCategoryCell.value
          let tc = UITraitCollection(preferredContentSizeCategory: sizeCategory)
          font = UIFont.preferredFont(forTextStyle: style, compatibleWith: tc)
        } else {
          font = UIFont.preferredFont(forTextStyle: style)
        }
        fontSizeCell.value = font.pointSize
      case .system:
        font = systemFontStyleCell.value.font(size: fontSizeCell.value)
      case .normal:
        let fontName = fontStyleCell.value.fontName
        let size = CGFloat(fontSizeCell.value)
        font = UIFont(name: fontName, size: size)!
      }
      print("\(font.fontName) \(font.pointSize)pt A/D/L: \(font.ascender)/\(-font.descender)/\(font.leading)")
      viewerVC.font.value = font
    }

    private let obs = PropertyObserverContainer()

    init(_ vc: UDHRViewerVC) {
      self.viewerVC = vc

      modeCell = SelectCell("Mode", Mode.allCases.map({ ($0.description, $0) }), vc.modeSetting)

      translationCell = SelectCell("Language", udhr.translations.map{ ($0.language, $0) },
                                   vc.translationSetting)

      let font = vc.font.value
      let fontName = font.fontName
      let fontStyle = styleName(fontName: fontName)
      let fontFamilyName = font.familyName

      fontFamilyCell = SelectCell("Font",
                                  [("UIFont.preferredFont (SF)",
                                    FontFamily(name: "UIFont.preferredFont", styles: [])),
                                   ("UIFont.systemFont (SF)",
                                    FontFamily(name: "UIFont.systemFont", styles: []))]
                                  + fontFamilies.map { ($0.name, $0) },
                                  index:   vc.fontKind == .preferred ? 0
                                         : vc.fontKind == .system ? 1
                                         : 2 + fontFamilies.firstIndex { $0.name == fontFamilyName }!)

      fontTextStyleCell = SelectCell("Font style", fontTextStyles, vc.preferredFontStyle)

      fontSizeCategoryCell = SelectCell("Size category", contentSizeCategories,
                                        vc.preferredFontSizeCategory)

      systemFontStyleCell = SelectCell("Font style", systemFontStyles.map { ($0.name, $0) },
                                       index: systemFontStyles.firstIndex { $0.name == fontStyle }
                                              ?? 0)

      let fontStyles = !fontFamilyCell.value.styles.isEmpty ? fontFamilyCell.value.styles
                     : fontFamilies.first!.styles

      fontStyleCell = SelectCell("Font style", fontStyles.map { ($0.name, $0) },
                                  index: fontStyles.firstIndex { $0.fontName == fontName } ?? 0)

      fontSizeCell = StepperCell("Font size", 1...200, step: 0.1, value: font.pointSize, unit: "pt")

      lineSpacingCell = StepperCell("Line spacing", 0...200, step: 0.5, vc.lineSpacing,
                                    unit: "pt")
      lineSpacingCell.roundsValueToMultipleOfStepSize = true

      textLayoutModeCell = SelectCell("Layout mode",
                                      [("Default", .default), ("Text Kit", .textKit)],
                                      vc.textLayoutMode)

      hyphenateCell = SwitchCell("Hyphenate", vc.hyphenate)
      hyphenateCell.isEnabled = vc.isHyphenationAvailable

      hyphenationFactorCell = StepperCell("Factor", 0...1, step: 0.01, vc.hyphenationFactor)
      hyphenationFactorCell.isEnabled = vc.hyphenate.value

      hyphenationTableCell = SubtableCell("Hyphenation", [hyphenateCell, hyphenationFactorCell])

      justifyCell = SwitchCell("Justify", vc.justify)

      func newUnderlineStyleCell(_ section: String, _ setting: Property<NSUnderlineStyle>)
        -> SelectCell<NSUnderlineStyle>
      {
        let cell = SelectCell("Style", underlineStyles, setting)
        cell.navigationItemTitle = section + " style"
        return cell
      }

      func newUnderlinePatternCell(_ section: String, _ setting: Property<NSUnderlineStyle>)
        -> SelectCell<NSUnderlineStyle>
      {
        let cell = SelectCell("Pattern", underlinePatterns, setting)
        cell.navigationItemTitle = section + " pattern"
        return cell
      }

      func newColorCell(_ section: String, _ property: Property<UIColor>, title: String = "Color",
                        blackName: String? = nil)
        -> SelectCell<UIColor>
      {
        let cs = blackName == nil ? colors
               : [(name: blackName!, value: UIColor.black)] + colors[1...]
        let cell = SelectCell(title, cs, property)
        cell.valueLabelStyler = { (index: Int, color: UIColor, label: UILabel) in
          label.textColor = color
        }
        cell.navigationItemTitle = section + " " + title.lowercased()
        cell.onIndexChange = { [unowned cell] (_, newColor) in
          cell.detailTextColor = newColor
        }
        return cell
      }

      func newOptionalColorCell(_ section: String, _ property: Property<UIColor?>,
                                title: String = "Color")
        -> SelectCell<UIColor?>
      {
        let cell = SelectCell(title,
                              [(name: "None", value: nil)]
                              + colors.map { (name: $0.0, value: $0.1 as UIColor?) },
                              property)
        cell.valueLabelStyler = { (index: Int, color: UIColor?, label: UILabel) in
          label.textColor = color ?? .black
        }
        cell.navigationItemTitle = section + " " + title.lowercased()
        cell.onIndexChange = { [unowned cell] (_, newColor) in
          cell.detailTextColor = newColor ?? UIColor.black
        }
        return cell
      }

      func newTextColorCell(_ section: String, _ setting: Property<UIColor>) -> SelectCell<UIColor> {
        return newColorCell(section, setting, blackName: "Text color (Black/Gray)")
      }


      let randomTextRanges = RandomTextRanges.allCases.map { ($0.name, $0)}
      let optionalRandomTextRanges = [(name: "None", value: nil)]
                                   + RandomTextRanges.allCases.map { ($0.name, $0)}

      func newRangesCell(_ section: String, _ property: Property<RandomTextRanges>)
        -> SelectCell<RandomTextRanges>
      {
        let cell = SelectCell("Ranges", randomTextRanges, property)
        cell.navigationItemTitle = section + " ranges"
        return cell
      }

      func newOptionalRangesCell(_ section: String, _ setting: Setting<RandomTextRanges?>)
        -> SelectCell<RandomTextRanges?>
      {
        let cell = SelectCell("Ranges", optionalRandomTextRanges, setting)
        cell.navigationItemTitle = section + " ranges"
        return cell
      }

      linkRangesCell = newOptionalRangesCell("Link", vc.linkRanges)
      linkDraggableCell = SwitchCell("Draggable", vc.linkDragInteractionEnabled)
      linkContextMenuCell = SwitchCell("Context Menus", vc.linkContextMenuInteractionEnabled)

      if #available(iOS 13, *) {
        linkTableCell = SubtableCell("Links", [linkRangesCell, linkDraggableCell, linkContextMenuCell])
      } else if #available(iOS 11, *) {
        linkTableCell = SubtableCell("Links", [linkRangesCell, linkDraggableCell])
      } else {
        linkTableCell = SubtableCell("Links", [linkRangesCell])
      }

      backgroundColorCell = newOptionalColorCell("Background", vc.backgroundColor)
      backgroundRangesCell = newRangesCell("Background", vc.backgroundRanges)
      backgroundFillLineGapsCell = SwitchCell("Fill line gaps", vc.backgroundFillLineGaps)
      backgroundExtendToCommonBoundsCell = SwitchCell("Extend to common bounds",
                                                      vc.backgroundExtendToCommonBounds)
      backgroundOutsetCell = StepperCell("Outset", -100...100, step: 0.5, vc.backgroundOutset)
      backgroundCornerRadiusCell = StepperCell("Corner radius", 0...100, step: 0.5,
                                               vc.backgroundCornerRadius)
      backgroundBorderWidthCell = StepperCell("Border width", 0...100, step: 0.5,
                                              vc.backgroundBorderWidth)
      backgroundBorderColorCell = newColorCell("Background", vc.backgroundBorderColor,
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

      underlineRangesCell = newOptionalRangesCell("Underline", vc.underlineRanges)
      underlineStyleCell = newUnderlineStyleCell("Underline", vc.underlineStyleStyle)
      underlinePatternCell = newUnderlinePatternCell("Underline", vc.underlineStylePattern)
      underlineColorCell = newTextColorCell("Underline", vc.underlineColor)

      underlineTableCell = SubtableCell("Underlining",
                                        [underlineRangesCell, underlineStyleCell,
                                         underlinePatternCell, underlineColorCell])

      strikethroughRangesCell = newOptionalRangesCell("Strikethrough", vc.strikethroughRanges)
      strikethroughStyleCell = newUnderlineStyleCell("Strikethrough", vc.strikethroughStyleStyle)
      strikethroughPatternCell = newUnderlinePatternCell("Strikethrough", vc.strikethroughStylePattern)
      strikethroughColorCell = newTextColorCell("Strikethrough", vc.strikethroughColor)
      strikethroughTableCell = SubtableCell("Strikethrough",
                                            [strikethroughRangesCell, strikethroughStyleCell,
                                             strikethroughPatternCell, strikethroughColorCell])

      shadowRangesCell = newOptionalRangesCell("Shadow", vc.shadowRanges)
      shadowColorCell = newColorCell("Shadow", vc.shadowColor)
      shadowColorAlphaCell = StepperCell("Color alpha", 0...1, step: 0.01, vc.shadowColorAlpha)
      shadowOffsetXCell = StepperCell("X-offset", -1000...1000, step: 0.5, vc.shadowOffsetX)
      shadowOffsetYCell = StepperCell("Y-offset", -1000...1000, step: 0.5, vc.shadowOffsetY)
      shadowBlurRadiusCell = StepperCell("blur radius", 0...1000, step: 0.5,
                                         vc.shadowBlurRadius)

      shadowTableCell = SubtableCell("Shadow", [shadowRangesCell, shadowColorCell,
                                                shadowColorAlphaCell,
                                                shadowOffsetXCell, shadowOffsetYCell,
                                                shadowBlurRadiusCell])

      strokeRangesCell = newRangesCell("Stroke", vc.strokeRanges)
      strokeWidthCell = StepperCell("Width", 0...1000, step: 0.25, vc.strokeWidth, unit: "pt")
      strokeColorCell = newColorCell("Stroke", vc.strokeColor)
      strokeFillColorCell = newOptionalColorCell("Text", vc.strokeFillColor, title: "Fill color")
      strokeTableCell = SubtableCell("Stroke", [strokeRangesCell, strokeWidthCell, strokeColorCell,
                                                strokeFillColorCell])

      maxLineCountCell = StepperCell("Max number of lines", 0...1000, step: 1,
                                     vc.maxLineCount)

      lastLineTruncationModeCell = SelectCell("Last line truncation", truncationModes,
                                              vc.lastLineTruncationMode)

      truncationTableCell = SubtableCell("Truncation", [maxLineCountCell,
                                                        lastLineTruncationModeCell])
      truncationTableCell.footerLabel.text = "Note that a STULabel view always uses 'end' truncation if it has to remove text from more than a single consecutive paragraph, because in that case the other truncation forms could appear misleading."

      accessibilitySeparateParagraphsCell = SwitchCell("Separate paragraphs",
                                                       vc.accessibilitySeparateParagraphs)

      accessibilitySeparateLinksCell = SwitchCell("Separate links",
                                                  vc.accessibilitySeparateLinks)

      accessibilityTableCell = SubtableCell("STULabel accessibility",
                                            [accessibilitySeparateParagraphsCell,
                                             accessibilitySeparateLinksCell])

      highlightGraphemeClusterCell = SwitchCell("Highlight character closest to tap",
                                                vc.highlightGraphemeCluster)
      highlightGraphemeClusterCell.textLabel?.numberOfLines = 0

      extraTableCell = SubtableCell("Extra", [highlightGraphemeClusterCell])

      resetButtonCell = ButtonCell("Reset")

      var preferredFontCells: [UITableViewCell] = [modeCell, translationCell, fontFamilyCell]
      var systemFontCells = preferredFontCells
      var normalFontCells = preferredFontCells

      preferredFontCells.append(contentsOf: [fontTextStyleCell])
      if #available(iOS 10, *) {
        preferredFontCells.append(fontSizeCategoryCell)
      }
      systemFontCells.append(contentsOf: [systemFontStyleCell, fontSizeCell])
      normalFontCells.append(contentsOf: [fontStyleCell, fontSizeCell])

      let otherCells = [lineSpacingCell, textLayoutModeCell, hyphenationTableCell,
                        justifyCell, linkTableCell, backgroundTableCell, underlineTableCell,
                        strikethroughTableCell, shadowTableCell, strokeTableCell,
                        truncationTableCell, accessibilityTableCell, extraTableCell, resetButtonCell]

      preferredFontCells.append(contentsOf: otherCells)
      systemFontCells.append(contentsOf: otherCells)
      normalFontCells.append(contentsOf: otherCells)

      self.preferredFontCells = preferredFontCells
      self.systemFontCells = systemFontCells
      self.normalFontCells = normalFontCells

      switch vc.fontKind {
      case .preferred: cells = preferredFontCells
      case .system:    cells = systemFontCells
      case .normal:    cells = normalFontCells
      }

      super.init(style: .plain)

      let updateCellsForMode = { [unowned self] in
        let mode = vc.modeSetting.value
        let isNotIOS9 = NSFoundationVersionNumber > Double(NSFoundationVersionNumber_iOS_9_x_Max)
        switch mode {
        case .stuLabel_vs_UITextView:
          self.accessibilitySeparateParagraphsCell.isEnabled = true
          self.accessibilitySeparateLinksCell.isEnabled = isNotIOS9
          self.highlightGraphemeClusterCell.isEnabled = false
        case .stuLabel, .zoomableSTULabel:
          self.accessibilitySeparateParagraphsCell.isEnabled = false
          self.accessibilitySeparateLinksCell.isEnabled = isNotIOS9
          self.highlightGraphemeClusterCell.isEnabled = true
        case .uiTextView:
          self.accessibilitySeparateParagraphsCell.isEnabled = false
          self.accessibilitySeparateLinksCell.isEnabled = false
          self.highlightGraphemeClusterCell.isEnabled = false
        }
      }
      updateCellsForMode()

      obs.observe(vc.modeSetting, updateCellsForMode)

      obs.observe(vc.translationSetting) { [unowned self] in
        if !vc.isHyphenationAvailable {
          vc.hyphenate.value = false
          self.hyphenateCell.isEnabled = false
        } else {
          self.hyphenateCell.isEnabled = true
        }
      }

      setFontFamilyLabelFont(fontFamilyCell.detailTextLabel!,
                             fontFamilyCell.index, fontFamilyCell.value)
      fontFamilyCell.valueLabelStyler = { [unowned self] (index, family, label) in
        self.setFontFamilyLabelFont(label, index, family)
      }

      fontFamilyCell.onIndexChange = { [unowned self] (newIndex, newFamily) in
        self.fontFamilyChanged(newIndex: newIndex, newFamily: newFamily)
      }

      fontTextStyleCell.onIndexChange = { [unowned self] (newIndex, value) in
        self.updateFont()
      }

      obs.observe(vc.preferredFontStyle) { [unowned self] in
        self.updateFont()
      }

      let updateFontSizeCategoryLabel = { [unowned self] in
        let category = self.fontSizeCategoryCell.valueName
        self.fontSizeCategoryCell.detailText = "\(category), \(vc.font.value.pointSize)pt"
      }
      updateFontSizeCategoryLabel()

      obs.observe(vc.font) {
        if vc.fontKind == .preferred {
          updateFontSizeCategoryLabel()
        }
      }

      obs.observe(vc.preferredFontSizeCategory) { [unowned self] in
        updateFontSizeCategoryLabel() // The category may change without the font changing.
        self.updateFont()
      }

      systemFontStyleCell.onIndexChange = { [unowned self] (_, _) in self.updateFont() }

      fontStyleCell.onIndexChange = { [unowned self] (_, _) in self.updateFont() }
      fontSizeCell.onValueChange = { [unowned self] (_) in self.updateFont() }

      let updateMinLineSpacing = { [unowned self] in
        let leading = vc.font.value.leading
        self.lineSpacingCell.range = max(0, leading)...self.lineSpacingCell.range.upperBound
      }
      updateMinLineSpacing()

      obs.observe(vc.font) {
        updateMinLineSpacing()
      }

      let updateHyphenationLabel = { [unowned self] in
        self.hyphenationTableCell.detailText = !vc.hyphenate.value ? "Disabled"
                                             : self.hyphenationFactorCell.detailText
      }
      updateHyphenationLabel()

      obs.observe(vc.hyphenate) { [unowned self] newValue in
        self.hyphenationFactorCell.isEnabled = newValue
        updateHyphenationLabel()
      }

      obs.observe(vc.hyphenationFactor) { _ in updateHyphenationLabel() }

      let linkColor = vc.view.tintColor

      let updateLinkTableCellDetailLabel = { [unowned self] in
        self.linkTableCell.detailText = vc.linkRanges.value?.name ?? "None"
        self.linkTableCell.detailTextColor = vc.linkRanges.value == nil ? nil : linkColor
      }

      updateLinkTableCellDetailLabel()

      obs.observe(vc.linkRanges, updateLinkTableCellDetailLabel)

      let updateBackgroundTableCellDetailLabel = { [unowned self] in
        let color = vc.background.color
        let borderWidth = vc.background.borderWidth
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

      obs.observe(vc.backgroundColor, updateBackgroundTableCellDetailLabel)
      obs.observe(vc.backgroundBorderWidth, updateBackgroundTableCellDetailLabel)

      func underlineLabel(style: String, pattern: String) -> String {
        if style == "None" {
          return "None"
        }
        if pattern == "Solid" {
          return style
        }
        return style + ", " + pattern
      }

      let updateUnderlineTableCellLabel = { [unowned self] in
        let hasUnderline = vc.underlineRanges.value != nil
        let style = underlineStyles[self.underlineStyleCell.index].name
        let pattern = underlinePatterns[self.underlinePatternCell.index].name
        self.underlineTableCell.detailText = !hasUnderline ? "None"
                                           : underlineLabel(style: style, pattern: pattern)
        self.underlineTableCell.detailTextColor = !hasUnderline ? nil
                                                : vc.underlineColor.value
      }

      let updateStrikethroughTableCellLabel = { [unowned self] in
        let hasStrikethrough = vc.strikethroughRanges.value != nil
        let style = underlineStyles[self.strikethroughStyleCell.index].name
        let pattern = underlinePatterns[self.strikethroughPatternCell.index].name
        self.strikethroughTableCell.detailText = !hasStrikethrough ? "None"
                                               : underlineLabel(style: style, pattern: pattern)
        self.strikethroughTableCell.detailTextColor = !hasStrikethrough ? nil
                                                    : vc.strikethroughColor.value
      }

      updateUnderlineTableCellLabel()
      updateStrikethroughTableCellLabel()

      obs.observe(vc.underlineRanges,       updateUnderlineTableCellLabel)
      obs.observe(vc.underlineStyleStyle,   updateUnderlineTableCellLabel)
      obs.observe(vc.underlineStylePattern, updateUnderlineTableCellLabel)
      obs.observe(vc.underlineColor,        updateUnderlineTableCellLabel)

      obs.observe(vc.strikethroughRanges,       updateStrikethroughTableCellLabel)
      obs.observe(vc.strikethroughStyleStyle,   updateStrikethroughTableCellLabel)
      obs.observe(vc.strikethroughStylePattern, updateStrikethroughTableCellLabel)
      obs.observe(vc.strikethroughColor,        updateStrikethroughTableCellLabel)


      let updateShadowTableCellLabel = { [unowned self] in
        self.shadowTableCell.detailText = vc.shadowRanges.value?.name ?? "None"
        self.shadowTableCell.detailTextColor = vc.shadowRanges.value == nil ? nil
                                             :  vc.shadowColor.value
      }
      updateShadowTableCellLabel()

      obs.observe(vc.shadowRanges, updateShadowTableCellLabel)
      obs.observe(vc.shadowColor,  updateShadowTableCellLabel)


      let updateStrokeTableCellLabel = { [unowned self] in
        let hasStroke = vc.strokeWidth.value > 0
        self.strokeTableCell.detailText =
            !hasStroke ? "None"
          : "\(self.strokeWidthCell.detailText.lowercased()), \(self.strokeColorCell.detailText.lowercased())"
            + (vc.strokeFillColor.value == nil
              ? "" : " " + self.strokeFillColorCell.detailText.lowercased())
        self.strokeTableCell.detailTextColor = !hasStroke ? nil
                                             : vc.strokeFillColor.value
                                               ?? vc.strokeColor.value
      }
      updateStrokeTableCellLabel()

      obs.observe(vc.strokeWidth, updateStrokeTableCellLabel)
      obs.observe(vc.strokeColor, updateStrokeTableCellLabel)
      obs.observe(vc.strokeFillColor, updateStrokeTableCellLabel)

      let updateTruncationTableCellLabel = { [unowned self] in
        let mode = self.lastLineTruncationModeCell.detailText.lowercased()
        self.truncationTableCell.detailText = vc.maxLineCount.value == 0 ? "None"
                                            : "\(vc.maxLineCount.value) lines, \(mode)"
      }
      updateTruncationTableCellLabel()

      obs.observe(vc.maxLineCount, updateTruncationTableCellLabel)
      obs.observe(vc.lastLineTruncationMode, updateTruncationTableCellLabel)

      resetButtonCell.onButtonTap = { [unowned self] in
        if self.fontFamilyCell.index != 0 {
          self.fontFamilyCell.index = 0
          self.fontFamilyCell.onIndexChange?(0, self.fontFamilyCell.value)
        }
        vc.preferredFontStyle.resetValue()
        vc.preferredFontSizeCategory.resetValue()
        vc.lineSpacing.resetValue()
        vc.textLayoutMode.resetValue()
        vc.hyphenate.resetValue()
        vc.hyphenationFactor.resetValue()
        vc.justify.resetValue()
        vc.linkRanges.resetValue()
        vc.linkDragInteractionEnabled.resetValue()
        vc.linkContextMenuInteractionEnabled.resetValue()
        vc.backgroundRanges.resetValue()
        vc.backgroundColor.resetValue()
        vc.backgroundFillLineGaps.resetValue()
        vc.backgroundExtendToCommonBounds.resetValue()
        vc.backgroundOutset.resetValue()
        vc.backgroundCornerRadius.resetValue()
        vc.backgroundBorderWidth.resetValue()
        vc.backgroundBorderColor.resetValue()
        vc.underlineRanges.resetValue()
        vc.underlineStyleStyle.resetValue()
        vc.underlineStylePattern.resetValue()
        vc.underlineColor.resetValue()
        vc.strikethroughRanges.resetValue()
        vc.strikethroughStyleStyle.resetValue()
        vc.strikethroughStylePattern.resetValue()
        vc.strikethroughColor.resetValue()
        vc.shadowRanges.resetValue()
        vc.shadowColor.resetValue()
        vc.shadowColorAlpha.resetValue()
        vc.shadowOffsetX.resetValue()
        vc.shadowOffsetY.resetValue()
        vc.shadowBlurRadius.resetValue()
        vc.strokeRanges.resetValue()
        vc.strokeWidth.resetValue()
        vc.strokeColor.resetValue()
        vc.strokeFillColor.resetValue()
        vc.maxLineCount.resetValue()
        vc.lastLineTruncationMode.resetValue()
        vc.accessibilitySeparateParagraphs.resetValue()
        vc.accessibilitySeparateLinks.resetValue()
        vc.highlightGraphemeCluster.resetValue()
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
