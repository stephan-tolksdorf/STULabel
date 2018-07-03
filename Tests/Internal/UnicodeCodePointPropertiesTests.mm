// Copyright 2017–2018 Stephan Tolksdorf

#import "TestUtils.h"

#import "UnicodeCodePointProperties.hpp"

#import <unicode/uchar.h>

extern "C" {
  UCharDirection u_charDirection_62(UChar32);
  UBool u_hasBinaryProperty_62(UChar32 c, UProperty which);
  int32_t u_getIntPropertyValue_62(UChar32 c, UProperty which);
}

const UProperty UCHAR_EXTENDED_PICTOGRAPHIC = UProperty(64);

using namespace stu_label;

static GraphemeClusterCategory graphemeClusterCategoryFromICU(Char32 cp);

@interface UnicodeCodePointPropertiesTest : XCTestCase
@end
@implementation UnicodeCodePointPropertiesTest

- (void)setUp {
  [super setUp];
  self.continueAfterFailure = false;
}

- (void)testIsSurrogate {
  for (uint32_t cp = 0; cp <= UCHAR_MAX_VALUE + 4; ++cp) {
    XCTAssertEqual(isHighSurrogate(cp), cp <= 0xffff && CFStringIsSurrogateHighCharacter((UInt16)cp));
    XCTAssertEqual(isLowSurrogate(cp),  cp <= 0xffff && CFStringIsSurrogateLowCharacter((UInt16)cp));
    XCTAssertEqual(isSurrogate(cp), isHighSurrogate(cp) || isLowSurrogate(cp));
  }
  XCTAssertEqual(isHighSurrogate(UINT32_MAX), false);
  XCTAssertEqual(isLowSurrogate(UINT32_MAX), false);
  XCTAssertEqual(isSurrogate(UINT32_MAX), false);
}

- (void)testCodePointFromSurrogatePair {
  XCTAssertEqual(codePointFromSurrogatePair(0xD800, 0xDC00),
                 CFStringGetLongCharacterForSurrogatePair(0xD800, 0xDC00));
  XCTAssertEqual(codePointFromSurrogatePair(0xD800, 0xDFFF),
                 CFStringGetLongCharacterForSurrogatePair(0xD800, 0xDFFF));
  XCTAssertEqual(codePointFromSurrogatePair(0xDBFF, 0xDC00),
                 CFStringGetLongCharacterForSurrogatePair(0xDBFF, 0xDC00));
  XCTAssertEqual(codePointFromSurrogatePair(0xDBFF, 0xDFFF),
                 CFStringGetLongCharacterForSurrogatePair(0xDBFF, 0xDFFF));
}

- (void)testIsLineTerminator {
  const CFCharacterSetRef set = CFCharacterSetGetPredefined(kCFCharacterSetNewline);

  for (uint32_t cp = 0; cp <= UINT16_MAX; ++cp) {
    const bool expected = CFCharacterSetIsCharacterMember(set, (uint16_t)cp);
    XCTAssertEqual(isLineTerminator((uint16_t)cp), expected, @"code point 0x%x", cp);
  }
}

- (void)testIsRegionalIndicator {
  for (UChar32 cp = 0; cp < UCHAR_MAX_VALUE + 4; ++cp) {
    XCTAssertEqual(isRegionalIndicator((Char32)cp),
                   u_hasBinaryProperty(cp, UCHAR_REGIONAL_INDICATOR),
                   @"code point 0x%x", cp);
  }
  XCTAssert(!isRegionalIndicator(UINT32_MAX));
}

- (void)testIsUnicodeWhitespace {
  for (uint32_t cp = 0; cp <= UINT16_MAX; ++cp) {
    const bool expected = u_hasBinaryProperty((UChar32)cp, UCHAR_WHITE_SPACE);
    XCTAssertEqual(isUnicodeWhitespace((Char32)cp), expected, @"code point 0x%x", cp);
  }
}

- (void)testIsNotIgnorableWithCodePoint:(uint32_t)cp {
  const bool ignorable = u_hasBinaryProperty_62((UChar32)cp, UCHAR_DEFAULT_IGNORABLE_CODE_POINT)
                      || (u_isISOControl((UChar32)cp) && !u_isUWhiteSpace((UChar32)cp))
                      || (0xFFF9 <= cp && cp <= 0xFFFB);
  XCTAssertEqual(isNotIgnorable(cp), !ignorable,
                 @"code point 0x%x", cp);
}

- (void)testIsNotIgnorableAndNotWhitespaceWithCodePoint:(uint32_t)cp {
  const bool ignorableOrWhitespace =
                u_hasBinaryProperty_62((UChar32)cp, UCHAR_DEFAULT_IGNORABLE_CODE_POINT)
             || u_hasBinaryProperty((UChar32)cp, UCHAR_WHITE_SPACE)
             || u_isISOControl((UChar32)cp)
             || (0xFFF9 <= cp && cp <= 0xFFFB);
  XCTAssertEqual(isNotIgnorableAndNotWhitespace(cp), !ignorableOrWhitespace,
                 @"code point 0x%x", cp);
}

- (void)testIsNotIgnorableAndNotWhitespaceWithCodePoint {
  for (uint32_t i = 0; i < UCHAR_MAX_VALUE + 4; ++i) {
    [self testIsNotIgnorableAndNotWhitespaceWithCodePoint:i];
    [self testIsNotIgnorableWithCodePoint:i];
  }
  [self testIsNotIgnorableAndNotWhitespaceWithCodePoint:UINT32_MAX - 42];
  [self testIsNotIgnorableAndNotWhitespaceWithCodePoint:UINT32_MAX];
  [self testIsNotIgnorableWithCodePoint:UINT32_MAX - 42];
  [self testIsNotIgnorableWithCodePoint:UINT32_MAX];
}


 - (void)testBidiStrongTypeOfCodePoint:(uint32_t)cp {
   BidiStrongType expected;
   const UCharDirection d =
      cp > UCHAR_MAX_VALUE ? U_OTHER_NEUTRAL
    : 0xf7f3 <= cp && cp < 0xf900 ? u_charDirection((UChar32)cp) // Apple's Private Use Area
    : u_charDirection_62((UChar32)cp);
   switch (d) {
     case U_LEFT_TO_RIGHT:
       expected = BidiStrongType::ltr;
       break;
     case U_RIGHT_TO_LEFT:
     case U_RIGHT_TO_LEFT_ARABIC:
       expected = BidiStrongType::rtl;
       break;
     case U_LEFT_TO_RIGHT_ISOLATE:
     case U_RIGHT_TO_LEFT_ISOLATE:
     case U_FIRST_STRONG_ISOLATE:
     case U_POP_DIRECTIONAL_ISOLATE:
       expected = BidiStrongType::isolate;
       break;
     default:
       expected = BidiStrongType::none;
       break;
   }
   const BidiStrongType st = bidiStrongType(cp);
   XCTAssertEqual(st, expected, @"code point 0x%x", cp);
 }

- (void)testBidiStrongType {
  if (@available(iOS 11, tvOS 11, watchOS 4, *)) {} else {
    NSLog(@"testBidiStrongType is skipped because it requires a newer system ICU library.");
    return;
  }
  for (uint32_t i = 0; i < UCHAR_MAX_VALUE + 4; ++i) {
    [self testBidiStrongTypeOfCodePoint:i];
  }
  [self testBidiStrongTypeOfCodePoint:UINT32_MAX - 42];
  [self testBidiStrongTypeOfCodePoint:UINT32_MAX];
}

 - (void)testGraphemeClusterCategoryOfCodePoint:(uint32_t)cp {
   const GraphemeClusterCategory expected = graphemeClusterCategoryFromICU(cp);
   const GraphemeClusterCategory value = graphemeClusterCategory(cp);
   XCTAssertEqual(value, expected, @"code point 0x%x", cp);
 }

- (void)testGraphemeClusterCategory {
  if (@available(iOS 11, tvOS 11, watchOS 4, *)) {} else {
    NSLog(@"testGraphemeClusterCategory is skipped because it requires a newer system ICU library.");
    return;
  }
  for (uint32_t i = 0; i < UCHAR_MAX_VALUE + 4; ++i) {
    [self testGraphemeClusterCategoryOfCodePoint:i];
  }
  [self testGraphemeClusterCategoryOfCodePoint:UINT32_MAX - 42];
  [self testGraphemeClusterCategoryOfCodePoint:UINT32_MAX];
}

@end

static GraphemeClusterCategory graphemeClusterCategoryFromICU(Char32 cp) {
  const bool isApplePUA = 0xf7f3 <= cp && cp < 0xf900;
  const bool isPicto = u_hasBinaryProperty_62(UChar32(cp), UCHAR_EXTENDED_PICTOGRAPHIC);
  const auto gcb = static_cast<UGraphemeClusterBreak>(
                     isApplePUA
                     ? u_getIntPropertyValue(UChar32(cp), UCHAR_GRAPHEME_CLUSTER_BREAK)
                     : u_getIntPropertyValue_62(UChar32(cp), UCHAR_GRAPHEME_CLUSTER_BREAK));
  switch (gcb) {
  case U_GCB_OTHER:
    if (isPicto) {
      return GraphemeClusterCategory::extendedPictographic;
    }
    return GraphemeClusterCategory::other;
  case U_GCB_CONTROL:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::controlOther;
  case U_GCB_CR:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::controlCR;
  case U_GCB_LF:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::controlLF;
  case U_GCB_EXTEND:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::extend;
  case U_GCB_ZWJ:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::zwj;
  case U_GCB_REGIONAL_INDICATOR:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::regionalIndicator;
  case U_GCB_PREPEND:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::prepend;
  case U_GCB_SPACING_MARK:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::spacingMark;
  case U_GCB_L:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::hangulL;
  case U_GCB_V:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::hangulV;
  case U_GCB_T:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::hangulT;
  case U_GCB_LV:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::hangulLV;
  case U_GCB_LVT:
    STU_CHECK(!isPicto);
    return GraphemeClusterCategory::hangulLVT;
  case U_GCB_E_BASE:
  case U_GCB_E_BASE_GAZ:
  case U_GCB_E_MODIFIER:
  case U_GCB_GLUE_AFTER_ZWJ:
    STU_CHECK(isApplePUA);
    return gcb == U_GCB_E_MODIFIER ? GraphemeClusterCategory::extend
         : GraphemeClusterCategory::extendedPictographic;
  default:
    STU_CHECK_MSG(false, "unexpected UGraphemeClusterBreak value");
  }
}



