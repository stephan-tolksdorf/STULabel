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

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

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

stu_mutex fontInfoCacheMutex = STU_MUTEX_INIT;
bool fontInfoCacheIsInitialized = false;
alignas(FontInfoCache)
Byte fontInfoCacheStorage[sizeof(FontInfoCache)];

CachedFontInfo::CachedFontInfo(FontRef font)
: metrics{uninitialized}
{
  CGFloat ascent = font.ascent();
  CGFloat descent = font.descent();
  if (STU_UNLIKELY(ascent < -descent)) {
    ascent = (ascent - descent)/2;
    descent = -ascent;
  }
  // We don't allow negative leading values. (Some fonts returned by UIFont.preferredFont currently
  // have a negative leading.)
  const CGFloat leading = max(0.f, font.leading());
  metrics = FontMetrics{ascent, descent, leading};
  xHeight = narrow_cast<Float32>(font.xHeight());
  capHeight = narrow_cast<Float32>(font.capHeight());
  yBoundsLLO = Range<Float32>(Rect{CTFontGetBoundingBox(font.ctFont())}.y);

  // This seems to be the way TextKit determines the decoration offset and thickness:
  strikethroughThickness = narrow_cast<Float32>(0.0440277312696109*(ascent + descent + leading));
  const Float64 underlineOffset = 0.47230300542086412*(descent + leading);
  const CGFloat thickness = CTFontGetUnderlineThickness(font.ctFont());

  underlineThickness = narrow_cast<Float32>(thickness);
   if (underlineThickness == 0) {
    underlineThickness = narrow_cast<Float32>(underlineOffset/2);
  }
  underlineMinY_ = narrow_cast<Float32>(underlineOffset*(CGFloat{3}/4));
  underlineMinYIsStrict_ = false;
  const CTFontSymbolicTraits traits = CTFontGetSymbolicTraits(font.ctFont());
  hasColorGlyphs = !!(traits & kCTFontTraitColorGlyphs);
  shouldBeIgnoredInSecondPassOfLineMetricsCalculation = false;
  shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = false;
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
  case 11:
  case 12:
    // [.]PingFang (SC|TC|HK)
    if (CFStringHasPrefix(name.get(), (__bridge CFString*)@".PingFang")
        || CFStringHasPrefix(name.get(), (__bridge CFString*)@"PingFang"))
    {
      // We want the underline to be positioned below the (lower) idiographic full stop in all
      // font weights.
      const Float32 minY = 0.12f*static_cast<Float32>(font.size());
      if (underlineMinY_ < minY + 1) {
        underlineMinY_ = minY;
        underlineMinYIsStrict_ = true;
      }
    }
    break;
  case 14:
    if (CFEqual(name.get(), (__bridge CFString*)@".PhoneFallback")) {
      shouldBeIgnoredInSecondPassOfLineMetricsCalculation = true;
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  case 15:
    if (CFEqual(name.get(), (__bridge CFString*)@"AppleColorEmoji")) {
      shouldBeIgnoredInSecondPassOfLineMetricsCalculation = true;
      shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont = true;
    }
    break;
  case 18:
    if (CFEqual(name.get(), (__bridge CFString*)@".AppleColorEmojiUI")) {
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

stu_mutex glyphBoundsCacheMutex = STU_MUTEX_INIT;
bool glyphBoundsCacheIsInitialized = false;
alignas(GlyphBoundsCache)
Byte glyphBoundsCacheStorage[sizeof(GlyphBoundsCache)];
// To inspect the glyph bounds cache in the debugger add the following watch expression:
// (stu_label::GlyphBoundsCache&)stu_label::glyphBoundsCacheStorage

/// @pre glyphBoundsCacheMutex must be locked by the current thread.
static void initGlyphBoundsCache() {
  STU_ASSERT(!glyphBoundsCacheIsInitialized);
  glyphBoundsCacheIsInitialized = true;
  GlyphBoundsCache& glyphBoundsCache = *new (glyphBoundsCacheStorage) GlyphBoundsCache{};
  glyphBoundsCache.poolsByFontFace.initializeWithBucketCount(8);

  NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
  NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
  const auto clearCacheBlock = ^(NSNotification*) {
    FontFaceGlyphBoundsCache::clearGlobalCache();
  };
  [notificationCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                  object:nil queue:mainQueue usingBlock:clearCacheBlock];
  [notificationCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                  object:nil queue:mainQueue usingBlock:clearCacheBlock];
}

void FontFaceGlyphBoundsCache::clearGlobalCache() {
  stu_mutex_lock(&glyphBoundsCacheMutex);
  if (glyphBoundsCacheIsInitialized) {
    reinterpret_cast<GlyphBoundsCache&>(glyphBoundsCacheStorage).clear();
  }
  stu_mutex_unlock(&glyphBoundsCacheMutex);
}

HashCode<UInt>FontFaceGlyphBoundsCache::FontFace::hash() {
  return narrow_cast<HashCode<UInt>>(
           stu_label::hash(bit_cast<UInt>(cgFont.get())
                           ^ hashableBits(fontMatrix.a) ^ hashableBits(fontMatrix.b),
                           hashableBits(appleColorEmojiSize)
                           ^ hashableBits(fontMatrix.c) ^ hashableBits(fontMatrix.d)));
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
    initGlyphBoundsCache();
  }
  GlyphBoundsCache& glyphBoundsCache = reinterpret_cast<GlyphBoundsCache&>(glyphBoundsCacheStorage);
  if (inOutCache) { // Return the cache to its pool.
    inOutCache->pool_.unusedCaches.append(Malloced{std::move(inOutCache).toRawPointer()});
  }
  const auto isEqualFontFace = [&](const Malloced<Pool>& entry) {
    return fontFace == entry->fontFace;
  };
  // Get the reference to the existing pool for the font face,
  // or insert a new pool and return the reference.
  const auto result = glyphBoundsCache.poolsByFontFace.insert(
                        hashCode, isEqualFontFace,
                        [&] { return mallocNew<Pool>(std::move(fontFace), font.ctFont()); }
                      );
  Pool& pool = *result.value;
  Malloced<FontFaceGlyphBoundsCache> cache = nullptr;
  if (pool.unusedCaches.isEmpty()) { // We'll create the cache after unlocking the mutex.
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

void FontFaceGlyphBoundsCache::returnToGlobalPool(FontFaceGlyphBoundsCache* __nonnull cache) noexcept {
  stu_mutex_lock(&glyphBoundsCacheMutex);
  cache->pool_.unusedCaches.append(Malloced{cache});
  stu_mutex_unlock(&glyphBoundsCacheMutex);
}

STU_NO_INLINE
void FontFaceGlyphBoundsCache
     ::returnToGlobalPool(ArrayRef<FontFaceGlyphBoundsCache* __nullable const> caches)
{
  stu_mutex_lock(&glyphBoundsCacheMutex);
  for (const auto cache : caches) {
    if (cache) {
      cache->pool_.unusedCaches.append(Malloced{cache});
    }
  }
  stu_mutex_unlock(&glyphBoundsCacheMutex);
}

// NOTE: We use the following details of the transformation that Core Text applies to the emoji font
// glyph bounds only for transforming the bounds back into 16-bit integer coordinates (in order to
// save memory without loosing accuracy). Should these details change in the future,
// FontFaceGlyphBoundsCache::boundingRect will automatically fall back to Float32 bounds.

static CGFloat appleColorEmojiTrackValue(bool isAppleColorEmojiUI, CGFloat fontSize) {
  struct Entry {
    uint8_t fontSize;
    uint8_t value;
  };
  // The values come from the 'trak' tables of the EmojiColorFont. You can extract the tables
  // from the AppleColorEmoji.ttc font e.g. with the help of the ttx util from fonttools:
  // `ttx -t name -t trak -y 0 AppleColorEmoji.ttc` extracts the non-UI font data. To get the
  // UI font data, replace 0 with 1.
  static constexpr Entry nonUITable[] = {{0, 0}, {9, 46}, {16, 46}, {22, 30}, {29, 0}};
  static constexpr Entry uiTable[] = {{0, 124}, {9, 124}, {13, 116}, {16, 114}, {17, 112},
                                      {20, 110}, {32, 106}, {36, 102}, {40, 100}, {48, 70},
                                      {64, 60}, {80, 62}, {96, 64}, {160, 70}};

  static_assert(uiTable[arrayLength(nonUITable) - 1].fontSize <= 255);
  static_assert(uiTable[arrayLength(uiTable) - 1].fontSize <= 255);
  const UInt8 u8FontSize = fontSize >= 255 ? 255 : static_cast<UInt8>(fontSize);

  const Entry* const table = isAppleColorEmojiUI ? uiTable : nonUITable;
  const Int n = isAppleColorEmojiUI ? arrayLength(uiTable) : arrayLength(nonUITable);

  for (Int i = 1;;) {
    if (u8FontSize >= table[i].fontSize) {
      if (++i < n) continue;
      return table[n - 1].value;
    }
    return trunc(table[i - 1].value
                 + ((fontSize - table[i - 1].fontSize)
                    * static_cast<CGFloat>(int{table[i].value} - int{table[i - 1].value}))
                   / static_cast<CGFloat>(int{table[i].fontSize} - int{table[i - 1].fontSize}));
  }
}

static CGFloat effectiveAppleColorEmojiFontSize(CGFloat fontSize) {
  // This is the transformation calculated by CoreText's TFont::GetEffectiveSize().
  if (fontSize <= 16) {
    return fontSize + fontSize/4;
  }
  if (fontSize < 24) {
    return fontSize + (24 - fontSize)/2;
  }
  return narrow_cast<CGFloat>(fontSize + 0.0001);
}

static CGPoint scaledAppleColorEmojiOffset(bool isAppleColorEmojiUI, CGFloat fontSize,
                                           CGFloat effectivePointsPerEM)
{
  // This is the offset calculated by CoreText's TFont::GetColorBitmapFontTranslate().
  const auto version = CTGetCoreTextVersion();
  CGFloat x;
  if (version > kCTVersionNumber10_12) {
    const CGFloat track = appleColorEmojiTrackValue(isAppleColorEmojiUI, fontSize);
    x = narrow_cast<CGFloat>(effectivePointsPerEM*track*0.4);
    if (x == 0) {
      x = 0.5;
    }
  } else if (version == kCTVersionNumber10_12) {
    x = isAppleColorEmojiUI || fontSize < 29 ? 0 : 0.5f;
  } else {
    x = 0.5;
  }
  CGFloat y1 = narrow_cast<CGFloat>(-0.075*fontSize);
  if (version >= kCTVersionNumber10_12) {
    y1 *= 2;
  } else {
    y1 = narrow_cast<CGFloat>(y1*1.7);
  }
  CGFloat y2;
  if (fontSize < 16) {
    y2 = fontSize/4;
  } else if (fontSize < 24) {
    y2 = (24 - fontSize)/2;
  } else {
    y2 = 0;
  }
  const CGFloat y = y1 - y2/2;
  return {x, y};
}

FontFaceGlyphBoundsCache::InitData::InitData(Pool& pool)
: pool{pool},
  font{pool.ctFont.get()},
  unitsPerEM{static_cast<CGFloat>(CTFontGetUnitsPerEm(font.ctFont()))},
  offset{},
  isAppleColorEmoji{pool.fontFace.isAppleColorEmoji},
  useIntBounds{pool.fontFace.fontMatrixIsIdentity}
{
  if (!isAppleColorEmoji) {
    pointsPerUnit = font.size()/unitsPerEM;
  } else if (!useIntBounds) {
    pointsPerUnit = 1;
  } else {
    const CGFloat fontSize = pool.fontFace.appleColorEmojiSize;
    pointsPerUnit = effectiveAppleColorEmojiFontSize(fontSize)/unitsPerEM;
    offset = scaledAppleColorEmojiOffset(pool.fontFace.isAppleColorEmojiUI, fontSize,
                                         pointsPerUnit);
  }
}

FontFaceGlyphBoundsCache::FontFaceGlyphBoundsCache(InitData data)
: pool_{data.pool},
  font_{pool_.ctFont.get()},
  unitsPerEM_{data.unitsPerEM},
  pointsPerUnit_{data.pointsPerUnit},
  inversePointsPerUnit_{1/pointsPerUnit_},
  scaledIntBoundsOffset_{data.offset},
  isAppleColorEmoji_{data.isAppleColorEmoji},
  usesIntBounds_{data.useIntBounds}
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

void FontFaceGlyphBoundsCache::switchToFloatBounds() {
  STU_ASSERT(usesIntBounds_);

  const auto oldTable = std::move(intBoundsByGlyphIndex_);

  // Change the active member of the union.
  intBoundsByGlyphIndex_.~HashTable();
  new (&floatBoundsByGlyphIndex_) decltype(floatBoundsByGlyphIndex_){uninitialized};
  floatBoundsByGlyphIndex_.initializeWithBucketCount(oldTable.buckets().count());

  // If isAppleColorEmoji_, we only use the cache for a single font size. So, when storing the
  // bounds as floats, it's preferable not to apply any transformation to the values returned
  // CTFontGetBoundingRectsForGlyphs. Hence, if isAppleColorEmoji_, we undo the transformation for
  // any previously stored bounds and then set pointsPerUnit_ to 1 and scaledIntBoundsOffset_ to 0.

  if (oldTable.count()) {
    for (auto& bucket : oldTable.buckets()) {
      if (!bucket.isEmpty()) {
        Rect<Float32> r;
        if (!isAppleColorEmoji_) {
          r = bucket.value;
        } else {
          r = narrow_cast<Rect<Float32>>(pointsPerUnit_*bucket.value + scaledIntBoundsOffset_);
        }
        floatBoundsByGlyphIndex_.insertNew(bucket.key(), r);
      }
    }
  }

  usesIntBounds_ = false;
  if (isAppleColorEmoji_) {
    pointsPerUnit_ = 1;
    inversePointsPerUnit_ = 1;
    scaledIntBoundsOffset_ = Point<CGFloat>{};
  }
}

auto FontFaceGlyphBoundsCache::fontFace() const -> const FontFace& { return pool_.fontFace; }

/// Indicates whether r1 is equal to the reference rect r2 with close to maximum accuracy.
STU_INLINE
static bool isBoundsRectEqualToRectWithHighAccuracy(Rect<CGFloat> r1, Rect<CGFloat> r2) {
  const CGFloat eps = 2*epsilon<CGFloat>;
  return abs(r2.x.start - r1.x.start) <= eps*abs(r2.x.start)
      && abs(r2.y.start - r1.y.start) <= eps*abs(r2.y.start)
      && abs(r2.x.end   - r1.x.end)   <= eps*max(abs(r2.x.end), r2.width())
      && abs(r2.y.end   - r1.y.end)   <= eps*max(abs(r2.y.end), r2.height());
}

Rect<CGFloat> FontFaceGlyphBoundsCache::boundingRect(const CGFloat fontSize,
                                                     const ArrayRef<const CGGlyph> glyphs,
                                                     const CGPoint* const positions)
{
  /// The scanGlyphs function fills this vector with the glyph array indices of the glyphs
  /// whose bounds haven't yet been cached. If the same glyph occurs more than once, the index for
  /// every occurance other than the first is inverted, i.e. multiplied by -1.
  TempVector<Int32> remaining{freeCapacityInCurrentThreadLocalAllocatorBuffer};

  /// The number of different remaining glyphs, which may be less than remaining.count().
  Int newGlyphCount = 0;

  STU_DEBUG_ASSERT(!isAppleColorEmoji_ || fontSize == pool_.fontFace.appleColorEmojiSize);
  CGFloat pointsPerUnit = isAppleColorEmoji_ ? pointsPerUnit_ : fontSize/unitsPerEM_;

  Rect<CGFloat> rect = Rect<CGFloat>::infinitelyEmpty();

  enum class BoundsAreInt : bool {}; // A "strong typedef" used in lieue of a named argument.

  const auto extendRect = [&](/* Rect */ auto glyphBounds, BoundsAreInt boundsAreInt,
                              Int positionIndex) STU_INLINE_LAMBDA
  {
    if (glyphBounds.isEmpty()) return;
    Point<CGFloat> offset = positions[positionIndex];
    if (boundsAreInt == BoundsAreInt{true}) {
      offset += scaledIntBoundsOffset_;
    }
    rect = rect.convexHull(pointsPerUnit*glyphBounds + offset);
  };

  if (fontSize > 0) {
    static constexpr Rect<Int16> intPlaceholder = {Range{minValue<Int16>, minValue<Int16>},
                                                   Range{minValue<Int16>, minValue<Int16>}};
    static constexpr Rect<Float32> floatPlaceholder = Rect<Float32>::infinitelyEmpty();
    const auto scanGlyphs = [&](auto& boundsByGlyph, const auto& placeholder) STU_INLINE_LAMBDA {
      for (Int i = 0; i < glyphs.count(); ++i) {
        // Look up the glyph in the hash table
        // and if it doesn't yet have an entry, insert a placeholder value.
        const CGGlyph glyph = glyphs[i];
        if (glyph == maxValue<CGGlyph>) {
          static_assert(maxValue<CGGlyph> == kCGFontIndexInvalid);
          // CTRunGetGlyphs sometimes returns an invalid glyph (with code kCGFontIndexInvalid) with
          // a zero width. Since this value is used as a reserved value in the boundsByGlyph
          // HashTable, we have to filter it out here if we don't want to run into an assertion
          // error in the insert, see https://github.com/stephan-tolksdorf/STULabel/issues/20
          // Chromium also contains code handling CTRunGetGlyphs returning invalid glyphs, see
          // https://chromium.googlesource.com/chromium/src/+/59fe54df8c0de55f03c8fb5e1860279d2993b473/ui/gfx/render_text_mac.mm#389
          continue;
        }
          
        const auto result = boundsByGlyph.insert(glyph, isEqualTo(glyph),
                                                 [&] { return placeholder; });
        if (!result.inserted && result.value.x.end != placeholder.x.end) {
          // If there was already a non-placeholder entry for the glyph, extend the bounding rect
          // for the positioned glyph.
          extendRect(result.value, BoundsAreInt{isInteger<decltype(placeholder.x.start)>}, i);
        } else {
          // We don't yet have cached bounds for this glyph.
          newGlyphCount += result.inserted;
          remaining.append(result.inserted ? narrow_cast<Int32>(i) : -narrow_cast<Int32>(i));
        }
      }
    };
    if (STU_LIKELY(usesIntBounds_)) {
      scanGlyphs(intBoundsByGlyphIndex_, intPlaceholder);
    } else {
      scanGlyphs(floatBoundsByGlyphIndex_, floatPlaceholder);
    }
  }
  remaining.trimFreeCapacity();
  if (STU_UNLIKELY(!remaining.isEmpty())) {
    // Fetch the bounds for the non-duplicate new glyphs.
    TempArray<CGRect> newBounds{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    TempArray<CGGlyph> newGlyphs{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    TempArray<Int32> newGlyphIndices{uninitialized, Count{newGlyphCount}, remaining.allocator()};
    {
      Int k = 0;
      for (auto i : remaining) {
        if (i >= 0) { // A negative index indicates a duplicate occurence of a new glyph.
          newGlyphs[k] = glyphs[i];
          newGlyphIndices[k] = i;
          ++k;
        }
      }
      STU_ASSERT(k == newGlyphCount);
    }
    CTFontGetBoundingRectsForGlyphs(font_.ctFont(), kCTFontOrientationHorizontal,
                                    newGlyphs.begin(), newBounds.begin(), newGlyphCount);
    for (Int k = 0; k < newGlyphs.count(); ++k) {
      const CGGlyph glyph = newGlyphs[k];
      Rect<CGFloat> bounds = Rect{newBounds[k].origin - scaledIntBoundsOffset_,
                                  newBounds[k].size}
                             * inversePointsPerUnit_;
      if (STU_LIKELY(usesIntBounds_)) {
        // Before inserting the bounds into intBoundsByGlyphIndex_ check that the bounds were
        // derived from the integer font space coordinates as expected.
        const Rect<CGFloat> r = bounds.roundedToNearbyInt();
        if (STU_LIKELY(
            // Can the rounded coordinates be represented with 16-bit signed integers?
               min(min(r.x.start, r.x.end), min(r.y.start, r.y.end)) >= minValue<Int16>
            && max(max(r.x.start, r.x.end), max(r.y.start, r.y.end)) <= maxValue<Int16>
            // Do we get back the original bounds when applying the inverse transform to r?
            && isBoundsRectEqualToRectWithHighAccuracy(pointsPerUnit_*r + scaledIntBoundsOffset_,
                                                       newBounds[k])
          #if STU_DEBUG
            && intBoundsByGlyphIndex_.count() < maxIntBoundsCount_
          #endif
            ))
        {
          *intBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph)) = narrow_cast<Rect<Int16>>(r);
          extendRect(r, BoundsAreInt{true}, newGlyphIndices[k]);
          continue;
        }
        switchToFloatBounds();
        if (isAppleColorEmoji_) {
          STU_DEBUG_ASSERT(pointsPerUnit_ == 1 && scaledIntBoundsOffset_ == Point<CGFloat>{});
          pointsPerUnit = 1;
          bounds = newBounds[k];
        } else {
          STU_DEBUG_ASSERT(pointsPerUnit == pointsPerUnit_);
        }
      }
      // !usesIntBounds_
      const Rect<Float32> bounds_f32 = narrow_cast<Rect<Float32>>(bounds);
      *floatBoundsByGlyphIndex_.find(glyph, isEqualTo(glyph)) = bounds_f32;
      extendRect(bounds_f32, BoundsAreInt{false}, newGlyphIndices[k]);
    }
    if (newGlyphCount < remaining.count()) {
      const auto extendRectForRemainingGlyphs = [&](auto& boundsByGlyph) STU_INLINE_LAMBDA {
        for (auto i : remaining) {
          // We already adjusted the bounding rect for the non-duplicate new glyphs.
          if (i >= 0) continue; // Indices of duplicate glyph occurences are multiplied by -1.
          i = -i;
          const CGGlyph glyph = glyphs[i];
          const auto bounds = *boundsByGlyph.find(glyph, isEqualTo(glyph));
          extendRect(bounds, BoundsAreInt{isInteger<decltype(bounds.x.start)>}, i);
        }
      };
      if (STU_LIKELY(usesIntBounds_)) {
        extendRectForRemainingGlyphs(intBoundsByGlyphIndex_);
      } else {
        extendRectForRemainingGlyphs(floatBoundsByGlyphIndex_);
      }
    }
  }
  if (rect.x.start == Range<CGFloat>::infinitelyEmpty().start) {
    rect = Rect<CGFloat>{};
  }
  return rect;
}

#if STU_DEBUG
void LocalGlyphBoundsCache::checkInvariants() {
  using FontFace = FontFaceGlyphBoundsCache::FontFace;
  for (auto& entry : entries_) {
    if (entry.font == nil) continue;
    STU_CHECK(CTFontGetSize(entry.font) == entry.fontSize);
    STU_CHECK(caches_[entry.cacheIndex]->fontFace() == FontFace(entry.font, entry.fontSize));
  }
  const auto caches = ArrayRef{caches_};
  for (Int i = 0; i < caches.count(); ++i) {
    for (Int j = i + 1; j < caches.count(); ++j) {
      STU_CHECK(!caches[i] || !caches[j] || caches[i] != caches[j]);
    }
  }
}
#endif

STU_NO_INLINE
FontFaceGlyphBoundsCache::Ref LocalGlyphBoundsCache::glyphBoundsCache(FontRef font) {
  CTFont* const ctFont = font.ctFont();
  STU_CHECK(ctFont != nullptr);
  // We only compare the font pointers here. We will compare the font face identity in _slowPath.
  if (STU_UNLIKELY(ctFont != entries_[0].font)) {
    // We keep the entries in LRU order.
    const Entry entry0 = entries_[0];
    if (ctFont == entries_[1].font) {
      entries_[0] = entries_[1];
    } else {
      if (ctFont == entries_[2].font) {
        entries_[0] = entries_[2];
      } else {
        static_assert(entryCount == 3);
        glyphBoundsCacheFor_slowPath(font); // Assigns entries_[0].
      }
      entries_[2] = entries_[1];
    }
    entries_[1] = entry0;
  }
  return {*caches_[entries_[0].cacheIndex], entries_[0].fontSize};
}
STU_NO_INLINE
void LocalGlyphBoundsCache::glyphBoundsCacheFor_slowPath(FontRef font) {
  static_assert(entryCount == STU_ARRAY_LENGTH(entries_));
  static_assert(entryCount == STU_ARRAY_LENGTH(caches_));
  const CGFloat fontSize = font.size();
  entries_[0].font = font.ctFont();
  entries_[0].fontSize = fontSize;
  FontFaceGlyphBoundsCache::FontFace fontFace{font, fontSize};
  UInt i = 0;
  for (;;) {
    if (caches_[i]) {
      if (caches_[i]->fontFace() == fontFace) break;
      if (++i != entryCount) continue;
      // We need to replace one of the existing caches.
      // Check if one of the caches is currently unused by the entries.
      bool isCachedUsed[entryCount] = {};
      for (const auto& entry : entries_) {
        isCachedUsed[entry.cacheIndex] = true;
      }
      i = 0;
      for (;;) {
        // We replace the first unused cache...
        if (!isCachedUsed[i]) break;
        if (++i != entryCount) continue;
        // ... or if all caches are used, i.e. if each font entry uses a different cache,
        // we replace the cache associated with the last entry. (Note that the last entry will be
        // immediately overwritten by the second to last entry when this function returns.)
        i = entries_[entryCount - 1].cacheIndex;
        break;
      }
    }
    FontFaceGlyphBoundsCache::UniquePtr ptr{caches_[i]};
    FontFaceGlyphBoundsCache::exchange(InOut{ptr}, font, std::move(fontFace));
    caches_[i] = std::move(ptr).toRawPointer();
    break;
  }
  entries_[0].cacheIndex = i;
}

} // namespace stu_label

