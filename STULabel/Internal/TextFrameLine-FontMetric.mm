// Copyright 2017–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

namespace stu_label {

template <FontMetric metric>
STU_INLINE
CGFloat getRunFontMetric(GlyphRunRef run) {
  const CTFont* font = run.font();
       if constexpr (metric == FontMetric::xHeight)   return [(__bridge UIFont*)font xHeight];
  else if constexpr (metric == FontMetric::capHeight) return [(__bridge UIFont*)font capHeight];
  else static_assert(false && metric == metric);
}

template <FontMetric metric>
Float32 TextFrameLine::maxFontMetricValue() const {
  _Atomic(Float32)* p;
  {
    TextFrameLine& line = const_cast<TextFrameLine&>(*this);
         if constexpr (metric == FontMetric::xHeight)   { p = &line._xHeight; }
    else if constexpr (metric == FontMetric::capHeight) { p = &line._capHeight; }
    else static_assert(false && metric == metric);
  }
  Float32 value = atomic_load_explicit(p, memory_order_relaxed);
  if (value == FLT_MAX) {
    CGFloat maxValue = 0;
    forEachGlyphSpan([&maxValue](TextLinePart, CTLineXOffset, GlyphSpan glyphSpan) {
      maxValue = max(maxValue, getRunFontMetric<metric>(glyphSpan.run()));
    });
    value = narrow_cast<Float32>(maxValue);
    atomic_store_explicit(p, value, memory_order_relaxed);
  }
  return value;
}
template Float32 TextFrameLine::maxFontMetricValue<FontMetric::xHeight>() const;
template Float32 TextFrameLine::maxFontMetricValue<FontMetric::capHeight>() const;

} // namespace stu_label
