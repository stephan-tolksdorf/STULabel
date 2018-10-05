// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STULabelPrerenderer-Internal.hpp"

#import "STULabel/STUTextFrameOptions-Internal.hpp"

#import "InputClamping.hpp"
#import "LabelRenderTask.hpp"
#import "Once.hpp"

namespace stu_label {

class LabelPrerenderer final : public LabelTextShapingAndLayoutAndRenderTask,
                               public LabelPropertiesCRTPBase<LabelPrerenderer>
{
  friend LabelRenderTask;
  friend LabelPropertiesCRTPBase<LabelPrerenderer>;

  bool isFrozen_{};
  bool stringIsEmpty_;
  bool hasShapedString_{};
  bool hasLayoutInfo_{};
  bool hasTextFrame_{};
  bool textFrameOptionsIsPrivate_{};
  bool contentInsetsAreDirectional_{};
  CGSize size_{};
  UIEdgeInsets contentInsets_{};

  alignas(void*) Byte objcObjectStorage[];

  LabelPrerenderer();

  static STULabelPrerenderer* create(Class prerendererClass) NS_RETURNS_RETAINED;

  friend STULabelPrerenderer* ::STULabelPrerendererAlloc(Class);
  friend void detail::labelPrerendererObjCObjectWasDestroyed(LabelPrerenderer&);
  void objcObjectWasDestroyed();

  void destroyAndDeallocate();

public:
  struct WaitingLabelSetNode  {
  private:
    friend LabelPrerenderer;

    LabelLayer* nextLabel;
    LabelLayer* previousLabel;

    // Defined in STULabelLayer.mm
    static WaitingLabelSetNode& get(LabelLayer&);
  };

  void registerWaitingLabelLayer(LabelLayer& label);

private:

  void deregisterWaitingLabelLayer(LabelLayer& label);

  Optional<LabelLayer&> popLabelFromWaitingSet();

  void checkNotFrozen() {
    if (STU_UNLIKELY(isFrozen_)) {
      attemptedMutationOfFrozenObject();
    }
  }
  void attemptedMutationOfFrozenObject() STU_NO_RETURN;

  void freeze() {
    checkNotFrozen();
    isFrozen_ = true;
  }

  void invalidateShapedString() {
    if (hasShapedString_) {
      invalidateShapedString_slowPath();
    }
  }
  void invalidateShapedString_slowPath();

  void layout();

  void invalidateLayout() {
    if (hasLayoutInfo_) {
      invalidateLayout_slowPath();
    }
  }
  void invalidateLayout_slowPath();


public:
  // MARK: - Public interface that mirrors STULabelPrerenderer's interface

  bool isFrozen() const { return isFrozen_; }

  NSAttributedString* __nullable attributedString() const { return attributedString_; }

  void setAttributedString(NSAttributedString* __unsafe_unretained attributedString) {
    checkNotFrozen();
    if (attributedString_ == attributedString) return;
    attributedString_ = [attributedString copy];
    stringIsEmpty_ = !attributedString_ || attributedString_.length == 0;
    invalidateShapedString();
  }

  bool stringIsEmpty() const { return STU_UNLIKELY(stringIsEmpty_); }

  bool hasShapedString() const { return hasShapedString_; }

  Unretained<STUShapedString* __nonnull> shapedString() {
    if (!hasShapedString_) {
      checkNotFrozen();
      createShapedString(nullptr);
      hasShapedString_ = true;
    } else if (stringIsEmpty_) {
      return emptyShapedString(params_.defaultBaseWritingDirection);
    }
    return shapedString_;
  }

  void setShapedString(STUShapedString* __unsafe_unretained __nullable stuShapedString) {
    checkNotFrozen();
    if (stuShapedString == shapedString_) return;
    shapedString_ = stuShapedString;
    invalidateLayout();
    if (stuShapedString) {
      const ShapedString& s = *stuShapedString->shapedString;
      attributedString_ = s.attributedString;
      stringIsEmpty_ = s.stringLength == 0;
    } else {
      attributedString_ = nil;
      stringIsEmpty_ = true;
    }
    hasShapedString_ = true;
  }

  const CGSize& size() const { return size_; }

  STULabelPrerendererSizeOptions sizeOptions() const { return sizeOptions_; }

private:
  void setSizeAndContentInsets(CGSize size, UIEdgeInsets contentInsets, bool insetsAreDirectional,
                               STULabelPrerendererSizeOptions options)
  {
    checkNotFrozen();
    contentInsetsAreDirectional_ = insetsAreDirectional;
    sizeOptions_ = options & (STUShrinkLabelWidthToFit | STUShrinkLabelHeightToFit);
    size_ = clampSizeInput(size);
    contentInsets_ = clampNonNegativeEdgeInsetsInput(contentInsets);
    params_.setSizeAndEdgeInsets(size_, contentInsets_);
    if (textFrame_) {
      if (textFrameInfo_.isValidForSize(params_.maxTextFrameSize(), params_.displayScale())) {
        textFrameOriginInLayer_ = textFrameOriginInLayer(textFrameInfo_, params_);
      } else {
        invalidateLayout();
      }
    }
  }

public:
  void setSizeAndContentInsets(CGSize size, UIEdgeInsets contentInsets,
                               STULabelPrerendererSizeOptions options)
  {
    setSizeAndContentInsets(size, contentInsets, false, options);
  }

  void setSizeAndContentInsets(CGSize size, STUDirectionalEdgeInsets contentInsets,
                               STULabelPrerendererSizeOptions options)
  {
    setSizeAndContentInsets(size, edgeInsets(contentInsets, params_.defaultBaseWritingDirection),
                            true, options);
  }

  void setDisplayScale(CGFloat scale) {
    checkNotFrozen();
    scale = clampDisplayScaleInput(scale);
    if (!params_.setDisplayScaleAndIfChangedUpdateSizeAndEdgeInsets(
                   DisplayScale::createOrIfInvalidGetMainSceenScale(scale), size_, contentInsets_))
    {
      return;
    }
    invalidateLayout();
  }

  void setVerticalAlignment(STULabelVerticalAlignment verticalAlignment) {
    checkNotFrozen();
    verticalAlignment = clampVerticalAlignmentInput(verticalAlignment);
    if (params_.verticalAlignment == verticalAlignment) return;
    params_.verticalAlignment = verticalAlignment;
    invalidateLayout();
  }


  // MARK: - STUTextFrameOptions properties

  Unretained<STUTextFrameOptions* __nonnull> textFrameOptions() {
    textFrameOptionsIsPrivate_ = false;
    STU_DEBUG_ASSERT(textFrameOptions_ != nil);
    return textFrameOptions_;
  }

  // MARK: - Properties that do not affect layout

  void setBackgroundColor(CGColor* __nullable backgroundColor) {
    checkNotFrozen();
    params_.setBackgroundColor(backgroundColor);
  }

  void setIsHighlighted(bool highlighted) {
    checkNotFrozen();
    params_.setIsHighlighted(highlighted);
  }

  void setHighlightStyle(STUTextHighlightStyle* __unsafe_unretained highlightStyle) {
    checkNotFrozen();
    params_.setHighlightStyle(highlightStyle);
  }

  void setHighlightRange(NSRange range, STUTextRangeType rangeType) {
    checkNotFrozen();
    params_.setHighlightRange(range, rangeType);
  }

  void setOverrideColorsApplyToHighlightedText(bool value) {
    checkNotFrozen();
    params_.setOverrideColorsApplyToHighlightedText(value);
  }

  void setOverrideTextColor(UIColor* __unsafe_unretained color) {
    checkNotFrozen();
    params_.setOverrideTextColor(color);
  }

  void setOverrideLinkColor(UIColor* __unsafe_unretained color) {
    checkNotFrozen();
    params_.setOverrideLinkColor(color);
  }

  void setDrawingBlock(STULabelDrawingBlock __unsafe_unretained drawingBlock) {
    checkNotFrozen();
    params_.drawingBlock = drawingBlock;
  }

  void setDrawingBlockColorOptions(STULabelDrawingBlockColorOptions colorOptions) {
    checkNotFrozen();
    params_.drawingBlockColorOptions = clampLabelDrawingBlockColorOptions(colorOptions);
  }

  void setDrawingBlockImageBounds(STULabelDrawingBounds drawingBounds) {
    checkNotFrozen();
    params_.drawingBlockImageBounds = clampLabelDrawingBounds(drawingBounds);
  }

  void setClipsContentToBounds(bool clipsContentToBounds) {
    checkNotFrozen();
    params_.clipsContentToBounds = clipsContentToBounds;
  }

  void setNeverUsesGrayscaleBitmapFormat(bool neverUsesGrayscaleBitmapFormat) {
    checkNotFrozen();
    params_.neverUseGrayscaleBitmapFormat = neverUsesGrayscaleBitmapFormat;
  }

  void setNeverUsesExtendedRGBBitmapFormat(bool neverUsesExtendedRGBBitmapFormat) {
    checkNotFrozen();
    params_.neverUsesExtendedRGBBitmapFormat = neverUsesExtendedRGBBitmapFormat;
    params_.neverUsesExtendedRGBBitmapFormatWasExplicitlySet = true;
  }

  void setReleasesShapedStringAfterRendering(bool releasesShapedStringAfterRendering) {
    checkNotFrozen();
    params_.releasesShapedStringAfterRendering = releasesShapedStringAfterRendering;
    params_.releasesTextFrameAfterRenderingWasExplicitlySet = true;
  }

  void setReleasesTextFrameAfterRendering(bool releasesTextFrameAfterRendering) {
    checkNotFrozen();
    params_.releasesTextFrameAfterRendering = releasesTextFrameAfterRendering;
    params_.releasesTextFrameAfterRenderingWasExplicitlySet = true;
  }

  // MARK: - Getting layout information

  bool hasLayoutInfo() const { return hasLayoutInfo_; }

  CGSize sizeThatFits() {
    if (!hasLayoutInfo_) {
      layout();
    }
    return textFrameInfo_.sizeThatFits(contentInsets_, params_.displayScale());
  }

  STULabelLayoutInfo layoutInfo() {
    if (!hasLayoutInfo_) {
      layout();
    }
    return stuLabelLayoutInfo(textFrameInfo_, textFrameOriginInLayer_,
                              params_.displayScale());
  }

  bool tryGetSizeThatFitsAndLayoutInfo(CGSize* outSizeThatFits, STULabelLayoutInfo* outInfo) const {
    if (completedLayout()) {
      if (outSizeThatFits) {
        *outSizeThatFits = textFrameInfo_.sizeThatFits(contentInsets_, params_.displayScale());
      }
      if (outInfo) {
        *outInfo = stuLabelLayoutInfo(textFrameInfo_, textFrameOriginInLayer_,
                                      params_.displayScale());
      }
      return true;
    }
    return false;
  }

  Unretained<STUTextLinkArray* __nonnull> links() {
    if (!hasLayoutInfo_) {
      layout();
    }
    return links_ ?: emptySTUTextLinkArray();
  }

  bool hasTextFrame() const { return hasTextFrame_; }

  Unretained<STUTextFrame* __nonnull> textFrame() {
    if (!hasTextFrame_) {
      layout();
    }
    return stringIsEmpty_ ? emptySTUTextFrame().unretained : textFrame_;
  }

  // MARK: - Starting the rendering

  void render() {
    if (!hasLayoutInfo_) {
      layout();
    } else {
      checkNotFrozen();
    }
    if (!stringIsEmpty_) {
      renderImage(nullptr);
      hasShapedString_ = !params_.releasesShapedStringAfterRendering;
      hasTextFrame_ = !params_.releasesTextFrameAfterRendering;
    }
    isFinished_ = true;
    freeze();
  }

  void renderAsyncOnQueue(__nullable dispatch_queue_t queue) {
    if (!queue) {
      queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    }
    renderUsingScheduler([queue](void* context, dispatch_function_t function) {
      dispatch_async_f(queue, context, function);
    });
  }

  template <typename Scheduler, EnableIf<isCallable<Scheduler, void(void*, void(*)(void*))>> = 0>
  void renderUsingScheduler(Scheduler&& scheduler) {
    if (stringIsEmpty_ && !hasLayoutInfo_) {
      layout();
    }
    freeze();
    if (stringIsEmpty_) return;
    dispatch_function_t function;
    if (!hasShapedString_) {
      function = LabelTextShapingAndLayoutAndRenderTask::run;
    } else {
      if (!hasTextFrame_) {
        function = LabelLayoutAndRenderTask::run;
      } else {
        function = LabelRenderTask::run;
        hasTextFrame_ = !params_.releasesTextFrameAfterRendering;
      }
      hasShapedString_ = !params_.releasesShapedStringAfterRendering;
    }
    referers_.store(Referers::layerOrPrerenderer | Referers::task, std::memory_order_relaxed);
    std::forward<Scheduler>(scheduler)(this, function);
  }
};

} // stu_label

