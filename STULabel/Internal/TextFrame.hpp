// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUStartEndRange-Internal.hpp"
#import "STULabel/STUTextFrame-Internal.hpp"

#import "CancellationFlag.hpp"
#import "Equal.hpp"
#import "Font.hpp"
#import "GlyphSpan.hpp"
#import "DisplayScaleRounding.hpp"
#import "IntervalSearchTable.hpp"
#import "TextFrameDrawingOptions.hpp"
#import "TextLineSpan.hpp"
#import "StyledStringRangeIteration.hpp"
#import "Rect.hpp"
#import "TextStyle.hpp"

#import "stu/ArenaAllocator.hpp"
#import "stu/ArrayRef.hpp"
#import "stu/FunctionRef.hpp"
#import "stu/NSFoundationSupport.hpp"
#import "stu/InOut.hpp"
#import "stu/Optional.hpp"

#import <stdatomic.h>

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

STU_INLINE
bool operator==(STUTextFrameIndex lhs, STUTextFrameIndex rhs) {
  return STUTextFrameIndexEqualToIndex(lhs, rhs);
}
STU_INLINE
bool operator!=(STUTextFrameIndex lhs, STUTextFrameIndex rhs) { return !(lhs == rhs); }

STU_INLINE
bool operator<(STUTextFrameIndex lhs, STUTextFrameIndex rhs) {
  return STUTextFrameIndexLessThanIndex(lhs, rhs);
}
STU_INLINE
bool operator> (STUTextFrameIndex lhs, STUTextFrameIndex rhs) { return rhs < lhs; }
STU_INLINE
bool operator<=(STUTextFrameIndex lhs, STUTextFrameIndex rhs) { return !(rhs < lhs); }
STU_INLINE
bool operator>=(STUTextFrameIndex lhs, STUTextFrameIndex rhs) { return !(lhs < rhs); }

template <>
class stu::OptionalValueStorage<STUTextFrameIndex> {
public:
  STUTextFrameIndex value_{.lineIndex = maxValue<UInt32>};
  STU_INLINE bool hasValue() const noexcept { return sign_cast(value_.lineIndex) >= 0; }
  STU_INLINE void clearValue() noexcept { value_.lineIndex = maxValue<UInt32>; }
  STU_INLINE void constructValue(STUTextFrameIndex index) { value_ = index; }
};

template <>
struct stu::RangeBase<STUTextFrameIndex> {
  STU_CONSTEXPR
  Range<Int32> rangeInTruncatedString() const {
    auto& r = static_cast<const Range<STUTextFrameIndex>&>(*this);
    const UInt32 start = r.start.indexInTruncatedString
                       + r.start.isIndexOfInsertedHyphen;
    const UInt32 end = r.end.indexInTruncatedString
                     + r.end.isIndexOfInsertedHyphen;
    return {sign_cast(start), sign_cast(end)};
  }
};

namespace stu_label {

STU_INLINE
bool operator==(STUTextFrameRange lhs, STUTextFrameRange rhs) {
  return lhs.start == rhs.start && lhs.end == rhs.end;
}
STU_INLINE
bool operator!=(STUTextFrameRange lhs, STUTextFrameRange rhs) { return !(lhs == rhs); }

} // namespace stu_label

template <>
struct stu::RangeConversion<STUTextFrameRange> {
  STU_CONSTEXPR
  static Range<STUTextFrameIndex> toRange(STUTextFrameRange range) {
    return {range.start, range.end};
  }

  STU_CONSTEXPR
  static STUTextFrameRange fromRange(Range<STUTextFrameIndex> range) {
    return {range.start, range.end};
  }
};

namespace stu_label {

STU_CONSTEXPR
bool operator==(STUTextRange lhs, STUTextRange rhs) {
  return lhs.range == rhs.range && lhs.type == rhs.type;
}
STU_CONSTEXPR
bool operator!=(STUTextRange lhs, STUTextRange rhs) { return !(lhs == rhs); }

class DrawingContext;

struct ImageBoundsContext {
  const STUCancellationFlag& cancellationFlag;
  STUTextFrameDrawingMode drawingMode;
  Optional<DisplayScale> displayScale;
  Optional<TextStyleOverride&> styleOverride;
  LocalFontInfoCache& fontInfoCache;
  LocalGlyphBoundsCache& glyphBoundsCache;

  STU_INLINE_T bool isCancelled() const { return STUCancellationFlagGetValue(&cancellationFlag); }

  STU_INLINE_T bool hasCancellationFlag() const {
    return &cancellationFlag != &CancellationFlag::neverCancelledFlag;
  }
};

#define STU_ASSUME_REGULAR_INDEX_RANGE(range) \
  STU_ASSUME(0 <= range.start && range.start <= range.end)

using TextFrameIndex = STUTextFrameIndex;
using TextFrameRange = STUTextFrameRange;

struct TruncationTokenIndex {
  Int32 indexInToken;
  Int32 tokenLength;
  NSAttributedString* __unsafe_unretained __nullable truncationToken;
};

struct IndexInOriginalString : Parameter<IndexInOriginalString, UInt> {
  using Parameter::Parameter;
};
struct IndexInTruncatedString : Parameter<IndexInTruncatedString, UInt> {
  using Parameter::Parameter;
};
struct IndexInTruncationToken : Parameter<IndexInTruncationToken, UInt> {
  using Parameter::Parameter;
};

template <typename Range>
struct RangeInOriginalString : Parameter<RangeInOriginalString<Range>, Range> {
  using Base = Parameter<RangeInOriginalString, Range>;
  using Base::Base;
};
RangeInOriginalString(NSRange) -> RangeInOriginalString<NSRange>;
template <typename T>
RangeInOriginalString(Range<T>) -> RangeInOriginalString<Range<T>>;

template <typename Range>
struct RangeInTruncatedString : Parameter<RangeInTruncatedString<Range>, Range> {
  using Base = Parameter<RangeInTruncatedString, Range>;
  using Base::Base;
};
RangeInTruncatedString(NSRange) -> RangeInTruncatedString<NSRange>;
template <typename T>
RangeInTruncatedString(Range<T>) -> RangeInTruncatedString<Range<T>>;

struct TextFrameOrigin : Parameter<TextFrameOrigin, Point<Float64>> {
  using Parameter::Parameter;
};

struct TextFrameLine;
struct TextFrameParagraph;
class TextFrameLayouter;

struct StringStartIndices {
  Int32 startIndexInOriginalString;
  Int32 startIndexInTruncatedString;
};

struct TextFrame : STUTextFrameData {
  using Base = STUTextFrameData;

  // Prevent inadvertent copies.
  TextFrame(const TextFrame&) = delete;
  TextFrame& operator=(const TextFrame&) = delete;

  STU_INLINE
  Range<TextFrameIndex> range() const {
    return {{}, STUTextFrameDataGetEndIndex(&*this)};
  }

  STU_INLINE
  Range<Int32> rangeInOriginalString() const {
    const Range<Int32> range = Base::rangeInOriginalString;
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  Range<Int32> rangeInTruncatedString() const {
    const Range<Int32> range = {0,  Base::truncatedStringLength};
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  NSDictionary<NSString*, id>* __nullable attributesAt(TextFrameIndex) const;

  Unretained<NSAttributedString* __nonnull> truncatedAttributedString() const;

  STU_INLINE
  ArrayRef<const TextFrameParagraph> paragraphs() const;

  STU_INLINE
  ArrayRef<const TextFrameLine> lines() const;

  STU_INLINE
  ArrayRef<const StringStartIndices> lineStringIndices() const {
    const Int n = lineCount + 1;
    return {(const StringStartIndices*)((const Byte*)this - sanitizerGap) - n, n, unchecked};
  }

  STU_INLINE
  IntervalSearchTable verticalSearchTable() const {
    const auto* const p = (const Float32*)((const Byte*)lineStringIndices().begin() - sanitizerGap)
                        - 2*lineCount;
    return {ArrayRef{p, lineCount}, ArrayRef{p + lineCount, lineCount}};
  }

  STU_INLINE
  ArrayRef<const ColorRef> colors() const {
    return {(const ColorRef*)((const Byte*)_textStylesData - sanitizerGap)
            - _colorCount, _colorCount};
  }

  STU_INLINE
  TextFrameIndex endIndex() const { return STUTextFrameDataGetEndIndex(this); }

  Optional<TextFrameIndex> normalize(TextFrameIndex) const;

  bool isValidIndex(TextFrameIndex index) const {
    return normalize(index) != none;
  }

  TextFrameIndex index(IndexInOriginalString, IndexInTruncationToken) const;

  TextFrameIndex index(IndexInTruncatedString) const;

  Range<TextFrameIndex> range(RangeInOriginalString<NSRange>) const;
  Range<TextFrameIndex> range(RangeInTruncatedString<NSRange>) const;

  Range<TextFrameIndex> range(STUTextRange textRange) const {
    if (textRange.type == STURangeInOriginalString) {
      return range(RangeInOriginalString{textRange.range});
    } else {
      return range(RangeInTruncatedString{textRange.range});
    }
  }

  Range<Int32> rangeInOriginalString(TextFrameIndex index,
                                     Optional<Out<TruncationTokenIndex>> = none) const;
  Range<Int32> rangeInOriginalString(STUTextFrameRange) const;

  TruncationTokenIndex truncationTokenIndex(TextFrameIndex index) const {
    TruncationTokenIndex result;
    rangeInOriginalString(index, Out{result});
    return result;
  }

  const TextFrameParagraph& paragraph(TextFrameIndex) const;

  // Defined in LineSpan.mm
  TempArray<TextLineSpan> lineSpans(STUTextFrameRange range,
                                    Optional<FunctionRef<bool(const TextStyle&)>> = none)
                             const;

  STU_INLINE
  const TextStyle& firstNonTokenTextStyleForLineAtIndex(Int lineIndex) const;

  STU_INLINE
  const TextStyle& firstTokenTextStyleForLineAtIndex(Int lineIndex) const;

  struct GraphemeClusterRange {
    Range<TextFrameIndex> range;
    Rect<Float64> bounds;
    STUWritingDirection writingDirection;
    bool isLigatureFraction;

    explicit operator STUTextFrameGraphemeClusterRange() const {
      return {range, narrow_cast<CGRect>(bounds), writingDirection, isLigatureFraction};
    }
  };

  // Defined in TextFrame-PointToindex.mm
  GraphemeClusterRange rangeOfGraphemeClusterClosestTo(Point<Float64> point,
                                                       TextFrameOrigin,
                                                       CGFloat displayScale) const;

  Rect<CGFloat> calculateImageBounds(TextFrameOrigin, const ImageBoundsContext&) const;

  static CGFloat assumedScaleForCTM(const CGAffineTransform& ctm) {
    const CGFloat scale = stu_label::scale(ctm);
    return scale > 1/64.f ? scale : 0;
  }

  void draw(CGPoint point, CGContext* cgContext, ContextBaseCTM_d, PixelAlignBaselines,
            Optional<const TextFrameDrawingOptions&>, Optional<TextStyleOverride&>,
            Optional<const STUCancellationFlag&>) const;

  void drawBackground(Range<Int> clipLineRange, DrawingContext& context) const;

  ~TextFrame();

private:
  friend STUTextFrame* ::STUTextFrameCreateWithShapedStringRange(Class, STUShapedString*, NSRange,
                                                                 CGSize, CGFloat,
                                                                 STUTextFrameOptions*,
                                                                 const STUCancellationFlag*);

  static constexpr Int sanitizerGap = STU_USE_ADDRESS_SANITIZER ? 8 : 0;

  struct SizeAndOffset {
    UInt size;
    UInt offset;
  };
  static SizeAndOffset objectSizeAndThisOffset(const TextFrameLayouter& layouter);

  explicit TextFrame(TextFrameLayouter&& layouter, UInt dataSize);
};


STU_INLINE const TextFrame& textFrameRef(const STUTextFrameData& data) {
  return down_cast<const TextFrame&>(data);
}
STU_INLINE const TextFrame& textFrameRef(const STUTextFrame* textFrame) {
  return textFrameRef(*textFrame->data);
}

struct TextFrameParagraph : STUTextFrameParagraph {
  using Base = STUTextFrameParagraph;

  STU_INLINE
  const TextFrame& textFrame() const {
    return reinterpret_cast<const TextFrame*>(this - paragraphIndex)[-1];
  }

  STU_INLINE
  Range<Int32> rangeOfTruncationTokenInTruncatedString() const {
    const Int32 start = STUTextFrameParagraphGetStartIndexOfTruncationTokenInTruncatedString(this);
    const Range<Int32> range{start, Count{this->truncationTokenLength}};
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  Range<TextFrameIndex> rangeOfTruncationToken() const {
    const Range<UInt32> range = sign_cast(rangeOfTruncationTokenInTruncatedString());
    const Range<Int32> lineIndexRange = this->lineIndexRange();
    const UInt32 lineIndex = sign_cast(max(lineIndexRange.start, lineIndexRange.end - 1));
    return {{.indexInTruncatedString = range.start, .lineIndex = lineIndex},
            {.indexInTruncatedString = range.end,   .lineIndex = lineIndex}};
  }

  STU_INLINE
  Range<Int32> excisedRangeInOriginalString() const {
    const Range<Int32> range = Base::excisedRangeInOriginalString;
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  Range<Int32> lineIndexRange() const {
    const Range<Int32> range = Base::lineIndexRange;
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  Range<Int32> initialLinesIndexRange() const {
    const Range<Int32> range = {Base::lineIndexRange.start, initialLinesEndIndex};
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  Range<Int32> nonInitialLinesIndexRange() const {
    const Range<Int32> range = {initialLinesEndIndex, Base::lineIndexRange.end};
    STU_ASSUME_REGULAR_INDEX_RANGE(range);
    return range;
  }

  STU_INLINE
  ArrayRef<const TextFrameLine> lines() const;

  STU_INLINE
  ShouldStop forEachStyledStringRange(
               Optional<TextStyleOverride&> styleOverride,
               FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body) const
  {
    return detail::forEachStyledStringRange(textFrame(), *this, lineIndexRange(), styleOverride,
                                            body);
  }

  template <typename Body,
            EnableIf<isCallable<Body, void(const TextStyle&, StyledStringRange)>> = 0>
  STU_INLINE
  void forEachStyledStringRange(Optional<TextStyleOverride&> styleOverride, Body&& body) const {
    forEachStyledStringRange(styleOverride,
                             [&](const TextStyle& style, StyledStringRange range) STU_INLINE_LAMBDA
                               -> ShouldStop
                             {
                               body(style, range);
                               return {};
                             });
  }

  STU_INLINE
  Range<TextFrameCompactIndex> range() const {
    return {TextFrameCompactIndex{rangeInTruncatedString.start},
            TextFrameCompactIndex{rangeInTruncatedString.end}};
  }

  STU_INLINE
  TextFlags textFlags() const { return static_cast<TextFlags>(Base::textFlags); }

  STU_INLINE
  TextFlags effectiveTextFlags(Optional<const TextStyleOverride&> styleOverride) const {
    return effectiveTextFlags(TextFlags{}, styleOverride);
  }
  STU_INLINE
  TextFlags effectiveTextFlags(TextFlags extraFlags,
                               Optional<const TextStyleOverride&> styleOverride) const
  {
    const TextFlags flags = textFlags() | extraFlags;
    return STU_LIKELY(!styleOverride) ?flags
         : stu_label::effectiveTextFlags(flags, range(), *styleOverride);
  }
};

static_assert(isBitwiseCopyable<TextFrameParagraph>);

} // namespace stu_label

template <> struct stu::IsMemberwiseConstructible<stu_label::TextFrameParagraph> : True {};

namespace stu_label {

struct CTLineXOffset {
  CGFloat value;
  STU_CONSTEXPR explicit CTLineXOffset(CGFloat value) : value(value) {};
};

struct FlagsRequiringIndividualRunIteration {
  TextFlags flags;
  explicit FlagsRequiringIndividualRunIteration() = default;

  template <typename T, EnableIf<isConvertible<const T&, TextFlags>> = 0>
  STU_CONSTEXPR
  explicit FlagsRequiringIndividualRunIteration(const T& flags) : flags(flags) {}
};


enum class TextLinePart : UInt8 {
  originalString,
  truncationToken,
  insertedHyphen
};

enum class FontMetric {
  xHeight,
  capHeight
};

struct StyledGlyphSpan;

struct TextFrameLine : STUTextFrameLine {
  using Base = STUTextFrameLine;

  // Prevent inadvertent copies.
  TextFrameLine(const TextFrameLine&) = delete;
  TextFrameLine& operator=(const TextFrameLine&) = delete;

  STU_INLINE
  void releaseCTLines() const {
    if (_ctLine) {
      CFRelease(_ctLine);
    }
    if (_tokenCTLine) {
      CFRelease(_tokenCTLine);
    }
  }

  STU_INLINE
  const TextFrame& textFrame() const {
    STU_DEBUG_ASSERT(!_initStep);
    return reinterpret_cast<const TextFrameParagraph*>(this - lineIndex)[-1].textFrame();
  }

  STU_INLINE
  const TextFrameParagraph& paragraph() const {
    STU_DEBUG_ASSERT(!_initStep);
    return *down_cast<const TextFrameParagraph*>(STUTextFrameLineGetParagraph(this));
  }

  STU_INLINE
  Range<TextFrameIndex> range() const {
    return STUTextFrameLineGetRange(this);
  }

  STU_INLINE
  Range<Int32> rangeInTruncatedStringIncludingTrailingWhitespace() const {
    Range<Int32> range = rangeInTruncatedString;
    range.end += trailingWhitespaceInTruncatedStringLength;
    return range;
  }

  using GraphemeClusterRange = TextFrame::GraphemeClusterRange;

  /// @param xOffset The X offset from the line's origin.
  // Defined in TextFrame-PointToindex.mm
  GraphemeClusterRange rangeOfGraphemeClusterAtXOffset(Float64 xOffset) const;

  STU_INLINE
  TextFlags textFlags()         const { return static_cast<TextFlags>(Base::textFlags); }
  STU_INLINE
  TextFlags nonTokenTextFlags() const { return static_cast<TextFlags>(Base::nonTokenTextFlags); }
  STU_INLINE
  TextFlags tokenTextFlags()    const { return static_cast<TextFlags>(Base::tokenTextFlags); }


  STU_INLINE
  TextFlags effectiveTextFlags(Optional<const TextStyleOverride&> styleOverride) const {
    return effectiveTextFlags(TextFlags{0}, styleOverride);
  }
  STU_INLINE
  TextFlags effectiveTextFlags(TextFlags extraFlags,
                               Optional<const TextStyleOverride&> styleOverride) const
  {
    const TextFlags flags = textFlags() | extraFlags;
    return STU_LIKELY(!styleOverride) ? flags
         : stu_label::effectiveTextFlags(flags, range(), *styleOverride);
  }

  ShouldStop forEachCTLineSegment(
               FlagsRequiringIndividualRunIteration mask,
               FunctionRef<ShouldStop(TextLinePart, CTLineXOffset, CTLine&,
                                      Optional<GlyphSpan>)> body)
             const;

  template <typename Body,
            EnableIf<isCallable<Body, void(TextLinePart, CTLineXOffset, CTLine&,
                                           Optional<GlyphSpan>)>> = 0>
  STU_INLINE
  void forEachCTLineSegment(FlagsRequiringIndividualRunIteration mask, Body&& body) const {
    forEachCTLineSegment(mask, [&](TextLinePart part, CTLineXOffset offset, CTLine& line,
                                   Optional<GlyphSpan> span) STU_INLINE_LAMBDA -> ShouldStop
                               {
                                 body(part, offset, line, span);
                                 return {};
                               });
  }

  template <typename Body,
            EnableIf<isCallable<Body, ShouldStop(TextLinePart, CTLineXOffset, GlyphSpan)>> = 0>
  STU_INLINE
  ShouldStop forEachGlyphSpan(Body&& body) const {
    return forEachCTLineSegment(FlagsRequiringIndividualRunIteration{detail::everyRunFlag},
           [&](TextLinePart part, CTLineXOffset offset, CTLine&, Optional<GlyphSpan> span)
             STU_INLINE_LAMBDA
           {
             return body(part, offset, *span);
           });
  }

  template <typename Body,
            EnableIf<isCallable<Body, void(TextLinePart, CTLineXOffset, GlyphSpan)>> = 0>
  STU_INLINE
  void forEachGlyphSpan(Body&& body) const {
    forEachCTLineSegment(FlagsRequiringIndividualRunIteration{detail::everyRunFlag},
      [&](TextLinePart part, CTLineXOffset offset, CTLine&, Optional<GlyphSpan> span)
        STU_INLINE_LAMBDA -> ShouldStop
      {
        body(part, offset, *span);
        return {};
      });
  }

  template <typename Body,
            EnableIf<isCallable<Body, void(const StyledGlyphSpan&, const TextStyle&,
                                           Range<Float64> xOffset)>> = 0>
  STU_INLINE
  void forEachStyledGlyphSpan(Optional<TextStyleOverride&> styleOverride, Body&& body) const {
    return forEachStyledGlyphSpan(detail::everyRunFlag, styleOverride, body);
  }

  template <typename Body,
            EnableIf<isCallable<Body, ShouldStop(const StyledGlyphSpan&, const TextStyle&,
                                                 Range<Float64> xOffset)>> = 0>
  STU_INLINE
  ShouldStop forEachStyledGlyphSpan(Optional<TextStyleOverride&> styleOverride,
                                    Body&& body)
               const
  {
    return forEachStyledGlyphSpan(detail::everyRunFlag, styleOverride, body);
  }

  template <typename Body,
            EnableIf<isCallable<Body, void(const StyledGlyphSpan&, const TextStyle&,
                                           Range<Float64> xOffset)>> = 0>
  STU_INLINE
  void forEachStyledGlyphSpan(TextFlags flagsFilterMask, Optional<TextStyleOverride&> styleOverride,
                              Body&& body) const
  {
    forEachStyledGlyphSpan(flagsFilterMask, styleOverride,
                           [&](const StyledGlyphSpan& span, const TextStyle& style,
                               Range<Float64> xOffset) STU_INLINE_LAMBDA -> ShouldStop
                           {
                             body(span, style, xOffset);
                             return {};
                           });
  }

  ShouldStop forEachStyledGlyphSpan(
               TextFlags flagsFilterMask, Optional<TextStyleOverride&>,
               FunctionRef<ShouldStop(const StyledGlyphSpan&, const TextStyle&,
                                      Range<Float64> xOffset)> body)
             const;

  STU_INLINE
  ShouldStop forEachStyledStringRange(Optional<TextStyleOverride&> styleOverride,
                                      FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body)
               const
  {
    return detail::forEachStyledStringRange(textFrame(), paragraph(),
                                            Range{lineIndex, Count{1}},
                                            styleOverride, body);
  }

  template <FontMetric metric>
  Float32 maxFontMetricValue() const;

  STU_INLINE Point<Float64> origin() const { return {this->originX, this->originY}; }

  STU_INLINE
  Point<Float64> origin(TextFrameOrigin frameOrigin,
                        const Optional<DisplayScale>& displayScale) const
  {
    auto y = frameOrigin.value.y + this->originY;
    if (displayScale) {
      y = ceilToScale(y, *displayScale);
    }
    return {frameOrigin.value.x + this->originX, y};
  }

  STU_INLINE
  Rect<Float64> typographicBounds(TextFrameOrigin frameOrigin = {},
                                  const Optional<DisplayScale>& displayScale = DisplayScale::none)
                  const
  {
    const auto origin = this->origin(frameOrigin, displayScale);
    auto ascent = this->ascent + this->leading/2;
    auto descent = this->descent + this->leading/2;
    auto result = Rect{origin.x + Range{0, this->width},
                       origin.y + Range{-ascent, descent}};
    STU_ASSUME(result.x.start <= result.x.end);
    STU_ASSUME(result.y.start <= result.y.end);
    return result;
  }

  /// Relative to the line origin.
  STU_INLINE Range<Float32> tokenXRange() const {
    return {leftPartWidth, leftPartWidth + tokenWidth};
  }

  /// Relative to the line origin.
  STU_INLINE
  Rect<Float32> fastBounds() const {
    return {Range{fastBoundsMinX, fastBoundsMaxX},
            Range{-fastBoundsLLOMaxY, -fastBoundsLLOMinY}};
  }

  /// The glyph bounding rect does not account for stroke, shadow or other decoration styles.
  STU_INLINE
  Optional<Rect<Float32>> loadGlyphsBoundingRectLLO() const {
    TextFrameLine& self = const_cast<TextFrameLine&>(*this);
    const Float32 maxY = atomic_load_explicit(&self._glyphsBoundingRectLLOMaxY,
                                              memory_order_relaxed);
    if (maxY == maxValue<Float32>) return none;
    const Float32 minX = atomic_load_explicit(&self._glyphsBoundingRectMinX, memory_order_relaxed);
    const Float32 maxX = atomic_load_explicit(&self._glyphsBoundingRectMaxX, memory_order_relaxed);
    const Float32 minY = atomic_load_explicit(&self._glyphsBoundingRectLLOMinY,
                                              memory_order_relaxed);
    if (minX != maxValue<Float32> && maxX != maxValue<Float32> && minY != maxValue<Float32>) {
      return Rect{Range{minX, maxX}, Range{minY, maxY}};
    } else {
      return none;
    }
  }

  /// Returns bounds relative to the line origin.
  Rect<CGFloat> calculateImageBoundsLLO(const ImageBoundsContext& context) const;

  void drawLLO(DrawingContext&) const;


  // We initialize the line data in multiple steps. In order to make the code easier to review
  // and refactor, we define some helper functions for this purpose.

  struct InitStep1Params {
    Int lineIndex;
    bool isFirstLineInParagraph;
    STUWritingDirection paragraphBaseWritingDirection;
    Int rangeInOriginalStringStart;
    Int rangeInTruncatedStringStart;
    Int paragraphIndex;
    Int textStylesOffset;
  };

  struct InitStep2Params {
    Int rangeInOriginalStringEnd;
    Int rangeInTruncatedStringCount;
    Int trailingWhitespaceInTruncatedStringLength;

    CTLine* ctLine;
    Float64 width;

    struct Token {
      bool isRightToLeftLine;

      RunGlyphIndex leftPartEnd;
      RunGlyphIndex rightPartStart;
      Float64 leftPartWidth;
      Float64 rightPartXOffset;

      CTLine* tokenCTLine;
      Float64 tokenWidth;
      TextFlags tokenTextFlags;
      Int tokenStylesOffset;

      struct Hyphen {
        Int8 runIndex{-1};
        Int8 glyphIndex{-1};
        Float64 xOffset{};
      } hyphen;
    } token{};
  };

  struct InitStep3Params {
    TextFlags nonTokenTextFlags;
  };

  struct HeightInfo {
    Float32 heightAboveBaseline;
    Float32 heightBelowBaseline;
    Float32 heightBelowBaselineWithoutSpacing;
  };

  struct InitStep4Params {
    bool hasColorGlyph;

    Float32 ascent;
    Float32 descent;
    Float32 leading;

    HeightInfo heightInfo;

    Float32 fastBoundsMinX;
    Float32 fastBoundsMaxX;
    Float32 fastBoundsLLOMaxY;
    Float32 fastBoundsLLOMinY;
  };

  struct InitStep5Params {
    Point<Float64> origin;
  };

  STU_INLINE
  void init_step1(InitStep1Params p) {
    rangeInOriginalString.start = narrow_cast<Int32>(p.rangeInOriginalStringStart);
    rangeInTruncatedString.start = narrow_cast<Int32>(p.rangeInTruncatedStringStart);
    paragraphIndex = narrow_cast<Int32>(p.paragraphIndex);
    lineIndex = narrow_cast<Int32>(p.lineIndex);
    paragraphBaseWritingDirection = p.paragraphBaseWritingDirection;
    isFirstLineInParagraph = p.isFirstLineInParagraph;
    isFollowedByTerminatorInOriginalString = false;
    hasInsertedHyphen = false;
    hasTruncationToken = false;
    isLastLine = false;
    _initStep = 1;
    _textStylesOffset = p.textStylesOffset;
    _tokenStylesOffset = 0;
    _ctLine = nullptr;
    _tokenCTLine = nullptr;
  }

  STU_INLINE
  void init_step2(InitStep2Params p) {
    if (_initStep == 1) {
      _initStep = 2;
    } else {
      STU_DEBUG_ASSERT(_initStep == 2);
      releaseCTLines();
    }

    rangeInOriginalString.end = narrow_cast<Int32>(p.rangeInOriginalStringEnd);
    rangeInTruncatedString.end = rangeInTruncatedString.start
                               + narrow_cast<Int32>(p.rangeInTruncatedStringCount);
    trailingWhitespaceInTruncatedStringLength = narrow_cast<Int32>(p.trailingWhitespaceInTruncatedStringLength);

    Base::tokenTextFlags = stuTextFlags(p.token.tokenTextFlags);

    _hyphenRunIndex = p.token.hyphen.runIndex;
    _hyphenGlyphIndex = p.token.hyphen.glyphIndex;

    hasInsertedHyphen = p.token.hyphen.runIndex >= 0;
    hasTruncationToken = !hasInsertedHyphen && p.token.tokenCTLine;
    isTruncatedAsRightToLeftLine = hasTruncationToken && p.token.isRightToLeftLine;

    width = narrow_cast<Float32>(p.width);

    _tokenStylesOffset  = p.token.tokenStylesOffset;

    _ctLine = p.ctLine;
    _tokenCTLine = p.token.tokenCTLine;

    tokenWidth = narrow_cast<Float32>(p.token.tokenWidth);
    _hyphenXOffset = narrow_cast<Float32>(p.token.hyphen.xOffset);

    if (p.token.tokenCTLine) {
      _leftPartEnd = p.token.leftPartEnd;
      _rightPartStart = p.token.rightPartStart;
      leftPartWidth = narrow_cast<Float32>(p.token.leftPartWidth);
      _rightPartXOffset = narrow_cast<Float32>(p.token.rightPartXOffset);
    } else {
      _leftPartEnd = STURunGlyphIndex{-1, -1};
      _rightPartStart = _leftPartEnd;
      leftPartWidth = width;
      _rightPartXOffset = 0;
    }
  }

  STU_INLINE
  void init_step3(InitStep3Params p) {
    STU_DEBUG_ASSERT(_initStep == 2);
    _initStep = 3;

    Base::nonTokenTextFlags = stuTextFlags(p.nonTokenTextFlags);
    Base::textFlags = stuTextFlags(p.nonTokenTextFlags) | Base::tokenTextFlags;
  }

  STU_INLINE
  void init_step4(InitStep4Params p) {
    STU_DEBUG_ASSERT(_initStep == 3);
    _initStep = 4;
    if (p.hasColorGlyph) {
      Base::textFlags |= STUTextMayNotBeGrayscale;
      Base::nonTokenTextFlags |= STUTextMayNotBeGrayscale;
      Base::tokenTextFlags |= _tokenCTLine ? STUTextMayNotBeGrayscale : STUTextFlags{};
    }
    ascent = p.ascent;
    descent = p.descent;
    leading = p.leading;
    _heightAboveBaseline = p.heightInfo.heightAboveBaseline;
    _heightBelowBaseline = p.heightInfo.heightBelowBaseline;
    _heightBelowBaselineWithoutSpacing = p.heightInfo.heightBelowBaselineWithoutSpacing;
    fastBoundsMinX = p.fastBoundsMinX;
    fastBoundsMaxX = p.fastBoundsMaxX;
    fastBoundsLLOMaxY = p.fastBoundsLLOMaxY;
    fastBoundsLLOMinY = p.fastBoundsLLOMinY;
    atomic_store_explicit(&_capHeight,                 maxValue<Float32>, memory_order_relaxed);
    atomic_store_explicit(&_xHeight,                   maxValue<Float32>, memory_order_relaxed);
    atomic_store_explicit(&_glyphsBoundingRectMinX,    maxValue<Float32>, memory_order_relaxed);
    atomic_store_explicit(&_glyphsBoundingRectMaxX,    maxValue<Float32>, memory_order_relaxed);
    atomic_store_explicit(&_glyphsBoundingRectLLOMinY, maxValue<Float32>, memory_order_relaxed);
    atomic_store_explicit(&_glyphsBoundingRectLLOMaxY, maxValue<Float32>, memory_order_relaxed);
  }

  STU_INLINE
  void init_step5(InitStep5Params p) {
    STU_DEBUG_ASSERT(_initStep == 4);
    _initStep = 5;
    originX = p.origin.x;
    originY = p.origin.y;
  }
};

static_assert(isBitwiseCopyable<TextFrameLine>);

struct StyledGlyphSpan {
  GlyphSpan glyphSpan;
  /// The string range associated with the glyph span in attributedString.string.
  /// (Range{rangeInOriginalString.end, Count{0}} if part == insertedHyphen.)
  Range<Int32> stringRange;
  Int32 startIndexOfTruncationTokenInTruncatedString;
  TextLinePart part;
  bool isPartialLigature;
  bool leftEndOfLigatureIsClipped;
  bool rightEndOfLigatureIsClipped;
  CGFloat ctLineXOffset;
  /// The original string or truncation token. (The original string if part == insertedHyphen.)
  NSAttributedString* attributedString;
  const TextFrameLine* line;
  const TextFrameParagraph* paragraph;

  Range<Int32> rangeInOriginalString() const {
    switch (part) {
    case TextLinePart::originalString:
    case TextLinePart::insertedHyphen:
      return stringRange;
    case TextLinePart::truncationToken:
      return paragraph->excisedRangeInOriginalString();
    }
    __builtin_trap();
  }

  Range<Int32> rangeInTruncatedString() const {
    switch (part) {
    case TextLinePart::originalString:
      return stringRange
           + (stringRange.start < paragraph->excisedRangeInOriginalString().start
              ? line->rangeInTruncatedString.start - line->rangeInOriginalString.start
              : line->rangeInTruncatedString.end - line->rangeInOriginalString.end);
    case TextLinePart::truncationToken:
      return stringRange + startIndexOfTruncationTokenInTruncatedString;
    case TextLinePart::insertedHyphen:
      return {line->rangeInTruncatedString.end, Count{0}};
    }
    __builtin_trap();
  }

  UIFont* originalFont() const {
    const UInt index = sign_cast(stringRange.start - (part == TextLinePart::insertedHyphen));
    return static_cast<UIFont*>([attributedString attribute:NSFontAttributeName atIndex:index
                                             effectiveRange:nil]);
  }
};


namespace detail {
  void adjustFastTextFrameLineBoundsToAccountForDecorationsAndAttachments(
         TextFrameLine& line, LocalFontInfoCache& fontInfoCache);
}


STU_INLINE
ArrayRef<const TextFrameLine> TextFrame::lines() const {
  return {down_cast<const TextFrameLine*>(STUTextFrameDataGetLines(this)),
          lineCount, unchecked};
};

STU_INLINE
ArrayRef<const TextFrameParagraph> TextFrame::paragraphs() const {
  return {down_cast<const TextFrameParagraph*>(STUTextFrameDataGetParagraphs(this)),
          paragraphCount, unchecked};
};

inline const TextFrameParagraph& TextFrame::paragraph(TextFrameIndex index) const {
  const auto* para = &paragraphs()[lines()[sign_cast(index.lineIndex)].paragraphIndex];
  while (para->rangeInTruncatedString.end < index.indexInTruncatedString) {
    STU_ASSERT(!para->isLastParagraph);
    // The index points to the trailing whitespace of the last paragraph of a multi-paragraph
    // truncation.
    ++para;
  }
  return *para;
}

STU_INLINE
const TextStyle& TextFrame::firstNonTokenTextStyleForLineAtIndex(Int index) const  {
  return *reinterpret_cast<const TextStyle*>(_textStylesData + lines()[index]._textStylesOffset);
}

STU_INLINE
const TextStyle& TextFrame::firstTokenTextStyleForLineAtIndex(Int index) const  {
  return *reinterpret_cast<const TextStyle*>(_textStylesData + lines()[index]._tokenStylesOffset);
}

using CFAttributedString = RemovePointer<CFAttributedStringRef>;


STU_INLINE
ArrayRef<const TextFrameLine> TextFrameParagraph::lines() const {
  return textFrame().lines()[lineIndexRange()];
}

class TextFrameScale {
public:
   /* implicit */ STU_CONSTEXPR operator CGFloat() const { return value_; }

  STU_CONSTEXPR
  CGFloat value() const {
    return value_;
  }

  STU_CONSTEXPR
  Float32 value_f32() const {
  #if CGFLOAT_IS_DOUBLE
    return value_f32_;
  #else
    return value_;
  #endif
  }

  explicit STU_CONSTEXPR
  TextFrameScale(CGFloat value)
  : value_{value}
  #if CGFLOAT_IS_DOUBLE
    , value_f32_{narrow_cast<Float32>(value)}
  #endif
  {}

  // Explicit to prevent inadvertent copies.
  explicit TextFrameScale(const TextFrameScale&) = default;
  TextFrameScale& operator=(const TextFrameScale&) = default;

private:
  CGFloat value_;
#if CGFLOAT_IS_DOUBLE
  Float32 value_f32_;
#endif
};

class TextFrameScaleAndDisplayScale {
public:
  static constexpr TextFrameScaleAndDisplayScale one() { return {}; }
  
  TextFrameScale textFrameScale;
  Optional<DisplayScale> displayScale; ///< originalDisplayScale*textFrameScale

  STU_INLINE
  TextFrameScaleAndDisplayScale(const TextFrame& textFrame, CGFloat displayScale)
  : textFrameScale{textFrame.textScaleFactor},
    displayScale{DisplayScale::create(textFrame.textScaleFactor*displayScale)}
  {}

  STU_INLINE
  TextFrameScaleAndDisplayScale(const TextFrame& textFrame, const DisplayScale& displayScale)
  : textFrameScale{textFrame.textScaleFactor},
    displayScale{textFrame.textScaleFactor == 1 ? displayScale
                 : DisplayScale::create(textFrame.textScaleFactor*displayScale)}
  {}
  
private:
  STU_CONSTEXPR TextFrameScaleAndDisplayScale()
  : textFrameScale{1}, displayScale{DisplayScale::oneAsOptional()}
  {}
};

struct TextFrameOriginY : Parameter<TextFrameOriginY, Float64> {
  using Parameter::Parameter;
};

} // stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
