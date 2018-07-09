// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrameLayouter.hpp"

#import "Kerning.hpp"
#import "Once.hpp"
#import "UnicodeCodePointProperties.hpp"

#import "stu/Assert.h"

namespace stu_label {

static const Char32 softHyphenCodePoint = 0x00AD;

static Float64 typographicOffset(const NSArrayRef<CTRun*>& runs, const RunGlyphIndex index) {
  Int i = 0;
  Float64 width = 0;
  for (const GlyphRunRef run : runs) {
    if (i < index.runIndex) {
      width += run.typographicWidth();
    } else if (index.glyphIndex > 0) {
      width += GlyphSpan{run, Range{0, index.glyphIndex}, unchecked}.typographicWidth();
    }
    ++i;
  }
  return width;
}

/// @returns The index of the last run in string order with positive width,
///          or -1 if there is no such run or if there's a run with negative width.
/// @pre Assumes all runs have a string range <= stringEndIndex.
static Int trailingRunIndex(const NSArrayRef<CTRun*>& runs, Int stringEndIndex,
                            STUWritingDirection baseWritingDirection) {
  const Int runCount = runs.count();
  Int maxStringRangeEnd = -1;
  Int maxStringRangeEndRunIndex = -1;
  Int start, end, d;
  if (baseWritingDirection == STUWritingDirectionLeftToRight) {
    start = runCount - 1; end = -1; d = -1;
  } else {
    start = 0; end = runCount; d = 1;
  }
  for (Int i = start; i != end; i += d) {
    runs.assumeValidIndex(i);
    const GlyphRunRef run = runs[i];
    const Range<Int> stringRange = run.stringRange();
    if (stringRange.end < maxStringRangeEnd) continue;
    const Float64 width = run.typographicWidth();
    if (STU_UNLIKELY(!(width > 0))) {
      if (width == 0) continue;
      return -1;
    }
    if (stringRange.end >= stringEndIndex) return i;
    maxStringRangeEnd = stringRange.end;
    maxStringRangeEndRunIndex = i;
  }
  return maxStringRangeEndRunIndex;
}

/// This function can be called multiple times for the same line.
/// If if fails because the full line width including the inserted hyphen exceeds lineMaxWidth_,
/// it won't mutate the line.
auto TextFrameLayouter
     ::breakLineAt(TextFrameLine& line, Int stringIndex, Hyphen hyphen,
                   TrailingWhitespaceStringLength trailingWhitespaceStringLength) const
  -> BreakLineAtStatus
{
  STU_DEBUG_ASSERT(stringIndex >= line.rangeInOriginalString.start);
  STU_DEBUG_ASSERT(trailingWhitespaceStringLength >= 0);
  CTLine* ctLine = nullptr;
  Float64 width = 0;
  const Int stringLength = stringIndex - line.rangeInOriginalString.start;
  if (stringLength > 0) {
    ctLine = CTTypesetterCreateLineWithOffset(
               typesetter_, Range{line.rangeInOriginalString.start, stringIndex},
               lineHeadIndent_);
    width = typographicWidth(ctLine);
    if (STU_UNLIKELY(width <= 0)) {
      CFRelease(ctLine);
      ctLine = nullptr;
      width = 0;
    } else {
      const bool mayNeedToCorrectLastGlyphAdvance = trailingWhitespaceStringLength == 0
                                                 && stringIndex < attributedString_.string.count();
      const NSArrayRef<CTRun*> runs = mayNeedToCorrectLastGlyphAdvance || hyphen != 0u
                                   ? glyphRuns(ctLine) : NSArrayRef<CTRun*>{};
      if (hyphen != 0u) {
        if (const Int trailingRunIndex = stu_label::trailingRunIndex(
                                           runs, stringIndex, line.paragraphBaseWritingDirection);
            trailingRunIndex >= 0)
        {
          const GlyphRunRef run = runs[trailingRunIndex];
          const HyphenLine hyphenLine = createHyphenLine(attributedString_, run, hyphen.value);
          const Float64 ctLineWidth = width;
          width += hyphenLine.trailingGlyphAdvanceCorrection + hyphenLine.width;
          if (width > lineMaxWidth_) {
            CFRelease(ctLine);
            CFRelease(hyphenLine.line);
            return {.success = false, .ctLineWidthWithoutHyphen = ctLineWidth};
          }
          // The following lines are duplicated below in justifyLine.
          RunGlyphIndex leftPartEnd{trailingRunIndex + 1 - run.isRightToLeft(), 0};
          Float64 leftPartWidth;
          if (leftPartEnd.runIndex == runs.count()) {
            leftPartEnd = RunGlyphIndex{-1, -1};
            leftPartWidth = width - hyphenLine.width;
          } else {
            leftPartWidth = typographicOffset(runs, leftPartEnd);
          }
          const TextStyle* const style = &firstOriginalStringStyle(line)
                                          ->styleForStringIndex(narrow_cast<Int32>(stringIndex - 1));
          STU_ASSUME(hyphenLine.line != nullptr);
          line.init_step2(TextFrameLine::InitStep2Params{
            .rangeInOriginalStringEnd = stringIndex,
            .rangeInTruncatedStringCount = stringLength,
            .trailingWhitespaceInTruncatedStringLength = trailingWhitespaceStringLength.value,
            .ctLine = ctLine,
            .width = width,
            .token = {
              .leftPartEnd = leftPartEnd,
              .rightPartStart = leftPartEnd,
              .leftPartWidth = leftPartWidth,
              .rightPartXOffset = hyphenLine.width,
              .tokenCTLine = hyphenLine.line,
              .tokenWidth = hyphenLine.width,
              .tokenTextFlags = style->flags(),
              .tokenStylesOffset = (const Byte*)style - originalStringStyles_.dataBegin(),
              .hyphen = {
                .runIndex = hyphenLine.runIndex,
                .glyphIndex = hyphenLine.glyphIndex,
                .xOffset = hyphenLine.xOffset
              },
            }
          });
          return {.success = true, .ctLineWidthWithoutHyphen = ctLineWidth};
        }
      }
      // No hyphen
      if (mayNeedToCorrectLastGlyphAdvance && !runs.isEmpty()) {
        // Fixes rdar://38258815 https://openradar.appspot.com/radar?id=5015323354857472
        const auto glyph = GlyphForKerningPurposes::find(runs[$ - 1], attributedString_,
                                                         rightmostGlyph);
        if (glyph.glyph && glyph.unkernedWidth > 0) {
          width += glyph.unkernedWidth - glyph.width;
        }
      }
    }
  }
  line.init_step2(TextFrameLine::InitStep2Params{
    .rangeInOriginalStringEnd = stringIndex,
    .rangeInTruncatedStringCount = stringLength,
    .trailingWhitespaceInTruncatedStringLength = trailingWhitespaceStringLength.value,
    .ctLine = ctLine,
    .width = width,
  });
  return {.success = true, .ctLineWidthWithoutHyphen = width};
}

// The implementation of this function mirrors the implementation in breakLineAt.
void TextFrameLayouter::justifyLine(STUTextFrameLine& line) const {
  STU_ASSERT(!line.hasTruncationToken);
  if (!line._ctLine) return;
  // The last glyph advance doesn't change when Core Text justifies the line.
  const Float64 originalCTLineWidth = typographicWidth(line._ctLine);
  const Float64 hyphenWidthPlusAdvanceCorrection = line.width - originalCTLineWidth;
  const CTLine* justifiedCTLine = CTLineCreateJustifiedLine(
                                    line._ctLine, 1,
                                    lineMaxWidth_ - hyphenWidthPlusAdvanceCorrection);
  if (!justifiedCTLine) return;
  const Float64 justifiedCTLineWidth = typographicWidth(justifiedCTLine);
  if (justifiedCTLineWidth <= originalCTLineWidth) {
    CFRelease(justifiedCTLine);
    return;
  }
  NSArrayRef<CTRun*> runs;
  Int trailingRunIndex = 0;
  if (line.hasInsertedHyphen) {
    runs = glyphRuns(justifiedCTLine);
    trailingRunIndex = stu_label::trailingRunIndex(runs, line.rangeInOriginalString.end,
                                                   line.paragraphBaseWritingDirection);
    if (trailingRunIndex < 0) {
      CFRelease(justifiedCTLine);
      return;
    }
  }
  CFRelease(line._ctLine);
  line._ctLine = justifiedCTLine;
  const Float64 width = justifiedCTLineWidth + hyphenWidthPlusAdvanceCorrection;
  line.width = narrow_cast<Float32>(width);
  if (!line.hasInsertedHyphen) {
    line.leftPartWidth = line.width;
  } else {
    // The following lines are duplicated above in breakLineAt.
    const bool isRTL = GlyphRunRef{runs[trailingRunIndex]}.isRightToLeft();
    RunGlyphIndex leftPartEnd{trailingRunIndex + 1 - isRTL, 0};
    Float64 leftPartWidth;
    if (leftPartEnd.runIndex == runs.count()) {
      leftPartEnd = RunGlyphIndex{-1, -1};
      leftPartWidth = width - line.tokenWidth;
    } else {
      leftPartWidth = typographicOffset(runs, leftPartEnd);
    }
    line._leftPartEnd = leftPartEnd;
    line._rightPartStart = leftPartEnd;
    line.leftPartWidth = narrow_cast<Float32>(leftPartWidth);
  }
}

bool TextFrameLayouter::hyphenateLineInRange(TextFrameLine& line, Range<Int> stringRange) {
  if (lastHyphenationLocationInRangeFinder_) {
    for (Int i = stringRange.end; i > stringRange.start + 1;) {
      const STUHyphenationLocation hl = lastHyphenationLocationInRangeFinder_(
                                          attributedString_.attributedString,
                                          NSRange(Range{stringRange.start, i}));
      if (STU_UNLIKELY(hl.options != 0)) {
        NSLog(@"ERROR: STUHyphenationLocation value with non-zero options property is ignored.");
        break;
      }
      if (hl.index <= sign_cast(stringRange.start) || hl.index >= sign_cast(i)) break;
      i = sign_cast(hl.index);
      if (breakLineAt(line, i, Hyphen{hl.hyphen}, TrailingWhitespaceStringLength{0}).success) {
        return true;
      }
    }
    return false;
  }
  const Int stringLength = attributedString_.string.count();
  const Int outerEnd = stringRange.end >= stringLength ? stringRange.end
                     : attributedString_.string
                       .indexOfFirstUTF16CharWhere({stringRange.end,
                                                    min(stringRange.end + 16, stringLength)},
                                                   isUnicodeWhitespace);
  __block bool result = false;
  [attributedString_.attributedString
     enumerateAttribute:STUHyphenationLocaleIdentifierAttributeName
                inRange:NSRange(Range{stringRange.start, outerEnd})
                options:NSAttributedStringEnumerationReverse // We want the longest effective range.
             usingBlock:^(__unsafe_unretained id value, NSRange nsRange, BOOL* shouldStop)
  {
    const auto range = Range<Int>(nsRange);
    if (range.start >= stringRange.end) return;
    CFString* const localeId = (__bridge CFStringRef)value;
    if (!localeId) return;
    if (localeId != cachedLocaleId_ && CFStringGetLength(localeId) == 0) return;
    if (localeId == cachedLocaleId_ || (cachedLocaleId_ && CFEqual(localeId, cachedLocaleId_))) {
      if (!cachedLocale_) return;
    } else {
      cachedLocaleId_ = localeId;
      cachedLocale_ = RC<CFLocale>{CFLocaleCreate(nil, localeId), ShouldIncrementRefCount{false}};
      if (!cachedLocale_) return;
      if (!CFStringIsHyphenationAvailableForLocale(cachedLocale_.get())) {
        cachedLocale_ = nullptr;
        return;
      }
    }
    for (Int i = min(stringRange.end, range.end); i > range.start + 1;) {
      UTF32Char hyphen;
      i = CFStringGetHyphenationLocationBeforeIndex(
            attributedString_.string, i, range, 0, cachedLocale_.get(), &hyphen);
      if (i <= range.start) break;
      if (hyphen == 0x2D) { // We prefer a proper hyphen, not a hyphen-minus.
        hyphen = hyphenCodePoint;
      }
      if (breakLineAt(line, i, Hyphen{hyphen}, TrailingWhitespaceStringLength{0}).success) {
        result = true;
        *shouldStop = true;
        return;
      }
    }
  }];
  return result;
}

STU_NO_INLINE
static bool isCodePointThatLikelyPrecedesGoodLineBreakLocation(Char32 ch) {
  // http://unicode.org/reports/tr14/
  // http://www.unicode.org/Public/UCD/latest/ucd/extracted/DerivedLineBreak.txt
  switch (ch) {
  case 0x000A: // Line_Feed
  case 0x000B: case 0x000C: case 0x2028: case 0x2029: // Mandatory_Break
  case 0x000D: // Carriage_Return
  case 0x0020: // Space
  case 0x002D: // Hyphen
  case 0x0085: // Next_Line
  case 0x200B: // ZWSpace
  case 0x2014: case 0x2E3A: case 0x2E3B: // Break_Both (EM dashes)
  case 0xFFFC: // Object replacement character

  // Probably incomplete lists of code points from the Break_After class that may occur in text
  // that will be hyphenated:
  case 0x0009: // TAB
  case 0x00AD: // SOFT HYPHEN
  case 0x058A: // ARMENIAN HYPHEN
  case 0x05BE: // HEBREW PUNCTUATION MAQAF
  // EN QUAD..SIX-PER-EM SPACE
  case 0x2000: case 0x2001: case 0x2002: case 0x2003: case 0x2004: case 0x2005: case 0x2006:
  case 0x2008: case 0x2009: case 0x200A: // PUNCTUATION SPACE..HAIR SPACE
  case 0x2010: // HYPHEN
  case 0x2012: case 0x2013: // FIGURE DASH..EN DASH
  case 0x205F: // MEDIUM MATHEMATICAL SPACE
  case 0x3000: // IDEOGRAPHIC SPACE
    return true;
  default:
    return false;
  }
}

/// @pre 0 < index < attributedString.length
static
bool isLikelyGoodLineBreakLocation(const NSAttributedStringRef& attributedString, Int index) {
  const Char16 ch = attributedString.string[index - 1];
  if (isCodePointThatLikelyPrecedesGoodLineBreakLocation(ch)) return true;
  const Char16 ch1 = attributedString.string[index];
  switch (ch1) {
  case 0x2014: case 0x2E3A: case 0x2E3B: // The EM dashes.
  case 0xFFFC: // Object replacement character
    return true;
  default:
    return false;
  }
}

void TextFrameLayouter::breakLine(TextFrameLine& line, Int paraStringEndIndex) {
  STU_DEBUG_ASSERT(line._ctLine == nil);
  const Int start = line.rangeInOriginalString.start;
  STU_DEBUG_ASSERT(paraStringEndIndex > start);
  const Float64 maxWidth = lineMaxWidth_;
  const Float64 headIndent = lineHeadIndent_;
  Int end = min(paraStringEndIndex, start + CTTypesetterSuggestLineBreakWithOffset(
                                              typesetter_, start, maxWidth, headIndent));
  const NSStringRef& string = attributedString_.string;
  if (STU_UNLIKELY(end <= start)) {
    end = string.endIndexOfGraphemeClusterAt(start);
  }
  for (;;) {
    const Char16 lastChar = string[end - 1];
    line.isFollowedByTerminatorInOriginalString = isLineTerminator(lastChar);
    const Char32 hyphen = lastChar == softHyphenCodePoint ? hyphenCodePoint : 0;
    // Getting rid of the trailing whitespace before creating the CTLine simplifies all later
    // glyph-based processing of the line. This also helps avoiding running into rdar://34184703
    // https://openradar.appspot.com/radar?id=5491960840192000
    const Int end1 = hyphen == 0 ? string.indexOfTrailingWhitespaceIn({start, end}) : end;
    const auto status = breakLineAt(line, end1, Hyphen{hyphen},
                                    TrailingWhitespaceStringLength{end - end1});
    if (status.success) break;
    STU_DEBUG_ASSERT(hyphen != 0);
    const Int end2 = start + CTTypesetterSuggestLineBreakWithOffset(
                               typesetter_, start, status.ctLineWidthWithoutHyphen - 0.01,
                               headIndent);
    if (start < end2 && end2 < end
        // The typesetter might have suggested `end2` as a line break location because it couldn't
        // find any good location that would fit the max width.
        && isLikelyGoodLineBreakLocation(attributedString_, end2))
    {
      end = end2;
      continue;
    }
    // There is no good prior line break opportunity, so we break the line at the soft hyphen
    // without inserting a hyphen.
    breakLineAt(line, end, Hyphen{}, TrailingWhitespaceStringLength{0});
    break;
  }
  if (hyphenationFactor_ == 0 || end == paraStringEndIndex || maxWidth <= 0) {
    return;
  }
  const Int maxEnd = clamp(end,
                           start + CTTypesetterSuggestClusterBreakWithOffset(
                                     typesetter_, start, maxWidth, headIndent),
                           paraStringEndIndex);
  // The typesetter might have suggested `end` as a line break location because it couldn't
  // find any good location that would fit the max width. We might be able to improve on that
  // by finding a hyphenation location.
  const bool isGoodBreak = isLikelyGoodLineBreakLocation(attributedString_, end);
  if (isGoodBreak && (end == maxEnd || line.width/maxWidth >= hyphenationFactor_)) {
    return;
  }
  // `hyphenateLineInRange` will try to break the line with a hyphen in the specified range. If
  // successful, the result in `line` will be overwritten, otherwise `line` is not changed.
  hyphenateLineInRange(line, Range{isGoodBreak ? end : start,
                                   string.endIndexOfGraphemeClusterAt(maxEnd)});
}

} // namespace stu_label
