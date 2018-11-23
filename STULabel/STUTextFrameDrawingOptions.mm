// Copyright 2018 Stephan Tolksdorf

#import "STUTextFrameDrawingOptions-Internal.hpp"

#import "STUObjCRuntimeWrappers.h"

#import "Internal/Equal.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/Once.hpp"

namespace stu_label {

STU_NO_INLINE STU_NO_RETURN
void TextFrameDrawingOptions::attemptedMutationOfFrozenObject() {
  STU_CHECK_MSG(false, "ERROR: Attempted mutation of frozen STUTextFrameDrawingOptions object.");
}

} // namespace stu_label

using namespace stu_label;

@implementation STUTextFrameDrawingOptions {
}

- (instancetype)copyWithZone:(NSZone* __unused)zone {
  STUTextFrameDrawingOptions* const instance = [[self.class alloc] init];
  instance->impl = self->impl;
  instance->impl.unfreeze_after_copy_initialization();
  return instance;
}

STUTextFrameDrawingOptions*
  STUTextFrameDrawingOptionsCopy(STUTextFrameDrawingOptions* __nullable other) NS_RETURNS_RETAINED
{
  STU_STATIC_CONST_ONCE(Class, stuTextFrameDrawingOptionsClass, STUTextFrameDrawingOptions.class);
  STU_ANALYZER_ASSUME(stuTextFrameDrawingOptionsClass != nil);
  STUTextFrameDrawingOptions* instance = stu_createClassInstance(stuTextFrameDrawingOptionsClass, 0);
  if (other) {
    STU_DEBUG_ASSERT(other.class == stuTextFrameDrawingOptionsClass);
    instance->impl = other->impl;
    instance->impl.unfreeze_after_copy_initialization();
  }
  return instance;
}

- (bool)isFrozen { return impl.isFrozen(); }
- (void)freeze { impl.freeze(); }

- (STUTextFrameDrawingMode)drawingMode {
  return impl.drawingMode();
}
- (void)setDrawingMode:(STUTextFrameDrawingMode)drawingMode {
  impl.setDrawingMode(drawingMode);
}

- (STUTextRange)highlightRange { return impl.highlightRange(); }
- (void)setHighlightRange:(STUTextRange)highlightRange {
  impl.setHighlightRange(highlightRange.range, highlightRange.type);
}
- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType {
  impl.setHighlightRange(range, clampTextRangeType(rangeType));
}

- (bool)getHighlightTextFrameRange:(STUTextFrameRange*)outTextFrameRange {
  if (const auto range = impl.highlightTextFrameRange()) {
    if (outTextFrameRange) {
      *outTextFrameRange = *range;
    }
    return true;
  }
  return false;
}

- (void)setHighlightTextFrameRange:(STUTextFrameRange)textFrameRange {
  impl.setHighlightRange(textFrameRange);
}

- (STUTextHighlightStyle*)highlightStyle { return impl.highlightStyle().unretained; }
- (void)setHighlightStyle:(STUTextHighlightStyle*)highlightStyle {
  impl.setHighlightStyle(highlightStyle);
}

- (bool)overrideColorsApplyToHighlightedText {
  return impl.overrideColorsApplyToHighlightedText();
}
- (void)setOverrideColorsApplyToHighlightedText:(bool)overrideColorsApplyToHighlightedText {
  impl.setOverrideColorsApplyToHighlightedText(overrideColorsApplyToHighlightedText);
}

- (UIColor*)overrideTextColor {
  return impl.overrideTextUIColor().unretained;
}
- (void)setOverrideTextColor:(UIColor*)overrideTextColor {
  impl.setOverrideTextColor(overrideTextColor);
}

- (UIColor*)overrideLinkColor {
  return impl.overrideLinkUIColor().unretained;
}
- (void)setOverrideLinkColor:(UIColor*)overrideLinkColor {
  impl.setOverrideTextColor(overrideLinkColor);
}

@end

