// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextRectArray-Internal.hpp"

#import "STUObjCRuntimeWrappers.h"

#import "Internal/InputClamping.hpp"
#import "Internal/Once.hpp"
#import "Internal/TextLineSpansPath.hpp"

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

struct STUTextRectArrayData {
  Int32 rectCount;
  Int32 textLineIndexOffset;
  Int32 lineCount;
  bool pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular;
  stu_label::Rect<CGFloat> bounds;
  TextLineSpan spanArray[];

  // The textLineVerticalPositions are stored after the spanArray.
  static_assert(alignof(TextLineSpan) == alignof(TextLineVerticalPosition));

  static UInt sizeInBytes(Int rectCount, Int lineCount) {
    return sizeof(STUTextRectArrayData)
         + sign_cast(rectCount)*sizeof(TextLineSpan)
         + sign_cast(lineCount)*sizeof(TextLineVerticalPosition);
  }

  UInt sizeInBytes() const {
    return STUTextRectArrayData::sizeInBytes(rectCount, lineCount);
  }

  NSRange textLineRange() const {
    return {sign_cast(textLineIndexOffset), sign_cast(lineCount)};
  };

  STU_INLINE
  ArrayRef<TextLineSpan> spans() { return {spanArray, rectCount, unchecked}; }

  STU_INLINE
  ArrayRef<const TextLineSpan> spans() const { return {spanArray, rectCount, unchecked}; }


  STU_INLINE
  ArrayRef<TextLineVerticalPosition> textLineVerticalPositions() {
    return {reinterpret_cast<TextLineVerticalPosition*>(spans().end()), lineCount, unchecked};
  }

  STU_INLINE
  ArrayRef<const TextLineVerticalPosition> textLineVerticalPositions() const {
    return {reinterpret_cast<const TextLineVerticalPosition*>(spans().end()), lineCount, unchecked};
  }

  bool operator==(const STUTextRectArrayData& other) {
    if (bounds != other.bounds) return false;
    if (rectCount != other.rectCount) return false;
    if (textLineRange() != other.textLineRange()) return false;
    for (Int32 i = 0; i < rectCount; ++i) {
      const TextLineSpan& span = spanArray[i];
      const TextLineSpan& otherSpan = other.spanArray[i];
      if (span.x != otherSpan.x) return false;
      if (span.isLeftEndOfLine != otherSpan.isLeftEndOfLine) return false;
      if (span.isRightEndOfLine != otherSpan.isRightEndOfLine) return false;
      if (span.lineIndex != otherSpan.lineIndex) return false;
    }
    const auto vps = textLineVerticalPositions().begin();
    const auto otherVPS = other.textLineVerticalPositions().begin();
    for (Int32 i = 0; i < lineCount; ++i) {
      if (vps[i] != otherVPS[i]) return false;
    }
    return true;
  }

  bool operator!=(const STUTextRectArrayData& other) {
    return !(*this == other);
  }
};


@implementation STUTextRectArray {
  UInt taggedPointer_; // TODO: debug viewer
}

struct DataOrOtherArray {
  const STUTextRectArrayData* data;
  const STUTextRectArray* __unsafe_unretained otherArray;

  explicit STU_INLINE
  DataOrOtherArray(const STUTextRectArray* __unsafe_unretained array) {
    const UInt p = array->taggedPointer_;
    if (!(p & 1)) {
      data = reinterpret_cast<const STUTextRectArrayData*>(p);
      otherArray = nil;
      STU_ASSUME(data != nullptr);
    } else {
      data = nullptr;
      otherArray = (__bridge const STUTextRectArray*)reinterpret_cast<const void*>(p & ~UInt{1});
      STU_ASSUME(otherArray != nil);
    }
  }
};

- (instancetype)init {
  return [self initWithTextRectArray:nil];
}
- (instancetype)initWithTextRectArray:(nullable STUTextRectArray*)textRectArray {
  if (!textRectArray) {
    textRectArray = STUTextRectArray.emptyArray;
  }
  const UInt p = reinterpret_cast<UInt>((__bridge_retained void*)textRectArray);
  STU_ASSERT(!(p & 1));
  taggedPointer_ = p | 1;
  return self;
}

- (void)dealloc {
  const DataOrOtherArray d{self};
  if (d.otherArray) {
    decrementRefCount(d.otherArray);
  }
}

- (nonnull id)copyWithZone:(nullable NSZone* __unused)zone {
  return self; // STUTextRectArray is immutable.
}

static STU_INLINE
Class stuTextRectArrayClass() {
  STU_STATIC_CONST_ONCE(Class, value, STUTextRectArray.class);
  return value;
}

+ (STUTextRectArray*)emptyArray {
  STU_STATIC_CONST_ONCE(STUTextRectArray*, instance,
                        STUTextRectArrayCreate(stuTextRectArrayClass(), {}, {},
                                               TextFrameOrigin{},
                                               TextFrameScaleAndDisplayScale::one()));
  STU_ANALYZER_ASSUME(instance != nil);
  return instance;
}

STUTextRectArray* __nonnull STUTextRectArrayCreate(__nullable Class cls,
                                                   ArrayRef<const TextLineSpan> spans,
                                                   ArrayRef<const TextFrameLine> lines,
                                                   TextFrameOrigin frameOrigin,
                                                   const TextFrameScaleAndDisplayScale& scales)
                              NS_RETURNS_RETAINED
{
  if (!cls) {
    cls = stuTextRectArrayClass();
  }
  STU_ASSERT(spans.count() <= maxValue<Int32>);
  const Int32 lineIndexOffset = spans.isEmpty() ? 0 : spans[0].lineIndex;
  const Int32 lineCount = spans.isEmpty() ? 0
                        : spans[$ - 1].lineIndex - spans[0].lineIndex + 1;

  const UInt dataSize = STUTextRectArrayData::sizeInBytes(spans.count(), lineCount);
  STUTextRectArray* const instance = stu_createClassInstance(cls, dataSize);
  STU_DEBUG_ASSERT([instance isKindOfClass:stuTextRectArrayClass()]);
  STUTextRectArrayData& data = *down_cast<STUTextRectArrayData*>(stu_getObjectIndexedIvars(instance));
  instance->taggedPointer_ = reinterpret_cast<UInt>(&data);

  data.rectCount = narrow_cast<Int32>(spans.count());
  data.lineCount = lineCount;
  data.textLineIndexOffset = lineIndexOffset;
  if (spans.isEmpty()) {
    data.bounds = stu_label::Rect<CGFloat>{};
  } else {
    STU_DISABLE_LOOP_UNROLL
    for (Int i = 0; i < spans.count(); ++i) {
      TextLineSpan span = spans[i];
      span.x = frameOrigin.value.x + span.x*scales.textFrameScale.value();
      span.lineIndex = sign_cast(span.lineIndex - lineIndexOffset);
      span.rangeIndex = 0;
      data.spanArray[i] = span;
    }
    const ArrayRef<TextLineVerticalPosition> vpArray = data.textLineVerticalPositions();
    const Float64 yOffset = scales.textFrameScale == 1 ? frameOrigin.value.y
                          : frameOrigin.value.y/scales.textFrameScale;
    for (Int i = 0; i < vpArray.count(); ++i) {
      const TextFrameLine& line = lines[i + lineIndexOffset];
      TextLineVerticalPosition vp = textLineVerticalPosition(
                                      line, scales.displayScale, VerticalEdgeInsets{},
                                      VerticalOffsets{.textFrameOriginY = yOffset});
      vp.scale(scales.textFrameScale);
      vpArray[i] = vp;
    }
    const auto bounds = calculateTextLineSpansPathBounds(data.spans(), vpArray);
    data.pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular =
           bounds.pathExtendedToCommonHorizontalTextLineBoundsIsRect;
    data.bounds = narrow_cast<CGRect>(bounds.rect);
  }
  return instance;
}

STUTextRectArray* __nonnull STUTextRectArrayCopyWithOffset(
                              Class cls, const STUTextRectArray* __unsafe_unretained array,
                              CGPoint offset)
                            NS_RETURNS_RETAINED
{
  const DataOrOtherArray d{array};
  STU_ASSERT(d.data && "The array must have been created with STUTextRectArrayCreate.");
  const STUTextRectArrayData& data = *d.data;
  const UInt dataSize = data.sizeInBytes();
  STUTextRectArray* const instance = stu_createClassInstance(cls, dataSize);
  STU_DEBUG_ASSERT([instance isKindOfClass:stuTextRectArrayClass()]);
  STUTextRectArrayData& newData = *down_cast<STUTextRectArrayData*>(stu_getObjectIndexedIvars(instance));
  instance->taggedPointer_ = reinterpret_cast<UInt>(&newData);
  memcpy(&newData, &data, dataSize);
  if (offset.x != 0) {
    newData.bounds.x += offset.x;
    STU_DISABLE_LOOP_UNROLL
    for (TextLineSpan& span : newData.spans()) {
      span.x += offset.x;
    }
  }
  if (offset.y != 0) {
    newData.bounds.y += offset.y;
    STU_DISABLE_LOOP_UNROLL
    for (TextLineVerticalPosition& position : newData.textLineVerticalPositions()) {
      position.baseline += offset.y;
    }
  }
  return instance;
}

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  const DataOrOtherArray d{self};
  if (d.data) {
    if (![object isKindOfClass:stuTextRectArrayClass()]) return false;
    const DataOrOtherArray other{static_cast<STUTextRectArray*>(object)};
    if (other.data) {
      return d.data == other.data;
    }
    return [other.otherArray isEqual:self];
  }
  return [d.otherArray isEqual:object];
}

- (NSUInteger)hash {
  const DataOrOtherArray d{self};
  if (d.data) {
    return narrow_cast<NSUInteger>(hash(d.data->bounds));
  }
  return [d.otherArray hash];
}

- (size_t)rectCount {
  const DataOrOtherArray d{self};
  if (d.data) {
    return sign_cast(d.data->rectCount);
  }
  return [d.otherArray rectCount];
}

- (NSRange)textLineRange {
  const DataOrOtherArray d{self};
  if (d.data) {
    return d.data->textLineRange();
  }
  return [d.otherArray textLineRange];
}

- (CGRect)bounds {
  const DataOrOtherArray d{self};
  if (d.data) {
    return d.data->bounds;
  }
  return [d.otherArray bounds];
}

stu_label::Rect<CGFloat> STUTextRectArrayGetBounds(STUTextRectArray* __unsafe_unretained self) {
  const DataOrOtherArray d{self};
  if (d.data) {
    return d.data->bounds;
  }
  return [d.otherArray bounds];
}

- (bool)pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular {
  const DataOrOtherArray d{self};
  if (d.data) {
    return d.data->pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular;
  }
  return [d.otherArray pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular];
}

#define CHECK_RECT_INDEX(data, index) \
  STU_CHECK_MSG(static_cast<UInt>(index) < sign_cast((data).rectCount), \
                "The rect index is out of bounds.")

STU_INLINE stu_label::Rect<Float64> rectAtIndex(const STUTextRectArrayData& data, Int index) {
  const TextLineSpan span = data.spans()[index];
  const auto verticalPositions = data.textLineVerticalPositions();
  verticalPositions.assumeValidIndex(span.lineIndex);
  const TextLineVerticalPosition vpos = verticalPositions[span.lineIndex];
  return {span.x, vpos.y()};
}

- (CGRect)rectAtIndex:(size_t)index {
  const DataOrOtherArray d{self};
  if (d.data) {
    const Int i = sign_cast(index);
    CHECK_RECT_INDEX(*d.data, i);
    return narrow_cast<CGRect>(rectAtIndex(*d.data, i));
  }
  return [d.otherArray rectAtIndex:index];
}

- (CGFloat)baselineForRectAtIndex:(size_t)index {
  const DataOrOtherArray d{self};
  if (d.data) {
    const Int i = sign_cast(index);
    CHECK_RECT_INDEX(*d.data, i);
    const Int lineIndex = d.data->spans()[i].lineIndex;
    const auto verticalPositions = d.data->textLineVerticalPositions();
    return narrow_cast<CGFloat>(verticalPositions[lineIndex].baseline);
  }
  return [d.otherArray baselineForRectAtIndex:index];
}

- (size_t)textLineIndexForRectAtIndex:(size_t)index {
  const DataOrOtherArray d{self};
  if (d.data) {
    const Int i = sign_cast(index);
    CHECK_RECT_INDEX(*d.data, i);
    return sign_cast(d.data->textLineIndexOffset) + d.data->spans()[i].lineIndex;
  }
  return [d.otherArray textLineIndexForRectAtIndex:index];
}

- (CGFloat)baselineForTextLineAtIndex:(size_t)textLineIndex {
  const DataOrOtherArray d{self};
  if (d.data) {
    const Int i = sign_cast(textLineIndex);
    STU_CHECK_MSG(sign_cast(i) < sign_cast(d.data->lineCount), "The line index is out of bounds.");
    const auto verticalPositions = d.data->textLineVerticalPositions();
    return narrow_cast<CGFloat>(verticalPositions[i].baseline);
  }
  return [d.otherArray baselineForTextLineAtIndex:textLineIndex];
}

- (nonnull NSMutableArray<NSValue*>*)copyRectsWithOffset:(CGVector)offset {
  const DataOrOtherArray d{self};
  if (d.data) {
    const STUTextRectArrayData& data = *d.data;
    const Int rectCount = data.rectCount;
    NSMutableArray* const array = [[NSMutableArray alloc] initWithCapacity:sign_cast(rectCount)];
    for (Int i = 0; i < rectCount; ++i) {
      array[sign_cast(i)] = @(narrow_cast<CGRect>(rectAtIndex(data, i) + offset));
    }
    return array;
  }
  return [d.otherArray copyRectsWithOffset:offset];
}

STUIndexAndDistance STUTextRectArrayFindRectClosestToPoint(
                      const STUTextRectArray* __unsafe_unretained self,
                      CGPoint point, CGFloat maxDistance)
{
  const DataOrOtherArray d{self};
  if (d.data) {
    const STUTextRectArrayData& data = *d.data;
    const Int rectCount = data.rectCount;
    if (!(maxDistance >= 0)) {
      maxDistance = 0;
    }
    const CGFloat maxSquaredDistance = maxDistance*maxDistance;
    if (rectCount > 0 && data.bounds.squaredDistanceTo(point) <= maxSquaredDistance) {
      Int minIndex = 0;
      Float64 minSquaredDistance = rectAtIndex(data, 0).squaredDistanceTo(point);
      for (Int i = 1; i < rectCount; ++i) {
        data.spans().assumeValidIndex(i);
        const Float64 squaredDistance = rectAtIndex(data, i).squaredDistanceTo(point);
        if (squaredDistance < minSquaredDistance) {
          minSquaredDistance = squaredDistance;
          minIndex = i;
          if (squaredDistance == 0) break;
        }
      }
      if (minSquaredDistance <= maxSquaredDistance) {
        return {.index = sign_cast(minIndex),
                .distance = sqrt(narrow_cast<CGFloat>(minSquaredDistance))};
      }
    }
    return {.index = NSNotFound, .distance = maxValue<CGFloat>};
  }
  return [d.otherArray findRectClosestToPoint:point maxDistance:maxDistance];
}

- (STUIndexAndDistance)findRectClosestToPoint:(CGPoint)point maxDistance:(CGFloat)maxDistance {
  return STUTextRectArrayFindRectClosestToPoint(self, point, maxDistance);
}

-   (CGPathRef)createPathWithEdgeInsets:(UIEdgeInsets)edgeInsets
                           cornerRadius:(CGFloat)cornerRadius
extendTextLinesToCommonHorizontalBounds:(bool)extendLinesToCommonBounds
                       fillTextLineGaps:(bool)fillTextLineGaps
                              transform:(nullable const CGAffineTransform*)transform
    CF_RETURNS_RETAINED
{
  const DataOrOtherArray d{self};
  if (d.data) {
    const STUTextRectArrayData& data = *d.data;
    ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
    ThreadLocalArenaAllocator alloc{Ref{buffer}};
    cornerRadius = clampNonNegativeFloatInput(cornerRadius);
    edgeInsets = clampEdgeInsetsInput(edgeInsets);
    CGMutablePathRef path = CGPathCreateMutable();
    addLineSpansPath(*path, data.spans(), data.textLineVerticalPositions(),
                     ShouldFillTextLineGaps{fillTextLineGaps},
                     ShouldExtendTextLinesToCommonHorizontalBounds{extendLinesToCommonBounds},
                     edgeInsets, CornerRadius{cornerRadius}, nil, transform);
    return path;
  }
  STU_ANALYZER_ASSUME(d.otherArray != nil);
  return [d.otherArray createPathWithEdgeInsets:edgeInsets
                                   cornerRadius:cornerRadius
        extendTextLinesToCommonHorizontalBounds:extendLinesToCommonBounds
                               fillTextLineGaps:fillTextLineGaps
                                      transform:transform];
}

@end





