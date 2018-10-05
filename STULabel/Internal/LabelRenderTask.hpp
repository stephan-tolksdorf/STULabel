// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUTextLink-Internal.hpp"

#import "AtomicEnum.hpp"
#import "CancellationFlag.hpp"
#import "LabelParameters.hpp"
#import "LabelRendering.hpp"
#import "ShapedString.hpp"


namespace stu_label {

enum class LabelRenderTaskReferers : UInt8 {
  task = 1,
  layerOrPrerenderer = 2
};

} // namespace stu_label

template <> struct stu::IsOptionsEnum<stu_label::LabelRenderTaskReferers> : stu::True {};

namespace stu_label {

class LabelRenderTask {
public:
  enum class Type : UInt8 {
    render,
    layoutAndRender,
    textShapingAndLayoutAndRender,
    prerender
  };

protected:
  using Referers = LabelRenderTaskReferers;

  const Type type_;
  AtomicEnum<Referers> referers_{Referers{}};
  std::atomic<bool> completedLayout_{};
  CancellationFlag isCancelled_;
  CancellationFlag renderingIsCancelled_;
  bool isFinished_{};
  STULabelPrerendererSizeOptions sizeOptions_{};
  bool allowExtendedRGBBitmapFormat_{true};

  LabelLayer* label_{};

  LabelParameters params_{};
  LabelTextFrameRenderInfo renderInfo_;
  PurgeableImage image_;

  STUTextFrame* textFrame_{};
  LabelTextFrameInfo textFrameInfo_;
  CGPoint textFrameOriginInLayer_;

  explicit LabelRenderTask(Type type)
  : type_{type}
  {}

  bool releaseReferenceAndReturnTrueIfItWasTheLast(Referers referer) {
    const auto oldValue = referers_.fetch_and(~referer, std::memory_order_release);
    if (oldValue == referer) {
      discard(referers_.load(std::memory_order_acquire));
      return true;
    } else {
      STU_DEBUG_ASSERT(oldValue & referer);
      return false;
    }
  }

  void commonNonPrerenderInit(LabelLayer& label, const LabelParameters& params,
                              bool allowExtendedRGBBitmapFormat)
  {
    label_ = &label;
    params_ = params;
    params_.releasesShapedStringAfterRendering = false;
    params_.releasesTextFrameAfterRendering = false;
    referers_.store(Referers::layerOrPrerenderer | Referers::task, std::memory_order_relaxed);
    allowExtendedRGBBitmapFormat_ = allowExtendedRGBBitmapFormat;
  }

  void renderImage(const STUCancellationFlag* __nullable);

  static void run(void* task);

  void taskStoppedAfterBeingCancelled();

private:
  // Defined in STULabelLayer.mm
  void copyLayoutInfoTo(stu_label::LabelLayer&) const;

  // Defined in STULabelLayer.mm
  static void finish_onMainThread(void* task);

  void destroyAndDeallocateNonPrerenderTask();

public:
  Type type() const { return type_; }

  bool completedLayout() const {
    if (completedLayout_.load(std::memory_order_relaxed)) {
      discard(completedLayout_.load(std::memory_order_acquire));
      return true;
    }
    return false;
  }

  // \pre isMainThread()
  bool tryCopyLayoutInfoTo(LabelLayer& label) const {
    if (completedLayout()) {
      copyLayoutInfoTo(label);
      return true;
    }
    return false;
  }

  /// Not thread-safe.
  bool isFinished() const { return isFinished_; }

  /// \pre isMainThread()
  /// \pre isFinished()
  // Defined in STULabelLayer.mm
  void assignResultTo(LabelLayer& label);

  static auto dispatchAsync(__nonnull dispatch_queue_t queue,
                            LabelLayer& label,
                            const LabelParameters& params,
                            bool allowExtendedRGBBitmapFormat,
                            STUTextFrame* __unsafe_unretained __nonnull textFrame,
                            LabelTextFrameInfo textFrameLayoutInfo,
                            CGPoint textFrameOriginInLayer)
          -> LabelRenderTask*
  {
    auto* task = new (Malloc().allocate<LabelRenderTask>(1))
                     LabelRenderTask{Type::render};
    task->commonNonPrerenderInit(label, params, allowExtendedRGBBitmapFormat);
    task->textFrame_ = textFrame;
    task->textFrameInfo_ = textFrameLayoutInfo;
    task->textFrameOriginInLayer_ = textFrameOriginInLayer;
    task->completedLayout_.store(true, std::memory_order_relaxed);
    dispatch_async_f(queue, task, run);
    return task;
  }

  // Defined in STULabelLayer.mm
  void abandonedByLabel(LabelLayer& layer);

  void cancelRendering() {
    renderingIsCancelled_.setCancelled();
  }
};

class LabelLayoutAndRenderTask : public LabelRenderTask {
protected:
  friend LabelRenderTask;

  STUShapedString* shapedString_{};
  STUTextFrameOptions* textFrameOptions_{};
  STUTextLinkArrayWithTextFrameOrigin* links_{};

  STU_INLINE
  explicit LabelLayoutAndRenderTask(Type type)
  : LabelRenderTask{type}
  {
    STU_DEBUG_ASSERT(type != Type::render);
  }

  static void run(void* task);

  /// \pre shapedString && !textFrame && !links
  void createTextFrame();

public:
  static auto dispatchAsync(__nonnull dispatch_queue_t queue,
                            LabelLayer& label,
                            const LabelParameters& params,
                            bool allowExtendedRGBBitmapFormat,
                            STUTextFrameOptions* __unsafe_unretained __nonnull textFrameOptions,
                            STUShapedString* __unsafe_unretained __nonnull shapedString)
          -> LabelLayoutAndRenderTask*
  {
    auto* task = new (Malloc().allocate<LabelLayoutAndRenderTask>(1))
                     LabelLayoutAndRenderTask{Type::layoutAndRender};
    task->commonNonPrerenderInit(label, params, allowExtendedRGBBitmapFormat);
    task->shapedString_ = shapedString;
    task->textFrameOptions_ = textFrameOptions;
    dispatch_async_f(queue, task, run);
    return task;
  }
};

class LabelTextShapingAndLayoutAndRenderTask : public LabelLayoutAndRenderTask {
  friend LabelRenderTask;
protected:
  NSAttributedString* attributedString_{};

  explicit LabelTextShapingAndLayoutAndRenderTask(Type type)
  : LabelLayoutAndRenderTask{type}
  {
    STU_DEBUG_ASSERT(type == Type::textShapingAndLayoutAndRender || type == Type::prerender);
  }

  /// \pre !shapedString && attributedString
  void createShapedString(const STUCancellationFlag* __nullable cancellationFlag);

  static void run(void* task);

public:
  static auto dispatchAsync(__nonnull dispatch_queue_t queue,
                            LabelLayer& label,
                            const LabelParameters& params,
                            bool allowExtendedRGBBitmapFormat,
                            STUTextFrameOptions* __unsafe_unretained __nonnull textFrameOptions,
                            NSAttributedString* __unsafe_unretained __nonnull attributedString)
          -> LabelTextShapingAndLayoutAndRenderTask*
  {
    auto* task = new (Malloc().allocate<LabelTextShapingAndLayoutAndRenderTask>(1))
                     LabelTextShapingAndLayoutAndRenderTask{Type::textShapingAndLayoutAndRender};
    task->commonNonPrerenderInit(label, params, allowExtendedRGBBitmapFormat);
    task->textFrameOptions_ = textFrameOptions;
    task->attributedString_ = attributedString;
    dispatch_async_f(queue, task, run);
    return task;
  }
};

} // namespace stu_label
