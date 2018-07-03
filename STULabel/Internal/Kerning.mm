// Copyright 2017–2018 Stephan Tolksdorf

#import "Kerning.hpp"

#import "Once.hpp"

namespace stu_label {

GlyphForKerningPurposes
GlyphForKerningPurposes::find(GlyphSpan glyphSpan, const NSAttributedStringRef& attributedString,
                              GlyphPositionInSpan position)
{
  const CTRunStatus status = glyphSpan.run().status();
  const bool isNonMonotonic = status & kCTRunStatusNonMonotonic;
  const bool isRightToLeft = status & kCTRunStatusRightToLeft;

  const NSStringRef& string = attributedString.string;

  CTFont* const font = glyphSpan.run().font();

  GlyphForKerningPurposes result = {
    .font = font,
    .isRightToLeftRun = isRightToLeft
  };

  // The implemention of this function is likely overly defensive.

  const GlyphSpan run = glyphSpan.run();
  run.ensureCountIsCached();
  glyphSpan.assumeFullRunGlyphCountIs(run.count());
  const Range<Int> glyphRange = glyphSpan.glyphRange();
  if (STU_UNLIKELY(glyphRange.isEmpty())) return result;

  Range<Int> stringRange = run.run().stringRange().intersection(Range{0, string.count()});
  if (STU_UNLIKELY(stringRange.isEmpty())) return result;

  result.attributes = attributedString.attributesAtIndex(stringRange.start);
  result.hasDelegate = [result.attributes
                          objectForKey:(__bridge NSAttributedStringKey)kCTRunDelegateAttributeName];
  if (STU_UNLIKELY(result.hasDelegate)) return result;

  StringIndicesArray runStringIndicesArray;
  const GlyphSpan::GlyphsRef runGlyphs = run.glyphs();
  GlyphSpan::StringIndicesRef runStringIndices = run.stringIndices();

  if (STU_UNLIKELY(isNonMonotonic) && glyphRange.count() != run.count()) {
    if (!runStringIndices.hasArray()) {
      runStringIndicesArray = run.copiedStringIndicesArray();
      runStringIndices.assignArray(runStringIndicesArray);
    }
    Int minIndex = stringRange.end;
    STU_DISABLE_LOOP_UNROLL
    for (const Int index : runStringIndices.array()[glyphRange]) {
      minIndex = min(minIndex, index);
    }
    stringRange.start = minIndex;
  } else if (!isRightToLeft) {
    if (glyphRange.start != 0) {
      stringRange.start = runStringIndices[glyphRange.start];
    }
  } else { // isRightToLeft
    if (glyphRange.end < run.count()) {
      stringRange.start = runStringIndices[glyphRange.end - 1];
    }
  }

  Int start, end, d;
  if (position == rightmostGlyph || (position == lastGlyphInStringOrder && !isRightToLeft)) {
    start = glyphRange.end - 1; end = glyphRange.start - 1; d = -1;
  } else {
    start = glyphRange.start; end = glyphRange.end; d = 1;
  }

  Float64 width = 0;
  for (Int i = start; i != end; i += d) {
    const Float64 glyphWidth = run[{i, Count{1}}].typographicWidth();
    width += glyphWidth;
    if (glyphWidth <= 0 || width <= 0) continue;
    const Int stringIndex = runStringIndices[i];
    if (!stringRange.contains(stringIndex)) continue;
    const CGGlyph glyph = runGlyphs[i];
    // Here we rely on CoreText returning a nonpositive width for glyphs that behave like nonspacing
    // marks.
    CGSize unkernedAdvance;
    const Float64 unkernedWidth = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal,
                                                             &glyph, &unkernedAdvance, 1);
    if (unkernedWidth <= 0) continue;
    stringRange.start = stringIndex;
    if (stringRange.count() > 1) {
      if (!isNonMonotonic) {
        const Int end1 = isRightToLeft ? -1 : run.count();
        const Int d1 = isRightToLeft ? -1 : 1;
        for (Int i1 = i + d1; i1 != end1; i1 += d1) {
          const Int stringIndex1 = runStringIndices[i1];
          if (stringIndex1 > stringRange.start) {
            stringRange.end = min(stringRange.end, stringIndex1);
            break;
          }
        }
      } else {
        if (!runStringIndices.hasArray()) {
          runStringIndicesArray = run.copiedStringIndicesArray();
          runStringIndices.assignArray(runStringIndicesArray);
        }
        STU_DISABLE_LOOP_UNROLL
        for (const Int index : runStringIndices.array()) {
          if (index > stringIndex) {
            stringRange.end = min(stringRange.end, index);
          }
        }
      }
    }
    if (stringRange.count() > 1) {
      const Int endIndex = string.indexOfEndOfLastCodePointWhere(stringRange, isNotIgnorable);
      if (stringRange.start < endIndex) {
        stringRange.end = endIndex;
      } else { // This shouldn't happen.
        STU_DEBUG_ASSERT(false);
      }
    }
    result.stringRange = stringRange;
    result.glyph = glyph;
    result.width = width;
    result.unkernedWidth = unkernedWidth;
    break;
  } // for
  return result;
}

STU_NO_INLINE
static CFDictionaryRef createTypesetterOptionsWithEmbeddingLevel(const int embedddingLevel)
                         CF_RETURNS_RETAINED
{
   const void* keys[1] = {kCTTypesetterOptionForcedEmbeddingLevel};
   const void* values[1] = {CFNumberCreate(nullptr, kCFNumberIntType, &embedddingLevel)};
   return CFDictionaryCreate(nullptr, keys, values, 1,
                             &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static CFDictionaryRef typesetterOptions(bool rightToLeft) {
  if (!rightToLeft) {
    STU_STATIC_CONST_ONCE(CFDictionaryRef, ltr, createTypesetterOptionsWithEmbeddingLevel(0));
    return ltr;
  } else {
    STU_STATIC_CONST_ONCE(CFDictionaryRef, rtl, createTypesetterOptionsWithEmbeddingLevel(1));
    return rtl;
  }
}

#if STU_TRUNCATION_TOKEN_KERNING

Optional<Float64> kerningAdjustment(const GlyphForKerningPurposes& glyph0,
                                    const NSStringRef& string0,
                                    const GlyphForKerningPurposes& glyph1,
                                    const NSStringRef& string1)
{
  if (!glyph0.glyph || !glyph1.glyph) return none;

  const BidiStrongType b0 = bidiStrongType(string0.codePointAtUTF16Index(glyph0.stringRange.start));
  const BidiStrongType b1 = bidiStrongType(string1.codePointAtUTF16Index(glyph1.stringRange.start));

  const bool isRightToLeft = (b0 == BidiStrongType::rtl && b1 != BidiStrongType::ltr)
                          || (b0 != BidiStrongType::ltr && b1 == BidiStrongType::rtl);

  const Int glyph0StringLength = glyph0.stringRange.count();
  const Int glyph1StringLength = glyph1.stringRange.count();
  const Int bufferLength = glyph0StringLength + glyph1StringLength;

  TempArray<Char16> buffer{uninitialized, Count{bufferLength}};

  const Int i0 = !isRightToLeft ? 0 : glyph1StringLength;
  const Int i1 = !isRightToLeft ? glyph0StringLength : 0;

  const Range<Int> glyph0BufferRange = {i0, Count{glyph0StringLength}};
  const Range<Int> glyph1BufferRange = {i1, Count{glyph1StringLength}};

  string0.copyUTF16Chars(glyph0.stringRange, buffer[glyph0BufferRange]);
  string1.copyUTF16Chars(glyph1.stringRange, buffer[glyph1BufferRange]);

  // It's a pity that we can't get the kerning info for two glyphs out of Core Text without
  // incurring dozens of allocations, atomic reference count operations and dictionary lookups.

  // We can't use a custom pool CFAllocator here because CTTypesetter may keep a reference to
  // a string or attribute dictionary in some global or thread-local cache.

  const auto bufferString = CFStringCreateWithCharacters(nullptr,
                              reinterpret_cast<const UTF16Char*>(buffer.begin()), bufferLength);

  const auto glyph0String = CFStringCreateWithCharacters(nullptr,
                              reinterpret_cast<const UTF16Char*>(&buffer[i0]), glyph0StringLength);
  const auto glyph1String = CFStringCreateWithCharacters(nullptr,
                              reinterpret_cast<const UTF16Char*>(&buffer[i1]), glyph1StringLength);

  const auto glyph0Info = CTGlyphInfoCreateWithGlyph(*glyph0.glyph, glyph0.font, glyph0String);
  const auto glyph1Info = CTGlyphInfoCreateWithGlyph(*glyph1.glyph, glyph1.font, glyph1String);

  const auto attributes0 = CFDictionaryCreateMutableCopy(
                             nullptr, sign_cast(glyph0.attributes.count) + 1,
                             (__bridge CFDictionaryRef)glyph0.attributes);

  const auto attributes1 = CFDictionaryCreateMutableCopy(
                             nullptr, sign_cast(glyph1.attributes.count) + 1,
                             (__bridge CFDictionaryRef)glyph1.attributes);

  CFDictionarySetValue(attributes0, kCTFontAttributeName, glyph0.font);
  CFDictionarySetValue(attributes1, kCTFontAttributeName, glyph1.font);
  CFDictionarySetValue(attributes0, kCTGlyphInfoAttributeName, glyph0Info);
  CFDictionarySetValue(attributes1, kCTGlyphInfoAttributeName, glyph1Info);

  const auto attributedString = CFAttributedStringCreateMutable(nullptr, bufferLength);
  CFAttributedStringReplaceString(attributedString, CFRange{}, bufferString);
  CFAttributedStringSetAttributes(attributedString, glyph0BufferRange, attributes0, true);
  CFAttributedStringSetAttributes(attributedString, glyph1BufferRange, attributes1, true);

  const auto typesetter = CTTypesetterCreateWithAttributedStringAndOptions(
                            attributedString, typesetterOptions(isRightToLeft));

  const auto line = CTTypesetterCreateLine(typesetter, CFRange{});
  NSArrayRef<CTRun*> runs = glyphRuns(line);

  Optional<Float64> result = none;
  do {
    if (runs.isEmpty() || runs.count() > 2) break;
    CGGlyph glyphs[2];
    CGSize advances[2];
    const CTRunRef run0 = runs[0];
    const Int count0 = CTRunGetGlyphCount(run0);
    if (count0 > 2) break;
    CTRunGetGlyphs(run0, CFRange{0, count0}, glyphs);
    CTRunGetAdvances(run0, CFRange{0, count0}, advances);
    if (runs.count() == 2) {
      const CTRunRef run1 = runs[1];
      const Int count1 = CTRunGetGlyphCount(run1);
      if (count0 + count1 != 2) break;
      CTRunGetGlyphs(run1, CFRange{0, count1}, glyphs + count0);
      CTRunGetAdvances(run1, CFRange{0, count1}, advances + count0);
    } else {
      if (count0 != 2) break;
    }
    if (glyphs[0] != glyph0.glyph) break;
    if (glyphs[1] != glyph1.glyph) break;
    if (!(advances[0].width > 0)) break;
    if (!(advances[1].width > 0)) break;
    result = advances[0].width - glyph0.width;
  } while (false);

  CFRelease(line);
  CFRelease(typesetter);
  CFRelease(attributedString);
  CFRelease(attributes1);
  CFRelease(attributes0);
  CFRelease(glyph1Info);
  CFRelease(glyph0Info);
  CFRelease(glyph1String);
  CFRelease(glyph0String);
  CFRelease(bufferString);

  return result;
}

#endif

static CFStringRef const hyphenCodePointString = (__bridge CFStringRef)@"\u2010";

HyphenLine createHyphenLine(const NSAttributedStringRef& originalAttributedString,
                            GlyphRunRef trailingRun, Char32 hyphen)
{
  UTF16Char hyphenChars[2];
  const Int hyphenCharsCount = CFStringGetSurrogatePairForLongCharacter(hyphen, hyphenChars)
                             ? 2 : 1;

  const NSStringRef& string = originalAttributedString.string;
  const auto tg = GlyphForKerningPurposes::find(trailingRun, originalAttributedString,
                                                lastGlyphInStringOrder);

  HyphenLine result;
  if (!tg.glyph) {
  NoKerning:;
    // This is the fallback path. It creates a CTLine with just the hyphen and without proper
    // kerning between the hyphen and the preceding character.
    const CFStringRef hyphenString = hyphen == hyphenCodePoint ? hyphenCodePointString
                                   : CFStringCreateWithCharacters(
                                       nullptr, hyphenChars, hyphenCharsCount);
    NSAttributedString* hyphenAttributedString;
    if (!tg.hasDelegate) {
      hyphenAttributedString = [[NSAttributedString alloc]
                                  initWithString:(__bridge NSString*)hyphenString
                                      attributes:tg.attributes];
    } else {
      NSMutableDictionary* newAttributes = [tg.attributes mutableCopy];
      [newAttributes removeObjectForKey:(__bridge NSString*)kCTRunDelegateAttributeName];
      hyphenAttributedString = [[NSAttributedString alloc]
                                  initWithString:(__bridge NSString*)hyphenString
                                      attributes:newAttributes];
    }
    if (hyphen != hyphenCodePoint) {
      CFRelease(hyphenString);
    }
    result.line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)
                                                     hyphenAttributedString);
    result.runIndex = 0;
    result.glyphIndex = -1;
    result.trailingGlyphAdvanceCorrection = 0;
    result.xOffset = 0;
    result.width = typographicWidth(result.line);
    STU_ASSERT(result.width >= 0);
    return result;
  }

  const CGGlyph trailingGlyph = *tg.glyph;

  { // Construct a CTLine with the trailing glyph plus the hyphen.
    const Int glyphStringLength = tg.stringRange.count();
    TempArray<Char16> buffer{uninitialized, Count{glyphStringLength + hyphenCharsCount}};
    string.copyUTF16Chars(tg.stringRange, buffer[{0, Count{glyphStringLength}}]);
    STU_DEBUG_ASSERT(1 <= hyphenCharsCount && hyphenCharsCount <= 2);
    buffer[glyphStringLength] = hyphenChars[0];
    if (hyphenCharsCount == 2) {
      buffer[glyphStringLength + 1] = hyphenChars[1];
    }
    CFString* const bufferString = CFStringCreateWithCharacters(nullptr,
                                     reinterpret_cast<const UTF16Char*>(buffer.begin()),
                                     buffer.count());
    auto* const attributedString = [[NSMutableAttributedString alloc]
                                      initWithString:(__bridge NSString*)bufferString
                                           attributes:tg.attributes];
    CFRelease(bufferString);
    const auto glyphString = CFStringCreateWithCharacters(nullptr,
                               reinterpret_cast<const UTF16Char*>(buffer.begin()),
                               glyphStringLength);
    const auto glyphInfo = CTGlyphInfoCreateWithGlyph(trailingGlyph, tg.font, glyphString);
    CFRelease(glyphString);
    [attributedString addAttribute:(__bridge NSString*)kCTGlyphInfoAttributeName
                             value:(__bridge id)glyphInfo
                              range:NSRange{0, sign_cast(glyphStringLength)}];
    CFRelease(glyphInfo);

    CGGlyph hyphenGlyphs[2];
    const bool fontHasHyphen = CTFontGetGlyphsForCharacters(tg.font, hyphenChars, hyphenGlyphs,
                                                            hyphenCharsCount);
    if (!fontHasHyphen) {
      [attributedString addAttribute:NSFontAttributeName
                               value:originalAttributedString.attributeAtIndex(NSFontAttributeName,
                                                                               tg.stringRange.start)
                               range:NSRange(Range{glyphStringLength, Count{hyphenCharsCount}})];
    }

    const CTTypesetterRef ts = CTTypesetterCreateWithAttributedStringAndOptions(
                                (__bridge CFAttributedStringRef)attributedString,
                                typesetterOptions(tg.isRightToLeftRun));
    result.line = CTTypesetterCreateLine(ts, CFRange{});
    CFRelease(ts);
  }
  auto guard = ScopeGuard{[&]{ CFRelease(result.line); }};

  const NSArrayRef<CTRun*> runs = glyphRuns(result.line);
  Float64 hyphenGlyphAdvance;
  Float64 kernedTrailingGlyphAdvance;
  {
    TempVector<CGSize> advances{Capacity{4}};
    Int nonZeroWidthGlyphCount = 0;
    for (Int i = 0; i < runs.count(); ++i) {
      const GlyphSpan run = runs[i];
      if (run.isEmpty()) continue;
      advances.removeAll();
      advances.append(repeat(uninitialized, run.count()));
      CTRunGetAdvances(run.run().ctRun(), Range{0, run.count()}, &advances[0]);
      for (Int j = 0; j < advances.count(); ++j) {
        const CGFloat width = advances[j].width;
        if (STU_UNLIKELY(width <= 0)) {
          if (width == 0) continue;
          goto NoKerning;
        }
        if (STU_UNLIKELY(nonZeroWidthGlyphCount == 2)) goto NoKerning;
        if (nonZeroWidthGlyphCount++ == !tg.isRightToLeftRun) {
          const Int hyphenStringIndex = run.stringIndexForGlyphAtIndex(j);
          if (hyphenStringIndex < tg.stringRange.count()) goto NoKerning;
          if ((i | j) >= 128) goto NoKerning;
          result.runIndex = narrow_cast<Int8>(i);
          result.glyphIndex = narrow_cast<Int8>(j);
          hyphenGlyphAdvance = width;
        } else {
          const CGGlyph glyph = run[j];
          if (glyph != trailingGlyph) goto NoKerning;
          kernedTrailingGlyphAdvance = width;
        }
      }
    }
    if (nonZeroWidthGlyphCount != 2) goto NoKerning;
  }
  guard.dismiss();

  STU_DISABLE_CLANG_WARNING("-Wconditional-uninitialized")
  result.width = hyphenGlyphAdvance;
  if (!tg.isRightToLeftRun) {
    result.xOffset = kernedTrailingGlyphAdvance;
    result.trailingGlyphAdvanceCorrection = kernedTrailingGlyphAdvance - tg.width;
  } else {
    result.xOffset = 0;
    result.trailingGlyphAdvanceCorrection = 0;
  }
  STU_REENABLE_CLANG_WARNING

  return result;
}


} // namespace stu_label
