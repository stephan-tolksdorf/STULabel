// Copyright 2018 Stephan Tolksdorf

#import "NSStringRef.hpp"

#import "TestUtils.h"

#import <unicode/uchar.h>

extern "C" {
  typedef struct UBreakIterator UBreakIterator;

  typedef enum UBreakIteratorType {
    UBRK_CHARACTER = 0,
  } UBreakIteratorType;

  UBreakIterator* ubrk_open_62(UBreakIteratorType type, const char* locale,
                               const UChar* string, int32_t stringLength, UErrorCode*);
  void ubrk_close_62(UBreakIterator*);

  void ubrk_setText_62(UBreakIterator*, const UChar* string, int32_t stringLength, UErrorCode*);

  int32_t ubrk_next_62(UBreakIterator*);
  int32_t ubrk_previous_62(UBreakIterator*);

  void udata_setCommonData_62(const void* data, UErrorCode*);
}

using namespace stu_label;

@interface StringWrapper : NSString {
  NSString* _string;
}
@end
@implementation StringWrapper
- (instancetype)initWithString:(NSString*)string
{
  if ((self = [super init])) {
    _string = string;
  }
  return self;
}
- (NSUInteger)length { return _string.length; }
- (unichar)characterAtIndex:(NSUInteger)index { return [_string characterAtIndex:index]; }
@end

@interface MutableStringRef : NSString {
@public
  const Char16* utf16;
  UInt length;
  bool doNotReturnPointer;
}
@end
@implementation MutableStringRef

- (NSUInteger)length {
  return self->length;
}

- (const Char16*)_fastCharacterContents {
  if (doNotReturnPointer) return nullptr;
  return utf16;
}

- (unichar)characterAtIndex:(NSUInteger)index {
  STU_CHECK(index < length);
  return utf16[index];
}

- (void)getCharacters:(UTF16Char*)buffer range:(NSRange)range {
  STU_CHECK(range.location <= length && range.length <= length - range.location);
  memcpy(buffer, utf16 + range.location, range.length*sizeof(UTF16Char));
}
@end



@interface NSStringRefTests : XCTestCase
@end

@implementation NSStringRefTests

- (void)setUp {
  [super setUp];
  self.continueAfterFailure = false;
}

- (void)testConstructorAndIndexingOperator {
  const auto test = [&](NSString* nsString) {
    const NSStringRef string{nsString};
    XCTAssertEqual((size_t)string.count(), nsString.length);
    if (string.count() != 0) {
      XCTAssertEqual(string[0], [nsString characterAtIndex:0]);
      XCTAssertEqual(string[string.count() - 1], [nsString characterAtIndex:nsString.length - 1]);
    }
  #if STU_ASSERT_MAY_THROW
    CHECK_FAILS_ASSERT(string[-1]);
    CHECK_FAILS_ASSERT(string[string.count()]);
    CHECK_FAILS_ASSERT(string[string.count() + 1]);
    CHECK_FAILS_ASSERT(string[maxValue<Int>]);
  #endif
  };
  const auto test3 = [&](NSString* nsString) {
    test(nsString);
    test([[NSMutableString alloc] initWithString:nsString]);
    test([[StringWrapper alloc] initWithString:nsString]);
  };
  test3(@"");
  test3(@"x");
  test3(@"abc");
  test3(@"äöüß");
}

static Int indexOf(const NSStringRef& string, Range<Int> range, Char16 ch) {
  STU_CHECK(0 <= range.start && range.end <= string.count());
  if (range.isEmpty()) return range.start;
  for (Int index = range.start; index < range.end; ++index) {
    if (string[index] == ch) return index;
  }
  return range.end;
}

static Int indexOf(const NSStringRef& string, Range<Int> range, Char32 cp) {
  STU_CHECK(0 <= range.start && range.end <= string.count());
  if (range.isEmpty()) return range.start;
  Char32 cp2;
  for (Int index = range.start; index < range.end; index += cp2 <= 0xffff ? 1 : 2) {
    const Char16 ch0 = string[index];
    if (isHighSurrogate(ch0) && index + 1 < range.end && isLowSurrogate(string[index + 1])) {
      cp2 = codePointFromSurrogatePair(ch0, string[index + 1]);
    } else {
      cp2 = ch0;
    }
    if (cp2 == cp) return index;
  }
  return range.end;
}

static Int lastEndIndexOf(const NSStringRef& string, Range<Int> range, Char32 cp) {
  STU_CHECK(0 <= range.start && range.end <= string.count());
  if (range.isEmpty()) return range.start;
  Char32 cp2;
  for (Int index = range.end; index > range.start; index -= cp2 <= 0xffff ? 1 : 2) {
    const Char16 ch1 = string[index - 1];
    if (isLowSurrogate(ch1) && index - 2 >= range.start && isHighSurrogate(string[index - 2])) {
      cp2 = codePointFromSurrogatePair(string[index - 2], ch1);
    } else {
      cp2 = ch1;
    }
    if (cp2 == cp) return index;
  }
  return range.start;
}

- (void)testIndexWhereMethods {
  {
    const auto alwaysTrue = [](auto){ return true; };
  #if STU_ASSERT_MAY_THROW
    CHECK_FAILS_ASSERT((NSStringRef{@""}.indexOfFirstUTF16CharWhere({-1, 0}, alwaysTrue)));
    CHECK_FAILS_ASSERT((NSStringRef{@"1"}.indexOfFirstUTF16CharWhere({0, -1}, alwaysTrue)));
    CHECK_FAILS_ASSERT((NSStringRef{@""}.indexOfFirstCodePointWhere({-1, 0}, alwaysTrue)));
    CHECK_FAILS_ASSERT((NSStringRef{@"1"}.indexOfFirstCodePointWhere({0, -1}, alwaysTrue)));
    CHECK_FAILS_ASSERT((NSStringRef{@""}.indexOfEndOfLastCodePointWhere({-1, 0}, alwaysTrue)));
    CHECK_FAILS_ASSERT((NSStringRef{@"1"}.indexOfEndOfLastCodePointWhere({0, -1}, alwaysTrue)));
  #endif
    XCTAssertEqual((NSStringRef{@"1"}.indexOfFirstUTF16CharWhere({1, 0}, alwaysTrue)), 1);
    XCTAssertEqual((NSStringRef{@"1"}.indexOfFirstCodePointWhere({1, 0}, alwaysTrue)), 1);
    XCTAssertEqual((NSStringRef{@"1"}.indexOfEndOfLastCodePointWhere({1, 0}, alwaysTrue)), 1);
  }
  const auto test = [&](const NSStringRef& str, Range<Int> range, Char32 cp) {
    const auto isEqual = [&](auto cp2){ return cp == cp2; };
    {
      const Char16 ch = narrow_cast<Char16>(cp);
      const Int index = indexOf(str, range, ch);
      XCTAssertEqual(str.indexOfFirstUTF16CharWhere(range, isEqual), index);
    }
    {
      const Int index = indexOf(str, range, cp);
      if (str.indexOfFirstCodePointWhere(range, isEqual) != index) {
        XCTAssertEqual(str.indexOfFirstCodePointWhere(range, isEqual), index);
      }
    }
    {
      const Int index = lastEndIndexOf(str, range, cp);
      XCTAssertEqual(str.indexOfEndOfLastCodePointWhere(range, isEqual), index);
    }
  };
  const auto test2 = [&](NSString* string, uint32_t cp) {
    NSMutableString* const mutableString = [[NSMutableString alloc] initWithString:string];
    StringWrapper* const stringWrapper = [[StringWrapper alloc] initWithString:string];

    NSMutableString* const longString1 = [[NSMutableString alloc] init];
    NSMutableString* const longString2 = [[NSMutableString alloc] init];
    // The internal buffer in NSStringRefBuffer has a capacity of 64 chars.
    [longString1 appendString:@"0123456789012345678901234567890123456789012345678901234567890123"];
    [longString2 appendString:@"0123456789012345678901234567890123456789012345678901234567890123"];
    [longString2 appendString:@"0123456789012345678901234567890123456789012345678901234567890123"];
    [longString1 appendString:string];
    [longString2 appendString:string];
    StringWrapper* const longString1Wrapper = [[StringWrapper alloc] initWithString:longString1];
    StringWrapper* const longString2Wrapper = [[StringWrapper alloc] initWithString:longString2];

    const NSStringRef ref1{string};
    const NSStringRef ref2{mutableString};
    const NSStringRef ref3{stringWrapper};

    const NSStringRef longRef1{longString1Wrapper};
    const NSStringRef longRef2{longString2Wrapper};

    const Int length = ref1.count();
    for (Int i = 0; i <= length; ++i) {
      for (Int j = 0; j <= length; ++j) {
        test(ref1, {i, j}, cp);
        test(ref2, {i, j}, cp);
        test(ref3, {i, j}, cp);
      }
      test(longRef1, {0, 64 + i}, cp);
      test(longRef2, {0, 128 + i}, cp);
      test(longRef1, {i, 64 + length}, cp);
      test(longRef2, {i, 128 + length}, cp);
    }
  };
  test2(@"", '\0');
  test2(@"t", 't');
  test2(@"t", 's');
  test2(@"tt", 't');
  test2(@"tet", 't');
  test2(@"😀", '3');
  test2(@"😀", U'😀');
  test2(@"😁😀😁", U'😀');
  test2(@"😁😀😁", U'😁');
  test2(@"😁😀😁", 0xD83D);
  test2(@"😁😀😁", 0xDE00);
  test2(@"4😀5", U'😀');
  test2(@"4😀5", U'😁');
  test2(@"4😀5", 0xD83D);
  test2(@"4😀5", 0xDE00);
  test2(@"4😀5", 4);
  test2(@"4😀5", 4);

  // Test the handling of unpaired surrogate code units.
  {
    unichar array[] = {0xD83D};
    NSString* string = [[NSString alloc] initWithCharactersNoCopy:array length:arrayLength(array) freeWhenDone:false];
    test2(string, '3');
    test2(string, 0xD83D);
    test2(string, 0xD83F);
  }
  {
    unichar array[] = {'x', 0xD83D, 'y'};
    NSString* string = [[NSString alloc] initWithCharactersNoCopy:array length:arrayLength(array) freeWhenDone:false];
    test2(string, 'x');
    test2(string, 'y');
    test2(string, 0xD83D);
    test2(string, 0xD83f);
  }
  {
    unichar array[] = {0xD83D, 0xD83D, 0xDE01};
    NSString* string = [[NSString alloc] initWithCharactersNoCopy:array length:arrayLength(array) freeWhenDone:false];
    test2(string, 0xD83D);
  }
  {
    unichar array[] = {0xDE01};
    NSString* string = [[NSString alloc] initWithCharactersNoCopy:array length:arrayLength(array) freeWhenDone:false];
    test2(string, '3');
    test2(string, 0xDE01);
    test2(string, 0xDE00);
  }
  {
    unichar array[] = {'x', 0xDE01, 'y'};
    NSString* string = [[NSString alloc] initWithCharactersNoCopy:array length:arrayLength(array) freeWhenDone:false];
    test2(string, 'x');
    test2(string, 'y');
    test2(string, 0xDE01);
    test2(string, 0xDE00);
  }
}

- (void)testIndexOfTrailingWhitespace {
  XCTAssertEqual(NSStringRef(@"").indexOfTrailingWhitespaceIn({}), 0);
  XCTAssertEqual(NSStringRef(@" ").indexOfTrailingWhitespaceIn({0, 1}), 0);
  XCTAssertEqual(NSStringRef(@"x").indexOfTrailingWhitespaceIn({0, 1}), 1);
  XCTAssertEqual(NSStringRef(@"x ").indexOfTrailingWhitespaceIn({0, 2}), 1);
  XCTAssertEqual(NSStringRef(@"x \t").indexOfTrailingWhitespaceIn({0, 3}), 1);
  // \u00ad is "ignorable"
  XCTAssertEqual(NSStringRef(@"x \u00ad").indexOfTrailingWhitespaceIn({0, 3}), 1);
  XCTAssertEqual(NSStringRef(@"x \u00ad ").indexOfTrailingWhitespaceIn({0, 4}), 1);
  XCTAssertEqual(NSStringRef(@"x\u00ad").indexOfTrailingWhitespaceIn({0, 2}), 2);
  XCTAssertEqual(NSStringRef(@"x\u00ad ").indexOfTrailingWhitespaceIn({0, 3}), 2);
}

- (void)testGraphemeClusterBreakFinding {
  self.continueAfterFailure = false;

  Char32 codePoints[] = {
    'x', 0xFFFD, 0x10000, // other
    '\r', '\n',
    0x0000, 0xE0001, // control
    0xA9, 0x1F603, // extended pictographic
    0x300, // extend, Emoji modifier
    0x1F3FB, // extend (Emoji modifier)
    0x200D, // ZWJ
    0x1F1E6, // regional indicator
    0x0903, 0x11000, // spacing mark
    0x0600, 0x111C2, // prepend
    0x1100, // Hangul L
    0x1160, // Hangul V
    0x11A8, // Hangul T
    0xAC00, // Hangul LV
    0xAC01, // Hangul LVT
    0xD800  // Unpaired high surrogate
  };
  const UInt8 codePointCount = arrayLength(codePoints);
  const int n = 7;
  UInt testCaseCount = 1;
  for (UInt i = 0; i < n; ++i) {
    testCaseCount *= n;
  }

  UInt8 indices[n];
  Char32 utf32[n];

  bool stringIsAscii = true;

  Char16 utf16[2*n];
  Int32 utf16Length = 0;

  char ascii[n];

  MutableStringRef* nsString = [[MutableStringRef alloc] init];
  nsString->doNotReturnPointer = true;
  nsString->utf16 = utf16;
  nsString->length = n;

  NSStringRef string{nsString};
  const auto stringGutsMethod = string._private_guts().method;
  XCTAssert(stringGutsMethod);

  UErrorCode ec = U_ZERO_ERROR;
  UBreakIterator* const iterator = ubrk_open_62(UBRK_CHARACTER, nullptr, nullptr, 0, &ec);
  XCTAssert(U_SUCCESS(ec));

  const auto convertString32ToUTF16 = [&]() {
    utf16Length = 0;
    for (int j = 0; j < n; ++j) {
      const Char32 codePoint = utf32[j];
      if (codePoint <= 0xffff) {
        utf16[utf16Length] = static_cast<Char16>(codePoint);
        utf16Length += 1;
      } else {
        UTF16Char cs[2];
        CFStringGetSurrogatePairForLongCharacter(codePoint, cs);
        utf16[utf16Length] = cs[0]; utf16[utf16Length + 1] = cs[1];
        utf16Length += 2;
      }
    }
  };

  const auto nextString = [&]() {
    for (int j = 0; j < n; ++j) {
      UInt8 index = indices[j] + 1;
      if (index == codePointCount) {
        index = 0;
      }
      indices[j] = index;
      utf32[j] = codePoints[index];
      if (index != 0) break;
    }

    convertString32ToUTF16();
    nsString->length = sign_cast(utf16Length);

    stringIsAscii = utf16Length == n;
    if (stringIsAscii) {
      for (int j = 0; j < n; ++j) {
        if (utf32[j] < 128) {
          ascii[j] = static_cast<char>(utf32[j]);
          continue;
        }
        stringIsAscii = false;
        break;
      }
    }
  };

  for (int i = 0; i < n; ++i) {
    indices[i] = codePointCount - 1;
  }
  nextString();

  for (UInt testCase = 0; testCase < testCaseCount; ++testCase, nextString()) {
    ubrk_setText_62(iterator, reinterpret_cast<const UChar*>(utf16), utf16Length, &ec);
    XCTAssert(U_SUCCESS(ec));
    string._private_setGuts(NSStringRef::Guts{.count = utf16Length, .utf16 = utf16});
    const char* kind = "UTF-16";
    Int index = 0;
    do {
      const Int nextIndex = ubrk_next_62(iterator);
      for (bool asciiTest = false, bufferedTest = false;;) {
        XCTAssertEqual(string.startIndexOfGraphemeClusterAt(index), index,
                       "testCase: %lu, index: %li %s", testCase, index, kind);
        XCTAssertEqual(string.indexOfFirstGraphemeClusterBreakNotBefore(index), index,
                       "testCase: %lu, index: %li %s", testCase, index, kind);
        XCTAssertEqual(string.endIndexOfGraphemeClusterAt(index), nextIndex,
                       "testCase: %lu, index: %li %s", testCase, index, kind);
        XCTAssertEqual(string.indexOfLastGraphemeClusterBreakBefore(nextIndex), index,
                       "testCase: %lu, index: %li %s", testCase, index, kind);
        for (Int index1 = index;;) {
          index1 += 1 + (string.codePointAtUTF16Index(index1) > 0xffff);
          if (index1 == nextIndex) break;

          XCTAssertEqual(string.endIndexOfGraphemeClusterAt(index1), nextIndex,
                         "testCase: %lu, index1: %li %s", testCase, index1, kind);
          XCTAssertEqual(string.indexOfFirstGraphemeClusterBreakNotBefore(index1), nextIndex,
                         "testCase: %lu, index1: %li %s", testCase, index1, kind);
          XCTAssertEqual(string.indexOfLastGraphemeClusterBreakBefore(index1), index,
                        "testCase: %lu, index1: %li %s", testCase, index1, kind);
          XCTAssertEqual(string.startIndexOfGraphemeClusterAt(index1), index,
                         "testCase: %lu, index1: %li %s", testCase, index1, kind);
        }
        if (!asciiTest && stringIsAscii) {
          asciiTest = true;
          kind = "ASCII";
          string._private_setGuts({.count = utf16Length, .ascii = ascii});
          continue;
        }
        if (!bufferedTest) {
          asciiTest = false;
          bufferedTest = true;
          kind = "buffered UTF-16";
          string._private_setGuts({.count = utf16Length, .method = stringGutsMethod});
          continue;
        }
        bufferedTest = false;
        kind = "UTF-16";
        string._private_setGuts({.count = utf16Length, .utf16 = utf16});
        break;
      } // for (;;)
      index = nextIndex;
    } while (index < utf16Length);

  }

  ubrk_close_62(iterator);
}

@end
