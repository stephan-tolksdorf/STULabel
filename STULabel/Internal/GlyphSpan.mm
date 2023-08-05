// Copyright 2017–2018 Stephan Tolksdorf

#import "GlyphSpan.hpp"

#import "Font.hpp"

#include <atomic>

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

STU_NO_INLINE
GlyphsWithPositions GlyphSpan::getGlyphsWithPositionsImpl(GlyphRunRef run, CFRange glyphRange) {
  const Int count = glyphRange.length;
  STU_ASSERT(count > 0);
  CTRun* const ctRun = run.ctRun();
  const CGGlyph* glyphs = CTRunGetGlyphsPtr(ctRun);
  if (glyphs) {
    glyphs += glyphRange.location;
  }
  const CGPoint* positions = CTRunGetPositionsPtr(ctRun);
  if (positions) {
    positions += glyphRange.location;
  }
  if (glyphs && positions) {
    return GlyphsWithPositions{none, count, glyphs, positions};
  }
  static_assert(alignof(CGPoint)%alignof(CGGlyph) == 0);
  const Int bufferSize = count*sign_cast(  (positions ? 0 : sizeof(CGPoint))
                                         + (glyphs ? 0 : sizeof(CGGlyph)));
  TempArray<Byte> buffer{uninitialized, Count{bufferSize}};
  if (!positions) {
    positions = reinterpret_cast<CGPoint*>(buffer.begin());
    CTRunGetPositions(ctRun, glyphRange, const_cast<CGPoint*>(positions));
  }
  if (!glyphs) {
    glyphs = reinterpret_cast<CGGlyph*>(buffer.end()) - count;
    CTRunGetGlyphs(ctRun, glyphRange, const_cast<CGGlyph*>(glyphs));
  }
  return GlyphsWithPositions{std::move(buffer), count, glyphs, positions};
}

STU_NO_INLINE
Rect<CGFloat> GlyphSpan::imageBoundsImpl(GlyphRunRef run, CFRange glyphRange,
                                         LocalGlyphBoundsCache& glyphBoundsCache)
{
  GlyphsWithPositions gwp = getGlyphsWithPositionsImpl(run, glyphRange);
  Rect<CGFloat> bounds = glyphBoundsCache.boundingRect(run.font(), gwp);
  if (run.status() & kCTRunStatusHasNonIdentityMatrix) {
    bounds = CGRectApplyAffineTransform(bounds, run.textMatrix());
  }
  return bounds;
}


STU_NO_INLINE
StringIndicesArray GlyphSpan::stringIndicesArray_slowPath(GlyphRunRef run, CFRange glyphRange) {
  if (STU_UNLIKELY(glyphRange.length <= 0)) return {};
  auto& alloc = ThreadLocalAllocatorRef().get();
  Int* const p = alloc.allocate<Int>(glyphRange.length);
  CTRunGetStringIndices(run.ctRun(), glyphRange, p);
  return {ArrayRef{p, glyphRange.length}, alloc};
}

STU_NO_INLINE
AdvancesArray GlyphSpan::advancesArray_slowPath(GlyphRunRef run, Range<Int> glyphRange) {
  if (STU_UNLIKELY(glyphRange.isEmpty())) return {};
  // CTRunGetAdvances may return an aggregate advance value if we don't also ask for the
  // following advance (rdar://38554856).
  const Int extraOne = glyphRange.end < run.count();
  const Int count = glyphRange.count();
  auto& alloc = ThreadLocalAllocatorRef().get();
  CGSize* p = alloc.allocate<CGSize>(count + extraOne);
  CTRunGetAdvances(run.ctRun(), {glyphRange.start, count + extraOne}, p);
  if (extraOne) {
    p = alloc.decreaseCapacity(p, count, count + extraOne, count);
  }
  return {ArrayRef{p, count}, alloc};
}

STU_NO_INLINE
Range<Int> GlyphSpan::stringRangeImpl(const GlyphRunRef run, Range<Int> glyphRange) {
  const GlyphSpan runSpan{run};
  const Int runGlyphCount = runSpan.count();
  STU_DEBUG_ASSERT(!glyphRange.isEmpty() && Range(0, runGlyphCount).contains(glyphRange));
  const auto status = run.status();
  const bool isRightToLeft = status & kCTRunStatusRightToLeft;
  Range<Int> stringRange{uninitialized};
  if (!(status & kCTRunStatusNonMonotonic)) {
    const auto stringIndices = runSpan.stringIndices();
    stringRange.start = stringIndices[glyphRange.start];
    if (!isRightToLeft) {
      for (; glyphRange.end < runGlyphCount; ++glyphRange.end) {
        const Int stringIndex = stringIndices[glyphRange.end];
        if (stringIndex > stringRange.start) {
          stringRange.end = stringIndex;
          break;
        }
      }
      if (glyphRange.end == runGlyphCount) {
        stringRange.end = run.stringRange().end;
      }
    } else { // isRightToLeft
      for (; glyphRange.start - 1 >= 0; --glyphRange.start) {
        const Int stringIndex = stringIndices[glyphRange.start - 1];
        if (stringIndex > stringRange.start) {
          stringRange.end = stringIndex;
          break;
        }
      }
      if (glyphRange.start == 0) {
        stringRange.end = run.stringRange().end;
      }
    }
  } else { // Non-monotonous run
    const auto stringIndices = runSpan.stringIndicesArray();
    stringRange.start = maxValue<Int>;
    STU_DISABLE_LOOP_UNROLL
    for (const Int stringIndex : stringIndices[glyphRange]) {
      stringRange.start = min(stringRange.start, stringIndex);
    }
    stringRange.end = maxValue<Int>;
    STU_DISABLE_LOOP_UNROLL
    for (const Int stringIndex : stringIndices) {
      if (stringRange.start < stringIndex && stringIndex < stringRange.end) {
        stringRange.end = stringIndex;
      }
    }
    if (stringRange.end == maxValue<Int>) {
      stringRange.end = run.stringRange().end;
    }
  }
  return stringRange;
}

STU_NO_INLINE
bool GlyphSpan::copyInnerCaretOffsetsForLigatureGlyphAtIndexImpl(
                  GlyphRunRef run, Int glyphIndex, ArrayRef<CGFloat> outInnerCaretOffsets)
{
  STU_DEBUG_ASSERT(outInnerCaretOffsets.count() > 0);
  CTFont* const font = run.font();
  STU_DEBUG_ASSERT(0 <= glyphIndex && glyphIndex < run.count());
  GlyphSpan glyphSpan{run, {glyphIndex, glyphIndex + 1}, unchecked};
  const CGGlyph glyph = glyphSpan[0];
  Int n = CTFontGetLigatureCaretPositions(
            font, glyph, outInnerCaretOffsets.begin(), outInnerCaretOffsets.count());
  if (n == outInnerCaretOffsets.count()) return true;
  if (n != 0) return false;
  // The font does not contain caret offsets for this glyph, so we just divide up the glyph's
  // width equally.
  n = outInnerCaretOffsets.count();
  const CGFloat d = narrow_cast<CGFloat>(glyphSpan.typographicWidth())/(n + 1);
  CGFloat i1 = 1;
  STU_DISABLE_LOOP_UNROLL
  for (CGFloat& outOffset : outInnerCaretOffsets[{0, n}]) {
    outOffset = i1*d;
    i1 += 1;
  }
  return true;
}

// Currently the only way to get a CTRun's font is through CTRunGetAttributes. This is unreasonably
// slow for a run where the original font was substituted with a fallback font, because in this case
// CTRunGetAttributes copies the original attribute dictionary in order to replace the value for the
// font attribute key. CTRunGetAttributes caches the copied dictionary using atomic ops
// in the CTRun instance, but if another run uses the same attributes and has the same substituted
// attributes, CoreText will create another copy of the attributes. This is a gratuitous waste of
// resources (both time and memory) that quickly adds up to double digit percent slowdowns when e.g.
// laying out Arabic text that uses the system default font.
//
// Given this situation we resort to an extremly ugly hack: Use memcpy to copy the font value out of
// the CTRun object. Since this relies on a specific object layout, we have to protect
// against future changes of the object layout. We do this in checkCanUseFastCTRunFontGetter by
// typesetting several test strings and checking that the run fonts are accessible at the expected
// object offset. If we detect a change in the object layout, we fall back to using
// CTRunGetAttributes. Taking into account implementation details of CoreText, it seems very
// unlikely that a future change to CoreText makes our implementation unsafe.

// A feature request for a public `CTRunGetFont` function has been filed as rdar://34109755

static CTFont* slow_getFont(CTRun* run) {
  return (__bridge CTFont*)[(__bridge NSDictionary*)CTRunGetAttributes(run)
                              objectForKey:(__bridge NSString*)kCTFontAttributeName];
}

static UInt expectedCTRunMinMallocSize = 0x78 + sizeof(void*);

static UInt ctRunFontFieldOffset;
static void initializeCTRunFontFieldOffset() {
  if (@available(iOS 15, *)) {
    ctRunFontFieldOffset = 0x80;
  } else if (@available(iOS 12, *)) {
    ctRunFontFieldOffset = 0x78;
  } else {
    ctRunFontFieldOffset = 0x68;
  }
}

STU_INLINE
static CTFont* unsafe_getFont_assumingExpectedObjectLayout(CTRun* __nonnull run) {
  if constexpr (sizeof(void*) == 8) {
    const void* p1;
    memcpy(&p1, reinterpret_cast<const uint8_t*>(run) + 0x28, sizeof(p1));
    if (STU_LIKELY(p1 == reinterpret_cast<const uint8_t*>(run) + 0x48)) {
      CTFont* font;
      memcpy(&font, reinterpret_cast<const uint8_t*>(run) + ctRunFontFieldOffset, sizeof(font));
      if (STU_LIKELY(font)) {
        return font;
      }
    }
  }
  return nullptr;
}

static bool checkCTRunsAreCompatibleWithFastCTRunFontGetter(NSAttributedString* string) {
  RC<CTLine> const line = {CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string),
                           ShouldIncrementRefCount{false}};
  for (CTRun* const run : glyphRuns(line.get())) {
    if (malloc_size(run) < expectedCTRunMinMallocSize) return false;
    if (slow_getFont(run) != unsafe_getFont_assumingExpectedObjectLayout(run)) return false;
  }
  return true;
}

STU_NO_INLINE
static bool checkCanUseFastCTRunFontGetter(CTRun* __nonnull run) {
  if (malloc_size(run) < expectedCTRunMinMallocSize) return false;
  initializeCTRunFontFieldOffset();
  if (slow_getFont(run) != unsafe_getFont_assumingExpectedObjectLayout(run)) return false;

  UIFont* const font1 = [UIFont systemFontOfSize:16];
  {
    auto* const s = [[NSAttributedString alloc] initWithString:@"x"
                                                    attributes:@{NSFontAttributeName: font1}];
    if (!checkCTRunsAreCompatibleWithFastCTRunFontGetter(s)) return false;
  }
  {
    auto* const s = [[NSAttributedString alloc] initWithString:@"😀"
                                                    attributes:@{NSFontAttributeName: font1}];
    if (!checkCTRunsAreCompatibleWithFastCTRunFontGetter(s)) return false;
  }

  UIFont* const font2 = [UIFont fontWithName:@"HelveticaNeue" size:16];
  {
    auto* const s = [[NSMutableAttributedString alloc] init];
    [s appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"x " attributes:@{NSFontAttributeName: font2}]];
    [s appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"是" attributes:@{NSFontAttributeName: font2}]];
    if (!checkCTRunsAreCompatibleWithFastCTRunFontGetter(s)) return false;
  }
  {
    auto* const s = [[NSMutableAttributedString alloc] init];
    [s appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"0123456789"
                                 attributes:@{NSFontAttributeName: font2}]];
    [s appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"abcdef"
                                 attributes:@{NSFontAttributeName: font2,
                                              @"stuTest": NSNull.null}]];
    if (!checkCTRunsAreCompatibleWithFastCTRunFontGetter(s)) return false;
  }
  {
    STUTextAttachment* const attachment = [[STUTextAttachment alloc]
                                             initWithWidth:20 ascent:10 descent:10 leading:0
                                               imageBounds:CGRect{}
                                                 colorInfo:STUTextAttachmentColorInfo{}
                                      stringRepresentation:nil];
    auto* const s = [NSAttributedString stu_newWithSTUAttachment:attachment];
    if (!checkCTRunsAreCompatibleWithFastCTRunFontGetter(s)) return false;
  }

  return true;
}

enum class GetFontFastPathStatus : Int {
  mustUseSlowpath = -1,
  untested        =  0,
  canUseFastPath  =  1
};

STU_NO_INLINE
CTFont* GlyphRunRef::getFont(CTRun* run) {
  if (STU_UNLIKELY(!run)) return nullptr;
  if (sizeof(void*) == 8) {
    using Status = GetFontFastPathStatus;
    static std::atomic<Status> status = {Status::untested};
    const Status oldStatus = status.load(std::memory_order_relaxed);
    if (STU_UNLIKELY(oldStatus <= Status::untested)) {
      if (status == Status::mustUseSlowpath) goto SlowPath;
      if (checkCanUseFastCTRunFontGetter(run)) {
        status.store(Status::canUseFastPath, std::memory_order_relaxed);
      } else {
        status.store(Status::mustUseSlowpath, std::memory_order_relaxed);
        goto SlowPath;
      }
    }
    if (CTFont* const font = unsafe_getFont_assumingExpectedObjectLayout(run)) {
      return font;
    }
  }
SlowPath:
  return slow_getFont(run);
}

} // namespace stu_label
