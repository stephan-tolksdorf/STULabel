// Copyright 2017–2018 Stephan Tolksdorf

#import "Color.hpp"

namespace stu_label {

ColorFlags colorFlags(const RGBA& rgba) {
  const auto [r, g, b, a] = rgba;
  if (a <= 0) return ColorFlags::isClear;
  return (a < 1 ? ColorFlags{} : ColorFlags::isOpaque)
       | (r == g && g == b ? ColorFlags{} : ColorFlags::isNotGray)
       | (0 <= r && r <= 1 && 0 <= g && g <= 1 && 0 <= b && b <= 1
          ? ColorFlags{} : ColorFlags::isExtended)
       | (r == 0 && g == 0 && b == 0 && a >= 1 ? ColorFlags::isBlack : ColorFlags{});
}

ColorFlags colorFlags(UIColor* __unsafe_unretained __nullable color) {
  if (STU_UNLIKELY(!color)) {
    return ColorFlags::isClear;
  }
  if (Optional<RGBA> rgba = RGBA::of(color)) {
    return colorFlags(*rgba);
  }
  return ColorFlags::isNotGray;
}

ColorFlags colorFlags(CGColor* __nullable color) {
  if (STU_UNLIKELY(!color)) {
    return ColorFlags::isClear;
  }
  // Allocating a temporary UIColor object here is inefficient, but convenient.
  return colorFlags([UIColor colorWithCGColor:color]);
}

}
