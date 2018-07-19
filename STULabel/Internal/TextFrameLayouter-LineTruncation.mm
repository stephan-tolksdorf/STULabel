// Copyright 2016–2018 Stephan Tolksdorf

#import "TextFrameLayouter.hpp"

#import "LineTruncation.hpp"
#import "Once.hpp"
#import "UnicodeCodePointProperties.hpp"

namespace stu_label {

void TextFrameLayouter::addAttributesNotYetPresentInAttributedString(
                          NSMutableAttributedString* const attributedString,
                          const NSRange fullRange,
                          NSDictionary<NSAttributedStringKey, id>* const attributes)
{
  [attributedString enumerateAttributesInRange:fullRange
        options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
     usingBlock:^(NSDictionary<NSAttributedStringKey, id>* const __unsafe_unretained oldAttributes,
                  const NSRange range, BOOL*)
  {
    if (oldAttributes.count == 0) {
      [attributedString setAttributes:attributes range:range];
    } else {
      NSMutableDictionary<NSAttributedStringKey, id>* const dict = [attributes mutableCopy];
      [dict addEntriesFromDictionary:oldAttributes]; // We want to keep the oldAttributes.
      [attributedString setAttributes:dict range:range];
    }
  }];
}

static NSDictionary<NSAttributedStringKey, id>*
  getAttributesThatApplyToWholeRangeIgnoringTrailingWhitespace(
    const NSAttributedStringRef& attributedString,
    const Range<Int> fullRange,
    // Here 'para' means 'text separated by line terminators'.
    const Int firstParaStartIndex,
    const Int firstParaTrailingWhitespaceIndex,
    const Int secondParaStartIndex)
{
  STU_DEBUG_ASSERT(firstParaStartIndex <= fullRange.start);
  STU_DEBUG_ASSERT(fullRange.start <= firstParaTrailingWhitespaceIndex);
  STU_DEBUG_ASSERT(firstParaTrailingWhitespaceIndex <= secondParaStartIndex);
  Range<Int> attributesRange{uninitialized};
  NSDictionary<NSAttributedStringKey, id>* const attributes =
    attributedString.attributesAtIndex(fullRange.start, OutEffectiveRange{attributesRange});

  __block NSMutableDictionary<NSAttributedStringKey, id>* mutableAttributes = nil;

  if (attributesRange.end < fullRange.end) {
    const NSStringRef& string = attributedString.string;
    TempVector<Range<Int>, 3> paraRangeVector;
    paraRangeVector.append(Range{fullRange.start, firstParaTrailingWhitespaceIndex});
    for (Int i = secondParaStartIndex; i < fullRange.end;) {
      const Int i3 = string.indexOfFirstUTF16CharWhere({i, fullRange.end}, isLineTerminator);
      const Int i2 = string.indexOfTrailingWhitespaceIn({i, i3});
      if (i < i2) {
        paraRangeVector.append(Range{i, i2});
      }
      i = i3;
      if (i + 1 >= fullRange.end) break;
      i += string.hasCRLFAtIndex(i) ? 2 : 1;
    }
    const auto& paraRanges = paraRangeVector; // The block should only capture this const reference.
    [attributes enumerateKeysAndObjectsUsingBlock:^(NSAttributedStringKey __unsafe_unretained key,
                                                    id __unsafe_unretained value, BOOL*)
    {
      for (const Range<Int>& paraRange : paraRanges) {
        const Range<UInt> range{paraRange};
        NSRange otherRange;
        const id otherValue = [attributedString.attributedString attribute:key atIndex:range.start
                                                     longestEffectiveRange:&otherRange
                                                                   inRange:range];
        if (range != otherRange || !equal(value, otherValue)) {
          if (!mutableAttributes) {
            mutableAttributes = [attributes mutableCopy];
          }
          [mutableAttributes removeObjectForKey:key];
          return;
        }
      }
    }];
  }
  // The default font is generally not good enough.
  if ([(mutableAttributes ?: attributes) objectForKey:NSFontAttributeName] == nil) {
    const Int i = fullRange.start - (fullRange.start > firstParaStartIndex);
    if (UIFont* font = [attributedString.attributesAtIndex(i) objectForKey:NSFontAttributeName]) {
      if (!mutableAttributes) {
        mutableAttributes = [attributes mutableCopy];
      }
      [mutableAttributes setObject:font forKey:NSFontAttributeName];
    }
  }
  return mutableAttributes ?: attributes;
}


void TextFrameLayouter::truncateLine(TextFrameLine& line,
                                     Int32 stringEndIndex,
                                     Range<Int32> originalTruncatableRange,
                                     CTLineTruncationType truncationMode,
                                     NSAttributedString* __unsafe_unretained __nullable
                                       truncationToken,
                                     __unsafe_unretained __nullable STUTruncationRangeAdjuster
                                       truncationRangeAdjuster,
                                     STUTextFrameParagraph& para,
                                     TextStyleBuffer& tokenStyleBuffer) const
{
  const Int32 paraTerminatorIndex = para.rangeInOriginalString.end
                                  - para.paragraphTerminatorInOriginalStringLength;
  const Int32 start = line.rangeInOriginalString.start;
  STU_DEBUG_ASSERT(stringEndIndex >= paraTerminatorIndex);
  line.isFollowedByTerminatorInOriginalString = para.paragraphTerminatorInOriginalStringLength != 0;
  const Int maxEnd = attributedString_.string.indexOfFirstUTF16CharWhere(
                       Range{start, stringEndIndex}, isLineTerminator);
  STU_DEBUG_ASSERT(maxEnd <= paraTerminatorIndex);
  const Int terminatorEndIndex = maxEnd == paraTerminatorIndex
                               ? para.rangeInOriginalString.end - paraTerminatorIndex
                               : maxEnd + 1; // The line-only terminator can't be "\r\n".
  const bool isSingleLineTruncation = maxEnd == paraTerminatorIndex
                                      && stringEndIndex <= para.rangeInOriginalString.end;
  const Int end = attributedString_.string.indexOfTrailingWhitespaceIn({start, maxEnd});
  const Range<Int> untruncatedRange = {start, end};
  CTLine* untruncatedLine = untruncatedRange.isEmpty() ? nullptr
                          : CTTypesetterCreateLineWithOffset(typesetter_, untruncatedRange,
                                                             lineHeadIndent_);
  const Float64 untruncatedWidth = untruncatedLine ? typographicWidth(untruncatedLine) : 0;
  if (STU_UNLIKELY(untruncatedLine && untruncatedWidth == 0)) {
    CFRelease(untruncatedLine);
    untruncatedLine = nullptr;
  }
  if (isSingleLineTruncation) {
    if (untruncatedWidth <= lineMaxWidth_) {
      line.init_step2(TextFrameLine::InitStep2Params{
        .rangeInOriginalStringEnd = end,
        .rangeInTruncatedStringCount = untruncatedRange.count(),
        .trailingWhitespaceInTruncatedStringLength = terminatorEndIndex - end,
        .ctLine = untruncatedLine,
        .width = untruncatedWidth
      });
      return;
    }
  } else { // !isSingleParaTruncation
    truncationMode = kCTLineTruncationEnd;
  }

  const NSArrayRef<CTRun*> untruncatedRuns = glyphRuns(untruncatedLine);
  const TruncatableTextLine truncatableTextLine = {
    .attributedString = attributedString_,
    .stringRange = untruncatedRange,
    .runs = untruncatedRuns,
    .width = typographicWidth(untruncatedLine),
    .isRightToLeftLine = untruncatedRuns.count() == 1
                       ? GlyphRunRef{untruncatedRuns[0]}.isRightToLeft()
                       : untruncatedRuns.count() == 0
                         ? para.baseWritingDirection != STUWritingDirectionLeftToRight
                         : GlyphRunRef{untruncatedRuns[0]}.stringRange().start
                           > GlyphRunRef{untruncatedRuns[$ - 1]}.stringRange().start,
    .truncatableStringRange = untruncatedRange.intersection(originalTruncatableRange)
  };

  Int32 tokenLength;
  if (!truncationToken) {
    tokenLength = 1;
  } else {
    const UInt length = truncationToken.length;
    if (0 < length && length < 4096) {
      tokenLength = narrow_cast<Int32>(length);
    } else {
      truncationToken = nil;
      tokenLength = 1;
    }
  }

  // The initial attributes dictionary is just a guess.
  NSDictionary<NSAttributedStringKey, id>* tokenAttributes =
    attributedString_.attributesAtIndex(truncationMode != kCTLineTruncationEnd
                                        ? start : max(end - 1, start));
  NSAttributedString* token = nil;
  STUWritingDirection tokenBaseWritingDirection{truncatableTextLine.isRightToLeftLine};

  CTLine* tokenLine = nullptr;
  Float64 tokenWidth = -infinity<Float64>;

  Range<Int> excisedRange{uninitialized};
  Float64 lineWidth;
  Float64 leftPartWidth;
  Float64 rightPartXOffset;
  RunGlyphIndex leftPartEnd;
  RunGlyphIndex rightPartStart;
  bool keepToken;
  bool keepUntruncated;

  Int iterationCount = 0;
  for (;;) {
    NSAttributedString* const previousToken = token;
    bool tokenIsMutable;
    if (!truncationToken) {
      // TODO: TextKit seems to choose the default ellipsis based on the script or langauge, e.g.
      //       for Japanese. Review whether we shold do something similar.
      token = [[NSAttributedString alloc] initWithString:@"…" attributes:tokenAttributes];
      // The NSMutableParagraphStyle.baseWritingDirection shouldn't matter for the ellipsis.
      tokenIsMutable = false;
    } else {
      NSMutableAttributedString* const mutableToken = [truncationToken mutableCopy];
      if (tokenAttributes) {
        addAttributesNotYetPresentInAttributedString(mutableToken,
                                                     NSRange{0, sign_cast(tokenLength)},
                                                     tokenAttributes);
      }
      NSParagraphStyle* __unsafe_unretained paraStyle;
      if (tokenBaseWritingDirection == STUWritingDirectionLeftToRight) {
        STU_STATIC_CONST_ONCE(NSParagraphStyle*, ltrStyle, ({
          NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
          style.baseWritingDirection = NSWritingDirectionLeftToRight;
          style;
        }));
        paraStyle = ltrStyle;
      } else {
        // TODO: Add radar numbers for CoreText RTL bugs.
        STU_STATIC_CONST_ONCE(NSParagraphStyle*, rtlStyle, ({
          NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
          style.baseWritingDirection = NSWritingDirectionRightToLeft;
          style;
        }));
        paraStyle = rtlStyle;
      }
      [mutableToken addAttribute:NSParagraphStyleAttributeName
                           value:paraStyle range:NSRange(Range{0, tokenLength})];
      token = mutableToken;
      tokenIsMutable = true;
    }
    if (++iterationCount > 1) {
      // If the attributedToken hasn't changed from the last iteration, we're done.
      if ([previousToken isEqual:token] || iterationCount == 4) break;
      CFRelease(tokenLine);
    }
    if (tokenIsMutable) {
      token = [token copy];
      tokenIsMutable = false;
    }
    tokenLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)token);
    STU_ASSERT(tokenLine);
    const Float64 previousTokenWidth = tokenWidth;
    tokenWidth = typographicWidth(tokenLine);
  #if STU_DEBUG
    STU_ASSERT(iterationCount != 1 || tokenWidth != previousTokenWidth);
  #else
    // For static analysis tools.
    STU_ASSUME(iterationCount != 1 || tokenWidth != previousTokenWidth);
  #endif
    // If the width didn't change, the truncation range and thus the attributes won't change either.
    if (tokenWidth == previousTokenWidth) break;
    if (tokenWidth >= lineMaxWidth_) {
      rightPartXOffset = 0;
      leftPartEnd = rightPartStart = RunGlyphIndex{-1, -1};
      // We rather exceed the max width than have no indication of truncation.
      if (tokenWidth < untruncatedWidth || !isSingleLineTruncation) {
        excisedRange = Range{start, stringEndIndex};
        keepUntruncated = false;
        keepToken = true;
        lineWidth = tokenWidth;
        leftPartWidth = 0;
        tokenBaseWritingDirection = para.baseWritingDirection;
      } else {
        excisedRange = Range{stringEndIndex, stringEndIndex};
        keepUntruncated = true;
        keepToken = false;
        lineWidth = untruncatedWidth;
        leftPartWidth = line.width;
      }
    } else {
      keepUntruncated = true;
      keepToken = true;
      const Float64 availableWidth = lineMaxWidth_ - tokenWidth;
      if (availableWidth >= untruncatedWidth) {
        // We can get here if the stringRange contains multiple line terminators and the first line
        // isn't long.
        STU_ASSERT(truncationMode == kCTLineTruncationEnd);
        excisedRange = Range{end, stringEndIndex};
        lineWidth = narrow_cast<Float32>(untruncatedWidth + tokenWidth);
        tokenBaseWritingDirection = para.baseWritingDirection;
        // We shouldn't have to adjust the kerning between the line and the token here.
        if (para.baseWritingDirection == STUWritingDirectionLeftToRight) {
          leftPartWidth = narrow_cast<Float32>(untruncatedWidth);
          rightPartXOffset = 0;
          leftPartEnd = rightPartStart = RunGlyphIndex{-1, -1};
        } else {
          leftPartWidth = 0;
          rightPartXOffset = tokenWidth;
          leftPartEnd = rightPartStart = RunGlyphIndex{0, 0};
        }
      } else { // availableWidth < untruncatedWidth
        tokenBaseWritingDirection = STUWritingDirection{truncatableTextLine.isRightToLeftLine};
        const ExcisedGlyphRange span = findRangeToExciseForTruncation(
                                         truncatableTextLine, truncationMode, availableWidth,
                                         truncationRangeAdjuster
                                       #if STU_TRUNCATION_TOKEN_KERNING
                                         , TokenForKerningPurposes{glyphRuns(tokenLine), tokenWidth,
                                                                   NSAttributedStringRef{token}}
                                       #endif
                                        );
        excisedRange = span.stringRange;
        if (excisedRange.end == end) {
          excisedRange.end = stringEndIndex;
        }
        lineWidth = span.adjustedWidthLeftOfExcision + span.adjustedWidthRightOfExcision
                  + tokenWidth;
        leftPartWidth = span.adjustedWidthLeftOfExcision;
        rightPartXOffset = lineWidth - untruncatedWidth;
        leftPartEnd = span.start;
        rightPartStart = span.end;
      }
    }
    if (!excisedRange.isEmpty()) {
      tokenAttributes = getAttributesThatApplyToWholeRangeIgnoringTrailingWhitespace(
                          attributedString_, excisedRange,
                          para.rangeInOriginalString.start, end, maxEnd);
    }
  } // for (;;)

  // Unfortunately, Clang's analysis currently can't handle the loop properly.
  STU_DISABLE_CLANG_WARNING("-Wconditional-uninitialized")

  if (!keepUntruncated && untruncatedLine) {
    CFRelease(untruncatedLine);
    untruncatedLine = nullptr;
  }

  Int tokenStylesOffset;
  TextFlags tokenTextFlags;
  if (keepToken) {
    tokenStylesOffset = tokenStyleBuffer.data().count();
    tokenTextFlags = tokenStyleBuffer.encode(token);
    para.truncationTokenLength = tokenLength;
    para.truncationToken = token;
    incrementRefCount(token);
  } else {
    CFRelease(tokenLine);
    tokenLine = nullptr;
    tokenWidth = 0;
    tokenStylesOffset = line._textStylesOffset;
    tokenTextFlags = TextFlags{};
  }

  para.excisedRangeInOriginalString.start = narrow_cast<Int32>(excisedRange.start);
  para.excisedRangeInOriginalString.end = min(narrow_cast<Int32>(excisedRange.end),
                                              para.rangeInOriginalString.end);

  line.init_step2(TextFrameLine::InitStep2Params{
    .rangeInOriginalStringEnd = end,
    .rangeInTruncatedStringCount = untruncatedRange.count()
                                 - (min(end, excisedRange.end) - excisedRange.start)
                                 + tokenLength,
    .trailingWhitespaceInTruncatedStringLength = max(0, terminatorEndIndex
                                                        - max(excisedRange.end, end)),
    .ctLine = untruncatedLine,
    .width = lineWidth,
    .token = {
      .isRightToLeftLine = truncatableTextLine.isRightToLeftLine,
      .leftPartEnd = leftPartEnd,
      .rightPartStart = rightPartStart,
      .leftPartWidth = leftPartWidth,
      .rightPartXOffset = rightPartXOffset,
      .tokenCTLine = tokenLine,
      .tokenWidth = tokenWidth,
      .tokenTextFlags = tokenTextFlags,
      .tokenStylesOffset = tokenStylesOffset
    }
  });

  STU_REENABLE_CLANG_WARNING
}

} // namespace stu_label
