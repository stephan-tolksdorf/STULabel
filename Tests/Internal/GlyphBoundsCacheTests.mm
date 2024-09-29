// Copyright 2018 Stephan Tolksdorf

#import "TestUtils.h"

#import "Font.hpp"

#import "GlyphSpan.hpp"

#import <random>

using namespace stu_label;

using FontFace = FontFaceGlyphBoundsCache::FontFace;

@interface GlyphBoundsCacheTests : XCTestCase
@end
@implementation GlyphBoundsCacheTests

- (void)setUp {
  [super setUp];
  self.continueAfterFailure = false;
}

- (stu_label::Rect<CGFloat>)checkGlyphBoundsWithFont:(UIFont*)font glyph:(CGGlyph)glyph
                                               cache:(FontFaceGlyphBoundsCache&)cache
{
  const CGFloat fontSize = font.pointSize;
  const stu_label::Rect<CGFloat> r1 = cache.boundingRect(fontSize, ArrayRef{&glyph, 1}, &CGPointZero);
  const stu_label::Rect<CGFloat> r2 = CTFontGetBoundingRectsForGlyphs((__bridge CTFontRef)font,
                                                                     kCTFontOrientationHorizontal,
                                                                     &glyph, nullptr, 1);
  if (r2.isEmpty()) {
    XCTAssert(r1 == stu_label::Rect<CGFloat>{});
    return r1;
  }
  const CGFloat eps = cache.usesIntBounds() ? epsilon<CGFloat>*(isSame<CGFloat, Float32> ? 2 : 1)
                    : epsilon<Float32>;
  XCTAssertEqualWithAccuracy(r1.x.start, r2.x.start, eps*abs(r2.x.start),
                             @"font: %@ glyph: %i",
                             font, glyph);
  XCTAssertEqualWithAccuracy(r1.y.start, r2.y.start, eps*abs(r2.y.start),
                             @"font: %@ glyph: %i",
                             font, glyph);
  XCTAssertEqualWithAccuracy(r1.x.end,   r2.x.end,   eps*max(abs(r2.x.end), r2.width()),
                             @"font: %@ glyph: %i",
                             font, glyph);
  XCTAssertEqualWithAccuracy(r1.y.end,   r2.y.end,   eps*max(abs(r2.y.end), r2.height()),
                             @"font: %@ glyph: %i",
                             font, glyph);
  return r1;
}

- (void)checkBoundingRectWithFont:(UIFont*)font
                           glyphs:(ArrayRef<const CGGlyph>)glyphs
                        positions:(ArrayRef<const CGPoint>)positions
                            cache:(FontFaceGlyphBoundsCache&)cache
                 maxRelativeError:(CGFloat)maxRelativeError
{
  const CGFloat fontSize = font.pointSize;
  const auto r1 = cache.boundingRect(fontSize, glyphs, positions.begin());

  auto r2 = stu_label::Rect<CGFloat>::infinitelyEmpty();
  for (Int i = 0; i < glyphs.count(); ++i) {
    auto r = [self checkGlyphBoundsWithFont:font glyph:glyphs[i] cache:cache];
    if (!r.isEmpty()) {
      r2 = r2.convexHull(r + positions[i]);
    }
  }
  if (r2.isEmpty()) {
    r2 = stu_label::Rect<CGFloat>{};
  }
  XCTAssertEqualWithAccuracy(r1.x.start, r2.x.start, maxRelativeError*abs(r2.x.start));
  XCTAssertEqualWithAccuracy(r1.y.start, r2.y.start, maxRelativeError*abs(r2.y.start));
  XCTAssertEqualWithAccuracy(r1.x.end,   r2.x.end,   maxRelativeError*abs(r2.x.end));
  XCTAssertEqualWithAccuracy(r1.y.end,   r2.y.end,   maxRelativeError*abs(r2.y.end));
}

- (void)checkBoundingRectWithFont:(UIFont*)font
                 randomGlyphCount:(int)randomGlyphCount
                            cache:(FontFaceGlyphBoundsCache&)cache
                 maxRelativeError:(CGFloat)maxRelativeError
{
  const UInt16 glyphCount = static_cast<UInt16>(CTFontGetGlyphCount((__bridge CTFont*)font));
  std::uniform_int_distribution<UInt16> dist{0, static_cast<UInt16>(glyphCount - 1)};
  std::minstd_rand rng{123};
  Vector<CGGlyph> glyphs;
  Vector<CGPoint> positions;
  while (randomGlyphCount > 0) {
    glyphs.removeAll();
    positions.removeAll();
    const int n = std::uniform_int_distribution<int>{1, min(randomGlyphCount, 5)}(rng);
    for (int i = 0; i < n; ++i) {
      glyphs.append(dist(rng));
      positions.append(CGPoint{CGFloat(i)/1024, -CGFloat(i)/1024});
    }
    [self checkBoundingRectWithFont:font glyphs:glyphs positions:positions cache:cache
                   maxRelativeError:maxRelativeError];
    randomGlyphCount -= n;
  }
}

- (void)testEmojiGlyphBoundWithFont:(UIFont*)font {
  NSAttributedString* const string = [[NSAttributedString alloc]
                                        initWithString:@"😎"
                                            attributes:@{NSFontAttributeName: font}];
  CTLine* const line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
  CTRun* const run = static_cast<CTRun*>(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(line), 0));
  CTFont* const runFont = static_cast<CTFont*>(CFDictionaryGetValue(CTRunGetAttributes(run),
                                                                    kCTFontAttributeName));
  const CGFloat runFontSize = CTFontGetSize(runFont);
  CGGlyph glyph;
  CTRunGetGlyphs(run, CFRange{0, 1}, &glyph);

  FontFaceGlyphBoundsCache::UniquePtr cache;
  FontFaceGlyphBoundsCache::exchange(InOut(cache), runFont, FontFace{runFont, runFontSize});

  [self checkGlyphBoundsWithFont:(__bridge UIFont*)runFont glyph:glyph cache:*cache];
  XCTAssert(cache->usesIntBounds());
}

- (void)testEmojiBounds {
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  [self testEmojiGlyphBoundWithFont:[UIFont systemFontOfSize:29]];

  for (int i = 0; i < 2; ++i) {
    for (CGFloat size = 1; size < 256; size += 0.25) {
      [self testEmojiGlyphBoundWithFont:[UIFont systemFontOfSize:size]];
    }
    [self testEmojiGlyphBoundWithFont:[UIFont systemFontOfSize:1021]];
  }
  for (int i = 0; i < 2; ++i) {
    for (CGFloat size = 1; size < 256; size += 0.25) {
      [self testEmojiGlyphBoundWithFont:[UIFont fontWithName:@"AppleColorEmoji" size:size]];
    }
    [self testEmojiGlyphBoundWithFont:[UIFont fontWithName:@"AppleColorEmoji" size:1021]];
  }
}

- (void)testBoundsOfAllGlyphsOfFont:(UIFont*)font {
  FontFaceGlyphBoundsCache::UniquePtr cache;
  const CGFloat fontSize = font.pointSize;
  FontFaceGlyphBoundsCache::exchange(InOut(cache), font, FontFace{font, fontSize});
  const Int glyphCount = CTFontGetGlyphCount((__bridge CTFontRef)font);
  for (Int i = 0; i < glyphCount; ++i) {
    const CGGlyph glyph = static_cast<CGGlyph>(i);
    [self checkGlyphBoundsWithFont:font glyph:glyph cache:*cache];
    XCTAssert(cache->usesIntBounds());
  }
}

- (void)testIndividualGlyphBounds {
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  FontFaceGlyphBoundsCache::clearGlobalCache();

  const CGFloat fontSizes[2] = {16, 67};
  for (CGFloat fontSize : fontSizes) {
    for (NSString* const familyName in // UIFont.familyNames) {
                                       @[@"HelveticaNeue", @"Thonburi"]) {
      for (NSString* const fontName in [UIFont fontNamesForFamilyName:familyName]) {
        [self testBoundsOfAllGlyphsOfFont:[UIFont fontWithName:fontName size:fontSize]];
      }
    }
  }

  const __unsafe_unretained UIFontTextStyle textStyles[] = {
    UIFontTextStyleTitle1,
    UIFontTextStyleTitle2,
    UIFontTextStyleTitle3,
    UIFontTextStyleHeadline,
    UIFontTextStyleSubheadline,
    UIFontTextStyleBody,
    UIFontTextStyleCallout,
    UIFontTextStyleFootnote,
    UIFontTextStyleCaption1,
    UIFontTextStyleCaption2,
  };
  const __unsafe_unretained UIContentSizeCategory categories[] = {
    UIContentSizeCategoryExtraSmall,
    UIContentSizeCategorySmall,
    UIContentSizeCategoryMedium,
    UIContentSizeCategoryLarge,
    UIContentSizeCategoryExtraLarge,
    UIContentSizeCategoryExtraExtraLarge,
    UIContentSizeCategoryExtraExtraExtraLarge,
    UIContentSizeCategoryAccessibilityMedium,
    UIContentSizeCategoryAccessibilityLarge,
    UIContentSizeCategoryAccessibilityExtraLarge,
    UIContentSizeCategoryAccessibilityExtraExtraLarge,
    UIContentSizeCategoryAccessibilityExtraExtraExtraLarge
  };

  if (@available(iOS 10, tvOS 10, *)) {
    for (const auto& category : categories) {
      const auto tc = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:category];
      for (const auto& textStyle : textStyles) {
        [self testBoundsOfAllGlyphsOfFont:[UIFont preferredFontForTextStyle:textStyle
                                              compatibleWithTraitCollection:tc]];
      }
      if (@available(iOS 11, *)) {
        [self testBoundsOfAllGlyphsOfFont:[UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle
                                              compatibleWithTraitCollection:tc]];
      }
    }
  } else {
    for (const auto& textStyle : textStyles) {
      [self testBoundsOfAllGlyphsOfFont:[UIFont preferredFontForTextStyle:textStyle]];
    }
  }
}

- (void)testBoundingRectWithRandomGlyphs {
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const auto getFreshCache = [&](UIFont* font) {
    FontFaceGlyphBoundsCache::clearGlobalCache();
    FontFaceGlyphBoundsCache::UniquePtr cache;
    UIFont* const largerFont = [font fontWithSize:font.pointSize*3];
    FontFaceGlyphBoundsCache::exchange(InOut(cache), largerFont,
                                       FontFace{largerFont, largerFont.pointSize});
    FontFaceGlyphBoundsCache::exchange(InOut(cache), font, FontFace{font, font.pointSize});
    return cache;
  };
  {
    UIFont* const font = [UIFont systemFontOfSize:17];
    auto cache = getFreshCache(font);
    [self checkBoundingRectWithFont:font randomGlyphCount:100000 cache:*cache
                   maxRelativeError:0];
  }
  {
    UIFont* const font = [UIFont fontWithName:@"Thonburi" size:17];
    auto cache = getFreshCache(font);
    [self checkBoundingRectWithFont:font randomGlyphCount:100000 cache:*cache
                   maxRelativeError:0];
  }
  {
    const CGAffineTransform matrix = CGAffineTransformMake(1, 0, -0.249f, 1, 0, 0);
    UIFont* font = (__bridge UIFont*)CTFontCreateWithName((__bridge CFStringRef)@"HelveticaNeue",
                                                          17, &matrix);
    auto cache = getFreshCache(font);
    [self checkBoundingRectWithFont:font randomGlyphCount:100000 cache:*cache
                   maxRelativeError:0];
  }
}

#if STU_DEBUG

- (void)testFallbackToFloatBoundsWithFont:(UIFont*)font string:(NSString*)string {
  NSAttributedString* const attributedString = [[NSAttributedString alloc]
                                                  initWithString:string
                                                      attributes:@{NSFontAttributeName: font}];
  CTLine* const line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)
                                                          attributedString);
  const NSArrayRef<CTRun*> runs = glyphRuns(line);
  XCTAssertEqual(runs.count(), 1);
  const GlyphSpan run = runs[0];
  const GlyphsWithPositions gwp = run.getGlyphsWithPositions();
  const ArrayRef<const CGGlyph> glyphs = gwp.glyphs();
  XCTAssertGreaterThan(glyphs.count(), 3);
  const ArrayRef<const CGPoint> positions = gwp.positions();

  UIFont* const runFont = (__bridge UIFont*)run.font();
  const CGFloat runFontSize = runFont.pointSize;

  const CGFloat largerFontSize = runFontSize*3;
  UIFont* const largerFont = [runFont fontWithSize:largerFontSize];

  const auto getFreshCache = [&] {
    FontFaceGlyphBoundsCache::clearGlobalCache();
    FontFaceGlyphBoundsCache::UniquePtr cache;
    FontFaceGlyphBoundsCache::exchange(InOut(cache), largerFont, FontFace{largerFont, largerFontSize});
    FontFaceGlyphBoundsCache::exchange(InOut(cache), runFont, FontFace{runFont, runFontSize});
    return cache;
  };


  {
    const auto cache = getFreshCache();
    cache->setMaxIntBoundsCountToTestFallbacktToFloatBounds(0);
    [self checkBoundingRectWithFont:runFont glyphs:glyphs positions:positions cache:*cache
                   maxRelativeError:0];
    [self checkBoundingRectWithFont:runFont randomGlyphCount:10000 cache:*cache
                  maxRelativeError:epsilon<Float32>/2];
  }

  {
    const auto cache = getFreshCache();
    cache->setMaxIntBoundsCountToTestFallbacktToFloatBounds(3);
    [self checkBoundingRectWithFont:runFont glyphs:glyphs[{0, 2}] positions:positions cache:*cache
                   maxRelativeError:0];
    [self checkBoundingRectWithFont:runFont glyphs:glyphs positions:positions cache:*cache
                  maxRelativeError:epsilon<Float32>/2];
    [self checkBoundingRectWithFont:runFont randomGlyphCount:10000 cache:*cache
                   maxRelativeError:epsilon<Float32>/2];
  }

  {
    const auto cache = getFreshCache();
    cache->setMaxIntBoundsCountToTestFallbacktToFloatBounds(123);
    [self checkBoundingRectWithFont:runFont randomGlyphCount:10000 cache:*cache
                   maxRelativeError:epsilon<Float32>/2];
  }

  CFRelease(line);
}

- (void)testFallbackToFloatBounds {
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  [self testFallbackToFloatBoundsWithFont:[UIFont systemFontOfSize:17] string:@"Testextt"];
  [self testFallbackToFloatBoundsWithFont:[UIFont systemFontOfSize:17] string:@"😀😁😂😎😁😍😎😎"];
}

#endif

- (void)testLocalGlyphBoundsCache {
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  NSArray* const fonts = @[[UIFont fontWithName:@"HelveticaNeue" size:16],
                           [UIFont fontWithName:@"HelveticaNeue" size:17],
                           [UIFont fontWithName:@"HelveticaNeue" size:18],
                           [UIFont fontWithName:@"HelveticaNeue" size:19],
                           [UIFont fontWithName:@"Thonburi" size:16],
                           [UIFont fontWithName:@"Thonburi" size:17],
                           [UIFont fontWithName:@"Helvetica" size:16],
                           [UIFont fontWithName:@"Helvetica" size:17],
                           [UIFont systemFontOfSize:17],
                           [UIFont systemFontOfSize:18]];

  std::minstd_rand rng{123};
  std::uniform_int_distribution<UInt> dist{0u, fonts.count - 1u};

  for (int i = 0; i < 1000; ++i) {
    LocalGlyphBoundsCache localCache;
    for (int j = 0; j < 100; ++j) {
      UIFont* const font = fonts[dist(rng)];
      const FontFace fontFace = FontFace{font, font.pointSize};
      const auto cache = localCache.glyphBoundsCache(font);
    #if STU_DEBUG
      localCache.checkInvariants();
    #endif
      const FontFace cacheFontFace = cache.cache.fontFace();
      XCTAssert(fontFace == cacheFontFace);
    }
  }
}

@end

