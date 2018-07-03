// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame-Unsafe.h"

#import "Internal/TextStyle.hpp"

namespace stu_label { Unretained<STUTextFrame* __nonnull> emptySTUTextFrame(); }

STU_EXTERN_C_BEGIN

STUTextFrame * __nonnull
  STUTextFrameCreateWithShapedString(__nullable Class cls,
                                     STUShapedString * __nonnull shapedString,
                                     CGSize size,
                                     STUTextFrameOptions * __nullable options)
    NS_RETURNS_RETAINED;

STUTextFrame * __nullable
  STUTextFrameCreateWithShapedStringRange(__nullable Class cls,
                                          STUShapedString * __nonnull shapedString,
                                          NSRange stringRange,
                                          CGSize,
                                          STUTextFrameOptions *,
                                          const STUCancellationFlag * __nullable)
    NS_RETURNS_RETAINED;

STU_INLINE
STUTextFrameRange STUTextFrameGetRange(const STUTextFrame* frame) {
  return {STUTextFrameIndexZero, STUTextFrameDataGetEndIndex(frame->data)};
}

CGRect STUTextFrameGetImageBoundsForRange(
         const STUTextFrame* __nonnull, STUTextFrameRange,
         CGPoint textFrameOrigin, CGFloat displayScale,
         const STUTextFrameDrawingOptions* __nullable,
         const STUCancellationFlag* __nullable);

void STUTextFrameDrawRange(
       const STUTextFrame * __nonnull, STUTextFrameRange,
       CGPoint origin, CGContext* __nonnull, bool isVectorContext, CGFloat contextBaseCTM_d,
       const STUTextFrameDrawingOptions* __nullable, const STUCancellationFlag* __nullable);

STU_INLINE
bool operator==(STURunGlyphIndex lhs, STURunGlyphIndex rhs) {
  return lhs.runIndex == rhs.runIndex & lhs.glyphIndex == rhs.glyphIndex;
}

STU_INLINE
bool operator!=(STURunGlyphIndex lhs, STURunGlyphIndex rhs) {
  return !(lhs == rhs);
}

STU_EXTERN_C_END
