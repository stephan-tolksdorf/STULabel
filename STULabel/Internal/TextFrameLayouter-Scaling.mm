// Copyright 2018 Stephan Tolksdorf

#import "TextFrameLayouter.hpp"

#import "STULabel/STUTextFrameOptions-Internal.hpp"

namespace stu_label {

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

static inline Float32 heightBelowBaselineWithoutExcessSpacing(const TextFrameLine& line) {
  return min(line.heightBelowBaseline,
             line._heightBelowBaselineWithoutSpacing + line.leading/2);
}

/// Does no displayScale rounding.
static Float64 heightWithMinimalSpacingBelowLastBaseline(const TextFrameLayouter& layouter) {
  if (STU_UNLIKELY(layouter.lines().isEmpty())) return 0;
  const TextFrameLine& lastLine = layouter.lines()[$ - 1];
  return lastLine.originY + min(lastLine.heightBelowBaseline,
                                lastLine._heightBelowBaselineWithoutSpacing + lastLine.leading/2);
}

void TextFrameLayouter::layoutAndScale(Size<Float64> frameSize,
                                       const Optional<DisplayScale>& displayScale,
                                       const STUTextFrameOptions* __unsafe_unretained options)
{
  layoutCallCount_ = 0;

  struct State {
    ScaleInfo scaleInfo;
    Size<Float64> inverselyScaledFrameSize;
    /// inverselyScaledFrameSize.height - scaleInfo.displayScale.inverseValue_f64()
    Float64 maxInverselyScaledHeight;
    CGFloat lowerBound;
    CGFloat upperBound;
    bool lowerBoundLayoutIsSaved;
    SavedLayout lowerBoundLayout;
  } state;

  state.scaleInfo = ScaleInfo{
    .originalDisplayScale = displayScale.storage().displayScaleOrZero(),
    .displayScale = displayScale,
    .scale = 1,
    .inverseScale = 1,
    .firstParagraphFirstLineOffset =  0,
    .firstParagraphFirstLineOffsetType = STUOffsetOfFirstBaselineFromDefault,
    .baselineAdjustment = options->_textScalingBaselineAdjustment
  };

  if (originalStringParagraphs().isEmpty()) {
    state.scaleInfo.firstParagraphFirstLineOffset = stringParas_[0].firstLineOffset;
    state.scaleInfo.firstParagraphFirstLineOffsetType = stringParas_[0].firstLineOffsetType;
  }
  const Int32 maxLineCount =    options->_maximumLineCount > 0
                             && options->_maximumLineCount <= maxValue<Int32>
                           ? narrow_cast<Int32>(options->_maximumLineCount) : maxValue<Int32>;
  const Float64 unlimitedHeight = 1 << 30;
  CGFloat minTextScaleFactor = options->_minimumTextScaleFactor;
  const CGFloat minStepSize = CGFloat{1}/16384;
  const bool hasStepSize = options->_textScaleFactorStepSize > minStepSize;
  const CGFloat stepSize = hasStepSize ? options->_textScaleFactorStepSize : minStepSize;
  if (minTextScaleFactor < 1 && hasStepSize) {
    const CGFloat n = nearbyint(minTextScaleFactor/stepSize);
    const CGFloat unrounded = minTextScaleFactor;
    minTextScaleFactor = n*stepSize;
    if (minTextScaleFactor < unrounded) {
      minTextScaleFactor = (n + 1)*stepSize;
    }
  }
  const bool shouldEstimateScaleFactor = minTextScaleFactor < 1;
  layout(Size{frameSize.width,
              shouldEstimateScaleFactor ? unlimitedHeight : frameSize.height},
         state.scaleInfo,
         shouldEstimateScaleFactor ? maxValue<Int32> : maxLineCount,
         options);
  if (!shouldEstimateScaleFactor || isCancelled()) return;
  inverselyScaledFrameSize_.height = frameSize.height;

  if (lines_.count() <= maxLineCount && !mayExceedMaxWidth_ && lastLineFitsFrameHeight()) return;

  state.inverselyScaledFrameSize = frameSize;
  state.lowerBoundLayoutIsSaved = false;
  state.lowerBound = options->_minimumTextScaleFactor;
  state.upperBound = 1;

  const CGFloat accuracy = hasStepSize ? stepSize
                         : narrow_cast<CGFloat>(
                             1/clamp(32, 2*max(frameSize.width, frameSize.height), 2048));
  const CGFloat accuracyPlusEps = accuracy + epsilon<CGFloat>/2;

  const auto estimatedScale = minTextScaleFactor + stepSize >= 1
                            ? ScaleFactorEstimate{minTextScaleFactor, 1}
                            : estimateScaleFactorNeededToFit(frameSize.height, maxLineCount,
                                                             state.lowerBound,
                                                             hasStepSize ? stepSize/2 : accuracy);
  if (estimatedScale.value >= 1 && estimatedScale.isAccurate) return;

  STU_DEBUG_ASSERT(estimatedScale.value >= state.lowerBound);

  const auto [type, offset] = firstLineOffsetForBaselineAdjustment(
                                lines_[0], state.scaleInfo.baselineAdjustment);
  state.scaleInfo.firstParagraphFirstLineOffsetType = type;
  state.scaleInfo.firstParagraphFirstLineOffset = offset;

  const auto updateScaleInfo = [&](CGFloat scale) {
    state.scaleInfo.scale = scale;
    const Float64 inverseScale = 1.0/scale;
    state.scaleInfo.inverseScale = inverseScale;
    state.inverselyScaledFrameSize = inverseScale*Size{frameSize.width, frameSize.height};
    if (state.scaleInfo.originalDisplayScale != 0) {
      state.scaleInfo.displayScale = DisplayScale::create(scale*state.scaleInfo.originalDisplayScale);
      // Reducing the max height by 1 pixel allows us to ignore the display scale rounding, which
      // considerably simplifies the optimization problem.
      state.maxInverselyScaledHeight = state.inverselyScaledFrameSize.height
                                     - state.scaleInfo.displayScale->inverseValue_f64();
    } else {
      state.maxInverselyScaledHeight = state.inverselyScaledFrameSize.height;
    }
  };

  const auto roundDownScale = [&](auto scale) -> CGFloat {
    if (hasStepSize) {
      return floor(narrow_cast<CGFloat>(scale/stepSize))*stepSize;
    } else {
      return floor(narrow_cast<CGFloat>(scale)/minStepSize)*minStepSize;
    }
  };
  const auto roundScale = [&](auto scale) -> CGFloat {
    if (hasStepSize) {
      return nearbyint(narrow_cast<CGFloat>(scale)/stepSize)*stepSize;
    } else {
      return roundDownScale(scale);
    }
  };

  const CGFloat initialScaleFactor = max(state.lowerBound, roundScale(estimatedScale.value));
  if (estimatedScale.isAccurate || initialScaleFactor == state.lowerBound) {
    updateScaleInfo(initialScaleFactor);
    layout(state.inverselyScaledFrameSize, state.scaleInfo, maxLineCount, options);
    if (isCancelled()
        || initialScaleFactor == state.lowerBound
        || (!lines_.isEmpty()
            && (!lines_[$ - 1].hasTruncationToken
                || stringParas_[lines_[$ - 1].paragraphIndex].truncationScopeIndex >= 0)))
    {
      return;
    }
  }

  const auto updateScaleInfoAndLayout = [&](CGFloat scale) {
    updateScaleInfo(scale);
    Float64 height = unlimitedHeight;
    Int32 lineCount = maxValue<Int32>;
    if (scale <= minTextScaleFactor) {
      height = state.inverselyScaledFrameSize.height;
      lineCount = maxLineCount;
    }
    layout(Size{state.inverselyScaledFrameSize.width, height}, state.scaleInfo, lineCount,
           options);
    inverselyScaledFrameSize_.height = state.inverselyScaledFrameSize.height;
  };
  const auto fits = [&]{
    if (lines_.count() > maxLineCount) return false;
    const Float64 height = heightWithMinimalSpacingBelowLastBaseline(*this);
    return height <= state.maxInverselyScaledHeight;
    // We shouldn't have to check the line widths here (after the initial scale factor estimate).
  };
  const auto updateLowerBound = [&]() -> bool {
    state.lowerBound = state.scaleInfo.scale;
    const Float64 m = calculateMaxScaleFactorForCurrentLineBreaks(state.maxInverselyScaledHeight);
    if (m > 1) {
      const CGFloat scale = roundDownScale(state.lowerBound*m);
      if (scale > state.lowerBound) {
        state.lowerBound = scale;
        updateScaleInfo(scale);
        scaleInfo_ = state.scaleInfo;
        inverselyScaledFrameSize_ = state.inverselyScaledFrameSize;
      }
    }
    const CGFloat lowerBoundPlusAccuracy = state.lowerBound + accuracyPlusEps;
    if (lowerBoundPlusAccuracy >= state.upperBound || isCancelled()) return false;
    state.lowerBoundLayoutIsSaved = true;
    saveLayoutTo(state.lowerBoundLayout);
    return true;
  };
  const auto updateUpperBound = [&]() -> bool {
    state.upperBound = state.scaleInfo.scale;
    if (isCancelled()) return false;
    if (state.lowerBound + accuracyPlusEps >= state.upperBound) {
      if (state.lowerBoundLayoutIsSaved) {
        restoreLayoutFrom(std::move(state.lowerBoundLayout));
      } else {
        updateScaleInfoAndLayout(state.lowerBound);
      }
      return false;
    }
    return true;
  };

  if (!estimatedScale.isAccurate) {
    updateScaleInfoAndLayout(initialScaleFactor);
  }

  CGFloat nextScale;
  if (!estimatedScale.isAccurate && fits()) {
    if (!updateLowerBound()) return;
    updateScaleInfoAndLayout(state.lowerBound + accuracy);
    if (!fits()) {
      restoreLayoutFrom(std::move(state.lowerBoundLayout));
      return;
    }
    if (!updateLowerBound()) return;
    nextScale = min(state.lowerBound + max(1/64.f, 2*accuracy),
                    (state.lowerBound + state.upperBound)/2);
  } else {
    if (!updateUpperBound()) return;
    if (hasStepSize) {
      updateScaleInfoAndLayout(state.upperBound - accuracy);
      if (fits()) return;
      if (!updateUpperBound()) return;
    }
    nextScale = max(state.upperBound - max(1/64.f, 2*accuracy),
                    (state.lowerBound + state.upperBound)/2);
  }
  for (;;) {
    if (hasStepSize) {
      nextScale = roundScale(nextScale);
    }
    updateScaleInfoAndLayout(nextScale);
    if (fits()) {
      if (!updateLowerBound()) return;
    } else {
      if (!updateUpperBound()) return;
    }
    nextScale = (state.lowerBound + state.upperBound)/2;
  }
}

static
Float64 computeWidth(CTTypesetter* typesetter, Range<Int32> stringRange, Float64 headIndent) {
  const RC<CTLine> ctLine{CTTypesetterCreateLineWithOffset(typesetter, stringRange, headIndent),
                          ShouldIncrementRefCount{false}};
  return CTLineGetTypographicBounds(ctLine.get(), nullptr, nullptr, nullptr);
}

class TextScalingHeap {
public:
  struct Paragraph {
    Float64 scale_lower;
    Float64 scale_upper;
    Int32 minLastLineStartIndex; ///< At scale == scale_upper.
    Int32 maxLastLineStartIndex; ///< At scale == scale_lower.
    Int32 lineCount; ///< At scale == scale_lower.
    Int32 oldLineCount;
    Int32 secondToLastLineStartIndex; ///< At scale == scale_lower.
    const Int32 initialLinesCount;
    const Float64 lineHeight;
    const Range<Int32> stringRange;
    const Float64 commonHeadIndent;
    const CGFloat initialExtraHeadIndent;
    const CGFloat initialExtraTailIndent;
    const Float64 maxWidthMinusCommonIndent;

    struct InitialParams {
      Range<Int32> stringRange;
      Int32 lineCount;
      Int32 secondToLastLineStartIndex;
      Int32 initialLinesCount;
      Float64 lineHeight;
      Float64 commonHeadIndent;
      CGFloat initialExtraHeadIndent;
      CGFloat initialExtraTailIndent;
      Float64 maxWidthMinusCommonIndent;
    };

    /* implicit */ Paragraph(InitialParams p)
    : scale_lower{1}, scale_upper{1},
      minLastLineStartIndex{p.secondToLastLineStartIndex},
      maxLastLineStartIndex{p.stringRange.end},
      lineCount{p.lineCount},
      oldLineCount{p.lineCount},
      secondToLastLineStartIndex{p.secondToLastLineStartIndex},
      initialLinesCount{p.initialLinesCount},
      lineHeight{p.lineHeight},
      stringRange{p.stringRange},
      commonHeadIndent{p.commonHeadIndent},
      initialExtraHeadIndent{p.initialExtraHeadIndent},
      initialExtraTailIndent{p.initialExtraTailIndent},
      maxWidthMinusCommonIndent{p.maxWidthMinusCommonIndent}
    {}

    void reduceLineCount(CTTypesetter* const typesetter, const NSStringRef& string) {
      STU_DEBUG_ASSERT(lineCount > 2 || secondToLastLineStartIndex == stringRange.start);
      oldLineCount = lineCount;
      lineCount -= 1;
      // We compute an approximate lower bound for the scale factor by estimating the scale
      // needed to fit the text of the two last lines into the space available for the second to
      // last line.
      Float64 indent = commonHeadIndent;
      if (indent != 0 && scale_upper != 1) {
        // The indentation in the inversely scaled coordinate system depends on the scale factor
        // that we want to estimate. We use the old scale factor here in the hope that the
        // difference doesn't matter too much.
        indent /= scale_upper;
      }
      Float64 extraIndent = 0;
      if (lineCount > initialLinesCount) {
        if (initialExtraHeadIndent < 0) {
          extraIndent = -initialExtraHeadIndent;
          indent += extraIndent;
        }
        if (initialExtraTailIndent < 0) {
          extraIndent -= initialExtraTailIndent;
        }
      } else {
        if (initialExtraHeadIndent > 0) {
          extraIndent = initialExtraHeadIndent;
          indent += extraIndent;
        }
        if (initialExtraTailIndent > 0) {
          extraIndent += initialExtraTailIndent;
        }
      }
      const Float64 w = computeWidth(typesetter,
                                     Range{secondToLastLineStartIndex, stringRange.end}, indent);
      scale_upper = scale_lower;
      scale_lower = maxWidthMinusCommonIndent/(w + extraIndent);
      if (lineCount == 1 && commonHeadIndent == 0) {
        minLastLineStartIndex = stringRange.start;
        maxLastLineStartIndex = stringRange.start;
        scale_upper = scale_lower;
        return;
      } else {
        minLastLineStartIndex = secondToLastLineStartIndex;
        maxLastLineStartIndex = stringRange.end;
      }
      // TODO: Tune this.
      const Float64 firstEstimate = lineCount <= 2 ? scale_lower
                                    : scale_lower
                                      + (scale_upper - scale_lower)
                                        *(2/3. - 1/static_cast<Float32>(lineCount - 1));
      if (!bisectScaleInterval(firstEstimate, typesetter, string)) {
        if (firstEstimate == scale_lower
            || !bisectScaleInterval(scale_lower, typesetter, string))
        {
          scale_lower = 0;
          lineCount = 1;
        }
      }
    }

    bool bisectScaleInterval(CTTypesetter* const typesetter, const NSStringRef& string) {
      return bisectScaleInterval((scale_lower + scale_upper)/2,
                                            typesetter, string);
    }

    /// Returns true if the lower bound has been updated.
    ///
    /// This function currently does not account for hyphenation opportunities. Implementing that
    /// currently doesn't seem worth the effort (as long as CTTypesetter has no built-in support
    /// for hyphenation).
    bool bisectScaleInterval(Float64 scale, CTTypesetter* const typesetter,
                             const NSStringRef& string)
    {
      STU_DEBUG_ASSERT(scale_lower <= scale && scale < scale_upper);
      const Float64 inverseScale = 1.0/scale;

      Float64 initialHeadIndent = commonHeadIndent*inverseScale;
      Float64 nonInitialHeadIndent = initialHeadIndent;
      Float64 initialMaxWidth = maxWidthMinusCommonIndent*inverseScale;
      Float64 nonInitialMaxWidth = initialMaxWidth;
      if (initialExtraHeadIndent != 0) {
        const Float64 extraHeadIndent = initialExtraHeadIndent;
        if (initialExtraHeadIndent > 0) {
          initialMaxWidth -= extraHeadIndent;
          initialHeadIndent += extraHeadIndent;
        } else {
          nonInitialMaxWidth += extraHeadIndent;
          nonInitialHeadIndent -= extraHeadIndent;
        }
      }
      if (initialExtraTailIndent != 0) {
        const Float64 extraTailIndent = initialExtraTailIndent;
        if (initialExtraTailIndent > 0) {
          initialMaxWidth -= extraTailIndent;
        } else {
          nonInitialMaxWidth += extraTailIndent;
        }
      }
      Int32 index = stringRange.start;
      Int32 endIndex = index;
      for (Int32 n = 1;; ++n) {
        const Int32 previousIndex = index;
        index = endIndex;
        const Float64 maxWidth = n <= initialLinesCount ? initialMaxWidth : nonInitialMaxWidth;
        const Float64 headIndent = n <= initialLinesCount ? initialHeadIndent : nonInitialHeadIndent;
        endIndex = index + narrow_cast<Int32>(CTTypesetterSuggestLineBreakWithOffset(
                                                typesetter, index, maxWidth, headIndent));
        if (STU_UNLIKELY(endIndex <= index)) {
          endIndex = narrow_cast<Int32>(string.endIndexOfGraphemeClusterAt(index));
        }
        if (endIndex >= stringRange.end) {
          scale_lower = scale;
          lineCount = n;
          secondToLastLineStartIndex = previousIndex;
          maxLastLineStartIndex = index;
          return true;
        } else if (n + 1 == oldLineCount) {
          scale_upper = scale;
          minLastLineStartIndex = index;
          return false;
        }
      }
    }
  };

private:
  STU_INLINE
  auto paragraphIndexComparison() {
    return [&](Int32 i1, Int32 i2) -> bool {
             auto& p1 = paragraphs_[i1];
             auto& p2 = paragraphs_[i2];
             return p1.scale_upper <  p2.scale_upper
                || (p1.scale_upper == p2.scale_upper
                    // We want to reduce the wider interval first.
                    && p1.scale_lower > p2.scale_lower);
           };
  }

public:
  /// Keeps a reference to the passed in paragraphs array.
  explicit STU_INLINE
  TextScalingHeap(ArrayRef<Paragraph> paragraphs)
  : paragraphs_{paragraphs},
    indices_{Capacity{paragraphs_.count()}}
  {
    for (Int i = 0; i < paragraphs_.count(); ++i) {
      indices_.append(static_cast<Int32>(i));
    }
    std::make_heap(indices_.begin(), indices_.end(), paragraphIndexComparison());
  }

  bool isEmpty() const {
    return indices_.isEmpty();
  }

  const Paragraph* __nullable peekParagraphWithLargestUpperBound() const {
    return indices_.isEmpty() ? nullptr : &paragraphs_[indices_[0]];
  }

  Paragraph* __nullable popParagraphWithMaxScaleUpperBound() {
    if (isEmpty()) return nullptr;
    Paragraph* const para = &paragraphs_[indices_[0]];
    std::pop_heap(indices_.begin(), indices_.end(), paragraphIndexComparison());
    indices_.removeLast();
    return para;
  }

  void pushParagraph(Paragraph* para) {
    STU_DEBUG_ASSERT(paragraphs_.begin() <= para && para < paragraphs_.end());
    const Int32 index = narrow_cast<Int32>(para - paragraphs_.begin());
    indices_.append(index);
    std::push_heap(indices_.begin(), indices_.end(), paragraphIndexComparison());
  }

private:
  const ArrayRef<Paragraph> paragraphs_;
  TempVector<Int32> indices_;
};

} // namespace stu_label

template <> struct stu::IsBitwiseCopyable<stu_label::TextScalingHeap::Paragraph> : True {};

namespace stu_label {

STU_NO_INLINE
Float64 TextFrameLayouter::estimateTailTruncationTokenWidth(const TextFrameLine& line) const {
  // TODO: Compute the token exactly like in TextFrameLayouter::truncateLine, ideally by using
  //       a common utility function.
  NSAttributedString* __unsafe_unretained originalToken = options_.truncationToken;
  const auto& stringPara = stringParas_[line.paragraphIndex];
  if (stringPara.truncationScopeIndex >= 0) {
    const auto& truncationScope = truncationScopes_[stringPara.truncationScopeIndex];
    if (truncationScope.stringRange.end >= stringRange_.end) {
      originalToken = truncationScope.truncationToken;
    }
  }
  auto* const attributes = attributedString_.attributesAtIndex(line.rangeInOriginalString.end - 1);
  NSAttributedString* token;
  if (!originalToken) {
    token = [[NSAttributedString alloc] initWithString:@"" attributes:attributes];
  } else {
    NSMutableAttributedString* mutableToken = [originalToken mutableCopy];
    TextFrameLayouter::addAttributesNotYetPresentInAttributedString(
                         mutableToken, NSRange{0, mutableToken.length}, attributes);
    token = mutableToken;
  }
  const RC<CTLine> ctLine{CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)token),
                          ShouldIncrementRefCount{false}};
  return CTLineGetTypographicBounds(ctLine.get(), nullptr, nullptr, nullptr);
}

auto TextFrameLayouter::estimateScaleFactorNeededToFit(Float64 frameHeight, Int32 maxLineCount,
                                                       Float64 minScale, Float64 accuracy) const
-> ScaleFactorEstimate
{
  ArrayRef<const TextFrameLine> lines = lines_;
  if (lines.isEmpty()) return {1, true};

  Float64 scale = 1;
  if (STU_UNLIKELY(mayExceedMaxWidth_)) {
    const Float64 frameWidth = inverselyScaledFrameSize_.width;
    const Float64 inverseScale = scaleInfo_.inverseScale;
    Int32 lineIndex = 0;
    for (auto& para : paras_) {
      if (STU_UNLIKELY(lineIndex == para.lineIndexRange().end)) continue;
      const ShapedString::Paragraph& p = stringParas_[para.paragraphIndex];
      Float64 initialExtraIndent = 0;
      Float64 nonInitialExtraIndent = 0;
      Float64 maxWidth = frameWidth;
      if (STU_UNLIKELY(p.isIndented)) {
        maxWidth -= (p.commonLeftIndent*inverseScale + p.commonRightIndent*inverseScale);
        initialExtraIndent = max(0.f, p.initialExtraLeftIndent)
                            + max(0.f, p.initialExtraRightIndent);
        nonInitialExtraIndent = max(0.f, -p.initialExtraLeftIndent)
                              + max(0.f, -p.initialExtraRightIndent);
      }
      if (maxWidth <= 0) return {minScale, true};;
      do {
        const Float64 width = (lineIndex < para.initialLinesEndIndex
                               ? initialExtraIndent : nonInitialExtraIndent)
                            + lines[lineIndex].width;
        if (width > maxWidth) {
          scale = min(scale, maxWidth/width);
          if (scale <= minScale) {
            return {minScale, true};
          }
        }
      } while (++lineIndex != para.lineIndexRange().end);
    }
    if (scale == 1 && lastLineFitsFrameHeight()) {
      return {1, true};
    }
  }

  if (const auto& displayScale = scaleInfo_.displayScale) {
    frameHeight -= displayScale->inverseValue_f64();
  }

  Float64 height = heightWithMinimalSpacingBelowLastBaseline(*this);
  if (scale*height <= frameHeight && lines.count() <= maxLineCount) {
    return {scale, true};
  }
  STU_ASSERT(maxLineCount > 0);

  const Float64 firstLineOffset = scaleInfo_.scale == 1
                                ? firstLineOffsetForBaselineAdjustment(
                                    lines[0], scaleInfo_.baselineAdjustment).second
                                : scaleInfo_.firstParagraphFirstLineOffset*scaleInfo_.inverseScale;
  frameHeight -= firstLineOffset;
  height -= firstLineOffset;
  if (frameHeight <= 0 || height <= 0 || inverselyScaledFrameSize_.width <= 0) {
    return {minScale, true};
  }

  minScale = max(minScale, frameHeight/height);

  Int32 lineCount = narrow_cast<Int32>(lines_.count());

  if (lineCount > maxLineCount) {
    // Note that a paragraph may contain multiple forced line breaks (e.g. U+2028).
    Int32 newlineCount = 0;
    Int linesEndIndex = lines.count();
    for (auto& line : lines) {
      if (line.isFollowedByTerminatorInOriginalString) {
        ++newlineCount;
        if (newlineCount < maxLineCount) continue;
        if (newlineCount > maxLineCount) break;
        linesEndIndex = line.lineIndex;
      }
    }
    if (!lines[$ - 1].isFollowedByTerminatorInOriginalString) {
      ++newlineCount;
    }
    if (newlineCount >= maxLineCount) {
      Float64 lastLineExtraWidth = 0;
      if (STU_UNLIKELY(linesEndIndex < lines.count())) {
        lines = lines[{0, linesEndIndex}];
        const TextFrameLine& lastLine = lines[$ - 1];
        if (!lastLine.hasTruncationToken) {
          lastLineExtraWidth = estimateTailTruncationTokenWidth(lastLine);
        }
      }
      for (Int i0 = 0, i = 0; i < lines.count(); i0 = i) {
        do {
          if (lines[i++].isFollowedByTerminatorInOriginalString) break;
        } while (i < lines.count());
        if (i == i0 + 1) continue;
        const ArrayRef<const TextFrameLine> paraLines = lines[{i0, i}];
        // The paragraph was broken into multiple lines.
        const TextFrameLine& firstLine = paraLines[0];
        const TextFrameLine& lastLine = paraLines[$ - 1];
        const bool isInitialLine = i0 < paras_[firstLine.paragraphIndex].initialLinesEndIndex;
        const ShapedString::Paragraph& p = stringParas_[firstLine.paragraphIndex];
        Float64 headIndent = 0;
        Float64 extraIndent = 0;
        Float64 maxWidth = inverselyScaledFrameSize_.width;
        if (STU_UNLIKELY(p.isIndented)) {
          const Float64 commonLeftIndent = p.commonLeftIndent*scaleInfo_.inverseScale;
          const Float64 commonRightIndent = p.commonRightIndent*scaleInfo_.inverseScale;
          maxWidth -= commonLeftIndent + commonRightIndent;
          Float64 extraIndentLeft;
          Float64 extraIndentRight;
          if (isInitialLine) {
            extraIndentLeft = max(0.f, p.initialExtraLeftIndent);
            extraIndentRight = max(0.f, p.initialExtraRightIndent);
          } else {
            extraIndentLeft = max(0.f, -p.initialExtraLeftIndent);
            extraIndentRight = max(0.f, -p.initialExtraRightIndent);
          }
          extraIndent = extraIndentLeft + extraIndentRight;
          headIndent = p.baseWritingDirection == STUWritingDirectionLeftToRight
                     ? commonLeftIndent + extraIndentLeft
                     : commonRightIndent + extraIndentRight;
        }
        if (maxWidth <= extraIndent || isCancelled()) return {minScale, true};
        const Range<Int32> range{firstLine.rangeInOriginalString.start,
                                 lastLine.rangeInOriginalString.end};
        const Float64 width = extraIndent
                            + (i == lines.count() ? lastLineExtraWidth : 0)
                            + computeWidth(typesetter_, range, headIndent);
        if (width > 0) {
          scale = min(scale, maxWidth/width);
          if (scale <= minScale) {
            return {minScale, true};
          }
        }
        const Float32 lastLineHeightBelowBaseline =
                        !lastLine.isLastLine ? lastLine.heightBelowBaseline
                        : heightBelowBaselineWithoutExcessSpacing(lastLine);
        Float32 maxHeightAboveBaseline = 0;
        Float32 maxHeightBelowBaseline = 0;
        for (auto& line : paraLines[{0, $ - 1}]) {
          maxHeightAboveBaseline = max(maxHeightAboveBaseline, line.heightAboveBaseline);
          maxHeightBelowBaseline = max(maxHeightBelowBaseline, line.heightBelowBaseline);
        }
        maxHeightAboveBaseline = max(maxHeightAboveBaseline, lastLine.heightAboveBaseline);
        maxHeightBelowBaseline = max(maxHeightBelowBaseline, lastLineHeightBelowBaseline);
        // Estimate the height that would be saved if the frame were wide enough for the whole
        // paragraph to fit into a single line.
        const Float64 d = (lastLine.originY - firstLine.originY)
                        + (firstLine.heightAboveBaseline + lastLineHeightBelowBaseline
                           - (maxHeightAboveBaseline + maxHeightBelowBaseline));
        height -= d;
      } // for (;;)
      if (frameHeight < scale*height) {
        scale = max(minScale, frameHeight/height);
      }
      return {scale, true};
    }
  }

  // Our "Para" segments here are separated by any kind of line terminator,
  // not just paragraph separators.
  using Para = TextScalingHeap::Paragraph;

  bool multiLineParaHasHyphenation = false;

  TempVector<Para> paras{freeCapacityInCurrentThreadLocalAllocatorBuffer};
  for (Int32 i0 = 0, i = 0; i < lines.count(); i0 = i) {
    while (!lines[i++].isFollowedByTerminatorInOriginalString && i < lines.count()) {
      continue;
    }
    const Int32 n = i - i0;
    if (n == 1) continue;
    // The para was broken into multiple lines.
    const STUTextFrameLine& firstLine = lines[i0];
    const STUTextFrameLine& lastLine = lines[i - 1];
    // If the paragraph was truncated due to a truncation scope, we ignore it here.
    if (lastLine.hasTruncationToken) continue;
    const Int32 initialLinesEndIndex = paras_[firstLine.paragraphIndex].initialLinesEndIndex;
    const ShapedString::Paragraph& p = stringParas_[firstLine.paragraphIndex];
    multiLineParaHasHyphenation |= p.hyphenationFactor > 0;
    Float64 commonHeadIndent = 0;
    CGFloat initialExtraHeadIndent = 0;
    CGFloat initialExtraTailIndent = 0;
    Float64 maxWidthMinusCommonIndent = inverselyScaledFrameSize_.width;
    if (STU_UNLIKELY(p.isIndented)) {
      const Float64 commonLeftIndent = p.commonLeftIndent*scaleInfo_.inverseScale;
      const Float64 commonRightIndent = p.commonRightIndent*scaleInfo_.inverseScale;
      const bool isLTR = p.baseWritingDirection == STUWritingDirectionLeftToRight;
      commonHeadIndent = isLTR ? commonLeftIndent : commonRightIndent;
      maxWidthMinusCommonIndent -= commonLeftIndent + commonRightIndent;
      initialExtraHeadIndent = isLTR ? p.initialExtraLeftIndent : p.initialExtraRightIndent;
      initialExtraTailIndent = isLTR ? p.initialExtraRightIndent : p.initialExtraLeftIndent;
    }
    Int32 initialLinesCount;
    if (firstLine.lineIndex < initialLinesEndIndex) {
      initialLinesCount = min(i, initialLinesEndIndex) - i0;
    } else {
      initialLinesCount = n;
      initialExtraHeadIndent = max(0.f, -initialExtraHeadIndent);
      initialExtraTailIndent = max(0.f, -initialExtraTailIndent);
    }
    paras.append(Para{{.stringRange = {firstLine.rangeInOriginalString.start,
                                       lastLine.rangeInOriginalString.end},
                       .lineCount = n,
                       .initialLinesCount = initialLinesCount,
                       .secondToLastLineStartIndex = n == 2
                                                   ? firstLine.rangeInOriginalString.start
                                                   : lines[i - 2].rangeInOriginalString.start,
                       .lineHeight = (lastLine.originY - firstLine.originY)/(n - 1),
                       .commonHeadIndent = commonHeadIndent,
                       .initialExtraHeadIndent = initialExtraHeadIndent,
                       .initialExtraTailIndent = initialExtraTailIndent,
                       .maxWidthMinusCommonIndent = maxWidthMinusCommonIndent}});
    paras[$ - 1].reduceLineCount(typesetter_, attributedString_.string);
    if (isCancelled()) break;
  }
  paras.trimFreeCapacity();
  for (TextScalingHeap heap{paras};;) {
    Para* const para = heap.popParagraphWithMaxScaleUpperBound();
    if (STU_UNLIKELY(!para || para->scale_upper <= minScale || isCancelled())) {
    ReturnMinScale:
      return {minScale, !para && !multiLineParaHasHyphenation};
    }
    const Int32 d = para->oldLineCount - para->lineCount;
    const Int32 nextLineCount = lineCount - d;
    const Float64 nextHeight = height - d*para->lineHeight;
    if (para->scale_lower < scale
        && para->scale_lower + accuracy < para->scale_upper)
    {
      const Para* const nextPara = heap.peekParagraphWithLargestUpperBound();
      const bool nextParaScaleOverlaps = nextPara && para->scale_lower < nextPara->scale_upper;
      if (nextParaScaleOverlaps
          || (((nextLineCount <= maxLineCount && para->scale_lower*nextHeight <= frameHeight)
               || para->scale_lower <= minScale)
              && para->minLastLineStartIndex != para->maxLastLineStartIndex))
      {
        const Float64 m = (para->scale_lower + para->scale_upper)/2;
        para->bisectScaleInterval(!nextParaScaleOverlaps ? m : min(nextPara->scale_upper, m),
                                  typesetter_, attributedString_.string);
        if (nextPara
            && para->scale_upper >= nextPara->scale_upper
            && para->scale_lower < nextPara->scale_upper
            && nextPara->scale_lower + accuracy < nextPara->scale_upper
            && !isCancelled())
        {
          Para* const next = heap.popParagraphWithMaxScaleUpperBound();
          STU_DEBUG_ASSERT(next == nextPara);
          next->bisectScaleInterval(max((next->scale_lower + next->scale_upper)/2,
                                        para->scale_lower),
                                    typesetter_, attributedString_.string);
          heap.pushParagraph(next);
        }
        heap.pushParagraph(para);
        continue;
      }
    }
    if (STU_UNLIKELY(para->scale_lower <= minScale)) goto ReturnMinScale;
    scale = min(scale, para->scale_lower);
    lineCount = nextLineCount;
    height = nextHeight;
    if (lineCount <= maxLineCount && scale*height <= frameHeight) {
      return {scale, para->lineCount == 1 && heap.isEmpty() && !multiLineParaHasHyphenation};
    }
    minScale = frameHeight/height;
    if (para->lineCount != 1 && !isCancelled()) {
      para->reduceLineCount(typesetter_, attributedString_.string);
      heap.pushParagraph(para);
    }
  } // for (;;)
}

Float64 TextFrameLayouter::calculateMaxScaleFactorForCurrentLineBreaks(Float64 maxHeight) const {
  if (STU_UNLIKELY(lines_.isEmpty())) return 1;
  const Float64 height = heightWithMinimalSpacingBelowLastBaseline(*this);
  Float64 scale = height <= 0 ? 1 : maxHeight/height;
  if (scale <= 1) return scale;
  const Float64 frameWidth = inverselyScaledFrameSize_.width;
  const Float64 inverseScale = scaleInfo_.inverseScale;
  Int32 i = 0;
  for (const TextFrameParagraph& para : paras_) {
    STU_DEBUG_ASSERT(i == para.lineIndexRange().start);
    if (STU_UNLIKELY(i == para.lineIndexRange().end)) continue;
    const ShapedString::Paragraph& p = stringParas_[para.paragraphIndex];
    Float64 maxWidth = frameWidth;
    CGFloat initialExtraIndent = 0;
    CGFloat nonInitialExtraIndent = 0;
    if (STU_UNLIKELY(para.isIndented)) {
      maxWidth -= p.commonLeftIndent*inverseScale + p.commonRightIndent*inverseScale;
      initialExtraIndent = max(0.f, p.initialExtraLeftIndent)
                         + max(0.f, p.initialExtraRightIndent);
      nonInitialExtraIndent = max(0.f, -p.initialExtraLeftIndent)
                            + max(0.f, -p.initialExtraRightIndent);
    }
    STU_DEBUG_ASSERT(i < para.initialLinesEndIndex);
    {
      Float32 width = lines_[i].width;
      while (++i != para.initialLinesEndIndex) {
        width = max(width, lines_[i].width);
      }
      width += initialExtraIndent;
      if (width > 0) {
        scale = min(scale, maxWidth/width);
      }
    }
    if (i != para.lineIndexRange().end) {
      Float32 width = lines_[i].width;
      while (++i != para.lineIndexRange().end) {
        width = max(width, lines_[i].width);
      }
      width += nonInitialExtraIndent;
      if (width > 0) {
        scale = min(scale, maxWidth/width);
      }
    }
  }
  return max(0, scale);
}

} // namespace stu_label
