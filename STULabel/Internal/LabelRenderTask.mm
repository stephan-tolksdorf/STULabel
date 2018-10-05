// Copyright 2017–2018 Stephan Tolksdorf

#include "LabelRenderTask.hpp"
#include "LabelPrerenderer.hpp"

namespace stu_label {

void LabelRenderTask::destroyAndDeallocateNonPrerenderTask() {
  switch (type_) {
  case Type::textShapingAndLayoutAndRender:
    down_cast<LabelTextShapingAndLayoutAndRenderTask*>(this)->~LabelTextShapingAndLayoutAndRenderTask();
    break;
  case Type::layoutAndRender:
    down_cast<LabelLayoutAndRenderTask*>(this)->~LabelLayoutAndRenderTask();
    break;
  case Type::render:
    this->~LabelRenderTask();
    break;
  default:
    __builtin_trap();
  }
  free(this);
}

void LabelRenderTask::abandonedByLabel(LabelLayer& label) {
  if (type_ != Type::prerender) {
    STU_DEBUG_ASSERT(label_ == &label);
    label_ = nullptr;
    isCancelled_.setCancelled();
    if (releaseReferenceAndReturnTrueIfItWasTheLast(Referers::layerOrPrerenderer)) {
      destroyAndDeallocateNonPrerenderTask();
    }
  } else {
    down_cast<LabelPrerenderer&>(*this).deregisterWaitingLabelLayer(label);
  }
}

void LabelTextShapingAndLayoutAndRenderTask
     ::createShapedString(const STUCancellationFlag* __nullable cancellationFlag)
{
  shapedString_ = STUShapedStringCreate(nil, attributedString_, params_.defaultBaseWritingDirection,
                                        cancellationFlag);
}

void LabelLayoutAndRenderTask::createTextFrame() {
  STU_DEBUG_ASSERT(shapedString_ && !textFrame_ && !links_);
  textFrame_ = STUTextFrameCreateWithShapedString(nil, shapedString_, params_.maxTextFrameSize(),
                                                  params_.displayScale(), textFrameOptions_);
  const TextFrame& textFrame = textFrameRef(textFrame_);
  textFrameInfo_ = labelTextFrameInfo(textFrame, params_.verticalAlignment, params_.displayScale());
  if (sizeOptions_) {
    params_.shrinkSizeToFitTextBounds(textFrameInfo_.layoutBounds, sizeOptions_);
  }
  textFrameOriginInLayer_ = textFrameOriginInLayer(textFrameInfo_, params_);
  if ((textFrameInfo_.flags & STUTextFrameHasLink)
      && (type_ == Type::prerender || params_.releasesTextFrameAfterRendering))
  {
    links_ = STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
               textFrame, textFrameOriginInLayer_,
               TextFrameScaleAndDisplayScale{textFrame, params_.displayScale()});
  }
}

void LabelRenderTask::renderImage(const STUCancellationFlag* __nullable cancellationFlag) {
  STU_DEBUG_ASSERT(textFrame_);
  if (params_.releasesShapedStringAfterRendering && type_ != Type::render) {
    auto& self = down_cast<LabelLayoutAndRenderTask&>(*this);
    self.shapedString_ = nil;
  }
  renderInfo_ = labelTextFrameRenderInfo(textFrame_, textFrameInfo_,
                                         textFrameOriginInLayer_, params_,
                                         allowExtendedRGBBitmapFormat_, true,
                                         cancellationFlag);
  if (renderInfo_.mode != LabelRenderMode::tiledSublayer) {
    image_ = createLabelTextFrameImage(textFrame_, renderInfo_, params_, cancellationFlag);
    if (params_.releasesTextFrameAfterRendering) {
      textFrame_ = nil;
    }
  }
}

void LabelTextShapingAndLayoutAndRenderTask::run(void* taskPointer) {
  auto& task = *down_cast<LabelTextShapingAndLayoutAndRenderTask*>(taskPointer);
  if (!task.isCancelled_) {
    task.createShapedString(&task.isCancelled_);
    LabelLayoutAndRenderTask::run(&task);
    return;
  }
  task.taskStoppedAfterBeingCancelled();
}
void LabelLayoutAndRenderTask::run(void* taskPointer) {
  auto& task = *down_cast<LabelLayoutAndRenderTask*>(taskPointer);
  if (!task.isCancelled_) {
    task.createTextFrame();
    task.completedLayout_.store(true, std::memory_order_release);
    LabelRenderTask::run(&task);
    return;
  }
  task.taskStoppedAfterBeingCancelled();
}
void LabelRenderTask::run(void* taskPointer) {
  auto& task = *down_cast<LabelRenderTask*>(taskPointer);
  if (!task.renderingIsCancelled_) {
    task.renderImage(&task.renderingIsCancelled_);
    if (!task.renderingIsCancelled_) {
      dispatch_async_f(dispatch_get_main_queue(), &task, finish_onMainThread);
      return;
    }
  }
  task.taskStoppedAfterBeingCancelled();
}

void LabelRenderTask::taskStoppedAfterBeingCancelled() {
  if (releaseReferenceAndReturnTrueIfItWasTheLast(Referers::task)) {
    if (type_ != Type::prerender) {
      destroyAndDeallocateNonPrerenderTask();
    } else {
      down_cast<LabelPrerenderer&>(*this).destroyAndDeallocate();
    }
  }
}

} // stu_label
