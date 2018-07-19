// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyle.hpp"

#import "STULabel/STUTextHighlightStyle-Internal.hpp"

#import "InputClamping.hpp"
#import "TextFrame.hpp"
#import "TextFrameDrawingOptions.hpp"

#import "stu/Assert.h"

namespace stu_label {

const Int32 TextStyle::stringIndexMask[2] = {
  TextStyle::maxSmallStringIndex, IntegerTraits<Int32>::max
};

static_assert(alignof(TextStyle) == 4
              && sizeof(TextStyle::LinkInfo)%4 == 0
              && sizeof(TextStyle::BackgroundInfo)%4 == 0
              && sizeof(TextStyle::ShadowInfo)%4 == 0
              && sizeof(TextStyle::UnderlineInfo)%4 == 0
              && sizeof(TextStyle::StrikethroughInfo)%4 == 0
              && sizeof(TextStyle::StrokeInfo)%4 == 0
              && sizeof(TextStyle::AttachmentInfo)%4 == 0
              && sizeof(TextStyle::BaselineOffsetInfo)%4 == 0);

static_assert(TextStyle::maxSize - sizeof(TextStyle::BaselineOffsetInfo) <= 255);

STU_CONSTEXPR UInt8 infoOffset(UInt16 flags) {
  return sizeof(TextStyle)
       + ((flags & 1) ? sizeof(TextStyle::Big) - sizeof(TextStyle) : 0)
       + ((flags & (STUTextHasLink          << 1)) ? sizeof(TextStyle::LinkInfo) : 0)
       + ((flags & (STUTextHasBackground    << 1)) ? sizeof(TextStyle::BackgroundInfo) : 0)
       + ((flags & (STUTextHasShadow        << 1)) ? sizeof(TextStyle::ShadowInfo) : 0)
       + ((flags & (STUTextHasUnderline     << 1)) ? sizeof(TextStyle::UnderlineInfo) : 0)
       + ((flags & (STUTextHasStrikethrough << 1)) ? sizeof(TextStyle::StrikethroughInfo) : 0)
       + ((flags & (STUTextHasStroke        << 1)) ? sizeof(TextStyle::StrokeInfo) : 0)
       + ((flags & (STUTextHasAttachment    << 1)) ? sizeof(TextStyle::AttachmentInfo) : 0);
};

#define OFFSETS8(i) \
  infoOffset(i),   infoOffset(i+1), infoOffset(i+2), infoOffset(i+3), \
  infoOffset(i+4), infoOffset(i+5), infoOffset(i+6), infoOffset(i+7)

#define OFFSETS64(i) \
  OFFSETS8(i),     OFFSETS8(i+8),   OFFSETS8(i+8*2), OFFSETS8(i+8*3), \
  OFFSETS8(i+8*4), OFFSETS8(i+8*5), OFFSETS8(i+8*6), OFFSETS8(i+8*7)

constexpr UInt8 TextStyle::infoOffsets[256] = {
  OFFSETS64(0), OFFSETS64(64), OFFSETS64(2*64), OFFSETS64(3*64)
};

STU_NO_INLINE
const TextStyle& TextStyle::styleForStringIndex(Int32 stringIndex) const {
  const TextStyle* style = this;
  if (style->stringIndex() <= stringIndex) {
    for (;;) {
      const TextStyle& next = style->next();
      const Int32 index = next.stringIndex();
      if (index > stringIndex) break;
      if (style != &next) {
        style = &next;
        continue;
      }
      if (index == stringIndex) break;
      STU_CHECK_MSG(false, "Invalid index or corrupted text style data");
    }
  } else {
    STU_CHECK_MSG(stringIndex >= 0, "Negative string index");
    do style = &style->previous();
    while (style->stringIndex() > stringIndex);
  }
  return *style;
}

void TextStyleOverride::applyTo(const TextStyle& style) {
  const TextFlags styleFlags = style.flags();
  const TextFlags preservedFlags = styleFlags & this->flagsMask;
  const TextFlags effectiveFlags = this->flags | preservedFlags;

  const Int32 stringIndex = max(style.stringIndex(), this->overrideRangeInOriginalString.start);

  const FontIndex fontIndex = style.fontIndex();
  const ColorIndex colorIndex = this->textColorIndex ? *this->textColorIndex : style.colorIndex();

  const bool isBig = stringIndex > TextStyle::maxSmallStringIndex
                  || fontIndex.value > TextStyle::maxSmallFontIndex
                  || colorIndex.value > TextStyle::maxSmallColorIndex;

  using BitIndex = TextStyle::BitIndex;

  style_ = TextStyle::Big{
             isBig
             | (1 << TextStyle::BitIndex::isOverride)
             | (UInt64(effectiveFlags) << BitIndex::flags)
             | (static_cast<UInt64>(stringIndex) << BitIndex::stringIndex)
             | (isBig ? 0 : (UInt64{fontIndex.value} << BitIndex::Small::font))
             | (isBig ? 0 : (UInt64{colorIndex.value} << BitIndex::Small::color)),
             fontIndex,
             colorIndex
           };
  overriddenStyle_ = &style;

  if (!(effectiveFlags & (  TextFlags::hasBackground
                          | TextFlags::hasShadow
                          | TextFlags::hasUnderline
                          | TextFlags::hasStrikethrough
                          | TextFlags::hasStroke
                          | TextFlags::hasAttachment)))
  {
    return;
  }

  static_assert(static_cast<Int>(TextFlags::hasBackground) == 2);
  static_assert(static_cast<Int>(TextFlags::hasLink) == 1);
  // - 1 because hasBackground is the first overridable component, cf. nonnullInfoFromOverride

  #define setStyleInfo(component, styleInfoName) \
    styleInfos_[__builtin_ctz(static_cast<UInt16>(component)) - 1] = \
      !(preservedFlags & component) ? &highlightStyle->info.styleInfoName \
                                    : style.nonnullOwnInfo(component)

  setStyleInfo(TextFlags::hasBackground, background);
  setStyleInfo(TextFlags::hasShadow, shadow);
  setStyleInfo(TextFlags::hasUnderline, underline);
  setStyleInfo(TextFlags::hasStrikethrough, strikethrough);
  setStyleInfo(TextFlags::hasStroke, stroke);

  #undef setStyleInfo

  styleInfos_[__builtin_ctz(STUTextHasAttachment) - 1] =
    !(effectiveFlags & TextFlags::hasAttachment)
    ? nil : style.nonnullOwnInfo(TextFlags::hasAttachment);
}

TextStyleOverride::TextStyleOverride(Range<Int32> drawnLineRange,
                                     Range<Int32> drawnRangeInOriginalString,
                                     Range<TextFrameCompactIndex> drawnRange)
: drawnLineRange{drawnLineRange},
  drawnRangeInOriginalString{drawnRangeInOriginalString},
  drawnRange{drawnRange},
  overrideRangeInOriginalString{drawnRangeInOriginalString.end, drawnRangeInOriginalString.end},
  overrideRange{drawnRange.end, drawnRange.end},
  flagsMask{TextFlags{UINT16_MAX}},
  flags{TextFlags{}},
  textColorIndex{},
  style_{0, FontIndex{}, ColorIndex{}},
  overriddenStyle_{},
  highlightStyle{}
{}

// Sometimes C++ can be a little silly.
STU_INLINE
TextStyleOverride::TextStyleOverride(
  Range<Int32> drawnLineRange,
  Range<Int32> drawnRangeInOriginalString,
  Range<TextFrameCompactIndex> drawnRange,
  Range<Int32> overrideRangeInOriginalString,
  Range<TextFrameCompactIndex> overrideRange,
  TextFlags flagsMask,
  TextFlags flags,
  Optional<ColorIndex> textColorIndex,
  Optional<const TextHighlightStyle&> highlightStyle)
: drawnLineRange{drawnLineRange},
  drawnRangeInOriginalString{drawnRangeInOriginalString},
  drawnRange{drawnRange},
  overrideRangeInOriginalString{overrideRangeInOriginalString},
  overrideRange{overrideRange},
  flagsMask{flagsMask},
  flags{flags},
  textColorIndex{textColorIndex},
  style_{0, FontIndex{}, ColorIndex{}},
  highlightStyle{highlightStyle}
{}

TextStyleOverride TextStyleOverride::create(
                    const TextFrame& textFrame,
                    Range<TextFrameIndex> drawnRange,
                    Optional<const TextFrameDrawingOptions&> options)
{
  const Range<Int32> drawnRangeInOriginalString = textFrame.rangeInOriginalString(drawnRange);
  Range<Int32> highlightRangeInOriginalString{uninitialized};
  Range<TextFrameIndex> highlightRange{uninitialized};
  const STUTextHighlightStyle* __unsafe_unretained highlightStyle =
    !options ? nil : options->highlightStyle().unretained;
  if (highlightStyle) {
    if (!highlightStyle->style.textColorIndex
        && highlightStyle->style.flagsMask == TextFlags{UINT16_MAX})
    {
      highlightStyle = nil;
    } else {
      bool needRangeInOriginalString = true;
      if (const Optional<STUTextFrameRange> range = options->highlightTextFrameRange()) {
        highlightRange = *range;
      } else {
        const STUTextRange textRange = options->highlightRange();
        if (textRange.type == STURangeInOriginalString) {
          needRangeInOriginalString = false;
          highlightRangeInOriginalString = drawnRangeInOriginalString
                                           .intersection(clampToInt32IndexRange(textRange.range));
        }
        highlightRange = textFrame.range(textRange);
      }
      if (highlightRange.start < drawnRange.start) {
        highlightRange.start = drawnRange.start;
      }
      if (drawnRange.end < highlightRange.end) {
        highlightRange.end = drawnRange.end;
      }
      if (highlightRange.end <= highlightRange.start) {
        highlightStyle = nil;
      } else if (needRangeInOriginalString) {
        // If the following range conversion causes a crash, the STUTextFrameDrawingOptions
        // contained a highlightTextFrameRange that is not valid for this textFrame.
        highlightRangeInOriginalString = textFrame.rangeInOriginalString(highlightRange);
      }
    }
  }
  Range<Int32> drawnLineRange = {sign_cast(drawnRange.start.lineIndex),
                                 sign_cast(drawnRange.end.lineIndex)};
  if (drawnLineRange.end < textFrame.lines().count()
      && (drawnRange.end.isIndexOfInsertedHyphen
          || (drawnRange.end.indexInTruncatedString
              != textFrame.lineStringIndices()[drawnLineRange.end].startIndexInTruncatedString)))
  {
    drawnLineRange.end += 1;
  }

  if (!highlightStyle) {
    return {drawnLineRange, drawnRangeInOriginalString, drawnRange};
  }
  return {drawnLineRange, drawnRangeInOriginalString, drawnRange,
          highlightRangeInOriginalString, highlightRange,
          highlightStyle->style.flagsMask, highlightStyle->style.flags,
          highlightStyle->style.textColorIndex, highlightStyle->style};
}

TextStyleOverride::TextStyleOverride(
  const TextFrame& textFrame,
  Range<TextFrameIndex> drawnRange,
  Optional<const TextFrameDrawingOptions&> options)
: TextStyleOverride{create(textFrame, drawnRange, options)} {}

} // namespace stu_label
