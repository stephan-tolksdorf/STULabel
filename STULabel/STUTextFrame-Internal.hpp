// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame-Unsafe.h"

#import "Internal/Rect.hpp"
#import "Internal/TextStyle.hpp"


namespace stu_label { Unretained<STUTextFrame* __nonnull> emptySTUTextFrame(); }

stu_label::Rect<CGFloat> STUTextFrameGetImageBoundsForRange(
                           const STUTextFrame* __nonnull, STUTextFrameRange,
                           CGPoint textFrameOrigin, CGFloat displayScale,
                           const STUTextFrameDrawingOptions* __nullable,
                           const STUCancellationFlag* __nullable);


STU_EXTERN_C_BEGIN

STUTextFrame * __nonnull
  STUTextFrameCreateWithShapedString(__nullable Class cls,
                                     STUShapedString * __nonnull shapedString,
                                     CGSize size, CGFloat displayScale,
                                     STUTextFrameOptions * __nullable options)
    NS_RETURNS_RETAINED;

STUTextFrame * __nullable
  STUTextFrameCreateWithShapedStringRange(__nullable Class cls,
                                          STUShapedString * __nonnull shapedString,
                                          NSRange stringRange,
                                          CGSize, CGFloat displayScale,
                                          STUTextFrameOptions *,
                                          const STUCancellationFlag * __nullable)
    NS_RETURNS_RETAINED;

STU_INLINE
STUTextFrameRange STUTextFrameGetRange(const STUTextFrame* frame) {
  return {STUTextFrameIndexZero, STUTextFrameDataGetEndIndex(frame->data)};
}


namespace stu_label {

struct ContextBaseCTM_d : Parameter<ContextBaseCTM_d, CGFloat> { using Parameter::Parameter; };
struct PixelAlignBaselines : Parameter<PixelAlignBaselines> { using Parameter::Parameter; };

void drawTextFrame(
       const STUTextFrame * __nonnull, STUTextFrameRange,
       CGPoint origin, CGContext* __nonnull, ContextBaseCTM_d, PixelAlignBaselines,
       const STUTextFrameDrawingOptions* __nullable, const STUCancellationFlag* __nullable);

}

STU_INLINE
bool operator==(STURunGlyphIndex lhs, STURunGlyphIndex rhs) {
  return lhs.runIndex == rhs.runIndex & lhs.glyphIndex == rhs.glyphIndex;
}

STU_INLINE
bool operator!=(STURunGlyphIndex lhs, STURunGlyphIndex rhs) {
  return !(lhs == rhs);
}

STU_EXTERN_C_END
