
#import "STUTextLink-Internal.hpp"

// Copyright 2017–2018 Stephan Tolksdorf

#import "STUObjCRuntimeWrappers.h"

#import "STUTextRectArray-Internal.hpp"

#import "Internal/CoreGraphicsUtils.hpp"
#import "Internal/Equal.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/IntervalSearchTable.hpp"
#import "Internal/Once.hpp"
#import "Internal/TextFrame.hpp"

#import "stu/BinarySearch.hpp"

#include <atomic>

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

@implementation STUTextLink {
@package
  Range<Int32> _rangeInOriginalString;
  Range<Int32> _rangeInTruncatedString;
  id _linkAttributeValue;
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (instancetype)initWithTextRectArray:(nullable STUTextRectArray* __unused)textRectArray {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (nonnull instancetype)initWithLinkAttributeValue:(nonnull id)linkAttributeValue
                             rangeInOriginalString:(NSRange)rangeInOriginalString
                            rangeInTruncatedString:(NSRange)rangeInTruncatedString
                                     textRectArray:(nullable STUTextRectArray*)textRectArray
{
  STU_CHECK_MSG(linkAttributeValue != nil, "The link attribute value is null.");
  self = [super initWithTextRectArray:textRectArray];
  _rangeInOriginalString = clampToInt32IndexRange(rangeInOriginalString);
  _rangeInTruncatedString = clampToInt32IndexRange(rangeInTruncatedString);
  _linkAttributeValue = linkAttributeValue;
  return self;
}

static STU_INLINE
Class stuTextLinkClass() {
  STU_STATIC_CONST_ONCE(Class, value, STUTextLink.class);
  return value;
}

static STUTextLink* __nonnull STUTextLinkCreateCreate(
                                __unsafe_unretained id attributeValue,
                                Range<Int32> rangeInOriginalString,
                                Range<Int32> rangeInTruncatedString,
                                ArrayRef<const TextLineSpan> spans,
                                ArrayRef<const TextFrameLine> lines,
                                TextFrameOrigin origin,
                                const TextFrameScaleAndDisplayScale& scaleFactors)
                              NS_RETURNS_RETAINED
{
  auto* const link = static_cast<STUTextLink*>(STUTextRectArrayCreate(stuTextLinkClass(), spans,
                                                                      lines, origin, scaleFactors));
  link->_rangeInOriginalString = rangeInOriginalString;
  link->_rangeInTruncatedString = rangeInTruncatedString;
  link->_linkAttributeValue = attributeValue;
  return link;
}

static STUTextLink* __nonnull STUTextLinkCopyWithTextFrameOriginOffset(
                                const STUTextLink* __unsafe_unretained link,
                                CGPoint textFrameOriginOffset) NS_RETURNS_RETAINED
{
  auto* const newLink = static_cast<STUTextLink*>(
                          STUTextRectArrayCopyWithOffset(stuTextLinkClass(), link,
                                                         textFrameOriginOffset));
  newLink->_rangeInOriginalString = link->_rangeInOriginalString;
  newLink->_rangeInTruncatedString = link->_rangeInTruncatedString;
  newLink->_linkAttributeValue = link->_linkAttributeValue;
  return newLink;
}

- (BOOL)isEqual:(id)object {
  if (self == object) return true;
  if (![object isKindOfClass:stuTextLinkClass()]) return false;
  STUTextLink* const other = object;
  return _rangeInOriginalString == other->_rangeInOriginalString
      && _rangeInTruncatedString == other->_rangeInTruncatedString
      && equal(_linkAttributeValue, other->_linkAttributeValue)
      && [super isEqual:other];
}

- (NSUInteger)hash {
  return narrow_cast<NSUInteger>(hash(_rangeInOriginalString, _rangeInTruncatedString));
}

- (id)linkAttribute {
  return _linkAttributeValue;
}

- (NSRange)rangeInOriginalString {
  return Range<UInt>{_rangeInOriginalString};
}

- (NSRange)rangeInTruncatedString {
  return Range<UInt>{_rangeInTruncatedString};
}

@end

// MARK: - STUTextLinkArray

@interface STUTextLinkArrayWithOriginalTextFrameOrigin : STUTextLinkArrayWithTextFrameOrigin
@end

STU_DISABLE_CLANG_WARNING("-Wincomplete-implementation")
@implementation STUTextLinkArray // This is an abstract base class.

STU_DISABLE_CLANG_WARNING("-Wimplicit-atomic-properties")
@dynamic count;
STU_REENABLE_CLANG_WARNING

STU_NO_INLINE
Unretained<STUTextLinkArray* __nonnull> stu_label::emptySTUTextLinkArray() {
  STU_STATIC_CONST_ONCE(STUTextLinkArrayWithOriginalTextFrameOrigin*, instance,
                        [[STUTextLinkArrayWithOriginalTextFrameOrigin alloc] init]);
  return instance;
}

+ (nonnull STUTextLinkArray*)emptyArray {
  return emptySTUTextLinkArray().unretained;
}

- (nonnull id)copyWithZone:(nullable NSZone* __unused)zone {
  return self; // STUTextLinkArray is immutable.
}


// A slow default implementation in terms of count and objectAtIndexedSubscript:.
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id*)buffer
                                    count:(NSUInteger __unused)length
{
  if (state->state == 0) {
    state->extra[0] = self.count;
    state->mutationsPtr = &state->extra[0];
  }
  const size_t count = state->extra[0];
  const size_t index = state->state;
  if (index >= count) return 0;
  buffer[0] = self[index];
  state->itemsPtr = buffer;
  state->state = index + 1;
  return 1;
}

- (STUTextLink*)linkMatchingLink:(STUTextLink* __nullable __unsafe_unretained)link {
  if (!link) return nil;
  return [self linkMatchingAttributeValue:link->_linkAttributeValue
                    rangeInOriginalString:Range<stu::UInt32>(link->_rangeInOriginalString)
                   rangeInTruncatedString:Range<stu::UInt32>(link->_rangeInTruncatedString)];
}

@end

STU_REENABLE_CLANG_WARNING

@implementation STUTextLinkArrayWithTextFrameOrigin {
@package
  CGPoint _textFrameOrigin;
}

CGPoint STUTextLinkArrayGetTextFrameOrigin(const STUTextLinkArrayWithTextFrameOrigin* self) {
  return self->_textFrameOrigin;
}
@end

// MARK: - STUTextLinkArrayWithOriginalTextFrameOrigin

@implementation STUTextLinkArrayWithOriginalTextFrameOrigin {
  STUTextLink* __unsafe_unretained * _array;
  Int _count;
}

STU_INLINE
ArrayRef<STUTextLink* __unsafe_unretained>
  links(const STUTextLinkArrayWithOriginalTextFrameOrigin*  self)
{
  return {self->_array, self->_count, unchecked};
}

STU_INLINE
IntervalSearchTable verticalSearchTable(const STUTextLinkArrayWithOriginalTextFrameOrigin* self) {
  const auto array = links(self);
  // The search table is stored immediately after the link array.
  const Float32* const maxYs = reinterpret_cast<const Float32*>(
                                 static_cast<const void*>(array.end()));
  return {ArrayRef{maxYs, array.count()}, ArrayRef{maxYs + array.count(), array.count()}};
}

STUTextLinkArrayWithTextFrameOrigin* __nonnull
  STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
    const TextFrame& textFrame, CGPoint frameOrigin,
    const TextFrameScaleAndDisplayScale& scaleFactors)
  NS_RETURNS_RETAINED
{
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const TaggedRangeLineSpans rls = findAndSortTaggedRangeLineSpans(
    textFrame.lines(), none,
    TextFlags::hasLink, SeparateParagraphs{false},
    [](const TextStyle& style) -> UInt {
      return reinterpret_cast<UInt>(style.linkInfo()->attribute);
    },
    [](UInt tag1, UInt tag2) -> bool {
       return [(__bridge id)reinterpret_cast<void*>(tag1)
                isEqual:(__bridge id)reinterpret_cast<void*>(tag2)];
    });

  const Int count = rls.spanTagCount;

  STUTextLinkArrayWithOriginalTextFrameOrigin* const instance =
    stu_createClassInstance(STUTextLinkArrayWithOriginalTextFrameOrigin.class,
                            sign_cast(count)*(sizeof(void*) + 2*sizeof(Float32)));

  const ArrayRef<STUTextLink* __unsafe_unretained> links{
    down_cast<STUTextLink* __unsafe_unretained *>(stu_getObjectIndexedIvars(instance)), count
  };
  // The verticalSearchTable is stored immediately after the links array.
  Float32* const increasingMaxYs = reinterpret_cast<Float32*>(static_cast<void*>(links.end()));
  Float32* const increasingMinYs = increasingMaxYs + count;

  instance->_textFrameOrigin = frameOrigin;
  instance->_array = links.begin();
  instance->_count = links.count();

  Float32 maxY = minValue<Float32>;
  Int32 linkIndex = 0;
  rls.forEachTaggedLineSpanSequence(
    [&](ArrayRef<const TextLineSpan> spans, FirstLastRange<const TaggedStringRange&> ranges)
  {
    const id __unsafe_unretained linkValue = (__bridge id)reinterpret_cast<void*>(ranges.first.tag);
    const Range<Int32> rangeInTruncatedString = {ranges.first.rangeInTruncatedString.start,
                                                 ranges.last.rangeInTruncatedString.end};

    // Extend range in original string to include any truncated part of the link text.
    Range<Int32> rangeInOriginalString = {ranges.first.rangeInOriginalString.start,
                                          ranges.last.rangeInOriginalString.end};
    const auto paragraphs = textFrame.paragraphs();
    if (!paragraphs[ranges.first.paragraphIndex].excisedRangeInOriginalString()
                                                .contains(rangeInOriginalString.start))
    {
      const TextStyle* style = ranges.first.nonOverriddenStyle();
      for (;;) {
        const TextStyle* previous = &style->previous();
        if (style == previous) break;
        if (!previous->hasLink() || !equal(linkValue, previous->linkInfo()->attribute)) break;
        style = previous;
      }
      rangeInOriginalString.start = style->stringIndex();
    }
    if (!paragraphs[ranges.last.paragraphIndex].excisedRangeInOriginalString()
                                               .contains(rangeInOriginalString.end - 1))
    {
      const TextStyle* style = ranges.last.nonOverriddenStyle();
      do style = &style->next();
      while (style->hasLink() && equal(linkValue, style->linkInfo()->attribute));
      rangeInOriginalString.end = style->stringIndex();
    }

    STUTextLink* const link = STUTextLinkCreateCreate(
                                linkValue, rangeInOriginalString, rangeInTruncatedString,
                                spans, textFrame.lines(), TextFrameOrigin{frameOrigin},
                                scaleFactors);
    const stu_label::Rect bounds = STUTextRectArrayGetBounds(link);

    links[linkIndex] = link;
    incrementRefCount(link);

    increasingMaxYs[linkIndex] = maxY = max(maxY, narrow_cast<Float32>(bounds.y.end));
    increasingMinYs[linkIndex] = narrow_cast<Float32>(bounds.y.start);
    ++linkIndex;
  });
  STU_ASSERT(linkIndex == count);

  { // A second pass over increasingMinYs that makes sure that the values are actually increasing.
    Float32 minY = infinity<Float32>;
    STU_DISABLE_LOOP_UNROLL
    for (Float32& value : ArrayRef{increasingMinYs, count}.reversed()) {
      value = minY = min(value, minY);
    }
  }

  return instance;
}

- (void)dealloc {
  for (STUTextLink* __unsafe_unretained p : links(self)) {
    decrementRefCount(p);
  }
}

- (size_t)count {
  return sign_cast(_count);
}

- (nonnull STUTextLink*)objectAtIndexedSubscript:(size_t)index {
  const auto array = links(self);
  STU_CHECK_MSG(index < sign_cast(array.count()), "The link index is out of bounds.");
  return array.begin()[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state
                                  objects:(__unsafe_unretained id* __unused)buffer
                                    count:(NSUInteger __unused)length
{
  if (state->state) return 0;
  state->state = 1;
  state->mutationsPtr = &state->state;
  state->itemsPtr = _array;
  return sign_cast(_count);
}

static Optional<Int> indexOfLinkClosestToPoint(
                       const STUTextLinkArrayWithOriginalTextFrameOrigin* self,
                       CGPoint point, CGFloat maxDistance)
{
  const ArrayRef<STUTextLink* __unsafe_unretained> array = links(self);
  const Range<Int> indexRange = verticalSearchTable(self)
                                .indexRange({narrow_cast<Float32>(point.y - maxDistance),
                                             narrow_cast<Float32>(point.y + maxDistance)});
  Optional<Int> minIndex = none;
  for (const Int i : indexRange.iter()) {
    const STUIndexAndDistance r = STUTextRectArrayFindRectClosestToPoint(array[i], point,
                                                                         maxDistance);
    if (r.index == NSNotFound || (r.distance == maxDistance && minIndex)) continue;
    minIndex = i;
    maxDistance = r.distance;
  }
  return minIndex;
}

static Optional<Int> indexOfLinkMatching(
                       const STUTextLinkArrayWithOriginalTextFrameOrigin* __unsafe_unretained self,
                       id attributeValue,
                       Range<Int32> rangeInOriginalString,
                       Range<Int32> rangeInTruncatedString)
{
  const ArrayRef<STUTextLink* __unsafe_unretained> array = links(self);
  const Range<Int> indexRange = {
    binarySearchFirstIndexWhere(array, [&](const STUTextLink* p) {
      return p->_rangeInOriginalString.end > rangeInOriginalString.start;
    }).indexOrArrayCount,
    binarySearchFirstIndexWhere(array, [&](const STUTextLink* p) {
      return p->_rangeInOriginalString.start >= rangeInOriginalString.end;
    }).indexOrArrayCount
  };
  Optional<Int> index = none;
  for (const Int i : indexRange.iter()) {
    STUTextLink& other = *array[i];
    if (!rangeInOriginalString.overlaps(other._rangeInOriginalString)) continue;
    if (!equal(attributeValue, other._linkAttributeValue)) continue;
    // We look for a link with a matching range in the truncated string.
    if (rangeInTruncatedString.overlaps(other._rangeInTruncatedString)) {
      return i;
    }
    // If we can't find such a link, we also accept the first link with a matching range in
    // the original string.
    if (!index) {
      index = i;
    }
  }
  return index;
}

Optional<Int> stu_label::indexOfMatchingLink(NSArray<STUTextLink*>* __unsafe_unretained array,
                                             STUTextLink* __unsafe_unretained link)
{
  const id attributeValue = link->_linkAttributeValue;
  const Range<Int32> rangeInOriginalString = link->_rangeInOriginalString;
  const Range<Int32> rangeInTruncatedString = link->_rangeInTruncatedString;
  Optional<Int> index = none;
  Int i = -1;
  for (STUTextLink* __unsafe_unretained other in array) {
    ++i;
    if (!rangeInOriginalString.overlaps(other->_rangeInOriginalString)) continue;
    if (!equal(attributeValue, other->_linkAttributeValue)) continue;
    // We look for a link with a matching range in the truncated string.
    if (rangeInTruncatedString.overlaps(other->_rangeInTruncatedString)) {
      return i;
    }
    // If we can't find such a link, we also accept the first link with a matching range in
    // the original string.
    if (!index) {
      index = i;
    }
  }
  return index;
}

- (STUTextLink*)linkMatchingAttributeValue:(nullable id)attributeValue
                     rangeInOriginalString:(NSRange)rangeInOriginalString
                    rangeInTruncatedString:(NSRange)rangeInTruncatedString
{
  if (attributeValue) {
    if (const Optional<Int> index =
          indexOfLinkMatching(self, attributeValue,
                              clampToInt32IndexRange(rangeInOriginalString),
                              clampToInt32IndexRange(rangeInTruncatedString)))
    {
      return _array[*index];
    }
  }
  return nil;
}

- (nullable STUTextLink*)linkClosestToPoint:(CGPoint)point
                                maxDistance:(CGFloat)maxDistance
{
  if (const Optional<Int> index = indexOfLinkClosestToPoint(self, point, maxDistance)) {
    return _array[*index];
  }
  return nil;
}

@end

// MARK: - STUTextLinkArrayWithShiftedTextFrameOrigin

@interface STUTextLinkArrayWithShiftedTextFrameOrigin : STUTextLinkArrayWithTextFrameOrigin
@end
@implementation STUTextLinkArrayWithShiftedTextFrameOrigin {
  Int _count;
  std::atomic<void*>* _newLinks;
  const STUTextLinkArrayWithOriginalTextFrameOrigin* _oldLinks;
}

STU_INLINE
ArrayRef<std::atomic<void*>> newLinks(const STUTextLinkArrayWithShiftedTextFrameOrigin* self) {
  return {self->_newLinks, self->_count, unchecked};
}

STU_DISABLE_CLANG_WARNING("-Wobjc-designated-initializers")
- (nonnull instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}
STU_REENABLE_CLANG_WARNING

STUTextLinkArrayWithTextFrameOrigin*
  STUTextLinkArrayCopyWithShiftedTextFrameOrigin(
    const STUTextLinkArrayWithTextFrameOrigin* __unsafe_unretained oldArray,
    CGPoint newTextFrameOrigin)
  NS_RETURNS_RETAINED
{
  STU_STATIC_CONST_ONCE(Class, textLinkArrayWithShiftedTextFrameOriginClass,
                               STUTextLinkArrayWithShiftedTextFrameOrigin.class);
  STU_ANALYZER_ASSUME(textLinkArrayWithShiftedTextFrameOriginClass != nil);
  const STUTextLinkArrayWithOriginalTextFrameOrigin* __unsafe_unretained oldLinks;
  if ([oldArray isKindOfClass:textLinkArrayWithShiftedTextFrameOriginClass]) {
    oldLinks = down_cast<const STUTextLinkArrayWithShiftedTextFrameOrigin*>(oldArray)->_oldLinks;
  } else {
    STU_DEBUG_ASSERT([oldArray isKindOfClass:STUTextLinkArrayWithOriginalTextFrameOrigin.class]);
    oldLinks = down_cast<const STUTextLinkArrayWithOriginalTextFrameOrigin*>(oldArray);
  }
  const Int count = links(oldLinks).count();
  STUTextLinkArrayWithShiftedTextFrameOrigin* const array =
    stu_createClassInstance(textLinkArrayWithShiftedTextFrameOriginClass,
                           sizeof(std::atomic<void*>)*sign_cast(count));
  // stu_createClassInstance zero-initialized the instance (including the array).
  array->_textFrameOrigin = newTextFrameOrigin;
  array->_count = count;
  array->_newLinks = static_cast<std::atomic<void*>*>(stu_getObjectIndexedIvars(array));
  array->_oldLinks = oldLinks;
  return array;
}

- (void)dealloc {
  for (std::atomic<void*>& ap : newLinks(self)) {
    // All other accesses to this array must have "happened before" dealloc is called, so we don't
    // to use memory_order_acquire here.
    if (void* const p = ap.load(std::memory_order_relaxed)) {
      discard((__bridge_transfer STUTextLink*)p); // Releases copied link.
    }
  }
}

- (size_t)count {
  return sign_cast(_count);
}

- (STUTextLink*)objectAtIndexedSubscript:(size_t)index {
  const ArrayRef<std::atomic<void*>> array = newLinks(self);
  STU_CHECK_MSG(index < sign_cast(array.count()), "The link index is out of bounds.");
  std::atomic<void*>& ap = array.begin()[index];
  if (ap.load(std::memory_order_relaxed)) {
    return (__bridge STUTextLink*)ap.load(std::memory_order_acquire);
  }
  const CGPoint offset = _textFrameOrigin - _oldLinks->_textFrameOrigin;
  STUTextLink* const link = STUTextLinkCopyWithTextFrameOriginOffset(
                              links(_oldLinks).begin()[index], offset);
  void* value = nullptr;
  if (ap.compare_exchange_strong(value, (__bridge void*)link,
                                 std::memory_order_release, std::memory_order_acquire))
  {
    value = (__bridge_retained void*)link;
  }
  return (__bridge STUTextLink*)value;
}

- (STUTextLink*)linkMatchingAttributeValue:(nullable id)attributeValue
                     rangeInOriginalString:(NSRange)rangeInOriginalString
                    rangeInTruncatedString:(NSRange)rangeInTruncatedString
{
  if (attributeValue) {
    const Optional<Int> index = indexOfLinkMatching(_oldLinks, attributeValue,
                                                    clampToInt32IndexRange(rangeInOriginalString),
                                                    clampToInt32IndexRange(rangeInTruncatedString));
    if (index) {
      return [self objectAtIndexedSubscript:sign_cast(*index)];
    }
  }
  return nil;
}

- (nullable STUTextLink*)linkClosestToPoint:(CGPoint)point
                                maxDistance:(CGFloat)maxDistance
{
  const CGPoint offset = _oldLinks->_textFrameOrigin - _textFrameOrigin;
  const Optional<Int> index = indexOfLinkClosestToPoint(_oldLinks, point + offset, maxDistance);
  return index ? [self objectAtIndexedSubscript:sign_cast(*index)] : nil;
}

@end

