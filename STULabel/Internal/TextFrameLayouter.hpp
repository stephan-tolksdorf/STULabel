// Copyright 2017–2018 Stephan Tolksdorf

#import "ShapedString.hpp"
#import "TextFrame.hpp"
#import "TextStyleBuffer.hpp"

namespace stu_label {

using CTTypesetter = RemovePointer<CTTypesetterRef>;

struct TextFrameOptions;

class TextFrameLayouter {
public:
  TextFrameLayouter(const ShapedString&, Range<stu::Int32> stringRange,
                    STUDefaultTextAlignment defaultTextAlignment,
                    const STUCancellationFlag* cancellationFlag);

  ~TextFrameLayouter();

  STU_INLINE_T
  bool isCancelled() const { return STUCancellationFlagGetValue(&cancellationFlag_); }

  struct ScaleInfo {
    stu::Float64 inverseScale;
    stu::Float64 firstParagraphFirstLineOffset;
    STUFirstLineOffsetType firstParagraphFirstLineOffsetType;
    STUBaselineAdjustment baselineAdjustment;
    CGFloat scale;
    CGFloat originalDisplayScale;
    Optional<DisplayScale> displayScale; ///< scale*originalDisplayScale
  };

  // Only layoutAndScale and layout check for cancellation while running.
  // After cancellation the TextFrameLayouter can be safely destructed,
  // but no other method may be called.

  void layoutAndScale(Size<stu::Float64> frameSize, const Optional<DisplayScale>& displayScale,
                      const TextFrameOptions& options);

  void layout(Size<stu::Float64> inverselyScaledFrameSize, ScaleInfo scaleInfo,
              stu::Int maxLineCount, const TextFrameOptions& options);

  template <STUTextLayoutMode mode>
  static MinLineHeightInfo minLineHeightInfo(const LineHeightParams& params,
                                             const MinFontMetrics& minFontMetrics);

  STUTextLayoutMode layoutMode() const { return layoutMode_; }

  struct ScaleFactorAndNeedsRealignment {
    stu::Float64 scaleFactor;
    bool needsRealignment;
  };

  ScaleFactorAndNeedsRealignment calculateMaxScaleFactorForCurrentLineBreaks(stu::Float64 maxHeight) const;

  void realignCenteredAndRightAlignedLines();

  struct ScaleFactorEstimate {
    stu::Float64 value;
    bool isAccurate;
  };

  /// Usually returns an exact value or a lower bound that is quite close to the exact value.
  /// Paragraphs with varying line heights affect the accuracy negatively.
  /// Hyphenation opportunities are currently ignored, so the estimate can be farther off if the
  /// text involves multiline paragraphs with hyphenation factors greater 0.
  ///
  /// @param accuracy The desired absolute accuracy of the returned estimate.
  ScaleFactorEstimate estimateScaleFactorNeededToFit(stu::Float64 frameHeight, stu::Int32 maxLineCount,
                                                     NSAttributedString* attributedString,
                                                     stu::Float64 minScale, stu::Float64 accuracy) const;

  bool needToJustifyLines() const { return needToJustifyLines_; }

  void justifyLinesWhereNecessary();

  const ScaleInfo& scaleInfo() const { return scaleInfo_; }

  Size<stu::Float64> inverselyScaledFrameSize() const { return inverselyScaledFrameSize_; }

  /// Is reset to 0 at the beginning of layoutAndScale.
  stu::UInt32 layoutCallCount() const { return layoutCallCount_; }

  stu::Float32 minimalSpacingBelowLastLine() const { return minimalSpacingBelowLastLine_; }

  const NSAttributedStringRef& attributedString() const {
    return attributedString_;
  }

  Range<stu::Int32> rangeInOriginalString() const {
    return {stringRange_.start, clippedStringRangeEnd_};
  }

  bool rangeInOriginalStringIsFullString() const {
    return stringRangeIsFullString_ && !textIsClipped();
  }

  bool textIsClipped() const {
    return stringRange_.end != clippedStringRangeEnd_;
  }

  STU_INLINE
  ArrayRef<const ShapedString::Paragraph> originalStringParagraphs() const {
    return stringParas();
  }

  ArrayRef<const TextFrameParagraph> paragraphs() const {
    return {paras_.begin(), clippedParagraphCount_, unchecked};
  }

  ArrayRef<const TextFrameLine> lines() const { return lines_; }

  stu::Int32 truncatedStringLength() const {
    return paras_.isEmpty() ? 0 : paras_[$ - 1].rangeInTruncatedString.end;
  }

  ArrayRef<const FontRef> fonts() const { return tokenStyleBuffer_.fonts(); }

  ArrayRef<const ColorRef> colors() const { return tokenStyleBuffer_.colors(); }

  TextStyleSpan originalStringStyles() const {
    return {originalStringStyles_.firstStyle, clippedOriginalStringTerminatorStyle_};
  }

  ArrayRef<const Byte> truncationTokenTextStyleData() const { return tokenStyleBuffer_.data(); }

  void relinquishOwnershipOfCTLinesAndParagraphTruncationTokens() {
    ownsCTLinesAndParagraphTruncationTokens_ = false;
  }

  LocalFontInfoCache& localFontInfoCache() { return localFontInfoCache_; }

  STU_INLINE
  static stu::Float32 extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                   const STUTextFrameLine& line, stu::Float32 minBaselineDistance)
  {
    return max(0.f,
               (minBaselineDistance - (line._heightAboveBaseline + line._heightBelowBaseline))/2);
  }


private:
  struct Indentations {
    stu::Float64 left;
    stu::Float64 right;
    stu::Float64 head;

    Indentations(const ShapedString::Paragraph spara,
                 const STUTextFrameParagraph& para,
                 stu::Int32 lineIndex,
                 const TextFrameLayouter::ScaleInfo& scaleInfo)
    : Indentations{spara, lineIndex < para.initialLinesEndIndex, scaleInfo}
    {}

    Indentations(const ShapedString::Paragraph& para,
                 bool isInitialLine,
                 const TextFrameLayouter::ScaleInfo& scaleInfo)
    {
      if (STU_LIKELY(!para.isIndented)) {
        this->left = 0;
        this->right = 0;
        this->head = 0;
        return;
      }
      stu::Float64 leftIndent = para.commonLeftIndent;
      stu::Float64 rightIndent = para.commonRightIndent;
      leftIndent *= scaleInfo.inverseScale;
      rightIndent *= scaleInfo.inverseScale;
      if (isInitialLine) {
        leftIndent  += max(0.f, para.initialExtraLeftIndent);
        rightIndent += max(0.f, para.initialExtraRightIndent);
      } else {
        leftIndent  -= min(0.f, para.initialExtraLeftIndent);
        rightIndent -= min(0.f, para.initialExtraRightIndent);
      }
      this->left = leftIndent;
      this->right = rightIndent;
      this->head = para.baseWritingDirection == STUWritingDirectionLeftToRight
                 ? leftIndent : rightIndent;
    }
  };

  struct MaxWidthAndHeadIndent {
    stu::Float64 maxWidth;
    stu::Float64 headIndent;
  };
  struct Hyphen : Parameter<Hyphen, stu::Char32> { using Parameter::Parameter; };
  struct TrailingWhitespaceStringLength : Parameter<TrailingWhitespaceStringLength, stu::Int> {
    using Parameter::Parameter;
  };

  void breakLine(TextFrameLine& line, stu::Int paraStringEndIndex);

  struct BreakLineAtStatus {
    bool success;
    stu::Float64 ctLineWidthWithoutHyphen;
  };

  BreakLineAtStatus breakLineAt(TextFrameLine& line, stu::Int stringIndex, Hyphen hyphen,
                                TrailingWhitespaceStringLength) const;

  bool hyphenateLineInRange(TextFrameLine& line, Range<stu::Int> stringRange);

  void truncateLine(TextFrameLine& line, stu::Int32 stringEndIndex, Range<stu::Int32> truncatableRange,
                    CTLineTruncationType, NSAttributedString* __nullable token,
                    __nullable STUTruncationRangeAdjuster,
                    STUTextFrameParagraph& para, TextStyleBuffer& tokenStyleBuffer) const;

  void justifyLine(STUTextFrameLine& line) const;

  const TextStyle* initializeTypographicMetricsOfLine(TextFrameLine& line);

  const TextStyle* firstOriginalStringStyle(const STUTextFrameLine& line) const {
    return reinterpret_cast<const TextStyle*>(originalStringStyles_.dataBegin()
                                              + line._textStylesOffset);
  }
  const TextStyle* __nullable firstTruncationTokenStyle(const STUTextFrameLine& line) const {
    STU_DEBUG_ASSERT(line._initStep != 1);
    if (!line.hasTruncationToken) return nullptr;
    return reinterpret_cast<const TextStyle*>(tokenStyleBuffer_.data().begin()
                                              + line._tokenStylesOffset);
  }

  bool lastLineFitsFrameHeight() const;

  static void addAttributesNotYetPresentInAttributedString(
                NSMutableAttributedString*, NSRange, NSDictionary<NSAttributedStringKey, id>*);

  stu::Float64 estimateTailTruncationTokenWidth(const TextFrameLine& line, NSAttributedString*) const;

  class SavedLayout {
    friend TextFrameLayouter;
    
    struct Data {
      stu::UInt size;
      ArrayRef<TextFrameParagraph> paragraphs;
      ArrayRef<TextFrameLine> lines;
      ArrayRef<Byte> tokenStyleData;
      ScaleInfo scaleInfo;
      Size<stu::Float64> inverselyScaledFrameSize;
      bool needToJustifyLines;
      bool mayExceedMaxWidth;
      stu::Int32 clippedStringRangeEnd;
      stu::Int clippedParagraphCount;
      const TextStyle* clippedOriginalStringTerminatorStyle;
    };

    Data* data_{};

  public:
    SavedLayout() = default;

    ~SavedLayout() { if (data_) clear(); }
    
    SavedLayout(const SavedLayout&) = delete;
    SavedLayout& operator=(const SavedLayout&) = delete;

    void clear();
  };

  void destroyLinesAndParagraphs();

  void saveLayoutTo(SavedLayout&);
  void restoreLayoutFrom(SavedLayout&&);

  struct InitData {
    const STUCancellationFlag& cancellationFlag;
    CTTypesetter* const typesetter;
    TempStringBuffer tempStringBuffer;
    NSAttributedStringRef attributedString;
    Range<stu::Int> stringRange;
    ArrayRef<const TruncationScope> truncationScopes;
    ArrayRef<const ShapedString::Paragraph> stringParas;
    TempArray<TextFrameParagraph> paras;
    TextStyleSpan stringStyles;
    ArrayRef<const FontMetrics> stringFontMetrics;
    ArrayRef<const ColorRef> stringColorInfos;
    ArrayRef<const TextStyleBuffer::ColorHashBucket> stringColorHashBuckets;
    bool stringRangeIsFullString;

    static InitData create(const ShapedString&, Range<stu::Int32> stringRange,
                           STUDefaultTextAlignment defaultTextAlignment,
                           Optional<const STUCancellationFlag&> cancellationFlag);
  };
  explicit TextFrameLayouter(InitData init);

  /// An abbreviation for originalStringParagraphs().
  STU_INLINE
  ArrayRef<const ShapedString::Paragraph> stringParas() const {
    return {stringParasPtr_, paras_.count(), unchecked};
  }

  const TempStringBuffer tempStringBuffer_;
  const STUCancellationFlag& cancellationFlag_;
  CTTypesetter* const typesetter_;
  const NSAttributedStringRef attributedString_;
  const TextStyleSpan originalStringStyles_;
  const ArrayRef<const FontMetrics> originalStringFontMetrics_;
  const ArrayRef<const TruncationScope> truncationScopes_;
  const ShapedString::Paragraph* stringParasPtr_;
  const Range<stu::Int32> stringRange_;
  TempArray<TextFrameParagraph> paras_;
  TempVector<TextFrameLine> lines_{Capacity{16}};
  ScaleInfo scaleInfo_{.scale = 1, .inverseScale = 1};
  Size<stu::Float64> inverselyScaledFrameSize_{};
  const bool stringRangeIsFullString_;
  STUTextLayoutMode layoutMode_{};
  bool needToJustifyLines_{};
  bool mayExceedMaxWidth_{};
  bool ownsCTLinesAndParagraphTruncationTokens_{true};
  stu::UInt32 layoutCallCount_{};
  stu::Int32 clippedStringRangeEnd_{};
  stu::Float32 minimalSpacingBelowLastLine_{};
  stu::Int clippedParagraphCount_{};
  const TextStyle* clippedOriginalStringTerminatorStyle_;
  /// A cached CFLocale instance for hyphenation purposes.
  RC<CFLocale> cachedLocale_;
  CFString* cachedLocaleId_{};
  stu::Float64 lineMaxWidth_;
  stu::Float64 lineHeadIndent_;
  stu::Float64 hyphenationFactor_;
  STULastHyphenationLocationInRangeFinder __nullable __unsafe_unretained
    lastHyphenationLocationInRangeFinder_;
  LocalFontInfoCache localFontInfoCache_;
  TextStyleBuffer tokenStyleBuffer_;
  TempVector<FontMetrics> tokenFontMetrics_;
};

} // namespace stu_label
