// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

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
  FontRef(UIFont* __unsafe_unretained font) : font_((__bridge CTFont*)font) {}

  /* implicit */ STU_INLINE_T
  FontRef(CTFont* font) : font_(font) {}

  STU_INLINE
  RC<NSString> familyName() const {
    return {(__bridge NSString*)CTFontCopyFamilyName(ctFont()), ShouldIncrementRefCount{false}};
  }

  STU_INLINE_T CTFont* __nonnull ctFont() const { return font_; }

  // We use the UIFont metrics here, which may differ from the CTFont ones.
  CGFloat ascent()  const { return  ((__bridge UIFont*)font_).ascender; }
  CGFloat descent() const { return -((__bridge UIFont*)font_).descender; }
  CGFloat leading() const { return  ((__bridge UIFont*)font_).leading; }
  CGFloat xHeight()   const { return ((__bridge UIFont*)font_).xHeight; }
  CGFloat capHeight() const { return ((__bridge UIFont*)font_).capHeight; }

  STU_INLINE
  bool operator==(FontRef other) const {
    return font_ == other.font_ || CFEqual(font_, other.font_);
  }

  STU_INLINE bool operator!=(FontRef other) const { return !(*this == other); }
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

  STU_INLINE
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

  MinFontMetrics(CGFloat ascent, CGFloat descent, CGFloat leading = 0)
  : ascentPlusDescent{narrow_cast<Float32>(ascent + descent)},
    descent{narrow_cast<Float32>(descent)},
    leading{narrow_cast<Float32>(leading)}
  {}

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

  STU_INLINE
  void aggregate(const FontMetrics& other) {
    ascentPlusDescent = min(ascentPlusDescent, other.ascent() + other.descent());
    descent = min(descent, other.descent());
    leading = min(leading, other.leading());
  }

  STU_INLINE
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

  static void clearCache();
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


} // namespace stu_label

