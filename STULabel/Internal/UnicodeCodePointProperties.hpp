// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

#import <CoreFoundation/CoreFoundation.h>

namespace stu_label {

constexpr stu::Char16 minSurrogateCodeUnit = 0xD800;

STU_CONSTEXPR
bool isSurrogate(stu::Char32 c) { return (c & 0xFFFFF800) == 0xD800; }

STU_CONSTEXPR
bool isHighSurrogate(stu::Char32 c) { return (c & 0xFFFFFC00) == 0xD800; }

STU_CONSTEXPR
bool isLowSurrogate(stu::Char32 c) { return (c & 0xFFFFFC00) == 0xDC00; }

STU_CONSTEXPR
stu::Char32 codePointFromSurrogatePair(stu::Char16 highSurrogate, stu::Char16 lowSurrogate) {
  return static_cast<stu::Char32>(lowSurrogate)
       - ((0xD800 << 10) + 0xDC00 - 0x10000)
       + (static_cast<stu::Char32>(highSurrogate) << 10) ;
}

constexpr bool isLineTerminator(stu::Char16 c) {
  return (0xA <= c && c <= 0xD) || (0x2028 <= c && c <= 0x2029) || c == 0x85;
}

constexpr bool isRegionalIndicator(stu::Char32 cp) {
  return 0x1F1E6 <= cp && cp <= 0x1F1FF;
}

enum class BidiStrongType : UInt8 {
  none,
  ltr,     ///< Bidi type L
  rtl,     ///< Bidi type R or AL
  isolate, ///< Bidi type LRI, RLI, FSI or PDI
};

enum class GraphemeClusterCategory : UInt8 {
  other,
  controlCR,
  controlLF,
  controlOther,
  prepend,
  spacingMark,
  extend,
  zwj,
  regionalIndicator,
  extendedPictographic,
  hangulLVT,
  hangulLV,
  hangulL,
  hangulV,
  hangulT
};
constexpr int graphemeClusterCategoryCount = (int)GraphemeClusterCategory::hangulT + 1;

struct CodePointProperties {
  stu::UInt8 bits;

  CodePointProperties() = default;

  STU_INLINE
  explicit CodePointProperties(stu::Char32 codePoint) {
    if (STU_LIKELY(codePoint < 0xD800)) {
      const stu::UInt i0 = codePoint >> 4;
      const stu::UInt i1 = (codePoint & 15) + (static_cast<stu::UInt>(indices[i0]) << 4);
      bits = data1[i1];
    } else {
      bits = lookupCodePointGreaterThanD7FF(codePoint);
    }
  }

  STU_INLINE
  BidiStrongType bidiStrongType() const {
    return BidiStrongType(bits & 0x3);
  }

  STU_INLINE
  bool isIgnorable() const { return bits & (1 << 2); }

  STU_INLINE
  bool isWhitespace() const { return bits & (1 << 3); }

  STU_INLINE
  bool isIgnorableOrWhitespace() const { return bits & (0x3 << 2); }

  STU_INLINE
  GraphemeClusterCategory graphemeClusterCategory() const {
    return GraphemeClusterCategory(bits >> 4);
  }

private:
  static stu::UInt8 lookupCodePointGreaterThanD7FF(stu::Char32 codePoint) noexcept
                 __attribute__((const));

  static const stu::UInt8 indices[3456];
  static const stu::UInt8 data1[3904];
  static const stu::UInt8 indices1[592];
  static const stu::UInt8 indices2[1312];
  static const stu::UInt8 data2[1312];
};

inline GraphemeClusterCategory graphemeClusterCategory(stu::Char32 cp) {
  return CodePointProperties{cp}.graphemeClusterCategory();
}

inline bool isUnicodeWhitespace(stu::Char32 cp) noexcept {
  return CodePointProperties{cp}.isWhitespace();
}

inline bool isNotIgnorableAndNotWhitespace(stu::Char32 cp) noexcept {
  return CodePointProperties{cp}.isIgnorableOrWhitespace() == false;
}

inline bool isNotIgnorable(stu::Char32 cp) noexcept {
  return CodePointProperties{cp}.isIgnorable() == false;
}

inline BidiStrongType bidiStrongType(stu::Char32 cp) noexcept {
  return CodePointProperties{cp}.bidiStrongType();
}

} // namespace stu_label
