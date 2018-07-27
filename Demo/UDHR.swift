// Copyright 2018 Stephan Tolksdorf

import STULabelSwift

let udhr = UDHR()

class UDHR {
  let translations: [Translation]
  let translationsByLanguageCode: [String: Translation]

  class Translation {
    struct Article {
      let title: String
      let paragraphs: [String]
    }

    let language: String
    let languageCode: String
    let writingDirection: STUWritingDirection
    let title: String
    let articles: [Article] // Includes preamble.

    init(language: String, languageCode: String, writingDirection: STUWritingDirection,
         title: String, articles: [Article])
    {
      self.language = language
      self.languageCode = languageCode
      self.writingDirection = writingDirection
      self.title = title
      self.articles = articles
    }

    func asAttributedString(titleAttributes: [NSAttributedString.Key: Any],
                            bodyAttributes: [NSAttributedString.Key: Any],
                            paragraphSeparator nl: String = "\n")
      -> NSAttributedString
    {
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.baseWritingDirection = self.writingDirection == .leftToRight
                                     ? .leftToRight : .rightToLeft
      var titleAttributes = titleAttributes
      var bodyAttributes = bodyAttributes
      titleAttributes[.paragraphStyle] = paraStyle
      bodyAttributes[.paragraphStyle] = paraStyle
      titleAttributes[kCTLanguageAttributeName as NSAttributedString.Key] = languageCode
      bodyAttributes[kCTLanguageAttributeName as NSAttributedString.Key] = languageCode

      let str = NSMutableAttributedString()

      str.append(NSAttributedString(self.title + nl, titleAttributes))
      for article in self.articles {
        str.append(NSAttributedString(nl + article.title + nl, titleAttributes))
        for paragraph in article.paragraphs {
          str.append(NSAttributedString(paragraph + nl, bodyAttributes))
        }
      }

      return str.copy() as! NSAttributedString
    }
  }

  fileprivate init() {
    let url = Bundle(for: type(of: self)).url(forResource: "udhr", withExtension: "html")!
    let parser = XMLParser(contentsOf: url)!
    let delegate = ParserDelegate()
    parser.delegate = delegate
    let success = parser.parse()
    assert(success)
    translations = delegate.translations
    translationsByLanguageCode = Dictionary(uniqueKeysWithValues:
                                              translations.map({ ($0.languageCode, $0) }))
  }

  private class ParserDelegate : NSObject, XMLParserDelegate {

    var currentString = String()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attribs: [String : String] = [:])
    {
      switch elementName {
      case "h2": break
      case "div":
        let languageCode = attribs["lang"]!
        let dir = attribs["dir"]
        startTranslationBody(languageCode: languageCode, dir == "rtl" ? .rightToLeft : .leftToRight)
      case "h3": break
      case "h4": startArticleTitle()
      case "p": break
      default: return
      }
      currentString = ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?)
    {
      switch elementName {
      case "h2": endTranslationLanguage()
      case "div" where currentLanguage != nil:
        endTranslationBody()
      case "h3" where currentLanguage != nil:
        endTitle()
      case "h4" where currentLanguage != nil:
        endArticleTitle()
      case "p" where currentArticleTitle != nil:
        endArticleParagraph()
      default: return
      }
    }

    var translations = [Translation]()

    var currentLanguage: String?
    var currentLanguageCode: String?
    var currentWritingDirection: STUWritingDirection?
    var currentTitle: String?
    var currentArticles = [Translation.Article]()

    var currentArticleTitle: String?
    var currentArticleParagraphs = [String]()

    private func endTranslationLanguage() {
      currentLanguage = currentString
    }

    private func startTranslationBody(languageCode: String, _ dir: STUWritingDirection) {
      currentLanguageCode = languageCode
      currentWritingDirection = dir
    }

    private func endTranslationBody() {
      if currentArticleTitle != nil {
        currentArticles.append(Translation.Article(title: currentArticleTitle!,
                                                   paragraphs: currentArticleParagraphs))
        currentArticleTitle = nil
        currentArticleParagraphs = []
      }
      guard !currentArticles.isEmpty
      else {
        print("Ignored empty \(currentLanguage!) translation")
        return
      }
      translations.append(Translation(language: currentLanguage!,
                                      languageCode: currentLanguageCode!,
                                      writingDirection: currentWritingDirection!,
                                      title: currentTitle!,
                                      articles: currentArticles))
      currentLanguage = nil
      currentLanguageCode = nil
      currentWritingDirection  = nil
      currentTitle = nil
      currentArticles = []
    }

    private func endTitle() {
      assert(currentTitle == nil)
      currentTitle = currentString
    }

    private func startArticleTitle() {
      if currentArticleTitle == nil { return }
      currentArticles.append(Translation.Article(title: currentArticleTitle!,
                                                 paragraphs: currentArticleParagraphs))
      currentArticleTitle = nil
      currentArticleParagraphs = []
    }

    private func endArticleTitle() {
      assert(currentArticleTitle == nil)
      currentArticleTitle = currentString
    }

    private func endArticleParagraph() {
      currentArticleParagraphs.append(currentString)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
      currentString += string
    }
  }
}
