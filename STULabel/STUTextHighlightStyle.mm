// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextHighlightStyle-Internal.hpp"

#import "stu/Assert.h"

#import "STUTextAttributes-Internal.hpp"
#import "STUTextFrame-Internal.hpp"

#import "Internal/Equal.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"

#import "Internal/CoreGraphicsUtils.hpp"

#import "Internal/TextFrame.hpp"

using namespace stu;
using namespace stu_label;

#define FOR_ALL_FIELDS(f) \
  f(STUBackgroundAttribute*, background) \
  f(UIColor*, textColor) \
  f(UIColor*, shadowColor) \
  f(UIColor*, strokeColor) \
  f(UIColor*, underlineColor) \
  f(UIColor*, strikethroughColor) \
  f(CGSize, shadowOffset) \
  f(CGFloat, shadowBlurRadius) \
  f(CGFloat, strokeWidth) \
  f(NSUnderlineStyle, underlineStyle) \
  f(NSUnderlineStyle, strikethroughStyle) \
  f(bool, strokeButDoNotFill)

#define DEFINE_FIELD(Type, name) Type _##name;

@interface STUTextHighlightStyle() {
@package // Accessed by the Builder's initWithStyle.
  FOR_ALL_FIELDS(DEFINE_FIELD)
}
@end

@implementation STUTextHighlightStyleBuilder {
@package // Accessed by the Style's initWithBuilder.
  FOR_ALL_FIELDS(DEFINE_FIELD)
}

#undef DEFINE_FIELD

- (instancetype)init {
  return [self initWithStyle:nil];
}
- (instancetype)initWithStyle:(STUTextHighlightStyle*)style {
  if (style) {
    #define ASSIGN_FROM_STYLE(Type, name) _##name = style->_##name;
    FOR_ALL_FIELDS(ASSIGN_FROM_STYLE)
    #undef ASSIGN_FROM_STYLE
  }
  return self;
}

- (void)setStrokeWidth:(CGFloat)width
                 color:(nullable UIColor*)color
             doNotFill:(bool)doNotFill
{
  _strokeWidth = clampNonNegativeFloatInput(width);
  _strokeColor = color;
  _strokeButDoNotFill = doNotFill && _strokeWidth > 0;
}

- (void)setUnderlineStyle:(NSUnderlineStyle)style
                    color:(nullable UIColor*)color
{
  _underlineStyle = style;
  _underlineColor = color;
}

- (void)setStrikethroughStyle:(NSUnderlineStyle)style
                        color:(nullable UIColor*)color
{
  _strikethroughStyle = style;
  _strikethroughColor = color;
}

- (void)setShadowOffset:(CGSize)offset
             blurRadius:(CGFloat)blurRadius
                  color:(nullable UIColor*)color
{
  _shadowOffset.width = clampFloatInput(offset.width);
  _shadowOffset.height = clampFloatInput(offset.height);
  _shadowBlurRadius = clampNonNegativeFloatInput(blurRadius);
  _shadowColor = color;
}

@end

@implementation STUTextHighlightStyle

// Manually define getter methods, so that we don't have to declare the properties as "nonatomic".
#define DEFINE_GETTER(Type, name) - (Type)name { return _##name; }
FOR_ALL_FIELDS(DEFINE_GETTER)
#undef DEFINE_GETTER

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  if (![object isKindOfClass:STUTextHighlightStyle.class]) return false;
  STUTextHighlightStyle* const other = object;
  if (style.flagsMask != other->style.flagsMask || style.flags != other->style.flags) return false;
  #define IF_NOT_EQUAL_RETURN_FALSE(Type, name) if (!equal(_##name, other->_##name)) return false;
  FOR_ALL_FIELDS(IF_NOT_EQUAL_RETURN_FALSE)
  #undef IF_NOT_EQUAL_RETURN_FALSE
  return true;
}

- (NSUInteger)hash {
  const auto h = hash(  static_cast<UInt64>(style.flags)
                      | (static_cast<UInt64>(style.flagsMask) << 16)
                      | (static_cast<UInt64>(_underlineStyle) << 32)
                      | (static_cast<UInt64>(_strikethroughStyle) << 48),
                      _textColor);
                // Doesn't include most properties.
  return narrow_cast<NSUInteger>(h);
}

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUTextHighlightStyleBuilder*))block {
  STUTextHighlightStyleBuilder* const builder = [[STUTextHighlightStyleBuilder alloc] init];
  block(builder);
  return [self initWithBuilder:builder];
}

- (id)copyWithZone:(NSZone* __unused)zone {
  return self;
}

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUTextHighlightStyleBuilder*))block {
  STUTextHighlightStyleBuilder* const builder = [[STUTextHighlightStyleBuilder alloc]
                                                   initWithStyle:self];
  block(builder);
  return [(STUTextHighlightStyle*)[self.class alloc] initWithBuilder:builder];
}

typedef enum : int {
  textColorIndex = 0,
  underlineColorIndex,
  strikethroughColorIndex,
  shadowColorIndex,
  backgroundColorIndex,
  backgroundBorderColorIndex,
  strokeColorIndex
} IndexInColorArray;
static_assert(strokeColorIndex + 1 == ColorIndex::highlightColorCount);

template <typename OutColorIndex>
STU_INLINE
bool setColor(TextHighlightStyle::ColorArray& colors, bool checkIfClear,
              UIColor* __unsafe_unretained __nullable color, IndexInColorArray index,
              OutColorIndex outColorIndex)
{
  const ColorFlags flags = !color ? ColorFlags::isClear : colorFlags(color);
  if (!color || (checkIfClear && (flags & ColorFlags::isClear))) {
    colors[index] = nullptr;
    if constexpr (isSame<OutColorIndex, Out<Optional<ColorIndex>>>) {
      outColorIndex = none;
    } else {
      static_assert(isSame<OutColorIndex, Out<ColorIndex>>);
      outColorIndex = ColorIndex::reserved;
    }
    return false;
  }
  if (flags & ColorFlags::isBlack) {
    colors[index] = nullptr;
    outColorIndex = ColorIndex::black;
    return true;
  }
  colors[index] = Color{color, flags};
  outColorIndex = ColorIndex{narrow_cast<UInt16>(ColorIndex::highlightColorStartIndex + index)};
  return true;
}

- (instancetype)init {
  return [self initWithBuilder:nil];
}
- (instancetype)initWithBuilder:(STUTextHighlightStyleBuilder* __unsafe_unretained)builder {
  style.flagsMask = TextFlags{IntegerTraits<UnderlyingType<TextFlags>>::max};

  if (!builder) return self;

  const auto setFlags = [&](TextFlags flag, bool isPresent, bool clearIfNotPresent) {
    if (isPresent) {
      style.flags |= flag;
    } else if (!clearIfNotPresent) {
      return;
    }
    style.flagsMask &= ~flag;
  };

  auto& colors = style.colors;

  if (builder->_textColor) {
    _textColor = builder->_textColor;
    setColor(colors, false, _textColor, textColorIndex, Out{style.textColorIndex});
  }
  if (builder->_strokeColor || builder->_strokeWidth != 0) {
    _strokeColor = builder->_strokeColor;
    _strokeWidth = builder->_strokeWidth;
    const Float32 strokeWidth = narrow_cast<Float32>(_strokeWidth);
    setColor(colors, false, _strokeColor, strokeColorIndex, Out{style.info.stroke.colorIndex});
    const bool hasStroke = strokeWidth > 0;
    if (hasStroke) {
      style.info.stroke.strokeWidth = strokeWidth;
      style.info.stroke.doNotFill = builder->_strokeButDoNotFill;
    }
    setFlags(TextFlags::hasStroke, hasStroke, _strokeColor != nil);
  }
  if (builder->_underlineColor || builder->_underlineStyle) {
    _underlineColor = builder->_underlineColor;
    _underlineStyle = builder->_underlineStyle;
    style.info.underline.setStyle(_underlineStyle);
    const bool hasStyle = !!style.info.underline.style();
    const bool isNotClear = setColor(colors, true, _underlineColor, underlineColorIndex,
                                     Out{style.info.underline.colorIndex});
    const bool hasUnderline = hasStyle && (_underlineColor == nil || isNotClear);
    setFlags(TextFlags::hasUnderline, hasUnderline, hasStyle || _underlineColor);
  }
  if (builder->_strikethroughColor || builder->_strikethroughStyle) {
    _strikethroughColor = builder->_strikethroughColor;
    _strikethroughStyle = builder->_strikethroughStyle;
    style.info.strikethrough.style = _strikethroughStyle;
    const bool hasStyle = style.info.strikethrough.style != StrikethroughStyle{};
    const bool isNotClear = setColor(colors, true, _strikethroughColor, strikethroughColorIndex,
                                     Out{style.info.strikethrough.colorIndex});
    const bool hasStrikethrough = hasStyle && (_strikethroughColor == nil || isNotClear);
    setFlags(TextFlags::hasStrikethrough, hasStrikethrough, hasStyle || _strikethroughColor);
  }
  if (builder->_shadowColor || builder->_shadowBlurRadius != 0
      || builder->_shadowOffset.width != 0 || builder->_shadowOffset.height != 0)
  {
    _shadowColor = builder->_shadowColor;
    _shadowBlurRadius = builder->_shadowBlurRadius;
    _shadowOffset = builder->_shadowOffset;
    UIColor* __unsafe_unretained shadowColor = _shadowColor;
    if (!shadowColor) {
      static UIColor* defaultColor;
      static dispatch_once_t once;
      dispatch_once_f(&once, nullptr, [](void *) {
        defaultColor = [[NSShadow alloc] init].shadowColor;
        STU_DEBUG_ASSERT(defaultColor);
        if (defaultColor && ![defaultColor isKindOfClass:UIColor.class]) { // Needed for Catalyst.
          defaultColor = [UIColor colorWithCGColor:defaultColor.CGColor];
        }
      });
      shadowColor = defaultColor;
    }
    const bool isNotClear = setColor(colors, true, shadowColor, shadowColorIndex,
                                     Out{style.info.shadow.colorIndex});
    if (isNotClear) {
      style.info.shadow.offsetX = narrow_cast<Float32>(_shadowOffset.width);
      style.info.shadow.offsetY = narrow_cast<Float32>(_shadowOffset.height);
      style.info.shadow.blurRadius = narrow_cast<Float32>(_shadowBlurRadius);
    }
    setFlags(TextFlags::hasShadow, isNotClear, true);
  }
  if (builder->_background) {
    _background  = builder->_background;
    const bool hasBackground = setColor(colors, true, _background->_color,
                                        backgroundColorIndex, Out{style.info.background.colorIndex})
                            || setColor(colors, true,
                                        _background->_borderWidth == 0
                                        ? nil : _background->_borderColor,
                                        backgroundBorderColorIndex,
                                        Out{style.info.background.borderColorIndex});
    if (hasBackground) {
      style.info.background.stuAttribute = _background;
    }
    setFlags(TextFlags::hasBackground, hasBackground, _background != nil);
  }
  // Aggregate the color flags.
  TextFlags flags{style.flags};
  for (ColorRef color : style.colors) {
    flags |= color.textFlags();
  }
  style.flags = flags;
  return self;
}

@end


