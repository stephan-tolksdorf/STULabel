// Copyright 2017–2018 Stephan Tolksdorf

#import "ShapedString.hpp"
#import "TextFrame.hpp"
#import "TextStyleBuffer.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

using CTTypesetter = RemovePointer<CTTypesetterRef>;

struct TextFrameOptions;

class TextFrameLayouter {
public:
  TextFrameLayouter(const ShapedString&, Range<Int32> stringRange,
                    STUDefaultTextAlignment defaultTextAlignment,
                    const STUCancellationFlag* cancellationFlag);

  ~TextFrameLayouter();

  STU_INLINE_T
  bool isCancelled() const { return STUCancellationFlagGetValue(&cancellationFlag_); }

  struct ScaleInfo {
    Float64 inverseScale;
    Float64 firstParagraphFirstLineOffset;
    STUFirstLineOffsetType firstParagraphFirstLineOffsetType;
    STUBaselineAdjustment baselineAdjustment;
    CGFloat scale;
    CGFloat originalDisplayScale;
    Optional<DisplayScale> displayScale; ///< scale*originalDisplayScale
  };

  // Only layoutAndScale and layout check for cancellation while running.
  // After cancellation the TextFrameLayouter can be safely destructed,
  // but no other method may be called.

  void layoutAndScale(Size<Float64> frameSize, const Optional<DisplayScale>& displayScale,
                      const TextFrameOptions& options);

  void layout(Size<Float64> inverselyScaledFrameSize, ScaleInfo scaleInfo,
              Int maxLineCount, const TextFrameOptions& options);

  template <STUTextLayoutMode mode>
  static MinLineHeightInfo minLineHeightInfo(const LineHeightParams& params,
                                             const MinFontMetrics& minFontMetrics);

  STUTextLayoutMode layoutMode() const { return layoutMode_; }

  struct ScaleFactorAndNeedsRealignment {
    Float64 scaleFactor;
    bool needsRealignment;
  };

  ScaleFactorAndNeedsRealignment calculateMaxScaleFactorForCurrentLineBreaks(Float64 maxHeight) const;

  void realignCenteredAndRightAlignedLines();

  struct ScaleFactorEstimate {
    Float64 value;
    bool isAccurate;
  };

  /// Usually returns an exact value or a lower bound that is quite close to the exact value.
  /// Paragraphs with varying line heights affect the accuracy negatively.
  /// Hyphenation opportunities are currently ignored, so the estimate can be farther off if the
  /// text involves multiline paragraphs with hyphenation factors greater 0.
  ///
  /// @param accuracy The desired absolute accuracy of the returned estimate.
  ScaleFactorEstimate estimateScaleFactorNeededToFit(Float64 frameHeight, Int32 maxLineCount,
                                                     NSAttributedString* attributedString,
                                                     Float64 minScale, Float64 accuracy) const;

  bool needToJustifyLines() const { return needToJustifyLines_; }

  void justifyLinesWhereNecessary();

  const ScaleInfo& scaleInfo() const { return scaleInfo_; }

  Size<Float64> inverselyScaledFrameSize() const { return inverselyScaledFrameSize_; }

  /// Is reset to 0 at the beginning of layoutAndScale.
  UInt32 layoutCallCount() const { return layoutCallCount_; }

  Float32 minimalSpacingBelowLastLine() const { return minimalSpacingBelowLastLine_; }

  const NSAttributedStringRef& attributedString() const {
    return attributedString_;
  }

  Range<Int32> rangeInOriginalString() const {
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

  Int32 truncatedStringLength() const {
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
  static Float32 extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                   const STUTextFrameLine& line, Float32 minBaselineDistance)
  {
    return max(0.f,
               (minBaselineDistance - (line._heightAboveBaseline + line._heightBelowBaseline))/2);
  }


private:
  struct Indentations {
    Float64 left;
    Float64 right;
    Float64 head;

    Indentations(const ShapedString::Paragraph spara,
                 const STUTextFrameParagraph& para,
                 Int32 lineIndex,
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
      Float64 leftIndent = para.commonLeftIndent;
      Float64 rightIndent = para.commonRightIndent;
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
    Float64 maxWidth;
    Float64 headIndent;
  };
  struct Hyphen : Parameter<Hyphen, Char32> { using Parameter::Parameter; };
  struct TrailingWhitespaceStringLength : Parameter<TrailingWhitespaceStringLength, Int> {
    using Parameter::Parameter;
  };

  void breakLine(TextFrameLine& line, Int paraStringEndIndex);

  struct BreakLineAtStatus {
    bool success;
    Float64 ctLineWidthWithoutHyphen;
  };

  BreakLineAtStatus breakLineAt(TextFrameLine& line, Int stringIndex, Hyphen hyphen,
                                TrailingWhitespaceStringLength) const;

  bool hyphenateLineInRange(TextFrameLine& line, Range<Int> stringRange);

  void truncateLine(TextFrameLine& line, Int32 stringEndIndex, Range<Int32> truncatableRange,
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

  Float64 estimateTailTruncationTokenWidth(const TextFrameLine& line, NSAttributedString*) const;

  class SavedLayout {
    friend TextFrameLayouter;
    
    struct Data {
      UInt size;
      ArrayRef<TextFrameParagraph> paragraphs;
      ArrayRef<TextFrameLine> lines;
      ArrayRef<Byte> tokenStyleData;
      ScaleInfo scaleInfo;
      Size<Float64> inverselyScaledFrameSize;
      bool needToJustifyLines;
      bool mayExceedMaxWidth;
      Int32 clippedStringRangeEnd;
      Int clippedParagraphCount;
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
    Range<Int> stringRange;
    ArrayRef<const TruncationScope> truncationScopes;
    ArrayRef<const ShapedString::Paragraph> stringParas;
    TempArray<TextFrameParagraph> paras;
    TextStyleSpan stringStyles;
    ArrayRef<const FontMetrics> stringFontMetrics;
    ArrayRef<const ColorRef> stringColorInfos;
    ArrayRef<const TextStyleBuffer::ColorHashBucket> stringColorHashBuckets;
    bool stringRangeIsFullString;

    static InitData create(const ShapedString&, Range<Int32> stringRange,
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
  const Range<Int32> stringRange_;
  TempArray<TextFrameParagraph> paras_;
  TempVector<TextFrameLine> lines_{Capacity{16}};
  ScaleInfo scaleInfo_{.scale = 1, .inverseScale = 1};
  Size<Float64> inverselyScaledFrameSize_{};
  const bool stringRangeIsFullString_;
  STUTextLayoutMode layoutMode_{};
  bool needToJustifyLines_{};
  bool mayExceedMaxWidth_{};
  bool ownsCTLinesAndParagraphTruncationTokens_{true};
  UInt32 layoutCallCount_{};
  Int32 clippedStringRangeEnd_{};
  Float32 minimalSpacingBelowLastLine_{};
  Int clippedParagraphCount_{};
  const TextStyle* clippedOriginalStringTerminatorStyle_;
  /// A cached CFLocale instance for hyphenation purposes.
  RC<CFLocale> cachedLocale_;
  CFString* cachedLocaleId_{};
  Float64 lineMaxWidth_;
  Float64 lineHeadIndent_;
  Float64 hyphenationFactor_;
  STULastHyphenationLocationInRangeFinder __nullable __unsafe_unretained
    lastHyphenationLocationInRangeFinder_;
  LocalFontInfoCache localFontInfoCache_;
  TextStyleBuffer tokenStyleBuffer_;
  TempVector<FontMetrics> tokenFontMetrics_;
};

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
