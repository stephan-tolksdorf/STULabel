// Copyright 2017–2018 Stephan Tolksdorf

#import "DrawingContext.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

constexpr UInt16 colorIndexOffsets[2] = {ColorIndex::fixedColorIndexRange.start,
                                         ColorIndex::fixedColorIndexRange.end};

STU_NO_INLINE
CGColor* DrawingContext::cgColor(ColorIndex colorIndex) {
  const UInt isTextFrameColor = colorIndex.value >= ColorIndex::fixedColorIndexRange.end;
  UInt32 index = colorIndex.value;
  index -= colorIndexOffsets[isTextFrameColor]; // May wrap around.
  STU_ASSERT(index < colorCounts_[isTextFrameColor]);
  return colorArrays_[isTextFrameColor][index].cgColor();
}

STU_NO_INLINE
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
