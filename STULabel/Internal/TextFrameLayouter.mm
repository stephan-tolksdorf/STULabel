// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrameLayouter.hpp"

#import "STULabel/STUTextAttachment-Internal.hpp"
#import "STULabel/STUTextFrameOptions-Internal.hpp"

#import "CoreGraphicsUtils.hpp"
#import "InputClamping.hpp"

namespace stu_label {

static STUParagraphAlignment paragraphAlignment(NSTextAlignment alignment,
                                                STUWritingDirection writingDirection,
                                                STUDefaultTextAlignment defaultTextAlignment)
{
  switch (alignment) {
  case NSTextAlignmentLeft:
  case NSTextAlignmentRight:
    static_assert((int)NSTextAlignmentLeft == (int)STUParagraphAlignmentLeft);
    static_assert((int)NSTextAlignmentRight == (int)STUParagraphAlignmentRight);
    return STUParagraphAlignment(alignment);
  case NSTextAlignmentCenter:
    return STUParagraphAlignmentCenter;
  case NSTextAlignmentNatural:
  case NSTextAlignmentJustified:
    STUParagraphAlignment result;
    switch (defaultTextAlignment) {
    case STUDefaultTextAlignmentLeft:
    case STUDefaultTextAlignmentRight:
      static_assert(((int)STUDefaultTextAlignmentLeft << 1) == (int)STUParagraphAlignmentLeft);
      static_assert(((int)STUDefaultTextAlignmentRight << 1) == (int)STUParagraphAlignmentRight);
      result = STUParagraphAlignment(defaultTextAlignment << 1);
      break;
    case STUDefaultTextAlignmentStart:
      result = writingDirection == STUWritingDirectionLeftToRight
             ? STUParagraphAlignmentLeft : STUParagraphAlignmentRight;
      break;
    case STUDefaultTextAlignmentEnd:
      result = writingDirection != STUWritingDirectionLeftToRight
             ? STUParagraphAlignmentLeft : STUParagraphAlignmentRight;
      break;
    }
    static_assert(((int)STUParagraphAlignmentLeft | 1) == (int)STUParagraphAlignmentJustifiedLeft);
    static_assert(((int)STUParagraphAlignmentRight | 1) == (int)STUParagraphAlignmentJustifiedRight);
    return STUParagraphAlignment(result | (alignment == NSTextAlignmentJustified));
  }
}

TextFrameLayouter::TextFrameLayouter(const ShapedString& shapedString,
                                     Range<Int32> stringRange,
                                     STUDefaultTextAlignment defaultTextAlignment,
                                     const STUCancellationFlag* cancellationFlag)
: TextFrameLayouter{InitData::create(shapedString, stringRange, defaultTextAlignment,
                                     cancellationFlag)} {}

auto TextFrameLayouter::InitData::create(const ShapedString& shapedString, Range<Int32> stringRange,
                                         const STUDefaultTextAlignment defaultTextAlignment,
                                         Optional<const STUCancellationFlag&> cancellationFlag)
  -> InitData
{
  const ShapedString::ArraysRef sas = shapedString.arrays();
  const Int32 stringLength = shapedString.stringLength;

  STU_DEBUG_ASSERT(0 <= stringRange.start
                   && stringRange.start <= stringRange.end && stringRange.end <= stringLength);

  const ShapedString::Paragraph* stringParasBegin;
  if (STU_UNLIKELY(stringRange.start == stringLength)) {
    stringParasBegin = sas.paragraphs.end();
  } else {
    stringParasBegin = sas.paragraphs.begin();
    while (stringParasBegin->stringRange.end <= stringRange.start) {
      ++stringParasBegin;
    }
  }
  const ShapedString::Paragraph* stringParasEnd;
  if (STU_UNLIKELY(stringRange.end == stringLength)) {
    stringParasEnd = sas.paragraphs.end();
  } else {
    stringParasEnd = stringParasBegin;
    while (stringParasEnd->stringRange.end < stringRange.end) {
      ++stringParasEnd;
    }
    ++stringParasEnd;
  }
  const ArrayRef<const ShapedString::Paragraph> stringParas{stringParasBegin, stringParasEnd,
                                                            unchecked};
  TempArray<TextFrameParagraph> paras{uninitialized, Count{stringParas.count()}};
  {
    Int32 i = 0;
    for (TextFrameParagraph& para : paras) {
      const ShapedString::Paragraph& p = stringParas[i];
      new (&para) TextFrameParagraph{{
                    .alignment = paragraphAlignment(p.alignment, p.baseWritingDirection,
                                                    defaultTextAlignment),
                    .rangeInOriginalString = p.stringRange,
                    .excisedRangeInOriginalString = {p.stringRange.end, p.stringRange.end},
                    .paragraphIndex = i,
                    .paragraphTerminatorInOriginalStringLength = narrow_cast<UInt8>(
                                                                   p.terminatorStringLength),
                    .baseWritingDirection = p.baseWritingDirection,
                  }};
      ++i;
    }
  }

  if (!paras.isEmpty()) {
    paras[0].rangeInOriginalString.start = stringRange.start;
    paras[0].isFirstParagraph = true;
    paras[$ - 1].rangeInOriginalString.end = stringRange.end;
    paras[$ - 1].paragraphTerminatorInOriginalStringLength =
      narrow_cast<UInt8>(max(0, stringRange.end - (  stringParas[$ - 1].stringRange.end
                                                   - stringParas[$ - 1].terminatorStringLength)));
    paras[$ - 1].isLastParagraph = true;
  }

  TextStyleSpan styles;
  const bool isFullString = stringRange.start == 0 && stringRange.end == stringLength;
  if (isFullString) {
    styles = sas.textStyles;
  } else {
    const ShapedString::Paragraph& firstPara = stringParas[0];
    styles.firstStyle = reinterpret_cast<const TextStyle*>(
                          sas.textStyles.dataBegin() + firstPara.textStylesOffset);
    STU_DEBUG_ASSERT(styles.firstStyle->stringIndex() <= stringRange.start);
    if (stringRange.start > firstPara.stringRange.start) {
      styles.firstStyle = &styles.firstStyle->styleForStringIndex(stringRange.start);
    }

    if (stringParas.end() < sas.paragraphs.end()) {
      styles.terminatorStyle = reinterpret_cast<const TextStyle*>(
                                 sas.textStyles.dataBegin() + stringParas.end()->textStylesOffset);
    } else {
      styles.terminatorStyle = sas.textStyles.terminatorStyle;
    }
    STU_DEBUG_ASSERT(styles.terminatorStyle->stringIndex() >= stringRange.end);
    if (stringRange.end < styles.terminatorStyle->stringIndex()) {
      do styles.terminatorStyle = &styles.terminatorStyle->previous();
      while (stringRange.end < styles.terminatorStyle->stringIndex());
      if (stringRange.end > styles.terminatorStyle->stringIndex()) {
        styles.terminatorStyle = &styles.terminatorStyle->next();
      }
    }
  }

  return {.cancellationFlag = *(cancellationFlag ?: &CancellationFlag::neverCancelledFlag),
          .typesetter = shapedString.typesetter.get(),
          .attributedString = NSAttributedStringRef{shapedString.attributedString},
          .stringRange = stringRange,
          .truncationScopes = sas.truncationSopes,
          .stringParas = stringParas,
          .paras = std::move(paras),
          .stringStyles = styles,
          .stringFontMetrics = sas.fontMetrics,
          .stringColorInfos = sas.colors,
          .stringColorHashBuckets = sas.colorHashBuckets,
          .stringRangeIsFullString = isFullString};
}

TextFrameLayouter::TextFrameLayouter(InitData init)
: cancellationFlag_{init.cancellationFlag},
  typesetter_{init.typesetter},
  attributedString_{init.attributedString},
  originalStringStyles_{init.stringStyles},
  originalStringFontMetrics_{init.stringFontMetrics},
  truncationScopes_{init.truncationScopes},
  stringParas_{init.stringParas.begin()},
  stringRange_{init.stringRange},
  paras_{std::move(init.paras)},
  stringRangeIsFullString_{init.stringRangeIsFullString},
  clippedStringRangeEnd_{stringRange_.end},
  clippedParagraphCount_{paras_.count()},
  clippedOriginalStringTerminatorStyle_{init.stringStyles.terminatorStyle},
  tokenStyleBuffer_{Ref{localFontInfoCache_},
                    pair(init.stringColorInfos, init.stringColorHashBuckets)}
{
  STU_DEBUG_ASSERT(init.stringParas.count() == paras_.count());
}

TextFrameLayouter::~TextFrameLayouter() {
  if (!ownsCTLinesAndParagraphTruncationTokens_) return;
#if STU_DEBUG
  if (!std::uncaught_exception()) {
    STU_ASSERT(isCancelled());
  }
#endif
  static_assert(isTriviallyDestructible<TextFrameLine>);
  for (TextFrameLine& line : lines_.reversed()) {
    line.releaseCTLines();
  }
  static_assert(isTriviallyDestructible<TextFrameParagraph>);
  for (TextFrameParagraph& para : paras_.reversed()) {
    if (para.truncationToken) {
      decrementRefCount(para.truncationToken);
    }
  }
}

STU_INLINE
void clearParagraphTruncationInfo(STUTextFrameParagraph& para) {
  para.excisedRangeInOriginalString.start = para.rangeInOriginalString.end;
  para.excisedRangeInOriginalString.end = para.rangeInOriginalString.end;
  para.truncationTokenLength = 0;
  para.excisedStringRangeContinuesInNextParagraph = false;
  if (para.truncationToken) {
    decrementRefCount(para.truncationToken);
    para.truncationToken = nil;
  }
}

static auto firstLineOffsetForBaselineAdjustment(const TextFrameLine& firstLine,
                                                 STUBaselineAdjustment baselineAdjustment)
        -> Pair<STUFirstLineOffsetType, Float64>
{
  switch (baselineAdjustment) {
  case STUBaselineAdjustmentNone:
    return {STUOffsetOfFirstBaselineFromDefault, 0};
  case STUBaselineAdjustmentAlignFirstBaseline:
    return {STUOffsetOfFirstBaselineFromTop, firstLine.originY};
  case STUBaselineAdjustmentAlignFirstLineCenter:
    return {STUOffsetOfFirstLineCenterFromTop,
            firstLine.originY - (firstLine.heightAboveBaseline - firstLine.heightBelowBaseline)/2};
  case STUBaselineAdjustmentAlignFirstLineXHeightCenter:
    return {STUOffsetOfFirstLineXHeightCenterFromTop,
            firstLine.originY - firstLine.maxFontMetricValue<FontMetric::xHeight>()/2};
  case STUBaselineAdjustmentAlignFirstLineCapHeightCenter:
    return {STUOffsetOfFirstLineCapHeightCenterFromTop,
            firstLine.originY - firstLine.maxFontMetricValue<FontMetric::capHeight>()/2};
  }
}

void TextFrameLayouter::layoutAndScale(CGSize frameSize,
                                       const STUTextFrameOptions* __unsafe_unretained options) {
  ScaleInfo scaleInfo = {
    .scale = 1,
    .inverseScale = 1,
    .firstParagraphFirstLineOffset = !originalStringParagraphs().isEmpty()
                                   ? stringParas_[0].firstLineOffset : 0,
    .firstParagraphFirstLineOffsetType = !originalStringParagraphs().isEmpty()
                                       ? stringParas_[0].firstLineOffsetType
                                       : STUOffsetOfFirstBaselineFromDefault,
    .baselineAdjustment = options->_textScalingBaselineAdjustment
  };
  const Int maxLineCount =   options->_maxLineCount > 0
                          && options->_maxLineCount <= maxValue<Int32>
                         ? narrow_cast<Int32>(options->_maxLineCount) : maxValue<Int32>;
  const CGSize unscaledFrameSize = frameSize;
  bool shouldEstimateScaleFactor = options->_minTextScaleFactor < 1;
  for (Int layoutIteration = 0; ; ++layoutIteration) {
    layout(CGSize{frameSize.width, shouldEstimateScaleFactor ? 1 << 30 : frameSize.height},
           scaleInfo,
           shouldEstimateScaleFactor ? maxValue<Int32> : maxLineCount,
           options);
    if (!shouldEstimateScaleFactor || isCancelled()) return;
    const Float64 scale = estimateScaleFactorNeededToFit(frameSize.height, maxLineCount);
    if (STU_LIKELY(scale >= 1)) {
      inverselyScaledFrameSize_.height = frameSize.height;
      return;
    }
    // We round down the estimated scale factor to 8 bits to reduce floating-point rounding errors
    // during the scaling. (Most of the CGFloat values we scale don't use the full CGFloat
    // significand.)
    scaleInfo.scale *= floor(narrow_cast<CGFloat>(scale)*256)/256;
    if (scaleInfo.scale <= options->_minTextScaleFactor) {
      shouldEstimateScaleFactor = false;
      scaleInfo.scale = options->_minTextScaleFactor;
    }
    const Float64 inverseScale = 1.0/scaleInfo.scale;
    scaleInfo.inverseScale = inverseScale;
    frameSize.width = unscaledFrameSize.width*narrow_cast<CGFloat>(inverseScale);
    frameSize.height = unscaledFrameSize.height*narrow_cast<CGFloat>(inverseScale);
    if (layoutIteration == 0) {
      const auto [type, offset] = firstLineOffsetForBaselineAdjustment(
                                    lines_[0], scaleInfo.baselineAdjustment);
      scaleInfo.firstParagraphFirstLineOffsetType = type;
      scaleInfo.firstParagraphFirstLineOffset = offset;
    } else if (layoutIteration == 2) {
      // We don't want to call layout more than 4 times.
      shouldEstimateScaleFactor = false;
    }
  } // for (;;)
}

static TextFrameLine::HeightInfo lineHeight(STUTextLayoutMode mode,
                                            const LineHeightParams& params,
                                            const FontMetrics& originalFontMetrics,
                                            const FontMetrics& fontMetrics)
{
  switch (mode) {
  case STUTextLayoutModeDefault: {
    const Float32 a = fontMetrics.ascent();
    const Float32 d = fontMetrics.descent();
    const Float32 g = fontMetrics.leading();
    const Float32 ad = a + d;
    const Float32 hm = max((ad + g)*params.lineHeightMultiple, ad + params.minLineSpacing);
    const Float32 h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const Float32 s = (h - ad)/2;
    return {.heightAboveBaseline = a + s,
            .heightBelowBaseline = d + s,
            .heightBelowBaselineWithoutSpacing = d + min(s, 0.f)};
  }
  case STUTextLayoutModeTextKit: {
    const Float32 a = originalFontMetrics.ascent();
    const Float32 d = originalFontMetrics.descent();
    const Float32 g = originalFontMetrics.leading();
    const Float32 hm = (a + d)*params.lineHeightMultiple;
    const Float32 h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const Float32 s = max(params.minLineSpacing, g);
    return {.heightAboveBaseline = h - d,
            .heightBelowBaseline = d + s,
            .heightBelowBaselineWithoutSpacing = d};

  }
  default: __builtin_trap();
  }
}

template <STUTextLayoutMode mode>
MinLineHeightInfo TextFrameLayouter::minLineHeightInfo(const LineHeightParams& params,
                                                       const MinFontMetrics& minFontMetrics)
{
  STU_DEBUG_ASSERT(minFontMetrics.descent < maxValue<Float32>);
  const Float32 ad = minFontMetrics.ascentPlusDescent;
  const Float32 d = minFontMetrics.descent;
  const Float32 g = minFontMetrics.leading;
  if constexpr (mode == STUTextLayoutModeDefault) {
    const Float32 hm = max((ad + g)*params.lineHeightMultiple, ad + params.minLineSpacing);
    const Float32 h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const Float32 s = (h - ad)/2;
    return {.minHeightWithoutSpacingBelowBaseline = ad + s,
            .minHeightBelowBaselineWithoutSpacing = d + min(s, 0.f),
            .minSpacingBelowBaseline = max(0.f, s)};
  } else {
    static_assert(mode == STUTextLayoutModeTextKit);
    const Float32 hm = ad*params.lineHeightMultiple;
    const Float32 h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const Float32 s = max(0.f, params.minLineSpacing - g);
    return {.minHeightWithoutSpacingBelowBaseline = h + s,
            .minHeightBelowBaselineWithoutSpacing = d,
            .minSpacingBelowBaseline = g};
  }
}
template MinLineHeightInfo TextFrameLayouter
                           ::minLineHeightInfo<STUTextLayoutModeDefault>(const LineHeightParams&,
                                                                         const MinFontMetrics&);
template MinLineHeightInfo TextFrameLayouter
                           ::minLineHeightInfo<STUTextLayoutModeTextKit>(const LineHeightParams&,
                                                                         const MinFontMetrics&);

static
Float64 calculateBaselineOfLineFromPreviousLine(const STUTextFrameLine* __nonnull const line,
                                                const ShapedString::Paragraph* __nonnull const para,
                                                const TextFrameLayouter::ScaleInfo& scaleInfo)
{
  STU_DEBUG_ASSERT(line->_initStep == 4);
  const bool isFirstLine = line->lineIndex == 0;
  Float64 y = isFirstLine ? 0 : line[-1].originY;
  if (isFirstLine || line->isFirstLineInParagraph) {
    Float64 firstLineOffset;
    STUFirstLineOffsetType firstLineOffsetType;
    if (isFirstLine) { // We ignore any paddingTop for the first paragraph.
      firstLineOffset = scaleInfo.firstParagraphFirstLineOffset*scaleInfo.inverseScale;
      firstLineOffsetType = scaleInfo.firstParagraphFirstLineOffsetType;
    } else  { // This is the first line in a paragraph that is not the first.
      firstLineOffset = para->firstLineOffset;
      firstLineOffsetType = para->firstLineOffsetType;
      const Int32 d = line[-1].paragraphIndex - line->paragraphIndex;
      STU_DEBUG_ASSERT(d < 0);
      // d can be less than -1 if the line follows a truncation context spanning multiple paras.
      y += line[-1].heightBelowBaseline + (para[d].paddingBottom + para->paddingTop);
    }
    switch (firstLineOffsetType) {
    case STUOffsetOfFirstBaselineFromDefault:
      firstLineOffset += line->heightAboveBaseline;
      break;
    case STUOffsetOfFirstBaselineFromTop:
      break;
    case STUOffsetOfFirstLineCenterFromTop:
      firstLineOffset += (line->heightAboveBaseline - line->heightBelowBaseline)/2;
      break;
    case STUOffsetOfFirstLineXHeightCenterFromTop:
      firstLineOffset += STUTextFrameLineGetXHeight(line)/2;
      break;
    case STUOffsetOfFirstLineCapHeightCenterFromTop:
      firstLineOffset += STUTextFrameLineGetCapHeight(line)/2;
      break;
    }
    return y + max(0, firstLineOffset);
  }
  // !line.isFirstLineInParagraph
  y += line[-1].heightBelowBaseline;
  y += line->heightAboveBaseline;
  return y;
}

Float32 TextFrameLayouter::intraParagraphBaselineDistanceForLinesLike(
                             const TextFrameLine& line, const ShapedString::Paragraph& para __unused)
{
  return line.heightAboveBaseline + line.heightBelowBaseline;
}

/// @pre scaleInfo == none if spara isn't the first paragraph.
STU_INLINE
Float64 minOffsetFromParagraphTopOfSpacingBelowFirstBaseline(
          STUTextLayoutMode mode, const ShapedString::Paragraph& spara,
          Optional<const TextFrameLayouter::ScaleInfo&> scaleInfo)
{
  STUFirstLineOffsetType offsetType;
  Float64 offset;
  if (scaleInfo) {
    offset = scaleInfo->firstParagraphFirstLineOffset*scaleInfo->inverseScale;
    offsetType = scaleInfo->firstParagraphFirstLineOffsetType;
  } else {
    offset = spara.firstLineOffset;
    offsetType = spara.firstLineOffsetType;
  }
  const MinLineHeightInfo& mh = spara.effectiveMinLineHeightInfo(mode);
  switch (offsetType) {
  case STUOffsetOfFirstBaselineFromDefault:
    offset += mh.minHeightWithoutSpacingBelowBaseline;
    break;
  case STUOffsetOfFirstLineCenterFromTop:
    // We'd need a mh.maxSpacingBelowBaseline to return a better bound.
    break;
  case STUOffsetOfFirstBaselineFromTop:
  case STUOffsetOfFirstLineXHeightCenterFromTop:
  case STUOffsetOfFirstLineCapHeightCenterFromTop:
    // For the two center offset cases this is a lower bound.
    offset += mh.minHeightBelowBaselineWithoutSpacing;
    break;
  }
  return offset;
}

static Float64 minYOfSpacingBelowNextBaselineInSameParagraph(STUTextLayoutMode mode,
                                                             const STUTextFrameLine& line,
                                                             const ShapedString::Paragraph& para)
{
  return line.originY
       + (line.heightBelowBaseline
          + para.effectiveMinLineHeightInfo(mode).minHeightWithoutSpacingBelowBaseline);
}

static
Float64 minYOfSpacingBelowFirstBaselineInNewParagraph(STUTextLayoutMode mode,
                                                      const STUTextFrameLine& line,
                                                      const ShapedString::Paragraph& para,
                                                      const ShapedString::Paragraph& nextPara)
{
  return line.originY
       + (line.heightBelowBaseline + (para.paddingBottom  + nextPara.paddingTop))
       + minOffsetFromParagraphTopOfSpacingBelowFirstBaseline(mode, nextPara, none);
}

static Float64 minDistanceFromMinYOfSpacingBelowBaselineToMinYOfSpacingBelowNextBaseline(
                 STUTextLayoutMode mode, const ShapedString::Paragraph* para, Int32 stringEndIndex)
{
  const MinLineHeightInfo& mh = para->effectiveMinLineHeightInfo(mode);
  Float64 d = mh.minHeight();
  if (para->stringRange.end < stringEndIndex) {
    const Float64 p = mh.minSpacingBelowBaseline + para->paddingBottom;
    const Int32 tsi = para->truncationScopeIndex;
    // Skip to the next para.
    ++para;
    d = min(d, p + para->paddingTop + minOffsetFromParagraphTopOfSpacingBelowFirstBaseline(
                                        mode, *para, none));
    if (tsi >= 0 && tsi == para->truncationScopeIndex) {
      // Skip to the first para after the truncation scope, if it is still in the string range.
      while (para->stringRange.end < stringEndIndex) {
        ++para;
        if (para->truncationScopeIndex != tsi) {
          d = min(d, p + para->paddingTop + minOffsetFromParagraphTopOfSpacingBelowFirstBaseline(
                                              mode, *para, none));
          break;
        }
      }
    }
  }
  return d;
}

struct Indentations {
  Float64 left;
  Float64 right;
  Float64 head;

  STU_INLINE
  Indentations(const ShapedString::Paragraph& para,
               bool isFirstLineInPara,
               Float64 inverselyScaledFrameWidth,
               const TextFrameLayouter::ScaleInfo& scaleInfo)
  {
    // We don't scale the horizontal indentation.
    Float64 leftIndent  = para.paddingLeft*scaleInfo.inverseScale;
    Float64 rightIndent = para.paddingRight*scaleInfo.inverseScale;
    if (leftIndent < 0) {
      leftIndent += inverselyScaledFrameWidth;
    }
    if (rightIndent < 0) {
      rightIndent += inverselyScaledFrameWidth;
    }
    if (isFirstLineInPara) {
      leftIndent  += para.firstLineLeftIndent;
      rightIndent += para.firstLineRightIndent;
    }
    this->left = leftIndent;
    this->right = rightIndent;
    this->head = para.baseWritingDirection == STUWritingDirectionLeftToRight
               ? leftIndent : rightIndent;
  }
};


STU_INLINE
bool isLeftAligned(const STUTextFrameParagraph& para) {
  return para.alignment <= STUParagraphAlignmentJustifiedLeft;
}

STU_INLINE
bool isJustified(const STUTextFrameParagraph& para) {
  return (para.alignment & 0x1) != 0;
}

void TextFrameLayouter::layout(const CGSize inverselyScaledFrameSize,
                               const ScaleInfo scaleInfo,
                               const Int maxLineCount,
                               const STUTextFrameOptions* __unsafe_unretained options)
{
  inverselyScaledFrameSize_ = inverselyScaledFrameSize;
  scaleInfo_ = scaleInfo;
  layoutMode_ = options->_textLayoutMode;
  if (STU_UNLIKELY(paras_.isEmpty())) return;
  if (!lines_.isEmpty()) {
    STU_ASSERT(ownsCTLinesAndParagraphTruncationTokens_);
    static_assert(isTriviallyDestructible<TextFrameLine>);
    for (auto& line : lines_.reversed()) {
      line.releaseCTLines();
    }
    lines_.removeAll();
    tokenStyleBuffer_.clearData();
    if (clippedStringRangeEnd_ < stringRange_.end) {
      TextFrameParagraph& clippedPara = paras_[clippedParagraphCount_ - 1];
      const ShapedString::Paragraph& spara = stringParas_[clippedParagraphCount_ - 1];
      clippedPara.rangeInOriginalString.end = spara.stringRange.end;
      clippedPara.paragraphTerminatorInOriginalStringLength = spara.terminatorStringLength;
      clippedPara.isLastParagraph = clippedParagraphCount_ == paras_.count();
    }
    for (auto& para : paras_[{0, clippedParagraphCount_}].reversed()) {
      clearParagraphTruncationInfo(para);
    }
    needToJustifyLines_ = false;
  }
  const Float64 frameWidth = inverselyScaledFrameSize.width;
  const Float64 frameHeight = inverselyScaledFrameSize.height;
  const STULastLineTruncationMode lastLineTruncationMode = options->_lastLineTruncationMode;
  lastHyphenationLocationInRangeFinder_ = options->_lastHyphenationLocationInRangeFinder;

  const ShapedString::Paragraph* spara = originalStringParagraphs().begin();
  STUTextFrameParagraph* para = paras_.begin();
  const TextStyle* style = originalStringStyles_.firstStyle;
  Int32 stringIndex = stringRange_.start;
  bool clipped = false;
  bool isLastLineInFrame = false;
  Float64 minYOfSpacingBelowBaseline = minOffsetFromParagraphTopOfSpacingBelowFirstBaseline(
                                         layoutMode_, *spara, scaleInfo_);
NewTruncationScope:;
  const Int truncationScopeStartLineIndex = lines_.count();
  Optional<const TruncationScope&> truncationScope =
    spara->truncationScopeIndex < 0 ? nil : &truncationScopes_[spara->truncationScopeIndex];
NewParagraph:;
  hyphenationFactor_ = spara->hyphenationFactor;
  Int32 paraStartLineIndex = narrow_cast<Int32>(lines_.count());
  const Float64 minBaselineDistance =
                  maxLineCount <= lines_.count() + 1
                  ? 0 : minDistanceFromMinYOfSpacingBelowBaselineToMinYOfSpacingBelowNextBaseline(
                          layoutMode_, spara, stringRange_.end);
  for (;;) {
    if (maxLineCount <= lines_.count() + 1
        || minYOfSpacingBelowBaseline + minBaselineDistance > frameHeight)
    {
    LastLine:
      isLastLineInFrame = true;
    }
    if (isCancelled()) return;

    const bool isFirstLineInParagraph = lines_.count() == paraStartLineIndex;
    style = &style->styleForStringIndex(stringIndex);
    TextFrameLine* line = &lines_.append(uninitialized);
    line->init_step1(TextFrameLine::InitStep1Params{
      .lineIndex = lines_.count() - 1,
      .isFirstLineInParagraph = isFirstLineInParagraph,
      .paragraphBaseWritingDirection = para->baseWritingDirection,
      .rangeInOriginalStringStart = stringIndex,
      .rangeInTruncatedStringStart = isFirstLineInParagraph
                                   ? (para->paragraphIndex == 0 ? 0
                                      : para[-1].rangeInTruncatedString.end)
                                   : line[-1].rangeInTruncatedString.end
                                      + line[-1].trailingWhitespaceInTruncatedStringLength,
      .paragraphIndex = para->paragraphIndex,
      .textStylesOffset = reinterpret_cast<const Byte*>(style)
                           - originalStringStyles_.dataBegin()
    });

    const Indentations indent{*spara, isFirstLineInParagraph, frameWidth, scaleInfo_};
    lineHeadIndent_ = indent.head;
    lineMaxWidth_ = max(0, frameWidth - indent.left - indent.right);

    enum ShouldTruncate {
      shouldNotTruncate = 0,
      shouldTruncate_withoutTruncationScope = 1,
      shouldTruncate_withTruncationScope = -1
    };

    ShouldTruncate shouldTruncate =
      isLastLineInFrame && lastLineTruncationMode != STULastLineTruncationModeClip
      ? shouldTruncate_withoutTruncationScope : shouldNotTruncate;
    if (truncationScope
        && (shouldTruncate ? truncationScope->stringRange.end >= stringRange_.end
            : lines_.count() - truncationScopeStartLineIndex == truncationScope->maxLineCount))
    {
      shouldTruncate = shouldTruncate_withTruncationScope;
    }

    Int32 nextStringIndex;
    if (!shouldTruncate) {
      breakLine(*line, para->rangeInOriginalString.end);
      nextStringIndex = line->rangeInOriginalString.end
                      + line->trailingWhitespaceInTruncatedStringLength;
    } else {
      NSAttributedString * __unsafe_unretained token;
      CTLineTruncationType mode;
      Range<Int32> truncatableRange;
      if (shouldTruncate == shouldTruncate_withoutTruncationScope) {
        token = options->_truncationToken;
        truncatableRange = Range{0, maxValue<Int32>};
        switch (options->_lastLineTruncationMode) {
        case STULastLineTruncationModeStart:  mode = kCTLineTruncationStart; break;
        case STULastLineTruncationModeMiddle: mode = kCTLineTruncationMiddle; break;
        default:                              mode = kCTLineTruncationEnd; break;
        }
        nextStringIndex = stringRange_.end;
      } else {
        token = truncationScope->truncationToken;
        truncatableRange = truncationScope->truncatableStringRange;
        mode = truncationScope->lastLineTruncationMode;
        if (truncationScope->stringRange.end < stringRange_.end) {
          nextStringIndex = truncationScope->stringRange.end
                          - truncationScope->finalLineTerminatorUTF16Length;
        } else {
          nextStringIndex = stringRange_.end;
        }
      }
      truncateLine(*line, nextStringIndex, truncatableRange, mode, token,
                   options->_truncationRangeAdjuster, *para, tokenStyleBuffer_);
      // The following line is needed for single-paragraph truncation scopes.
      nextStringIndex = max(nextStringIndex, para->rangeInOriginalString.end);
      for (Int i = tokenFontMetrics_.count(); i < tokenStyleBuffer_.fonts().count(); ++i) {
        const FontRef font = tokenStyleBuffer_.fonts()[i];
        tokenFontMetrics_.append(localFontInfoCache_[font.ctFont()].metrics);
      }
    }

    Float64 originX;
    if (isLeftAligned(*para)) {
      originX = indent.left;
    } else if (para->alignment == STUParagraphAlignmentCenter) {
      originX = (frameWidth - line->width)/2 + (indent.left - indent.right);
    } else { // Align right.
      originX = frameWidth - indent.right - line->width;
    }

    style = initializeTypographicMetricsOfLine(*line);

    line->init_step5(TextFrameLine::InitStep5Params{
      .origin = {originX, calculateBaselineOfLineFromPreviousLine(line, spara, scaleInfo)}
    });

    if ((lastLineTruncationMode != STULastLineTruncationModeClip
         || lines_.count() != maxLineCount)
        && (line->originY + line->_heightBelowBaselineWithoutSpacing <= frameHeight
            || (lines_.count() == 1 && nextStringIndex == stringRange_.end)))
    {
      stringIndex = nextStringIndex;
      if (stringIndex < para->rangeInOriginalString.end) {
        minYOfSpacingBelowBaseline = minYOfSpacingBelowNextBaselineInSameParagraph(
                                       layoutMode_, *line, *spara);
        if (minYOfSpacingBelowBaseline <= frameHeight) continue;
        if (lastLineTruncationMode != STULastLineTruncationModeClip) goto BacktrackOneLine;
        goto ClipPara;
      }
    } else if (lastLineTruncationMode != STULastLineTruncationModeClip) {
      stringIndex = line->rangeInOriginalString.start;
      down_cast<TextFrameLine*>(line)->releaseCTLines();
      lines_.removeLast();
      if (!lines_.isEmpty()) {
      BacktrackOneLine:
        stringIndex = lines_[$ - 1].rangeInOriginalString.start;
        lines_[$ - 1].releaseCTLines();
        lines_.removeLast();
      }
      while (para->rangeInOriginalString.start > stringIndex) {
        clearParagraphTruncationInfo(*para);
        --para;
        --spara;
      }
      clearParagraphTruncationInfo(*para);
      paraStartLineIndex = para->paragraphIndex == 0 ? 0 : para[-1].endLineIndex;
      hyphenationFactor_ = spara->hyphenationFactor;
      truncationScope = none;
      goto LastLine;
    } else { // lastLineTruncationMode == STULastLineTruncationModeClip
      if (lines_.count() > 1
          && line->originY + line->_heightBelowBaselineWithoutSpacing > frameHeight)
      {
        nextStringIndex = stringIndex;
        down_cast<TextFrameLine*>(line)->releaseCTLines();
        lines_.removeLast();
        line = &lines_[$ - 1];
        if (para->rangeInOriginalString.start == stringIndex) {
          --para;
          --spara;
        }
      }
      stringIndex = nextStringIndex;
    ClipPara:
      clipped = true;
      if (stringIndex < para->rangeInOriginalString.end) {
        para->rangeInOriginalString.end = stringIndex;
        para->excisedRangeInOriginalString.start = stringIndex;
        para->excisedRangeInOriginalString.end = stringIndex;
        para->paragraphTerminatorInOriginalStringLength = 0;
      }
    }
    {
      const Int32 start = (para->isFirstParagraph ? 0 : para[-1].rangeInTruncatedString.end);
      const Int32 end = Range{para->rangeInOriginalString}.count()
                      - Range{para->excisedRangeInOriginalString}.count()
                      + para->truncationTokenLength
                      + start;
      para->rangeInTruncatedString = Range{start, end};
    }
    para->endLineIndex = narrow_cast<Int32>(lines_.count());
    needToJustifyLines_ |= isJustified(*para) && paraStartLineIndex + 1 < para->endLineIndex;
    if (STU_UNLIKELY(clipped)) break;
    const ShapedString::Paragraph* const previousSPara = spara;
    for (;;) {
      if (para->rangeInOriginalString.end == stringRange_.end) {
        line->isLastLine = true;
        return;
      }
      ++para;
      ++spara;
      if (stringIndex == para->rangeInOriginalString.start) break;
      // The paragraph was truncated.
      para[-1].excisedStringRangeContinuesInNextParagraph = true;
      para->endLineIndex = narrow_cast<Int32>(lines_.count());
      para->excisedRangeInOriginalString.start = para->rangeInOriginalString.start;
      STU_ASSERT(stringIndex >= para->rangeInOriginalString.end
                                - para->paragraphTerminatorInOriginalStringLength);
      para->excisedRangeInOriginalString.end = min(stringIndex, para->rangeInOriginalString.end);
      const Int32 indexInTruncatedString = para[-1].rangeInTruncatedString.end;
      para->rangeInTruncatedString.start = indexInTruncatedString;
      const Int32 remainingTerminatorLength = para->rangeInOriginalString.end
                                            - para->excisedRangeInOriginalString.end;
      para->rangeInTruncatedString.end = indexInTruncatedString + remainingTerminatorLength;
      if (remainingTerminatorLength != 0) {
        if (line->rangeInTruncatedString.end == indexInTruncatedString) {
          line->trailingWhitespaceInTruncatedStringLength = remainingTerminatorLength;
        }
        stringIndex = para->rangeInOriginalString.end;
      }
    }
    minYOfSpacingBelowBaseline = minYOfSpacingBelowFirstBaselineInNewParagraph(
                                   layoutMode_, *line, *previousSPara, *spara);
    if (minYOfSpacingBelowBaseline <= frameHeight) {
      if (spara->truncationScopeIndex == previousSPara->truncationScopeIndex) goto NewParagraph;
      goto NewTruncationScope;
    }
    // The first line of the new paragraph already doesn't fit.
    if (lastLineTruncationMode != STULastLineTruncationModeClip) goto BacktrackOneLine;
    --para;
    --spara;
    break;
  } // for (;;)
  clippedStringRangeEnd_ = stringIndex;
  clippedOriginalStringTerminatorStyle_ = &style->styleForStringIndex(stringIndex - 1).next();
  clippedParagraphCount_ = para->paragraphIndex + 1;
  para->isLastParagraph = true;
  lines_[$ - 1].isLastLine = true;
}

struct FontMetricsAndStyleFlags {
  FontMetrics metrics;
  TextFlags flags;
  const TextStyle* nextStyle;
};

static FontMetricsAndStyleFlags calculateOriginalFontsMetricsForLineRange(
                                  STUStartEndRangeI32 range,
                                  const TextStyle* __nonnull style,
                                  const FontMetrics* __nonnull fontMetrics)
{
  if (STU_UNLIKELY(range.start == range.end)) {
    return FontMetricsAndStyleFlags{.nextStyle = style};
  }
  Int32 stringIndex = range.start;
  style = &style->styleForStringIndex(stringIndex);
  TextFlags flags = style->flags();
  FontMetrics metrics = fontMetrics[style->fontIndex().value];
  for (;;) {
    if (STU_UNLIKELY(style->hasAttachment())) {
      const STUTextAttachment* __unsafe_unretained const attachment = style->attachmentInfo()->attribute;
      metrics.aggregate(FontMetrics{attachment->_ascent, attachment->_descent});
    }
    const TextStyle* const next = &style->next();
    stringIndex = next->stringIndex();
    if (stringIndex >= range.end) break;
    style = next;
    flags |= style->flags();
    metrics.aggregate(fontMetrics[style->fontIndex().value]);
  }
  return FontMetricsAndStyleFlags{.metrics = metrics, .flags = flags, .nextStyle = style};
}

const TextStyle* TextFrameLayouter::initializeTypographicMetricsOfLine(TextFrameLine& line) {
  const STUTextFrameParagraph& para = paras_[line.paragraphIndex];

  Range<Int32> stringRange1 = line.rangeInOriginalString;
  Range<Int32> stringRange2{uninitialized};
  if (!line.hasTruncationToken) {
    if (stringRange1.isEmpty()) {
      stringRange1.end += line.trailingWhitespaceInTruncatedStringLength;
    }
    stringRange2 = Range{stringRange1.end, stringRange1.end};
  } else {
    stringRange1 = Range{line.rangeInOriginalString.start, para.excisedRangeInOriginalString.start};
    stringRange2 = Range{para.excisedRangeInOriginalString.end, line.rangeInOriginalString.end};
  }

  TextFlags nonTokenTextFlags = TextFlags{};
  FontMetrics metrics = FontMetrics{-infinity<Float32>, -infinity<Float32>};
  const TextStyle* lastOriginalStringStyle;
  {
    const TextStyle* style = firstOriginalStringStyle(line);
    if (!stringRange1.isEmpty()) {
      const FontMetricsAndStyleFlags fsi = calculateOriginalFontsMetricsForLineRange(
                                          stringRange1, style, originalStringFontMetrics_.begin());
      style = fsi.nextStyle;
      nonTokenTextFlags = fsi.flags;
      metrics = fsi.metrics;
    }
    if (!stringRange2.isEmpty()) {
      const FontMetricsAndStyleFlags fsi = calculateOriginalFontsMetricsForLineRange(
                                          stringRange2, style, originalStringFontMetrics_.begin());
      style = fsi.nextStyle;
      nonTokenTextFlags |= fsi.flags;
      metrics.aggregate(fsi.metrics);
    }
    lastOriginalStringStyle = style;
  }

  if (line.hasTruncationToken) {
    const Int32 tokenLength = para.truncationTokenLength;
    const TextStyle* const tokenStyles = firstTruncationTokenStyle(line);
    const FontMetricsAndStyleFlags fsi = calculateOriginalFontsMetricsForLineRange(
                                        Range{0, tokenLength},
                                        tokenStyles, tokenFontMetrics_.begin());
    metrics.aggregate(fsi.metrics);
    // The tokenTextFlags have already been set in init_step2.
  }
  if (STU_UNLIKELY(metrics.ascent() == -infinity<Float32>)) {
    metrics = FontMetrics{};
  }

  line.init_step3(TextFrameLine::InitStep3Params{
    .nonTokenTextFlags = nonTokenTextFlags,
  });

  const FontMetrics originalMetrics{metrics};

  bool hasColorGlyph = false;
  Range<Float32> yBounds;
  { // Adjust the font info to account for substituted fonts, check for color glyphs
    // and calculate the fast vertical bounds for the glyphs.
    const auto nonTokenPartHasBaselineOffsetOrAttachment =
      line.nonTokenTextFlags() & (TextFlags::hasBaselineOffset | TextFlags::hasAttachment);
    const auto tokenPartHasBaselineOffsetOrAttachment =
      line.tokenTextFlags() & (TextFlags::hasBaselineOffset | TextFlags::hasAttachment);
    const TextStyle* originalStringStyle = firstOriginalStringStyle(line);
    const TextStyle* truncationTokenStyle = firstTruncationTokenStyle(line);
    CTFont* font = nullptr;
    Float32 baselineOffset = 0;
    // This requires the line's style flag fields to be initialized.
    down_cast<const TextFrameLine&>(line).forEachGlyphSpan(
      [&](const TextLinePart part, CTLineXOffset, GlyphSpan glyphSpan)
    {
      const Float32 previousBaselineOffset = baselineOffset;
      
      const TextStyle* style = nullptr;
      if (part == TextLinePart::originalString) {
        if (nonTokenPartHasBaselineOffsetOrAttachment) {
          const Int32 stringIndex = narrow_cast<Int32>(glyphSpan.run().stringRange().start);
          style = originalStringStyle = &originalStringStyle->styleForStringIndex(stringIndex);
        }
      } else {
        if (tokenPartHasBaselineOffsetOrAttachment) {
          if (part == TextLinePart::truncationToken) {
            const Int32 stringIndex = narrow_cast<Int32>(glyphSpan.run().stringRange().start);
            style = truncationTokenStyle = &truncationTokenStyle->styleForStringIndex(stringIndex);
          } else {
            style = reinterpret_cast<const TextStyle*>(originalStringStyles_.dataBegin()
                                                       + line._tokenStylesOffset);
            STU_ASSUME(style != nullptr);
          }
        }
      }
      if (STU_LIKELY(!style)) {
        baselineOffset = 0;
      } else {
        if (style->flags() & TextFlags::hasAttachment) return;
        if (style->flags() & TextFlags::hasBaselineOffset) {
          baselineOffset = style->baselineOffset();
        }
      }

      CTFont* const previousFont = font;
      font = glyphSpan.run().font();
      if (font == previousFont && baselineOffset == previousBaselineOffset) return;

      const CachedFontInfo& fontInfo = localFontInfoCache_[font];
      yBounds = yBounds.convexHull(baselineOffset + fontInfo.yBoundsLLO);
      hasColorGlyph |= fontInfo.hasColorGlyphs;
      if (!fontInfo.shouldBeIgnoredInSecondPassOfLineMetricsCalculation) {
        metrics.aggregate(fontInfo.metrics);
      }
    });
  }
  const Float32 d = (yBounds.end - yBounds.start)/2;
  line.init_step4(TextFrameLine::InitStep4Params{
    .hasColorGlyph = hasColorGlyph,
    .ascent = metrics.ascent(),
    .descent = metrics.descent(),
    .leading = metrics.leading(),
    .heightInfo = lineHeight(layoutMode_,
                             originalStringParagraphs()[line.paragraphIndex].lineHeightParams,
                             originalMetrics, metrics),
    .fastBoundsMinX = -d,
    .fastBoundsMaxX = line.width + d,
    .fastBoundsLLOMaxY = yBounds.end,
    .fastBoundsLLOMinY = yBounds.start
  });

  return lastOriginalStringStyle;
}

void TextFrameLayouter::justifyLinesWhereNecessary() {
  const Float64 frameWidth = inverselyScaledFrameSize_.width;
  for (TextFrameParagraph& para : paras_) {
    if (!isJustified(para)) continue;
    const Range<Int> lineIndexRange = para.lineIndexRange();
    if (lineIndexRange.isEmpty()) continue;
    const ShapedString::Paragraph& spara = originalStringParagraphs()[para.paragraphIndex];
    // We don't want to justify the last line in a paragraph.
    for (TextFrameLine& line : lines_[{lineIndexRange.start, lineIndexRange.end - 1}]) {
      if (line.isFollowedByTerminatorInOriginalString) continue;
      const Indentations indent{spara, line.isFirstLineInParagraph, frameWidth, scaleInfo_};
      const Float64 maxWidth = frameWidth - indent.left - indent.right;
      if (maxWidth <= line.width) continue;
      lineMaxWidth_ = maxWidth;
      lineHeadIndent_ = indent.head;
      justifyLine(line);
      if (para.alignment == STUParagraphAlignmentJustifiedLeft) {
        line.originX = indent.left;
      } else {
        line.originX = frameWidth - indent.right - line.width;
      }
    }
  }
}


class TextScalingHeap {
public:
  struct Para {
    Float32 firstLineWidth;
    Float32 nonFirstLineWidth;
    Float32 typographicWidth;
    Float32 lineHeight;
    Float32 scaleThreshold;

    STU_INLINE_T
    bool operator<(const Para& other) const { return scaleThreshold < other.scaleThreshold; }
  };

  STU_INLINE_T
  bool isEmpty() const { return paras_.isEmpty(); };

  STU_INLINE
  void push(Para para) {
    paras_.append(para);
    std::push_heap(paras_.begin(), paras_.end());
  }

  STU_INLINE
  Para popParaWithMaxScaleThreshold() {
    std::pop_heap(paras_.begin(), paras_.end());
    Para result = paras_[$ - 1];
    paras_.removeLast();
    return result;
  }

  explicit STU_INLINE
  TextScalingHeap(MaxInitialCapacity maxInitialCapacity)
  : paras_{maxInitialCapacity}
  {}

private:
  TempVector<Para> paras_;
};

Float64
TextFrameLayouter::estimateScaleFactorNeededToFit(Float64 frameHeight, Int maxLineCount) const {
  const ArrayRef<const TextFrameLine> lines = lines_;
  if (lines.isEmpty()) return 1;

  // TODO: We need more accurate scaling, and likely have to switch to binary searching for
  //       everything but the simplest cases.

  Float64 height = lines[$ - 1].originY + lines[$ - 1]._heightBelowBaselineWithoutSpacing;
  if (height <= frameHeight && lines.count() <= maxLineCount) return 1;
  const Float64 firstLineOffset = scaleInfo_.scale == 1
                                ? firstLineOffsetForBaselineAdjustment(
                                    lines[0], scaleInfo_.baselineAdjustment).second
                                : scaleInfo_.firstParagraphFirstLineOffset*scaleInfo_.inverseScale;
  frameHeight -= firstLineOffset;
  if (frameHeight <= 0 || inverselyScaledFrameSize_.width <= 0) return 0;
  height -= firstLineOffset;

  if (lines.count() > maxLineCount) {
    // Note that a paragraph may contain multiple forced line breaks (e.g. U+2028).
    Int newlineCount = 0;
    for (auto& line : lines) {
      if (line.isFollowedByTerminatorInOriginalString) {
        if (++newlineCount > maxLineCount) break;
      }
    }
    if (!lines[$ - 1].isFollowedByTerminatorInOriginalString) {
      ++newlineCount;
    }
    if (newlineCount == maxLineCount) { // The simple case.
      Float64 scale = 1;
      for (Int i0 = 0, i = 0; i < lines.count(); i0 = i) {
        do {
          if (lines[i++].isFollowedByTerminatorInOriginalString) break;
        } while (i < lines.count());
        if (i == i0 + 1) continue;
        const ArrayRef<const STUTextFrameLine> paraLines = lines[{i0, i}];
        // The paragraph was broken into multiple lines.
        const STUTextFrameLine& firstLine = paraLines[0];
        const STUTextFrameLine& lastLine = paraLines[$ - 1];
        const Indentations indent{stringParas_[firstLine.paragraphIndex],
                                  firstLine.isFirstLineInParagraph,
                                  inverselyScaledFrameSize_.width, scaleInfo_};
        const Float64 width = inverselyScaledFrameSize_.width - indent.left - indent.right;
        if (width <= 0) {
          return 0;
        }
        Float32 maxHeightAboveBaseline = 0;
        Float32 maxHeightBelowBaseline = 0;
        for (auto& line : paraLines) {
          maxHeightAboveBaseline = max(maxHeightAboveBaseline, line.heightAboveBaseline);
          maxHeightBelowBaseline = max(maxHeightBelowBaseline, line.heightBelowBaseline);
        }
        // Estimate the height that would be saved if the frame were wide enough for the whole
        // paragraph to fit into a single line.
        const Float64 d = (lastLine.originY - firstLine.originY)
                        + (firstLine.heightAboveBaseline + lastLine.heightBelowBaseline
                           - (maxHeightAboveBaseline + maxHeightBelowBaseline));
        height -= d;

        const Range<Int> range{firstLine.rangeInOriginalString.start,
                               lastLine.rangeInOriginalString.end};
        const RC<CTLine> line{CTTypesetterCreateLineWithOffset(typesetter_, range, indent.head),
                              ShouldIncrementRefCount{false}};
        const Float64 typographicWidth = stu_label::typographicWidth(line.get());
        if (typographicWidth > 0) {
          scale = min(scale, width/typographicWidth);
        }
      } // for (;;)

      if (scale*height > frameHeight) {
        scale = min(scale, frameHeight/(scale*height));
      }

      return scale;
    }
  }

  TextScalingHeap heap{freeCapacityInCurrentThreadLocalAllocatorBuffer};
  using Para = TextScalingHeap::Para;

  for (Int i0 = 0, i = 0; i < lines.count(); i0 = i) {
    // Our "Para" segments here are separated by any kind of line terminator,
    // not just paragraph separators.
    Float32 width = 0;
    do {
      width += lines[i].width;
      if (lines[i++].isFollowedByTerminatorInOriginalString) break;
    } while (i < lines.count());
    const Int n = i - i0;
    if (width <= 0 || n == 1) continue;
    // The para was broken into multiple lines.
    const STUTextFrameLine& firstLine = lines[i0];
    const STUTextFrameLine& lastLine = lines[i - 1];
    // If the paragraph was truncated due to a truncation scope, we ignore it here.
    if (lastLine.hasTruncationToken) continue;
    // These are just rough estimates that hopefully are conservative enough.
    const Float32 firstLineWidth = firstLine.width;
    const Float32 nonFirstLineWidth = n == 2 ? 0
                                    : (width - firstLineWidth - lastLine.width)/(n - 2);
    const Float32 lineHeight = narrow_cast<Float32>(lastLine.originY - firstLine.originY)/(n - 1);
    const Float32 f = static_cast<Float32>(lines[i - 2].trailingWhitespaceInTruncatedStringLength)
                      /Range{lastLine.rangeInOriginalString}.count();
    const Float32 scaleThreshold = 0.99f - (1 + f)*lastLine.width/width;
    heap.push({.typographicWidth = width,
               .firstLineWidth = firstLineWidth,
               .nonFirstLineWidth = nonFirstLineWidth,
               .lineHeight = lineHeight,
               .scaleThreshold = scaleThreshold});
  }

  Int lineCount = lines.count();
  Float64 scale = 1;
  while (!heap.isEmpty()) {
    Para para = heap.popParaWithMaxScaleThreshold();
    if (lineCount <= maxLineCount) {
      if (scale*height <= frameHeight) break;
      scale = frameHeight/(scale*height);
      if (scale > para.scaleThreshold) break;
    }
    const Float32 scalef = para.scaleThreshold;
    scale = scalef;
    lineCount -= 1;
    height -= para.lineHeight;
    const Float32 scaledWidth = para.typographicWidth*scalef;
    if (scaledWidth <= para.firstLineWidth || para.nonFirstLineWidth <= 0) continue;
    const Float32 r = fmod(scaledWidth - para.firstLineWidth, para.nonFirstLineWidth)/scaledWidth;
    para.scaleThreshold = scalef*(0.99f - r);
    heap.push(para);
  }

  if (frameHeight < scale*height) {
    scale = frameHeight/(scale*height);
  }

  return scale;
}

} // namespace stu_label
