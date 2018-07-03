// Copyright 2018 Stephan Tolksdorf

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, STUTextRangeType)  {
  STURangeInOriginalString  = 0,
  STURangeInTruncatedString = 1
};
enum { STUTextRangeTypeBitSize STU_SWIFT_UNAVAILABLE = 1 };

typedef struct STUTextRange {
  NSRange range;
  STUTextRangeType type;
} STUTextRange;

