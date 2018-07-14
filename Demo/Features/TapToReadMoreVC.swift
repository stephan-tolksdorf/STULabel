// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

enum Link {
  case readMore
  case readLess
}

let linkColor = UITextView().linkTextAttributes[NSAttributedStringKey.foregroundColor.rawValue]
                as! UIColor

let readMoreToken = { () -> NSAttributedString in
  let token = NSMutableAttributedString()
  token.append(NSAttributedString(string: "… "))
  token.append(NSAttributedString(string: "more", attributes: [.link: Link.readMore,
                                                               .foregroundColor: linkColor]))
  return token.copy() as! NSAttributedString
}();

class TapToReadMoreVC : UIViewController, STULabelDelegate {

  let label = STULabel()

  let label2 = STULabel()

  var firstRTLCharStringIndex = 0
  var label2NumberOfLines = 0


  override func loadView() {
    let scrollView = UIScrollView()
    scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.view = scrollView
    scrollView.backgroundColor = UIColor.white
    scrollView.alwaysBounceVertical = false
  }

  override func viewDidLoad() {
    let string = "STULabel makes it easy to implement a “Tap to read more” feature: Just add a truncation token with a .link attribute and then expand the label's size in a `label:link:wasTappedAt:` delegate method. The link text, the link formatting and the active link overlay are all customizable. "

    let string2LTR = "This also works when the truncated line happens to contain right-to-left text:\n"
    let string2RTL = "هذا مجرد نص حشو عربي ممل يجب أن يمتد على أكثر من سطر واحد ويفضل أن يكون أكثر من سطرين ، أو حتى أكثر من ثلاثة أسطر. "

    let font = UIFont.preferredFont(forTextStyle: .body)

    let attributedText = NSMutableAttributedString()
    attributedText.append(NSAttributedString(string: string, attributes: [.font: font]))
    attributedText.append(NSAttributedString(string: "less",
                                             attributes: [.font: font,
                                                          .link: Link.readLess,
                                                          .foregroundColor: linkColor]))

    let attributedText2 = NSMutableAttributedString()
    attributedText2.append(NSAttributedString(string: string2LTR, attributes: [.font: font]))
    firstRTLCharStringIndex = string2LTR.utf16.count
    attributedText2.append(NSAttributedString(string: string2RTL, attributes: [.font: font]))
    attributedText2.append(NSAttributedString(string: "less",
                                              attributes: [.font: font,
                                                           .link: Link.readLess,
                                                           .foregroundColor: linkColor]))
    label.maximumLineCount = 2
    label.attributedText = attributedText
    label.adjustsFontForContentSizeCategory = true
    label.truncationToken = readMoreToken
    label.delegate = self

    let scrollView = self.view!
    let readableContentGuide = scrollView.readableContentGuide

    scrollView.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    [constrain(label, .top,      .equal, readableContentGuide, .top, constant: 15),
     constrain(label, .leading,  .equal, readableContentGuide, .leading),
     constrain(label, .trailing, .lessThanOrEqual, scrollView.readableContentGuide, .trailing),
    ].activate()

    label2.maximumLineCount  = 100
    label2.adjustsFontForContentSizeCategory = true
    label2.defaultTextAlignment = .textStart
    label2.attributedText = attributedText2
    label2.truncationToken = readMoreToken
    label2.delegate = self
    scrollView.addSubview(label2)
    label2.translatesAutoresizingMaskIntoConstraints = false
    [constrain(label2, .top,      .equal, label, .bottom, constant: 15),
     constrain(label2, .leading,  .equal, readableContentGuide, .leading),
     constrain(label2, .trailing, .lessThanOrEqual, scrollView.readableContentGuide, .trailing),
     constrain(label2, .bottom,   .lessThanOrEqual, scrollView, .bottom)
    ].activate()
  }

  override func viewDidLayoutSubviews() {
    label2NumberOfLines = label2.textFrame.index(forUTF16IndexInOriginalString:
                                                   firstRTLCharStringIndex - 1,
                                                 indexInTruncationToken: 0).lineIndex + 2
    if label2.maximumLineCount != 0 {
      label2.maximumLineCount = label2NumberOfLines
    }
  }

  func label(_ label: STULabel, link: STUTextLink, wasTappedAt point: CGPoint) {
    guard let linkValue = link.linkAttribute as? Link
    else {
      fatalError("Link attribute value not supported")
    }
    switch linkValue {
    case .readMore:
      label.maximumLineCount = 0

    case .readLess: ();
      label.maximumLineCount = label === self.label ? 2 : label2NumberOfLines
    }
  }

}
