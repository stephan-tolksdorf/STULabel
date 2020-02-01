// Copyright 2017–2018 Stephan Tolksdorf

#import "ShapedString.hpp"

#import "STULabel/STUObjCRuntimeWrappers.h"
#import "STULabel/STUStartEndRange-Internal.hpp"
#import "STULabel/STUTextAttributes-Internal.hpp"

#import "CancellationFlag.hpp"
#import "InputClamping.hpp"
#import "NSAttributedStringRef.hpp"
#import "Once.hpp"
#import "TextFrameLayouter.hpp"
#import "TextStyleBuffer.hpp"
#import "ThreadLocalAllocator.hpp"
#import "UnicodeCodePointProperties.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

NSWritingDirection detectBaseWritingDirection(const NSStringRef& string, Range<Int> range,
                                              SkipIsolatedText skipIsolatedText)
{
  NSWritingDirection result = NSWritingDirectionNatural;
  NSInteger isolateCounter = 0;
  string.indexOfFirstCodePointWhere(range, [&](Char32 cp) -> bool {
    const BidiStrongType bt = bidiStrongType(cp);
    switch (bt) {
    case BidiStrongType::none: return false;
    case BidiStrongType::ltr:
    case BidiStrongType::rtl:
      if (isolateCounter != 0) return false;
      result = bt == BidiStrongType::ltr ? NSWritingDirectionLeftToRight
                                         : NSWritingDirectionRightToLeft;
      return true;
    case BidiStrongType::isolate:
      if (skipIsolatedText) {
        isolateCounter += cp == 0x2069 ? -1 : 1;
      }
      return false;
    }
    __builtin_trap();
  });
  return result;
}

struct ScanStatus {
  int32_t stringLength;
  bool needToFixParagraphStyles;
  bool defaultBaseWritingDirectionWasUsed;
};

static ScanStatus scanAttributedString(
                    NSAttributedString* __unsafe_unretained __nonnull nsAttributedString,
                    const STUWritingDirection defaultBaseWritingDirection,
                    TempVector<ShapedString::Paragraph>& paragraphs,
                    TempVector<TruncationScope>& truncationScopes,
                    TextStyleBuffer& textStyleBuffer)
{
  TempStringBuffer stringBuffer{paragraphs.allocator()};
  NSAttributedStringRef attributedString{nsAttributedString, Ref{stringBuffer}};
  STU_CHECK_MSG(attributedString.string.count() < (1 << 30),
                "The string must have length less than 2^30.");
  const Int32 stringLength = narrow_cast<Int32>(attributedString.string.count());

  STU_DEBUG_ASSERT(paragraphs.isEmpty());

  ScanStatus status {
    .stringLength = stringLength ,
    .needToFixParagraphStyles = false,
    .defaultBaseWritingDirectionWasUsed = false
  };

  Int32 start = 0;
  Range<Int> attributesRange = {};
  STUTruncationScope* __unsafe_unretained previousTruncationScopeAttribute = nil;
  NSDictionary<NSAttributedStringKey, id>* __unsafe_unretained attributes = nil;
  TextFlags lastTextFlags = TextFlags{0};
  TextStyleBuffer::ParagraphAttributes pas;

  while (start != stringLength) {
    ShapedString::Paragraph& para = paragraphs.append(uninitialized);

    // Find the end of the paragraph.
    bool isCR = false;
    Int32 end = narrow_cast<Int32>(attributedString.string.indexOfFirstUTF16CharWhere(
                                     Range{start, stringLength}, [&isCR](Char16 ch) -> bool
                                   {
                                      switch (ch) {
                                      case 0xD: // CR
                                        isCR = true;
                                        // Fall through.
                                        [[fallthrough]];
                                      case 0xA:    // LF
                                      case 0x2029: // PS
                                        return true;
                                      default:
                                       return false;
                                      }
                                    }));
    const Int32 terminatorStart = end;
    if (end < stringLength) {
      end += 1;
      if (isCR && end < stringLength && attributedString.string[end] == '\n') {
        // This is a CR LF terminator.
        end += 1;
      }
    }
    para.stringRange.start = start;
    para.stringRange.end = end;
    para.terminatorStringLength = narrow_cast<UInt8>(end - terminatorStart);
    const bool isEmpty = start == terminatorStart;
    para.textStylesOffset = narrow_cast<UInt32>(textStyleBuffer.data().count());
    para.paragraphStyleNeededFix = false;
    if (attributesRange.end == start) {
      attributes = attributedString.attributesAtIndex(start, OutEffectiveRange{attributesRange});
      lastTextFlags = textStyleBuffer.encodeStringRangeStyle(attributesRange, attributes, Out{pas});
    }

    if (pas.truncationScope != previousTruncationScopeAttribute) {
      if (previousTruncationScopeAttribute) {
        TruncationScope& scope = truncationScopes[$ - 1];
        scope.stringRange.end = start;
        scope.truncatableStringRange.end = min(scope.truncatableStringRange.end, start);
        scope.finalLineTerminatorUTF16Length = paragraphs[$ - 2].terminatorStringLength;
      }
      if (pas.truncationScope) {
        Range<Int32> truncatableStringRange = {start, maxValue<Int32>};
        if (pas.truncationScope->_truncatableStringRange.length != 0) {
          if (STU_LIKELY(para.stringRange.contains(pas.truncationScope->_truncatableStringRange))) {
            truncatableStringRange = Range<Int32>(pas.truncationScope->_truncatableStringRange);
          } else {
            NSLog(@"ERROR: Ignoring STUTruncationScope.truncatableStringRange that"
                   " exceeds the bounds of the paragraph the attribute is applied to.");
          #if STU_DEBUG
            __builtin_trap();
          #endif
          }
        }
        truncationScopes.append(TruncationScope{
          .stringRange = {start, -1},
          .truncatableStringRange = truncatableStringRange,
          .maxLineCount = pas.truncationScope->_maximumNumberOfLines,
          .lastLineTruncationMode = pas.truncationScope->_lastLineTruncationMode,
          .truncationToken = pas.truncationScope->_fixedTruncationToken
        });
      }
      previousTruncationScopeAttribute = pas.truncationScope;
    } else if (pas.truncationScope
               && truncationScopes[$ - 1].truncatableStringRange.end != maxValue<Int32>)
    {
      NSLog(@"ERROR: Ignoring truncatableStringRange of STUTruncationScope that is applied to"
            " multiple paragraphs.");
    #if STU_DEBUG
      __builtin_trap();
    #else
      truncationScopes[$ - 1].truncatableStringRange =
        Range{truncationScopes[$ - 1].stringRange.start, maxValue<Int32>};
    #endif
    }

    bool hasTruncationScope = pas.truncationScope;
    // Check if need to create a truncation scope to implement the NSParagraphStyle's lineBreakMode.
    if (!hasTruncationScope && pas.style) {
      const NSLineBreakMode lineBreakMode = pas.style.lineBreakMode;
      switch (lineBreakMode) {
      case NSLineBreakByWordWrapping: // The default.
      case NSLineBreakByCharWrapping: // Not supported.
      case NSLineBreakByClipping:     // Not supported.
        break;
      case NSLineBreakByTruncatingHead:
      case NSLineBreakByTruncatingTail:
      case NSLineBreakByTruncatingMiddle:
        static_assert((int)NSLineBreakByTruncatingHead   - 3 == (int)kCTLineTruncationStart);
        static_assert((int)NSLineBreakByTruncatingTail   - 3 == (int)kCTLineTruncationEnd);
        static_assert((int)NSLineBreakByTruncatingMiddle - 3 == (int)kCTLineTruncationMiddle);
        truncationScopes.append(TruncationScope{
          .stringRange = para.stringRange,
          .truncatableStringRange = para.stringRange,
          .lastLineTruncationMode = static_cast<CTLineTruncationType>(lineBreakMode - 3),
          .finalLineTerminatorUTF16Length = static_cast<UInt8>(para.terminatorStringLength)});
        hasTruncationScope = true;
        break;
      }
    }

    para.truncationScopeIndex = !hasTruncationScope ? -1
                              : narrow_cast<Int32>(truncationScopes.count() - 1);

    NSParagraphStyle* __unsafe_unretained const paraStyle = pas.style;

    NSWritingDirection baseWritingDirection = paraStyle ? paraStyle.baseWritingDirection
                                                        : NSWritingDirectionNatural;
    const bool baseWritingDirectionWasNatural = baseWritingDirection == NSWritingDirectionNatural;
    if (baseWritingDirectionWasNatural) {
      if (pas.hasWritingDirectionAttribute) {
        // CoreText also takes into account the writing directions set via the NSWritingDirection
        // attribute when detecting the base paragraph writing direction (but apparently only of the
        // outermost nesting context). This seems to contravene the spirit of the Bidi rules and
        // would further complicate our code, so we don't imitate this behaviour. In order to ensure
        // that CoreText assumes the same base writing direction, we fix the paragraph style.
        para.paragraphStyleNeededFix = !isEmpty;
      }
      const bool isAtLeastIOS10 = NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max;
      baseWritingDirection = detectBaseWritingDirection(attributedString.string, para.stringRange,
                                                        SkipIsolatedText{isAtLeastIOS10});
      if (baseWritingDirection == NSWritingDirectionNatural) {
        baseWritingDirection = NSWritingDirection(defaultBaseWritingDirection);
        status.defaultBaseWritingDirectionWasUsed = true;
        // CoreText seems to assume LTR if there is no character with a strong Bidi class...
        // ... but it's unclear whether we can rely on that, so we always fix the paragraph style.
        para.paragraphStyleNeededFix = !isEmpty;
      }
    }
    para.baseWritingDirection = static_cast<STUWritingDirection>(baseWritingDirection);
    LineHeightParams& lineHeightParams = para.lineHeightParams;
    if (!paraStyle) {
      lineHeightParams.lineHeightMultiple = 1;
      lineHeightParams.minLineHeight = 0;
      lineHeightParams.maxLineHeight = maxValue<Float32>;
      lineHeightParams.minLineSpacing = 0;
      para.hyphenationFactor = 0;
      para.alignment = NSTextAlignmentNatural;
      para.paddingTop = 0;
      para.paddingBottom = 0;
    } else {
      const CGFloat lineHeightMultiple = paraStyle.lineHeightMultiple;
      if (lineHeightMultiple > 0) {
        lineHeightParams.lineHeightMultiple = narrow_cast<Float32>(lineHeightMultiple);
      } else {
        lineHeightParams.lineHeightMultiple = 1;
      }
      const CGFloat maxLineHeight = paraStyle.maximumLineHeight;
      lineHeightParams.maxLineHeight = maxLineHeight > 0 ? narrow_cast<Float32>(maxLineHeight)
                                     : maxValue<Float32>;
      lineHeightParams.minLineHeight =
        min(narrow_cast<Float32>(clampNonNegativeFloatInput(paraStyle.minimumLineHeight)),
            lineHeightParams.maxLineHeight);
      lineHeightParams.minLineSpacing = narrow_cast<Float32>(
                                          clampNonNegativeFloatInput(paraStyle.lineSpacing));

      para.hyphenationFactor = clamp(0.f, paraStyle.hyphenationFactor, 1.f);

      NSTextAlignment alignment = clampTextAlignment(paraStyle.alignment);
      if (!baseWritingDirectionWasNatural && alignment == NSTextAlignmentNatural) {
        alignment = baseWritingDirection == NSWritingDirectionLeftToRight
                  ? NSTextAlignmentLeft : NSTextAlignmentRight;
      }
      para.alignment = alignment;
      para.paddingTop = narrow_cast<Float32>(clampNonNegativeFloatInput(
                                               paraStyle.paragraphSpacingBefore));
      para.paddingBottom = narrow_cast<Float32>(clampNonNegativeFloatInput(
                                                  paraStyle.paragraphSpacing));
    }
    Float32 nonInitialHeadIndent;
    Float32 nonInitialTailIndent;
    Float32 initialHeadIndent;
    if (!paraStyle) {
      nonInitialHeadIndent = 0;
      nonInitialTailIndent = 0;
      initialHeadIndent = 0;
    } else {
      nonInitialHeadIndent = narrow_cast<Float32>(clampNonNegativeFloatInput(paraStyle.headIndent));
      nonInitialTailIndent = narrow_cast<Float32>(clampNonNegativeFloatInput(-paraStyle.tailIndent));
      initialHeadIndent = narrow_cast<Float32>(clampNonNegativeFloatInput(
                                                 paraStyle.firstLineHeadIndent));
    }
    if (!pas.extraStyle) {
      para.firstLineOffsetType = STUOffsetOfFirstBaselineFromDefault;
      para.firstLineOffset = 0;
      para.minBaselineDistance = 0;
    } else {
      para.firstLineOffsetType = pas.extraStyle->firstLineOffsetType;
      para.firstLineOffset = narrow_cast<Float32>(pas.extraStyle->firstLineOffset);
      para.minBaselineDistance = narrow_cast<Float32>(pas.extraStyle->minimumBaselineDistance);
    }
    Float32 initialTailIndent;
    if (pas.extraStyle && pas.extraStyle->numberOfInitialLines > 0) {
      para.maxNumberOfInitialLines = narrow_cast<Int32>(min(pas.extraStyle->numberOfInitialLines,
                                                            maxValue<Int32>));
      initialHeadIndent = narrow_cast<Float32>(pas.extraStyle->initialLinesHeadIndent);
      initialTailIndent = -narrow_cast<Float32>(pas.extraStyle->initialLinesTailIndent);
    } else {
      para.maxNumberOfInitialLines = 1;
      initialTailIndent = nonInitialTailIndent;
    }
    const Float32 initialExtraHeadIndent = initialHeadIndent - nonInitialHeadIndent;
    const Float32 initialExtraTailIndent = initialTailIndent - nonInitialTailIndent;
    const Float32 commonHeadIndent = min(initialHeadIndent, nonInitialHeadIndent);
    const Float32 commonTailIndent = min(initialTailIndent, nonInitialTailIndent);
    para.isIndented = initialHeadIndent != 0 || nonInitialHeadIndent != 0
                   || initialTailIndent != 0 || nonInitialTailIndent != 0;
    if (baseWritingDirection == NSWritingDirectionLeftToRight) {
      para.commonLeftIndent = commonHeadIndent;
      para.commonRightIndent = commonTailIndent;
      para.initialExtraLeftIndent = initialExtraHeadIndent;
      para.initialExtraRightIndent = initialExtraTailIndent;
    } else {
      para.commonLeftIndent = commonTailIndent;
      para.commonRightIndent = commonHeadIndent;
      para.initialExtraLeftIndent = initialExtraTailIndent;
      para.initialExtraRightIndent = initialExtraHeadIndent;
    }

    TextFlags textFlags = lastTextFlags;
    while (attributesRange.end < end) {
      attributes = attributedString.attributesAtIndex(attributesRange.end,
                                                      OutEffectiveRange{attributesRange});
      lastTextFlags = textStyleBuffer.encodeStringRangeStyle(attributesRange, attributes, Out{pas});
      textFlags |= lastTextFlags;
      if (pas.hasWritingDirectionAttribute && baseWritingDirectionWasNatural) {
        para.paragraphStyleNeededFix = true;
      }
    }
    para.textFlags = stuTextFlags(textFlags);
    status.needToFixParagraphStyles |= para.paragraphStyleNeededFix;
    start = end;
  }
  // If the last paragraph ends with a terminator, TextKit behaves as if there was an empty
  // paragraph afterwards, but we don't.
  textStyleBuffer.addStringTerminatorStyle();
  if (previousTruncationScopeAttribute) {
    TruncationScope& scope = truncationScopes[$ - 1];
    scope.stringRange.end = start;
    scope.truncatableStringRange.end = min(scope.truncatableStringRange.end, start);
    scope.finalLineTerminatorUTF16Length = paragraphs[$ - 1].terminatorStringLength;
  }
  return status;
}

static void fixParagraphStyles(NSMutableAttributedString* const attributedString,
                               const ArrayRef<const ShapedString::Paragraph> paragraphs)
{
  for (Int i = 0; i < paragraphs.count(); ++i) {
    const auto& para = paragraphs[i];
    if (!para.paragraphStyleNeededFix) continue;
    NSRange range;
    NSParagraphStyle* const style = [attributedString attribute:NSParagraphStyleAttributeName
                                                        atIndex:sign_cast(para.stringRange.start)
                                                 effectiveRange:&range];
    NSMutableParagraphStyle* const newStyle = style ? [style mutableCopy]
                                                    : [[NSMutableParagraphStyle alloc] init];
    const auto writingDirection = para.baseWritingDirection;
    newStyle.baseWritingDirection = NSWritingDirection(writingDirection);
    const NSUInteger rangeEnd = range.location + range.length;
    NSUInteger paraStringRangeEnd;
    while (rangeEnd > (paraStringRangeEnd = sign_cast(paragraphs[i].stringRange.end)) // Assignment
           && paragraphs[i + 1].baseWritingDirection == writingDirection)
    {
      ++i;
    }
    range.length = paraStringRangeEnd - range.location;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:newStyle range:range];
  }
}

static void initializeParagraphMinFontMetrics(const ArrayRef<ShapedString::Paragraph> paragraphs,
                                              const TextStyle* style,
                                              const ArrayRef<const FontMetrics> fontMetrics)
{
  const TextStyle* nextStyle = &style->next();
  Int32 nextIndex = nextStyle->stringIndex();
  for (ShapedString::Paragraph& para : paragraphs) {
    while (nextIndex < para.stringRange.start) {
      style = nextStyle;
      nextStyle = &style->next();
      nextIndex = nextStyle->stringIndex();
    }
    MinFontMetrics minMetrics{uninitialized};
    {
      const FontMetrics& metrics = !style->hasAttachment()
                                 ? fontMetrics[style->fontIndex().value]
                                 : style->attachmentInfo()->attribute->_metrics;
      if (STU_LIKELY(!style->hasBaselineOffset())) {
        minMetrics = metrics;
      } else {
        minMetrics = metrics.adjustedByBaselineOffset(style->baselineOffset());
      }
    }
    // The line terminator only influences the style if it is the only text in the paragraph.
    const Int32 endIndex = para.stringRange.end - para.terminatorStringLength;
    while (nextIndex < endIndex) {
      style = nextStyle;
      nextStyle = &style->next();
      nextIndex = nextStyle->stringIndex();
      const FontMetrics& metrics = !style->hasAttachment()
                                 ? fontMetrics[style->fontIndex().value]
                                 : style->attachmentInfo()->attribute->_metrics;
      if (STU_LIKELY(!style->hasBaselineOffset())) {
        minMetrics.aggregate(metrics);
      } else {
        minMetrics.aggregate(metrics.adjustedByBaselineOffset(style->baselineOffset()));
      }
    }
    para.effectiveMinLineHeightInfo_[UInt{STUTextLayoutModeDefault}] =
      TextFrameLayouter::minLineHeightInfo<STUTextLayoutModeDefault>
                                          (para.lineHeightParams, minMetrics);
    para.effectiveMinLineHeightInfo_[UInt{STUTextLayoutModeTextKit}] =
      TextFrameLayouter::minLineHeightInfo<STUTextLayoutModeTextKit>
                                          (para.lineHeightParams, minMetrics);
  }
}

ShapedString* __nullable
  ShapedString::create(NSAttributedString* __unsafe_unretained const originalAttributedString,
                       const STUWritingDirection defaultBaseWritingDirection,
                       const STUCancellationFlag* cancellationFlagPointer,
                       const FunctionRef<void*(UInt)> alloc)
{
  // Make sure the string is immutable.
  NSAttributedString* attributedString = [originalAttributedString copy];

  const STUCancellationFlag& cancellationFlag = *(cancellationFlagPointer
                                                  ?: &CancellationFlag::neverCancelledFlag);
  if (isCancelled(cancellationFlag)) return nullptr;

  TempVector<Paragraph> paragraphs{Capacity{8}};
  TempVector<TruncationScope> truncationScopes{Capacity{4}, paragraphs.allocator()};
  LocalFontInfoCache fontInfoCache;
  TextStyleBuffer textStyleBuffer{Ref{fontInfoCache}, paragraphs.allocator()};

  const auto status = scanAttributedString(attributedString, defaultBaseWritingDirection,
                                           paragraphs, truncationScopes, textStyleBuffer);
  // We must apply any attachment attribute fixes before checking for cancellation and returning
  // since otherwise we could leak memory.
  if (status.needToFixParagraphStyles | textStyleBuffer.needToFixAttachmentAttributes()) {
    NSMutableAttributedString* const mutableString = [attributedString mutableCopy];
    if (status.needToFixParagraphStyles) {
      if (isCancelled(cancellationFlag)) return nullptr;
      fixParagraphStyles(mutableString, paragraphs);
    }
    // To reliably work around rdar://36622225 the attachments have to be fixed after the paragraph
    // styles.
    if (textStyleBuffer.needToFixAttachmentAttributes()) {
      textStyleBuffer.fixAttachmentAttributesIn(mutableString);
    }
    if (isCancelled(cancellationFlag)) return nullptr;
    // The CTTypesetter will make a copy of the attributedString. By making it immutable now
    // we can turn that later copy into a retain and thus reduce memory usage.
    attributedString = [mutableString copy];
  }
  if (isCancelled(cancellationFlag)) return nullptr;

  const ArrayRef<const ColorRef> colors = textStyleBuffer.colors();
  const ArrayRef<const ColorHashBucket> colorHashBuckets = textStyleBuffer.colorHashBuckets();

  const UInt size = sizeof(ShapedString)
                  + paragraphs.arraySizeInBytes() + sanitizerGap
                  + truncationScopes.arraySizeInBytes() + sanitizerGap
                  + sizeof(FontMetrics)*sign_cast(textStyleBuffer.fonts().count()) + sanitizerGap
                  + colors.arraySizeInBytes() + sanitizerGap
                  + sizeof(ColorHashBucket)*sign_cast(colors.count()) + sanitizerGap
                  + sign_cast(textStyleBuffer.data().count()) + sanitizerGap;

  return new (alloc(size))
             ShapedString{attributedString, status.stringLength,
                          defaultBaseWritingDirection, status.defaultBaseWritingDirectionWasUsed,
                          paragraphs, truncationScopes, colors, colorHashBuckets,
                          textStyleBuffer.fonts(), textStyleBuffer.data()};
}

static
CTTypesetter* createTypesetter(CFAttributedStringRef string, Int32 stringLength) CF_RETURNS_RETAINED {
#if defined(kCTVersionNumber10_14)
  STU_STATIC_CONST_ONCE(CFDictionaryRef, options, ({
    CFDictionaryRef options = nullptr;
    if (@available(iOS 12.0, macOS 10.14, *)) {
       // Without this option CTTypesetter stops working properly for texts with a UTF-16 length
       // longer than 4096. If not setting this option is important to protect against denial-of-
       // service attacks, then we may have to split up the ShapedString into multiple typesetters.
       // However, currently there is no documentation on what this option does exactly, and just
       // limiting the paragraph length (as opposed to, say, the grapheme cluster length or bidi
       // context stack depth) seems incredibly blunt.
       const void* keys[1] = {kCTTypesetterOptionAllowUnboundedLayout};
       const void* values[1] = {kCFBooleanTrue};
       options = CFDictionaryCreate(nil, keys, values, 1,
                                    &kCFTypeDictionaryKeyCallBacks,
                                    &kCFTypeDictionaryValueCallBacks);
    }
    options;
  }));
  if (stringLength > 4096 && options) {
    return CTTypesetterCreateWithAttributedStringAndOptions(string, options);
  }
#else
  discard(stringLength);
#endif
  return CTTypesetterCreateWithAttributedString(string);
}

ShapedString::ShapedString(NSAttributedString* const attributedString, const Int32 stringLength,
                           const STUWritingDirection defaultBaseWritingDirection,
                           const bool defaultBaseWritingDirectionWasUsed,
                           const ArrayRef<const Paragraph> paragraphs,
                           const ArrayRef<const TruncationScope> truncationScopes,
                           const ArrayRef<const ColorRef> colors,
                           const ArrayRef<const ColorHashBucket> colorHashBuckets,
                           const ArrayRef<const FontRef> fonts,
                           const ArrayRef<const Byte> textStyleDataIncludingTerminator)
: attributedString{attributedString},
  typesetter{createTypesetter((__bridge CFAttributedStringRef)attributedString, stringLength),
              ShouldIncrementRefCount{false}},
  stringLength{stringLength},
  paragraphCount{narrow_cast<Int32>(paragraphs.count())},
  truncationScopeCount{narrow_cast<Int32>(truncationScopes.count())},
  fontCount{narrow_cast<UInt16>(fonts.count())},
  colorCount{narrow_cast<UInt16>(colors.count())},
  defaultBaseWritingDirection{defaultBaseWritingDirection},
  defaultBaseWritingDirectionWasUsed{defaultBaseWritingDirectionWasUsed},
  textStylesSize{textStyleDataIncludingTerminator.count()}
{
  const ArraysRef tas = arrays();

#if STU_USE_ADDRESS_SANITIZER
  sanitizer::poison((Byte*)tas.paragraphs.end(), sanitizerGap);
  sanitizer::poison((Byte*)tas.truncationSopes.end(), sanitizerGap);
  sanitizer::poison((Byte*)tas.colors.end(), sanitizerGap);
  sanitizer::poison((Byte*)tas.fontMetrics.end(), sanitizerGap);
  sanitizer::poison((Byte*)(tas.textStyles.dataBegin() + textStylesSize), sanitizerGap);
#endif

  using array_utils::copyConstructArray;

  copyConstructArray(paragraphs, const_array_cast(tas.paragraphs).begin());

  copyConstructArray(truncationScopes, const_array_cast(tas.truncationSopes).begin());

  {
    ArrayRef<FontMetrics> fontMetrics = const_array_cast(tas.fontMetrics);
    Int i = 0;
    for (const FontRef& font : fonts) {
      new (&fontMetrics[i++]) FontMetrics{CachedFontInfo::get(font).metrics};
    }
  }
  if (!colors.isEmpty()) {
    for (auto& color : colors) {
      incrementRefCount(color.cgColor());
    }
    copyConstructArray(colors, const_array_cast(tas.colors).begin());
    const ArrayRef<ColorHashBucket> thisHashBuckets = const_array_cast(tas.colorHashBuckets);
    Int i = 0;
    for (auto& bucket : colorHashBuckets) {
      if (bucket.isEmpty()) continue;
      thisHashBuckets[i] = bucket;
      ++i;
    }
    STU_ASSERT(i == thisHashBuckets.count());
  }
  copyConstructArray(textStyleDataIncludingTerminator,
                     const_cast<Byte*>(tas.textStyles.dataBegin()));

  initializeParagraphMinFontMetrics(const_array_cast(tas.paragraphs), tas.textStyles.firstStyle,
                                    tas.fontMetrics);
}

ShapedString::~ShapedString() {
  const ArraysRef tas = arrays();
  for (ColorRef color : tas.colors.reversed()) {
    decrementRefCount(color.cgColor());
  }
#if STU_USE_ADDRESS_SANITIZER
  sanitizer::unpoison((Byte*)tas.paragraphs.end(), sanitizerGap);
  sanitizer::unpoison((Byte*)tas.truncationSopes.end(), sanitizerGap);
  sanitizer::unpoison((Byte*)tas.colors.end(), sanitizerGap);
  sanitizer::unpoison((Byte*)tas.fontMetrics.end(), sanitizerGap);
  sanitizer::unpoison((Byte*)(tas.textStyles.dataBegin() + textStylesSize), sanitizerGap);
#endif
}

} // namespace stu_label

