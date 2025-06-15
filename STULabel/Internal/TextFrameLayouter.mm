// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrameLayouter.hpp"

#import "STULabel/STUTextAttachment-Internal.hpp"
#import "STULabel/STUTextFrameOptions-Internal.hpp"

#import "CoreGraphicsUtils.hpp"
#import "InputClamping.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

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
  #if !TARGET_ABI_USES_IOS_VALUES
    const int s = 0;
  #else
    const int s = 1;
  #endif
    STUParagraphAlignment result;
    switch (defaultTextAlignment) {
    case STUDefaultTextAlignmentLeft:
    case STUDefaultTextAlignmentRight:
      static_assert(((int)STUDefaultTextAlignmentLeft << s) == (int)STUParagraphAlignmentLeft);
      static_assert(((int)STUDefaultTextAlignmentRight << s) == (int)STUParagraphAlignmentRight);
      result = STUParagraphAlignment(defaultTextAlignment << s);
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
  #if !TARGET_ABI_USES_IOS_VALUES
    static_assert(((int)STUParagraphAlignmentLeft + 2) == (int)STUParagraphAlignmentJustifiedLeft);
    static_assert(((int)STUParagraphAlignmentRight + 2) == (int)STUParagraphAlignmentJustifiedRight);
    return STUParagraphAlignment(result + (alignment == NSTextAlignmentJustified ? 2 : 0));
  #else
    static_assert(((int)STUParagraphAlignmentLeft | 1) == (int)STUParagraphAlignmentJustifiedLeft);
    static_assert(((int)STUParagraphAlignmentRight | 1) == (int)STUParagraphAlignmentJustifiedRight);
    return STUParagraphAlignment(result | (alignment == NSTextAlignmentJustified));
  #endif
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
                    .isIndented = p.isIndented}};
      ++i;
    }
  }

  if (!paras.isEmpty()) {
    paras[0].rangeInOriginalString.start = stringRange.start;
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

  TempStringBuffer tempStringBuffer{paras.allocator()};
  NSAttributedStringRef attributedString{shapedString.attributedString, Ref{tempStringBuffer}};

  return {.cancellationFlag = *(cancellationFlag ?: &CancellationFlag::neverCancelledFlag),
          .typesetter = shapedString.typesetter.get(),
          .tempStringBuffer = std::move(tempStringBuffer),
          .attributedString = attributedString,
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
: tempStringBuffer_{std::move(init.tempStringBuffer)},
  cancellationFlag_{init.cancellationFlag},
  typesetter_{init.typesetter},
  attributedString_{init.attributedString},
  originalStringStyles_{init.stringStyles},
  originalStringFontMetrics_{init.stringFontMetrics},
  truncationScopes_{init.truncationScopes},
  stringParasPtr_{init.stringParas.begin()},
  stringRange_{init.stringRange},
  paras_{std::move(init.paras)},
  lines_{paras_.allocator()},
  stringRangeIsFullString_{init.stringRangeIsFullString},
  clippedStringRangeEnd_{stringRange_.end},
  clippedParagraphCount_{paras_.count()},
  clippedOriginalStringTerminatorStyle_{init.stringStyles.terminatorStyle},
  tokenStyleBuffer_{Ref{localFontInfoCache_}, paras_.allocator(),
                    pair(init.stringColorInfos, init.stringColorHashBuckets)},
  tokenFontMetrics_{paras_.allocator()}
{
  STU_DEBUG_ASSERT(init.stringParas.count() == paras_.count());
}

TextFrameLayouter::~TextFrameLayouter() {
  if (!ownsCTLinesAndParagraphTruncationTokens_) return;
#if STU_DEBUG
  if (!std::uncaught_exceptions()) {
    STU_ASSERT(isCancelled());
  }
#endif
  destroyLinesAndParagraphs();
}

void TextFrameLayouter::destroyLinesAndParagraphs() {
  STU_ASSERT(ownsCTLinesAndParagraphTruncationTokens_);
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

void TextFrameLayouter::SavedLayout::clear() {
  if (!data_) return;
  for (TextFrameLine& line : data_->lines.reversed()) {
    line.releaseCTLines();
  }
  for (TextFrameParagraph& para : data_->paragraphs.reversed()) {
    if (para.truncationToken) {
      decrementRefCount(para.truncationToken);
    }
  }
  ThreadLocalAllocatorRef{}.get().deallocate(reinterpret_cast<Byte*>(data_), data_->size);
  data_ = nullptr;
}

void TextFrameLayouter::saveLayoutTo(SavedLayout& layout) {
  if (layout.data_) {
    layout.clear();
  }
  using Data = SavedLayout::Data;
  static_assert(alignof(Data) >= alignof(TextFrameParagraph));
  static_assert(alignof(TextFrameParagraph) >= alignof(TextFrameLine));
  const UInt size = sizeof(Data) + paras_.arraySizeInBytes()
                                 + lines_.arraySizeInBytes()
                                 + tokenStyleBuffer_.data().arraySizeInBytes();
  auto* const data = reinterpret_cast<Data*>(ThreadLocalAllocatorRef{}.get().allocate(size));
  layout.data_ = data;
  data->size = size;

  data->scaleInfo = scaleInfo_;
  data->inverselyScaledFrameSize = inverselyScaledFrameSize_;
  data->needToJustifyLines = needToJustifyLines_;
  data->mayExceedMaxWidth = mayExceedMaxWidth_;
  data->clippedStringRangeEnd = clippedStringRangeEnd_;
  data->clippedParagraphCount = clippedParagraphCount_;
  data->clippedOriginalStringTerminatorStyle = clippedOriginalStringTerminatorStyle_;

  data->paragraphs = ArrayRef{reinterpret_cast<TextFrameParagraph*>(data + 1), paras_.count()};
  array_utils::copyConstructArray(paras_, data->paragraphs.begin());
  for (TextFrameParagraph& para : data->paragraphs) {
    if (para.truncationToken) {
      incrementRefCount(para.truncationToken);
    }
  }

  data->lines = ArrayRef{reinterpret_cast<TextFrameLine*>(data->paragraphs.end()), lines_.count()};
  array_utils::copyConstructArray(lines_, data->lines.begin());
  for (TextFrameLine& line : data->lines) {
    if (line._ctLine) {
      incrementRefCount(line._ctLine);
    }
    if (line._tokenCTLine) {
      incrementRefCount(line._tokenCTLine);
    }
  }

  data->tokenStyleData = ArrayRef{reinterpret_cast<Byte*>(data->lines.end()),
                                  tokenStyleBuffer_.data().count()};
  array_utils::copyConstructArray(tokenStyleBuffer_.data(), data->tokenStyleData.begin());
}

void TextFrameLayouter::restoreLayoutFrom(SavedLayout&& layout) {
  STU_ASSERT(layout.data_ != nullptr);
  auto& data = *layout.data_;

  destroyLinesAndParagraphs();

  scaleInfo_ = data.scaleInfo;
  inverselyScaledFrameSize_ = data.inverselyScaledFrameSize;
  needToJustifyLines_ = data.needToJustifyLines;
  mayExceedMaxWidth_ = data.mayExceedMaxWidth;
  clippedStringRangeEnd_ = data.clippedStringRangeEnd;
  clippedParagraphCount_ = data.clippedParagraphCount;
  clippedOriginalStringTerminatorStyle_ = data.clippedOriginalStringTerminatorStyle;

  static_assert(isTriviallyDestructible<TextFrameParagraph>);
  STU_ASSERT(data.paragraphs.count() == paras_.count());
  array_utils::copyConstructArray(data.paragraphs, paras_.begin());

  lines_.removeAll();
  lines_.append(repeat(uninitialized, data.lines.count()));
  array_utils::copyConstructArray(data.lines, lines_.begin());

  tokenStyleBuffer_.setData(data.tokenStyleData);

  layout.data_ = nullptr;
  ThreadLocalAllocatorRef{}.get().deallocate(reinterpret_cast<Byte*>(&data), data.size);
}

STU_INLINE
void clearParagraphTruncationInfo(STUTextFrameParagraph& para) {
  para.excisedRangeInOriginalString.start = para.rangeInOriginalString.end;
  para.excisedRangeInOriginalString.end = para.rangeInOriginalString.end;
  para.truncationTokenLength = 0;
  para.excisedStringRangeIsContinuedInNextParagraph = false;
  para.excisedStringRangeIsContinuationFromLastParagraph = false;
  if (para.truncationToken) {
    decrementRefCount(para.truncationToken);
    para.truncationToken = nil;
  }
}

static TextFrameLine::HeightInfo lineHeight(STUTextLayoutMode mode,
                                            const LineHeightParams& params,
                                            CGFloat ascent, CGFloat descent, CGFloat leading)
{
  const CGFloat a = ascent;
  const CGFloat d = descent;
  const CGFloat g = leading;
  switch (mode) {
  case STUTextLayoutModeDefault: {
    const CGFloat ad = a + d;
    const CGFloat hm = ad*params.lineHeightMultiple
                     + max(g*params.lineHeightMultiple, params.minLineSpacing);
    const CGFloat h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const CGFloat s = (h - ad)/2;
    return {.heightAboveBaseline = narrow_cast<Float32>(a + s),
            .heightBelowBaseline = narrow_cast<Float32>(d + s),
            .heightBelowBaselineWithoutSpacing = narrow_cast<Float32>(d + min(s, 0.f))};
  }
  case STUTextLayoutModeTextKit: {
    const CGFloat hm = (a + d)*params.lineHeightMultiple;
    const CGFloat h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const CGFloat s = max(params.minLineSpacing, g);
    return {.heightAboveBaseline = narrow_cast<Float32>(h - d),
            .heightBelowBaseline = narrow_cast<Float32>(d + s),
            .heightBelowBaselineWithoutSpacing = narrow_cast<Float32>(d)};

  }
  default: __builtin_trap();
  }
}

template <STUTextLayoutMode mode>
MinLineHeightInfo TextFrameLayouter::minLineHeightInfo(const LineHeightParams& params,
                                                       const MinFontMetrics& minFontMetrics)
{
  STU_DEBUG_ASSERT(minFontMetrics.minDescent < maxValue<Float32>);
  const CGFloat ad = minFontMetrics.minAscentPlusDescent;
  const CGFloat d = minFontMetrics.minDescent;
  const CGFloat g = minFontMetrics.minLeading;
  if constexpr (mode == STUTextLayoutModeDefault) {
    const CGFloat hm = ad*params.lineHeightMultiple
                     + max(g*params.lineHeightMultiple, params.minLineSpacing);
    const CGFloat h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    CGFloat minHeightBelowBaselineWithoutSpacing;
    CGFloat minSpacingBelowBaseline;
    if (params.lineHeightMultiple >= 1 && params.maxLineHeight >= maxValue<Float32>) {
      minSpacingBelowBaseline = (h - ad)/2;
      minHeightBelowBaselineWithoutSpacing = d;
    } else {
      minSpacingBelowBaseline = (h - minFontMetrics.maxAscentPlusDescent)/2;
      minHeightBelowBaselineWithoutSpacing = d + min(minSpacingBelowBaseline, 0.f);
    }
    return {.minHeight = narrow_cast<Float32>(h),
            .minHeightWithoutSpacingBelowBaseline = narrow_cast<Float32>(min((ad + h)/2, h)),
            .minHeightBelowBaselineWithoutSpacing = narrow_cast<Float32>(
                                                      minHeightBelowBaselineWithoutSpacing),
            .minSpacingBelowBaseline = narrow_cast<Float32>(minHeightBelowBaselineWithoutSpacing)};
  } else {
    static_assert(mode == STUTextLayoutModeTextKit);
    const CGFloat hm = ad*params.lineHeightMultiple;
    const CGFloat h = clamp(params.minLineHeight, hm, params.maxLineHeight);
    const CGFloat s = max(params.minLineSpacing, g);
    return {.minHeight = narrow_cast<Float32>(h + s),
            .minHeightWithoutSpacingBelowBaseline = narrow_cast<Float32>(h),
            .minHeightBelowBaselineWithoutSpacing = narrow_cast<Float32>(d),
            .minSpacingBelowBaseline = narrow_cast<Float32>(s)};
  }
}
template MinLineHeightInfo TextFrameLayouter
                           ::minLineHeightInfo<STUTextLayoutModeDefault>(const LineHeightParams&,
                                                                         const MinFontMetrics&);
template MinLineHeightInfo TextFrameLayouter
                           ::minLineHeightInfo<STUTextLayoutModeTextKit>(const LineHeightParams&,
                                                                         const MinFontMetrics&);

STU_INLINE
Float32 extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
          const STUTextFrameLine& line, Float32 minBaselineDistance)
{
  return TextFrameLayouter::extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                              line, minBaselineDistance);
}

static
Float64 calculateBaselineOfLineFromPreviousLine(const STUTextFrameLine* __nonnull const line,
                                                const ShapedString::Paragraph* __nonnull const para,
                                                const TextFrameLayouter::ScaleInfo& scaleInfo)
{
  STU_DEBUG_ASSERT(line->_initStep == 4);
  if (line->isFirstLineInParagraph) {
    STUFirstLineOffsetType firstLineOffsetType;
    Float64 firstLineOffset;
    Float64 y;
    Float32 minBaselineDistance;
    if (line->lineIndex == 0) {
      firstLineOffsetType = scaleInfo.firstParagraphFirstLineOffsetType;
      firstLineOffset = scaleInfo.firstParagraphFirstLineOffset*scaleInfo.inverseScale;
      // We ignore any paddingTop for the first paragraph.
      y = 0;
      minBaselineDistance = para->minBaselineDistance;
    } else {
      firstLineOffsetType = para->firstLineOffsetType;
      firstLineOffset = para->firstLineOffset;
      const STUTextFrameLine& line1 = line[-1];
      const Int32 d = line1.paragraphIndex - line->paragraphIndex;
      STU_DEBUG_ASSERT(d < 0);
      // d can be less than -1 if the line follows a truncation scope spanning multiple paragraphs.
      const ShapedString::Paragraph& para1 = para[d];
      Float32 offset = line1._heightBelowBaseline + (para1.paddingBottom + para->paddingTop);
      minBaselineDistance = para1.minBaselineDistance;
      if (minBaselineDistance == 0) {
        minBaselineDistance = para->minBaselineDistance;
      } else {
        offset += extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                    line1, minBaselineDistance);
        minBaselineDistance = max(minBaselineDistance, para->minBaselineDistance);
      }
      y = line1.originY + offset;
    }
    switch (firstLineOffsetType) {
    case STUOffsetOfFirstBaselineFromDefault: {
      Float32 offset = line->_heightAboveBaseline;
      if (minBaselineDistance == 0) {
        firstLineOffset += offset;
        break;
      }
      if (para->minBaselineDistance > 0) {
        offset += extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                    *line, para->minBaselineDistance);
      }
      if (line->lineIndex == 0) {
        firstLineOffset += offset;
        break;
      }
      return max(y, max(y + offset, line[-1].originY + minBaselineDistance) + firstLineOffset);
    }
    case STUOffsetOfFirstBaselineFromTop:
      break;
    case STUOffsetOfFirstLineCenterFromTop:
      firstLineOffset += (line->_heightAboveBaseline - line->_heightBelowBaseline)/2;
      break;
    case STUOffsetOfFirstLineXHeightCenterFromTop:
      firstLineOffset += STUTextFrameLineGetXHeight(line)/2;
      break;
    case STUOffsetOfFirstLineCapHeightCenterFromTop:
      firstLineOffset += STUTextFrameLineGetCapHeight(line)/2;
      break;
    }
    y += max(0, firstLineOffset);
    return y;
  }
  return line[-1].originY + max(line[-1]._heightBelowBaseline + line->_heightAboveBaseline,
                                para->minBaselineDistance);
}

/// @pre scaleInfo == none if spara isn't the first paragraph.
STU_INLINE
Float32 minDistanceFromParagraphTopToSpacingBelowFirstBaseline(
          STUTextLayoutMode mode, const ShapedString::Paragraph& spara,
          Optional<const TextFrameLayouter::ScaleInfo&> scaleInfo)
{
  STUFirstLineOffsetType offsetType;
  Float32 offset;
  if (scaleInfo) {
    offset = narrow_cast<Float32>(scaleInfo->firstParagraphFirstLineOffset*scaleInfo->inverseScale);
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
    return 0;
  case STUOffsetOfFirstBaselineFromTop:
  case STUOffsetOfFirstLineXHeightCenterFromTop:
  case STUOffsetOfFirstLineCapHeightCenterFromTop:
    offset += mh.minHeightBelowBaselineWithoutSpacing;
    break;
  }
  return offset;
}

static Float64 minYOfSpacingBelowNextBaselineInSameParagraph(STUTextLayoutMode mode,
                                                             const STUTextFrameLine& line,
                                                             const ShapedString::Paragraph& para)
{
  const auto& mh = para.effectiveMinLineHeightInfo(mode);
  const Float32 offset1 = line._heightBelowBaseline + mh.minHeightWithoutSpacingBelowBaseline;
  const Float32 offset2 = para.minBaselineDistance + mh.minSpacingBelowBaseline;
  return line.originY + max(offset1, offset2);
}

static
Float64 minYOfSpacingBelowFirstBaselineInNewParagraph(STUTextLayoutMode mode,
                                                      const STUTextFrameLine& line,
                                                      const ShapedString::Paragraph& para,
                                                      const ShapedString::Paragraph& nextPara)
{
  Float32 offset = line._heightBelowBaseline + (para.paddingBottom + nextPara.paddingTop)
                 + minDistanceFromParagraphTopToSpacingBelowFirstBaseline(mode, nextPara, none);
  Float32 minBaselineDistance = para.minBaselineDistance;
  if (minBaselineDistance == 0) {
    minBaselineDistance = nextPara.minBaselineDistance;
  } else {
    offset += extraSpacingBeforeFirstAndAfterLastLineInParagraphDueToMinBaselineDistance(
                line, minBaselineDistance);
    minBaselineDistance = max(minBaselineDistance, nextPara.minBaselineDistance);
  }
  if (minBaselineDistance == 0
      || nextPara.firstLineOffsetType != STUOffsetOfFirstBaselineFromDefault)
  {
    return line.originY + offset;
  }
  const Float32 offset2 = minBaselineDistance + nextPara.firstLineOffset
                        + nextPara.effectiveMinHeightBelowBaselineWithoutSpacing(mode);
  return line.originY + max(offset, offset2);
}

static Float32 minDistanceFromMinYOfSpacingBelowBaselineToMinYOfSpacingBelowNextBaseline(
                 STUTextLayoutMode mode, const ShapedString::Paragraph* para, Int32 stringEndIndex)
{
  const MinLineHeightInfo& mh = para->effectiveMinLineHeightInfo(mode);
  const Float32 minBaselineDistance = para->minBaselineDistance;
  Float32 d = max(mh.minHeight, minBaselineDistance);
  if (para->stringRange.end < stringEndIndex) {
    Float32 p = mh.minSpacingBelowBaseline + para->paddingBottom;
    const Int32 tsi = para->truncationScopeIndex;
    // Skip to the next para.
    ++para;
    Float32 d1 = p + para->paddingTop
                 + minDistanceFromParagraphTopToSpacingBelowFirstBaseline(mode, *para, none);
    if (para->firstLineOffsetType == STUOffsetOfFirstBaselineFromDefault) {
      const Float32 d2 = max(minBaselineDistance, para->minBaselineDistance)
                       + para->firstLineOffset
                       + (para->effectiveMinHeightBelowBaselineWithoutSpacing(mode)
                          - mh.minHeightBelowBaselineWithoutSpacing);
      d1 = max(d1, d2);
    }
    d = min(d, d1);
    if (tsi >= 0 && tsi == para->truncationScopeIndex) {
      // Skip to the first para after the truncation scope, if it is still in the string range.
      while (para->stringRange.end < stringEndIndex) {
        ++para;
        if (para->truncationScopeIndex != tsi) {
          d1 = p + para->paddingTop
             + minDistanceFromParagraphTopToSpacingBelowFirstBaseline(mode, *para, none);
          if (para->firstLineOffsetType == STUOffsetOfFirstBaselineFromDefault) {
            const Float32 d2 = max(minBaselineDistance, para->minBaselineDistance)
                             + para->firstLineOffset
                             + (para->effectiveMinHeightBelowBaselineWithoutSpacing(mode)
                                - mh.minHeightBelowBaselineWithoutSpacing);
            d1 = max(d1, d2);
          }
          d = min(d, d1);
        }
      }
    }
  }
  return d;
}


STU_INLINE
bool isLeftAligned(const STUTextFrameParagraph& para) {
  return para.alignment <= STUParagraphAlignmentJustifiedLeft;
}

STU_INLINE
bool isJustified(const STUTextFrameParagraph& para) {
  return (para.alignment & 0x1) != 0;
}


bool TextFrameLayouter::lastLineFitsFrameHeight() const {
  if (STU_UNLIKELY(lines_.isEmpty())) return true;
  const TextFrameLine& line = lines_[$ - 1];
  const Float64 heightBelowBaselineWithoutSpacing = line._heightBelowBaselineWithoutSpacing;
  Float64 maxY = line.originY + heightBelowBaselineWithoutSpacing;
  const Float64 maxHeight = inverselyScaledFrameSize_.height;
  const Optional<DisplayScale>& displayScale = scaleInfo_.displayScale;
  if (!displayScale) {
    return maxY <= maxHeight;
  }
  if (maxY + displayScale->inverseValue_f64() <= maxHeight) {
    return true;
  }
  maxY = ceilToScale(line.originY, *displayScale) + heightBelowBaselineWithoutSpacing;
  return maxY <= maxHeight;
}

void TextFrameLayouter::layout(const Size<Float64> inverselyScaledFrameSize,
                               const ScaleInfo scaleInfo,
                               const Int maxLineCount,
                               const TextFrameOptions& options)
{
  layoutCallCount_ += 1;
  inverselyScaledFrameSize_ = inverselyScaledFrameSize;
  const Float64 frameWidth = inverselyScaledFrameSize.width;
  const Float64 frameHeight = inverselyScaledFrameSize.height;
  const Float64 frameHeightPlusEpsilon = frameHeight + 1/1024.;
  scaleInfo_ = scaleInfo;
  layoutMode_ = options.textLayoutMode;
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
      const ShapedString::Paragraph& spara = stringParas()[clippedParagraphCount_ - 1];
      clippedPara.rangeInOriginalString.end = spara.stringRange.end;
      clippedPara.paragraphTerminatorInOriginalStringLength = spara.terminatorStringLength;
      clippedPara.isLastParagraph = clippedParagraphCount_ == paras_.count();
    }
    for (auto& para : paras_[{0, clippedParagraphCount_}].reversed()) {
      clearParagraphTruncationInfo(para);
    }
    needToJustifyLines_ = false;
  }
  mayExceedMaxWidth_ = false;
  const STULastLineTruncationMode lastLineTruncationMode = options.lastLineTruncationMode;
  lastHyphenationLocationInRangeFinder_ = options.lastHyphenationLocationInRangeFinder;

  const ShapedString::Paragraph* spara = originalStringParagraphs().begin();
  STUTextFrameParagraph* para = paras_.begin();
  const TextStyle* style = originalStringStyles_.firstStyle;
  Int32 stringIndex = stringRange_.start;
  bool clipped = false;
  bool isLastLineInFrame = false;
  Float64 minYOfSpacingBelowBaseline = minDistanceFromParagraphTopToSpacingBelowFirstBaseline(
                                         layoutMode_, *spara, scaleInfo_);
NewTruncationScope:;
  const Int truncationScopeStartLineIndex = lines_.count();
  Optional<const TruncationScope&> truncationScope =
    spara->truncationScopeIndex < 0 ? nil : &truncationScopes_[spara->truncationScopeIndex];
NewParagraph:;
  hyphenationFactor_ = spara->hyphenationFactor;
  para->lineIndexRange.start = narrow_cast<Int32>(lines_.count());
  if (__builtin_add_overflow(para->lineIndexRange.start, spara->maxNumberOfInitialLines,
                             &para->initialLinesEndIndex))
  {
    para->initialLinesEndIndex = maxValue<Int32>;
  }
  const Float64 minLineDistance =
                  maxLineCount <= lines_.count() + 1
                  ? 0 : minDistanceFromMinYOfSpacingBelowBaselineToMinYOfSpacingBelowNextBaseline(
                          layoutMode_, spara, stringRange_.end);
  for (;;) {
    if (maxLineCount <= lines_.count() + 1
        || minYOfSpacingBelowBaseline + minLineDistance > frameHeightPlusEpsilon)
    {
    LastLine:
      isLastLineInFrame = true;
      minYOfSpacingBelowBaseline = -infinity<Float64>;
    }
    if (isCancelled()) return;

    const bool isFirstLineInParagraph = lines_.count() == para->lineIndexRange.start;
    const bool isInitialLineInParagraph = lines_.count() < para->initialLinesEndIndex;
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
      .textStylesOffset = reinterpret_cast<const Byte*>(style) - originalStringStyles_.dataBegin()
    });

    const Indentations indent{*spara, isInitialLineInParagraph, scaleInfo_};
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
      Range<Int32> truncatableRange{uninitialized};
      if (shouldTruncate == shouldTruncate_withoutTruncationScope) {
        token = options.fixedTruncationToken;
        truncatableRange = Range{0, maxValue<Int32>};
        switch (options.lastLineTruncationMode) {
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
                   options.truncationRangeAdjuster, *para, tokenStyleBuffer_);
      // The following line is needed for single-paragraph truncation scopes.
      nextStringIndex = max(nextStringIndex, para->rangeInOriginalString.end);
      for (Int i = tokenFontMetrics_.count(); i < tokenStyleBuffer_.fonts().count(); ++i) {
        const FontRef font = tokenStyleBuffer_.fonts()[i];
        tokenFontMetrics_.append(localFontInfoCache_[font.ctFont()].metrics);
      }
    }

    // "may" because we may backtrack.
    mayExceedMaxWidth_ |= line->width > lineMaxWidth_;

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
    STU_DEBUG_ASSERT(minYOfSpacingBelowBaseline
                     <= line->originY + line->_heightBelowBaselineWithoutSpacing + 1/1024.0);

    const bool lineFits = lastLineFitsFrameHeight();

    if ((lastLineTruncationMode != STULastLineTruncationModeClip
         || lines_.count() != maxLineCount)
        && (lineFits || (lines_.count() == 1 && nextStringIndex == stringRange_.end)))
    {
      stringIndex = nextStringIndex;
      if (stringIndex < para->rangeInOriginalString.end) {
        minYOfSpacingBelowBaseline = minYOfSpacingBelowNextBaselineInSameParagraph(
                                       layoutMode_, *line, *spara);
        if (minYOfSpacingBelowBaseline <= frameHeightPlusEpsilon) continue;
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
      if (__builtin_add_overflow(para->lineIndexRange.start, spara->maxNumberOfInitialLines,
                                 &para->initialLinesEndIndex))
      {
        para->initialLinesEndIndex = maxValue<Int32>;
      }
      hyphenationFactor_ = spara->hyphenationFactor;
      truncationScope = none;
      goto LastLine;
    } else { // lastLineTruncationMode == STULastLineTruncationModeClip
      if (lines_.count() > 1 && !lineFits) {
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
      const Int32 start = (para->paragraphIndex == 0 ? 0 : para[-1].rangeInTruncatedString.end);
      const Int32 end = Range{para->rangeInOriginalString}.count()
                      - Range{para->excisedRangeInOriginalString}.count()
                      + para->truncationTokenLength
                      + start;
      para->rangeInTruncatedString = Range{start, end};
    }
    para->lineIndexRange.end = narrow_cast<Int32>(lines_.count());
    para->initialLinesEndIndex = min(para->initialLinesEndIndex, para->lineIndexRange.end);
    needToJustifyLines_ |= isJustified(*para)
                           && para->lineIndexRange.start + 1 < para->lineIndexRange.end;
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
      para[-1].excisedStringRangeIsContinuedInNextParagraph = true;
      para->excisedStringRangeIsContinuationFromLastParagraph = true;
      const Int32 lineIndex = narrow_cast<Int32>(lines_.count());
      para->lineIndexRange.start = lineIndex;
      para->lineIndexRange.end = lineIndex;
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
    if (minYOfSpacingBelowBaseline <= frameHeightPlusEpsilon) {
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
  FontMetrics metrics = !style->hasAttachment()
                      ? fontMetrics[style->fontIndex().value]
                      : style->attachmentInfo()->attribute->_metrics;
  if (STU_UNLIKELY(style->hasBaselineOffset())) {
    metrics.adjustByBaselineOffset(style->baselineOffset());
  }
  for (;;) {
    const TextStyle* const next = &style->next();
    stringIndex = next->stringIndex();
    if (stringIndex >= range.end) break;
    style = next;
    flags |= style->flags();
    const FontMetrics& styleMetrics = !style->hasAttachment()
                                    ? fontMetrics[style->fontIndex().value]
                                    : style->attachmentInfo()->attribute->_metrics;
    if (STU_LIKELY(!style->hasBaselineOffset())) {
      metrics.aggregate(styleMetrics);
    } else {
      metrics.aggregate(styleMetrics.adjustedByBaselineOffset(style->baselineOffset()));
    }
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
  Range<Float32> yBounds = {};
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
        if (STU_LIKELY(baselineOffset == 0)) {
          metrics.aggregate(fontInfo.metrics);
        } else {
          metrics.aggregate(fontInfo.metrics.adjustedByBaselineOffset(baselineOffset));
        }
      }
    });
  }
  const CGFloat ascent = metrics.ascent();
  const CGFloat descent = metrics.descent();
  const CGFloat leading = metrics.leading();
  const Float32 d = (yBounds.end - yBounds.start)/2;
  TextFrameLine::HeightInfo heightInfo;
  if (layoutMode_ == STUTextLayoutModeDefault) {
    minimalSpacingBelowLastLine_ = static_cast<Float32>(leading/2);
    heightInfo = lineHeight(STUTextLayoutModeDefault,
                            originalStringParagraphs()[line.paragraphIndex].lineHeightParams,
                            ascent, descent, leading);
  } else {
    const CGFloat originalAscent = originalMetrics.ascent();
    const CGFloat originalDescent = originalMetrics.descent();
    const CGFloat originalLeading = originalMetrics.leading();
    minimalSpacingBelowLastLine_ = static_cast<Float32>(originalLeading);
    heightInfo = lineHeight(STUTextLayoutModeTextKit,
                            originalStringParagraphs()[line.paragraphIndex].lineHeightParams,
                            originalAscent, originalDescent, originalLeading);
  }
  line.init_step4(TextFrameLine::InitStep4Params{
    .hasColorGlyph = hasColorGlyph,
    .ascent = narrow_cast<Float32>(ascent),
    .descent = narrow_cast<Float32>(descent),
    .leading = narrow_cast<Float32>(leading),
    .heightInfo = heightInfo,
    .fastBoundsMinX = -d,
    .fastBoundsMaxX = line.width + d,
    // If we ever change the calculation of the fast bounds such that they no longer are guaranteed
    // to contain the typographic bounds, we will have to adjust the initialization of the
    // vertical search table in TextFrame::TextFrame.
    .fastBoundsLLOMaxY = max(yBounds.end, narrow_cast<Float32>(ascent + leading/2)),
    .fastBoundsLLOMinY = min(yBounds.start, narrow_cast<Float32>(-(descent + leading/2)))
  });

  return lastOriginalStringStyle;
}

void TextFrameLayouter::realignCenteredAndRightAlignedLines() {
  const Float64 frameWidth = inverselyScaledFrameSize_.width;
  for (Int paraIndex = 0; paraIndex < paras_.count(); ++paraIndex) {
    const TextFrameParagraph& para = paras_[paraIndex];
    switch (para.alignment) {
    case STUParagraphAlignmentLeft:
    case STUParagraphAlignmentJustifiedLeft:
      continue; // for
    case STUParagraphAlignmentRight:
    case STUParagraphAlignmentJustifiedRight:
    case STUParagraphAlignmentCenter:
      break; // switch
    }
    const ShapedString::Paragraph& stringPara = stringParas()[paraIndex];
    for (const Int32 lineIndex : para.lineIndexRange().iter()) {
      const Indentations indent{stringPara, para, lineIndex, scaleInfo_};
      TextFrameLine& line = lines_[lineIndex];
      if (para.alignment == STUParagraphAlignmentCenter) {
        line.originX = (frameWidth - line.width)/2 + (indent.left - indent.right);
      } else {  // Align right.
        line.originX = frameWidth - indent.right - line.width;
      }
    }
  }
}

void TextFrameLayouter::justifyLinesWhereNecessary() {
  const Float64 frameWidth = inverselyScaledFrameSize_.width;
  for (Int paraIndex = 0; paraIndex < paras_.count(); ++paraIndex) {
    const TextFrameParagraph& para = paras_[paraIndex];
    if (!isJustified(para)) continue;
    const Range<Int32> lineIndexRange = para.lineIndexRange();
    if (lineIndexRange.isEmpty()) continue;
    // We don't want to justify the last line in a paragraph.
    for (const Int32 lineIndex : Range{lineIndexRange.start, lineIndexRange.end - 1}.iter()) {
      TextFrameLine& line = lines_[lineIndex];
      if (line.isFollowedByTerminatorInOriginalString) continue;
      const Indentations indent{stringParas()[paraIndex], para, lineIndex, scaleInfo_};
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

} // namespace stu_label
