// Copyright 2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <Foundation/Foundation.h>

typedef struct STU_ALIGN_AS(uint64_t) NS_SWIFT_NAME(STUTextFrame.Index) STUTextFrameIndex {
  /// Indicates whether this is the index for a hyphen that was inserted immediately after
  /// @c indexInTruncatedString during line breaking.
  bool isIndexOfInsertedHyphen : 1;

  // var utf16IndexInTruncatedString: Int
  uint32_t indexInTruncatedString : 31 NS_REFINED_FOR_SWIFT;

  /// The (0-based) index of the line in the text frame corresponding to the character identified
  /// by @c indexInTruncatedString.
  // var lineIndex: Int
  uint32_t lineIndex NS_REFINED_FOR_SWIFT;
} STUTextFrameIndex;

#define STUTextFrameIndexZero (STUTextFrameIndex){0, 0, 0}

STU_EXTERN_C_BEGIN

STU_INLINE NS_REFINED_FOR_SWIFT
static bool STUTextFrameIndexEqualToIndex(STUTextFrameIndex a, STUTextFrameIndex b) {
  _Static_assert(sizeof(STUTextFrameIndex) == 8, "");
  // We only compare indexInTruncatedString and isIndexOfInsertedHyphen.
  uint32_t aIndex; __builtin_memcpy(&aIndex, &a, 4);
  uint32_t bIndex; __builtin_memcpy(&bIndex, &b, 4);
  return aIndex == bIndex;
}

STU_INLINE NS_REFINED_FOR_SWIFT
static bool STUTextFrameIndexLessThanIndex(STUTextFrameIndex a, STUTextFrameIndex b) {
  // We only compare indexInTruncatedString and isIndexOfInsertedHyphen.
  // The C standard doesn't specify the memory layout for bitfields, but we only need this to
  // work with Clang on little-endian platforms, and we test the implementation.
  uint32_t aIndex; __builtin_memcpy(&aIndex, &a, 4);
  uint32_t bIndex; __builtin_memcpy(&bIndex, &b, 4);
  return aIndex < bIndex;
}

STU_INLINE STU_SWIFT_UNAVAILABLE
static bool STUTextFrameIndexLessThanOrEqualToIndex(STUTextFrameIndex a, STUTextFrameIndex b) {
  return !(STUTextFrameIndexLessThanIndex(b, a));
}

// In Swift code this type is replaced by Range<STUTextFrame.Index>
typedef struct NS_REFINED_FOR_SWIFT STUTextFrameRange {
  STUTextFrameIndex start;
  STUTextFrameIndex end;
} STUTextFrameRange;

#define STUTextFrameRangeZero (STUTextFrameRange){STUTextFrameIndexZero, STUTextFrameIndexZero}

STU_INLINE NS_REFINED_FOR_SWIFT
static bool STUTextFrameRangeIsEmpty(STUTextFrameRange range) {
  return STUTextFrameIndexLessThanOrEqualToIndex(range.end, range.start);
}

NS_SWIFT_NAME(getter:STUTextFrameRange.rangeInTruncatedString(self:))
NSRange STUTextFrameRangeGetRangeInTruncatedString(STUTextFrameRange range);

STU_EXTERN_C_END
