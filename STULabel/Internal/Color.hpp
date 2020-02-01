// Copyright 2017–2018 Stephan Tolksdorf

#import "Hash.hpp"
#import "TextFlags.hpp"
#import "Unretained.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

struct RGBA {
  CGFloat red, green, blue, alpha;

  explicit STU_INLINE
  RGBA(Uninitialized) {}

  static Optional<RGBA> of(UIColor* __nullable color) {
    Optional<RGBA> result{inPlace, uninitialized};
    RGBA& rgba = *result;
    if (![color getRed:&rgba.red green:&rgba.green blue:&rgba.blue alpha:&rgba.alpha]) {
      result = none;
    }
    return result;
  }
};

enum class ColorFlags : uint8_t {
  isNotGray  = 1 << 0,
  isExtended = 1 << 1,
  isClear    = 1 << 2,
  isOpaque   = 1 << 3,
  isBlack    = 1 << 4
};
constexpr int ColorFlagsBitSize = 5;

ColorFlags colorFlags(const RGBA& color);
  
ColorFlags colorFlags(UIColor* __nullable color);

ColorFlags colorFlags(CGColor* __nullable color);

} // namespace stu_label

template <> struct stu::IsOptionsEnum<stu_label::ColorFlags> : True {};

namespace stu_label {

/// color.CGColor without the mandatory autorelease of the color object in ARC code (triggered by
/// the NS_RETURNS_INNER_POINTER annotation of the CGColor getter).
CGColor* cgColor(UIColor* color);

// For our purposes it's quite convenient to use nullable color types.

class ColorRef;

class ColorBase {
protected:
  UInt taggedPointer_{};

  ColorBase() = default;

  STU_INLINE
  ColorBase(CGColor* color, ColorFlags flags)
  : taggedPointer_{reinterpret_cast<UInt>(color) | (static_cast<UInt>(flags) & 3)}
  {
    static_assert(static_cast<Int>(ColorFlags::isNotGray) == 1);
    static_assert(static_cast<Int>(ColorFlags::isExtended) == 2);
    STU_DEBUG_ASSERT((reinterpret_cast<UInt>(color) & 3) == 0);
  }

public:
  STU_INLINE_T
  explicit operator bool() const { return taggedPointer_; }

  STU_INLINE
  const ColorFlags colorFlags() const {
    return static_cast<ColorFlags>(taggedPointer_ & 3);
  }

  STU_INLINE
  const TextFlags textFlags() const {
    static_assert(static_cast<Int>(TextFlags::mayNotBeGrayscale) == (1 << 8));
    static_assert(static_cast<Int>(TextFlags::usesExtendedColor) == (1 << 9));
    return static_cast<TextFlags>(static_cast<UInt>(colorFlags()) << 8);
  }

  STU_INLINE bool isNotGray() const { return taggedPointer_ & 1; }
  STU_INLINE bool isExtended() const { return taggedPointer_ & 2; }

  STU_INLINE
  CGColor* cgColor() const {
    return reinterpret_cast<CGColor*>(taggedPointer_ & ~UInt(3));
  }

  STU_INLINE
  bool operator==(const ColorBase& other) const {
    return taggedPointer_ == other.taggedPointer_
        || CGColorEqualToColor(cgColor(), other.cgColor());
  }

  STU_INLINE
  bool operator!=(const ColorBase& other) const { return !(*this == other); }
};

/// A non-owning and nullable reference to a color.
class ColorRef : public ColorBase {
  using ColorBase::taggedPointer_;

  friend class Color;
  friend OptionalValueStorage<ColorRef>;

public:
  STU_CONSTEXPR
  ColorRef() = default;

  /* implicit */ STU_CONSTEXPR
  ColorRef(std::nullptr_t)
  : ColorBase{} {}

  STU_INLINE
  ColorRef(CGColor* color, ColorFlags flags)
  : ColorBase{color, flags}
  {}
};

/// A nullable color.
class Color : public ColorBase {
  using ColorBase::taggedPointer_;

  friend OptionalValueStorage<Color>;
public:
  STU_CONSTEXPR
  Color() = default;

  /* implicit */ STU_CONSTEXPR
  Color(std::nullptr_t)
  : ColorBase{} {}

  /* implicit */ STU_INLINE
  Color(ColorRef color)
  : ColorBase{color}
  {
    if (taggedPointer_) {
      incrementRefCount(cgColor());
    }
  }

  STU_INLINE
  Color(CGColor* color, ColorFlags flags)
  : ColorBase{color, flags}
  {
    if (color) {
      incrementRefCount(color);
    }
  }

  explicit STU_INLINE
  Color(UIColor* __unsafe_unretained color) {
    if (color) {
      *this = Color{color, stu_label::colorFlags(color)};
    }
  }

  STU_INLINE
  Color(UIColor* __unsafe_unretained color, ColorFlags flags)
  : Color{stu_label::cgColor(color), flags}
  {}

  STU_INLINE
  Color(const Color& other)
  : ColorBase{other}
  {
    if (taggedPointer_) {
      incrementRefCount(cgColor());
    }
  }
  
  STU_INLINE
  Color& operator=(const Color& other) {
    if (other.taggedPointer_) {
      incrementRefCount(other.cgColor());
    }
    if (taggedPointer_) {
      decrementRefCount(cgColor());
    }
    taggedPointer_ = other.taggedPointer_;
    return *this;
  }

  STU_INLINE
  Color(Color&& other)
  : ColorBase{other}
  {
    other.taggedPointer_ = 0;
  }

  STU_INLINE
  Color& operator=(Color&& other) {
    if (this != &other) {
      if (taggedPointer_) {
        decrementRefCount(cgColor());
      }
      taggedPointer_ = std::exchange(other.taggedPointer_, 0);
    }
    return *this;
  }

  STU_INLINE
  ~Color() {
    if (taggedPointer_) {
      decrementRefCount(cgColor());
    }
  }

  /* implicit */ STU_INLINE
  operator ColorRef() const {
    ColorRef r;
    r.taggedPointer_ = taggedPointer_;
    return r;
  }
};

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
