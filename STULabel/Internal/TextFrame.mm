// Copyright 2017–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "CancellationFlag.hpp"
#import "CoreGraphicsUtils.hpp"
#import "TextFrameLayouter.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

TextFrame::SizeAndOffset TextFrame::objectSizeAndThisOffset(const TextFrameLayouter& layouter) {
  // The data layout must be kept in-sync with
  //   TextFrame::verticalSearchTable
  //   TextFrame::lineStringIndices
  //   STUTextFrameDataGetParagraphs
  //   STUTextFrameDataGetLines
  //   STUTextFrameLineGetParagraph
  //   TextFrame::colors()
  //   stu_label_lldb_formatters.STUTextFrameData_ChildrenProvider

  static_assert(IntervalSearchTable::arrayElementSize%alignof(STUTextFrameData) == 0
                && sizeof(StringStartIndices)%alignof(STUTextFrameData) == 0
                && alignof(STUTextFrameData) == alignof(STUTextFrameLine)
                && alignof(STUTextFrameData) == alignof(STUTextFrameParagraph)
                && alignof(STUTextFrameData) == alignof(ColorRef)
                && alignof(STUTextFrameData) >= alignof(TextStyle));

  const Int lineCount = layouter.lines().count();

  const UInt verticalSearchTableSize = IntervalSearchTable::sizeInBytesForCount(lineCount);
  const UInt lineStringIndicesTableSize = sizeof(StringStartIndices)*sign_cast(lineCount + 1);
  const Int stylesTerminatorSize = TextStyle::sizeOfTerminatorWithStringIndex(
                                                layouter.rangeInOriginalString().end);
  const ArrayRef<const ColorRef> colors = layouter.colors();

  return {.offset = verticalSearchTableSize + sanitizerGap
                  + lineStringIndicesTableSize + sanitizerGap,
          .size = verticalSearchTableSize
                + sanitizerGap
                + lineStringIndicesTableSize
                + sanitizerGap
                + sizeof(STUTextFrameData)
                + layouter.paragraphs().arraySizeInBytes()
                + layouter.lines().arraySizeInBytes()
                + sanitizerGap
                + colors.arraySizeInBytes()
                + sanitizerGap
                + layouter.originalStringStyles().dataExcludingTerminator().arraySizeInBytes()
                + sign_cast(stylesTerminatorSize)
                + layouter.truncationTokenTextStyleData().arraySizeInBytes()
                + sanitizerGap};
}

TextFrame::TextFrame(TextFrameLayouter&& layouter, UInt dataSize)
: STUTextFrameData{
    .paragraphCount = narrow_cast<Int32>(layouter.paragraphs().count()),
    .lineCount = narrow_cast<Int32>(layouter.lines().count()),
    ._colorCount = narrow_cast<UInt16>(layouter.colors().count()),
    .layoutMode = layouter.layoutMode(),
    .size = narrow_cast<CGSize>(layouter.scaleInfo().scale*layouter.inverselyScaledFrameSize()),
    .textScaleFactor = layouter.scaleInfo().scale,
    .displayScale = layouter.scaleInfo().originalDisplayScale,
    .rangeInOriginalStringIsFullString = layouter.rangeInOriginalStringIsFullString(),
    ._layoutIterationCount = narrow_cast<UInt8>(layouter.layoutCallCount()),
    .rangeInOriginalString = layouter.rangeInOriginalString(),
    .truncatedStringLength = layouter.truncatedStringLength(),
    .originalAttributedString = layouter.attributedString().attributedString,
    ._dataSize = dataSize
  }
{
  incrementRefCount(originalAttributedString);
  const Range<Int32> stringRange = rangeInOriginalString();
  const Int originalStylesTerminatorSize = TextStyle
                                           ::sizeOfTerminatorWithStringIndex(stringRange.end);
  const UInt originalStringTextStyleDataSize = sign_cast(layouter.originalStringStyles()
                                                         .dataExcludingTerminator().count()
                                                         + originalStylesTerminatorSize);
  _textStylesData = reinterpret_cast<const uint8_t*>(this)
                  + dataSize
                  - sanitizerGap
                  - layouter.truncationTokenTextStyleData().count()
                  - originalStringTextStyleDataSize;

#if STU_USE_ADDRESS_SANITIZER
  sanitizer::poison((Byte*)verticalSearchTable().startValues().end(), sanitizerGap);
  sanitizer::poison((Byte*)lineStringIndices().end(), sanitizerGap);
  sanitizer::poison((Byte*)lines().end(), sanitizerGap);
  sanitizer::poison((Byte*)colors().end(), sanitizerGap);
  sanitizer::poison((Byte*)this + _dataSize - sanitizerGap, sanitizerGap);
#endif
  { // Write out the data into the embedded arrays.
    Byte* p = reinterpret_cast<Byte*>(this + 1);
    using array_utils::copyConstructArray;

    layouter.relinquishOwnershipOfCTLinesAndParagraphTruncationTokens();

    copyConstructArray(layouter.paragraphs(), reinterpret_cast<TextFrameParagraph*>(p));
    p += layouter.paragraphs().arraySizeInBytes();

    copyConstructArray(layouter.lines(), reinterpret_cast<TextFrameLine*>(p));
    p += layouter.lines().arraySizeInBytes();
    p += sanitizerGap;

    const ArrayRef<const ColorRef> colors = layouter.colors();
    for (auto& color : colors) {
      CFRetain(color.cgColor());
    }
    copyConstructArray(colors, reinterpret_cast<ColorRef*>(p));
    p += colors.arraySizeInBytes();
    p += sanitizerGap;

    STU_ASSERT(p == _textStylesData);
    const TextStyleSpan originalStyles = layouter.originalStringStyles();
    copyConstructArray(originalStyles.dataExcludingTerminator(), p);
    if (stringRange.start > 0) {
      TextStyle* const style = reinterpret_cast<TextStyle*>(p);
      STU_ASSERT(style->stringIndex() <= stringRange.start);
      style->setStringIndex(stringRange.start);
    }
    p += originalStyles.dataExcludingTerminator().count();
    TextStyle::writeTerminatorWithStringIndex(stringRange.end,
                                              p - originalStyles.lastStyleSizeInBytes(),
                                              ArrayRef{p, originalStylesTerminatorSize});
    p += originalStylesTerminatorSize;
    STU_DEBUG_ASSERT(p + layouter.truncationTokenTextStyleData().count() + sanitizerGap
                     == reinterpret_cast<Byte*>(this) + dataSize);
    copyConstructArray(layouter.truncationTokenTextStyleData(), p);
  }

  const ArrayRef<TextFrameParagraph> paragraphs = const_array_cast(this->paragraphs());
  const ArrayRef<TextFrameLine> lines = const_array_cast(this->lines());
  const ArrayRef<StringStartIndices> lineIndices = const_array_cast(lineStringIndices());

  lineIndices[lines.count()].startIndexInOriginalString = rangeInOriginalString().end;
  lineIndices[lines.count()].startIndexInTruncatedString = truncatedStringLength;

  if (lines.isEmpty()) {
    this->consistentAlignment = STUTextFrameConsistentAlignmentLeft;
    this->flags = STUTextFrameHasMaxTypographicWidth;
    return;
  }

  bool isTruncated = false;
  TextFlags flags{};
  Range<Float64> xBounds = Range<Float64>::infinitelyEmpty();
  const ArrayRef<Float32> increasingMaxYs{const_array_cast(verticalSearchTable().endValues())};
  const ArrayRef<Float32> increasingMinYs{const_array_cast(verticalSearchTable().startValues())};
  Float32 maxY = minValue<Float32>;

  const Float64 inverseScale = layouter.scaleInfo().inverseScale;

  Int32 lineIndex = 0;
  for (TextFrameParagraph& para : paragraphs) {
    isTruncated |= !para.excisedRangeInOriginalString().isEmpty();

    bool isIndented = para.isIndented;
    Float64 initialLeftIndent;
    Float64 initialRightIndent;
    Float64 nonInitialLeftIndent;
    Float64 nonInitialRightIndent;
    if (isIndented) {
      const ShapedString::Paragraph& p = layouter.originalStringParagraphs()[para.paragraphIndex];
      initialLeftIndent  = p.commonLeftIndent*inverseScale;
      initialRightIndent = p.commonRightIndent*inverseScale;
      nonInitialLeftIndent  = initialLeftIndent;
      nonInitialRightIndent = initialRightIndent;
      if (p.initialExtraLeftIndent == 0) {
        para.initialLinesLeftIndent    = p.commonLeftIndent;
        para.nonInitialLinesLeftIndent = p.commonLeftIndent;
      } else {
        if (p.initialExtraLeftIndent > 0) {
          initialLeftIndent += p.initialExtraLeftIndent;
          para.nonInitialLinesLeftIndent = p.commonLeftIndent;
          para.initialLinesLeftIndent = p.commonLeftIndent
                                      + textScaleFactor*p.initialExtraLeftIndent;

        } else {
          nonInitialLeftIndent -= p.initialExtraLeftIndent;
          para.initialLinesLeftIndent = p.commonLeftIndent;
          para.nonInitialLinesLeftIndent = p.commonLeftIndent
                                         - textScaleFactor*p.initialExtraLeftIndent;
        }
      }
      if (p.initialExtraRightIndent == 0) {
        para.initialLinesRightIndent    = p.commonRightIndent;
        para.nonInitialLinesRightIndent = p.commonRightIndent;
      } else {
        if (p.initialExtraRightIndent > 0) {
          initialRightIndent += p.initialExtraRightIndent;
          para.nonInitialLinesRightIndent = p.commonRightIndent;
          para.initialLinesRightIndent = p.commonRightIndent
                                       + textScaleFactor*p.initialExtraRightIndent;

        } else {
          nonInitialRightIndent -= p.initialExtraRightIndent;
          para.initialLinesRightIndent = p.commonRightIndent;
          para.nonInitialLinesRightIndent = p.commonRightIndent
                                          - textScaleFactor*p.initialExtraRightIndent;
        }
      }
    }

    TextFlags paraFlags{};
    for (; lineIndex < para.lineIndexRange().end; ++lineIndex) {
      TextFrameLine& line = lines[lineIndex];

      STU_ASSERT(line._initStep == 5);
      line._initStep = 0;

      paraFlags = paraFlags | TextFlags{line.textFlags()};

      lineIndices[lineIndex].startIndexInOriginalString = line.rangeInOriginalString.start;
      lineIndices[lineIndex].startIndexInTruncatedString = line.rangeInTruncatedString.start;

      Range<Float64> x = line.originX + Range{0., line.width};
      if (isIndented) {
        STU_DISABLE_CLANG_WARNING("-Wconditional-uninitialized")
        const Float64 leftIndent = lineIndex < para.initialLinesEndIndex
                                 ? initialLeftIndent : nonInitialLeftIndent;
        const Float64 rightIndent = lineIndex < para.initialLinesEndIndex
                                  ? initialRightIndent : nonInitialRightIndent;
        STU_REENABLE_CLANG_WARNING
        x.start -= leftIndent;
        x.end += rightIndent;
      }
      xBounds = xBounds.convexHull(x);

      if (const auto& displayScale = layouter.scaleInfo().displayScale) {
        line.originY = ceilToScale(line.originY, *displayScale);
      }

      if (line.hasTruncationToken) {
        line._tokenStylesOffset += originalStringTextStyleDataSize;
      }
      if (line.textFlags() & (TextFlags::decorationFlags | TextFlags::hasAttachment)) {
        stu_label::detail::adjustFastTextFrameLineBoundsToAccountForDecorationsAndAttachments(
                             line, layouter.localFontInfoCache());
      }

      // Note that the line's fast bounds currently always encompass the typographic bounds (see
      // TextFrameLayouter::initializeTypographicMetricsOfLine), so that we can use the vertical
      // search table for finding lines whose typographic *or* image bounds intersect vertically
      // with a specified range.
      maxY = max(maxY, narrow_cast<Float32>(line.originY - line.fastBoundsLLOMinY));
      increasingMaxYs[lineIndex] = maxY;
      // We'll do a second pass over the increasingMinYs below.
      increasingMinYs[lineIndex] = narrow_cast<Float32>(line.originY - line.fastBoundsLLOMaxY);
    }
    implicit_cast<STUTextFrameParagraph&>(para).textFlags = static_cast<STUTextFlags>(paraFlags);
    flags |= paraFlags;
  }

  {
    Float32 minY = infinity<Float32>;
    STU_DISABLE_LOOP_UNROLL
    for (Float32& value : increasingMinYs.reversed()) {
      value = minY = min(value, minY);
    }
  }

  this->minX = textScaleFactor*xBounds.start;
  this->maxX = textScaleFactor*xBounds.end;

  const auto& firstLine = lines[0];
  const auto& lastLine = lines[$ - 1];

  this->firstBaseline = textScaleFactor*firstLine.originY;
  this->lastBaseline = textScaleFactor*lastLine.originY;

  const Float32 firstLineHeight = firstLine._heightAboveBaseline + firstLine._heightBelowBaseline;
  const Float32 lastLineHeight = lastLine._heightAboveBaseline + lastLine._heightBelowBaseline;
  const Float32 firstLineMinBaselineDistance =
                  layouter.originalStringParagraphs()[0].minBaselineDistance;
  const Float32 lastLineMinBaselineDistance =
                  layouter.originalStringParagraphs()[lastLine.paragraphIndex].minBaselineDistance;

  const Float32 scale32 = narrow_cast<Float32>(textScaleFactor);

  this->firstLineHeight = scale32*max(firstLineHeight, firstLineMinBaselineDistance);
  this->firstLineHeightAboveBaseline =
    scale32*(firstLine._heightAboveBaseline
             + max(0.f, (firstLineMinBaselineDistance - firstLineHeight)/2));

  this->lastLineHeight = scale32*max(lastLineHeight, lastLineMinBaselineDistance);
  this->lastLineHeightBelowBaselineWithoutSpacing =
    scale32*lastLine._heightBelowBaselineWithoutSpacing;
  this->lastLineHeightBelowBaselineWithMinimalSpacing =
    scale32*min(lastLine._heightBelowBaseline,
                lastLine._heightBelowBaselineWithoutSpacing
                + layouter.minimalSpacingBelowLastLine());
  this->lastLineHeightBelowBaseline =
    scale32*(lastLine._heightBelowBaseline
             + max(0.f, (lastLineMinBaselineDistance - lastLineHeight)/2));

  STUTextFrameConsistentAlignment consistentAlignment = stuTextFrameConsistentAlignment(
                                                          paragraphs[0].alignment);
  for (const TextFrameParagraph& para : paragraphs[{1, $}]) {
    if (consistentAlignment != stuTextFrameConsistentAlignment(para.alignment)) {
      consistentAlignment = STUTextFrameConsistentAlignmentNone;
      break;
    }
  }

  const bool isScaled = this->textScaleFactor < 1;

  bool hasMaxTypographicWidth = consistentAlignment != STUTextFrameConsistentAlignmentNone
                             && !isTruncated
                             && !isScaled;
  if (hasMaxTypographicWidth) {
    Int32 i = 0;
    for (const TextFrameParagraph& para : paragraphs) {
      if (para.lineIndexRange().end == ++i) continue;
      hasMaxTypographicWidth = false;
      break;
    }
  }

  this->consistentAlignment = consistentAlignment;
  this->flags = static_cast<STUTextFrameFlags>(
                  static_cast<STUTextFrameFlags>(flags)
                  | (isTruncated ? STUTextFrameIsTruncated : 0)
                  | (isScaled ? STUTextFrameIsScaled : 0)
                  | (hasMaxTypographicWidth ? STUTextFrameHasMaxTypographicWidth : 0));
}


TextFrame::~TextFrame() {
  if (const void* const bs = atomic_load_explicit(&_backgroundSegments, memory_order_relaxed)) {
    free(const_cast<void*>(bs));
  }
  if (flags & STUTextFrameIsTruncated) {
    if (const CFAttributedString* const ts = atomic_load_explicit(&_truncatedAttributedString,
                                                                  memory_order_relaxed))
    {
      discard((__bridge_transfer NSAttributedString*)ts); // Releases the string.
    }
    for (const TextFrameParagraph& para : paragraphs().reversed()) {
      if (para.truncationToken) {
        decrementRefCount(para.truncationToken);
      }
    }
  }
  for (const TextFrameLine& line : lines().reversed()) {
    line.releaseCTLines();
  }
  for (ColorRef color : colors()) {
    decrementRefCount(color.cgColor());
  }
  decrementRefCount(originalAttributedString);

#if STU_USE_ADDRESS_SANITIZER
  sanitizer::unpoison((Byte*)verticalSearchTable().startValues().end(), sanitizerGap);
  sanitizer::unpoison((Byte*)lineStringIndices().end(), sanitizerGap);
  sanitizer::unpoison((Byte*)lines().end(), sanitizerGap);
  sanitizer::unpoison((Byte*)colors().end(), sanitizerGap);
  sanitizer::unpoison((Byte*)this + _dataSize - sanitizerGap, sanitizerGap);
#endif
}

Rect<CGFloat> TextFrame::calculateImageBounds(TextFrameOrigin originalTextFrameOrigin,
                                              const ImageBoundsContext& originalContext) const
{
  ImageBoundsContext context{originalContext};
  Point<Float64> textFrameOrigin{originalTextFrameOrigin};
  if (textScaleFactor < 1) {
    textFrameOrigin /= textScaleFactor;
    if (context.displayScale) {
      context.displayScale = DisplayScale::create(textScaleFactor * *context.displayScale);
    }
  }
  Rect<Float64> bounds = Rect<Float64>::infinitelyEmpty();
  ArrayRef<const TextFrameLine> lines = this->lines();
  if (context.styleOverride) {
    lines = lines[context.styleOverride->drawnLineRange];
  }
  for (const TextFrameLine& line : lines) {
    Rect<CGFloat> r = line.calculateImageBoundsLLO(context);
    if (context.isCancelled()) break;
    if (r.isEmpty()) continue;
    r.y *= -1;
    Point<Float64> lineOrigin = textFrameOrigin + line.origin();
    if (context.displayScale) {
      lineOrigin.y = ceilToScale(lineOrigin.y, *context.displayScale);
    }
    bounds = bounds.convexHull(lineOrigin + r);
  }
  if (bounds.x.start == Rect<Float64>::infinitelyEmpty().x.start) {
    return Rect<CGFloat>{narrow_cast<CGPoint>(originalTextFrameOrigin.value), {}};
  }
  return narrow_cast<Rect<CGFloat>>(textScaleFactor*bounds);
}


} // namespace stu_label
