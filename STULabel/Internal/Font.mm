// Copyright 2017–2018 Stephan Tolksdorf

#import "Font.hpp"

#import "STULabel/stu_mutex.h"

#import "Hash.hpp"
#import "HashSet.hpp"
#import "Once.hpp"
#import "Rect.hpp"

#import "stu/ScopeGuard.hpp"
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
    UInt hashCode; // hash(CFHash(font.ctFont()))
    CachedFontInfo info;
  };

  Vector<Entry> entries;
  UIntHashSet<UInt16, Malloc> indicesByFontPointer{uninitialized};
  UIntHashSet<UInt16, Malloc> indicesByHashIdentity{uninitialized};
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

void CachedFontInfo::clearCache() {
  STU_ASSERT(!stu_mutex_trylock(&fontInfoCacheMutex) && "fontInfoCacheMutex must already be locked");
  STU_ASSERT(fontInfoCacheIsInitialized);
  FontInfoCache& cache = reinterpret_cast<FontInfoCache&>(fontInfoCacheStorage);
  for (auto& entry : cache.entries.reversed()) {
    decrementRefCount((__bridge UIFont*)entry.font.ctFont());
  }
  cache.entries.removeAll();
  cache.indicesByFontPointer.removeAll();
  cache.indicesByHashIdentity.removeAll();
}

CachedFontInfo CachedFontInfo::get(FontRef font) {
  const size_t pointerHashCode = narrow_cast<size_t>(hashPointer(font.ctFont()));
  stu_mutex_lock(&fontInfoCacheMutex);
  if (STU_UNLIKELY(!fontInfoCacheIsInitialized)) {
    fontInfoCacheIsInitialized = true;
    new (fontInfoCacheStorage) FontInfoCache{};
    FontInfoCache& cache = reinterpret_cast<FontInfoCache&>(fontInfoCacheStorage);
    cache.indicesByFontPointer.initializeWithBucketCount(16);
    cache.indicesByHashIdentity.initializeWithBucketCount(16);
    cache.entries.ensureFreeCapacity(8);

    NSNotificationCenter* const notificationCenter = NSNotificationCenter.defaultCenter;
    NSOperationQueue* const mainQueue = NSOperationQueue.mainQueue;
    const auto clearCacheBlock = ^(NSNotification*) {
      stu_mutex_lock(&fontInfoCacheMutex);
      clearCache();
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

  const UInt hashCode = narrow_cast<UInt>(hash(CFHash(font.ctFont())));
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
    clearCache();
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

} // namespace stu_label

