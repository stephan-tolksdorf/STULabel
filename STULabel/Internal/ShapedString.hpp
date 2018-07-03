// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUShapedString-Internal.hpp"
#import "STULabel/STUTextFrame-Unsafe.h"

#import "Font.hpp"
#import "HashSet.hpp"
#import "NSAttributedStringRef.hpp"
#import "TextStyleBuffer.hpp"

#import "stu/FunctionRef.hpp"

namespace stu_label {

struct SkipIsolatedText : Parameter<SkipIsolatedText> { using Parameter::Parameter; };

NSWritingDirection detectBaseWritingDirection(const NSStringRef&, Range<Int> range,
                                              SkipIsolatedText skipIsolatedText);

struct LineHeightParams {
  Float32 lineHeightMultiple; // > 0
  Float32 minLineHeight; // ≥ 0
  Float32 maxLineHeight; // > 0
  Float32 minLineSpacing; // ≥ 0
};

struct MinLineHeightInfo {
  Float32 minHeightWithoutSpacingBelowBaseline;
  Float32 minHeightBelowBaselineWithoutSpacing;
  Float32 minSpacingBelowBaseline;

  Float32 minHeight() const {
    return minHeightWithoutSpacingBelowBaseline + minSpacingBelowBaseline;
  }
};

struct TruncationScope {
  Range<Int32> stringRange;
  Range<Int32> truncatableStringRange;
  Int32 maxLineCount;
  CTLineTruncationType lastLineTruncationMode : 8;
  UInt8 finalLineTerminatorUTF16Length;
  NSAttributedString* __unsafe_unretained __nullable truncationToken;
};

using CTTypesetter = RemovePointer<CTTypesetterRef>;

class TextStyleBuffer;

class ShapedString {
public:
  struct Paragraph {
    Range<Int32> stringRange;

    NSTextAlignment alignment : 4; // NSTextAlignment's underlying type is the signed NSInteger.
    // The length of the paragraph terminator ("\r", "\n", "\r\n" or "\u2029").
    UInt8 terminatorStringLength : 2;
    bool paragraphStyleNeededFix : 1;
    STUWritingDirection baseWritingDirection : 1;
    STUFirstLineOffsetType firstLineOffsetType : 3;
    STUTextFlags textFlags;

    Int32 truncationScopeIndex; // A negative index indicates there's no truncation scope.
    UInt32 textStylesOffset;

    Float32 firstLineLeftIndent; // ≥ 0
    Float32 firstLineRightIndent; // ≥ 0
    Float32 paddingLeft; // If negative, the frame width should be added to the value.
    Float32 paddingRight; // If negative, the frame width should be added to the value.
    Float32 paddingTop; // ≥ 0
    Float32 paddingBottom; // ≥ 0

    LineHeightParams lineHeightParams;
    Float32 firstLineOffset;
    Float32 hyphenationFactor; // in [0, 1]

    MinLineHeightInfo effectiveMinLineHeightInfo_default;
    MinLineHeightInfo effectiveMinLineHeightInfo_textKit;

    STU_INLINE
    const MinLineHeightInfo& effectiveMinLineHeightInfo(STUTextLayoutMode mode) const {
      switch (mode) {
      case STUTextLayoutModeTextKit: return effectiveMinLineHeightInfo_textKit;
      case STUTextLayoutModeDefault: break;
      }
      return effectiveMinLineHeightInfo_default;
    }
  };

  NSAttributedString* const attributedString;
  const RC<CTTypesetter> typesetter;
  const Int32 stringLength;
  const Int32 paragraphCount;
  const Int32 truncationScopeCount;
  const UInt16 fontCount;
  const UInt16 colorCount;
  const STUWritingDirection defaultBaseWritingDirection;
  const bool defaultBaseWritingDirectionWasUsed;
  const Int textStylesSize;
private:
  Paragraph paragraphs_[];

public:
  using ColorHashBucket = TempIndexHashTable<UInt16>::Bucket;

  struct ArraysRef {
    ArrayRef<const Paragraph> paragraphs;
    ArrayRef<const TruncationScope> truncationSopes;
    ArrayRef<const ColorRef> colors;
    ArrayRef<const ColorHashBucket> colorHashBuckets;
    ArrayRef<const FontMetrics> fontMetrics;
    TextStyleSpan textStyles;
  };

  STU_INLINE
  ArraysRef arrays() const {
    static_assert(alignof(Paragraph) == alignof(TruncationScope));
    static_assert(alignof(TruncationScope) == alignof(ColorRef));
    static_assert(alignof(ColorRef) >= alignof(ColorHashBucket));
    static_assert(alignof(ColorRef) >= alignof(FontMetrics)
                  && sizeof(ColorHashBucket)%alignof(FontMetrics) == 0);
    static_assert(alignof(TextStyle) == alignof(FontMetrics));

    const ArrayRef<const Paragraph> paragraphs{
      paragraphs_, paragraphCount, unchecked
    };
    const ArrayRef<const TruncationScope> truncationScopes{
      (const TruncationScope*)((const Byte*)paragraphs.end() + sanitizerGap),
      truncationScopeCount, unchecked
    };
    const ArrayRef<const ColorRef> colors{
      (const ColorRef*)((const Byte*)truncationScopes.end() + sanitizerGap),
      colorCount, unchecked
    };
    const ArrayRef<const ColorHashBucket> colorHashBuckets{
      (const ColorHashBucket*)((const Byte*)colors.end() + sanitizerGap),
      colorCount, unchecked
    };
    const ArrayRef<const FontMetrics> fontMetrics{
      (const FontMetrics*)((const Byte*)colorHashBuckets.end() + sanitizerGap),
      fontCount, unchecked
    };
   const auto firstStyle = (const TextStyle*)((const Byte*)fontMetrics.end() + sanitizerGap);
   const auto terminatorStyle =
                (const TextStyle*)((const Byte*)firstStyle + textStylesSize
                                   - TextStyle::sizeOfTerminatorWithStringIndex(stringLength));

    return {paragraphs, truncationScopes, colors, colorHashBuckets, fontMetrics,
            TextStyleSpan{.firstStyle = firstStyle, .terminatorStyle = terminatorStyle}};
  };

  static ShapedString* __nullable create(NSAttributedString*, STUWritingDirection,
                                         const STUCancellationFlag*,
                                         FunctionRef<void*(UInt)> alloc);

  ~ShapedString();

private:
  static constexpr Int sanitizerGap = STU_USE_ADDRESS_SANITIZER ? 8 : 0;

  explicit ShapedString(NSAttributedString *attributedString, Int32 stringLength,
                        STUWritingDirection defaultBaseWritingDirection,
                        bool defaultBaseWritingDirectionWasUsed,
                        ArrayRef<const Paragraph> paragraphs,
                        ArrayRef<const TruncationScope> truncationScopes,
                        ArrayRef<const ColorRef> colors,
                        ArrayRef<const ColorHashBucket> colorHashBuckets,
                        ArrayRef<const FontRef> fonts,
                        ArrayRef<const Byte> textStyleDataIncludingTerminator);
};

} // stu_label

