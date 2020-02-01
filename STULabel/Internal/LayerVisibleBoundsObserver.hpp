// Copyright 2018 Stephan Tolksdorf

#import "Common.hpp"
#import "Once.hpp"
#import "Unretained.hpp"

#import "stu/Vector.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

/// Tracks the bounds of the layer not masked by its superlayers, ignoring any superlayer above
/// the first layer belonging to a `UIScrollView`.
///
/// Starts observing the bounds after the first call to `calculateVisibleBounds`.
///
/// `UIScrollView` layers are treated as "root" superlayers in order to make it possible to get
/// useful clipping bounds for layers in ScrollViews that are currently positioned offscreen and are
/// about to be moved onto screen.
///
/// Note that this class won't get notified when the root of the tracked superlayer list gets a
/// superlayer. Such a change won't be recognized until the next time `calculateVisibleBounds`
/// is called (and the current root is not a ScrollView layer).
class LayerVisibleBoundsObserver {
public:
  using Callback = void (^)();

  LayerVisibleBoundsObserver() = default;

  Unretained<CALayer* __nullable> layer() const { return layer_; }

  /// The layer will not be retained and you must clear the reference or destroy the observer when
  /// the layer is deallocated.
  void setLayer(CALayer* __unsafe_unretained __nullable layer) {
    removeSuperlayerObservers();
    layer_ = layer;
  }

  void setOnVisibleBoundsMayHaveChangedCallback(Callback __nullable callback) {
    callback_ = callback;
  }

  LayerVisibleBoundsObserver(const LayerVisibleBoundsObserver&) = delete;
  LayerVisibleBoundsObserver& operator=(const LayerVisibleBoundsObserver&) = delete;

  ~LayerVisibleBoundsObserver() {
    removeSuperlayerObservers();
  }

  CGRect calculateVisibleBounds();

  /// The factor by which the area is scaled when the layer's visible bounds are projected onto the
  /// root superlayer, given the current (super)layer transforms. This factor is updated when
  /// calculateVisibleBounds is called.
  CGFloat areaScale() const { return areaScale_; }

  UIScreen* screen();

  void _private_superlayerIsBeingRemovedOrDestroyed(CALayer* superlayer);
  void _private_superlayerMasksToBoundsChanged(CALayer* superlayer, bool masksToBounds);
  void _private_visibleBoundsMayHaveChanged();

private:
  void removeSuperlayerObservers();
  void addMissingSuperlayerObservers();

  struct OutIsUIScrollViewLayer : Parameter<OutIsUIScrollViewLayer, bool&> {
    using Parameter::Parameter;
  };

  class SuperlayerRef {
    UInt taggedPointer_;
  public:
    explicit SuperlayerRef(CALayer* __unsafe_unretained layer,
                           OutIsUIScrollViewLayer outIsUIScrollViewLayer)
    {
      STU_DEBUG_ASSERT(layer != nil);
      static Class uiViewClass;
      static Class uiScrollViewClass;
      static dispatch_once_t once;
      dispatch_once_f(&once, nullptr, [](void *) {
        uiViewClass = UIView.class;
        uiScrollViewClass = UIScrollView.class;
      });

      taggedPointer_ = reinterpret_cast<UInt>((__bridge void*)layer);
      STU_ASSERT(!(taggedPointer_ & 3));
      taggedPointer_ |= [layer masksToBounds] ? 1u : 0;
      if (const __unsafe_unretained id delegate = layer.delegate;
          [delegate isKindOfClass:uiViewClass] && static_cast<UIView*>(delegate).layer == layer)
      {
        taggedPointer_ |= 2;
        outIsUIScrollViewLayer.value = [delegate isKindOfClass:uiScrollViewClass];
      } else {
        outIsUIScrollViewLayer.value = false;
      }
    }

    Unretained<CALayer* __nonnull> layer() const {
      return (__bridge CALayer*)reinterpret_cast<void*>(taggedPointer_ & ~UInt{3});
    }

    bool masksToBounds() const { return taggedPointer_ & 1; }

    void setMasksToBounds(bool value) {
      taggedPointer_ = (taggedPointer_ & ~UInt{1}) | value;
    }

    bool isViewLayer() const { return taggedPointer_ & 2; }
  };

  CALayer* __unsafe_unretained layer_;
  Vector<SuperlayerRef> superlayers_;
  Callback callback_; // arc
  CGFloat areaScale_{};
  bool visibleBoundsMayHaveChanged_{};
  bool rootSuperlayerIsScrollViewLayer_;
};

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
