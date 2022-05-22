

#import "STULabelTiledLayer.h"

#import "CancellationFlag.hpp"
#import "CoreAnimationUtils.hpp"
#import "InputClamping.hpp"
#import "LayerVisibleBoundsObserver.hpp"
#import "Once.hpp"
#import "PurgeableImage.hpp"
#import "Rect.hpp"

#import "stu/Vector.hpp"
#import "stu/UniquePtr.hpp"

#include <atomic>

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

@interface STUTileLayer : STULayerWithNullDefaultActions
@end
@implementation STUTileLayer
@end

namespace stu_label {

/// An owning STUTileLayer pointer.
class SpareTileLayer {
  UInt taggedPointer_;
public:
  explicit SpareTileLayer(STUTileLayer* layer, bool hasSuperlayer) {
    taggedPointer_ = reinterpret_cast<UInt>((__bridge_retained void*)layer);
    STU_DEBUG_ASSERT(!(taggedPointer_ & 1) && (taggedPointer_ || !hasSuperlayer));
    taggedPointer_ |= hasSuperlayer;
  }

  Unretained<STUTileLayer* __nullable> layer() const {
    return (__bridge STUTileLayer*)reinterpret_cast<void*>(taggedPointer_ & ~UInt{1});
  }

  bool hasSuperlayer() const { return taggedPointer_ & 1; }

  void removeFromSuperlayer() {
    [layer().unretained removeFromSuperlayer];
    taggedPointer_ = taggedPointer_ & ~UInt{1};
  }

private:
  void destroy() {
    if (void* const layer = (__bridge void*)this->layer().unretained) {
      discard((__bridge_transfer CALayer*)layer);
    }
  }

public:
  SpareTileLayer(SpareTileLayer&& other) noexcept
  : taggedPointer_{std::exchange(other.taggedPointer_, 0)}
  {}

  SpareTileLayer& operator=(SpareTileLayer&& other) noexcept {
    if (this != &other) {
      destroy();
      taggedPointer_ = std::exchange(other.taggedPointer_, 0);
    }
    return *this;
  }

  ~SpareTileLayer() {
    destroy();
  }
};

} // namespace stu_label

template <> struct stu::IsBitwiseMovable<stu_label::SpareTileLayer> : True {};

namespace stu_label {

#ifndef STU_TRACE_TILED_LAYER
  #define STU_TRACE_TILED_LAYER 0
#endif

#if STU_TRACE_TILED_LAYER
  #define STU_TRACE(string, ...) printf(string "\n", ##__VA_ARGS__)
  #define STU_TRACE_IF(condition, string, ...) (condition ? STU_TRACE(string, ##__VA_ARGS__) : 0)
#else
  #define STU_TRACE(string, ...)
  #define STU_TRACE_IF(condition, string, ...)
#endif

/// Must be zero-initialized.
class TiledLayer {
  using SInt = Int32;
public:
  using DrawingBlock = void (^)(CGContext* __nonnull, CGRect, const STUCancellationFlag*);

  void init(STULabelTiledLayer* __unsafe_unretained thisSelf) {
    self = thisSelf;
    registerTiledLayer(*this);
    visibleBoundsObserver_.setLayer(self);
    visibleBoundsObserver_.setOnVisibleBoundsMayHaveChangedCallback(^() {
                             this->setNeedsLayout();
                           });
  }

  // The following public methods can be safely called before init

  DrawingBlock drawingBlock() const { return drawingBlock_; }

  void setDrawingBlock(DrawingBlock drawingBlock) {
    if (drawingBlock_ == drawingBlock) return;
    checkNotDisplaying();
    drawingBlock_ = drawingBlock;
    removeAllTiles();
    setNeedsLayout();
  }

  STUPredefinedCGImageFormat imageFormat() const { return imageFormat_; }

  void setImageFormat(STUPredefinedCGImageFormat imageFormat) {
    if (imageFormat_ == imageFormat) return;
    checkNotDisplaying();
    imageFormat_ = imageFormat;
    removeAllTiles();
    setNeedsLayout();
  }

  void setContentsScale(CGFloat contentsScale) {
    if (contentsScale_ == contentsScale) return;
    checkNotDisplaying();
    contentsScale_ = contentsScale;
    contentsScaleChanged_ = true;
    setNeedsLayout();
  }

  void setSize(CGSize size) {
    size = CGSize{max(0.f, size.width), max(0.f, size.height)};
    if (layerSize_ == size) return;
    layerSize_ = size;
    sizeChanged_ = true;
    setNeedsLayout();
  }

private:
  void setNeedsLayout() {
    if (needsLayout_) return;
    setNeedsDisplay_slowPath();
  }
  STU_NO_INLINE
  void setNeedsDisplay_slowPath() {
    needsLayout_ = true;
    [self setNeedsLayout];
  }

  void setNeedsDisplay() {
    if (needsDisplay_) return;
    needsDisplay_ = true;
    [self setNeedsDisplay];
  }

public:
  void layout(bool layoutEvenWithoutScreen = false) {
    checkNotDisplaying();
    needsLayout_ = false;

    if (UIScreen* const screen = visibleBoundsObserver_.screen()) {
      screenScale_ = screen.scale;
    } else if (layoutEvenWithoutScreen) {
      screenScale_ = stu_mainScreenScale();
    } else {
      // Let's wait until the layer has a window and actually needs to be displayed before we update
      // the tiles.
      screenScale_ = 0;
      setNeedsDisplay();
      return;
    }
    if (!(screenScale_ > 0)) {
      screenScale_ = 1;
    }

    const auto oldSize = size_;
    if (updateSizeAndVisibleBounds()) {
      resizeTiles(oldSize);
    }
    if (!drawingBlock_ || tileSize_.width == 0 || tileSize_.height == 0) {
      removeSpareLayersFromSuperLayer();
      return;
    }
    const Rect<SInt> tileRect = visibleTilesRectMultiple(5, true);
    if (tileRect != tileRect_) {
      setTileRect(tileRect);
    }
    if (tileRect.isEmpty()) {
      removeSpareLayersFromSuperLayer();
      return;
    }

    const Rect<SInt> visibleTileRect = tileRectOverlappingNonNegativeBounds(
                                         visibleBounds_.clampedTo({{}, size_}), tileSize_);
    const Rect<SInt> prerenderTileRect = visibleTilesRectMultiple(2, false);
    const Rect<SInt> keepLayerTileRect = visibleTilesRectMultiple(3, false);

    if (keepLayerTileRect_ != keepLayerTileRect) {
      keepLayerTileRect_ = keepLayerTileRect;
      forEachTileIn(tileRect_, [&](Point<SInt> location, Tile*& tile) {
        if (keepLayerTileRect.contains(location) || !tile) return;
        removeTileLayer(*tile);
        if (abandonTileIfUsedByTaskElseMakeItPurgeableOrDeleteIt(*tile, false)) {
          tile = nullptr;
        }
      });
    }
    auto& displayTiles = tempTileVector_;
    displayTiles.removeAll();
    bool visibleTileIsBeingPrerendered = false;
    if (needsDisplay_ || visibleTileRect_ != visibleTileRect) {
      visibleTileRect_ = visibleTileRect;
      STU_TRACE("Visible rect: [%i, %i] [%i, %i]",
                visibleTileRect_.x.start, visibleTileRect_.x.end - 1,
                visibleTileRect_.y.start, visibleTileRect_.y.end - 1);
      forEachTileIn(visibleTileRect, [&](Point<SInt> location, Tile*& tile) {
        if (tile && tile->layerHasImage()) return;
        if (!tile) {
          tile = getSpareTileOrCreateOne(location);
        }
        if (!tile->hasLayer()) {
          insertTileLayer(*tile);
        }
        if (isTileUsedByTask(*tile)) {
          visibleTileIsBeingPrerendered = true;
        } else if (!tile->trySetLayerImage()) {
          displayTiles.append(tile);
        }
      });
    }
    removeSpareLayersFromSuperLayer();
    if (prerenderTileRect_ != prerenderTileRect) {
      prerenderTileRect_ = prerenderTileRect;
      STU_TRACE("Prerender rect: [%i, %i] [%i, %i]",
                prerenderTileRect_.x.start, prerenderTileRect_.x.end - 1,
                prerenderTileRect_.y.start, prerenderTileRect_.y.end - 1);
      for (bool& value : sectorPrerendered_) {
        value = false;
      }
      if (!applicationDidEnterBackground) {
        forEachTileIn(prerenderTileRect, [&](Point<SInt> location __unused, Tile*& tile) {
          if (tile && !tile->hasLayer()) {
            tile->tryMakeNonPurgeableUntilNextCGImageIsCreated();
          }
        });
      }
    }
    if (visibleTileRect_.isEmpty()) {
      needsDisplay_ = false;
      return;
    }
    if (visibleTileIsBeingPrerendered || !displayTiles.isEmpty()) {
      setNeedsDisplay();
      return;
    }
    if (applicationDidEnterBackground) return;

    // We let the scrolling drive the prerendering and prerender with up to 2 threads.
    const Point<SInt> d = lastVisibleBoundsCenterDelta_;
    if (d.y != 0 && (!prerenderTile1_ || !isTileUsedByTask(*prerenderTile1_))) {
      const auto sectorIndex = d.y > 0 ? topSectorIndex : bottomSectorIndex;
      if (!sectorPrerendered_[sectorIndex]) {
        prerenderTile1_ = findTileToPrerender(visibleTileRect_.x, prerenderTileRect_.x, d.x,
                                              visibleTileRect_.y, prerenderTileRect_.y, d.y, false);
        if (prerenderTile1_) {
          prerenderTile1StartTimestamp_ = CACurrentMediaTime();
          prerenderTile1_->startPrerenderTask(displayScale_, inverseDisplayScale_, imageFormat_,
                                              drawingBlock_);
        } else {
          sectorPrerendered_[sectorIndex] = true;
        }
      }
    }
    if (d.x != 0 && (!prerenderTile2_ || !isTileUsedByTask(*prerenderTile2_))) {
      const auto sectorIndex = d.x > 0 ? rightSectorIndex : leftSectorIndex;
      if (!sectorPrerendered_[sectorIndex]) {
        prerenderTile2_ = findTileToPrerender(visibleTileRect_.y, prerenderTileRect_.y, d.y,
                                              visibleTileRect_.x, prerenderTileRect_.x, d.x, true);
        if (prerenderTile2_) {
          prerenderTile2StartTimestamp_ = CACurrentMediaTime();
          prerenderTile2_->startPrerenderTask(displayScale_, inverseDisplayScale_, imageFormat_,
                                              drawingBlock_);
        } else {
          sectorPrerendered_[sectorIndex] = true;
        }
      }
    }
  }

  void display() {
    checkNotDisplaying();
    if (!(screenScale_ > 0)) {
      layout(true);
    }
    isDisplaying_ = true;
    needsDisplay_ = false;

    auto& displayTiles = tempTileVector_;

    if (!displayTiles.isEmpty()) {
      if (displayTiles.count() == 1) {
         Tile& tile = *displayTiles[0];
         STU_TRACE("Render: (%i, %i)", tile.location().x, tile.location().y);
         tile.render(displayScale_, inverseDisplayScale_, imageFormat_, drawingBlock_);
      } else {
        dispatch_apply(sign_cast(displayTiles.count()), maximumPriorityQueue(), ^(UInt index) {
          Tile& tile = *displayTiles[sign_cast(index)];
          STU_TRACE("Render in parallel: (%i, %i)", tile.location().x, tile.location().y);
          tile.render(displayScale_, inverseDisplayScale_, imageFormat_, drawingBlock_);
        });
      }
      for (Tile* const tile : displayTiles) {
        tile->setLayerImage();
      }
      displayTiles.removeAll();
    }

    Tile* prerenderTile1 = nullptr;
    Tile* prerenderTile2 = nullptr;
    if (prerenderTile1_ && visibleTileRect_.contains(prerenderTile1_->location())) {
      prerenderTile1 = std::exchange(prerenderTile1_, nullptr);
    }
    if (prerenderTile2_ && visibleTileRect_.contains(prerenderTile2_->location())) {
      prerenderTile2 = std::exchange(prerenderTile2_, nullptr);
    }
    if (prerenderTile1 && prerenderTile2
        && prerenderTile1StartTimestamp_ > prerenderTile2StartTimestamp_)
    {
      std::swap(prerenderTile1, prerenderTile2);
    }
    if (prerenderTile1) {
      prerenderTile1->awaitTaskAndSetLayerImage();
    }
    if (prerenderTile2) {
      prerenderTile2->awaitTaskAndSetLayerImage();
    }

    isDisplaying_ = false;
  }

private:
  static dispatch_queue_t maximumPriorityQueue() {
    STU_STATIC_CONST_ONCE(dispatch_queue_t, queue,
                          dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
    return queue;
  }

  void checkNotDisplaying() {
    if (STU_UNLIKELY(isDisplaying_)) {
      invalidMultiThreadedOrReentrantCall();
    }
  }
  STU_NO_INLINE
  void invalidMultiThreadedOrReentrantCall() {
    STU_CHECK_MSG(false, "Invalid multi-threaded or reentrant STUTiledLayer method call.");
  }

  // MARK: - Size calculations

  template <typename Int, EnableIf<isSignedInteger<Int>> = 0>
  static STU_INLINE Int sub_saturated(Int a, Int b) {
    Int result;
    if (STU_UNLIKELY(__builtin_sub_overflow(a, b, &result))) {
      result = b > 0 ? minValue<Int> : maxValue<Int>;
    }
    return result;
  }

  template <typename Int, EnableIf<isInteger<Int>> = 0>
  static STU_INLINE Int mul_positive_saturated(Int a, Int b) {
    STU_ASSUME(a >= 0);
    STU_ASSUME(b >= 0);
    Int result;
    if (STU_UNLIKELY(__builtin_mul_overflow(a, b, &result))) {
      result = maxValue<Int>;
    }
    return result;
  }

  /// Returns true if size_, displayScale_ or visibleBounds_.size changes.
  bool updateSizeAndVisibleBounds() {
    STU_ASSERT(screenScale_ > 0);
    bool displayScaleChanged = contentsScaleChanged_;
    /// We have to be careful not to consume too much memory if a transform with scale less than
    /// displayScale/screenScale_ zooms out the layer and hence makes more tiles visible than
    /// would normally fit on the screen.
    Rect<CGFloat> visibleBounds = visibleBoundsObserver_.calculateVisibleBounds();
    if (const CGFloat areaScale = visibleBoundsObserver_.areaScale();
        displayScaleChanged || areaScale_ != areaScale)
    {
      areaScale_ = areaScale;
      const CGFloat threshold = sqrt(areaScale)*screenScale_;
      if (threshold >= contentsScale_*zoomScale_) {
        if (zoomScale_ < 1 && threshold > contentsScale_*zoomScale_) {
          do zoomScale_ *= 2;
          while (threshold > contentsScale_*zoomScale_);
          zoomScale_ = min(zoomScale_, 1.f);
          displayScaleChanged = true;
        }
      } else if (2.5*threshold < contentsScale_*zoomScale_) {
        do zoomScale_ /= 2;
        while (2.5*threshold < contentsScale_*zoomScale_);
        displayScaleChanged = true;
      }
    }
    /// Note that adjusting the displayScale by the zoom scale here is purely a safety measure to
    /// limit memory consumption. If you want to support smooth zooming, you should switch between
    /// multiple tiled layers rendered at different resolutions.
    if (displayScaleChanged) {
      contentsScaleChanged_ = false;
      removeAllTiles();
      displayScale_ = contentsScale_*zoomScale_;
      if (!(displayScale_ > 0)) {
        displayScale_ = 1;
      }
      inverseDisplayScale_ = 1/displayScale_;
      STU_TRACE("Display scale: %f", displayScale_);
      STU_TRACE("Contents scale: %f", contentsScale_);
      STU_TRACE("Zoom scale: %f", zoomScale_);
    }
    bool sizeChanged = displayScaleChanged || sizeChanged_;
    if (sizeChanged) {
      sizeChanged_ = false;
      const auto size = (Size<CGFloat>{layerSize_}*displayScale_).roundedToNearbyInt();
      size_ = Size{truncatePositiveFloatTo<SInt>(size.width),
                   truncatePositiveFloatTo<SInt>(size.height)};
      STU_TRACE("Layer size in pixels: (%i, %i)", size_.width, size_.height);
    }
    visibleBounds *= displayScale_;
    visibleBounds.roundToNearbyInt();
    Rect<SInt> bounds = Rect{Range{truncateFloatTo<SInt>(visibleBounds.x.start),
                                   truncateFloatTo<SInt>(visibleBounds.x.end)},
                             Range{truncateFloatTo<SInt>(visibleBounds.y.start),
                                   truncateFloatTo<SInt>(visibleBounds.y.end)}};
    // Clamp width and height to SInt range using unsigned arithmetic.
    const SInt width = sign_cast(min(sign_cast(bounds.x.end) - sign_cast(bounds.x.start),
                                     sign_cast(maxValue<SInt>)));
    const SInt height = sign_cast(min(sign_cast(bounds.y.end) - sign_cast(bounds.y.start),
                                      sign_cast(maxValue<SInt>)));
    bounds.x.end = bounds.x.start + width;
    bounds.y.end = bounds.y.start + height;

    const Point<SInt> newCenter{bounds.x.start + width/2, bounds.y.start + height/2};
    const Point<SInt> oldCenter{visibleBounds_.x.start + visibleBounds_.width()/2,
                                 visibleBounds_.y.start + visibleBounds_.height()/2};

    sizeChanged |= bounds.size() != visibleBounds_.size();
    visibleBounds_ = bounds;
    lastVisibleBoundsCenterDelta_ = Point{sub_saturated(newCenter.x, oldCenter.x),
                                          sub_saturated(newCenter.y, oldCenter.y)};
    return sizeChanged;
  }

  STU_NO_INLINE
  void updateScreenSizeAndTileSize(UIScreen* __unsafe_unretained screen) {
    if (!screen) {
      screen = UIScreen.mainScreen;
    }
    Size<CGFloat> screenSize = screen.bounds.size;
    CGFloat screenScale = screen.scale;
    if (!(screenSize.width > 0) || !(screenSize.height > 0)) {
      screenSize = CGSize{1920, 1080};
    }
    if (!(screenScale > 0)) {
      screenScale = 1;
    }
    screenSize *= screenScale;
    screenSize.roundToNearbyInt();
    screenSize_ = Size{truncatePositiveFloatTo<SInt>(screenSize.width),
                       truncatePositiveFloatTo<SInt>(screenSize.height)};

    CGFloat w = min(screenSize.width*1.25f, layerSize_.width*displayScale_);
    const CGFloat a1 = w*screenSize.height;
    const CGFloat a2 = min(screenSize.height*1.25f, layerSize_.width*displayScale_)
                       *screenSize.width;
    const bool isLarge = max(screenSize.width, screenSize.height) > 1900;
    const CGFloat a = max(a1, a2)*(isLarge ? 0.25f : CGFloat{1}/3);
    w = nearbyint(w);
    tileSize_ = Size{truncatePositiveFloatTo<SInt>(w),
                     truncatePositiveFloatTo<SInt>((a/w) + 1)};
  }

  // MARK: - Tile rects

  static Rect<SInt> tileRectOverlappingNonNegativeBounds(Rect<SInt> bounds, Size<SInt> tileSize) {
    STU_DEBUG_ASSERT(bounds.x.start >= 0 && bounds.y.start >= 0);
    bounds.x.end = max(bounds.x.start, bounds.x.end);
    bounds.y.end = max(bounds.y.start, bounds.y.end);
    const SInt tw = tileSize.width;
    const SInt th = tileSize.height;
    bounds.x.start /= tw;
    bounds.y.start /= th;
    // Use unsigned arithmetic to avoid a possible overflow.
    bounds.x.end = sign_cast((sign_cast(bounds.x.end) + sign_cast(tw - 1))/sign_cast(tw));
    bounds.y.end = sign_cast((sign_cast(bounds.y.end) + sign_cast(th - 1))/sign_cast(th));
    return bounds;
  }

  Rect<SInt> visibleTilesRectMultiple(SInt multiplier, bool relativeToScreenSize) const {
    SInt w = visibleBounds_.width();
    SInt h = visibleBounds_.height();
    STU_ASSUME(w >= 0);
    STU_ASSUME(h >= 0);
    const Point<SInt> center = {visibleBounds_.x.start + w/2, visibleBounds_.y.start + h/2};
    if (relativeToScreenSize) {
      w = max(w, screenSize_.width);
      h = max(h, screenSize_.height);
    }
    w = mul_positive_saturated(w, multiplier);
    h = mul_positive_saturated(h, multiplier);
    // Shift and clamp rect to layer bounds.
    Range<SInt> x;
    Range<SInt> y;
    x.start = max(0, min(center.x - w/2, size_.width  - w));
    y.start = max(0, min(center.y - h/2, size_.height - h));
    x.end = x.start + min(w, size_.width);
    y.end = y.start + min(h, size_.height);
    return tileRectOverlappingNonNegativeBounds({x, y}, tileSize_);
  }

  // MARK: - Tile iteration

  class Tile;

  Tile*& tileAt(SInt x, SInt y) {
    Tile*& tile = tiles_[(y - tileRect_.y.start)*tileColumnCount_ + (x - tileRect_.x.start)];
  #if STU_DEBUG
    STU_ASSERT(!tile || tile->location() == Point(x, y));
  #endif
    return tile;
  }

  template <typename F,
            bool isTilePredicate = isCallable<F, bool(Point<SInt>, Tile*&)>,
            EnableIf<isTilePredicate || isCallable<F, void(Point<SInt>, Tile*&)>> = 0>
  STU_INLINE
  auto forEachTileIn(Rect<SInt> rect, F&& f) -> Conditional<isTilePredicate, bool, void> {
    STU_DEBUG_ASSERT(tileRect_.contains(rect));
    SInt offset = (rect.y.start - tileRect_.y.start)*tileColumnCount_ - tileRect_.x.start;
    for (const SInt y : rect.y.iter()) {
      for (const SInt x : rect.x.iter()) {
        if constexpr (isTilePredicate) {
          if (!f(Point{x, y}, tiles_[offset + x])) return false;
        } else {
          f(Point{x, y}, tiles_[offset + x]);
        }
      }
      offset += tileColumnCount_;
    }
    if constexpr (isTilePredicate) {
      return true;
    } else {
      return;
    }
  }

  Tile* __nullable getTileToPrerenderAt(SInt x, SInt y, bool swapXAndY) {
    if (swapXAndY) {
      std::swap(x, y);
    }
    Tile*& tile = tileAt(x, y);
    if (!tile) {
      tile = getSpareTileOrCreateOne(Point{x, y});
    } else if (tile->hasLayer() || tile->tryMakeNonPurgeableUntilNextCGImageIsCreated()) {
      return nullptr;
    }
    return tile;
  }

  /// The sign of dx and dy indicate the respective scroll direction.
  STU_NO_INLINE
  Tile* findTileToPrerender(Range<SInt> visibleX, Range<SInt> prerenderX, SInt dx,
                            Range<SInt> visibleY, Range<SInt> prerenderY, SInt dy,
                            bool swapXAndY)
  {
    // This implementation is slightly obfuscated, because we want to reduce code size by having
    // only a single nested loop and only calling the loop body in one place.
    STU_DEBUG_ASSERT(!visibleX.isEmpty());
    STU_DEBUG_ASSERT(!visibleY.isEmpty());
    STU_DEBUG_ASSERT(prerenderX.contains(visibleX));
    STU_DEBUG_ASSERT(prerenderY.contains(visibleY));
    STU_DEBUG_ASSERT(dy != 0);
    SInt y0, y1, yd;
    // The outer loop iterates over y:
    //   y0, y0 + yd, y0 + 2*yd, ..., y1 - yd
    if (dy > 0) {
      yd = 1;
      y0 = visibleY.end;
      y1 = prerenderY.end;
    } else { // dy < 0
      yd = -1;
      y0 = visibleY.start - 1;
      y1 = prerenderY.start - 1;
    }
    // The inner loop iterates over x in two parts:
    //   x0, x0 + xd, x0 + 2*xd, ..., x1 - xd
    //   And if x1 != x2:
    //     x0 - xd, x0 - 2*xd, ..., x2 + xd
    SInt x0, x1, x2, xd;
    if (dx >= 0) {
      xd = -1;
      x0 = visibleX.end - 1;
      x1 = visibleX.start - 1;
      x2 = dx == 0 ? x1 : prerenderX.end;
    } else { // dx < 0
      xd = 1;
      x0 = visibleX.start;
      x1 = visibleX.end;
      x2 = prerenderX.start - 1;
    }
    for (SInt y = y0; y != y1; y += yd) {
      for (SInt x = x0, d = xd, xEnd = x1;;) {
        if (Tile* const tile = getTileToPrerenderAt(x, y, swapXAndY)) {
          return tile;
        }
        x += d;
        if (x == xEnd) {
          if (xEnd == x2) break;
          d = -d;
          x = x0 + d;
          xEnd = x2;
          if (x == xEnd) break;
        }
      }
    }
    return nullptr;
  }

  // MARK: - Tile helpers

  Tile* getSpareTileOrCreateOne(Point<SInt> location) {
    Tile* const tile = spareTiles_.isEmpty() ? mallocNew<Tile>().toRawPointer()
                     : spareTiles_.popLast();
    tile->location_ = location;
    auto frame = Rect{{location.x*tileSize_.width, location.y*tileSize_.height}, tileSize_};
    frame.x.end = min(frame.x.end, size_.width);
    frame.y.end = min(frame.y.end, size_.height);
    STU_DEBUG_ASSERT(!frame.isEmpty());
    tile->frame_ = frame;
    return tile;
  }

  void removeTileLayer(Tile& tile) {
    if (!tile.layer_) return;
    tile.clearLayerImage();
    spareLayers_.append(SpareTileLayer{tile.layer_, true});
    tile.layer_ = nil;
  }

  void removeSpareLayersFromSuperLayer() {
    for (SpareTileLayer& spareLayer : spareLayers_.reversed()) {
      if (!spareLayer.hasSuperlayer()) return;
      spareLayer.removeFromSuperlayer();
    }
  }

  void removeSpareTiles() {
    for (Tile* tile : spareTiles_.reversed()) {
      destroyAndFree(tile);
    }
    spareTiles_.removeAll();
  }

  void insertTileLayer(Tile& tile) {
    bool needToInsert;
    if (!spareLayers_.isEmpty()) {
      const SpareTileLayer spareLayer = spareLayers_.popLast();
      needToInsert = !spareLayer.hasSuperlayer();
      tile.layer_ = spareLayer.layer().unretained;
    } else {
      tile.layer_ = [[STUTileLayer alloc] init];
      needToInsert = true;
    }
    tile.layer_.frame = CGRect(tile.frame())*inverseDisplayScale_;
    if (needToInsert) {
      [self insertSublayer:tile.layer_ atIndex:0];
    }
  }

  /// Returns true if the tile was abandoned.
  [[nodiscard]]
  bool abandonTileIfUsedByTaskElseMakeItPurgeableOrDeleteIt(Tile& tile, bool deleteImage) {
    if (tile.task_) {
      if (prerenderTile1_ == &tile) {
        prerenderTile1_ = nullptr;
      } else {
        STU_ASSERT(prerenderTile2_ == &tile);
        prerenderTile2_ = nullptr;
      }
      if (tile.isUsedByTask()) {
        removeTileLayer(tile);
      }
    }
    return tile.abandonIfTaskIsRenderingElseMakeItPurgeableOrDeleteIt(deleteImage);
  }

  bool isTileUsedByTask(Tile& tile) {
    if (!tile.task_) return false;
    if (tile.isUsedByTask()) return true;
    if (prerenderTile1_ == &tile) {
      prerenderTile1_ = nullptr;
    } else {
      STU_ASSERT(prerenderTile2_ == &tile);
      prerenderTile2_ = nullptr;
    }
    return false;
  }

  // MARK: - Changing the current tile rect

  void removeAllTiles() {
    if (!tiles_.isEmpty()) return
    setTileRect({tileRect_.origin(), Size<SInt>{}});
  }

  void setTileRect(Rect<SInt> newRect) {
    if (newRect == tileRect_) return;
    newRect.x.end = max(newRect.x.start, newRect.x.end);
    newRect.y.end = max(newRect.y.start, newRect.y.end);

    Vector<Tile*> newTiles = std::move(tempTileVector_);
    newTiles.removeAll();
    const SInt newColumnCount = newRect.width();
    newTiles.ensureFreeCapacity(mul_positive_saturated(newColumnCount, newRect.height()));

    forEachTileIn(tileRect_, [&](Point<SInt> location, Tile*& tile) {
      if (!tile) return;
      if (newRect.contains(location)) return;
      removeTileLayer(*tile);
      if (!abandonTileIfUsedByTaskElseMakeItPurgeableOrDeleteIt(*tile, true)) {
        STU_DEBUG_ASSERT(!tile->layerHasImage());
        spareTiles_.append(tile);
      }
      tile = nullptr;
    });

    const auto oldRect = tileRect_;
    const SInt oldColumnCount = tileColumnCount_;
    for (const SInt y : newRect.y.iter()) {
      const bool oldRectContainsY = oldRect.y.contains(y);
      const SInt tilesIndexOffset = (y - oldRect.y.start)*oldColumnCount - oldRect.x.start;
      for (const SInt x : newRect.x.iter()) {
        if (oldRectContainsY && oldRect.x.contains(x)) {
          newTiles.append(tiles_[tilesIndexOffset + x]);
        #if STU_DEBUG
          tiles_[tilesIndexOffset + x] = nullptr;
        #endif
        } else {
          newTiles.append(nullptr);
        }
      }
    }
  #if STU_DEBUG
    for (Tile*& tile : tiles_) {
      STU_ASSERT(!tile);
    }
  #endif
    tiles_.removeAll();
    tempTileVector_ = std::move(tiles_);
    tiles_ = std::move(newTiles);
    tileRect_ = newRect;
    tileColumnCount_ = newColumnCount;
    keepLayerTileRect_.intersect(newRect);
    prerenderTileRect_.intersect(newRect);
    visibleTileRect_.intersect(newRect);
  }

  // This function expects the rest of layout() to run after it returns.
  STU_NO_INLINE
  void resizeTiles(Size<SInt> oldTiledLayerSize) {
    const Size oldTileSize = tileSize_;
    updateScreenSizeAndTileSize(visibleBoundsObserver_.screen());
    const Size newTileSize = tileSize_;
    if (oldTileSize == newTileSize && oldTiledLayerSize == size_) return;
    STU_TRACE_IF(oldTileSize != newTileSize,
                 "Tile size changed: (%i, %i) ==> (%i, %i)",
                 oldTileSize.width, oldTileSize.height, tileSize_.width, tileSize_.height);
    if (tiles_.isEmpty()) return;
    STU_ASSERT(tiles_.count() == tileRect_.area());
    // The rect of new tiles completely contained in the old rect.
    const Rect newTileRect = [&](){
      Rect bounds = tileRect_;
      bounds.x *= oldTileSize.width;
      bounds.y *= oldTileSize.height;
      bounds.x.end = min(bounds.x.end, oldTiledLayerSize.width);
      bounds.y.end = min(bounds.y.end, oldTiledLayerSize.height);
      Rect tileRect = {
        Range{bounds.x.start + (newTileSize.width - 1), bounds.x.end}/newTileSize.width,
        Range{bounds.y.start + (newTileSize.height - 1), bounds.y.end}/newTileSize.height
      };
      const Rect maxRect = tileRectOverlappingNonNegativeBounds(Rect{{}, size_}, newTileSize);
      tileRect.x.end = min(tileRect.x.end, maxRect.x.end);
      tileRect.y.end = min(tileRect.y.end, maxRect.y.end);
      return tileRect;
    }();
    if (newTileRect.isEmpty() || newTileSize == oldTileSize) {
      setTileRect(newTileRect);
      return;
    }
    const auto newTileColumnCount = newTileRect.width();
    const auto newTileCount = newTileColumnCount*newTileRect.height();
    // Find new tiles that we can patch together from existing images.
    Vector<UInt, 5> newTilesWithImagesBitArray;
    const int uintBits = IntegerTraits<UInt>::bits;
    const auto bitArrayWordAndMask = [&](Int index) STU_INLINE_LAMBDA -> Pair<UInt&, UInt> {
      const Int i = sign_cast(sign_cast(index)/uintBits);
      const Int j = sign_cast(sign_cast(index)%uintBits);
      return {newTilesWithImagesBitArray[i], UInt{1} << j};
    };
    newTilesWithImagesBitArray.append(repeat(0u, (newTileCount + (uintBits - 1))/uintBits));
    {
      Int newTileIndex = -1;
      for (const auto y : newTileRect.y.iter()) {
        for (const auto x : newTileRect.x.iter()) {
          ++newTileIndex;
          const Rect newTileFrame{Point{x*newTileSize.width, y*newTileSize.height}, newTileSize};
          const Rect tileRect = tileRectOverlappingNonNegativeBounds(newTileFrame, oldTileSize);
          if (forEachTileIn(tileRect,
                            [&](Point<SInt> location __unused, Tile* tile) {
                              return tile && tile->tryMakeNonPurgeableUntilNextCGImageIsCreated();
                            }))
          {
            const auto & [word, mask] = bitArrayWordAndMask(newTileIndex);
            word |= mask;
            forEachTileIn(tileRect, [&](Point<SInt> location __unused, Tile* tile) {
              const auto area = tile->frame().intersection(newTileFrame).area();
              STU_ASSERT(area > 0);
              const auto newNeededArea = tile->neededArea_.load(std::memory_order_relaxed) + area;
              tile->neededArea_.store(newNeededArea, std::memory_order_relaxed);
            });
          }
        }
      }
    }
    // Remove old tiles that we no longer need and create temporary CGImages.
    for (Tile*& tile : tiles_) {
      if (!tile) continue;
      removeTileLayer(*tile);
      if (tile->neededArea_.load(std::memory_order_relaxed) != 0) {
        tile->awaitTask();
        tile->tempCGImage_ = tile->image_.createCGImage();
        continue;
      }
      if (!tile->abandonIfTaskIsRenderingElseMakeItPurgeableOrDeleteIt(true)) {
        spareTiles_.append(tile);
      }
      tile = nullptr;
    }
    prerenderTile1_ = nullptr;
    prerenderTile2_ = nullptr;
    // Create new new Tiles.
    tempTileVector_.removeAll();
    tempTileVector_.ensureFreeCapacity(newTileCount);
    for (SInt i = 0; i < newTileCount; ++i) {
      if (const auto [word, mask] = bitArrayWordAndMask(i); !(word & mask)) continue;
      const Point<SInt> location = Point{i%newTileColumnCount, i/newTileColumnCount}
                                 + newTileRect.origin();
      tempTileVector_.append(getSpareTileOrCreateOne(location));
    }
    STU_TRACE("%li new tile images can be patched together from old tile images",
              tempTileVector_.count());
    // Draw the new tile images in parallel.
    dispatch_apply(sign_cast(tempTileVector_.count()), maximumPriorityQueue(), ^(UInt index) {
      Tile& newTile = *tempTileVector_[sign_cast(index)];
      // We're using an LLO coordinate system here.
      newTile.image_ = PurgeableImage{SizeInPixels{Size<UInt32>{newTile.frame().size()}}, -1, nil,
                                      imageFormat_, STUCGImageFormatOptions{},
        [&](CGContext* context)
      {
        forEachTileIn(tileRectOverlappingNonNegativeBounds(newTile.frame(), oldTileSize),
          [&](Point<SInt> location __unused, Tile* pOldTile)
        {
          Tile& oldTile = *pOldTile;
          const auto origin = Point{oldTile.frame().x.start - newTile.frame().x.start,
                                    newTile.frame().y.end - oldTile.frame().y.end};
          CGContextDrawImage(context, {CGPoint(origin), CGSize(oldTile.frame().size())},
                             oldTile.tempCGImage_.get());
          const auto area = oldTile.frame().intersection(newTile.frame()).area();
          const auto rest = oldTile.neededArea_.fetch_sub(area, std::memory_order_release) - area;
          STU_ASSERT(rest >= 0);
          if (rest == 0) {
            oldTile.neededArea_.load(std::memory_order_acquire);
            // Release the old images as early as possible.
            oldTile.tempCGImage_ = nullptr;
            oldTile.image_ = PurgeableImage();
          }
        });
      }};
    });
    // Remove the remaining old tiles.
    for (Tile*& tile : tiles_) {
      if (!tile) continue;
      STU_ASSERT(!tile->image_);
      STU_DEBUG_ASSERT(!tile->layer_);
      spareTiles_.append(tile);
    }
    tiles_.removeAll();
    // Insert the new tiles into tiles_.
    for (SInt i = 0, k = 0; i < newTileCount; ++i) {
      if (const auto [word, mask] = bitArrayWordAndMask(i); !(word & mask)) {
        tiles_.append(nullptr);
      } else{
        tiles_.append(tempTileVector_[k]);
        ++k;
      }
    }
    tempTileVector_.removeAll();
    tileRect_ = newTileRect;
    tileColumnCount_ = newTileColumnCount;
    visibleTileRect_ = Rect<SInt>{tileRect_.origin(), Size<SInt>{}};
    prerenderTileRect_ = visibleTileRect_;
    keepLayerTileRect_ = visibleTileRect_;
  }

  // MARK: - Tile

  class Tile {
    enum class Status: UInt8 {
      notUsedByTask,
      usedByTask,
      usedByTaskAndAbandoned
    };

    Point<SInt> location_;
    Rect<SInt> frame_;
    STUTileLayer* layer_; // arc
    dispatch_block_t task_; // arc
    /// Must only be accessed from the TiledLayer if task is null.
    PurgeableImage image_;
    bool layerHasImage_;
    CancellationFlag isCancelled_;
    std::atomic<Status> status_{Status::notUsedByTask};
    std::atomic<SInt> neededArea_{};
    RC<CGImage> tempCGImage_;

    friend Tile* TiledLayer::getSpareTileOrCreateOne(Point<SInt>);
    friend void TiledLayer::removeTileLayer(Tile&);
    friend void TiledLayer::insertTileLayer(Tile&);
    friend bool TiledLayer::isTileUsedByTask(Tile&);
    friend void TiledLayer::display();
    friend void TiledLayer::resizeTiles(Size<SInt>);

  public:
    /// frame.origin()/maxTileSize
    STU_INLINE_T Point<SInt> location() const { return location_; }

    STU_INLINE_T Rect<SInt> frame() const { return frame_; }

    void render(CGFloat scale, CGFloat inverseScale, STUPredefinedCGImageFormat format,
                DrawingBlock drawingBlock)
    {
      image_ = PurgeableImage{SizeInPixels{Size<UInt32>{frame_.size()}}, -1, nil,
                              format, STUCGImageFormatOptionsNone,
                              [&](CGContext* const context) {
                                const auto frame = Rect<CGFloat>{frame_};
                                CGContextConcatCTM(context,
                                                   CGAffineTransform{.a = scale, .d = -scale,
                                                                     .tx = -frame.x.start,
                                                                     .ty =  frame.y.end});
                                drawingBlock(context, frame*inverseScale, &isCancelled_);
                              }};
    }

    void startPrerenderTask(CGFloat scale, CGFloat inverseScale, STUPredefinedCGImageFormat format,
                            DrawingBlock drawingBlock)
    {
      STU_TRACE("Prerender (%i, %i)", location_.x, location_.y);
      STU_DEBUG_ASSERT(drawingBlock != nullptr);
      STU_DEBUG_ASSERT(!task_);
      STU_DEBUG_ASSERT(!isCancelled_);
      STU_DEBUG_ASSERT(status_.load(std::memory_order_relaxed) == Status::notUsedByTask);
      status_.store(Status::usedByTask, std::memory_order_relaxed);
      task_ = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, ^{
        if (!isCancelled_) {
          render(scale, inverseScale, format, drawingBlock);
        }
        Status expected = Status::usedByTask;
        if (!status_.compare_exchange_strong(expected, Status::notUsedByTask,
                                             std::memory_order_release, std::memory_order_acquire))
        {
          STU_ASSERT(expected == Status::usedByTaskAndAbandoned);
          destroyAndFree(this);
        }
      });
      STU_STATIC_CONST_ONCE(dispatch_queue_t, queue,
                            dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
      STU_ANALYZER_ASSUME(queue != nullptr);
      dispatch_async(queue, task_);
    }

    bool tryMakeNonPurgeableUntilNextCGImageIsCreated() {
      if (task_) return true;
    #if STU_TRACE_TILED_LAYER
      const bool wasPurgeable = image_ && !image_.isNonPurgeableUntilNextCGImageIsCreated();
    #endif
      const bool result = image_.tryMakeNonPurgeableUntilNextCGImageIsCreated();
    #if STU_TRACE_TILED_LAYER
      if (wasPurgeable) {
        if (result) {
          STU_TRACE("Made image non-purgeable (%i, %i)", location_.x, location_.y);
        } else {
          STU_TRACE("Image was purged (%i, %i)", location_.x, location_.y);
        }
      }
    #endif
      return result;
    }

    bool hasLayer() const {
      return layer_ != nil;
    }

    bool layerHasImage() const {
      return layerHasImage_;
    }

    bool trySetLayerImage() {
      STU_DEBUG_ASSERT(hasLayer() && !layerHasImage_);
      if (task_) return false;
      if (const RC<CGImage> cgImage = image_.createCGImage()) {
        layerHasImage_ = true;
        layer_.contents = (__bridge id)cgImage.get();
        return true;
      }
      return false;
    }

    void clearLayerImage() {
      if (!layerHasImage_) return;
      layerHasImage_ = false;
      layer_.contents = nil;
    }

  private:
    bool isUsedByTask() {
      if (task_ == nil) return false;
      const Status status = status_.load(std::memory_order_relaxed);
      if (status != Status::notUsedByTask) {
        STU_DEBUG_ASSERT(status == Status::usedByTask);
        return true;
      }
      status_.load(std::memory_order_acquire);
      task_ = nil;
      return false;
    }

    void setLayerImage() {
      const bool success = trySetLayerImage();
    #if DEBUG
      STU_ASSERT(success);
    #else
      discard(success);
    #endif
    }

    void awaitTask() {
      if (isUsedByTask()) {
        dispatch_block_wait(task_, DISPATCH_TIME_FOREVER);
        task_ = nil;
      }
    }

    void awaitTaskAndSetLayerImage() {
      STU_ASSERT(task_);
      awaitTask();
      setLayerImage();
    }

    friend bool TiledLayer::abandonTileIfUsedByTaskElseMakeItPurgeableOrDeleteIt(Tile&, bool);

    /// @pre !task_ || !layer_
    [[nodiscard]]
    bool abandonIfTaskIsRenderingElseMakeItPurgeableOrDeleteIt(bool deleteImage) {
      if (isUsedByTask()) {
        STU_ASSERT(!layer_);
        isCancelled_.setCancelled();
        Status expected = Status::usedByTask;
        if (status_.compare_exchange_strong(expected, Status::usedByTaskAndAbandoned,
                                            std::memory_order_release, std::memory_order_acquire))
        {
          STU_TRACE("Abandoned task (%i, %i)", location_.x, location_.y);
          return true;
        }
        isCancelled_.clear();
        task_ = nil;
        deleteImage = true;
      }
      if (image_) {
        clearLayerImage();
        if (deleteImage) {
          STU_TRACE("Deleted image (%i, %i)", location_.x, location_.y);
          image_ = PurgeableImage();
        } else {
          STU_TRACE_IF(image_.isNonPurgeableUntilNextCGImageIsCreated(),
                       "Made image purgeable (%i, %i)", location_.x, location_.y);
          image_.makePurgeableOnceAllCGImagesAreDestroyed();
        }
      }
      return false;
    }
  };

  // MARK: - Releasing memory after memory warnings or when the application enters the background

  static TiledLayer* lastTiledLayer;

  template <typename F, EnableIf<isCallable<F&&, void(TiledLayer&)>> = 0>
  static void forAllTiledLayers(F&& f) {
    STU_ASSERT(is_main_thread());
    TiledLayer* layer = lastTiledLayer;
    while (layer) {
      TiledLayer* const previous = layer->previousTiledLayer_;
      f(*layer);
      layer = previous;
    }
  }

  STU_NO_INLINE
  static void releaseMemoryOfAllTiledLayers() {
    forAllTiledLayers([](TiledLayer& layer){
      layer.releaseMemory();
    });
  }

  void releaseMemory() {
    if (!visibleBoundsObserver_.screen()) {
      removeAllTiles();
      setNeedsLayout();
    } else {
      forEachTileIn(tileRect_, [&](Point<SInt> location, Tile*& tile) {
        if (visibleTileRect_.contains(location) || !tile) return;
        removeTileLayer(*tile);
        if (abandonTileIfUsedByTaskElseMakeItPurgeableOrDeleteIt(*tile, false)) {
          tile = nullptr;
        }
      });
    }
    removeSpareLayersFromSuperLayer();
    spareLayers_.removeAll();
    spareLayers_.trimFreeCapacity();
    removeSpareTiles();
    spareTiles_.trimFreeCapacity();
    tempTileVector_.trimFreeCapacity();
    tiles_.trimFreeCapacity();
  }

  static bool applicationDidEnterBackground;

  static void registerTiledLayer(TiledLayer& layer) {
    STU_ASSERT(is_main_thread());

    STU_ASSERT(!layer.nextTiledLayer_ && !layer.previousTiledLayer_);
    layer.previousTiledLayer_ = lastTiledLayer;
    if (layer.previousTiledLayer_) {
      layer.previousTiledLayer_->nextTiledLayer_ = &layer;
    }
    layer.lastTiledLayer = &layer;

    static bool didRegisterForNotifications = false;
    if (STU_UNLIKELY(!didRegisterForNotifications)) {
      didRegisterForNotifications = true;
      NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
      NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
      [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        releaseMemoryOfAllTiledLayers();
      }];
      [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        applicationDidEnterBackground = true;
        releaseMemoryOfAllTiledLayers();
      }];
      [notificationCenter addObserverForName:UIApplicationWillEnterForegroundNotification
                                      object:nil queue:mainQueue
                                  usingBlock:^(NSNotification* notification __unused) {
        applicationDidEnterBackground = false;
      }];
    }
  }

  static void deregisterTiledLayer(TiledLayer& layer) {
    STU_ASSERT(is_main_thread());
    if (layer.previousTiledLayer_) {
      layer.previousTiledLayer_->nextTiledLayer_ = layer.nextTiledLayer_;
    }
    if (layer.nextTiledLayer_) {
      layer.nextTiledLayer_->previousTiledLayer_ = layer.previousTiledLayer_;
    } else {
      STU_ASSERT(lastTiledLayer == &layer);
      lastTiledLayer = layer.previousTiledLayer_;
    }
    layer.previousTiledLayer_ = nullptr;
    layer.nextTiledLayer_ = nullptr;
  }

  // MARK: - Destructor and fields
public:
  ~TiledLayer() {
    deregisterTiledLayer(*this);
    removeAllTiles();
    STU_DEBUG_ASSERT(tiles_.isEmpty());
    removeSpareTiles();
  }

private:
  // Fields without initializer are zero-initialized.

  STULabelTiledLayer* __unsafe_unretained self;
  TiledLayer* previousTiledLayer_;
  TiledLayer* nextTiledLayer_;

  bool needsLayout_;
  bool isDisplaying_;
  bool needsDisplay_ : 1;
  bool sizeChanged_ : 1;
  bool contentsScaleChanged_ : 1;
  STUPredefinedCGImageFormat imageFormat_{STUPredefinedCGImageFormatRGB};

  enum PrerenderSectorIndex {
    bottomSectorIndex = 0, topSectorIndex, rightSectorIndex, leftSectorIndex
  };
  bool sectorPrerendered_[4];

  CGFloat contentsScale_{1};
  CGFloat screenScale_; ///< Updated by layout().
  CGFloat areaScale_{1};
  CGFloat zoomScale_{1}; ///< Is <= 1. Prevents excessive memory use during zoom out operations.
  CGFloat displayScale_{1}; ///< contentsScale_*zoomScale_
  CGFloat inverseDisplayScale_{1}; ///< 1/displayScale_
  CGSize layerSize_; ///< The tiled layer size in points.

  Size<SInt> size_; ///< The tiled layer size in pixels.
  Size<SInt> screenSize_; ///< The screen size in pixels.
  Size<SInt> tileSize_; ///< The maximum tile size in pixels.
  Rect<SInt> visibleBounds_; ///< The visible bounds in pixels. NOT clamped to Rect{{}, size_}.
  Point<SInt> lastVisibleBoundsCenterDelta_;

  Rect<SInt> tileRect_;
  SInt tileColumnCount_;
  Rect<SInt> keepLayerTileRect_;
  Rect<SInt> prerenderTileRect_;
  Rect<SInt> visibleTileRect_;

  Tile* prerenderTile1_;
  CFTimeInterval prerenderTile1StartTimestamp_;
  Tile* prerenderTile2_;
  CFTimeInterval prerenderTile2StartTimestamp_;

  LayerVisibleBoundsObserver visibleBoundsObserver_;

  Vector<Tile*> tiles_;
  Vector<Tile*> tempTileVector_;
  Vector<Tile*> spareTiles_;
  Vector<SpareTileLayer> spareLayers_;

  DrawingBlock drawingBlock_;
};

bool TiledLayer::applicationDidEnterBackground;
TiledLayer* TiledLayer::lastTiledLayer;

} // namespace stu_label;

using namespace stu_label;

@implementation STULabelTiledLayer {
  TiledLayer impl;
}

- (instancetype)init {
  if ((self = [super init])) {
    impl.init(self);
    const CGFloat scale = stu_mainScreenScale();
    [super setContentsScale:scale];
    impl.setContentsScale(scale);
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  if ((self = [super initWithCoder:decoder])) {
    impl.init(self);
  }
  return self;
}

- (instancetype)initWithLayer:(id)layer {
  if ((self = [super initWithLayer:layer])) {
    STU_CHECK([layer isKindOfClass:STULabelTiledLayer.class]);
    impl.init(self);
    STULabelTiledLayer* const other = static_cast<STULabelTiledLayer*>(layer);
    impl.setDrawingBlock(other.drawingBlock);
    impl.setImageFormat(other.imageFormat);
    // The other parameters have already been set by the base class initializer.
  }
  return self;
}

- (STULabelTileDrawingBlock)drawingBlock {
  return impl.drawingBlock();
}
- (void)setDrawingBlock:(STULabelTileDrawingBlock)drawingBlock {
  impl.setDrawingBlock(drawingBlock);
}

- (STUPredefinedCGImageFormat)imageFormat {
  return impl.imageFormat();
}
- (void)setImageFormat:(STUPredefinedCGImageFormat)imageFormat {
  impl.setImageFormat(imageFormat);
}

- (void)setContentsFormat:(NSString* __unsafe_unretained)contentsFormat {
  [super setContentsFormat:contentsFormat];
  impl.setImageFormat(contentsImageFormat(contentsFormat, STUPredefinedCGImageFormatRGB));
}

- (void)setContentsScale:(CGFloat)contentsScale {
  contentsScale = clampDisplayScaleInput(contentsScale);
  [super setContentsScale:contentsScale];
  impl.setContentsScale(contentsScale);
}

- (void)setBounds:(CGRect)bounds {
  bounds = clampRectInput(bounds);
  [super setBounds:bounds];
  impl.setSize(CGSize{max(0.f, min(0.f, bounds.origin.x) + bounds.size.width),
                      max(0.f, min(0.f, bounds.origin.y) + bounds.size.height)});
}

- (void)layoutSublayers {
  [super layoutSublayers];
  impl.layout();
}

- (void)display {
  impl.display();
}

@end
