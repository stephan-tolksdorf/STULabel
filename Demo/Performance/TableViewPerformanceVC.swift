// Copyright 2018 Stephan Tolksdorf

import UIKit

import STULabel

typealias Attributes = [NSAttributedString.Key: Any]

#if !swift(>=4.2)
extension UITableView {
  static let automaticDimension = UITableViewAutomaticDimension
  typealias Style = UITableViewStyle
}

extension UITableViewCell {
  typealias CellStyle = UITableViewCellStyle
}
#endif


private let font = UIFont.systemFont(ofSize: 14)

private let lineSpacing: CGFloat = 6

private let multiLineAttributes: Attributes =
    [.font: font,
     .paragraphStyle: { let p = NSMutableParagraphStyle();
                        p.baseWritingDirection = .leftToRight
                        p.lineSpacing = lineSpacing
                        return p.copy() }()]

private let singleLineAttributes: Attributes =
    [.font: UIFont.boldSystemFont(ofSize: 14),
     .paragraphStyle: { let p = NSMutableParagraphStyle();
                        p.baseWritingDirection = .leftToRight
                        p.lineBreakMode = .byTruncatingTail
                        return p.copy() }()]

private func ceilToDisplayScale(_ value: CGFloat) -> CGFloat {
  let displayScale = stu_mainScreenScale()
  return ceil(displayScale*value)/displayScale
}

private let lineHeight = font.ascender - font.descender

private let lineHeightIncludingSpacing = lineHeight + max(font.leading, lineSpacing)

private let titleTextViewBottomInset: CGFloat = {
  let rh = ceilToDisplayScale(lineHeight + max(font.leading, lineSpacing/2))
  let s = rh - lineHeight
  return max(0, s.nextDown)
}()

private let extraSpacingAfterTitleUILabel = roundToDisplayScale(lineHeightIncludingSpacing - lineHeight)

let emojis = Array("😀😁😂😃😄😅😆😉😊😋😎😍😘😗😙😚☺️🙂🤗🤔😶🙄😏😣😥😮😯😪😫😴😌😛😜😝😒😓😔😕🙃🤑😲😖😤😢😩😬😱😳😵😇🤓😡😠😷🤒🤕😇🤓💀👻👽🤖💩😺😸😹😻😼😽🙀🐶🐱🐭🐹🐰🐻🐼🐨🐯🦁🐮🐷🐽🐸🐵🙊🙉🙊🐒🐔🐧🐦🐤🐣🐥🐺🐗🐴🦄🐝🐛🐌🐚🐞🐜🕷🕸🐢🐍🦂🦀🐙🐠🐟🐡🐬🐳🐋🐊🐆🐅🐃🐂🐄🐪🐫🐘🐎🐖🐐🐏🐑🐕🐩🐈🐓🦃🕊🐇🐁🐀🐿🐾🐉🐲🌵🎄🌲🌳🌴🌱🌿☘️🍀🎍🎋🍃🍂🍁🍄🌾💐🌷🌹🌻🌼🌸🌺🌎🌍🌏🌕🌖🌗🌘🌑🌒🌓🌔🌚🌝🌞🌛🌜🌙💫⭐️🌟✨⚡️🔥💥☄️☀️🌤🌈☃️⛄️❄️💧💦☔️🚗🚕🚙🚌🚎🏎🚓🚑🚒🚐🚚🚛🚜🚲🏍🚨🚔🚍🚘🚖🚡🚠🚟🚃🚋🚞🚝🚄🚅🚈🚂🚆🚇🚊🚉🚁🛩✈️🛫🛬🚀🛰💺⛵️🛥🚤🛳⛴🚢⚓️🚧⛽️🚏🚦🚥🗺🗿🗽⛲️🗼🏰🏯🏟🎡🎢🎠⛱🏖🏝⛰🏔🗻🌋🏜🏕⛺️🛤🛣🏗🏭🏠🏡🏘🏚🏢🏬🏣🏤🏥🏦🏨🏪🏫🏩💒🏛⛪️🕌🕍🕋⛩🗾🎑🏞🌅🌄🌠🎇🎆🌇🌆🏙🌃🌌🌉🌁⚽️🏀🏈⚾️🎾🏐🏉🏓🏸🏒🏑🏏⛳️🏹🎣⛸🎿⛷🏂🎽🏅🎖🏆🏵🎗🎫🎟🎪🎭🎨🎬🎤🎧🎼🎹🎷🎺🎸🎻🎲🎯🎳🎮🎰")

// Extracts from text generated with http://www.richyli.com/tool/loremipsum/ and translated to simplified Chinese using Google translate.
let chinese = ["此安里包心统妈然得准么", "大水品他体同台也团度", "信第般了动管", "式否物师有是而求", "身界转叫举话大起", "山业系受衣影目子", "象朋土奇化火我死", "人四技果", "三人现是说长名火以当的教三", "成可南", "高常来卖拿旅", "比过论国地至", "的愿德到中上入", "统金路过害教次什个校走多区人", "是他技红只后", "点人法红景理经国朋童上说", "你在有道子先", "我像举子站没", "其议所车到", "是热企双大着际手极", "起而来究像文小脑要金大中为子", "用以可", "中度走活还片资无", "当国工识新那衣气", "是灵故我", "运鱼养统", "司道往解还童极会会", "华己局电宝势内时湾", "家让我步类方好", "实到以电美的海形", "安区有行前居下式得当", "度我子易母职", "民不任表发她省", "乎就老爱委机经了色住欢光全", "道说失结代东白防城", "产多女引是", "消客通", "界及可长与国出众", "亲物许来以价", "决不无物信高响衣陆合老", "何他的加再于千到", "福长独制术是知长", "有完标？才城使老久不兴出年学企", "却生重台", "查毛们顾代了资进期今们病手", "地形孩前因轻效人此", "商衣少统发让华", "了记为市运么张对", "那定留感", "月果情能", "提人候作水女", "各状会", "两起复", "金销像时", "生议找欢产传子", "系银心时道它要喜发", "理说我则在过影", "广灵广照的请该", "素趣建", "际大自小平只电要后童人为", "南经火太的家政切同德头", "解大是師而以被久", "發果自義賽出健靜完", "然用法放這山禮星正", "就過天現它能其", "功大我緊自面在著都病爭", "只在引廣多通車英", "地際要二後教統護", "然意到险能边代数步大就", "但助入同如流都是", "而太被别还童轮议", "持位作小的独马古变", "求有我题家集分证", "层建然城房是心如", "到同石日谢两集在", "不行好长", "根加有有", "他专来经望直黄", "部是能", "面落险试务还建", "展画活快来数", "大笑罗望数统", "没头立分舞者离", "们克孩三心业", "民常此还点星", "比德他历发开什字举在都是约", "长钱团和于照事", "子消爸亚", "数告升创界案以真不约", "里做的我教此程", "问重比取合展妈", "样众声", "着工生下求品之来不象声小天千看"]


// Extracts from text generated with http://generator.lorem-ipsum.info/
let hindi = ["भारतीय", "ब्रौशर", "भारत", "हिंदी", "द्वारा", "एकत्रित", "यन्त्रालय", "एछित", "उन्हे", "विश्व", "समूह", "हार्डवेर", "प्रौध्योगिकी", "मुक्त", "आवश्यक", "करेसाथ", "बारे", "भाति", "पुष्टिकर्ता", "माहितीवानीज्य", "शीघ्र", "विश्व", "शारिरिक", "अविरोधता", "भीयह", "प्राप्त", "निर्देश", "समूह", "लेकिन", "विश्लेषण", "व्रुद्धि", "चिदंश", "गएआप", "बाटते", "सकते", "उसीएक्", "असक्षम", "प्रतिबध", "देने", "विभाजन", "प्राथमिक", "तरीके", "स्थिति", "दिनांक", "व्यवहार", "बनाति", "भीयह", "सहायता", "प्रतिबध्दता", "जनित", "सादगि", "प्राप्त", "मुख्यतह", "व्रुद्धि", "ध्वनि", "किया", "है।अभी", "व्याख्या", "बढाता", "।क", "सभीकुछ", "यन्त्रालय", "देखने", "देते", "बनाए", "आवश्यक", "सोफ़तवेर", "ध्वनि", "पहेला", "पुस्तक", "और्४५०", "विभाजन", "रचना", "हमारी", "दारी", "कुशलता", "वास्तव", "सम्पर्क", "सक्षम", "अपनि", "हुएआदि", "बेंगलूर", "विभाग", "ब्रौशर", "मुश्किल", "देते", "जागरुक", "जानकारी", "होने", "बनाति", "रखति", "सदस्य", "तरहथा।", "परिभाषित", "विचरविमर्श", "सुविधा", "अनुवादक", "आंतरकार्यक्षमता", "हैं।", "विवरन", "अथवा", "होसके", "व्याख्या", "प्रौध्योगिकी", "चिदंश", "अनुवादक", "सोफ़तवेर", "व्रुद्धि", "देकर", "जैसी", "बनाने", "एसेएवं", "बीसबतेबोध", "सदस्य", "और्४५०", "निर्माण", "रिती", "दिशामे", "निर्माण", "जानते", "बारे", "सकता", "भारतीय", "संस्थान", "बनाना", "लगती", "मुख्यतह", "सोफ़्टवेर", "ढांचामात्रुभाषा", "समजते", "विकास", "तरहथा।", "लाभान्वित", "बिन्दुओमे", "सुनत", "बनाति", "मेमत", "उपलब्ध", "वर्तमान", "अर्थपुर्ण", "उदेश", "चिदंश", "विनिमय", "तकनिकल", "वार्तालाप", "आधुनिक", "विकसित", "मुश्किल", "बारे", "सदस्य", "परस्पर", "एसेएवं", "बनाना", "वर्ष", "सादगि", "बाधा", "प्राधिकरन", "विभाजनक्षमता", "बिन्दुओ", "गोपनीयता", "बाटते", "भाषा", "भीयह", "हमारी", "मानसिक", "आशाआपस", "मुश्किल"]

private let isPad = UI_USER_INTERFACE_IDIOM() == .pad

private var greyBackgroundColor = UIColor(white: 0.95, alpha: 1)

private func emojiText(index: Int) -> NSAttributedString {
  seedRand(Int32(truncatingIfNeeded: index))

  var string = String("\(index)")

  let n = 16 + rand(64)

  for _ in 0..<n {
    let r = rand(Int32(emojis.count))
    string.append(" ")
    string.append(emojis[r])
  }
  return NSAttributedString(string, multiLineAttributes)
}

private let zeroSizeFont = UIFont(name: "Helvetica", size: 0)!

private let lineSpacingSuffix = NSAttributedString("\n ", [.font: zeroSizeFont])

private func withLineSpacingAfter(_ attributedString: NSAttributedString) -> NSAttributedString {
  let mutableAttributedString = NSMutableAttributedString()
  mutableAttributedString.append(attributedString)
  mutableAttributedString.append(lineSpacingSuffix)
  return mutableAttributedString.copy() as! NSAttributedString
}

private enum TestCase : Int, UserDefaultsStorable {
  case emojicalypse
  case socialMediaChinese
  case socialMediaHindi

  static let allCases = [emojicalypse, socialMediaChinese, socialMediaHindi]

  var name: String {
    switch self {
    case .emojicalypse: return "Emojicalypse"
    case .socialMediaChinese: return "Social media (Chinese)"
    case .socialMediaHindi: return "Social media (Hindi)"
    }
  }
}

private func pseudoChineseText(index: Int, singleLine: Bool) -> String {
  seedRand(Int32(index) + (singleLine ? 42 : 0))

  var string = ""

  let n = 1 + rand((singleLine ? 3 : 15)*(isPad ? 2 : 1))

  for i in 0..<n {
    let r = rand(Int32(chinese.count))
    string.append(chinese[r])
    let r2 = rand(24)
    if singleLine && r2 > 0 {
      if i < n - 1 {
        string.append("，")
      }
      continue;
    }
    switch r2 {
    case 0: string.append(" \(emojis[rand(min(51, Int32(emojis.count)))])")
            fallthrough
    case 1: string.append(" \(emojis[rand(min(51, Int32(emojis.count)))]) ")
    case 2 where i != n - 1: string.append("，１")
    case 3: string.append("：")
    case 4: string.append("一")
    case 3...10: string.append("，")
    case 11...12: string.append("！")
    case 13...14 where i != n - 1 && !singleLine:
      string.append("。\n")
    default:
      string.append("。")
    }
  }

  return string
}

private func pseudoHindiText(index: Int, singleLine: Bool) -> String {
  seedRand(Int32(index) + (singleLine ? 42 : 0))

  var string = ""

  let n = 1 + rand((singleLine ? 9 : 35)*(isPad ? 2 : 1))

  var newline: Bool = true
  for i in 0..<n {
    if !newline  {
      string.append(" ")
    }
    newline = false
    let r = rand(Int32(hindi.count))
    string.append(hindi[r])
    let r2 = rand(100)
    if r2 < 2 && isPad && rand(2) == 0 { continue }
    switch r2 {
    case 0: string.append(" \(emojis[rand(min(51, Int32(emojis.count)))])")
            fallthrough
    case 1: string.append(" \(emojis[rand(min(51, Int32(emojis.count)))]) ")
    case 2...3 where i != n - 1 && !singleLine:
      string.append("|\n")
      newline = true
    case 7...9 where i != n - 1 || !singleLine:
      string.append("?")
    case 10 where i != n - 1 || !singleLine:
      string.append("!")
    case 11...20 where i != n - 1 || !singleLine:
      string.append("|")
    case 47:
      string.append("1947")
    default:
      continue
    }
  }

  return string
}


private struct SocialMediaCellContent {
  let name: NSAttributedString
  let timestamp: NSAttributedString
  let text: NSAttributedString
  let truncationToken: NSAttributedString?

  init(_ testCase: TestCase, index: Int) {
    let genText: (_ index: Int, _ singleLine: Bool) -> String
    switch testCase {
    case .socialMediaHindi:
      genText = pseudoHindiText
      truncationToken = nil
    default:
      genText = pseudoChineseText
      truncationToken = NSAttributedString(string: "……")
    }
    name = NSAttributedString(genText(index, true), singleLineAttributes)
    timestamp = NSAttributedString(" · \(index)", singleLineAttributes)
    text = NSAttributedString(genText(index, false), multiLineAttributes)
  }

  var combinedTextForSTULabel: NSAttributedString {
    let string = NSMutableAttributedString(attributedString: name)
    let nameLength = string.length
    string.append(timestamp)
    string.append(NSAttributedString(string: "\n"))
    let firstParaLength = string.length
    string.addAttribute(.paragraphStyle, value: multiLineAttributes[.paragraphStyle]!,
                        range: NSRange(0..<firstParaLength))
    let scope = STUTruncationScope(maximumNumberOfLines: 1, lastLineTruncationMode: .end,
                                   truncationToken: truncationToken,
                                   truncatableStringRange: NSRange(0..<nameLength))
    string.addAttribute(.stuTruncationScope, value: scope, range: NSRange(0..<firstParaLength))
    string.append(text)
    return string
  }

}

private let isAtLeastIOS10 = NSFoundationVersionNumber > 1299
private let isAtLeastIOS11 = NSFoundationVersionNumber > 1399

private let rowCount = isAtLeastIOS11 ? 50000 : 5000

private let cellSeparatorHeight = 1/stu_mainScreenScale();

private func setting<Value: UserDefaultsStorable>(_ id: String, _ defaultValue: Value)
          -> Setting<Value>
{
  return Setting(id: "TableViewPerformance." + id, default: defaultValue)
}


class TableViewPerformanceVC : UITableViewController, UITableViewDataSourcePrefetching,
                               UIPopoverPresentationControllerDelegate, STULabelDelegate
{

  private class TableView : UITableView {

    var cellEdgeInsets: UIEdgeInsets = .zero {
      didSet {
        let newValue = cellEdgeInsets
        if newValue == oldValue { return }
        (delegate as! TableViewPerformanceVC).cellEdgeInsetsDidChangeTo(newValue)
      }
    }

    var cellContentWidth: CGFloat = 0 {
      didSet {
        let newValue = cellContentWidth
        if newValue == oldValue { return }
        print("contentWidth", newValue)
        (delegate as! TableViewPerformanceVC).cellContentWidthDidChangeTo(newValue)
      }
    }

    var autoScrollSpeed: Double = 0 {
      didSet { resetAutoScroll() }
    }
    var autoScrollsDownwards: Bool = true

    override func layoutMarginsDidChange() {
      super.layoutMarginsDidChange()
      let margins = layoutMargins
      cellEdgeInsets = UIEdgeInsets(top: lineSpacing, left: margins.left,
                                    bottom: lineSpacing, right: margins.right)
      let size = self.bounds.size
      cellContentWidth = size.width - margins.left - margins.right
      let contentSize = self.contentSize
      let minOffset = -margins.top
      contentOffsetYRange = minOffset...max(minOffset, contentSize.height - size.height)
    }

    override var frame: CGRect {
      willSet {
        // UITableView sometimes does layout work in setFrame, including delegate calls.
        cellContentWidth = newValue.size.width - cellEdgeInsets.left - cellEdgeInsets.right
      }
      didSet {
        cellContentWidth = frame.size.width - cellEdgeInsets.left - cellEdgeInsets.right
      }
    }

    private var reloadedMiddleCellIndexPathAndYInWindow: (IndexPath, CGFloat)?

    func reloadData(preservingVerticalOffset: Bool) {
      if preservingVerticalOffset {
        // When we switch between Label types the cell heights can change by a pixel. And with
        // estimated cell heights UITableView sometimes moves the cells during a reload even if the
        // cell sizes don't change. We work around these issues by recording the vertical position
        // of a cell before the reload and then correcting the contentOffset during the next call to
        // layoutSubviews().
        layoutIfNeeded()
        if let ips = indexPathsForVisibleRows, !ips.isEmpty,
           case let ip = ips[ips.count/2],
           let cell = cellForRow(at: ip),
           let window = self.window
        {
          let y = window.convert(CGPoint.zero, from:cell).y
          reloadedMiddleCellIndexPathAndYInWindow = (ip, y)
        }
      }
      super.reloadData()
      if !preservingVerticalOffset {
        scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        super.layoutSubviews()
      }
    }

    private var contentOffsetY: CGFloat = 0
    private var contentOffsetYRange: ClosedRange<CGFloat> = 0...0
    private var scrollsDownwards: Bool = true

    override func layoutSubviews() {
      let size = self.bounds.size
      cellContentWidth = size.width - cellEdgeInsets.left - cellEdgeInsets.right
      let contentOffsetYBeforeLayout = self.contentOffset.y
      if contentOffsetYBeforeLayout != contentOffsetY {
        scrollsDownwards = contentOffsetYBeforeLayout > contentOffsetY
                        || contentOffsetYBeforeLayout <= 0
      }
      super.layoutSubviews()
      if let (indexPath, y) = reloadedMiddleCellIndexPathAndYInWindow {
        reloadedMiddleCellIndexPathAndYInWindow = nil
        scrollToRow(at: indexPath, at: .none, animated: false)
        super.layoutSubviews()
        if let cell = cellForRow(at: indexPath),
           let window = self.window
        {
          let y2 = window.convert(CGPoint.zero, from:cell).y
          if y2 != y {
            print("Adjusted table view vertical offset after reload by \(y2 - y)")
            self.contentOffset.y += y2 - y
            super.layoutSubviews()
          }
        }
      }
      contentOffsetY = self.contentOffset.y
      if contentOffsetY != contentOffsetYBeforeLayout {
        // The table view updated its estimate of the contentOffset.
        let delta = contentOffsetY - contentOffsetYBeforeLayout
        autoScrollStartOffset += delta
      }
      contentOffsetYRange = (-cellEdgeInsets.top)...(contentSize.height - size.height)
      if prefetchesOnIOS9 {
        prefetchCellsOnIOS9()
      }
    }

    var prefetchesOnIOS9: Bool = false
    var prefetchRange: CountableRange<Int> = 0..<0

    private var indexPathArray = [IndexPath]()
    private var prefetchedIndexPaths = Set<IndexPath>()

    private func prefetchCellsOnIOS9() {
      if isAtLeastIOS10 { return }

      var minVisibleIndex: Int = .max
      var maxVisibleIndex: Int = .min
      for ip in self.indexPathsForVisibleRows ?? [] {
        let index = ip.row
        minVisibleIndex = min(minVisibleIndex, index)
        maxVisibleIndex = max(maxVisibleIndex, index)
      }
      if maxVisibleIndex <= minVisibleIndex { return }
      let d = maxVisibleIndex - minVisibleIndex + 1

      let delegate = self.delegate as! TableViewPerformanceVC

      var lb = max(0, minVisibleIndex - (scrollsDownwards ? d/2 : d))
      var ub = min(maxVisibleIndex + 1 + (scrollsDownwards ? d : d/2), rowCount)
      if prefetchRange.contains(lb - 1) {
        lb = max(prefetchRange.lowerBound, lb - d)
      }
      if prefetchRange.contains(ub) {
        ub = min(prefetchRange.upperBound, ub + d)
      }
      let newPrefetchRange = lb..<ub

      let r1 = lb ..< minVisibleIndex
      let r2 = (maxVisibleIndex + 1) ..< ub

      let kept = newPrefetchRange.clamped(to: prefetchRange)
      let c1 = prefetchRange.lowerBound..<kept.lowerBound
      let c2 = kept.upperBound..<prefetchRange.upperBound
      indexPathArray.append(contentsOf: c1.lazy.map({ IndexPath(row: $0, section: 0) }))
      indexPathArray.append(contentsOf: c2.lazy.map({ IndexPath(row: $0, section: 0) }))
      if !indexPathArray.isEmpty {
        delegate.tableView(self, cancelPrefetchingForRowsAt: indexPathArray)
        indexPathArray.removeAll(keepingCapacity: true)
      }

      let r1b = prefetchRange.clamped(to: r1)
      let r1a = r1.lowerBound..<r1b.lowerBound
      let r1c = r1b.upperBound..<r1.upperBound

      let r2b = prefetchRange.clamped(to: r2)
      let r2a = r2.lowerBound..<r2b.lowerBound
      let r2c = r2b.upperBound..<r2.upperBound

      if scrollsDownwards {
        indexPathArray.append(contentsOf: r2a.lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r2c.lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r1c.reversed().lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r1a.reversed().lazy.map({ IndexPath(row: $0, section: 0) }))
      } else  {
        indexPathArray.append(contentsOf: r2a.lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r2c.lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r1c.reversed().lazy.map({ IndexPath(row: $0, section: 0) }))
        indexPathArray.append(contentsOf: r1a.reversed().lazy.map({ IndexPath(row: $0, section: 0) }))
      }
      if !indexPathArray.isEmpty {
        delegate.tableView(self, prefetchRowsAt: indexPathArray)
        indexPathArray.removeAll(keepingCapacity: true)
      }
      prefetchRange = newPrefetchRange
    }

    private var displayLink: CADisplayLink?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil {
        if displayLink == nil {
          displayLink = CADisplayLink(target: self, selector: #selector(nextFrame(_:)))
          displayLink!.isPaused = autoScrollSpeed == 0
          displayLink!.add(to: RunLoop.current, forMode: .common)
        }
      } else {
        if displayLink != nil {
          displayLink!.invalidate()
          displayLink = nil
        }
      }
    }

    private var autoScrollStartTime: CFTimeInterval = 0
    private var autoScrollStartOffset: CGFloat = 0

    private func resetAutoScroll() {
      displayLink?.isPaused = autoScrollSpeed == 0
      autoScrollStartTime = 0
      return
    }

    @objc
    private func nextFrame(_ link: CADisplayLink) {
      let timeStamp: TimeInterval
      if #available(iOS 10, *) {
        timeStamp = link.targetTimestamp
      } else {
        timeStamp = link.timestamp
      }
      if autoScrollStartTime == 0 {
        autoScrollStartTime = timeStamp
        layoutIfNeeded()
        var y = contentOffsetY
        if y < contentOffsetYRange.lowerBound { y = contentOffsetYRange.lowerBound }
        else if y > contentOffsetYRange.upperBound { y = contentOffsetYRange.upperBound }
        autoScrollStartOffset = autoScrollsDownwards ? y : 2*contentOffsetYRange.upperBound - y
        return
      }
      let d = Double(contentOffsetYRange.upperBound - contentOffsetYRange.lowerBound)
      var y = (Double(autoScrollStartOffset - contentOffsetYRange.lowerBound)
               + (timeStamp - autoScrollStartTime)*autoScrollSpeed)
              .truncatingRemainder(dividingBy: 2*d)
      autoScrollsDownwards = y <= d
      if !autoScrollsDownwards {
        y = 2*d - y
      }
      y += Double(contentOffsetYRange.lowerBound)
      self.contentOffset = CGPoint(x: 0, y: CGFloat(y))
    }

  }

  private var _tableView: TableView?

  private var ourTableView: TableView {
    if let tv = _tableView { return tv }
    return self.view as! TableView
  }

  override func loadView() {
    let tableView = TableView()
    _tableView = tableView
    self.view = tableView
    tableView.delegate = self
    tableView.dataSource = self
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tableView.cellLayoutMarginsFollowReadableWidth = true
    tableView.rowHeight = UITableView.automaticDimension

    if #available(iOS 11, tvOS 11, *) {}
    else {
      tableView.estimatedRowHeight = 57.5
    }

    for id in ReuseIdentifier.all {
      tableView.register(id.cellType, forCellReuseIdentifier: id.rawValue)
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return rowCount
  }

  override func tableView(_ tableView: UITableView,
                          willSelectRowAt indexPath: IndexPath) -> IndexPath?
  {
    autoScrollSpeed = 0
    return nil
  }

  private var autoScrollSpeed: Double = 0 {
    didSet { ourTableView.autoScrollSpeed = autoScrollSpeed }
  }

  private var autoScrollSpeedBeforeDragging: Double?

  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    if autoScrollSpeed != 0 {
      autoScrollSpeedBeforeDragging = autoScrollSpeed
      autoScrollSpeed = 0
      self.tableView.decelerationRate = UIScrollView.DecelerationRate.fast
    }
  }
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    if let speed = autoScrollSpeedBeforeDragging {
      autoScrollSpeedBeforeDragging = nil
      autoScrollSpeed = speed
      self.tableView.decelerationRate = UIScrollView.DecelerationRate.normal
    }
  }

  override func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>)
  {
    if autoScrollSpeedBeforeDragging != nil {
      ourTableView.autoScrollsDownwards = velocity.y > 0
    }
  }

  private var isScrollingToTop: Bool =  false

  override func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
    autoScrollSpeed = 0
    isScrollingToTop = true
    return true
  }

  override func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
    isScrollingToTop = false
  }

  private let testCaseSetting = setting("testCase", TestCase.emojicalypse)
  private var testCase: TestCase { return testCaseSetting.value }

  private enum LabelViewType : Int, UserDefaultsStorable {
    case stuLabel = 0
    case uiLabel
    case uiTextView
  }

  private let labelViewTypeSetting = setting("labelViewType", LabelViewType.stuLabel)
  private var labelViewType: LabelViewType { return labelViewTypeSetting.value }

  private let usesAutoLayoutSetting = setting("usesAutoLayout", true)
  private var usesAutoLayout: Bool { return usesAutoLayoutSetting.value }

  private let usesPrefetchLayoutSetting = setting("usesPrefetchLayout", true)
  private var usesPrefetchLayout: Bool { return usesPrefetchLayoutSetting.value }

  override func responds(to selector: Selector!) -> Bool {
    if selector == #selector(tableView(_:heightForRowAt:)) {
      return !usesAutoLayout && usesPrefetchLayout
    }
    return super.responds(to: selector)
  }

  private let usesPrefetchRenderingSetting = setting("usesPrefetchRendering", true)
  private var usesPrefetchRendering: Bool { return usesPrefetchRenderingSetting.value }

  override func viewWillTransition(to size: CGSize,
                                   with coordinator: UIViewControllerTransitionCoordinator)
  {
    let bounds = ourTableView.bounds
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    if let ip = ourTableView.indexPathForRow(at: center) {
      coordinator.animate(alongsideTransition: { (context) in
        // UITableView doesn't properly maintain the vertical scroll position on rotations. We can
        // fix the position with the following scrollToRow call, but the rotation animation still
        // won't look good in many situatons.
        self.ourTableView.scrollToRow(at: ip, at: .middle, animated: false)
      }, completion: { _ in
        // After a rotation, UITableView sometimes seems to forget to update the position of a
        // single cell, this seems to fix that issue.
        let tv = self.ourTableView
        tv.layoutIfNeeded()
        for ip in tv.indexPathsForVisibleRows ?? [] {
          tv.cellForRow(at: ip)?.frame = tv.rectForRow(at: ip)
        }
      })
    }
    super.viewWillTransition(to: size, with: coordinator)
  }

  private var cellReloadContextCounter: Int = 0

  private func reloadCells(preservingPositions: Bool) {
    print("\nreloading cells \(labelViewType.rawValue, usesAutoLayout)\n")
    cellReloadContextCounter += 1
    clearPrefetchItems()
    let oldSpeed = autoScrollSpeed
    autoScrollSpeed = 0
    ourTableView.reloadData(preservingVerticalOffset: preservingPositions)
    autoScrollSpeed = oldSpeed
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      self.cellReloadContextCounter -= 1
    }
  }

  private func clearPrefetchItems() {
    prefetchItems = [:]
    heightForRowPrerenderer = nil
    cachedCellHeights = [:]
  }

  private func updatePrefetchSource() {
    clearPrefetchItems()
    let shouldPrefetch = usesPrefetchLayout || usesPrefetchRendering
    if #available(iOS 10, tvOS 10, *) {
      ourTableView.prefetchDataSource = shouldPrefetch ? self : nil
    } else {
      ourTableView.prefetchesOnIOS9 = shouldPrefetch
    }
  }

  private let displaysAsynchronouslySetting = setting("displaysAsynchronously", true)
  private var displaysAsynchronously: Bool { return displaysAsynchronouslySetting.value }

  func label(_ label: STULabel,
               shouldDisplayAsynchronouslyWithProposedValue proposedValue: Bool) -> Bool
  {
    // The prefetching for the scroll to top animation is inadequate.
    let value = proposedValue && displaysAsynchronously && !isScrollingToTop
                && cellReloadContextCounter == 0
    return value
  }

  private var prefetchItems = [Int: AnyObject]()

  private class PrefetchLayoutItem {
    private let prerenderer: STULabelPrerenderer
    private var workItem: DispatchWorkItem?

    init(_ prerenderer: STULabelPrerenderer, startAsyncLayout: Bool) {
      self.prerenderer = prerenderer
      if startAsyncLayout {
        workItem = DispatchWorkItem(qos: .userInitiated, block: { _ = prerenderer.textFrame })
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem!)
      }
    }

    func await() -> STULabelPrerenderer {
      if let workItem = self.workItem {
        workItem.wait()
        self.workItem = nil
      }
      return prerenderer
    }

    func cancel() {
      workItem?.cancel()
    }
  }

  func prerenderer(forIndex index: Int) -> STULabelPrerenderer {
    let prerenderer = STULabelPrerenderer()
    let insets = labelContentInsets
    let negativeMargin = testCase == .emojicalypse ? 0 : insets.left + insets.right
    prerenderer.setWidth(ourTableView.cellContentWidth + negativeMargin, maxHeight: 1000,
                         contentInsets: labelContentInsets)
    prerenderer.textLayoutMode = .textKit
    prerenderer.clipsContentToBounds = true
    prerenderer.maximumNumberOfLines = 0
    prerenderer.backgroundColor = labelBackgroundColor?.cgColor

    let text: NSAttributedString
    switch testCase {
    case .emojicalypse: text = emojiText(index: index)
    case .socialMediaChinese, .socialMediaHindi:
      text = SocialMediaCellContent(testCase, index: index).combinedTextForSTULabel
    }
    prerenderer.attributedText = text

    return prerenderer
  }

  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    guard enteredBackground == 0 else { return }
    for indexPath in indexPaths {
      let index = indexPath.row
      guard prefetchItems[index] == nil else { continue }
      let prerenderer = self.prerenderer(forIndex: index)
      if usesPrefetchRendering {
        prerenderer.renderAsync(on: DispatchQueue.global(qos: .userInitiated))
        prefetchItems[index] = prerenderer
      } else {
        prefetchItems[index] = PrefetchLayoutItem(prerenderer, startAsyncLayout: true)
      }
    }
  }

  func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      if let item = prefetchItems.removeValue(forKey: indexPath.row) {
        if !usesPrefetchRendering {
          (item as! PrefetchLayoutItem).cancel()
        } else {
          // The async render task is cancelled automatically when the last reference to the
          // STULabelPrerenderer is released.
        }
      }
    }
  }

  private var heightForRowPrerenderer: (Int, STULabelPrerenderer)?

  private var cachedCellHeights = [Int: CGFloat]()

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    precondition(usesPrefetchLayout && !usesAutoLayout)
    let index = indexPath.row
    if let height = cachedCellHeights[index] {
      return height
    }
    var sizeThatFits: CGSize = .zero
    if let item = prefetchItems[index] {
      if usesPrefetchRendering  {
        var prerenderer = item as! STULabelPrerenderer
        if !prerenderer.tryGet(sizeThatFits: &sizeThatFits, layoutInfo: nil) {
          // We cancel and replace the existing prerenderer.
          prerenderer = self.prerenderer(forIndex: index)
          prefetchItems[index] = prerenderer
          sizeThatFits = prerenderer.sizeThatFits
          prerenderer.renderAsync(on: DispatchQueue.global(qos: .userInteractive))
        }
      } else {
        sizeThatFits = (item as! PrefetchLayoutItem).await().sizeThatFits
      }
    } else {
      let prerenderer = self.prerenderer(forIndex: index)
      sizeThatFits = prerenderer.sizeThatFits
      heightForRowPrerenderer = (index, prerenderer)
      if usesPrefetchRendering {
        prerenderer.renderAsync(on: DispatchQueue.global(qos: .userInteractive))
      }
    }
    let insets = ourTableView.cellEdgeInsets
    let height = sizeThatFits.height + insets.top + insets.bottom + cellSeparatorHeight
    cachedCellHeights[index] = height
    return height
  }

  private var allCells = NSHashTable<Cell>.weakObjects()

  private var labelBackgroundColor: UIColor? {
    return testCase == .emojicalypse ? greyBackgroundColor : nil
  }

  private var labelContentInsets: UIEdgeInsets {
    let sideInset = testCase == .emojicalypse ? lineSpacing : roundToDisplayScale(lineSpacing/2)
    return UIEdgeInsets(top: lineSpacing, left: sideInset,
                        bottom: lineSpacing, right: sideInset)
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
  {
    let tableView = ourTableView
    let cellEdgeInsets = tableView.cellEdgeInsets
    let index = indexPath.row
    let reuseIdentifier = ReuseIdentifier(testCase, labelViewType,
                                          autoLayout: usesAutoLayout).rawValue
    let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier,
                                             for: indexPath) as! Cell
    allCells.add(cell)
    cell.contentInsets = cellEdgeInsets
    switch labelViewType {
    case .stuLabel:
      let cell = cell as! STULabelCell
      cell.labelDelegate = self
      cell.labelBackgroundColor = labelBackgroundColor
      if usesPrefetchLayout || usesPrefetchRendering {
        var prerenderer: STULabelPrerenderer?
        if let item = prefetchItems.removeValue(forKey: index) {
          prerenderer = usesPrefetchRendering ? item as! STULabelPrerenderer
                      : (item as! PrefetchLayoutItem).await()
        } else if let (index2, prerenderer2) = heightForRowPrerenderer, index == index2 {
          prerenderer = prerenderer2
        }
        if let prerenderer = prerenderer {
          if displaysAsynchronously && !prerenderer.isFrozen {
            prerenderer.renderAsync(on: DispatchQueue.global(qos: .userInteractive))
          }
          cell.setContent(prerenderer)
          return cell
        }
      }
      let labelContentInsets = self.labelContentInsets
      cell.label.contentInsets = labelContentInsets
      let content: NSAttributedString
      switch testCase {
      case .emojicalypse:
        cell.labelNegativeSideMargin = 0
        content = emojiText(index: index)
      case .socialMediaChinese, .socialMediaHindi:
        cell.labelNegativeSideMargin = labelContentInsets.left
        content = SocialMediaCellContent(testCase, index: index).combinedTextForSTULabel
      }
      cell.setContent(content)
    case .uiLabel:
      switch testCase {
      case .emojicalypse:
        let cell = cell as! UILabelCell
        cell.labelBackgroundColor = labelBackgroundColor
        cell.label.contentInsets = labelContentInsets
        cell.setContent(emojiText(index: index))
      case .socialMediaChinese, .socialMediaHindi:
        let cell = cell as! UILabelSocialMediaCell
        cell.setContent(SocialMediaCellContent(testCase, index: index))
      }
    case .uiTextView:
      switch testCase {
      case .emojicalypse:
        let cell = cell as! UITextViewCell
        cell.labelBackgroundColor = labelBackgroundColor
        cell.label.contentInsets = labelContentInsets
        cell.setContent(emojiText(index: index))
      case .socialMediaChinese, .socialMediaHindi:
        let cell = cell as! UITextViewSocialMediaCell
        cell.setContent(SocialMediaCellContent(testCase, index: index))
      }
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    //print(indexPath.row, cell.frame.size.height)
  }

  func cellEdgeInsetsDidChangeTo(_ value: UIEdgeInsets) {
    for cell in allCells.allObjects {
      cell.contentInsets = value
    }
  }

  func cellContentWidthDidChangeTo(_ value: CGFloat) {
    cachedCellHeights = [:]
    prefetchItems = [:]
    heightForRowPrerenderer = nil
  }

  private enum ReuseIdentifier : String {
    case stuLabelCell = "s.m"
    case uiLabelCell = "u.m"
    case uiTextViewCell = "t.m"

    case stuLabelCellAL = "s.a"
    case uiLabelCellAL = "u.a"
    case uiTextViewCellAL = "t.a"

    case uiLabelSocialMediaCell = "u3.m"
    case uiTextViewSocialMediaCell = "t3.m"

    case uiLabelSocialMediaCellAL = "u3.a"
    case uiTextViewSocialMediaCellAL = "t3.a"

    static let all = [stuLabelCell, stuLabelCellAL,
                      uiLabelCell, uiLabelCellAL,
                      uiTextViewCell, uiTextViewCellAL,
                      uiLabelSocialMediaCell, uiLabelSocialMediaCellAL,
                      uiTextViewSocialMediaCell, uiTextViewSocialMediaCellAL]

    init(_ testCase: TestCase, _ labelViewType: LabelViewType, autoLayout: Bool) {
      switch testCase {
      case .emojicalypse:
        switch (labelViewType) {
        case .stuLabel:   self = autoLayout ? .stuLabelCellAL   : .stuLabelCell
        case .uiLabel:    self = autoLayout ? .uiLabelCellAL    : .uiLabelCell
        case .uiTextView: self = autoLayout ? .uiTextViewCellAL : .uiTextViewCell
        }
      case .socialMediaChinese, .socialMediaHindi:
        switch (labelViewType) {
        case .stuLabel:   self = autoLayout ? .stuLabelCellAL   : .stuLabelCell
        case .uiLabel:    self = autoLayout ? .uiLabelSocialMediaCellAL : .uiLabelSocialMediaCell
        case .uiTextView: self = autoLayout ? .uiTextViewSocialMediaCellAL : .uiTextViewSocialMediaCell
        }
      }
    }

    var cellType: UITableViewCell.Type {
      switch self {
      case .stuLabelCell,   .stuLabelCellAL:   return STULabelCell.self
      case .uiLabelCell,    .uiLabelCellAL:    return UILabelCell.self
      case .uiTextViewCell, .uiTextViewCellAL: return UITextViewCell.self
      case .uiLabelSocialMediaCell, .uiLabelSocialMediaCellAL: return UILabelSocialMediaCell.self
      case .uiTextViewSocialMediaCell, .uiTextViewSocialMediaCellAL: return UITextViewSocialMediaCell.self
      }
    }
  }

  private class Cell : UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      precondition(reuseIdentifier != nil)
      let reuseIdentifier = reuseIdentifier!
      let autoLayout = reuseIdentifier.hasSuffix(".a")
      precondition(autoLayout || reuseIdentifier.hasSuffix(".m"))
      usesAutoLayout = autoLayout
      super.init(style: style, reuseIdentifier: reuseIdentifier)
      self.selectionStyle = .none
      self.contentView.preservesSuperviewLayoutMargins = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    let usesAutoLayout: Bool

    var contentInsets: UIEdgeInsets = .zero {
      didSet {
        let newValue = contentInsets
        if newValue == oldValue { return }
        if usesAutoLayout {
          self.contentView.layoutMargins = contentInsets
        } else {
          self.setNeedsLayout()
        }
      }
    }
  }

  private class SimpleLabelCell<Label: UIView & LabelViewWithContentInsets> : Cell {
    fileprivate let label = Label()

    private var labelLeftConstraint: NSLayoutConstraint?
    private var labelRightConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
      label.configureForUseAsLabel()
      label.maximumNumberOfLines = 0
      let contentView = self.contentView
      let contentViewMargin = contentView.layoutMarginsGuide
      self.contentView.addSubview(label)
      if usesAutoLayout {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        labelLeftConstraint = constrain(label, .left, eq, contentViewMargin, .left)
        labelRightConstraint = constrain(label, .right, eq, contentViewMargin, .right)
        if let label = label as? STULabel {
          // The label's width is fully determined by the cell's width, so we don't need the
          // intrinsic width.
          label.hasIntrinsicContentWidth = false
        }
        [labelLeftConstraint!,
         labelRightConstraint!,
         constrain(label, .top,    eq,  contentViewMargin, .top),
         constrain(label, .bottom, eq,  contentViewMargin, .bottom, priority: .defaultHigh)
        ].activate()
      }
    }

    var labelNegativeSideMargin: CGFloat = 0 {
      didSet {
        if labelNegativeSideMargin == oldValue { return }
        clearLabelSizeThatFits()
        if usesAutoLayout {
          labelLeftConstraint!.constant = -labelNegativeSideMargin
          labelRightConstraint!.constant = labelNegativeSideMargin
        } else {
          self.setNeedsLayout()
        }
      }
    }

    var labelBackgroundColor: UIColor? {
      get { return label.backgroundColor }
      set { label.backgroundColor = newValue }
    }

    final func setContent(_ attributedText: NSAttributedString) {
      label.attributedString = attributedText
      clearLabelSizeThatFits()
      if !usesAutoLayout {
        self.setNeedsLayout()
      }
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize,
                           withHorizontalFittingPriority hPriority: UILayoutPriority,
                           verticalFittingPriority vPriority: UILayoutPriority) -> CGSize
    {
      if usesAutoLayout {
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: hPriority,
                                             verticalFittingPriority: vPriority)
      } else {
        let labelSize = labelSizeThatFits(width: targetSize.width
                                                 + 2*labelNegativeSideMargin
                                                 - contentInsets.left - contentInsets.right)
        return CGSize(width: labelSize.width
                             - 2*labelNegativeSideMargin + contentInsets.left + contentInsets.right,
                      height: labelSize.height + contentInsets.top + contentInsets.bottom
                              + cellSeparatorHeight)
      }
    }

    final func clearLabelSizeThatFits() {
      cachedLabelSizeThatFits.width = .infinity
    }

    var cachedLabelSizeThatFits = CGSize(width: CGFloat.infinity, height: 0)
    func labelSizeThatFits(width: CGFloat) -> CGSize {
      if width != cachedLabelSizeThatFits.width {
        let height = label.sizeThatFits(CGSize(width: width, height: 10000)).height
        cachedLabelSizeThatFits = CGSize(width: width, height: height)
      }
      return cachedLabelSizeThatFits
    }

    public override func layoutSubviews() {
      if !usesAutoLayout {
        let width = self.bounds.size.width + 2*labelNegativeSideMargin
                  - contentInsets.left - contentInsets.right
        label.frame = CGRect(origin: CGPoint(x: contentInsets.left - labelNegativeSideMargin,
                                             y: contentInsets.top),
                             size: labelSizeThatFits(width: width))
      }
      super.layoutSubviews()
    }
  }

  private class STULabelCell : SimpleLabelCell<STULabel> {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
      label.textLayoutMode = .textKit
      label.clipsContentToBounds = true
      // We implement shouldDisplayAsynchronouslyWithProposedValue.
      label.displaysAsynchronously = true
    }

    var labelDelegate: STULabelDelegate? {
      get { return label.delegate }
      set { label.delegate = newValue }
    }

    func setContent(_ prerenderer: STULabelPrerenderer) {
      label.configure(with: prerenderer)
      cachedLabelSizeThatFits = label.bounds.size
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize,
                           withHorizontalFittingPriority hPriority: UILayoutPriority,
                           verticalFittingPriority vPriority: UILayoutPriority) -> CGSize
    {
      if usesAutoLayout {
        assert(self.bounds.size.width == targetSize.width)
        layoutIfNeeded()
      }
      let size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: hPriority,
                                               verticalFittingPriority: vPriority)
      return size
    }
  }

  private class UILabelCell : SimpleLabelCell<UILabelWithContentInsets> {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
      label.clipsToBounds = true
      label.expectedLineHeight = lineHeight
      label.expectedLineSpacing = lineSpacing
    }
  }

  private class UITextViewCell : SimpleLabelCell<UITextView> {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
  }

  private class SocialMediaCell<Label: UIView & LabelView> : Cell {
    private let nameLabel = Label()
    private let timestampLabel = Label()
    private let mainTextLabel = Label()

    private let negativeSideMargin: CGFloat

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      let labelIsUITextView = Label.self == UITextView.self
      negativeSideMargin = labelIsUITextView ? roundToDisplayScale(lineSpacing/2) : 0

      super.init(style: style, reuseIdentifier: reuseIdentifier)
      nameLabel.configureForUseAsLabel()
      nameLabel.maximumNumberOfLines = 1
      timestampLabel.configureForUseAsLabel()
      timestampLabel.maximumNumberOfLines = 1
      mainTextLabel.configureForUseAsLabel()
      mainTextLabel.maximumNumberOfLines = 0

      if labelIsUITextView {
        let nameLabel = self.nameLabel as! UITextView
        let timestampLabel = self.timestampLabel as! UITextView
        let mainTextLabel = self.mainTextLabel as! UITextView

        nameLabel.textContainerInset = UIEdgeInsets(top: lineSpacing, left: negativeSideMargin,
                                                    bottom: titleTextViewBottomInset, right: 0)
        timestampLabel.textContainerInset = UIEdgeInsets(top: lineSpacing, left: 0,
                                                         bottom: titleTextViewBottomInset,
                                                         right: negativeSideMargin)
        mainTextLabel.textContainerInset = UIEdgeInsets(top: lineSpacing - titleTextViewBottomInset,
                                                        left: negativeSideMargin,
                                                        bottom: lineSpacing,
                                                        right: negativeSideMargin)
      }

      self.contentView.addSubview(nameLabel)
      self.contentView.addSubview(timestampLabel)
      self.contentView.addSubview(mainTextLabel)
      if usesAutoLayout {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        mainTextLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timestampLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        nameLabel.setContentHuggingPriority(.required, for: .vertical)
        timestampLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        timestampLabel.setContentHuggingPriority(.required, for: .vertical)
        mainTextLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        mainTextLabel.setContentHuggingPriority(.required, for: .vertical)

        let contentMargin = contentView.layoutMarginsGuide

        [constrain(nameLabel,      .leading,  eq,  contentMargin, .leading,
                   plus: -negativeSideMargin),
         constrain(mainTextLabel,  .leading,  eq,  contentMargin, .leading,
                   plus: -negativeSideMargin),

         constrain(nameLabel,      .trailing, eq,  timestampLabel, .leading),

         constrain(timestampLabel, .trailing, leq, contentMargin, .trailing,
                   plus: negativeSideMargin),
         constrain(mainTextLabel,  .trailing, eq,  contentMargin, .trailing,
                   plus: negativeSideMargin),

         constrain(mainTextLabel,  .bottom, eq, contentMargin, .bottom,
                   priority: .defaultHigh)

        ].activate()

        if !labelIsUITextView {
          [constrain(nameLabel, .top, eq, contentMargin, .top, plus: lineSpacing),

           constrain(nameLabel, .firstBaseline, eq, timestampLabel, .firstBaseline),

           constrain(mainTextLabel, .firstBaseline, eq, nameLabel, .firstBaseline,
                     plus: lineHeightIncludingSpacing),
          ].activate()
        } else {
          [constrain(nameLabel, .top, eq, contentMargin, .top),
           constrain(timestampLabel, .top, eq, contentMargin, .top),
           constrain(mainTextLabel, .top, eq, nameLabel, .bottom),
          ].activate()
        }
      }
    }

     public override func systemLayoutSizeFitting(_ targetSize: CGSize,
                           withHorizontalFittingPriority hPriority: UILayoutPriority,
                           verticalFittingPriority vPriority: UILayoutPriority) -> CGSize
    {
      if usesAutoLayout {
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: hPriority,
                                             verticalFittingPriority: vPriority)
      } else {
        let bounds = self.bounds
        if bounds.size.width != targetSize.width {
          self.bounds = CGRect(origin: bounds.origin, size: CGSize(width: targetSize.width,
                                                                   height: bounds.size.height))
        }
        self.layoutIfNeeded()
        let frame = mainTextLabel.frame
        let size = CGSize(width: targetSize.width,
                          height: frame.origin.y + frame.size.height + contentInsets.bottom
                                  + cellSeparatorHeight)
        return size
      }
    }

    func setContent(_ content: SocialMediaCellContent) {
      nameLabel.attributedString = content.name
      timestampLabel.attributedString = content.timestamp
      // UILabel includes the lineSpacing below the last line inconsistently in the
      // intrinsicContentSize, depending on the text content and whether there's more than one line.
      // We work around this issue by appending a zero size line.
      mainTextLabel.attributedString = Label.self != UILabel.self ? content.text
                                     : withLineSpacingAfter(content.text)
      lastLayoutParams = nil
      if !usesAutoLayout {
        self.setNeedsLayout()
      }
    }

    var lastLayoutParams: (CGFloat, UIEdgeInsets)?

    public override func layoutSubviews() {
      if !usesAutoLayout {
        let width = self.bounds.size.width + 2*negativeSideMargin
                    - contentInsets.left - contentInsets.right
        if let lastLayoutParams = lastLayoutParams, lastLayoutParams == (width, contentInsets) {
          super.layoutSubviews()
          return
        }
        lastLayoutParams = (width, contentInsets)
        let timestampSize = timestampLabel.sizeThatFits(CGSize(width: width,
                                                               height: 10000))
        let maxNameWidth = width - timestampSize.width
        var nameSize = nameLabel.sizeThatFits(CGSize(width: maxNameWidth, height: 10000))
        nameSize.width = min(nameSize.width, maxNameWidth)

        var y: CGFloat = contentInsets.top
        let isUILabel = Label.self == UILabel.self
        if isUILabel {
          y += lineSpacing
        }
        let nameLabelFrame = CGRect(origin: CGPoint(x: contentInsets.left - negativeSideMargin,
                                                    y: y),
                                    size: nameSize)
        let timestampFrame = CGRect(origin: CGPoint(x: nameLabelFrame.origin.x + nameSize.width,
                                                    y: y),
                                    size: timestampSize)
        nameLabel.frame = nameLabelFrame
        timestampLabel.frame = timestampFrame
        y += max(nameLabelFrame.size.height, timestampFrame.size.height)
        if isUILabel {
          y += extraSpacingAfterTitleUILabel
        }
        let mainLabelSize = CGSize(width: width,
                                   height: mainTextLabel.sizeThatFits(CGSize(width: width,
                                                                             height: 10000)).height)
        mainTextLabel.frame = CGRect(origin: CGPoint(x: contentInsets.left - negativeSideMargin,
                                                     y: y),
                                     size: mainLabelSize)
      }
      super.layoutSubviews()
    }
  }

  private class UILabelSocialMediaCell : SocialMediaCell<UILabel> {}

  private class UITextViewSocialMediaCell : SocialMediaCell<UITextView> {}

  private class SettingsViewController : UITableViewController {
    var cells: [UITableViewCell]

    private let obs = PropertyObserverContainer()

    init(_ vc: TableViewPerformanceVC) {
      let testCaseCell = SelectCell("Test case", TestCase.allCases.map { ($0.name, $0) },
                                    vc.testCaseSetting)

      let labelTypeCell = SelectCell("Label view",
                                     [("STULabel", LabelViewType.stuLabel),
                                      ("UILabel", LabelViewType.uiLabel),
                                      ("UITextView", LabelViewType.uiTextView)],
                                     vc.labelViewTypeSetting)

      let autoLayoutCell = SwitchCell("Auto Layout", vc.usesAutoLayoutSetting)

      let asyncDisplayCell = SwitchCell("Async display", vc.displaysAsynchronouslySetting)

      let prefetchLayoutCell = SwitchCell("Prefetch layout", vc.usesPrefetchLayoutSetting)
      let prefetchRenderingCell = SwitchCell("Prefetch rendering", vc.usesPrefetchRenderingSetting)


      func updateCellsEnabled() {
        let isSTULabel = vc.labelViewType == .stuLabel
        asyncDisplayCell.isEnabled = isSTULabel
        prefetchLayoutCell.isEnabled = isSTULabel
        prefetchRenderingCell.isEnabled = isSTULabel
      }

      updateCellsEnabled()

      obs.observe(vc.labelViewTypeSetting) { newValue in
        updateCellsEnabled()
      }

      let autoScrollStepperCell = StepperCell("Auto scroll", 0...5000, step: 50,
                                              value: Double(vc.autoScrollSpeed), unit: "pt/s")
      autoScrollStepperCell.onValueChange = { value in vc.autoScrollSpeed = value }

      cells = [testCaseCell,
               labelTypeCell,
               autoLayoutCell,
               asyncDisplayCell,
               prefetchLayoutCell,
               prefetchRenderingCell,
               autoScrollStepperCell]

      super.init(style: .plain)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }


    override func viewDidLoad() {
      self.tableView.alwaysBounceVertical = false
      let footerView = UIView()
      footerView.backgroundColor = .green
      self.tableView.tableFooterView = footerView
      self.tableView.backgroundColor = .gray
    }

    override func viewDidLayoutSubviews() {
      let contentSize = self.tableView.contentSize
      let preferredSize = self.parent!.preferredContentSize
      if contentSize != preferredSize {
        self.parent!.preferredContentSize = contentSize
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


  var enteredBackground: Int = 0

  var notificationObservers = [NSObjectProtocol]()


  override init(style: UITableView.Style) {
    super.init(style: style)

    let notificationCenter = NotificationCenter.default
    let mainQueue = OperationQueue.main;
    notificationObservers.append(
      notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                     object: nil, queue: mainQueue, using:
         { [unowned self] (notification) in self.enteredBackground += 1 }))

    notificationObservers.append(
      notificationCenter.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                     object: nil, queue: mainQueue, using:
         { [unowned self] (notification) in self.enteredBackground -= 1 }))

    testCaseSetting.onChange = { [unowned self] in
      self.ourTableView.contentOffset.y = -self.topLayoutGuide.length
      self.reloadCells(preservingPositions: false)
      self.ourTableView.contentOffset.y = -self.topLayoutGuide.length
    }
    labelViewTypeSetting.onChange = { [unowned self] in
      if self.labelViewType != .stuLabel {
        self.displaysAsynchronouslySetting.value = false
        self.usesPrefetchLayoutSetting.value = false
        self.usesPrefetchRenderingSetting.value = false
      }
      self.ourTableView.layoutIfNeeded()
      self.reloadCells(preservingPositions: true)
    }
    usesAutoLayoutSetting.onChange = { [unowned self] in
      if self.usesPrefetchLayout {
        // Update cached status of respondsTo:#selector(tableView(_:heightForRowAt:))
        self.ourTableView.delegate = self
      }
      self.reloadCells(preservingPositions: true)
    }
    usesPrefetchLayoutSetting.onChange = { [unowned self] in
      self.updatePrefetchSource()
      if !self.usesAutoLayout {
        // Update cached status of respondsTo:#selector(tableView(_:heightForRowAt:))
        self.ourTableView.delegate = self
      }
      if !self.usesPrefetchLayout {
        self.usesPrefetchRenderingSetting.value = false
      }
    }
    usesPrefetchRenderingSetting.onChange = { [unowned self] in
      if self.usesPrefetchRendering {
        self.usesPrefetchLayoutSetting.value = true
      }
      self.updatePrefetchSource()
    }

    self.updatePrefetchSource()

    self.navigationItem.titleView = debugBuildTitleLabel()
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(image:  UIImage(named: "toggle-icon"),
                                                             style: .plain, target: self,
                                                             action: #selector(showSettings))
  }

  deinit {
    for obs in notificationObservers {
      NotificationCenter.default.removeObserver(obs)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    cellReloadContextCounter += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.cellReloadContextCounter -= 1
    }
  }

  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @objc
  func showSettings() {

    //let settingsVC = SettingsViewController()
    let navigationVC = UINavigationController(rootViewController: SettingsViewController(self))
    navigationVC.modalPresentationStyle = .popover
    navigationVC.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
    navigationVC.popoverPresentationController?.delegate = self
    navigationVC.setNavigationBarHidden(true, animated: false)
    self.present(navigationVC, animated: false, completion: nil)
  }
  func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
    return .none
  }

}

