// Copyright 2017–2018 Stephan Tolksdorf

#import "ShapedString.hpp"
#import "TextFrame.hpp"
#import "TextStyleBuffer.hpp"

namespace stu_label {

using CTTypesetter = RemovePointer<CTTypesetterRef>;

class TextFrameLayouter {
public:
  TextFrameLayouter(const ShapedString&, Range<Int32> stringRange,
                    STUDefaultTextAlignment defaultTextAlignment,
                    const STUCancellationFlag* cancellationFlag);

  ~TextFrameLayouter();

  STU_INLINE_T
  bool isCancelled() const { return STUCancellationFlagGetValue(&cancellationFlag_); }

  struct ScaleInfo {
    CGFloat scale;
    Float64 inverseScale;
    Float64 firstParagraphFirstLineOffset;
    STUFirstLineOffsetType firstParagraphFirstLineOffsetType;
    STUBaselineAdjustment baselineAdjustment;
  };

  // Only layoutAndScale and layout check for cancellation while running.
  // After cancellation the TextFrameLayouter can be safely destructed,
  // but no other method may be called.

  void layoutAndScale(CGSize frameSize, const STUTextFrameOptions* __nonnull options);

  void layout(CGSize inverselyScaledFrameSize, ScaleInfo scaleInfo,
              Int maxLineCount, const STUTextFrameOptions* __nonnull options);

  template <STUTextLayoutMode mode>
  static MinLineHeightInfo minLineHeightInfo(const LineHeightParams& params,
                                             const MinFontMetrics& minFontMetrics);

  STUTextLayoutMode layoutMode() const { return layoutMode_; }

  Float64 estimateScaleFactorNeededToFit(Float64 frameHeight, Int maxLineCount) const;

  bool needToJustifyLines() const { return needToJustifyLines_; }

  void justifyLinesWhereNecessary();

  const ScaleInfo& scaleInfo() const { return scaleInfo_; }

  CGSize inverselyScaledFrameSize() const { return inverselyScaledFrameSize_; }

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
    return {stringParas_, paras_.count(), unchecked};
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

  static Float32 intraParagraphBaselineDistanceForLinesLike(const TextFrameLine& line,
                                                            const ShapedString::Paragraph& para);

  LocalFontInfoCache& localFontInfoCache() { return localFontInfoCache_; }

private:
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

  struct InitData {
    const STUCancellationFlag& cancellationFlag;
    CTTypesetter* const typesetter;
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

  const STUCancellationFlag& cancellationFlag_;
  CTTypesetter* const typesetter_;
  const NSAttributedStringRef attributedString_;
  const TextStyleSpan originalStringStyles_;
  const ArrayRef<const FontMetrics> originalStringFontMetrics_;
  const ArrayRef<const TruncationScope> truncationScopes_;
  const ShapedString::Paragraph* stringParas_;
  const Range<Int32> stringRange_;
  TempArray<TextFrameParagraph> paras_;
  TempVector<TextFrameLine> lines_{Capacity{16}};
  ScaleInfo scaleInfo_{.scale = 1, .inverseScale = 1};
  CGSize inverselyScaledFrameSize_{};
  const bool stringRangeIsFullString_;
  STUTextLayoutMode layoutMode_{};
  bool needToJustifyLines_{};
  bool ownsCTLinesAndParagraphTruncationTokens_{true};
  Int32 clippedStringRangeEnd_{};
  Int clippedParagraphCount_{};
  const TextStyle* clippedOriginalStringTerminatorStyle_;
  /// A cached CFLocale instance for hyphenation purposes.
  RC<CFLocale> cachedLocale_;
  CFString* cachedLocaleId_{};
  Float64 lineMaxWidth_;
  Float64 lineHeadIndent_;
  Float64 hyphenationFactor_;
  __nullable __unsafe_unretained
  STULastHyphenationLocationInRangeFinder lastHyphenationLocationInRangeFinder_;
  LocalFontInfoCache localFontInfoCache_;
  TextStyleBuffer tokenStyleBuffer_;
  TempVector<FontMetrics> tokenFontMetrics_;
};

} // namespace stu_label
