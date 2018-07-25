// Copyright 2017–2018 Stephan Tolksdorf

#import "HashTable.hpp"
#import "Rect.hpp"

#import "stu/UniquePtr.hpp"

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
  RC<NSString> familyName() const {
    return {(__bridge NSString*)CTFontCopyFamilyName(ctFont()), ShouldIncrementRefCount{false}};
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
  Float32 ascent_;
  Float32 descent_;
  Float32 ascentPlusHalfLeading_;
  Float32 descentPlusHalfLeading_;
public:
  STU_CONSTEXPR Float32 ascent() const { return ascent_; }
  STU_CONSTEXPR Float32 descent() const { return descent_; }

  STU_CONSTEXPR
  Float32 leading() const {
    return 2*max(ascentPlusHalfLeading_ - ascent_, descentPlusHalfLeading_ - descent_);
  }

  STU_CONSTEXPR_T
  FontMetrics() : ascent_{}, descent_{}, ascentPlusHalfLeading_{}, descentPlusHalfLeading_{} {}

  STU_CONSTEXPR_T
  FontMetrics(CGFloat ascent, CGFloat descent, CGFloat leading = 0)
  : ascent_{narrow_cast<Float32>(ascent)},
    descent_{narrow_cast<Float32>(descent)},
    ascentPlusHalfLeading_{narrow_cast<Float32>(ascent + leading/2)},
    descentPlusHalfLeading_{narrow_cast<Float32>(descent + leading/2)}
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
  Float32 ascentPlusDescent;
  Float32 descent;
  Float32 leading;

private:
  explicit MinFontMetrics(Uninitialized) {}

public:
  static MinFontMetrics infinity() {
    MinFontMetrics result{uninitialized};
    result.ascentPlusDescent = stu::infinity<Float32>;
    result.descent = stu::infinity<Float32>;
    result.leading = stu::infinity<Float32>;
    return result;
  }

  STU_CONSTEXPR
  void aggregate(const FontMetrics& other) {
    ascentPlusDescent = min(ascentPlusDescent, other.ascent() + other.descent());
    descent = min(descent, other.descent());
    leading = min(leading, other.leading());
  }

  STU_CONSTEXPR
  void aggregate(const MinFontMetrics& other) {
    ascentPlusDescent = min(ascentPlusDescent, other.ascentPlusDescent);
    descent = min(descent, other.descent);
    leading = min(leading, other.leading);
  }
};

class CachedFontInfo {
public:
  FontMetrics metrics;
  Float32 xHeight;
  Float32 capHeight;
  Range<Float32> yBoundsLLO;
  Float32 underlineOffset;
  Float32 underlineThickness;
  Float32 strikethroughThickness;
  bool hasColorGlyphs;
  bool shouldBeIgnoredInSecondPassOfLineMetricsCalculation;
  bool shouldBeIgnoredForDecorationLineThicknessWhenUsedAsFallbackFont;

  static CachedFontInfo get(FontRef);

  /* implicit */ CachedFontInfo(Uninitialized) {}

private:
  CachedFontInfo(FontRef);
};

class LocalFontInfoCache {
public:
  STU_INLINE
  const CachedFontInfo& operator[](CTFont* __nonnull font) {
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
    RC<CGFont> cgFont;
    CGAffineTransform fontMatrix;
    bool fontMatrixIsIdentity;

    explicit FontFace(FontRef font)
    : cgFont{CTFontCopyGraphicsFont(font.ctFont(), nullptr), ShouldIncrementRefCount{false}},
      fontMatrix{CTFontGetMatrix(font.ctFont())},
      fontMatrixIsIdentity{fontMatrix == CGAffineTransformIdentity}
    {}

    HashCode<UInt> hash();

    friend bool operator==(const FontFace& lhs, const FontFace& rhs) {
      return lhs.cgFont == rhs.cgFont
          && lhs.fontMatrixIsIdentity == rhs.fontMatrixIsIdentity
          && (lhs.fontMatrixIsIdentity || lhs.fontMatrix == rhs.fontMatrix);
    }
    friend bool operator!=(const FontFace& lhs, const FontFace& rhs) {
      return !(lhs == rhs);
    }
  };

  struct Ref {
    FontFaceGlyphBoundsCache& cache;
    const CGFloat fontSize;

    Rect<CGFloat> boundingRectFor(ArrayRef<const CGGlyph> glyphs, const CGPoint* positions) const {
      return cache.boundingRectFor(fontSize, glyphs, positions);
    }

    Rect<CGFloat> boundingRectFor(CGGlyph glyph, CGPoint position) const {
      return cache.boundingRectFor(fontSize, ArrayRef{&glyph, 1}, &position);
    }
  };

private:
  static void returnToGlobalPool(FontFaceGlyphBoundsCache* __nonnull) noexcept;
public:
  using UniquePtr = stu::UniquePtr<FontFaceGlyphBoundsCache, returnToGlobalPool>;

  /// @pre `fontFace == FontFace(font)`
  static void exchange(InOut<UniquePtr>, FontRef font, FontFace&& fontFace);

  const FontFace& fontFace() const;

  Rect<CGFloat> boundingRectFor(CGFloat fontSize,
                                ArrayRef<const CGGlyph> glyphs,
                                const CGPoint* positions);

private:
  friend Malloced<FontFaceGlyphBoundsCache>;

  friend class GlyphBoundsCache;
  struct Pool;

  FontFaceGlyphBoundsCache(const FontFaceGlyphBoundsCache&) = delete;
  FontFaceGlyphBoundsCache& operator==(const FontFaceGlyphBoundsCache&) = delete;

  explicit FontFaceGlyphBoundsCache(Pool& entry);

  ~FontFaceGlyphBoundsCache();

  struct GlyphHasher {
    STU_INLINE static HashCode<UInt32> hash(CGGlyph glyph) {
      UInt32 value = glyph;
      // This is the hash function used by Skia, see SkChecksum::CheapMix.
      value *= 0x85ebca6b;
      value ^= value >> 16;
      return HashCode{value};
    }
  };

  Pool& pool_;
  FontRef const font_;
  CGFloat const fontSize_;
  CGFloat const unitsPerEM_;
  CGFloat const unitPerPoint_;
  CGFloat const pointPerUnit_;
  bool usesIntBounds_;
  union {
    HashTable<CGGlyph, Rect<Int16>, Malloc, GlyphHasher> intBoundsByGlyphIndex_;
    HashTable<CGGlyph, Rect<Float32>, Malloc, GlyphHasher> floatBoundsByGlyphIndex_;
    Int uninitialized_{};
  };
};

class LocalGlyphBoundsCache {
public:
  struct
  /// The returned reference is only guranteed to be valid until the next call to a method of this
  /// class.
  FontFaceGlyphBoundsCache::Ref glyphBoundsCacheFor(FontRef);

  Rect<CGFloat> boundingRectFor(FontRef font, const GlyphsWithPositions& gwp) {
     return glyphBoundsCacheFor(font).boundingRectFor(gwp.glyphs(), gwp.positions().begin());
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
  FontFaceGlyphBoundsCache::UniquePtr caches_[entryCount];
};

} // namespace stu_label

