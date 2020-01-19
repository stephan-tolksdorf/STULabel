// Copyright 2018 Stephan Tolksdorf

#import "LayerVisibleBoundsObserver.hpp"

#import "STULabel/STUObjCRuntimeWrappers.h"

#import <objc/runtime.h>

using namespace stu_label;

@interface STULabelSuperlayerObserver : NSObject {
  CALayer* __unsafe_unretained _layer;
  CALayer* __unsafe_unretained _sublayer;
  stu_label::LayerVisibleBoundsObserver* _visibleBoundsObserver;
  bool _sublayerIsMask;
}
@end

#define FOR_ALL_OBSERVED_NON_SUBLAYER_PROPERTIES(f) \
  f(@"masksToBounds", NSKeyValueObservingOptionNew) \
  f(@"bounds", 0) \
  f(@"bounds", 0) \
  f(@"zPosition", 0) \
  f(@"anchorPoint", 0) \
  f(@"anchorPointZ", 0) \
  f(@"transform", 0)

@implementation STULabelSuperlayerObserver

- (void)observeValueForKeyPath:(NSString* __unsafe_unretained)keyPath
                      ofObject:(__unsafe_unretained id __unused)object
                        change:(NSDictionary<NSKeyValueChangeKey,id>* __unsafe_unretained)change
                       context:(void* __unused)context
{
  if (!_visibleBoundsObserver) return;
  if (!_sublayerIsMask) {
    if ([keyPath isEqualToString:@"sublayers"]) {
      const id sublayers = [change objectForKey:NSKeyValueChangeNewKey];
      if (sublayers == (__bridge id)kCFNull || ![sublayers containsObject:_sublayer]) {
        _visibleBoundsObserver->_private_superlayerIsBeingRemovedOrDestroyed(_layer);
        removeSuperlayerObserver(_layer, *_visibleBoundsObserver); // Deallocates self.
      }
      return;
    }
  } else {
    if ([keyPath isEqualToString:@"mask"]) {
      const id mask = [change objectForKey:NSKeyValueChangeNewKey];
      if (mask != _sublayer) {
        _visibleBoundsObserver->_private_superlayerIsBeingRemovedOrDestroyed(_layer);
        removeSuperlayerObserver(_layer, *_visibleBoundsObserver); // Deallocates self.
      }
      return;
    }
  }
  if ([keyPath isEqualToString:@"masksToBounds"]) {
    const bool masksToBounds = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
    _visibleBoundsObserver->_private_superlayerMasksToBoundsChanged(_layer, masksToBounds);
    return;
  }
  _visibleBoundsObserver->_private_visibleBoundsMayHaveChanged();
}

- (void)dealloc {
  if (const auto observer = _visibleBoundsObserver) { // The layer is being destroyed.
    _visibleBoundsObserver = nullptr;
    observer->_private_superlayerIsBeingRemovedOrDestroyed(_layer);
  }
}

static void addSuperlayerObserver(CALayer* __unsafe_unretained layer,
                                  CALayer* __unsafe_unretained sublayer,
                                  LayerVisibleBoundsObserver& visibleBoundsObserver)
{
  STU_STATIC_CONST_ONCE(Class, observerClass, STULabelSuperlayerObserver.class);
  STU_ANALYZER_ASSUME(observerClass != nil);
  STULabelSuperlayerObserver* const observer = stu_createClassInstance(observerClass, 0);
  observer->_layer = layer;
  observer->_sublayer = sublayer;
  observer->_visibleBoundsObserver = &visibleBoundsObserver;
  observer->_sublayerIsMask = sublayer == layer.mask;

  #define addPropertyObserver(name, opts) \
    [layer addObserver:observer forKeyPath:name options:opts context:nil];
  if (!observer->_sublayerIsMask) {
    addPropertyObserver(@"sublayers", NSKeyValueObservingOptionNew)
  } else {
    addPropertyObserver(@"mask", NSKeyValueObservingOptionNew)
  }
  FOR_ALL_OBSERVED_NON_SUBLAYER_PROPERTIES(addPropertyObserver)
  #undef addPropertyObserver

  objc_setAssociatedObject(layer, &visibleBoundsObserver, observer,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void removeSuperlayerObserver(CALayer* __unsafe_unretained superlayer,
                                     LayerVisibleBoundsObserver& visibleBoundsObserver)
{
  auto const observer = static_cast<STULabelSuperlayerObserver*>(
                          objc_getAssociatedObject(superlayer, &visibleBoundsObserver));
  STU_DEBUG_ASSERT(observer != nil);
  if (!observer) return;
  STU_DEBUG_ASSERT(observer->_layer == superlayer);

  #define removePropertyObserver(name, options) [superlayer removeObserver:observer forKeyPath:name];
  if (!observer->_sublayerIsMask) {
    removePropertyObserver(@"sublayers", )
  } else {
    removePropertyObserver(@"mask", )
  }
  FOR_ALL_OBSERVED_NON_SUBLAYER_PROPERTIES(removePropertyObserver)
  #undef removeObserver
    
  observer->_visibleBoundsObserver = nullptr;
  objc_setAssociatedObject(superlayer, &visibleBoundsObserver, nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

namespace stu_label {

void LayerVisibleBoundsObserver::addMissingSuperlayerObservers() {
  CALayer* __unsafe_unretained sublayer = superlayers_.isEmpty() ? layer_
                                        : superlayers_[$ - 1].layer().unretained;
  CALayer* __unsafe_unretained layer = sublayer.superlayer;
  if (!layer) return;
  do {
    addSuperlayerObserver(layer, sublayer, *this);
    bool isUIScrollViewLayer;
    superlayers_.append(SuperlayerRef{layer, OutIsUIScrollViewLayer{isUIScrollViewLayer}});
    if (isUIScrollViewLayer) {
      // Checking that the ScrollView actually masksToBounds and updating superlayers_ in case that
      // changes doesn't seem worth the effort.
      rootSuperlayerIsScrollViewLayer_ = true;
      return;
    }
    sublayer = layer;
  } while ((layer = sublayer.superlayer));
}

UIScreen* LayerVisibleBoundsObserver::screen() {
  if (!rootSuperlayerIsScrollViewLayer_) {
    addMissingSuperlayerObservers();
  }
  for (SuperlayerRef& sl : superlayers_.reversed()) {
    if (!sl.isViewLayer()) continue;
    return static_cast<UIView*>(sl.layer().unretained.delegate).window.screen;
  }
  return nil;
}

void LayerVisibleBoundsObserver::removeSuperlayerObservers() {
  for (SuperlayerRef& sl : superlayers_.reversed()) {
    removeSuperlayerObserver(sl.layer().unretained, *this);
  }
  superlayers_.removeAll();
}

void LayerVisibleBoundsObserver
     ::_private_superlayerIsBeingRemovedOrDestroyed(CALayer* __unsafe_unretained superlayer)
{
  const auto optIndex = superlayers_.indexWhere([&](SuperlayerRef sr) {
                                                  return sr.layer() == superlayer;
                                                });
  STU_ASSERT(optIndex != none);
  const Int index = *optIndex;
  // We don't need to remove the observer for superlayers_[index].
  for (const SuperlayerRef& sl : superlayers_[{index + 1, $}].reversed()) {
    removeSuperlayerObserver(sl.layer().unretained, *this);
  }
  superlayers_.removeLast(superlayers_.count() - index);
  rootSuperlayerIsScrollViewLayer_ = false;
  _private_visibleBoundsMayHaveChanged();
}

void LayerVisibleBoundsObserver
     ::_private_superlayerMasksToBoundsChanged(CALayer* __unsafe_unretained superlayer,
                                               bool masksToBounds)
{
  for (SuperlayerRef& sl : superlayers_) {
    if (sl.layer() == superlayer) {
      sl.setMasksToBounds(masksToBounds);
      break;
    }
  }
  _private_visibleBoundsMayHaveChanged();
}

void LayerVisibleBoundsObserver::_private_visibleBoundsMayHaveChanged() {
  if (visibleBoundsMayHaveChanged_) return;
  visibleBoundsMayHaveChanged_ = true;
  if (callback_) {
    callback_();
  }
}

STU_INLINE
CGRect standardize(CGRect rect) {
  if (STU_UNLIKELY(!(rect.size.width >= 0) || !(rect.size.height >= 0))) {
    rect = CGRectStandardize(rect);
  }
  return rect;
}

static CGRect convertRectAndAccumulateAreaScale(CGRect bounds,
                                                CALayer* __unsafe_unretained superlayer,
                                                CALayer* __unsafe_unretained layer,
                                                CGFloat* areaScale)
{
  const CGFloat oldArea = bounds.size.width*bounds.size.height;
  bounds = standardize([superlayer convertRect:bounds toLayer:layer]);
  const CGFloat newArea = bounds.size.width*bounds.size.height;
  if (oldArea != newArea) {
    *areaScale *= newArea != 0 ? oldArea/newArea : infinity<CGFloat>;
  }
  return bounds;
}

CGRect LayerVisibleBoundsObserver::calculateVisibleBounds() {
  visibleBoundsMayHaveChanged_ = false;
  if (!rootSuperlayerIsScrollViewLayer_) {
    addMissingSuperlayerObservers();
  }
  areaScale_ = 1;
  if (superlayers_.isEmpty()) {
    return standardize(layer_.bounds);
  }
  CALayer* __unsafe_unretained superlayer = superlayers_[$ - 1].layer().unretained;
  CGRect bounds = standardize(superlayer.bounds);
  for (const SuperlayerRef& sl : superlayers_[{0, $ - 1}].reversed()) {
    if (!sl.masksToBounds()) continue;
    CALayer* __unsafe_unretained layer = sl.layer().unretained;
    convertRectAndAccumulateAreaScale(bounds, superlayer, layer_, &areaScale_);
    bounds = CGRectIntersection(bounds, layer.bounds);
    superlayer = layer;
  }
  bounds = convertRectAndAccumulateAreaScale(bounds, superlayer, layer_, &areaScale_);
  return bounds;
}

} // stu_label
