// Copyright 2018 Stephan Tolksdorf

#import "TestUtils.h"

#import "STULabel/STUTextAttributes.h"

#import "TextStyleBuffer.hpp"

using namespace stu_label;

static NSDictionary<NSAttributedStringKey, id>* lotsOfAttributes() {
  return @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:16],
           NSLinkAttributeName: [NSURL URLWithString:@"https://www.apple.com"],
           STUBackgroundAttributeName:
             [[STUBackgroundAttribute alloc]
                initWithBlock:^(STUBackgroundAttributeBuilder *builder) {
                                  builder.cornerRadius = 2;
                                  builder.color = UIColor.redColor;
                                  builder.borderWidth = 3;
                                  builder.borderColor = UIColor.purpleColor;
                                }],
           NSShadowAttributeName: []{ const auto s = [[NSShadow alloc] init];
                                      s.shadowColor = UIColor.brownColor;
                                      s.shadowOffset = CGSize{4, 5};
                                      s.shadowBlurRadius = 6;
                                      return s;
                                   }(),
           NSUnderlineStyleAttributeName: @(NSUnderlineStyleDouble | NSUnderlinePatternDot),
           NSUnderlineColorAttributeName: UIColor.cyanColor,
           NSStrikethroughStyleAttributeName: @(NSUnderlineStyleThick | NSUnderlinePatternDashDot),
           NSStrikethroughColorAttributeName: UIColor.orangeColor,
           NSStrokeWidthAttributeName: @(-25),
           NSStrokeColorAttributeName: UIColor.magentaColor,
           STUAttachmentAttributeName: [[STUTextAttachment alloc]
                                          initWithWidth:10 ascent:11 descent:12 leading:3
                                          imageBounds:CGRect{{1, 2}, {3, 4}}
                                          colorInfo:STUTextAttachmentUsesExtendedColors
                                          stringRepresentation:nil],
           NSBaselineOffsetAttributeName: @(-7)};
}

@interface TextStyleBufferTests : XCTestCase
@end
@implementation TextStyleBufferTests

- (void)setUp {
  [super setUp];
  self.continueAfterFailure = false;
}

- (void)testLargeTextStyle {
  ThreadLocalArenaAllocator::InitialBuffer<2048> allocBuffer;
  ThreadLocalArenaAllocator alloc{Ref{allocBuffer}};

  LocalFontInfoCache fontInfoCache;
  TextStyleBuffer buffer{Ref{fontInfoCache}, alloc};

  NSDictionary* NS_VALID_UNTIL_END_OF_SCOPE attributes1 = lotsOfAttributes();
  NSMutableDictionary<NSAttributedStringKey, id>* NS_VALID_UNTIL_END_OF_SCOPE
    attributes1b = [attributes1 mutableCopy];
  NSMutableDictionary<NSAttributedStringKey, id>* NS_VALID_UNTIL_END_OF_SCOPE
    attributes2 = [attributes1 mutableCopy];

  attributes1b[@"Test"] = NSNull.null;
  attributes2[NSForegroundColorAttributeName] = UIColor.yellowColor;

  buffer.encodeStringRangeStyle(Range{0, 1}, attributes1);
  XCTAssertEqual(buffer.needToFixAttachmentAttributes(), true);
  buffer.encodeStringRangeStyle(Range{1, 2}, attributes1b);
  buffer.encodeStringRangeStyle(Range{2, 3}, attributes2);
  buffer.encodeStringRangeStyle(Range{3, TextStyle::maxSmallStringIndex + 1}, attributes2);
  buffer.encodeStringRangeStyle(Range{TextStyle::maxSmallStringIndex + 1, Count{1}}, attributes2);
  buffer.addStringTerminatorStyle();

  buffer.clearNeedToFixAttachmentAttributesFlag();

  const auto flags = TextFlags::hasLink
                   | TextFlags::hasBackground
                   | TextFlags::hasShadow
                   | TextFlags::hasUnderline
                   | TextFlags::hasStrikethrough
                   | TextFlags::hasStroke
                   | TextFlags::hasAttachment
                   | TextFlags::hasBaselineOffset
                   | TextFlags::mayNotBeGrayscale
                   | TextFlags::usesExtendedColor;

  const auto bufferColor = [&](ColorIndex index) -> ColorRef {
    STU_CHECK(index.value >= ColorIndex::fixedColorCount);
    return buffer.colors()[index.value - ColorIndex::fixedColorIndexRange.end];
  };

  UIFont* const font = attributes1[NSFontAttributeName];

  const TextStyle& s0 = *reinterpret_cast<const TextStyle*>(buffer.data().begin());
  XCTAssertEqual(s0.stringIndex(), 0);
  XCTAssert(!s0.isBig());
  XCTAssertEqual(s0.flags(), flags);
  XCTAssertEqual(s0.fontIndex().value, 0);
  XCTAssertEqual(buffer.fonts()[0].ctFont(), (__bridge CTFont*)font);
  XCTAssertEqual(s0.colorIndex().value, ColorIndex::black.value);

  const TextStyle& s1 = s0.next();
  XCTAssertEqual(s1.stringIndex(), 2);
  XCTAssert(!s1.isBig());
  XCTAssertEqual(s1.flags(), flags);
  XCTAssertEqual(s1.fontIndex().value, 0);
  XCTAssertEqual(bufferColor(s1.colorIndex()), Color{UIColor.yellowColor});

  const TextStyle& s2 = s1.next();
  XCTAssertEqual(s2.stringIndex(), 3);
  XCTAssert(s2.isBig());
  XCTAssertEqual(s2.flags(), flags);
  XCTAssertEqual(s2.fontIndex().value, 0);
  XCTAssertEqual(bufferColor(s2.colorIndex()), Color{UIColor.yellowColor});

  const TextStyle& s3 = s2.next();
  XCTAssertEqual(s3.stringIndex(), TextStyle::maxSmallStringIndex + 2);
  XCTAssert(s3.isBig());
  XCTAssertEqual(&s3, &s3.next());

  STUBackgroundAttribute* const background = attributes1[STUBackgroundAttributeName];
  NSShadow* const shadow = attributes1[NSShadowAttributeName];

  const NSUnderlineStyle underlineStyle =
    ((NSNumber*)attributes1[NSUnderlineStyleAttributeName]).integerValue ;
  UIColor* const underlineColor = attributes1[NSUnderlineColorAttributeName];

  const NSUnderlineStyle strikethroughStyle =
    ((NSNumber*)attributes1[NSStrikethroughStyleAttributeName]).integerValue;
  UIColor* const strikethroughColor = attributes1[NSStrikethroughColorAttributeName];

  UIColor* const strokeColor = attributes1[NSStrokeColorAttributeName];

  const float baselineOffset = ((NSNumber*)attributes1[NSBaselineOffsetAttributeName]).floatValue;

  for (const TextStyle* s = &s0; s != &s->next(); s = &s->next()) {
    XCTAssertEqual(s->linkInfo()->attribute, attributes1[NSLinkAttributeName]);
    XCTAssertEqual(s->backgroundInfo()->stuAttribute, background);
    XCTAssertEqual(bufferColor(*s->backgroundInfo()->colorIndex),
                   Color{background.color});
    XCTAssertEqual(bufferColor(*s->backgroundInfo()->borderColorIndex),
                   Color{background.borderColor});

    XCTAssertEqual(s->backgroundInfo()->stuAttribute, background);
    XCTAssertEqual(bufferColor(*s->backgroundInfo()->colorIndex),
                   Color{background.color});
    XCTAssertEqual(bufferColor(*s->backgroundInfo()->borderColorIndex),
                   Color{background.borderColor});

    XCTAssertEqual(s->shadowInfo()->offsetX, narrow_cast<Float32>(shadow.shadowOffset.width));
    XCTAssertEqual(s->shadowInfo()->offsetY, narrow_cast<Float32>(shadow.shadowOffset.height));
    XCTAssertEqual(s->shadowInfo()->blurRadius, narrow_cast<Float32>(shadow.shadowBlurRadius));
    XCTAssertEqual(bufferColor(s->shadowInfo()->colorIndex), Color{shadow.shadowColor});

    XCTAssertEqual(s->underlineInfo()->style, underlineStyle);
    XCTAssertEqual(bufferColor(*s->underlineInfo()->colorIndex), Color{underlineColor});

    XCTAssertEqual(s->strikethroughInfo()->style, strikethroughStyle);
    XCTAssertEqual(bufferColor(*s->strikethroughInfo()->colorIndex), Color{strikethroughColor});

    XCTAssertEqual(bufferColor(*s->strokeInfo()->colorIndex), Color{strokeColor});

    XCTAssertEqual(s->attachmentInfo()->attribute, attributes1[STUAttachmentAttributeName]);

    XCTAssertEqual(s->baselineOffsetInfo()->baselineOffset, baselineOffset);
  }
}

- (void)testColorOverflowHandling {
  ThreadLocalArenaAllocator::InitialBuffer<2048> allocBuffer;
  ThreadLocalArenaAllocator alloc{Ref{allocBuffer}};

  LocalFontInfoCache fontInfoCache;
  TextStyleBuffer buffer{Ref{fontInfoCache}, alloc};

  constexpr int n = maxValue<UInt16> + 2;

  NSMutableArray* NS_VALID_UNTIL_END_OF_SCOPE const
    colors = [[NSMutableArray alloc] initWithCapacity:n];

  for (int i = 0; i < n; ++i) {
    UIColor* const color = [UIColor colorWithWhite:i/CGFloat{maxValue<UInt16>} alpha:1];
    [colors addObject:color];
    buffer.encodeStringRangeStyle(Range{i, i + 1}, @{NSForegroundColorAttributeName: color});
  }
  buffer.addStringTerminatorStyle();

  const TextStyle* s = reinterpret_cast<const TextStyle*>(buffer.data().begin());
  XCTAssertEqual(s->stringIndex(), 0);
  XCTAssertEqual(s->colorIndex(), ColorIndex::black);

  for (int i = 0; i < TextStyleBuffer::maxFontCount; ++i) {
    s = &s->next();
    XCTAssertEqual(s->stringIndex(), i + 1);
    XCTAssertEqual(buffer.colors()[s->colorIndex().value - ColorIndex::fixedColorIndexRange.end],
                   Color{colors[sign_cast(i + 1)]});
  }
  s = &s->next();
  XCTAssertEqual(s->stringIndex(), TextStyleBuffer::maxFontCount + 1);
  XCTAssertEqual(s->colorIndex(), ColorIndex::black);

  s = &s->next();
  XCTAssertEqual(s->stringIndex(), n);
  XCTAssertEqual(s, &s->next());
}

// This test is too slow to be enabled by default.
- (void)testFontOverflowHandling {
  ThreadLocalArenaAllocator::InitialBuffer<2048> allocBuffer;
  ThreadLocalArenaAllocator alloc{Ref{allocBuffer}};

  LocalFontInfoCache fontInfoCache;
  TextStyleBuffer buffer{Ref{fontInfoCache}, alloc};

  constexpr int n = maxValue<UInt16> + 2;

  NSMutableArray<UIFont*>* NS_VALID_UNTIL_END_OF_SCOPE const
    fonts = [[NSMutableArray alloc] initWithCapacity:n];

  for (int i = 0; i < n; ++i) {
    UIFont* const font = [UIFont fontWithName:@"HelveticaNeue" size:i/1024.f];
    [fonts addObject:font];
    buffer.encodeStringRangeStyle(Range{i, i + 1}, @{NSFontAttributeName: font});
  }
  buffer.addStringTerminatorStyle();

  const TextStyle* s = reinterpret_cast<const TextStyle*>(buffer.data().begin());
  XCTAssertEqual(s->stringIndex(), 0);
  XCTAssertEqual(s->fontIndex().value, 0);
  XCTAssertEqual(buffer.fonts()[0].ctFont(), (__bridge CTFont*)fonts[0]);

  for (int i = 0; i < TextStyleBuffer::maxFontCount; ++i, s = &s->next()) {
    XCTAssertEqual(s->stringIndex(), i);
    XCTAssertEqual(buffer.fonts()[s->fontIndex().value].ctFont(),
                   (__bridge CTFont*)fonts[sign_cast(i)]);
  }
  XCTAssertEqual(s->stringIndex(), TextStyleBuffer::maxFontCount);
  XCTAssertEqual(s->fontIndex().value, 0);

  s = &s->next();
  XCTAssertEqual(s->stringIndex(), n);
  XCTAssertEqual(s, &s->next());
}

@end

