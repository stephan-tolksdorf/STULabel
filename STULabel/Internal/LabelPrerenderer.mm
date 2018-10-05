// Copyright 2017–2018 Stephan Tolksdorf

#import "LabelPrerenderer.hpp"

#import "STULabel/STUObjCRuntimeWrappers.h"

STU_EXTERN_C_BEGIN

STULabelPrerenderer* STULabelPrerendererAlloc(const Class prerendererClass) NS_RETURNS_RETAINED {
  using namespace stu_label;
  const size_t instanceSize = class_getInstanceSize(prerendererClass);
  void* const p = malloc(sizeof(LabelPrerenderer) + instanceSize);
  if (!p) stu::detail::badAlloc();
  LabelPrerenderer* const prerenderer = new (p) LabelPrerenderer();
  memset(prerenderer->objcObjectStorage, 0, instanceSize);
  STULabelPrerenderer* const instance = stu_constructClassInstance(
                                          prerendererClass, prerenderer->objcObjectStorage);
  STU_DEBUG_ASSERT([instance isKindOfClass:STULabelPrerenderer.class]);
  instance->prerenderer = prerenderer;
  return instance;
}

STU_EXTERN_C_END

namespace stu_label {

void LabelPrerenderer::destroyAndDeallocate() {
  this->~LabelPrerenderer();
  free(this);
}

LabelPrerenderer::LabelPrerenderer()
: LabelTextShapingAndLayoutAndRenderTask(Type::prerender)
{
  referers_.store(Referers::layerOrPrerenderer, std::memory_order_relaxed);
  params_.defaultBaseWritingDirection = stu_defaultBaseWritingDirection();
  params_.setDisplayScale_assumingSizeAndEdgeInsetsAreAlreadyCorrectlyRounded(
            *DisplayScale::create(stu_mainScreenScale()));
  params_.neverUsesExtendedRGBBitmapFormat = stu_mainScreenDisplayGamut() == STUDisplayGamutSRGB;
  stringIsEmpty_ = true;
  textFrameOptions_ = defaultLabelTextFrameOptions().unretained;
}

STU_NO_INLINE STU_NO_RETURN
void LabelPrerenderer::attemptedMutationOfFrozenObject() {
  STU_CHECK_MSG(false, "ERROR: Attempted mutation of frozen STULabelPrerenderer object.");
}

void LabelPrerenderer::invalidateShapedString_slowPath() {
  shapedString_ = nil;
  hasShapedString_ = false;
  invalidateLayout();
}

void LabelPrerenderer::invalidateLayout_slowPath() {
  textFrame_ = nil;
  links_ = nil;
  textFrameInfo_.isValid = false;
  hasLayoutInfo_ = false;
  hasTextFrame_ = false;
  completedLayout_.store(false, std::memory_order_relaxed);
}

void LabelPrerenderer::layout() {
  checkNotFrozen();
  STU_DEBUG_ASSERT(!hasLayoutInfo_);
  if (!stringIsEmpty_) {
    if (!shapedString_) {
      createShapedString(nullptr);
      hasShapedString_ = true;
    }
    createTextFrame(); // Also calculates the layout info and links.
  } else { // stringIsEmpty_
    textFrameInfo_ = LabelTextFrameInfo::empty;
    textFrameOriginInLayer_ = CGPoint{};
    if (sizeOptions_) {
      params_.shrinkSizeToFitTextBounds(Rect<CGFloat>{}, sizeOptions_);
    }
  }
  completedLayout_.store(true, std::memory_order_relaxed);
  hasLayoutInfo_ = true;
  hasTextFrame_ = true;
}

void LabelPrerenderer::registerWaitingLabelLayer(LabelLayer& label) {
  if (!label_) {
    label_ = &label;
    incrementRefCount(((__bridge id)implicit_cast<void*>(objcObjectStorage)));
  } else {
    WaitingLabelSetNode::get(label).previousLabel = label_;
    WaitingLabelSetNode::get(*label_).nextLabel = &label;
    label_ = &label;
  }
}

void LabelPrerenderer::deregisterWaitingLabelLayer(LabelLayer& label) {
  WaitingLabelSetNode& node = WaitingLabelSetNode::get(label);
  LabelLayer* const previousLabel = node.previousLabel;
  if (previousLabel) {
    WaitingLabelSetNode::get(*previousLabel).nextLabel = node.nextLabel;
    node.previousLabel = nullptr;
  }
  if (node.nextLabel) {
    WaitingLabelSetNode::get(*node.nextLabel).previousLabel = previousLabel;
    node.nextLabel = nullptr;
  } else {
    STU_ASSERT(label_ == &label);
    label_ = previousLabel;
    if (!previousLabel) {
      decrementRefCount(((__bridge id)implicit_cast<void*>(objcObjectStorage)));
    }
  }
}

Optional<LabelLayer&> LabelPrerenderer::popLabelFromWaitingSet() {
   LabelLayer* label = label_;
   if (label) {
     auto& node = WaitingLabelSetNode::get(*label);
     STU_DEBUG_ASSERT(node.nextLabel == nil);
     label_ = node.previousLabel;
     if (label_) {
       WaitingLabelSetNode::get(*label_).nextLabel = nil;
     } else {
       decrementRefCount(((__bridge id)implicit_cast<void*>(objcObjectStorage)));
     }
   }
  return label;
}


void detail::labelPrerendererObjCObjectWasDestroyed(LabelPrerenderer& prerenderer) {
  prerenderer.objcObjectWasDestroyed();
}
void LabelPrerenderer::objcObjectWasDestroyed() {
  isCancelled_.setCancelled();
  if (releaseReferenceAndReturnTrueIfItWasTheLast(Referers::layerOrPrerenderer)) {
    destroyAndDeallocate();
  }
}

} // namespace stu_label

