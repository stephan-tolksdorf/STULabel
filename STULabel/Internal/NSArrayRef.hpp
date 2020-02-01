// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

#import <objc/message.h>

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

using CFArray = RemovePointer<CFArrayRef>;

template <typename T>
class NSArrayRef;

namespace detail {
  union NSArrayBufferOrObjectAtIndexMethod {
    using ObjectAtIndexMethod = id (*)(NSArray *, SEL, NSUInteger);

    ObjectAtIndexMethod objectAtIndexMethod;
    id __nullable __unsafe_unretained* buffer;
  };

  template <typename T>
  using UnretainedObjectPointer = Conditional<!isConvertible<T, id>, T,
                                              Unretained<RemovePointer<T>>>;

  CFTypeRef objectAtIndex(NSArray* array, id (* method)(NSArray *, SEL, NSUInteger),
                          NSUInteger) STU_PURE;
}

/// A non-owning reference to an NSArray<ObjectPointer> subspan.
template <typename ObjectPointer>
class NSArraySpan
      : public ArrayBase<NSArraySpan<ObjectPointer>,
                         detail::UnretainedObjectPointer<ObjectPointer>,
                         detail::UnretainedObjectPointer<ObjectPointer>,
                         NSArraySpan<ObjectPointer>, NSArraySpan<ObjectPointer>>
{
  static_assert(isPointer<ObjectPointer>);
  static_assert(isConvertible<ObjectPointer, id> || isBridgableToId<ObjectPointer>);

  using ObjectAtIndexMethod = detail::NSArrayBufferOrObjectAtIndexMethod::ObjectAtIndexMethod;

  UInt taggedArrayPointer_;
  UInt startIndex_;
  UInt count_;
  detail::NSArrayBufferOrObjectAtIndexMethod bufferOrMethod_;

  friend NSArrayRef<ObjectPointer>;

  STU_INLINE
  bool hasBuffer() const { return taggedArrayPointer_ & 1; }

  STU_INLINE
  NSArraySpan(NSArray* __unsafe_unretained __nullable array, Int startIndex, Int count, Unchecked)
  : taggedArrayPointer_{reinterpret_cast<UInt>(array)},
    startIndex_{sign_cast(startIndex)}, count_(sign_cast(count))
  {
    STU_DEBUG_ASSERT(!(taggedArrayPointer_ & 1));
    if (count == 0) {
      bufferOrMethod_.objectAtIndexMethod = reinterpret_cast<ObjectAtIndexMethod>(objc_msgSend);
      return;
    }
    // Here count > 0. We rely on that when comparing with n below.
    NSFastEnumerationState state;
    state.state = 0;
    id __nullable __unsafe_unretained buffer[1]; // We don't actually use the stack buffer.
    const UInt n = [array countByEnumeratingWithState:&state objects:buffer count:0];
    if (n >= sign_cast(startIndex + count)) {
      STU_DEBUG_ASSERT(state.itemsPtr != buffer);
      bufferOrMethod_.buffer = state.itemsPtr;
      taggedArrayPointer_ |= 1;
      return;
    }
    bufferOrMethod_.objectAtIndexMethod = reinterpret_cast<ObjectAtIndexMethod>(
                                            [array methodForSelector:@selector(objectAtIndex:)]);
  }

public:
  STU_INLINE
  NSArraySpan() noexcept
  : taggedArrayPointer_{}, startIndex_{}, count_{}, bufferOrMethod_{} {}

  using ObjectPointerOrId = Conditional<isConvertible<ObjectPointer, id>, ObjectPointer, id>;

  using UnretainedObjectPointer = Conditional<isConvertible<ObjectPointer, id>,
                                              Unretained<RemovePointer<ObjectPointer>>,
                                              ObjectPointer>;

  template <bool enable = isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArraySpan(NSArray<ObjectPointerOrId>* __unsafe_unretained __nullable array)
  : NSArraySpan{array, 0, sign_cast(array.count), unchecked}
  {}

  template <bool enable = isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  NSArraySpan(NSArray<ObjectPointerOrId>* __unsafe_unretained __nullable array, Range<Int> range)
  : NSArraySpan{array}
  {
    *this = (*this)[range];
  }

  template <bool enable = isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  NSArraySpan(NSArray<ObjectPointerOrId>* __unsafe_unretained __nullable array, Range<Int> range,
              Unchecked)
  : NSArraySpan{array, range.start, range.count(), unchecked}
  {}

  template <bool enable = !isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArraySpan(CFArray* __nullable array)
  : NSArraySpan{(__bridge NSArray*)array, 0, sign_cast(((__bridge NSArray*)array).count), unchecked}
  {}

  template <bool enable = !isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArraySpan(CFArray* __nullable array, Range<Int> range)
  : NSArraySpan{array}
  {
    *this = (*this)[range];
  }

  template <bool enable = !isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArraySpan(CFArray* __nullable array, Range<Int> range, Unchecked)
  : NSArraySpan{(__bridge NSArray*)array, range.start, range.count(), unchecked}
  {}

  class Iterator;

  STU_INLINE
  NSArraySpan(Iterator iter, Int count)
  : NSArraySpan{iter, count, unchecked}
  {
    STU_PRECONDITION(0 <= iter.index && 0 <= count && iter.index <= iter.array.count() - count);
  }

  STU_INLINE
  NSArraySpan(Iterator iter, Int count, Unchecked)
  : NSArraySpan{iter.span}
  {
    count_ = sign_cast(count);
    startIndex_ += sign_cast(iter.index);
  }

  explicit STU_INLINE
  operator bool() const { return taggedArrayPointer_ != 0; }

  STU_INLINE
  Iterator begin() const noexcept { return Iterator{.span = *this, .index = 0}; }

  STU_INLINE
  Int count() const noexcept {
    const Int count = sign_cast(count_);
    STU_ASSUME(count >= 0);
    return count;
  }

  STU_INLINE
  Unretained<NSArray<ObjectPointerOrId>> nsArray() const {
    return (__bridge NSArray<ObjectPointerOrId>*)cfArray();
  }

  STU_INLINE
  CFArray* cfArray() const {
    return reinterpret_cast<CFArray*>(taggedArrayPointer_ & ~UInt{1});
  }

  STU_INLINE
  Int startIndexInNSArray() {
    const Int startIndex = sign_cast(startIndex_);
    STU_ASSUME(startIndex >= 0);
    return startIndex;
  }

  /// \note The Iterator does no bounds checking (in release mode).
  class Iterator : public IteratorBase<Iterator, std::random_access_iterator_tag,
                                       UnretainedObjectPointer>
  {
  public:
    NSArraySpan span;
    Int index;

    STU_INLINE
    UnretainedObjectPointer operator*() const noexcept(!STU_ASSERT_MAY_THROW) {
      STU_DEBUG_ASSERT(sign_cast(index) < span.count_);
      const UInt i = span.startIndex_ + sign_cast(index);
      id __unsafe_unretained p;
      if (span.hasBuffer()) {
        p = span.bufferOrMethod_.buffer[i];
      } else {
        p = (__bridge id)detail::objectAtIndex((__bridge NSArray*)span.cfArray(),
                                               span.bufferOrMethod_.objectAtIndexMethod, i);
      }
      if constexpr (!isConvertible<ObjectPointer, id>) {
        return static_cast<ObjectPointer>((__bridge void*)p);
      } else {
        return static_cast<ObjectPointer>(p);
      }
    }

    STU_INLINE
    Iterator& operator+=(Int offset) noexcept {
      index += offset;
      return *this;
    }

    STU_INLINE
    Iterator& operator-=(Int offset) noexcept {
      index -= offset;
      return *this;
    }

    STU_INLINE
    bool operator==(const Iterator& other) const noexcept {
      return index == other.index;
    }

    STU_INLINE
    bool operator<(const Iterator& other) const noexcept {
      return index < other.index;
    }
  };

  using Reversed = ReversedArrayRef<NSArraySpan<ObjectPointer>>;
};

/// A non-owning reference to an NSArray<T*> instance.
template <typename ObjectPointer>
class NSArrayRef
      : public ArrayBase<NSArrayRef<ObjectPointer>,
                         detail::UnretainedObjectPointer<ObjectPointer>,
                         detail::UnretainedObjectPointer<ObjectPointer>,
                         NSArraySpan<ObjectPointer>, NSArraySpan<ObjectPointer>>
{
  static_assert(isPointer<ObjectPointer>);
  static_assert(isConvertible<ObjectPointer, id> || isBridgableToId<ObjectPointer>);

  UInt taggedArrayPointer_;
  UInt count_;
  detail::NSArrayBufferOrObjectAtIndexMethod bufferOrMethod_;

  bool hasBuffer() const { return taggedArrayPointer_ & 1; }

  STU_INLINE
  NSArrayRef(NSArraySpan<ObjectPointer> fullArraySpan, Unchecked) {
    taggedArrayPointer_ = fullArraySpan.taggedArrayPointer_;
    count_ = fullArraySpan.count_;
    bufferOrMethod_ = fullArraySpan.bufferOrMethod_;
  }

public:
  STU_INLINE
  NSArrayRef() noexcept
  : taggedArrayPointer_{}, count_{}, bufferOrMethod_{} {}

  using ObjectPointerOrId = Conditional<isConvertible<ObjectPointer, id>, ObjectPointer, id>;

  template <bool enable = isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  NSArrayRef(NSArray<ObjectPointerOrId>* __unsafe_unretained __nullable array)
  : NSArrayRef{NSArraySpan<ObjectPointer>{array}, unchecked}
  {}

  template <bool enable = !isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArrayRef(CFArray* __nullable array)
  : NSArrayRef{NSArraySpan<ObjectPointer>{array}, unchecked}
  {}

  template <bool enable = isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  NSArrayRef(NSArray<ObjectPointerOrId>* __unsafe_unretained __nullable array, Count<Int> count,
             Unchecked)
  : NSArrayRef{NSArraySpan<ObjectPointer>{array, Range{0, count.value}, unchecked}, unchecked}
  {
    STU_DEBUG_ASSERT(sign_cast(count.value) == array.count);
  }

  template <bool enable = !isConvertible<ObjectPointer, id>, EnableIf<enable> = 0>
  STU_INLINE
  explicit NSArrayRef(CFArray* __nullable array, Count<Int> count, Unchecked)
  : NSArrayRef{NSArraySpan<ObjectPointer>{array, Range{0, count.value}, unchecked}, unchecked}
  {
    STU_DEBUG_ASSERT(count.value == CFArrayGetCount(array));
  }

  /* implicit */ STU_INLINE
  operator NSArraySpan<ObjectPointer>() const noexcept {
    NSArraySpan<ObjectPointer> span;
    span.taggedArrayPointer_ = taggedArrayPointer_;
    span.count_ = count_;
    span.bufferOrMethod_ = bufferOrMethod_;
    return span;
  }

  explicit STU_INLINE
  operator bool() const { return taggedArrayPointer_ != 0; }

  STU_INLINE
  Int count() const noexcept {
    const Int count = sign_cast(count_);
    STU_ASSUME(count >= 0);
    return count;
  }

  STU_INLINE
  Unretained<NSArray<ObjectPointerOrId>> nsArray() const {
    return (__bridge NSArray<ObjectPointerOrId>*)cfArray();
  }

  STU_INLINE
  CFArray* cfArray() const {
    return reinterpret_cast<CFArray*>(taggedArrayPointer_ & ~UInt{1});
  }

  using Iterator = typename NSArraySpan<ObjectPointer>::Iterator;

  STU_INLINE
  Iterator begin() const noexcept { return Iterator{.span = *this, .index = 0}; }
};

}
                     
#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
