// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUShapedString-Internal.hpp"
#import "STULabel/STUTextFrame-Unsafe.h"

#import "Font.hpp"
#import "HashTable.hpp"
#import "NSAttributedStringRef.hpp"
#import "TextStyleBuffer.hpp"

#import "stu/FunctionRef.hpp"

namespace stu_label {

struct SkipIsolatedText : Parameter<SkipIsolatedText> { using Parameter::Parameter; };

NSWritingDirection detectBaseWritingDirection(const NSStringRef&, Range<stu::Int> range,
                                              SkipIsolatedText skipIsolatedText);

struct LineHeightParams {
  stu::Float32 lineHeightMultiple; // > 0
  stu::Float32 minLineHeight; // ≥ 0
  stu::Float32 maxLineHeight; // > 0
  stu::Float32 minLineSpacing; // ≥ 0
};

struct MinLineHeightInfo {
  stu::Float32 minHeight;
  stu::Float32 minHeightWithoutSpacingBelowBaseline;
  stu::Float32 minHeightBelowBaselineWithoutSpacing;
  stu::Float32 minSpacingBelowBaseline;
};

struct TruncationScope {
  Range<stu::Int32> stringRange;
  Range<stu::Int32> truncatableStringRange;
  stu::Int32 maxLineCount;
  CTLineTruncationType lastLineTruncationMode : 8;
  stu::UInt8 finalLineTerminatorUTF16Length;
  NSAttributedString* __unsafe_unretained __nullable truncationToken;
};

using CTTypesetter = RemovePointer<CTTypesetterRef>;

class TextStyleBuffer;

class ShapedString {
public:
  // TODO: Investigate whether spltting up large strings into multiple typesetter would improve
  //       performance. (Note that STULabel views wouldn't benefit from any lazy typesetting, since
  //       they always eagerly compute the full layout size.)

  struct Paragraph {
    Range<stu::Int32> stringRange;

    stu::UInt32 textStylesOffset;
    stu::Int32 truncationScopeIndex; // A negative index indicates there's no truncation scope.
    stu::Int32 maxNumberOfInitialLines;

    NSTextAlignment alignment : 4; // NSTextAlignment's underlying type is the signed NSInteger.
    // The length of the paragraph terminator ("\r", "\n", "\r\n" or "\u2029").
    stu::UInt8 terminatorStringLength : 2;
    bool paragraphStyleNeededFix : 1;
    STUWritingDirection baseWritingDirection : 1;
    STUFirstLineOffsetType firstLineOffsetType : 3;
    bool isIndented : 1;
    STUTextFlags textFlags;

    stu::Float32 hyphenationFactor; // in [0, 1]

    CGFloat commonLeftIndent; // ≥ 0
    CGFloat commonRightIndent; // ≥ 0
    CGFloat initialExtraLeftIndent;
    CGFloat initialExtraRightIndent;

    LineHeightParams lineHeightParams;
    stu::Float32 firstLineOffset;
    stu::Float32 minBaselineDistance; // ≥ 0
    stu::Float32 paddingTop; // ≥ 0
    stu::Float32 paddingBottom; // ≥ 0

    MinLineHeightInfo effectiveMinLineHeightInfo_[2];

    STU_INLINE
    const MinLineHeightInfo& effectiveMinLineHeightInfo(STUTextLayoutMode mode) const {
      STU_DEBUG_ASSERT(static_cast<stu::Int>(mode) <= arrayLength(effectiveMinLineHeightInfo_));
      return effectiveMinLineHeightInfo_[static_cast<stu::Int>(mode)];
    }

    STU_INLINE
    stu::Float32 effectiveMinHeightBelowBaselineWithoutSpacing(STUTextLayoutMode mode) const {
      return effectiveMinLineHeightInfo(mode).minHeightBelowBaselineWithoutSpacing;
    }
  };

  NSAttributedString* const attributedString;
  const RC<CTTypesetter> typesetter;
  const stu::Int32 stringLength;
  const stu::Int32 paragraphCount;
  const stu::Int32 truncationScopeCount;
  const UInt16 fontCount;
  const UInt16 colorCount;
  const STUWritingDirection defaultBaseWritingDirection;
  const bool defaultBaseWritingDirectionWasUsed;
  const stu::Int textStylesSize;
private:
  Paragraph paragraphs_[];

public:
  using ColorHashBucket = TempIndexHashSet<UInt16>::Bucket;

  struct ArraysRef {
    ArrayRef<const Paragraph> paragraphs;
    ArrayRef<const TruncationScope> truncationSopes;
    ArrayRef<const FontMetrics> fontMetrics;
    ArrayRef<const ColorRef> colors;
    ArrayRef<const ColorHashBucket> colorHashBuckets;
    TextStyleSpan textStyles;
  };

  STU_INLINE
  ArraysRef arrays() const {
    static_assert(alignof(Paragraph) == alignof(TruncationScope));
    static_assert(alignof(TruncationScope) >= alignof(FontMetrics));
    static_assert(alignof(FontMetrics) >= alignof(ColorRef));
    static_assert(alignof(ColorRef) >= alignof(ColorHashBucket));
    static_assert(alignof(ColorRef) >= alignof(TextStyle));
    static_assert(sizeof(ColorHashBucket)%alignof(TextStyle) == 0);

    const ArrayRef<const Paragraph> paragraphs{
      paragraphs_, paragraphCount, unchecked
    };
    const ArrayRef<const TruncationScope> truncationScopes{
      (const TruncationScope*)((const Byte*)paragraphs.end() + sanitizerGap),
      truncationScopeCount, unchecked
    };
    const ArrayRef<const FontMetrics> fontMetrics{
      (const FontMetrics*)((const Byte*)truncationScopes.end() + sanitizerGap),
      fontCount, unchecked
    };
    const ArrayRef<const ColorRef> colors{
      (const ColorRef*)((const Byte*)fontMetrics.end() + sanitizerGap),
      colorCount, unchecked
    };
    const ArrayRef<const ColorHashBucket> colorHashBuckets{
      (const ColorHashBucket*)((const Byte*)colors.end() + sanitizerGap),
      colorCount, unchecked
    };
   const auto firstStyle = (const TextStyle*)((const Byte*)colorHashBuckets.end() + sanitizerGap);
   const auto terminatorStyle =
                (const TextStyle*)((const Byte*)firstStyle + textStylesSize
                                   - TextStyle::sizeOfTerminatorWithStringIndex(stringLength));

    return {paragraphs, truncationScopes, fontMetrics, colors, colorHashBuckets,
            TextStyleSpan{.firstStyle = firstStyle, .terminatorStyle = terminatorStyle}};
  };

  static ShapedString* __nullable create(NSAttributedString*, STUWritingDirection,
                                         const STUCancellationFlag*,
                                         FunctionRef<void*(stu::UInt)> alloc);

  ~ShapedString();

private:
  static constexpr stu::Int sanitizerGap = STU_USE_ADDRESS_SANITIZER ? 8 : 0;

  explicit ShapedString(NSAttributedString *attributedString, stu::Int32 stringLength,
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

