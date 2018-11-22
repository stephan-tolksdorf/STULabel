// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUTextFrame-Unsafe.h"

#import "STULabel/STUTextHighlightStyle-Internal.hpp"

#import "CancellationFlag.hpp"
#import "DisplayScaleRounding.hpp"
#import "GlyphSpan.hpp"
#import "Once.hpp"
#import "TextFrame.hpp"
#import "TextFrameDrawingOptions.hpp"
#import "TextStyle.hpp"
#import "ThreadLocalAllocator.hpp"

namespace stu_label {

class DrawingContext {
public:
  struct ColorIndices {
    ColorIndex fillColorIndex;
    ColorIndex strokeColorIndex;
  };

  STU_INLINE_T
  CGContext* __nonnull const cgContext() const { return cgContext_; }

  STU_INLINE_T
  const Optional<DisplayScale>& displayScale() const { return displayScale_; }

  STU_INLINE_T
  const Optional<DisplayScale>& textFrameDisplayScale() const { return textFrameDisplayScale_; }

  bool hasCancellationFlag() const {
    return &cancellationFlag_ != &CancellationFlag::neverCancelledFlag;
  }

  STU_INLINE
  bool isCancelled() const { return STUCancellationFlagGetValue(&cancellationFlag_); }

  STU_INLINE_T const Rect<CGFloat>& clipRect() const { return clipRect_; }

  STU_INLINE_T Optional<TextStyleOverride&> styleOverride() const { return styleOverride_; }

  CGColor* cgColor(ColorIndex colorIndex);

  STU_INLINE
  const CachedFontInfo& fontInfo(CTFont* __nonnull font) { return fontInfoCache_[font]; }

  STU_INLINE
  LocalFontInfoCache& fontInfoCache() { return fontInfoCache_; }

  STU_INLINE
  LocalGlyphBoundsCache& glyphBoundsCache() {
    if (STU_UNLIKELY(!glyphBoundsCache_)) {
      initializeGlyphBoundsCache();
      glyphBoundsCache_.assumeNotNone();
    }
    return *glyphBoundsCache_;
  }

  STU_INLINE
  void setFillColor(ColorIndex index) {
    if (colorIndices_.fillColorIndex == index) return;
    colorIndices_.fillColorIndex = index;
    CGContextSetFillColorWithColor(cgContext_, cgColor(index));
  }

  void setStrokeColor(ColorIndex index) {
    if (colorIndices_.strokeColorIndex == index) return;
    colorIndices_.strokeColorIndex = index;
    CGContextSetStrokeColorWithColor(cgContext_, cgColor(index));
  }

  void currentCGContextColorsMayHaveChanged() {
    colorIndices_ = reservedColorIndices;
  }

  ColorIndices currentColorIndices() const { return colorIndices_; }

  void restoreColorIndicesAfterCGContextRestoreGState(ColorIndices oldIndices) {
    colorIndices_ = oldIndices;
  }

  class ShadowOnlyDrawingScope {
    DrawingContext* context_;
  public:
    explicit STU_INLINE
    ShadowOnlyDrawingScope(DrawingContext& context)
    : context_(&context)
    {
      if (context_->shadowOnlyScopeCount_++ == 0) {
        CGContextTranslateCTM(context_->cgContext_, -context_->offCanvasShadowExtraXOffset_, 0);
        context_->setShadow(nullptr);
      }
    }

    ShadowOnlyDrawingScope(ShadowOnlyDrawingScope&& other)
    : context_{std::exchange(other.context_, nullptr)} {}

    ShadowOnlyDrawingScope(const ShadowOnlyDrawingScope&) = delete;
    ShadowOnlyDrawingScope& operator=(const ShadowOnlyDrawingScope&) = delete;

    STU_INLINE
    ~ShadowOnlyDrawingScope() {
      if (context_ && --context_->shadowOnlyScopeCount_ == 0) {
        CGContextTranslateCTM(context_->cgContext_, context_->offCanvasShadowExtraXOffset_, 0);
        context_->setShadow(nullptr);
      }
    }
  };

  void setShadow(const TextStyle::ShadowInfo* __nullable shadowInfo) {
    if (shadowInfo_ == shadowInfo) return;
    setShadow_slowPath(shadowInfo);
  }

  class TextFrameLineDrawingScope {
    DrawingContext* context_;
    const Optional<TextStyleOverride&> originalStyleOverride_;

    friend DrawingContext;

    TextFrameLineDrawingScope(DrawingContext& context,
                              Optional<TextStyleOverride&> originalStyleOverride)
    : context_(&context), originalStyleOverride_(originalStyleOverride)
    {}

    TextFrameLineDrawingScope(const TextFrameLineDrawingScope&) = delete;

  public:
    TextFrameLineDrawingScope(TextFrameLineDrawingScope&& other)
    : context_(std::exchange(other.context_, nullptr)),
      originalStyleOverride_(other.originalStyleOverride_)
    {}

    ~TextFrameLineDrawingScope() {
      if (context_) {
        context_->styleOverride_ = originalStyleOverride_;
        context_->textFrameLine_ = none;
      }
    }
  };

  void invertYAxis() {
    CGContextScaleCTM(cgContext_, 1, -1);
    clipRect_.y *= -1;
  }

  Optional<TextFrameLineDrawingScope> enterLineDrawingScope(const TextFrameLine& line) {
    STU_ASSERT(!textFrameLine_);
    TextFlags flags = line.textFlags();
    const Optional<TextStyleOverride&> styleOverride = styleOverride_;
    if (styleOverride) {
      const Range<TextFrameCompactIndex> range = line.range();
      if (styleOverride->overrideRange.overlaps(range)) {
        if (styleOverride->overrideRange.contains(range)) {
          flags &= styleOverride->flagsMask;
        }
        flags |= styleOverride->flags;
      } else {
        if (!styleOverride->drawnRange.overlaps(range)) return none;
        if (styleOverride->drawnRange.contains(range)) {
          styleOverride_ = none; // Will be restored by ~TextFrameLineDrawingScope.
        }
      }
    }
    textFrameLine_ = Optional<const TextFrameLine&>{line};
    effectiveLineFlags_ = flags;
    return TextFrameLineDrawingScope(*this, styleOverride);
  }

  Float64 ctmYOffset() const {
    return ctmYOffset_;
  }

  CGPoint textFrameOrigin() const {
    return textFrameOrigin_;
  }

  CGPoint lineOrigin() const {
    STU_DEBUG_ASSERT(textFrameLine_);
    return lineOrigin_;
  }
  void setLineOrigin(CGPoint origin) {
    lineOrigin_ = origin;
  }

  TextFlags effectiveLineFlags() const {
    STU_DEBUG_ASSERT(textFrameLine_);
    return effectiveLineFlags_;
  }

  TextFlags textFlagsNecessitatingDirectGlyphDrawingOfNonHighlightedText() const {
    return directGlyphDrawingFlags_nonHighlighted;
  }

  bool needToDrawGlyphsDirectly(const TextStyle& style) const {
    if (!style.isOverrideStyle()) {
      const TextFlags flags = style.flags() | detail::everyRunFlag;
      return !!(flags & directGlyphDrawingFlags_nonHighlighted);
    } else {
      if (directGlyphDrawingFlags_highlighted & detail::everyRunFlag) return true;
      return !!(styleOverride_->overriddenStyle()->flags() & directGlyphDrawingFlags_highlighted);
    }
  }

  ColorIndex textColorIndex(const TextStyle& style) const {
    return overrideTextColorIndices_[style.isOverride_isLink().index].value_or(style.colorIndex());
  }

  STU_INLINE
  DrawingContext(Optional<const STUCancellationFlag&> cancellationFlag,
                 CGContext* cgContext, ContextBaseCTM_d contextBaseCTM_d,
                 Optional<DisplayScale> displayScale, Rect<CGFloat> clipRect,
                 Float64 ctmYOffset, CGPoint textFrameOrigin,
                 Optional<const TextFrameDrawingOptions&> options,
                 const TextFrame& textFrame, Optional<TextStyleOverride&> styleOverride)
  : cancellationFlag_{*(cancellationFlag ?: &CancellationFlag::neverCancelledFlag)},
    cgContext_{cgContext}, displayScale_{displayScale},
    textFrameDisplayScale_{textFrame.displayScale == displayScale.storage().displayScaleOrZero()
                           ? displayScale : DisplayScale::create(textFrame.displayScale) },
    clipRect_{clipRect}, styleOverride_{styleOverride},
    colorCounts_{ColorIndex::fixedColorCount, narrow_cast<UInt16>(textFrame.colors().count())},
    ctmYOffset_{ctmYOffset},
    textFrameOrigin_{textFrameOrigin},
    shadowYExtraScaleFactor_{-(displayScale ? displayScale->value() : 1)/contextBaseCTM_d.value},
    offCanvasShadowExtraXOffset_{max(4*clipRect.x.diameter(), 1024.f)},
    colorArrays_{otherColors_, textFrame.colors().begin()}
  {
    STU_STATIC_CONST_ONCE_PRESERVE_MOST(CGColor*, cgBlackColor,
                                        (CGColor*)CFRetain(UIColor.blackColor.CGColor));
    otherColors_[0] = ColorRef{cgBlackColor, ColorFlags{}};
    const TextFlags directGlyphDrawingFlags = TextFlags::hasAttachment
                                            | TextFlags::hasBackground
                                            | TextFlags::hasUnderline
                                            | TextFlags::hasStroke
                                            | TextFlags::hasShadow
                                            | TextFlags::hasStroke;
    if (!options) {
      directGlyphDrawingFlags_nonHighlighted = directGlyphDrawingFlags;
      directGlyphDrawingFlags_highlighted = directGlyphDrawingFlags;
    } else {
      directGlyphDrawingFlags_nonHighlighted = directGlyphDrawingFlags
                                             | options->overrideColorsTextFlagsMask();
      directGlyphDrawingFlags_highlighted = options->overrideColorsApplyToHighlightedText()
                                          ? directGlyphDrawingFlags_nonHighlighted
                                          : directGlyphDrawingFlags;
      overrideTextColorIndices_[0] = directGlyphDrawingFlags_nonHighlighted & detail::everyRunFlag
                                   ? ColorIndex::overrideTextColor : Optional<ColorIndex>{};
      overrideTextColorIndices_[2] = directGlyphDrawingFlags_nonHighlighted & TextFlags::hasLink
                                   ? ColorIndex::overrideLinkColor : overrideTextColorIndices_[0];
      overrideTextColorIndices_[1] = directGlyphDrawingFlags_highlighted & detail::everyRunFlag
                                   ? ColorIndex::overrideTextColor : Optional<ColorIndex>{};
      overrideTextColorIndices_[3] = directGlyphDrawingFlags_highlighted & TextFlags::hasLink
                                   ? ColorIndex::overrideLinkColor : overrideTextColorIndices_[1];
      otherColors_[ColorIndex::overrideTextColor.value
                   - ColorIndex::fixedColorIndexRange.start] = options->overrideTextColor();
      otherColors_[ColorIndex::overrideLinkColor.value
                   - ColorIndex::fixedColorIndexRange.start] = options->overrideLinkColor();
    }
    if (styleOverride) {
      if (styleOverride->textColorIndex || (styleOverride->flags & TextFlags::hasStroke)) {
        directGlyphDrawingFlags_highlighted |= detail::everyRunFlag;
      }
      if (auto style = styleOverride->highlightStyle) {
        const Int offset = ColorIndex::highlightColorStartIndex
                         - ColorIndex::fixedColorIndexRange.start;
        for (Int i = 0; i < ColorIndex::highlightColorCount; ++i) {
          otherColors_[offset + i] = style->colors[i];
        }
      }
    }
  }

private:
  static constexpr ColorIndices reservedColorIndices =
    ColorIndices{ColorIndex::reserved, ColorIndex::reserved};

  CGFloat currentShadowExtraXOffset() const {
    return shadowOnlyScopeCount_ == 0 ? 0 : offCanvasShadowExtraXOffset_;
  }

  void setShadow_slowPath(const TextStyle::ShadowInfo* __nullable shadowInfo);

  void initializeGlyphBoundsCache();

  const STUCancellationFlag& cancellationFlag_;
  CGContext* __nonnull const cgContext_;
  const Optional<DisplayScale> displayScale_;
  const Optional<DisplayScale> textFrameDisplayScale_;
  Rect<CGFloat> clipRect_;
  Optional<TextStyleOverride&> styleOverride_;
  TextFlags directGlyphDrawingFlags_nonHighlighted;
  TextFlags directGlyphDrawingFlags_highlighted;
  TextFlags effectiveLineFlags_;
  UInt16 colorCounts_[2]; // {ColorIndex::fixedColorCount, textFrameColorCount}
  UInt32 shadowOnlyScopeCount_{};
  ColorIndices colorIndices_{reservedColorIndices};
  /// Indexed by TextStyle::IsOverrideIsLinkIndex
  Optional<ColorIndex> overrideTextColorIndices_[4];
  Float64 ctmYOffset_;
  CGPoint textFrameOrigin_;
  CGPoint lineOrigin_;
  Optional<const TextFrameLine&> textFrameLine_;
  const TextStyle::ShadowInfo* __nullable shadowInfo_{};
  CGFloat shadowYExtraScaleFactor_;
  // This should be a value large enough such that any content drawn does not intersect with the
  // clip area. We use this to coerce CoreGraphics into drawing *only* the shadow (by translating
  // the CGContext by minus this offset and then adding this offset to the shadow offset).
  const CGFloat offCanvasShadowExtraXOffset_;
  const ColorRef* __nullable const colorArrays_[2]; // {otherColors_, textFrameColors}
  ColorRef otherColors_[ColorIndex::fixedColorCount];
  LocalFontInfoCache fontInfoCache_;
  Optional<LocalGlyphBoundsCache> glyphBoundsCache_;
};

} // namespace stu_label
