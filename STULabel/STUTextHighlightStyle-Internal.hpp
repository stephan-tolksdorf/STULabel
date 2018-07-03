// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextHighlightStyle.h"

#import "Internal/TextStyle.hpp"

namespace stu_label {

struct TextHighlightStyle {
  struct Info {
    TextStyle::BackgroundInfo    background;
    TextStyle::ShadowInfo        shadow;
    TextStyle::UnderlineInfo     underline;
    TextStyle::StrikethroughInfo strikethrough;
    TextStyle::StrokeInfo        stroke;
  };

  using ColorArray = Color[stu_label::ColorIndex::highlightColorCount];

  TextFlags flagsMask;
  TextFlags flags;
  Optional<ColorIndex> textColorIndex;
  ColorArray colors;
  Info info;
};

} // namespace stu_label

@interface STUTextHighlightStyle() {
@package
  stu_label::TextHighlightStyle style;
}
@end

