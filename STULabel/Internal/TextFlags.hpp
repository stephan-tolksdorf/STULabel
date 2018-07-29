// Copyright 2017 Stephan Tolksdorf

#import "STULabel/STUTextFrame.h"

#import "Common.hpp"

namespace stu_label {

enum class TextFlags : UnderlyingType<STUTextFlags> {
  hasLink           = STUTextHasLink,
  hasBackground     = STUTextHasBackground,
  hasShadow         = STUTextHasShadow,
  hasUnderline      = STUTextHasUnderline,
  hasStrikethrough  = STUTextHasStrikethrough,
  hasStroke         = STUTextHasStroke,
  hasAttachment     = STUTextHasAttachment,
  hasBaselineOffset = STUTextHasBaselineOffset,
  mayNotBeGrayscale = STUTextMayNotBeGrayscale,
  usesExtendedColor = STUTextUsesExtendedColor,

  decorationFlags   = STUTextDecorationFlags,
  colorFlags        = STUTextMayNotBeGrayscale | STUTextUsesExtendedColor,
};
static constexpr int TextFlagsBitSize = STUTextFlagsBitSize;
static_assert((1 << TextFlagsBitSize) > (  STUTextDecorationFlags
                                         | STUTextHasAttachment
                                         | STUTextHasBaselineOffset
                                         | STUTextMayNotBeGrayscale
                                         | STUTextUsesExtendedColor));

STU_CONSTEXPR STUTextFlags stuTextFlags(TextFlags flags) {
  return static_cast<STUTextFlags>(flags);
}

} // namespace stu_label

template <>
struct stu::IsOptionsEnum<stu_label::TextFlags> : stu::True {};

namespace stu_label::detail {
  static_assert(STUTextFlagsBitSize < sizeof(TextFlags)*8);
  constexpr TextFlags everyRunFlag = static_cast<TextFlags>(1 << STUTextFlagsBitSize);
}
