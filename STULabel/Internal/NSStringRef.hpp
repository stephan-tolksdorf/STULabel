// Copyright 2017–2018 Stephan Tolksdorf

#import "UnicodeCodePointProperties.hpp"

#import "ThreadLocalAllocator.hpp"

#import "stu/FunctionRef.hpp"
#import "stu/ArrayUtils.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

using CFString = RemovePointer<CFStringRef>;

namespace detail {
  enum class NSStringRefBufferKind : UInt8 { utf16, ascii, none };
  template <NSStringRefBufferKind> class NSStringRefBuffer;
}

using TempStringBuffer = TempArray<Char16>;

/// A non-owning reference to an NSString instance.
///
/// @note All indices are expected to be code point aligned. Be careful with +/- 1 index offsets!
class NSStringRef {
public:
  STU_INLINE
  explicit NSStringRef(NSString* __unsafe_unretained string)
  : NSStringRef((__bridge CFStringRef)string)
  {}

  explicit NSStringRef(CFString* string, Optional<Ref<TempStringBuffer>> = none);

  /* implicit */ STU_INLINE_T
  operator CFString*() const { return string_; }

  STU_INLINE_T
  Int count() const {
    const Int count = count_;
    // Just in case the optimizer doesn't figure this out from the bit field size.
    STU_ASSUME(count >= 0);
    return count;
  }

  // The index is a template parameter here in order to avoid ambiguities for non-Int arguments
  // that arise due to the implicit conversion operator to CFString*.
  template <typename Integer, EnableIf<isSafelyConvertible<Integer, Int>> = 0>
  STU_INLINE_T
  Char16 operator[](const Integer index) const {
    const Int i = index;
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(0 <= i && i < count);
    Char16 result;
    if (kind == BufferKind::utf16) {
      result = utf16Buffer()[i];
    } else if (kind == BufferKind::ascii) {
      result = asciiBuffer()[i];
    } else {
      result = utf16CharAtIndex_slowPath(i);
    }
    return result;
  }

  bool hasCRLFAtIndex(Int index) const {
    return 0 <= index && index < count() - 1
        && operator[](index) == '\r' && operator[](index + 1) == '\n';
  }

  STU_INLINE
  Char32 codePointAtUTF16Index(Int index) const {
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(0 <= index && index < count);
    Char32 cp;
    if (kind == BufferKind::utf16) {
      const Char16 c0 = utf16Buffer()[index];
      cp = c0;
      if (STU_UNLIKELY(isHighSurrogate(c0))) {
        if (STU_LIKELY(index + 1 != count)) {
          const Char16 c1 = utf16Buffer()[index + 1];
          if (STU_LIKELY(isLowSurrogate(c1))) {
            cp = codePointFromSurrogatePair(c0, c1);
          }
        }
      }
    } else if (kind == BufferKind::ascii) {
      cp = asciiBuffer()[index];
    } else {
      cp = codePointAtUTF16Index_slowPath(index);
    }
    return cp;
  }

  STU_INLINE
  void copyUTF16Chars(Range<Int> utf16IndexRange, ArrayRef<Char16> out) const {
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(Range(0, count).contains(utf16IndexRange));
    STU_PRECONDITION(utf16IndexRange.count() == out.count());
    if (!utf16IndexRange.isEmpty()) {
      if (kind == BufferKind::utf16) {
        array_utils::copyConstructArray(ArrayRef{utf16Buffer() + utf16IndexRange.start, out.count()},
                                       out.begin());
      } else {
        copyUTF16Chars_slowPath(NSRange(utf16IndexRange), out.begin());
      }
    }
    STU_ASSUME(kind == kind_);
    STU_ASSUME(count == count_);
  }

  // "Grapheme cluster" here always means "default Unicode extended grapheme cluster"

  Int endIndexOfGraphemeClusterAt(Int index) const {
    const Int count = this->count();
    STU_PRECONDITION(0 <= index && index < count);
    Int result = endIndexOfGraphemeClusterAtImpl(index);
    STU_ASSUME(index < result && result <= count);
    return result;
  }

  Int indexOfLastGraphemeClusterBreakBefore(Int index) const {
    const Int count = this->count();
    STU_PRECONDITION(0 < index && index <= count);
    Int result = indexOfLastGraphemeClusterBreakBeforeImpl(index);
    STU_ASSUME(0 <= result && result < index);
    return result;
  }

  Int indexOfFirstGraphemeClusterBreakNotBefore(Int index) const {
    const Int count = this->count();
    Int result;
    if (0 < index && index < count) {
      result = indexOfFirstGraphemeClusterBreakNotBeforeImpl(index);
    } else {
      STU_PRECONDITION(0 <= index && index <= count);
      result = index;
    }
    STU_ASSUME(index <= result && result <= count);
    return result;
  }

  Int startIndexOfGraphemeClusterAt(Int index) const {
    const Int count = this->count();
    Int result;
    if (0 < index && index < count) {
      result = startIndexOfGraphemeClusterAtImpl(index);
    } else {
      STU_PRECONDITION(0 <= index && index <= count);
      result = index;
    }
    STU_ASSUME(0 <= result && result <= index);
    return result;
  }

  Int countGraphemeClusters() const STU_PURE;

  /// Returns the grapheme cluster string ranges of the grapheme clusters overlapping the specified
  /// string range.
  ///
  /// @note The first (last) grapheme cluster string ranges may extend to before (after) the
  ///       specified string range.
  ///
  /// @returns The number of non-ignorable grapheme clusters, which maybe larger than
  ///          `outStringIndices.count()`.
  Int copyRangesOfGraphemeClustersSkippingTrailingIgnorables(
        Range<Int> stringRange, ArrayRef<Range<Int>> outStringRanges) const;

  template <typename Predicate, EnableIf<isCallable<Predicate, bool(Char16)>> = 0>
  /// Returns `range.start` if no code point in the range satisfies the predicate.
  STU_INLINE
  Int indexOfFirstUTF16CharWhere(Range<Int> range, Predicate&& predicate) const {
    return indexOfFirstUTF16CharWhere(range, [&](Int index __unused, Char16 ch) {
                                                return predicate(ch);
                                              });
  }
  /// Returns `max(range.start, range.end)` if no UTF-16 char in the range satisfies the predicate.
  STU_INLINE
  Int indexOfFirstUTF16CharWhere(Range<Int> range,
                                 FunctionRef<bool(Int index, Char16)> predicate) const
  {
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(   0 <= range.start && range.start <= count
                     && 0 <= range.end   && range.end <= count);
    Int result;
    if (STU_LIKELY(!range.isEmpty())) {
      result = indexOfFirstUTF16CharWhereImpl(range, predicate);
      STU_ASSUME(range.start <= result && result <= range.end);
    } else {
      result = range.start;
    }
    STU_ASSUME(kind == kind_); discard(kind);
    STU_ASSUME(count == count_);
    return result;
  }

  template <typename Predicate, EnableIf<isCallable<Predicate, bool(Char32)>> = 0>
  /// Returns `range.start` if no code point in the range satisfies the predicate.
  STU_INLINE
  Int indexOfFirstCodePointWhere(Range<Int> range, Predicate&& predicate) const {
    return indexOfFirstCodePointWhere(range, [&](Int index __unused, Char32 codePoint) {
                                                return predicate(codePoint);
                                              });
  }
  /// Returns `max(range.start, range.end)` if no code point in the range satisfies the predicate.
  STU_INLINE
  Int indexOfFirstCodePointWhere(Range<Int> range,
                                 FunctionRef<bool(Int index, Char32)> predicate) const
  {
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(   0 <= range.start && range.start <= count
                     && 0 <= range.end   && range.end <= count);
    Int result;
    if (STU_LIKELY(!range.isEmpty())) {
      result = indexOfFirstCodePointWhereImpl(range, predicate);
      STU_ASSUME(range.start <= result && result <= range.end);
    } else {
      result = range.start;
    }
    STU_ASSUME(kind == kind_); discard(kind);
    STU_ASSUME(count == count_);
    return result;
  }

  template <typename Predicate, EnableIf<isCallable<Predicate, bool(Char32)>> = 0>
  /// Returns `range.start` if no code point in the range satisfies the predicate.
  STU_INLINE
  Int indexOfEndOfLastCodePointWhere(Range<Int> range, Predicate&& predicate) const {
    return indexOfEndOfLastCodePointWhere(range, [&](Int index __unused, Char32 codePoint) {
                                                    return predicate(codePoint);
                                                 });
  }
  /// Returns `range.start` if no code point in the range satisfies the predicate.
  STU_INLINE
  Int indexOfEndOfLastCodePointWhere(Range<Int> range,
                                     FunctionRef<bool(Int index, Char32)> predicate) const
  {
    const BufferKind kind = kind_;
    const Int count = this->count();
    STU_PRECONDITION(   0 <= range.start && range.start <= count
                     && 0 <= range.end   && range.end <= count);
    Int result;
    if (STU_LIKELY(!range.isEmpty())) {
      result = indexOfEndOfLastCodePointWhereImpl(range, predicate);
      STU_ASSUME(range.start <= result && result <= range.end);
    } else {
      result = range.start;
    }
    STU_ASSUME(kind == kind_); discard(kind);
    STU_ASSUME(count == count_);
    return result;
  }

  Int indexOfTrailingWhitespaceIn(Range<Int> range) const;

  using GetCharactersMethod = void (*)(NSString*, SEL, unichar*, NSRange);

  // For testing purposes:

  struct Guts {
    Int count;
    const Char16* utf16;
    const char* ascii;
    GetCharactersMethod method;
  };

  Guts _private_guts() const {
    return {
      .count = sign_cast(count_),
      .utf16 = kind_ == BufferKind::utf16 ? utf16Buffer() : nullptr,
      .ascii = kind_ == BufferKind::ascii ? reinterpret_cast<const char*>(asciiBuffer()) : nullptr,
      .method = kind_ == BufferKind::none ? bufferOrMethod_.method : nullptr
    };
  }
  void _private_setGuts(Guts guts) {
    STU_CHECK(guts.count >= 0);
    count_ = sign_cast(guts.count);
    if (guts.utf16) {
      kind_ = BufferKind::utf16;
      bufferOrMethod_.buffer = guts.utf16;
    } else if (guts.ascii) {
      kind_ = BufferKind::ascii;
      bufferOrMethod_.buffer = guts.ascii;
    } else {
      STU_CHECK(guts.method);
      kind_ = BufferKind::none;
      bufferOrMethod_.method = guts.method;
    }
  }

private:
  using BufferKind = detail::NSStringRefBufferKind;
  template <BufferKind> friend class detail::NSStringRefBuffer;

  Char16 utf16CharAtIndex_slowPath(Int index) const STU_PURE;

  Char32 codePointAtUTF16Index_slowPath(Int index) const STU_PURE;

  void copyUTF16Chars_slowPath(NSRange utf16IndexRange, Char16* out) const;

  Int indexOfFirstUTF16CharWhereImpl(Range<Int> range, FunctionRef<bool(Int, Char16)>) const;

  Int indexOfFirstCodePointWhereImpl(Range<Int> range, FunctionRef<bool(Int, Char32)>) const;

  Int indexOfEndOfLastCodePointWhereImpl(Range<Int> range, FunctionRef<bool(Int, Char32)>) const;

  Int endIndexOfGraphemeClusterAtImpl(Int index) const STU_PURE;
  Int endIndexOfGraphemeClusterAtImpl_utf16Buffer(Int index, GraphemeClusterCategory,
                                                  Int nextIndex) const STU_PURE;

  Int indexOfFirstGraphemeClusterBreakNotBeforeImpl(Int index) const STU_PURE;
  Int indexOfFirstGraphemeClusterBreak_noBuffer(bool greaterThan, Int index) const STU_PURE;

  Int indexOfLastGraphemeClusterBreakBeforeImpl(Int index) const STU_PURE;
  Int indexOfLastGraphemeClusterBreakBeforeImpl_utf16Buffer(Int index,
                                                            GraphemeClusterCategory) const STU_PURE;

  Int startIndexOfGraphemeClusterAtImpl(Int index) const STU_PURE;
  Int indexOfLastGraphemeClusterBreakImpl_noBuffer(bool lessThan, Int index) const STU_PURE;

  STU_INLINE_T
  const Char16* utf16Buffer() const {
    return static_cast<const Char16*>(bufferOrMethod_.buffer);
  }

  STU_INLINE_T
  const unsigned char* asciiBuffer() const {
    return static_cast<const unsigned char*>(bufferOrMethod_.buffer);
  }

  CFString* string_;
  BufferKind kind_ : 2;
  UInt count_ : sizeof(Int)*8 - 2;
  union BufferOrGetCharactersMethod {
    const void* buffer;
    GetCharactersMethod method;
  } bufferOrMethod_;
};

static_assert(sizeof(NSStringRef) == 3*sizeof(void*));

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
