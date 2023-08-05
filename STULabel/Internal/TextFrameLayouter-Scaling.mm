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
            firstLine.originY
            - (firstLine._heightAboveBaseline - firstLine._heightBelowBaseline)/2};
  case STUBaselineAdjustmentAlignFirstLineXHeightCenter:
    return {STUOffsetOfFirstLineXHeightCenterFromTop,
            firstLine.originY - firstLine.maxFontMetricValue<FontMetric::xHeight>()/2};
  case STUBaselineAdjustmentAlignFirstLineCapHeightCenter:
    return {STUOffsetOfFirstLineCapHeightCenterFromTop,
            firstLine.originY - firstLine.maxFontMetricValue<FontMetric::capHeight>()/2};
  }
}

static inline Float32 heightBelowBaselineWithoutExcessSpacing(const TextFrameLine& line) {
  return min(line._heightBelowBaseline,
             line._heightBelowBaselineWithoutSpacing + line.leading/2);
}

/// Does no displayScale rounding.
static Float64 heightWithMinimalSpacingBelowLastBaseline(const TextFrameLayouter& layouter) {
  if (STU_UNLIKELY(layouter.lines().isEmpty())) return 0;
  const TextFrameLine& lastLine = layouter.lines()[$ - 1];
  return lastLine.originY + min(lastLine._heightBelowBaseline,
                                lastLine._heightBelowBaselineWithoutSpacing
                                + layouter.minimalSpacingBelowLastLine());
}

void TextFrameLayouter::layoutAndScale(Size<Float64> frameSize,
                                       const Optional<DisplayScale>& displayScale,
                                       const TextFrameOptions& options)
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
    .firstParagraphFirstLineOffset = 0,
    .firstParagraphFirstLineOffsetType = STUOffsetOfFirstBaselineFromDefault,
    .baselineAdjustment = options.textScalingBaselineAdjustment
  };

  if (!stringParas().isEmpty()) {
    state.scaleInfo.firstParagraphFirstLineOffset = stringParas()[0].firstLineOffset;
    state.scaleInfo.firstParagraphFirstLineOffsetType = stringParas()[0].firstLineOffsetType;
  }
  const Int32 maxLineCount =    options.maximumNumberOfLines > 0
                             && options.maximumNumberOfLines <= maxValue<Int32>
                           ? narrow_cast<Int32>(options.maximumNumberOfLines) : maxValue<Int32>;
  const Float64 unlimitedHeight = 1 << 30;
  CGFloat minTextScaleFactor = options.minimumTextScaleFactor;
  const CGFloat minStepSize = CGFloat{1}/16384;
  const bool hasStepSize = options.textScaleFactorStepSize > minStepSize;
  const CGFloat stepSize = hasStepSize ? options.textScaleFactorStepSize : minStepSize;
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
  state.lowerBound = options.minimumTextScaleFactor;
  state.upperBound = 1;

  const CGFloat accuracy = hasStepSize ? stepSize
                         : narrow_cast<CGFloat>(
                             1/clamp(32, 2*max(frameSize.width, frameSize.height), 2048));
  const CGFloat accuracyPlusEps = accuracy + epsilon<CGFloat>/2;

  const auto estimatedScale = minTextScaleFactor + stepSize >= 1
                            ? ScaleFactorEstimate{minTextScaleFactor, 1}
                            : estimateScaleFactorNeededToFit(frameSize.height, maxLineCount,
                                                             options.fixedTruncationToken,
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
                || stringParas()[lines_[$ - 1].paragraphIndex].truncationScopeIndex >= 0)))
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
    const auto r = calculateMaxScaleFactorForCurrentLineBreaks(state.maxInverselyScaledHeight);
    if (r.scaleFactor > 1) {
      const CGFloat scale = roundDownScale(state.lowerBound*r.scaleFactor);
      if (scale > state.lowerBound) {
        state.lowerBound = scale;
        updateScaleInfo(scale);
        scaleInfo_ = state.scaleInfo;
        inverselyScaledFrameSize_ = state.inverselyScaledFrameSize;
        realignCenteredAndRightAlignedLines();
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

STU_NO_INLINE
Float64 TextFrameLayouter::estimateTailTruncationTokenWidth(const TextFrameLine& line,
                                                            NSAttributedString* __unsafe_unretained
                                                              originalTruncationToken) const

{
  // TODO: Compute the token exactly like in TextFrameLayouter::truncateLine, ideally by using
  //       a common utility function.
  const auto& stringPara = stringParas()[line.paragraphIndex];
  if (stringPara.truncationScopeIndex >= 0) {
    const auto& truncationScope = truncationScopes_[stringPara.truncationScopeIndex];
    if (truncationScope.stringRange.end >= stringRange_.end) {
      originalTruncationToken = truncationScope.truncationToken;
    }
  }
  auto* const attributes = attributedString_.attributesAtIndex(line.rangeInOriginalString.end - 1);
  NSAttributedString* token;
  if (!originalTruncationToken) {
    token = [[NSAttributedString alloc] initWithString:@"…" attributes:attributes];
  } else {
    NSMutableAttributedString* mutableToken = [originalTruncationToken mutableCopy];
    TextFrameLayouter::addAttributesNotYetPresentInAttributedString(
                         mutableToken, NSRange{0, mutableToken.length}, attributes);
    token = mutableToken;
  }
  const RC<CTLine> ctLine{CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)token),
                          ShouldIncrementRefCount{false}};
  return CTLineGetTypographicBounds(ctLine.get(), nullptr, nullptr, nullptr);
}

struct ScalingPara {
  Int32 minLineCount{1};
  Int32 maxLineCount;
  Int32 lineCount;
  const Int32 originalLineCount;
  const Int32 initialLinesCount;
  Float64 singleLineInverseScale{0};
  const Float64 lineHeight;
  const Range<Int32> stringRange;
  const Float64 commonHeadIndent;
  const CGFloat initialExtraHeadIndent;
  const CGFloat initialExtraTailIndent;
  const Float64 maxWidthMinusCommonIndent;

  /// This function currently does not account for hyphenation opportunities. Implementing that
  /// currently doesn't seem worth the effort (as long as CTTypesetter has no built-in support
  /// for hyphenation).
  void bisectInverseScaleInterval(bool lineCountIsLowerBound, Float64 inverseScale,
                                  CTTypesetter* const typesetter, const NSStringRef& string)
  {
    if (lineCountIsLowerBound) {
      minLineCount = lineCount;
    } else {
      maxLineCount = lineCount;
    }
    if (minLineCount == maxLineCount) return;
    if (maxLineCount == 2 && commonHeadIndent == 0) {
      if (singleLineInverseScale == 0) {
        const Float64 initialHeadIndent = max(0.f, initialExtraHeadIndent);
        const Float64 initialTailIndent = max(0.f, initialExtraTailIndent);
        const Float64 w = computeWidth(typesetter, stringRange,
                                       max(0.f, initialExtraHeadIndent));
        singleLineInverseScale = (initialHeadIndent + initialTailIndent + w)
                                 /maxWidthMinusCommonIndent;
      }
      lineCount = 1 + (inverseScale < singleLineInverseScale);
      return;
    }

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
    for (Int32 n = 1, index = stringRange.start, endIndex;; ++n, index = endIndex) {
      const Float64 maxWidth = n <= initialLinesCount ? initialMaxWidth : nonInitialMaxWidth;
      const Float64 headIndent = n <= initialLinesCount ? initialHeadIndent : nonInitialHeadIndent;
      endIndex = index + narrow_cast<Int32>(CTTypesetterSuggestLineBreakWithOffset(
                                              typesetter, index, maxWidth, headIndent));
      if (STU_UNLIKELY(endIndex <= index)) {
        endIndex = narrow_cast<Int32>(string.endIndexOfGraphemeClusterAt(index));
      }
      if (endIndex >= stringRange.end) {
        lineCount = n;
        return;
      } else if (n + 1 == maxLineCount) {
        lineCount = maxLineCount;
        return;
      }
    }
  }
};

} // namespace stu_label

template <> struct stu::IsBitwiseMovable<stu_label::ScalingPara> : True {};

namespace stu_label {

auto TextFrameLayouter::estimateScaleFactorNeededToFit(Float64 frameHeight, Int32 maxLineCount,
                                                       NSAttributedString* __unsafe_unretained
                                                         truncationToken,
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
      const ShapedString::Paragraph& p = stringParas()[para.paragraphIndex];
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
          lastLineExtraWidth = estimateTailTruncationTokenWidth(lastLine, truncationToken);
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
        const ShapedString::Paragraph& p = stringParas()[firstLine.paragraphIndex];
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
                        !lastLine.isLastLine ? lastLine._heightBelowBaseline
                        : heightBelowBaselineWithoutExcessSpacing(lastLine);
        Float32 maxHeightAboveBaseline = 0;
        Float32 maxHeightBelowBaseline = 0;
        for (auto& line : paraLines[{0, $ - 1}]) {
          maxHeightAboveBaseline = max(maxHeightAboveBaseline, line._heightAboveBaseline);
          maxHeightBelowBaseline = max(maxHeightBelowBaseline, line._heightBelowBaseline);
        }
        maxHeightAboveBaseline = max(maxHeightAboveBaseline, lastLine._heightAboveBaseline);
        maxHeightBelowBaseline = max(maxHeightBelowBaseline, lastLineHeightBelowBaseline);
        // Estimate the height that would be saved if the frame were wide enough for the whole
        // paragraph to fit into a single line.
        const Float64 d = (lastLine.originY - firstLine.originY)
                        + (firstLine._heightAboveBaseline + lastLineHeightBelowBaseline
                           - (maxHeightAboveBaseline + maxHeightBelowBaseline));
        height -= d;
      } // for (;;)
      if (frameHeight < scale*height) {
        scale = max(minScale, frameHeight/height);
      }
      return {scale, true};
    }
  }

  minScale = max(minScale, frameHeight/height);

  TempVector<ScalingPara> paras{freeCapacityInCurrentThreadLocalAllocatorBuffer,
                                paras_.allocator()};

  STU_APPEARS_UNUSED
  bool multiLineParaHasHyphenation = false;
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
    const ShapedString::Paragraph& p = stringParas()[firstLine.paragraphIndex];
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
    paras.append(ScalingPara{.stringRange = {firstLine.rangeInOriginalString.start,
                                             lastLine.rangeInOriginalString.end},
                             .maxLineCount = n,
                             .lineCount = n,
                             .originalLineCount = n,
                             .initialLinesCount = initialLinesCount,
                             .lineHeight = (lastLine.originY - firstLine.originY)/(n - 1),
                             .commonHeadIndent = commonHeadIndent,
                             .initialExtraHeadIndent = initialExtraHeadIndent,
                             .initialExtraTailIndent = initialExtraTailIndent,
                             .maxWidthMinusCommonIndent = maxWidthMinusCommonIndent});
    if (isCancelled()) break;
  }
  paras.trimFreeCapacity();
  TempVector<Int32> remainingParaIndices{Capacity{paras.count()}, paras.allocator()};
  remainingParaIndices.append(repeat(uninitialized, paras.count()));
  for (Int i = 0; i < paras.count(); ++i) {
    remainingParaIndices[i] = static_cast<Int32>(i);
  }
  Float64 lowerBound = minScale;
  Float64 upperBound = scale;
  bool isLowerBound = false;
  while (lowerBound + accuracy < upperBound) {
    scale = (lowerBound + upperBound)/2;
    const Float64 inverseScale = 1/scale;
    Float64 savedHeight = 0;
    Int32 savedLineCount = 0;
    remainingParaIndices.removeWhere([&](Int32 i) -> bool {
      ScalingPara& para = paras[i];
      para.bisectInverseScaleInterval(isLowerBound, inverseScale,
                                      typesetter_, attributedString_.string);
      const Int32 lineCountDiff = para.originalLineCount - para.lineCount;
      const Float64 heighDiff = lineCountDiff*para.lineHeight;
      if (para.minLineCount != para.maxLineCount) {
        savedLineCount += lineCountDiff;
        savedHeight += heighDiff;
        return false;
      } else {
        lineCount -= lineCountDiff;
        height -= lineCountDiff;
        return true;
      }
    });
    const Int32 newLineCount = lineCount - savedLineCount;
    const Float64 newHeight = height - savedHeight;
    isLowerBound = newLineCount <= maxLineCount && scale*newHeight <= frameHeight;
    if (isLowerBound) {
      lowerBound = scale;
    } else {
      if (newLineCount <= maxLineCount) {
        lowerBound = max(lowerBound, frameHeight/newHeight);
      }
      upperBound = scale;
    }
  }
  return {lowerBound, false};
}

auto TextFrameLayouter::calculateMaxScaleFactorForCurrentLineBreaks(Float64 maxHeight) const
  -> ScaleFactorAndNeedsRealignment
{
  if (STU_UNLIKELY(lines_.isEmpty())) return {1, false};
  const Float64 height = heightWithMinimalSpacingBelowLastBaseline(*this);
  Float64 scale = height <= 0 ? 1 : maxHeight/height;
  if (scale <= 1) return {scale, false};
  const Float64 frameWidth = inverselyScaledFrameSize_.width;
  const Float64 inverseScale = scaleInfo_.inverseScale;
  bool needsRealignment = false;
  Int32 i = 0;
  for (const TextFrameParagraph& para : paras_) {
    STU_DEBUG_ASSERT(i == para.lineIndexRange().start);
    if (STU_UNLIKELY(i == para.lineIndexRange().end)) continue;
    switch (para.alignment) {
    case STUParagraphAlignmentRight:
    case STUParagraphAlignmentJustifiedRight:
    case STUParagraphAlignmentCenter:
      needsRealignment = true;
      break;
    case STUParagraphAlignmentLeft:
    case STUParagraphAlignmentJustifiedLeft:
      break;
    }
    const ShapedString::Paragraph& p = stringParas()[para.paragraphIndex];
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
      Float32 width32 = lines_[i].width;
      while (++i != para.initialLinesEndIndex) {
        width32 = max(width32, lines_[i].width);
      }
      CGFloat width = width32;
      width += initialExtraIndent;
      if (width > 0) {
        scale = min(scale, maxWidth/width);
      }
    }
    if (i != para.lineIndexRange().end) {
      Float32 width32 = lines_[i].width;
      while (++i != para.lineIndexRange().end) {
        width32 = max(width32, lines_[i].width);
      }
      CGFloat width = width32;
      width += nonInitialExtraIndent;
      if (width > 0) {
        scale = min(scale, maxWidth/width);
      }
    }
  }
  return {max(0, scale), needsRealignment};
}

} // namespace stu_label
