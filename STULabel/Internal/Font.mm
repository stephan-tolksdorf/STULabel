// Copyright 2017–2018 Stephan Tolksdorf

#import "Font.hpp"

#import "STULabel/stu_mutex.h"

#import "Hash.hpp"
#import "HashTable.hpp"
#import "Once.hpp"
#import "Rect.hpp"

#import "stu/ScopeGuard.hpp"
#import "stu/UniquePtr.hpp"
#import "stu/Vector.hpp"

namespace stu_label {

STU_NO_INLINE
CTFont* defaultCoreTextFont() {
  STU_STATIC_CONST_ONCE(UIFont*, value, [UIFont fontWithName:@"Helvetica" size:12]
                                        ?: [UIFont systemFontOfSize:12]);
  return (__bridge CTFont*)value;
}

struct FontInfoCache {
  struct Entry {
    FontRef font;
    HashCode<UInt> hashCode; // hash(CFHash(font.ctFont()))
    CachedFontInfo info;
  };

  Vector<Entry> entries;
  HashSet<UInt16, Malloc> indicesByFontPointer{uninitialized};
  HashSet<UInt16, Malloc> indicesByHashIdentity{uninitialized};


  STU_NO_INLINE
  void clear() {
    for (auto& entry : entries.reversed()) {
      decrementRefCount((__bridge UIFont*)entry.font.ctFont());
    }
    entries.removeAll();
    indicesByFontPointer.removeAll();
    indicesByHashIdentity.removeAll();
  }

};

static stu_mutex fontInfoCacheMutex = STU_MUTEX_INIT;
static bool fontInfoCacheIsInitialized = false;
alignas(FontInfoCache)
static Byte fontInfoCacheStorage[sizeof(FontInfoCache)];

CachedFontInfo::CachedFontInfo(FontRef font)
: metrics{uninitialized}
{
  CGFloat ascent = font.ascent();
  CGFloat descent = font.descent();
  if (STU_UNLIKELY(ascent < -descent)) {
    ascent = (ascent - descent)/2;
    descent = -ascent;
  }
  const CGFloat leading = max(0.f, font.leading());
  metrics = FontMetrics{ascent, descent, leading};
  xHeight = narrow_cast<Float32>(font.xHeight());
  capHeight = narrow_cast<Float32>(font.capHeight());
  yBoundsLLO = Range<Float32>(Rect{CTFontGetBoundingBox(font.ctFont())}.y);

  // This seems to be the way TextKit determines the decoration offset and thickness:
  underlineOffset = narrow_cast<Float32>(0.47230300542086412*(descent + leading));
  underlineThickness = narrow_cast<Float32>(CTFontGetUnderlineThickness(font.ctFont()));
  if (underlineThickness == 0) {
    underlineThickness = underlineOffset/2;
  }
  strikethroughThickness = narrow_cast<Float32>(0.0440277312696109*(ascent + descent + leading));

  const CTFontSymbolicTraits traits = CTFontGetSymbolicTraits(font.ctFont());
  hasColorGlyphs = !!(traits & kCTFontTraitColorGlyphs);
  shouldBeIgnoredInSecondPassOfLineMetricsCalculation = hasColorGlyphs;
  shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = hasColorGlyphs;
  if (hasColorGlyphs) return;
  RC<CFString> const name{CTFontCopyFamilyName(font.ctFont()), ShouldIncrementRefCount{false}};
  const Int length = CFStringGetLength(name.get());
  switch (length)  {
  case 6:
    if (CFEqual(name.get(), (__bridge CFString*)@"Symbol")) {
      shouldBeIgnoredInSecondPassOfLineMetricsCalculation = true;
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  case 7:
    if (CFEqual(name.get(), (__bridge CFString*)@"ArialMT")) {
      shouldBeIgnoredInSecondPassOfLineMetricsCalculation = true;
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  case 14:
    if (CFEqual(name.get(), (__bridge CFString*)@".PhoneFallback")) {
      shouldBeIgnoredInSecondPassOfLineMetricsCalculation = true;
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  case 25:
    if (CFEqual(name.get(), (__bridge CFString*)@".Helvetica Neue Interface")) {
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  }
}

CachedFontInfo CachedFontInfo::get(FontRef font) {
  const auto pointerHashCode = narrow_cast<HashCode<UInt>>(hashPointer(font.ctFont()));
  stu_mutex_lock(&fontInfoCacheMutex);
  if (STU_UNLIKELY(!fontInfoCacheIsInitialized)) {
    fontInfoCacheIsInitialized = true;
    FontInfoCache& cache = *new (fontInfoCacheStorage) FontInfoCache{};
    cache.indicesByFontPointer.initializeWithBucketCount(16);
    cache.indicesByHashIdentity.initializeWithBucketCount(16);
    cache.entries.ensureFreeCapacity(8);

    NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
    NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
    const auto clearCacheBlock = ^(NSNotification*) {
      stu_mutex_lock(&fontInfoCacheMutex);
      cache.clear();
      stu_mutex_unlock(&fontInfoCacheMutex);
    };
    [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
    [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
  }
  FontInfoCache& cache = reinterpret_cast<FontInfoCache&>(fontInfoCacheStorage);

  const auto isEqualFontPointer = [&](const UInt16 index) {
    return font.ctFont() == cache.entries[index].font.ctFont();
  };
  CachedFontInfo info{uninitialized};
  if (const auto optIndex = cache.indicesByFontPointer.find(pointerHashCode, isEqualFontPointer)) {
    info = cache.entries[*optIndex].info;
    stu_mutex_unlock(&fontInfoCacheMutex);
    return info;
  }

  const auto hashCode = narrow_cast<HashCode<UInt>>(hash(CFHash(font.ctFont())));
  const auto isEqualFont = [&](const UInt16 index) {
    const auto& entry = cache.entries[index];
    return hashCode == entry.hashCode && CFEqual(font.ctFont(), entry.font.ctFont());
  };
  if (const auto optIndex = cache.indicesByHashIdentity.find(hashCode, isEqualFont)) {
    info = cache.entries[*optIndex].info;
    stu_mutex_unlock(&fontInfoCacheMutex);
    return info;
  }
  stu_mutex_unlock(&fontInfoCacheMutex);
  info = CachedFontInfo{font};
  incrementRefCount((__bridge UIFont*)font.ctFont());
  stu_mutex_lock(&fontInfoCacheMutex);
  UInt16 index = narrow_cast<UInt16>(cache.entries.count());
  if (STU_UNLIKELY(index == maxValue<UInt16>)) {
    cache.clear();
    index = 0;
  }
  const bool inserted = cache.indicesByHashIdentity.insert(hashCode, index, isEqualFont).inserted;
  if (inserted) {
    cache.indicesByFontPointer.insertNew(pointerHashCode, index);
    cache.entries.append(FontInfoCache::Entry{font, hashCode, info});
  }
  stu_mutex_unlock(&fontInfoCacheMutex);
  if (!inserted) {
    decrementRefCount((__bridge UIFont*)font.ctFont());
  }
  return info;
};

struct FontFaceGlyphBoundsCache::Pool {
  FontFace fontFace;
  RC<CTFont> ctFont;
  Int cacheCount{};
  Vector<Malloced<FontFaceGlyphBoundsCache>> unusedCaches{};
};


class GlyphBoundsCache {
  using Pool = FontFaceGlyphBoundsCache::Pool;
public:
  HashSet<Malloced<Pool>, Malloc> poolsByFontFace{uninitialized};

  STU_NO_INLINE
  void clear() {
    poolsByFontFace.filterAndRehash(MinBucketCount{8}, [](const Malloced<Pool>& poolPtr) {
      Pool& pool = *poolPtr;
      pool.cacheCount -= pool.unusedCaches.count();
      pool.unusedCaches.removeAll();
      return pool.cacheCount != 0;
    });
  }
};

static stu_mutex glyphBoundsCacheMutex = STU_MUTEX_INIT;
static bool glyphBoundsCacheIsInitialized = false;
alignas(GlyphBoundsCache)
static Byte glyphBoundsCacheStorage[sizeof(GlyphBoundsCache)];

HashCode<UInt>FontFaceGlyphBoundsCache::FontFace::hash() {
  HashCode<UInt> hashCode = narrow_cast<HashCode<UInt>>(hashPointer(cgFont.get()));
  if (STU_UNLIKELY(!fontMatrixIsIdentity)) {
    hashCode = narrow_cast<HashCode<UInt>>(
                 stu_label::hash(hashCode, fontMatrix.a, fontMatrix.b, fontMatrix.c, fontMatrix.d));
  };
  return hashCode;
}

STU_NO_INLINE
void FontFaceGlyphBoundsCache::exchange(InOut<UniquePtr> inOutArg, FontRef font,
                                        FontFace&& fontFace)
{
  UniquePtr& inOutCache = inOutArg;
  STU_PRECONDITION(fontFace.cgFont);
  const HashCode<UInt> hashCode = fontFace.hash();
  stu_mutex_lock(&glyphBoundsCacheMutex);
  if (STU_UNLIKELY(!glyphBoundsCacheIsInitialized)) {
    glyphBoundsCacheIsInitialized = true;
    GlyphBoundsCache& glyphBoundsCache = *new (glyphBoundsCacheStorage) GlyphBoundsCache{};
    glyphBoundsCache.poolsByFontFace.initializeWithBucketCount(8);

    NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
    NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
    const auto clearCacheBlock = ^(NSNotification*) {
      stu_mutex_lock(&glyphBoundsCacheMutex);
      reinterpret_cast<GlyphBoundsCache&>(glyphBoundsCacheStorage).clear();
      stu_mutex_unlock(&glyphBoundsCacheMutex);
    };
    [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
    [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                    object:nil queue:mainQueue usingBlock:clearCacheBlock];
  }
  GlyphBoundsCache& glyphBoundsCache = reinterpret_cast<GlyphBoundsCache&>(glyphBoundsCacheStorage);
  if (inOutCache) {
    inOutCache->pool_.unusedCaches.append(Malloced{std::move(inOutCache).toRawPointer()});
  }
  const auto isEqualFontFace = [&](const Malloced<Pool>& entry) {
    return fontFace == entry->fontFace;
  };
  CachedFontInfo info{uninitialized};
  const auto result = glyphBoundsCache.poolsByFontFace.insert(
                        hashCode, isEqualFontFace,
                        [&] { return mallocNew<Pool>(std::move(fontFace), font.ctFont()); }
                      );
  Pool& pool = *result.value;
  Malloced<FontFaceGlyphBoundsCache> cache = nullptr;
  if (pool.unusedCaches.isEmpty()) {
    pool.cacheCount += 1;
  } else {
    cache = result.value->unusedCaches.popLast();
  }
  stu_mutex_unlock(&glyphBoundsCacheMutex);

  if (!cache) {
    cache = mallocNew<FontFaceGlyphBoundsCache>(pool);
  }

  STU_DEBUG_ASSERT(!inOutCache);
  inOutCache.assumeIsNull();
  inOutCache = UniquePtr{std::move(cache).toRawPointer()};
}

void FontFaceGlyphBoundsCache::returnToGlobalPool(FontFaceGlyphBoundsCache* cache) noexcept {
  stu_mutex_lock(&glyphBoundsCacheMutex);
  cache->pool_.unusedCaches.append(Malloced{cache});
  stu_mutex_unlock(&glyphBoundsCacheMutex);
}

FontFaceGlyphBoundsCache::FontFaceGlyphBoundsCache(Pool& pool)
: pool_{pool},
  font_{pool.ctFont.get()},
  fontSize_{font_.size()},
  unitsPerEM_{static_cast<Float64>(CTFontGetUnitsPerEm(font_.ctFont()))},
  unitPerPoint_{unitsPerEM_/fontSize_},
  pointPerUnit_{fontSize_/unitsPerEM_},
  usesIntBounds_{pool.fontFace.fontMatrixIsIdentity}
{
  if (usesIntBounds_) {
    new (&intBoundsByGlyphIndex_) decltype(intBoundsByGlyphIndex_){uninitialized};
    intBoundsByGlyphIndex_.initializeWithBucketCount(64);
  } else {
    new (&floatBoundsByGlyphIndex_) decltype(floatBoundsByGlyphIndex_){uninitialized};
    floatBoundsByGlyphIndex_.initializeWithBucketCount(64);
  }
}

FontFaceGlyphBoundsCache::~FontFaceGlyphBoundsCache() {
  if (usesIntBounds_) {
    intBoundsByGlyphIndex_.~HashTable();
  } else {
    floatBoundsByGlyphIndex_.~HashTable();
  }
}

auto FontFaceGlyphBoundsCache::fontFace() const -> const FontFace& { return pool_.fontFace; }

Rect<CGFloat> FontFaceGlyphBoundsCache::boundingRectFor(const CGFloat fontSize,
                                                        const ArrayRef<const CGGlyph> glyphs,
                                                        const CGPoint* const positions)
{
  TempVector<Int32> remaining{freeCapacityInCurrentThreadLocalAllocatorBuffer};

  const Float64 pointPerUnit = fontSize/unitsPerEM_;

  static constexpr Rect<Int16> intPlaceholder = {Range{minValue<Int16>, minValue<Int16>},
                                                 Range{minValue<Int16>, minValue<Int16>}};
  static constexpr Rect<Float32> floatPlaceholder = Rect<Float32>::infinitelyEmpty();

  static const Point<Float64> intBoundsOffsets[] = {{0, 0}, {0.5, 0}};

  Rect<CGFloat> rect = Rect<CGFloat>::infinitelyEmpty();
  Int newGlyphCount = 0;
  if (fontSize > 0) {
    if (usesIntBounds_) {
      const Point<Float64>& offset = intBoundsOffsets[usesHalfUnitIntBoundsXOffset_];
      for (Int i = 0; i < glyphs.count(); ++i) {
        const CGGlyph glyph = glyphs[i];
        const auto result = intBoundsByGlyphIndex_.insert(glyph, isEqualTo(glyph),
                                                          [&] { return intPlaceholder; });
        if (!result.inserted && result.value.x.end != intPlaceholder.x.end) {
          const auto bounds = result.value;
          if (!bounds.isEmpty()) {
            rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*(bounds + offset))
                                   + positions[i]);
          }
        } else {
          newGlyphCount += result.inserted;
          remaining.append(result.inserted ? narrow_cast<Int32>(i) : -narrow_cast<Int32>(i));
        }
      }
    } else {
      for (Int i = 0; i < glyphs.count(); ++i) {
        const CGGlyph glyph = glyphs[i];
        const auto result = floatBoundsByGlyphIndex_.insert(glyph, isEqualTo(glyph),
                                                            [&] { return floatPlaceholder; });
        if (!result.inserted && result.value.x.end != floatPlaceholder.x.end) {
          const auto bounds = result.value;
          if (!bounds.isEmpty()) {
            rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*bounds) + positions[i]);
          }
        } else {
          newGlyphCount += result.inserted;
          remaining.append(result.inserted ? narrow_cast<Int32>(i) : -narrow_cast<Int32>(i));
        }
      }
    }
  }
  remaining.trimFreeCapacity();
  if (STU_UNLIKELY(!remaining.isEmpty())) {
    TempArray<CGRect> newBounds{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    TempArray<CGGlyph> newGlyphs{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    TempArray<Int32> newGlyphIndices{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    {
      Int k = 0;
      for (auto i : remaining) {
        if (i >= 0) {
          newGlyphs[k] = glyphs[i];
          newGlyphIndices[k] = i;
          ++k;
        }
      }
      STU_ASSERT(k == newGlyphCount);
    }
    CTFontGetBoundingRectsForGlyphs(font_.ctFont(), kCTFontOrientationHorizontal,
                                    newGlyphs.begin(), newBounds.begin(), newGlyphCount);
    if (usesIntBounds_ && STU_UNLIKELY(intBoundsByGlyphIndex_.count() == newGlyphCount)) {
      const Float64 x = unitPerPoint_*newBounds[0].origin.x;
      if (nearbyint(2*x)/2 == floor(x) + 0.5) {
        usesHalfUnitIntBoundsXOffset_ = true;
      }
    }
    for (Int k = 0; k < newGlyphs.count(); ++k) {
      const CGGlyph glyph = newGlyphs[k];
      const Point<Float64> boundsOrigin = unitPerPoint_*newBounds[k].origin;
      const Size<Float64> boundsSize = unitPerPoint_*newBounds[k].size;
      if (usesIntBounds_) {
        const Point<Float64>& offset = intBoundsOffsets[usesHalfUnitIntBoundsXOffset_];
        const Rect<Float64> r = Rect<Float64>{boundsOrigin - offset, boundsSize}
                                .roundedToNearbyInt();
        if (STU_LIKELY(min(min(r.x.start, r.x.end), min(r.y.start, r.y.end)) >= minValue<Int16>
                       && max(max(r.x.start, r.x.end), max(r.y.start, r.y.end)) <= maxValue<Int16>))
        {
          const CGRect r1 = narrow_cast<CGRect>(pointPerUnit_*(r + offset));
          const CGRect& r2 = newBounds[k];
          const CGFloat eps = 2*epsilon<CGFloat>;
          if (   abs(r2.origin.x - r1.origin.x) <= abs(r2.origin.x)*eps
              && abs(r2.origin.y - r1.origin.y) <= abs(r2.origin.y)*eps
              && abs(r2.size.width  - r1.size.width)  <= r2.size.width*eps
              && abs(r2.size.height - r1.size.height) <= r2.size.height*eps)
          {
            *intBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph)) = narrow_cast<Rect<Int16>>(r);
            if (!r.isEmpty()) {
              rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*(r + offset))
                                     + positions[newGlyphIndices[k]]);
            }
            continue;
          }
        }
        // Switch to float bounds.
        const auto oldTable = std::move(intBoundsByGlyphIndex_);
        intBoundsByGlyphIndex_.~HashTable();
        new (&floatBoundsByGlyphIndex_) decltype(floatBoundsByGlyphIndex_){uninitialized};
        floatBoundsByGlyphIndex_.initializeWithBucketCount(oldTable.buckets().count());
        const auto offset_f32 = narrow_cast<Point<Float32>>(offset);
        for (auto& bucket : oldTable.buckets()) {
          if (!bucket.isEmpty()) {
            floatBoundsByGlyphIndex_.insertNew(bucket.key(), bucket.value + offset_f32);
          }
        }
        usesIntBounds_ = false;
      }
      const Rect<Float32> bounds_f32 = narrow_cast<Rect<Float32>>(Rect{boundsOrigin, boundsSize});
      *floatBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph)) = bounds_f32;
      if (!bounds_f32.isEmpty()) {
        rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*bounds_f32)
                               + positions[newGlyphIndices[k]]);
      }
    }
    if (newGlyphCount < remaining.count()) {
      if (usesIntBounds_) {
        const Point<Float64>& offset = intBoundsOffsets[usesHalfUnitIntBoundsXOffset_];
        for (auto i : remaining) {
          if (i >= 0) continue;
          i = -i;
          const CGGlyph glyph = glyphs[i];
          const auto bounds = *intBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph));
          if (!bounds.isEmpty()) {
            rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*(bounds + offset))
                                   + positions[i]);
          }
        }
      } else {
        for (auto i : remaining) {
          if (i >= 0) continue;
          i = -i;
          const CGGlyph glyph = glyphs[i];
          const auto bounds = *floatBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph));
          if (!bounds.isEmpty()) {
            rect = rect.convexHull(narrow_cast<Rect<CGFloat>>(pointPerUnit*bounds) + positions[i]);
          }
        }
      }
    }
  }
  if (rect.x.start == Range<CGFloat>::infinitelyEmpty().start) {
    rect = Rect<CGFloat>{};
  }
  return rect;
}

FontFaceGlyphBoundsCache::Ref LocalGlyphBoundsCache::glyphBoundsCacheFor(FontRef font) {
  CTFont* const ctFont = font.ctFont();
  STU_CHECK(ctFont != nullptr);
  if (STU_UNLIKELY(ctFont != entries_[0].font)) {
    const Entry entry0 = entries_[0];
    if (ctFont == entries_[1].font) {
      entries_[0] = entries_[1];
    } else {
      if (ctFont == entries_[2].font) {
        entries_[0] = entries_[2];
      } else {
        glyphBoundsCacheFor_slowPath(font);
      }
      entries_[2] = entries_[1];
    }
    entries_[1] = entry0;
  }
  return {*caches_[entries_[0].cacheIndex], entries_[0].fontSize};
}

STU_NO_INLINE
void LocalGlyphBoundsCache::glyphBoundsCacheFor_slowPath(FontRef font) {
  entries_[0].font = font.ctFont();
  entries_[0].fontSize = font.size();
  FontFaceGlyphBoundsCache::FontFace fontFace{font};
  UInt i = 0;
  for (;;) {
    if (caches_[i]) {
      if (caches_[i]->fontFace() == fontFace) break;
      if (++i != entryCount) continue;
      i = entries_[entryCount - 1].cacheIndex;
    }
    FontFaceGlyphBoundsCache::exchange(InOut{caches_[i]}, font, std::move(fontFace));
    break;
  }
  entries_[0].cacheIndex = i;
}

} // namespace stu_label

