// Copyright 2017–2018 Stephan Tolksdorf

#import "DrawingContext.hpp"

namespace stu_label {

CGColor* DrawingContext::cgColor(ColorIndex colorIndex) {
  const bool isTextFrameColor = colorIndex.value < ColorIndex::fixedColorStartIndex;
  const ColorRef* const array = isTextFrameColor ? textFrameColors_ : otherColors_;
  const UInt indexOffset = isTextFrameColor ? 1 : ColorIndex::fixedColorStartIndex;
  const UInt colorCount = isTextFrameColor ? textFrameColorCount_ : ColorIndex::fixedColorCount;
  UInt index = colorIndex.value;
  index -= indexOffset; // May wrap around.
  STU_ASSERT(index < colorCount);
  return array[index].cgColor();
}

void DrawingContext::setShadow_slowPath(const TextStyle::ShadowInfo* __nullable shadowInfo) {
  const TextStyle::ShadowInfo* const previousShadowInfo = shadowInfo_;
  shadowInfo_ = shadowInfo;
  if (shadowInfo) {
    if (shadowInfo == previousShadowInfo
        || (shadowInfo && previousShadowInfo && *shadowInfo == *previousShadowInfo))
    {
      return;
    }
    const CGFloat yScale = shadowYExtraScaleFactor_;
    const CGFloat xScale = abs(yScale);
    const CGSize offset = {xScale*(shadowInfo->offsetX + currentShadowExtraXOffset()),
                           yScale*shadowInfo->offsetY};
    const CGFloat blurRadius = xScale*shadowInfo->blurRadius;
    CGContextSetShadowWithColor(cgContext_, offset, blurRadius, cgColor(shadowInfo->colorIndex));
  } else {
    CGContextSetShadowWithColor(cgContext_, (CGSize){}, 0, nil);
  }
}

STU_NO_INLINE
void DrawingContext::initializeGlyphBoundsCache() {
  STU_APPEARS_UNUSED
  const bool isNotInitialized = !glyphBoundsCache_;
  STU_ASSUME(isNotInitialized);
  glyphBoundsCache_.emplace();
}


} // namespace stu_label
