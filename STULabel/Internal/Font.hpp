// Copyright 2017–2018 Stephan Tolksdorf

#import "DisplayScaleRounding.hpp"
#import "HashTable.hpp"
#import "Rect.hpp"

#import "stu/UniquePtr.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

using CTFont = RemovePointer<CTFontRef>;
using CFString = RemovePointer<CFStringRef>;

CTFont* __nonnull defaultCoreTextFont();

class FontRef {
  friend OptionalValueStorage<FontRef>;
  CTFont* font_{};
  FontRef() = default;
  friend class CachedFontInfo;
public:
  /* implicit */ STU_INLINE_T
  FontRef(UIFont* __unsafe_unretained font)
  : FontRef((__bridge CTFont*)font)
  {}

  /* implicit */ STU_INLINE_T
  FontRef(CTFont* font)
  : font_(font)
  {
    STU_DEBUG_ASSERT(font != nullptr);
  }

  STU_INLINE
  RC<CFString> familyName() const {
    return {CTFontCopyFamilyName(ctFont()), ShouldIncrementRefCount{false}};
  }

  STU_INLINE_T CTFont* __nonnull ctFont() const { return font_; }

  STU_INLINE
  CGFloat size() const { return CTFontGetSize(font_); }

  // We use the UIFont metrics here, which can differ from the CTFont ones.
  CGFloat ascent()  const { return  ((__bridge UIFont*)font_).ascender; }
  CGFloat descent() const { return -((__bridge UIFont*)font_).descender; }
  CGFloat leading() const { return  ((__bridge UIFont*)font_).leading; }
  CGFloat xHeight()   const { return ((__bridge UIFont*)font_).xHeight; }
  CGFloat capHeight() const { return ((__bridge UIFont*)font_).capHeight; }
};

} // namespace stu_label

template <>
class stu::OptionalValueStorage<stu_label::FontRef> {
public:
  stu_label::FontRef value_{};
  STU_INLINE bool hasValue() const noexcept { return value_.font_ != nullptr; }
  STU_INLINE void clearValue() noexcept { value_.font_ = nullptr; }
  STU_INLINE void constructValue(stu_label::FontRef value) { value_ = value; }
};

namespace stu_label {

class CachedFontInfo;

class FontMetrics {
  CGFloat ascent_;
  CGFloat descent_;
  Float64 ascentPlusHalfLeading_;
  Float64 descentPlusHalfLeading_;
public:
  STU_CONSTEXPR CGFloat ascent() const { return ascent_; }
  STU_CONSTEXPR CGFloat descent() const { return descent_; }

  STU_CONSTEXPR
  CGFloat leading() const {
    return narrow_cast<CGFloat>(2*max(ascentPlusHalfLeading_ - ascent_,
                                      descentPlusHalfLeading_ - descent_));
  }

  STU_CONSTEXPR_T
  FontMetrics() : ascent_{}, descent_{}, ascentPlusHalfLeading_{}, descentPlusHalfLeading_{} {}

  STU_CONSTEXPR_T
  FontMetrics(CGFloat ascent, CGFloat descent, CGFloat leading = 0)
  : ascent_{ascent},
    descent_{descent},
    ascentPlusHalfLeading_{ascent + leading/2},
    descentPlusHalfLeading_{descent + leading/2}
  {}

  explicit FontMetrics(Uninitialized) {}

  STU_CONSTEXPR
  void adjustByBaselineOffset(Float32 baselineOffset) {
    ascent_  = ascent_  + baselineOffset;
    descent_ = descent_ - baselineOffset;
    ascentPlusHalfLeading_  = ascentPlusHalfLeading_  + baselineOffset;
    descentPlusHalfLeading_ = descentPlusHalfLeading_ - baselineOffset;
  }

  [[nodiscard]] STU_CONSTEXPR
  FontMetrics adjustedByBaselineOffset(Float32 baselineOffset) const {
    FontMetrics result{*this};
    result.adjustByBaselineOffset(baselineOffset);
    return result;
  }

  STU_CONSTEXPR
  void aggregate(const FontMetrics& other) {
    ascent_ = max(ascent_, other.ascent_);
    ascentPlusHalfLeading_ = max(ascentPlusHalfLeading_,  other.ascentPlusHalfLeading_);
    descent_ = max(descent_, other.descent_);
    descentPlusHalfLeading_ = max(descentPlusHalfLeading_, other.descentPlusHalfLeading_);
  }

private:
  FontMetrics(FontRef);
  friend CachedFontInfo;
};

struct MinFontMetrics {
  CGFloat minAscentPlusDescent;
  CGFloat maxAscentPlusDescent;
  CGFloat minDescent;
  CGFloat minLeading;

  explicit MinFontMetrics(Uninitialized) {}

  /* implicit */ STU_CONSTEXPR
  MinFontMetrics(const FontMetrics& metrics)
  : minAscentPlusDescent{metrics.ascent() + metrics.descent()},
    maxAscentPlusDescent{minAscentPlusDescent},
    minDescent{metrics.descent()},
    minLeading{metrics.leading()}
  {}

  STU_CONSTEXPR
  void aggregate(const FontMetrics& other) {
    const CGFloat otherAscentPlusDescent = other.ascent() + other.descent();
    minAscentPlusDescent = min(minAscentPlusDescent, otherAscentPlusDescent);
    maxAscentPlusDescent = max(maxAscentPlusDescent, otherAscentPlusDescent);
    minDescent = min(minDescent, other.descent());
    minLeading = min(minLeading, other.leading());
  }

  STU_CONSTEXPR
  void aggregate(const MinFontMetrics& other) {
    minAscentPlusDescent = min(minAscentPlusDescent, other.minAscentPlusDescent);
    maxAscentPlusDescent = min(maxAscentPlusDescent, other.maxAscentPlusDescent);
    minDescent = min(minDescent, other.minDescent);
    minLeading = min(minLeading, other.minLeading);
  }
};

class CachedFontInfo {
public:
  FontMetrics metrics;
  Float32 xHeight;
  Float32 capHeight;
  Range<Float32> yBoundsLLO;
private:
  Float32 underlineMinY_;
public:
  Float32 underlineThickness;
  Float32 strikethroughThickness;
private:
  bool underlineMinYIsStrict_;
public:
  bool hasColorGlyphs; // Color bitmap or SVG font
  bool shouldBeIgnoredInSecondPassOfLineMetricsCalculation;
  bool shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont;

  static CachedFontInfo get(FontRef);

  /* implicit */ CachedFontInfo(Uninitialized) {}

  struct UnderlineMinY {
    Float32 value;
    bool isStrict;

    STU_CONSTEXPR
    const Float32 operator()(const Optional<DisplayScale>& displayScale) const {
      if (STU_LIKELY(!isStrict)) return value;
      return value + (displayScale ? displayScale->inverseValue_f32() : 0.5f);
    }
  };

  STU_CONSTEXPR
  UnderlineMinY underlineMinY() const {
    return UnderlineMinY{underlineMinY_, underlineMinYIsStrict_};
  }

  /// The minimum offset from the baseline to the top of an underline.
  /// The returned value includes at least 1/displayScale "wiggle room".
  STU_CONSTEXPR
  Float32 underlineMinY(const Optional<DisplayScale>& displayScale) const {
    return underlineMinY()(displayScale);
  }

private:
  CachedFontInfo(FontRef);
};

class LocalFontInfoCache {
public:
  STU_INLINE
  const CachedFontInfo& operator[](FontRef font) {
    return (*this)[font.ctFont()];
  }
  STU_INLINE
  const CachedFontInfo& operator[](CTFont* __nonnull font) {
    // TODO: Replace this with a simple LRU cache like in LocalGlyphBoundsCache::glyphBoundsCache.
    UInt index = (  (font == fonts_[0] ? 1 : 0)
                  | (font == fonts_[1] ? 2 : 0))
               | (  (font == fonts_[2] ? 3 : 0)
                  | (font == fonts_[3] ? 4 : 0));
    if (STU_LIKELY(index != 0)) {
      return infos_[index - 1];
    }
    index = counter_%4;
    counter_ += 1;
    fonts_[index] = font;
    infos_[index] = CachedFontInfo::get(font);
    return infos_[index];
  }

private:
  CTFont* fonts_[4] = {};
  UInt counter_{};
  CachedFontInfo infos_[4] = {uninitialized, uninitialized, uninitialized, uninitialized};
};

class GlyphsWithPositions {
public:
  Int count() const { return count_; }
  ArrayRef<const CGGlyph> glyphs() const { return {glyphs_, count_, unchecked}; }
  ArrayRef<const CGPoint> positions() const { return {positions_, count_, unchecked}; }

private:
  friend class GlyphSpan;

  STU_INLINE_T
  GlyphsWithPositions()
  : buffer_{}, count_{}, glyphs_{}, positions_{} {}

  STU_INLINE
  GlyphsWithPositions(Optional<TempArray<Byte>>&& buffer,
                      Int count, const CGGlyph* glyphs, const CGPoint* positions)
  : buffer_{std::move(buffer)}, count_{count}, glyphs_{glyphs}, positions_{positions}
  {}

  Optional<TempArray<Byte>> buffer_;
  Int count_;
  const CGGlyph* glyphs_;
  const CGPoint* positions_;
};

class FontFaceGlyphBoundsCache {
public:
  struct FontFace {
    // The glyph bounds of Core Text fonts with the same graphics font scale linearly with the font
    // size, except for the AppleColorEmoji and .AppleColorEmojiUI fonts (or all color bitmap
    // fonts?), which are scaled and translated in a piecewise linear way. Since the way the emoji
    // glyph bounds are transformed may change in the future, we make the font size a part of the
    // identity of the emoji font face.

    RC<CGFont> cgFont;
    CGFloat appleColorEmojiSize;
    CGAffineTransform fontMatrix;
    bool fontMatrixIsIdentity;
    /// Indicates whether cgFont is the 'AppleColorEmoji' or '.AppleColorEmojiUI' font.
    bool isAppleColorEmoji;
    /// Indicates whether cgFont is the '.AppleColorEmojiUI' font.
    bool isAppleColorEmojiUI;

    /// @pre `fontSize == font.size()`
    explicit FontFace(FontRef font, CGFloat fontSize)
    : cgFont{CTFontCopyGraphicsFont(font.ctFont(), nullptr), ShouldIncrementRefCount{false}},
      fontMatrix{CTFontGetMatrix(font.ctFont())},
      fontMatrixIsIdentity{fontMatrix == CGAffineTransformIdentity}
    {
      STU_DEBUG_ASSERT(fontSize == font.size());
      RC<CFString> name{CTFontCopyPostScriptName(font.ctFont()), ShouldIncrementRefCount{false}};
      const Int nameLength = CFStringGetLength(name.get());
      isAppleColorEmoji = false;
      isAppleColorEmojiUI = false;
      if (nameLength == 18) {
        isAppleColorEmojiUI = CFEqual(name.get(), (__bridge CFString*)@".AppleColorEmojiUI");
        isAppleColorEmoji = isAppleColorEmojiUI;
      } else if (nameLength == 15) {
        isAppleColorEmoji = CFEqual(name.get(), (__bridge CFString*)@"AppleColorEmoji");
      }
      appleColorEmojiSize = isAppleColorEmoji ? fontSize : 0;
    }

    HashCode<UInt> hash();

    friend bool operator==(const FontFace& lhs, const FontFace& rhs) {
      return lhs.cgFont == rhs.cgFont
          && lhs.appleColorEmojiSize == rhs.appleColorEmojiSize
          && lhs.fontMatrixIsIdentity == rhs.fontMatrixIsIdentity
          && (lhs.fontMatrixIsIdentity || lhs.fontMatrix == rhs.fontMatrix);
    }
    friend bool operator!=(const FontFace& lhs, const FontFace& rhs) {
      return !(lhs == rhs);
    }
  };

  /// A non-owning reference.
  struct Ref {
    FontFaceGlyphBoundsCache& cache;
    const CGFloat fontSize;

    Rect<CGFloat> boundingRect(ArrayRef<const CGGlyph> glyphs, const CGPoint* positions) const {
      return cache.boundingRect(fontSize, glyphs, positions);
    }

    Rect<CGFloat> boundingRect(CGGlyph glyph, CGPoint position) const {
      return cache.boundingRect(fontSize, ArrayRef{&glyph, 1}, &position);
    }
  };

private:
  static void returnToGlobalPool(FontFaceGlyphBoundsCache* __nonnull) noexcept;
public:
  using UniquePtr = stu::UniquePtr<FontFaceGlyphBoundsCache, returnToGlobalPool>;

  /// Transfers ownership. Don't dereference the pointers after returning them to the pool!
  ///
  /// Thread-safe (for nonoverlapping array arguments).
  static void returnToGlobalPool(ArrayRef<FontFaceGlyphBoundsCache* __nullable const>);

  /// Exchanges the cache with one that holds glyph bounds for the specified font.
  /// The caller relinquishes the ownership of the nullable old cache and assumes ownership for the
  /// nonnull new one (via the @c UniquePtr).
  ///
  /// @pre `fontFace == FontFace(font)`
  ///
  /// Thread-safe (for different cache and fontface arguments).
  static void exchange(InOut<UniquePtr> cache, FontRef font, FontFace&& fontFace);

  const FontFace& fontFace() const;

  Rect<CGFloat> boundingRect(CGFloat fontSize, ArrayRef<const CGGlyph> glyphs,
                             const CGPoint* positions);

  /// For testing purposes.
  bool usesIntBounds() const { return usesIntBounds_; }

#if STU_DEBUG
  void setMaxIntBoundsCountToTestFallbacktToFloatBounds(Int maxCount) {
    maxIntBoundsCount_ = maxCount;
  }
#endif

  /// Thread-safe.
  static void clearGlobalCache();

private:
  friend Malloced<FontFaceGlyphBoundsCache>;

  friend class GlyphBoundsCache;
  struct Pool;

  FontFaceGlyphBoundsCache(const FontFaceGlyphBoundsCache&) = delete;
  FontFaceGlyphBoundsCache& operator==(const FontFaceGlyphBoundsCache&) = delete;

  ~FontFaceGlyphBoundsCache();

  /// @pre usesIntBounds_
  void switchToFloatBounds();

  struct GlyphHasher {
    STU_INLINE static HashCode<UInt32> hash(CGGlyph glyph) {
      UInt32 value = glyph;
      // This is the hash function used by Skia, see SkChecksum::CheapMix.
      value *= 0x85ebca6b;
      value ^= value >> 16;
      return HashCode{value};
    }
  };

  struct InitData {
    Pool& pool;
    FontRef font;
    CGFloat unitsPerEM;
    CGFloat pointsPerUnit;
    CGPoint offset;
    bool isAppleColorEmoji;
    bool useIntBounds;

    InitData(Pool&);
  };

  explicit FontFaceGlyphBoundsCache(Pool& pool)
  : FontFaceGlyphBoundsCache{InitData{pool}} {}

  explicit FontFaceGlyphBoundsCache(InitData data);
  
  Pool& pool_;
  const FontRef font_;
  const CGFloat unitsPerEM_;
  /// effectiveFontSize/unitsPerEM_ if usesIntBounds_ || !isAppleColorEmoji_ else 1
  CGFloat pointsPerUnit_;
  /// 1/pointPerUnit_
  CGFloat inversePointsPerUnit_;
  /// Is zero if !isAppleColorEmoji_ || !usesIntBounds_
  Point<CGFloat> scaledIntBoundsOffset_;
  const bool isAppleColorEmoji_;
  bool usesIntBounds_;
#if STU_DEBUG
  /// Only used for testing the fallback to float bounds.
  Int maxIntBoundsCount_{maxValue<Int>};
#endif

  union {
    HashTable<CGGlyph, Rect<Int16>, Malloc, GlyphHasher> intBoundsByGlyphIndex_;
    HashTable<CGGlyph, Rect<Float32>, Malloc, GlyphHasher> floatBoundsByGlyphIndex_;
    Int uninitialized_{};
  };
};

class LocalGlyphBoundsCache {
public:
  /// The returned reference is only guaranteed to be valid until the next call to a method of this
  /// class.
  FontFaceGlyphBoundsCache::Ref glyphBoundsCache(FontRef);

  Rect<CGFloat> boundingRect(FontRef font, const GlyphsWithPositions& gwp) {
     return glyphBoundsCache(font).boundingRect(gwp.glyphs(), gwp.positions().begin());
  }

#if STU_DEBUG
  void checkInvariants();
#endif

  ~LocalGlyphBoundsCache() {
    if (caches_[0]) {
      FontFaceGlyphBoundsCache::returnToGlobalPool(ArrayRef{caches_});
    }
  }

private:
  void glyphBoundsCacheFor_slowPath(FontRef);

  struct Entry {
    CTFont* font;
    CGFloat fontSize;
    UInt cacheIndex;

    explicit operator bool() const { return font != nullptr; }
  };

  static constexpr Int entryCount = 3;

  Entry entries_[entryCount] = {};
  FontFaceGlyphBoundsCache* caches_[entryCount] = {};
};

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
