// Copyright 2016–2018 Stephan Tolksdorf

#import "LineTruncation.hpp"

#import "Kerning.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

constexpr static Float64 one_minusOne_F64[] = {1, -1};
constexpr static Int one_minusOne_Int[] = {1, -1};

struct StartAtEndOfLineString : Parameter<StartAtEndOfLineString> { using Parameter::Parameter; };
struct IsRightToLeftLine : Parameter<IsRightToLeftLine> { using Parameter::Parameter; };
struct MinInitialOffset : Parameter<MinInitialOffset, Float64> { using Parameter::Parameter; };

/// An iterator for iterating over the grapheme clusters in a line such that both the skipped
/// string range and the corresponding glyph range are continuous, i.e. do not have gaps.
struct Iterator {
  const NSAttributedStringRef& attributedString_;
  const NSStringRef string_;
  const Range<Int> lineStringRange_;
  const NSArrayRef<CTRun*> runs_;

  const bool isRightToLeftLine_;
  bool isStringForwardIterator_;
  bool isRightToLeftIterator_;
  bool isReversed_;
  bool isRightToLeftRun_;
  bool isNonMonotonicRun_;
  /// !run_ || (isRightToLeftRun_ != isRightToLeftLine_) || runGlyphCount_ == 0
  bool skipRun_;

  /// The sum of the typographic width skipped by the iterator.
  Float64 offset_;

  /// If isStringForwardIterator, the UTF-16 index of the end of the continuous string span that the
  /// iterator has skipped over; otherwise the UTF-16 index of the start of the continuous string
  /// span.
  Int stringIndex_;
  /// The index of the run with the next glyph that the iterator will skip,
  /// or (!isRightToLeftIterator_ ? runs_.count() : -1) if there is no such glyph.
  Int runIndex_;
  /// runs[runIndex], or none if `runIndex` is not a valid run index
  Optional<GlyphRunRef> run_;
  /// The glyph count of the run.
  Int runGlyphCount_;
  /// The index of the first glyph (within its run) that the iterator will next skip,
  /// or 0 if there is no such glyph.
  Int glyphIndex_;

  /// Is only set if skipRun.
  Range<Int> runStringRange_;

  ArrayRef<const Int> stringIndices_;
  TempVector<Int> stringIndexBuffer_;

  STU_INLINE
  Iterator(const TruncatableTextLine& line, const StartAtEndOfLineString startAtEndOfLineString,
           const MinInitialOffset minOffset = {})
  : attributedString_{line.attributedString},
    string_{attributedString_.string},
    lineStringRange_{line.stringRange},
    runs_{line.runs},
    isRightToLeftLine_{line.isRightToLeftLine},
    isStringForwardIterator_{!startAtEndOfLineString},
    isRightToLeftIterator_{isStringForwardIterator_ == isRightToLeftLine_},
    isReversed_{false},
    isRightToLeftRun_{false},
    isNonMonotonicRun_{false},
    skipRun_{true},
    offset_{0},
    stringIndex_{isStringForwardIterator_ ? lineStringRange_.start : lineStringRange_.end},
    runIndex_{!isRightToLeftIterator_ ? -1 : runs_.count()}
  {
    if (minOffset <= 0) {
      loadNextRun();
    } else {
      advanceToInitialMinOffset(minOffset.value);
    }
    STU_APPEARS_UNUSED
    const bool startAtLineStringStart = !startAtEndOfLineString;
    STU_ASSUME(isStringForwardIterator_ == startAtLineStringStart);
  }

  STU_INLINE bool isLeftToRightIterator() const { return !isRightToLeftIterator_; }
  STU_INLINE bool isStringForwardIterator() const { return isStringForwardIterator_; }

  STU_INLINE Float64 offset() const { return offset_; }

  STU_INLINE Range<Int> lineStringRange() const { return lineStringRange_; }

  STU_INLINE Int stringIndex() const { return stringIndex_; }

  STU_INLINE
  RunGlyphIndex position() const {
    Int runIndex = runIndex_;
    Int glyphIndex = glyphIndex_;
    if (isRightToLeftIterator_) {
      if (skipRun_ || (++glyphIndex >= runGlyphCount())) {
        runIndex += 1;
        glyphIndex = 0;
      }
    }
    return {runIndex, glyphIndex};
  }

  STU_INLINE
  void reverseDirection() {
    isReversed_ = !isReversed_;
    reverseDirectionImpl();
  }

  STU_INLINE
  void reverseDirectionAndInvertOffsetRelativeToLineWidth(const Float64 lineWidth) {
    offset_ = lineWidth - offset_;
    reverseDirectionImpl();
  }

private:
  STU_INLINE
  void reverseDirectionImpl() {
    const bool isForwardIterator = !isStringForwardIterator_;
    isStringForwardIterator_ = isForwardIterator;
    isRightToLeftIterator_ = !isRightToLeftIterator_;
    if (!skipRun_) {
      glyphIndex_ += one_minusOne_Int[isRightToLeftIterator_];
      if (0 <= glyphIndex_ && glyphIndex_ < runGlyphCount()) return;
    }
    loadNextRun();
    STU_ASSUME(isForwardIterator == isStringForwardIterator_);
  }

public:
  STU_INLINE bool canAdvance() const { return run_ != none; }

  STU_INLINE
  bool advance() {
    const bool isStringForwardIterator = isStringForwardIterator_;
    const bool result = isStringForwardIterator ? advanceImpl<true>() : advanceImpl<false>();
    STU_ASSUME(isStringForwardIterator == isStringForwardIterator_);
    return result;
  }

  Float64 leftPartWidthAdjustment(RunGlyphIndex leftPartEnd
                               #if STU_TRUNCATION_TOKEN_KERNING
                                  , const GlyphForKerningPurposes& firstTokenGlyph
                                  , const NSStringRef& tokenString
                               #endif
                                 ) const;

  Float64 rightPartWidthAdjustment(RunGlyphIndex rightPartStart
                                #if STU_TRUNCATION_TOKEN_KERNING
                                  , const GlyphForKerningPurposes& lastTokenGlyph
                                  , const NSStringRef& tokenString
                                #endif
                                 ) const;

private:
  template <bool isStringForwardIterator>
  bool advanceImpl();

  void advanceToInitialMinOffset(Float64 minOffset);

  STU_INLINE
  Int runGlyphCount() const {
    const Int count = runGlyphCount_;
    STU_ASSUME(count >= 0);
    return count;
  }

  STU_INLINE
  CTRunStatus isRightToLeftLineAsCTRunStatus() const {
    static_assert(kCTRunStatusRightToLeft == 1);
    return CTRunStatus{isRightToLeftLine_};
  }

  bool loadNextRun();

  STU_INLINE
  Int glyphStringIndex() {
    if (STU_LIKELY(stringIndices_.isValidIndex(glyphIndex_))) {
      return stringIndices_[glyphIndex_];
    }
    return glyphStringIndex_slowPath();
  }
  STU_NO_INLINE
  Int glyphStringIndex_slowPath();
};

STU_NO_INLINE
Int Iterator::glyphStringIndex_slowPath() {
  stringIndexBuffer_.removeAll();
  stringIndexBuffer_.append(repeat(uninitialized, runGlyphCount_));
  stringIndices_ = stringIndexBuffer_;
  CTRunGetStringIndices(run_->ctRun(), CFRange{0, runGlyphCount_}, stringIndexBuffer_.begin());
  if (isNonMonotonicRun_) {
    // This ensures that the iterator only stops at positions in a run where the string indices
    // of glyphs on one side are strictly higher than the string indices on the other side.
    Int maxIndex = 0;
    if (!isRightToLeftLine_) {
      STU_DISABLE_LOOP_UNROLL
      for (Int& stringIndex : stringIndexBuffer_) {
        stringIndex = maxIndex = max(stringIndex, stringIndex);
      }
    } else {
      STU_DISABLE_LOOP_UNROLL
      for (Int& stringIndex : stringIndexBuffer_.reversed()) {
        stringIndex = maxIndex = max(stringIndex, stringIndex);
      }
    }
  }
  return stringIndices_[glyphIndex_];
}

void Iterator::advanceToInitialMinOffset(const Float64 minOffset) {
  STU_ASSERT(!run_); // This method is only called from the constructor.
  const Int minusOneIfRightToLeftIterator = one_minusOne_Int[isRightToLeftIterator_];
  const CTRunStatus isRTLStatus = isRightToLeftLineAsCTRunStatus();
  Float64 offset = 0;
  Int runIndex = runIndex_;
  Int stringIndex = stringIndex_;
  for (;;) {
    runIndex += minusOneIfRightToLeftIterator;
    if (!(0 <= runIndex && runIndex < runs_.count())) break;
    const GlyphRunRef run = runs_[runIndex];
    const Float64 nextOffset = offset + run.typographicWidth();
    if (nextOffset > minOffset && isRTLStatus == (run.status() & kCTRunStatusRightToLeft)) break;
    offset = nextOffset;
    if (isStringForwardIterator_) {
      stringIndex = max(stringIndex, run.stringRange().end);
    } else {
      stringIndex = min(stringIndex, run.stringRange().start);
    }
  }
  offset_ = offset;
  runIndex_ = runIndex - minusOneIfRightToLeftIterator;
  if (stringIndex > stringIndex_) {
    STU_DEBUG_ASSERT(isStringForwardIterator_);
    stringIndex_ = string_.indexOfFirstGraphemeClusterBreakNotBefore(stringIndex);
  } else if (stringIndex < stringIndex_) {
    STU_DEBUG_ASSERT(!isStringForwardIterator_);
    stringIndex_ = string_.startIndexOfGraphemeClusterAt(stringIndex);
  }
  loadNextRun();
  while (offset_ < minOffset) {
    advance();
  }
}

STU_NO_INLINE
bool Iterator::loadNextRun() {
  // Note that this method may be called from the constructor
  // with runIndex == (!isRightToLeftIterator_ ? -1 : runs_.count()).
  runIndex_ += one_minusOne_Int[isRightToLeftIterator_];
  if (0 <= runIndex_ && runIndex_ < runs_.count()) {
    run_ = runs_[runIndex_];
    runGlyphCount_ = run_->count();
    glyphIndex_ = !isRightToLeftIterator_? 0 : max(runGlyphCount_ - 1, 0);
    const auto runStatus = run_->status();
    isRightToLeftRun_ = runStatus & kCTRunStatusRightToLeft;
    isNonMonotonicRun_ = runStatus & kCTRunStatusNonMonotonic;
    skipRun_ = runGlyphCount_ <= 0 || (isRightToLeftRun_ != isRightToLeftLine_);
    if (skipRun_) {
      runStringRange_ = run_->stringRange();
    } else {
      stringIndices_ = ArrayRef<const Int>();
      if (!isNonMonotonicRun_) {
        if (const Int* const stringIndices = CTRunGetStringIndicesPtr(run_->ctRun())) {
          stringIndices_ = ArrayRef{stringIndices, runGlyphCount_};
        }
      }
    }
    return true;
  }
  run_ = none;
  isRightToLeftRun_ = false;
  isNonMonotonicRun_ = false;
  skipRun_ = true;
  runIndex_ = !isRightToLeftIterator_ ? runs_.count() : -1;
  glyphIndex_ = 0;
  stringIndex_ = isStringForwardIterator_ ? lineStringRange_.end : lineStringRange_.start;
  return false;
}

// We specialize this function by the string iteration direction as an optimization.
template <bool isStringForwardIter>
STU_NO_INLINE
bool Iterator::advanceImpl() {
  STU_DEBUG_ASSERT(isStringForwardIter == isStringForwardIterator_);
  if (!run_) return false;
  const Float64 minusOneIfReversed = one_minusOne_F64[isReversed_];
  const auto hasAdvanced = [&, oldOffset = offset_*minusOneIfReversed]() {
    return offset_*minusOneIfReversed > oldOffset;
  };
  const Int minusOneIfRightToLeftIter = one_minusOne_Int[isRightToLeftIterator_];
  if (!skipRun_) {
    const Int stringIndex = glyphStringIndex();
    stringIndex_ = isStringForwardIter ? string_.endIndexOfGraphemeClusterAt(stringIndex)
                                       : string_.startIndexOfGraphemeClusterAt(stringIndex);
    STU_ASSUME(!skipRun_);
  }
  for (;;) {
    if (STU_LIKELY(!skipRun_)) {
      for (;;) {
        const Int glyphStartIndex = glyphIndex_;
        Int stringIndex;
        do {
          glyphIndex_ += minusOneIfRightToLeftIter;
          if (!(0 <= glyphIndex_ && glyphIndex_ < runGlyphCount())) break;
          stringIndex = glyphStringIndex();
        } while (isStringForwardIter ? stringIndex < stringIndex_ : stringIndex >= stringIndex_);
        Int lastGlyphIndex = glyphIndex_ - minusOneIfRightToLeftIter;
        const Range<Int> glyphRange = {min(glyphStartIndex, lastGlyphIndex),
                                       max(glyphStartIndex, lastGlyphIndex) + 1};
        offset_ += minusOneIfReversed*CTRunGetTypographicBounds(run_->ctRun(), glyphRange,
                                                                nullptr, nullptr, nullptr);
        if (!(0 <= glyphIndex_ && glyphIndex_ < runGlyphCount())) break;
        if (STU_LIKELY(hasAdvanced())) return true;
        STU_DISABLE_CLANG_WARNING("-Wconditional-uninitialized")
        stringIndex_ = isStringForwardIter             // clang analyzer false positive
                     ? string_.endIndexOfGraphemeClusterAt(stringIndex)
                     : string_.startIndexOfGraphemeClusterAt(stringIndex);
        STU_REENABLE_CLANG_WARNING
      }
    } else {
      offset_ += run_->typographicWidth()*minusOneIfReversed;
      if (!runStringRange_.isEmpty()) {
        if (isStringForwardIter) {
          if (runStringRange_.end > stringIndex_) {
            stringIndex_ = string_.indexOfFirstGraphemeClusterBreakNotBefore(runStringRange_.end);
          }
        } else {
          if (runStringRange_.start < stringIndex_) {
            stringIndex_ = string_.startIndexOfGraphemeClusterAt(runStringRange_.start);
          }
        }
      }
    }
    const bool isEnd = !loadNextRun();
    const bool isAdvanced = hasAdvanced();
    if (isEnd) return isAdvanced;
    if (!isAdvanced) continue;
    if (!skipRun_) {
      const Int stringIndex = glyphStringIndex();
      if (isStringForwardIter
          ? stringIndex >= stringIndex_
          : stringIndex < stringIndex_)
      {
        return true;
      }
      STU_ASSUME(!skipRun_);
    } else {
      if (isStringForwardIter
          ? runStringRange_.start >= stringIndex_
          : runStringRange_.end <= stringIndex_)
      {
        return true;
      }
    }
  } // for (;;)
}

Float64 Iterator::leftPartWidthAdjustment(RunGlyphIndex leftPartEnd
                                        #if STU_TRUNCATION_TOKEN_KERNING
                                          , const GlyphForKerningPurposes& firstTokenGlyph
                                          , const NSStringRef& tokenString
                                        #endif
                                          ) const
{
  if (leftPartEnd == RunGlyphIndex{}) return 0;
  const Int glyphIndex = leftPartEnd.glyphIndex;
  const Int runIndex = leftPartEnd.runIndex - (glyphIndex == 0);
  const GlyphSpan run = runIndex == runIndex_
                      ? GlyphSpan{*run_, Range{0, runGlyphCount_}, unchecked}
                      : runs_[runIndex];
  const auto glyph = GlyphForKerningPurposes::find(
                       glyphIndex == 0 ? run : GlyphSpan{run.run(), {0, glyphIndex}, unchecked},
                       attributedString_, rightmostGlyph);
  if (!glyph.glyph) return 0;
#if STU_TRUNCATION_TOKEN_KERNING
  if (const auto adjustment = kerningAdjustment(glyph, string_, firstTokenGlyph, tokenString)) {
    return *adjustment;
  }
#endif
  const Float64 adjustment = glyph.unkernedWidth > 0 ? glyph.unkernedWidth - glyph.width : 0;
  return adjustment;
}

Float64 Iterator::rightPartWidthAdjustment(RunGlyphIndex rightPartStart
                                        #if STU_TRUNCATION_TOKEN_KERNING
                                           , const GlyphForKerningPurposes& lastTokenGlyph
                                           , const NSStringRef& tokenString
                                        #endif
                                           ) const
{
  if (rightPartStart.runIndex == runs_.count()) return 0;
  Float64 offset = 0;
  const Int glyphIndex = rightPartStart.glyphIndex;
  if (rightPartStart != RunGlyphIndex{}) {
    const Int runIndex = rightPartStart.runIndex - (glyphIndex == 0);
    const GlyphSpan run = runIndex == runIndex_
                        ? GlyphSpan{*run_, Range{0, runGlyphCount_}, unchecked}
                        : runs_[runIndex];
    const auto glyph = GlyphForKerningPurposes::find(
                         glyphIndex == 0 ? run : GlyphSpan{run.run(), {0, glyphIndex}, unchecked},
                         attributedString_, rightmostGlyph);
    if (glyph.glyph && glyph.unkernedWidth > 0) {
      offset = max(0, glyph.width - glyph.unkernedWidth);
    }
  }
#if STU_TRUNCATION_TOKEN_KERNING
  if (!lastTokenGlyph.glyph) return offset;
  const GlyphSpan run = rightPartStart.runIndex == runIndex_
                        ? GlyphSpan{*run_, Range{0, runGlyphCount_}, unchecked}
                        : runs_[rightPartStart.runIndex];
  const auto glyph = GlyphForKerningPurposes::find(
                      GlyphSpan{run.run(), {glyphIndex, run.count()}, unchecked},
                      attributedString_, leftmostGlyph);
  if (!glyph.glyph) return offset;
  if (const auto adjustment = kerningAdjustment(lastTokenGlyph, tokenString, glyph, string_)) {
    offset += *adjustment;
  }
#endif
  return offset;
}


STU_NO_INLINE
static void truncationRangeAdjusterReturnedInvalidRange(
              STUTruncationRangeAdjuster truncationRangeAdjuster __unused,
              NSRange invalidRange __unused,
              NSAttributedString* attributedString __unused,
              NSRange fullRange __unused,
              NSRange proposedRange __unused)
{
#if STU_DEBUG
  STU_CHECK_MSG(false, "A STUTextFrame truncation range adjuster block returned an invalid range.");
#else
  NSLog(@"ERROR - A STUTextFrame truncation range adjuster block returned an invalid range.");
#endif
}

static ExcisedGlyphRange findRangeToExciseForStartOrEndTruncation(
                           const TruncatableTextLine& line,
                           const CTLineTruncationType truncationType,
                           const Float64 maxWidth,
                           const __nullable __unsafe_unretained
                             STUTruncationRangeAdjuster truncationRangeAdjuster
                         #if STU_TRUNCATION_TOKEN_KERNING
                           , const TokenForKerningPurposes& token
                         #endif
                         )
{
  const bool startAtTruncatedEnd = line.width < 2*maxWidth;
  const Float64 minTruncationWidth = line.width - maxWidth;
  Iterator iter{line,
                StartAtEndOfLineString{startAtTruncatedEnd
                                       == (truncationType == kCTLineTruncationEnd)},
                MinInitialOffset{startAtTruncatedEnd ? minTruncationWidth : maxWidth}};
  if (!startAtTruncatedEnd) {
    iter.reverseDirectionAndInvertOffsetRelativeToLineWidth(line.width);
    if (iter.offset() < minTruncationWidth) {
      iter.advance();
      STU_DEBUG_ASSERT(iter.offset() >= minTruncationWidth);
    }
  }
  // Advancing the iterator now enlarges the excision range and iter.offset() is the width of the
  // excision.

  const bool isRightTruncated = !iter.isLeftToRightIterator();

#if STU_TRUNCATION_TOKEN_KERNING
  STU_ASSERT(!token.runs.isEmpty());
  const auto tokenGlyph = GlyphForKerningPurposes::find(
                            isRightTruncated ? token.runs[0] : token.runs[$ - 1],
                            token.attributedString,
                            isRightTruncated ? leftmostGlyph : rightmostGlyph);
  #define TOKEN_GLYPH , tokenGlyph, token.attributedString.string
#else
  #define TOKEN_GLYPH
#endif

  RunGlyphIndex position = iter.position();
  Float64 removedWidth;
  for (;;) {
    removedWidth = iter.offset()
                 - (isRightTruncated ? iter.leftPartWidthAdjustment(position TOKEN_GLYPH)
                                     : iter.rightPartWidthAdjustment(position TOKEN_GLYPH));
    if (removedWidth >= minTruncationWidth) break;
    iter.advance();
    position = iter.position();
  }

  const Range<Int> fullStringRange{iter.lineStringRange()};
  Range<Int> stringRange{truncationType == kCTLineTruncationStart
                         ? Range{fullStringRange.start, iter.stringIndex()}
                         : Range{iter.stringIndex(), fullStringRange.end}};
  if (truncationRangeAdjuster) {
    bool adjusted = false;
    for (;;) {
      const Range<Int> range{truncationRangeAdjuster(line.attributedString.attributedString,
                                                     NSRange(fullStringRange),
                                                     NSRange(stringRange))};
      if (range == stringRange) break;
      if (STU_UNLIKELY(!range.contains(stringRange) || !fullStringRange.contains(range))) {
        truncationRangeAdjusterReturnedInvalidRange(truncationRangeAdjuster, Range<UInt>{range},
                                                    line.attributedString.attributedString,
                                                    NSRange(fullStringRange),
                                                    NSRange(stringRange));
        break;
      }
      adjusted = true;
      if (!iter.isStringForwardIterator()) {
        do iter.advance();
        while (iter.stringIndex() > range.start);
        stringRange.start = iter.stringIndex();
        if (stringRange.start == range.start) break;
      } else {
        do iter.advance();
        while (iter.stringIndex() < range.end);
        stringRange.end = iter.stringIndex();
        if (stringRange.end == range.end) break;
      }
    }
    if (adjusted) {
      position = iter.position();
      removedWidth = iter.offset()
                   - (isRightTruncated ? iter.leftPartWidthAdjustment(position TOKEN_GLYPH)
                                       : iter.rightPartWidthAdjustment(position TOKEN_GLYPH));
    }
  }
  #undef TOKEN_GLYPH

  return {.stringRange = stringRange,
          .start = isRightTruncated ? position : RunGlyphIndex{},
          .end = isRightTruncated ? RunGlyphIndex{-1, -1} : position,
          .adjustedWidthLeftOfExcision = isRightTruncated ? line.width - removedWidth : 0,
          .adjustedWidthRightOfExcision = isRightTruncated ? 0 : line.width - removedWidth};
}

static
ExcisedGlyphRange findRangeToExciseForMiddleTruncation(
                    const TruncatableTextLine& line,
                    const CTLineTruncationType truncationType,
                    const Float64 maxWidth,
                    const __nullable __unsafe_unretained
                      STUTruncationRangeAdjuster truncationRangeAdjuster
                  #if STU_TRUNCATION_TOKEN_KERNING
                    , const TokenForKerningPurposes& token
                  #endif
                    )
{
  // We iteratively determine the two spans at the ends of the lines that will remain after
  // truncation. We alternate between both sides to keep the widths balanced when possible.

  Iterator iterS{line, StartAtEndOfLineString{false}};
  Iterator iterE{line, StartAtEndOfLineString{true}};

  auto& iterL = line.isRightToLeftLine ? iterE : iterS;
  auto& iterR = line.isRightToLeftLine ? iterS : iterE;

  // - 0.01 to protect against infinite iteration due to accumulated floating point rounding errors.
  const Float64 maxWidthForIteration = min(maxWidth, line.width - 0.01);

  const Range<Int> truncationRange = line.truncatableStringRange;

  STU_DEBUG_ASSERT(line.stringRange.contains(truncationRange));
  const bool isMiddleStartOrEndTruncation = truncationType != kCTLineTruncationMiddle;

  {
    Float64 offsetS = 0;
    Float64 offsetE = 0;
    // Look ahead one step.
    iterS.advance();
    iterE.advance();
    for (;;) {
      const bool canAdvanceS = iterS.offset() + offsetE <= maxWidthForIteration;
      const bool canAdvanceE = iterE.offset() + offsetS <= maxWidthForIteration;
      if (isMiddleStartOrEndTruncation) {
        if (truncationType == kCTLineTruncationEnd) {
          if (iterE.stringIndex() < truncationRange.end) {
            if (!canAdvanceS) break;
            offsetS = iterS.offset();
            iterS.advance();
            continue;
          }
          if (iterS.stringIndex() > truncationRange.start && canAdvanceE) {
            offsetE = iterE.offset();
            iterE.advance();
            continue;
          }
        } else { // truncationType == kCTLineTruncationStart
          if (iterS.stringIndex() > truncationRange.start) {
            if (!canAdvanceE) break;
            offsetE = iterE.offset();
            iterE.advance();
            continue;
          }
          if (iterE.stringIndex() < truncationRange.end && canAdvanceS) {
            offsetS = iterS.offset();
            iterS.advance();
            continue;
          }
        }
      }
      if (!(canAdvanceS | canAdvanceE)) break;
      // TODO: Advance by the shorter full run if both runs together still fit.
      if (canAdvanceS && (!canAdvanceE || iterS.offset() <= iterE.offset())) {
        offsetS = iterS.offset();
        iterS.advance();
      } else {
        offsetE = iterE.offset();
        iterE.advance();
      }
    }
  }

  iterS.reverseDirection();
  iterE.reverseDirection();
  // Undo lookahead.
  iterS.advance();
  iterE.advance();

#if STU_TRUNCATION_TOKEN_KERNING
  STU_ASSERT(!token.runs.isEmpty());
  const auto leftTokenGlyph = GlyphForKerningPurposes::find(
                                 token.runs[0], token.attributedString, leftmostGlyph);
  const auto rightTokenGlyph = leftTokenGlyph.width >= token.width - 0.01 ? leftTokenGlyph
                            : GlyphForKerningPurposes::find(
                                token.runs[$ - 1], token.attributedString, rightmostGlyph);
  #define LEFT_TOKEN_GLYPH , leftTokenGlyph, token.attributedString.string
  #define RIGHT_TOKEN_GLYPH , rightTokenGlyph, token.attributedString.string
#else
  #define LEFT_TOKEN_GLYPH
  #define RIGHT_TOKEN_GLYPH
#endif

  RunGlyphIndex positionL = iterL.position();
  RunGlyphIndex positionR = iterR.position();
  Float64 leftWidth = iterL.offset() + iterL.leftPartWidthAdjustment(positionL LEFT_TOKEN_GLYPH);
  Float64 rightWidth = iterR.offset() + iterR.rightPartWidthAdjustment(positionR RIGHT_TOKEN_GLYPH);
  while (leftWidth + rightWidth > maxWidth) {
    if (isMiddleStartOrEndTruncation
        && (truncationType == kCTLineTruncationEnd
            ? (&iterS != &iterL && iterS.stringIndex() > truncationRange.start)
            : (&iterE != &iterL && iterE.stringIndex() < truncationRange.end)))
    {
      iterR.advance();
      positionR = iterR.position();
      rightWidth = iterR.offset() + iterR.rightPartWidthAdjustment(positionR LEFT_TOKEN_GLYPH);
      continue;
    }
    iterL.advance();
    positionL = iterL.position();
    leftWidth = iterL.offset() + iterL.leftPartWidthAdjustment(positionL RIGHT_TOKEN_GLYPH);
  }

  Range<Int> stringRange{iterS.stringIndex(), iterE.stringIndex()};

  if (truncationRangeAdjuster
      && truncationRange.contains(stringRange) && truncationRange != stringRange)
  {
    const Range<Int> oldStringRange = stringRange;
    for (;;) {
      const Range<Int> range{truncationRangeAdjuster(line.attributedString.attributedString,
                                                     NSRange(truncationRange),
                                                     NSRange(stringRange))};
      if (range == stringRange) break;
      if (STU_UNLIKELY(!range.contains(stringRange) || !truncationRange.contains(range))) {
        truncationRangeAdjusterReturnedInvalidRange(truncationRangeAdjuster, Range<UInt>{range},
                                                    line.attributedString.attributedString,
                                                    NSRange(truncationRange),
                                                    NSRange(stringRange));
        break;
      }
      while (iterS.stringIndex() > range.start) {
        iterS.advance();
      }
      stringRange.start = iterS.stringIndex();
      while (iterE.stringIndex() < range.end) {
        iterE.advance();
      }
      stringRange.end = iterE.stringIndex();
      if (range == stringRange) break;
    }
    const bool adjustedS = stringRange.start != oldStringRange.start;
    const bool adjustedE = stringRange.end != oldStringRange.end;
    const bool adjustedL = &iterS == &iterL ? adjustedS : adjustedE;
    const bool adjustedR = &iterS == &iterL ? adjustedE : adjustedS;
    if (adjustedL) {
      positionL = iterL.position();
      leftWidth = iterL.offset() + iterL.leftPartWidthAdjustment(positionL LEFT_TOKEN_GLYPH);
    }
    if (adjustedR) {
      positionR = iterR.position();
      rightWidth = iterR.offset() + iterR.rightPartWidthAdjustment(positionR RIGHT_TOKEN_GLYPH);
    }
  }

  #undef LEFT_TOKEN_GLYPH
  #undef RIGHT_TOKEN_GLYPH

  return {.stringRange = stringRange,
          .start = positionL, .end = positionR,
          .adjustedWidthLeftOfExcision = leftWidth,
          .adjustedWidthRightOfExcision = rightWidth};
}

ExcisedGlyphRange findRangeToExciseForTruncation(
                    const TruncatableTextLine& line, const CTLineTruncationType truncationType,
                    const Float64 maxWidth,
                    const __nullable __unsafe_unretained
                      STUTruncationRangeAdjuster truncationRangeAdjuster
                  #if STU_TRUNCATION_TOKEN_KERNING
                    , const TokenForKerningPurposes& token
                  #endif
                  )
{
  STU_ASSERT(line.width > maxWidth);
  const bool isMiddleStartOrEndTruncation = line.truncatableStringRange != line.stringRange;
  if (!isMiddleStartOrEndTruncation && truncationType != kCTLineTruncationMiddle) {
    return findRangeToExciseForStartOrEndTruncation(line, truncationType, maxWidth,
                                                    truncationRangeAdjuster
                                                  #if STU_TRUNCATION_TOKEN_KERNING
                                                    , token
                                                  #endif
                                                    );
  } else {
    if (isMiddleStartOrEndTruncation) {
      STU_ASSERT(truncationType != kCTLineTruncationMiddle);
      STU_ASSERT(line.stringRange.contains(line.truncatableStringRange));
    }
    return findRangeToExciseForMiddleTruncation(line, truncationType, maxWidth,
                                                truncationRangeAdjuster
                                              #if STU_TRUNCATION_TOKEN_KERNING
                                                , token
                                              #endif
                                                );
  }
}

} // namespace stu_label
