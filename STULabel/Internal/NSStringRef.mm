// Copyright 2017–2018 Stephan Tolksdorf

#import "NSStringRef.hpp"

#import "stu/Array.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

STU_NO_INLINE
NSStringRef::NSStringRef(CFString* string, Optional<Ref<TempStringBuffer>> optBuffer)
: string_(string)
{
  const Int length = CFStringGetLength(string);
  BufferKind kind = BufferKind::none;
  if (length != 0) {
  #if TARGET_OS_IPHONE
    const bool isLikelyTaggedPointer = reinterpret_cast<ptrdiff_t>(string) < 0;
  #else
    const bool isLikelyTaggedPointer = false;
  #endif
    bool noBuffer = isLikelyTaggedPointer;
    if (!noBuffer) {
      if (const UTF16Char* const utf16 = CFStringGetCharactersPtr(string)) {
        bufferOrMethod_.buffer = reinterpret_cast<const Char16*>(utf16);
        kind = BufferKind::utf16;
      } else if (const char* const ascii = CFStringGetCStringPtr(string, kCFStringEncodingASCII)) {
        bufferOrMethod_.buffer = reinterpret_cast<const unsigned char*>(ascii);
        kind = BufferKind::ascii;
      } else {
        noBuffer = true;
      }
    }
    if (noBuffer) {
      if (optBuffer && length < 2048) {
        TempStringBuffer& buffer = *optBuffer;
        buffer = TempStringBuffer{uninitialized, Count{length + 1}, buffer.allocator()};
        static_assert(sizeof(*buffer.begin()) == sizeof(UTF16Char));
        [(__bridge NSString*)string getCharacters:reinterpret_cast<UTF16Char*>(buffer.begin())
                                            range:NSRange{0, sign_cast(length)}];
        buffer[length] = 0;
        bufferOrMethod_.buffer = reinterpret_cast<const Char16*>(buffer.begin());
        kind = BufferKind::utf16;
      } else {
        bufferOrMethod_.method = reinterpret_cast<GetCharactersMethod>(
                                   [(__bridge NSString*)string
                                     methodForSelector:@selector(getCharacters:range:)]);
        kind = BufferKind::none;
      }
    }
  } else { // length == 0
    bufferOrMethod_.buffer = nullptr;
    kind = BufferKind::utf16;
  }
  kind_ = kind;
  count_ = sign_cast(length);
}

STU_NO_INLINE // Should be pure enough for our purposes.
Char16 NSStringRef::utf16CharAtIndex_slowPath(Int index) const {
  UTF16Char result;
  bufferOrMethod_.method((__bridge NSString*)string_, @selector(getCharacters:range:),
                         &result, NSRange{sign_cast(index), 1});
  return result;
}

STU_NO_INLINE
Char32 NSStringRef::codePointAtUTF16Index_slowPath(Int index) const {
  UTF16Char chars[2];
  const Int n = min(2, count() - index);
  bufferOrMethod_.method((__bridge NSString*)string_, @selector(getCharacters:range:),
                         chars, NSRange(Range{index, Count{n}}));
  if (!isHighSurrogate(chars[0]) || n == 1 || !isLowSurrogate(chars[1])) {
    return chars[0];
  }
  return codePointFromSurrogatePair(chars[0], chars[1]);
}

STU_NO_INLINE
void NSStringRef::copyUTF16Chars_slowPath(NSRange utf16IndexRange, Char16* out) const {
  if (kind_ == BufferKind::ascii) {
    const unsigned char* const buffer = this->asciiBuffer() + utf16IndexRange.location;
    STU_DISABLE_LOOP_UNROLL
    for (UInt i = 0; i < utf16IndexRange.length; ++i) {
      out[i] = buffer[i];
    }
    return;
  }
  bufferOrMethod_.method((__bridge NSString*)string_, @selector(getCharacters:range:),
                         reinterpret_cast<UTF16Char*>(out), utf16IndexRange);
}

Int NSStringRef::copyRangesOfGraphemeClustersSkippingTrailingIgnorables(
                   Range<Int> stringRange, ArrayRef<Range<Int>> outStringRanges) const
{
  Int count = 0;
  for (Int i = startIndexOfGraphemeClusterAt(stringRange.start); i < stringRange.end;) {
    const Range<Int> graphemeClusterRange = {i, endIndexOfGraphemeClusterAt(i)};
    if (count < outStringRanges.count()) {
      outStringRanges[count] = graphemeClusterRange;
    }
    ++count;
    i = graphemeClusterRange.end;
    if (i >= stringRange.end) break;
    i = indexOfFirstCodePointWhere(Range{i, stringRange.end}, isNotIgnorable);
  }
  return count;
}

Int NSStringRef::countGraphemeClusters() const {
  Int graphemeCount = 0;
  for (Int i = 0, count = this->count(); i < count; i = endIndexOfGraphemeClusterAt(i)) {
    ++graphemeCount;
  }
  return graphemeCount;
}

namespace detail {

template <NSStringRefBufferKind kind>
class NSStringRefBuffer {
  static_assert(   kind == NSStringRefBufferKind::utf16
                || kind == NSStringRefBufferKind::ascii);
  using Char = Conditional<kind == NSStringRefBufferKind::utf16, Char16, unsigned char>;
public:
  struct Storage {};

  STU_INLINE
  NSStringRefBuffer(const NSStringRef& string, Range<Int> range, Int startIndex, Storage __unused)
  : buffer_{static_cast<const Char*>(string.bufferOrMethod_.buffer)},
    start_{range.start},
    end_{range.end},
    index_{startIndex}
  {
    STU_DEBUG_ASSERT(string.kind_ == kind);
    STU_DEBUG_ASSERT(range.start <= startIndex && startIndex <= range.end);
  }

  STU_INLINE_T
  Int index() const { return index_; }

  STU_INLINE
  Optional<Char16> getUTF16CharAndSkipToNext() {
    if (STU_LIKELY(index_ != end_)) {
      return buffer_[index_++];
    }
    return none;
  }

  STU_INLINE
  Optional<Char16> skipToPreviousUTF16CharAndGetIt() {
    if (STU_LIKELY(index_ != start_)) {
      return buffer_[--index_];
    }
    return none;
  }

private:
  const Char* const buffer_;
  const Int start_;
  const Int end_;
  Int index_;
};

template <>
class NSStringRefBuffer<NSStringRefBufferKind::none> {
public:
  // LLVM's optimizer currently is not able to promote this class's fields to registers when the
  // storage array is embedded in the class, so we place it externally and pass in a reference to
  // the constructor.
  struct Storage { UTF16Char array[64]; };

  STU_INLINE
  NSStringRefBuffer(const NSStringRef& string, Range<Int> range, Int startIndex, Storage& storage)
  : string_{(__bridge NSString*)string.string_},
    getCharacters_{string.bufferOrMethod_.method},
    array_{storage.array},
    startIndex_{range.start},
    endIndex_{range.end},
    arrayStartIndex_{startIndex},
    arrayCount_{0},
    indexInArray_{0}
  {
    STU_DEBUG_ASSERT(range.start <= startIndex && startIndex <= range.end);
  }

  STU_INLINE_T
  Int index() const { return arrayStartIndex_ + indexInArray_; }

  STU_INLINE
  Optional<Char16> getUTF16CharAndSkipToNext() {
    if (STU_UNLIKELY(indexInArray_ == arrayCount_)) {
      const Int index = this->index();
      if (index == endIndex_) {
        return none;
      }
      const Int n = min(endIndex_ - index, arrayLength(array_));
      arrayStartIndex_ = index;
      indexInArray_ = 0;
      arrayCount_ = n;
      getCharacters_(string_, @selector(getCharacters:range:),
                     array_, NSRange{sign_cast(arrayStartIndex_), sign_cast(n)});
    }
    return array_[indexInArray_++];
  }

  STU_INLINE
  Optional<Char16> skipToPreviousUTF16CharAndGetIt() {
    if (STU_UNLIKELY(indexInArray_ == 0)) {
      if (arrayStartIndex_ == startIndex_) {
        return none;
      }
      const Int n = min(arrayStartIndex_ - startIndex_, arrayLength(array_));
      arrayStartIndex_ -= n;
      indexInArray_ = n;
      arrayCount_ = n;
      getCharacters_(string_, @selector(getCharacters:range:),
                     array_, NSRange{sign_cast(arrayStartIndex_), sign_cast(n)});
    }
    return array_[--indexInArray_];
  }

private:
  NSString* __unsafe_unretained const string_;
  const NSStringRef::GetCharactersMethod getCharacters_;
  decltype(Storage::array)& array_;
  const Int startIndex_;
  const Int endIndex_;
  Int arrayStartIndex_;
  Int arrayCount_;
  Int indexInArray_;
};

template <NSStringRefBufferKind kind, typename Predicate,
          EnableIf<isCallable<Predicate, bool(Int index, Char16)>> = 0>
STU_INLINE
Int indexOfFirstUTF16CharWhereImpl(const NSStringRef& string, const Range<Int> range,
                                   Predicate&& predicate)
{
  STU_DEBUG_ASSERT(range.start < range.end);
  STU_ASSUME(range.start < range.end);
  typename NSStringRefBuffer<kind>::Storage storage;
  NSStringRefBuffer<kind> buffer{string, range, range.start, storage};
  Int index;
  for (;;) {
    index = buffer.index();
    const Optional<Char16> optCh = buffer.getUTF16CharAndSkipToNext();
    if (!optCh || predicate(index, *optCh)) break;
  }
  return index;
}

template <NSStringRefBufferKind kind, typename Predicate,
          EnableIf<isCallable<Predicate, bool(Int index, Char32)>> = 0>
STU_INLINE
Int indexOfFirstCodePointWhereImpl(const NSStringRef& string, const Range<Int> range,
                                   Predicate&& predicate)
{
  STU_DEBUG_ASSERT(range.start < range.end);
  STU_ASSUME(range.start < range.end);
  typename NSStringRefBuffer<kind>::Storage storage;
  NSStringRefBuffer<kind> buffer{string, range, range.start, storage};
  Int index;
  for (;;) {
    index = buffer.index();
    const Optional<Char16> optCh0 = buffer.getUTF16CharAndSkipToNext();
    if (!optCh0) break;
    const Char16 ch0 = *optCh0;
    Char32 cp = ch0;
    if (STU_UNLIKELY(isHighSurrogate(ch0))) {
      const Optional<Char16> optCh1 = buffer.getUTF16CharAndSkipToNext();
      if (STU_LIKELY(optCh1)) {
        const UInt16 ch1 = *optCh1;
        if (STU_LIKELY(isLowSurrogate(ch1))) {
          cp = codePointFromSurrogatePair(ch0, ch1);
        } else {
          // This may be expensive if the buffer was just refilled when ch1 was read,
          // but we care more about code size than the performance of invalid UTF-16 in multi-buffer
          // strings.
          buffer.skipToPreviousUTF16CharAndGetIt();
        }
      }
    }
    if (predicate(index, cp)) break;
  }
  return index;
}

template <NSStringRefBufferKind kind, typename Predicate,
          EnableIf<isCallable<Predicate, bool(Int endIndex, Char32)>> = 0>
STU_INLINE
Int indexOfEndOfLastCodePointWhereImpl(const NSStringRef& string, const Range<Int> range,
                                       Predicate&& predicate)
{
  STU_DEBUG_ASSERT(range.start < range.end);
  STU_ASSUME(range.start < range.end);
  Int previousIndex = range.end;
  typename NSStringRefBuffer<kind>::Storage storage;
  NSStringRefBuffer<kind> buffer{string, range, range.end, storage};
  for (;;) {
    const Optional<Char16> optCh1 = buffer.skipToPreviousUTF16CharAndGetIt();
    if (!optCh1) break;
    Int index = buffer.index();
    const UInt16 ch1 = *optCh1;
    Char32 cp = ch1;
    if (STU_UNLIKELY(isLowSurrogate(ch1))) {
      const Optional<Char16> optCh0 = buffer.skipToPreviousUTF16CharAndGetIt();
      if (STU_LIKELY(optCh0)) {
        const UInt16 ch0 = *optCh0;
        if (STU_LIKELY(isHighSurrogate(ch0))) {
          cp = codePointFromSurrogatePair(ch0, ch1);
          --index;
        } else {
          // This may be expensive if the buffer was just refilled when ch0 was read,
          // but we care more about code size than the performance of invalid UTF-16 in multi-buffer
          // strings.
          buffer.getUTF16CharAndSkipToNext();
        }
      }
    }
    if (predicate(index, cp)) break;
    previousIndex = index;
  }
  return previousIndex;
}

} // namespace detail

STU_NO_INLINE
Int NSStringRef
    ::indexOfFirstUTF16CharWhereImpl(Range<Int> range,
                                     FunctionRef<bool(Int index, Char16)> predicate) const
{
  const BufferKind kind = kind_;
  if (kind == BufferKind::utf16) {
    return detail::indexOfFirstUTF16CharWhereImpl<BufferKind::utf16>(*this, range, predicate);
  } else if (kind == BufferKind::ascii) {
    return detail::indexOfFirstUTF16CharWhereImpl<BufferKind::ascii>(*this, range, predicate);
  } else {
    return detail::indexOfFirstUTF16CharWhereImpl<BufferKind::none>(*this, range, predicate);
  }
}

STU_NO_INLINE
Int NSStringRef
    ::indexOfFirstCodePointWhereImpl(Range<Int> range,
                                     FunctionRef<bool(Int index, Char32)> predicate) const
{
  const BufferKind kind = kind_;
  if (kind == BufferKind::utf16) {
    return detail::indexOfFirstCodePointWhereImpl<BufferKind::utf16>(*this, range, predicate);
  } else if (kind == BufferKind::ascii) {
    return detail::indexOfFirstCodePointWhereImpl<BufferKind::ascii>(*this, range, predicate);
  } else {
    return detail::indexOfFirstCodePointWhereImpl<BufferKind::none>(*this, range, predicate);
  }
}

STU_NO_INLINE
Int NSStringRef
    ::indexOfEndOfLastCodePointWhereImpl(Range<Int> range,
                                         FunctionRef<bool(Int endIndex, Char32)> predicate) const
{
  const BufferKind kind = kind_;
  if (kind == BufferKind::utf16) {
    return detail::indexOfEndOfLastCodePointWhereImpl<BufferKind::utf16>(*this, range, predicate);
  } else if (kind == BufferKind::ascii) {
    return detail::indexOfEndOfLastCodePointWhereImpl<BufferKind::ascii>(*this, range, predicate);
  } else {
    return detail::indexOfEndOfLastCodePointWhereImpl<BufferKind::none>(*this, range, predicate);
  }
}

Int NSStringRef::indexOfTrailingWhitespaceIn(Range<Int> range) const {
  Int index = indexOfEndOfLastCodePointWhere(range, isNotIgnorableAndNotWhitespace);
  if (index != range.end) {
    index = indexOfFirstUTF16CharWhere({index, range.end}, isUnicodeWhitespace);
  }
  return index;
}

// MARK: - Grapheme cluster break finding

namespace grapheme_cluster {

// This is based on the Unicode 11 default extended grapheme cluster specification.

enum class CategoryPairCase : Int8 {
  isBreak = -1,
  noBreak = 0,
  picto_extend,
  picto_zwj,
  extend_extend,
  extend_zwj,
  zwj_picto,
  ri_ri,
  prepend_ri,
  prepend_prepend
};
constexpr CategoryPairCase lastCategoryPairCase STU_APPEARS_UNUSED = CategoryPairCase::prepend_prepend;

using Category = GraphemeClusterCategory;

static constexpr CategoryPairCase categoryPairCase_init(Category a, Category b) {
  using C = Category;
  using Case = CategoryPairCase;
  if (a == C::controlCR && b == C::controlLF) return Case::noBreak;
  if (a == C::controlCR || a == C::controlLF || a == C::controlOther) return Case::isBreak;
  switch (b) {
  case C::other:
    break;
  case C::prepend:
    if (a == C::prepend) return Case::prepend_prepend;
    break;
  case C::controlCR:
  case C::controlLF:
  case C::controlOther:
    return Case::isBreak;
  case C::hangulL:
  case C::hangulLV:
  case C::hangulLVT:
    if (a == C::hangulL) return Case::noBreak;
    break;
  case C::hangulV:
    if (a == C::hangulL || a == C::hangulV || a == C::hangulLV) return Case::noBreak;
    break;
  case C::hangulT:
    if (a == C::hangulV || a == C::hangulT || a == C::hangulLV || a == C::hangulLVT) {
      return Case::noBreak;
    }
    break;
  case C::extend:
    if (a == C::extend) return Case::extend_extend;
    if (a == C::extendedPictographic) return Case::picto_extend;
    return Case::noBreak;
  case C::zwj:
    if (a == C::extend) return Case::extend_zwj;
    if (a == C::extendedPictographic) return Case::picto_zwj;
    return Case::noBreak;
  case C::spacingMark:
    return Case::noBreak;
  case C::extendedPictographic:
    if (a == C::zwj) return Case::zwj_picto;
    break;
  case C::regionalIndicator:
    if (a == C::regionalIndicator) return Case::ri_ri;
    if (a == C::prepend) return Case::prepend_ri;
  }
  if (a == C::prepend) return Case::noBreak;
  return Case::isBreak;
}

static_assert(graphemeClusterCategoryCount <= 16);
constexpr int categoryPairCaseMatrixColumnCount = 16;
constexpr int categoryPairCaseMatrixLength = categoryPairCaseMatrixColumnCount
                                             *graphemeClusterCategoryCount;

using CategoryPairCaseMatrix = Array<CategoryPairCase, Fixed, categoryPairCaseMatrixLength>;

constexpr CategoryPairCaseMatrix createCategoryPairCaseMatrix() {
  const int categoryCount = graphemeClusterCategoryCount;
  const int columnCount = categoryPairCaseMatrixColumnCount;
  CategoryPairCaseMatrix array{};
  for (int i = 0; i < categoryCount; ++i) {
    for (int j = 0; j < columnCount; ++j) {
      array[i*columnCount + j] = j >= categoryCount ? CategoryPairCase::noBreak
                               : categoryPairCase_init(Category(j), Category(i));
    }
  }
  return array;
}

constexpr CategoryPairCaseMatrix matrix = createCategoryPairCaseMatrix();

constexpr CategoryPairCase categoryPairCase(Category a, Category b) {
  static_assert(isUnsigned<UnderlyingType<Category>>);
  const UInt index = static_cast<UInt>(b)*categoryPairCaseMatrixColumnCount + static_cast<UInt>(a);
  matrix.assumeValidIndex(index);
  return matrix[index];
}

struct BreakFinder {

  enum class State : UInt8 {
    other = 0,

    picto_extend,
    picto_zwj,
    ri_ri,

    maybe_picto_extend,
    maybe_picto_zwj,
    maybe_ri_ri,
  };

  State state;
  Category previousCategory;
  Category startCategory;
  const NSStringRef& string;
  Int startIndex;

  explicit BreakFinder(const NSStringRef& string)
  : string{string}, startIndex{-1}
  {}

  STU_INLINE
  void startForwardsSearchAt(Int index, Category category) {
    STU_DEBUG_ASSERT(0 <= index && index < string.count());
    startIndex = index;
    startCategory = category;
    previousCategory = category;
    static_assert((int)Category::extend + 1 == (int)Category::zwj);
    static_assert((int)Category::extend + 2 == (int)Category::regionalIndicator);
    static_assert((int)State::maybe_picto_extend + 1 == (int)State::maybe_picto_zwj);
    static_assert((int)State::maybe_picto_extend + 2 == (int)State::maybe_ri_ri);
    // Currently this compiles to a branch. A conditional move might be better.
    switch (category) {
    case Category::extend:
      state = State::maybe_picto_extend;
      break;
    case Category::zwj:
      state = State::maybe_picto_zwj;
      break;
    case Category::regionalIndicator:
      state = State::maybe_ri_ri;
      break;
    default:
      state = State::other;
      break;
    }
  }

  STU_INLINE
  bool advanceForwards(Category category) {
    STU_DEBUG_ASSERT(startIndex >= 0);
    using Case = CategoryPairCase;
    const Case pairCase = categoryPairCase(previousCategory, category);
    if (pairCase < Case::noBreak) return false;
    STU_ASSUME(pairCase <= lastCategoryPairCase);
    State newState;
    switch (pairCase) {
    case Case::isBreak:
      static_assert(Case::isBreak < Case::noBreak);
     __builtin_unreachable();
    case Case::noBreak:
    case Case::picto_extend:
    case Case::picto_zwj:
      static_assert((int)Case::noBreak == (int)State::other);
      static_assert((int)Case::picto_extend == (int)State::picto_extend);
      static_assert((int)Case::picto_zwj == (int)State::picto_zwj);
      newState = static_cast<State>(pairCase);
      break;
    case Case::extend_extend:
      newState = state == State::picto_extend || state == State::maybe_picto_extend ? state
               : State::other;
      break;
    case Case::extend_zwj:
      newState = state == State::picto_extend ? State::picto_zwj
               : state == State::maybe_picto_extend ? State::maybe_picto_zwj
               : State::other;
      break;
    case Case::zwj_picto:
      if (state == State::maybe_picto_zwj) {
        state = hasPictoPrefix(string, startIndex, startCategory) ? State::picto_zwj : State::other;
      }
      if (state != State::picto_zwj) {
        return false;
      }
      newState = State::other;
      break;
    case Case::prepend_prepend:
    case Case::prepend_ri:
      newState = State::other;
      break;
    case Case::ri_ri:
      if (state == State::ri_ri
          || (state == State::maybe_ri_ri
              && numberOfConsecutiveRegionalIndicatorsBefore(string, startIndex)%2 != 0))
      {
        return false;
      }
      newState = State::ri_ri;
      break;
    }
    state = newState;
    previousCategory = category;
    return true;
  }

  STU_INLINE
  void startBackwardsSearchAt(Int index, Category category) {
    STU_DEBUG_ASSERT(0 <= index && index < string.count());
    startIndex = index;
    startCategory = category;
    previousCategory = category;
    state = State::other;
  }

  // If this function encounters a zwj-picto pair, it will scan the string backwards to find
  // the beginning of the emoji zwj sequence and store the start index in `startIndex` before
  // returning true.
  STU_INLINE
  bool advanceBackwards(Int index, Category category) {
    STU_DEBUG_ASSERT(startIndex >= 0 && index < startIndex);
    using Case = CategoryPairCase;
    const Case pairCase = categoryPairCase(category, previousCategory);
    if (pairCase < Case::noBreak) return false;
    STU_ASSUME(pairCase <= lastCategoryPairCase);
    State newState;
    switch (pairCase) {
    case Case::isBreak:
      static_assert(Case::isBreak < Case::noBreak);
     __builtin_unreachable();
    case Case::noBreak:
    case Case::picto_extend:
    case Case::picto_zwj:
    case Case::extend_extend:
    case Case::extend_zwj:
      newState = State::other;
      break;
    case Case::zwj_picto:
      STU_DEBUG_ASSERT(category == Category::zwj);
      startIndex = startIndexOfPictoZWJSequence(string, index);
      return false;
    case Case::ri_ri:
      if (state == State::ri_ri
          || numberOfConsecutiveRegionalIndicatorsBefore(string, index)%2 != 0)
      {
        return false;
      }
      newState = State::ri_ri;
      break;
    case Case::prepend_ri:
    case Case::prepend_prepend:
      newState = state == State::ri_ri ? State::ri_ri : State::other;
      break;
    }
    state = newState;
    previousCategory = category;
    return true;
  }

  STU_NO_INLINE
  static bool hasPictoPrefix(const NSStringRef& string, Int index, Category category) {
    bool hasPrefix = false;
    string.indexOfEndOfLastCodePointWhere(Range{0, index}, [&](Char32 cp) -> bool {
      const Category c0 = graphemeClusterCategory(cp);
      const Category c1 = category;
      category = c0;
      if (   (c0 == Category::zwj && c1 == Category::extendedPictographic)
          || (c0 == Category::extend && (c1 == Category::zwj || c1 == Category::extend)))
      {
        return false;
      }
      hasPrefix = c0 == Category::extendedPictographic
                  && (c1 == Category::extend || c1 == Category::zwj);
      return true;
    });
    return hasPrefix;
  }

  STU_NO_INLINE
  static Int startIndexOfPictoZWJSequence(const NSStringRef& string,
                                          const Int indexOfZWJBeforePicto)
  {
    STU_DEBUG_ASSERT(string[indexOfZWJBeforePicto] == 0x200D);
    Int startOfPicto = indexOfZWJBeforePicto + 1;
    Category category = Category::zwj;
    string.indexOfEndOfLastCodePointWhere(Range{0, indexOfZWJBeforePicto},
                                          [&](Int index, Char32 cp) -> bool
    {
      const Category c0 = graphemeClusterCategory(cp);
      const Category c1 = category;
      category = c0;
      switch (c0) {
      case Category::zwj:
        if (c1 == Category::extendedPictographic) return false;
        return true;
      case Category::extend:
        if (c1 == Category::zwj || c1 == Category::extend) return false;
        return true;
      case Category::extendedPictographic:
        if (c1 == Category::zwj || c1 == Category::extend) {
          startOfPicto = index;
          return false;
        }
        return true;
      case Category::prepend:
        if (index + 1 + (cp > 0xffff) == startOfPicto) {
          startOfPicto = index;
          return false;
        }
        return true;
      default:
        return true;
      }
    });
    return startOfPicto;
  }

  STU_NO_INLINE
  static UInt numberOfConsecutiveRegionalIndicatorsBefore(const NSStringRef& string, Int index) {
    UInt count = 0;
    string.indexOfEndOfLastCodePointWhere(Range{0, index}, [&](Char32 cp) -> bool {
      const bool isRegionalIndicator = stu_label::isRegionalIndicator(cp);
      count += isRegionalIndicator;
      return !isRegionalIndicator || count == 1000;
    });
    return count;
  }
}; // BreakFinder

} // namespace grapheme_cluster

STU_NO_INLINE
Int NSStringRef::indexOfFirstGraphemeClusterBreak_noBuffer(const bool greaterThan,
                                                           const Int index) const
{
  STU_DEBUG_ASSERT(kind_ == BufferKind::none);
  const Int count = this->count();
  if (greaterThan) {
    STU_DEBUG_ASSERT(0 <= index && index < count - 1);
  } else {
    STU_DEBUG_ASSERT(0 < index && index < count);
  }
  using namespace grapheme_cluster;
  const Int index0 = max(0, index - (greaterThan ? 0 : 2));
  return detail::indexOfFirstCodePointWhereImpl<BufferKind::none>(*this, Range{index0, count},
           [index, isFirst = true, finder = BreakFinder(*this)]
           (Int i, Char32 cp) STU_INLINE_LAMBDA mutable -> bool
         {
           if (!isFirst) {
             return !finder.advanceForwards(graphemeClusterCategory(cp));
           } else {
             if (i != index - 2 || cp > 0xffff) {
               isFirst = false;
               finder.startForwardsSearchAt(i, graphemeClusterCategory(cp));
             }
             return false;
           }
         });
}

STU_NO_INLINE
Int NSStringRef::indexOfLastGraphemeClusterBreakImpl_noBuffer(const bool lessThan,
                                                              const Int index) const
{
  STU_DEBUG_ASSERT(kind_ == BufferKind::none);
  const Int count = this->count();
  if (lessThan) {
    STU_DEBUG_ASSERT(0 < index && index <= count);
  } else {
    STU_DEBUG_ASSERT(0 < index && index < count);
  }
  using namespace grapheme_cluster;
  BreakFinder finder{*this};
  bool isFirst = true;
  const Int endIndex = detail::indexOfEndOfLastCodePointWhereImpl<BufferKind::none>(
                         *this, Range{0, min(index + (lessThan ? 0 : 2), count)},
                         [&](Int i, Char32 cp) STU_INLINE_LAMBDA -> bool
                       {
                         if (!isFirst) {
                           return !finder.advanceBackwards(i, graphemeClusterCategory(cp));
                         }
                         if (i <= index) {
                           isFirst = false;
                           finder.startBackwardsSearchAt(i, graphemeClusterCategory(cp));
                         } else {
                           STU_DEBUG_ASSERT(i == index + 1 && cp <= 0xffff);
                         }
                         return false;
                       });
  // The finder may store the start of the emoji ZWJ sequence in finder.startIndex.
  return min(endIndex, finder.startIndex);
}

STU_NO_INLINE
Int NSStringRef::endIndexOfGraphemeClusterAtImpl(Int index) const {
  const BufferKind kind = kind_;
  const Int count = this->count();
  STU_DEBUG_ASSERT(0 <= index && index < count);
  Int index1 = index + 1;
  if (index1 == count) return index1;
  if (kind == BufferKind::ascii) {
    if (STU_LIKELY(asciiBuffer()[index] != '\r') || asciiBuffer()[index1] != '\n') {
      return index1;
    }
    return index1 + 1;
  } else if (kind == BufferKind::utf16) {
    const Char16 c0 = utf16Buffer()[index];
    const Char16 c1 = utf16Buffer()[index1];
    if ((c0 | c1) < 0x300) {
      if (STU_LIKELY(c0 != '\r') || c1 != '\n') {
        return index1;
      }
      return index1 + 1;
    }
    GraphemeClusterCategory category;
    if (c0 < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c0);
    } else {
      Char32 cp = c0;
      if (isHighSurrogate(c0) && isLowSurrogate(c1)) {
        cp = codePointFromSurrogatePair(c0, c1);
        ++index1;
        if (index1 == count) return index1;
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    return endIndexOfGraphemeClusterAtImpl_utf16Buffer(index, category, index1);
  } else {
    return indexOfFirstGraphemeClusterBreak_noBuffer(true, index);
  }
}
STU_NO_INLINE
Int NSStringRef
    ::endIndexOfGraphemeClusterAtImpl_utf16Buffer(Int index, GraphemeClusterCategory category,
                                                  Int nextIndex) const
{
  using namespace grapheme_cluster;
  BreakFinder finder{*this};
  finder.startForwardsSearchAt(index, category);
  index = nextIndex;
  const Char16* const utf16 = utf16Buffer();
  const Int count = this->count();
  STU_DEBUG_ASSERT(index < count);
  do {
    const Char16 c = utf16[index];
    nextIndex = index + 1;
    if (c < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c);
    } else {
      Char32 cp = c;
      if (isHighSurrogate(c) && nextIndex != count) {
        const Char16 c1 = utf16[nextIndex];
        if (isLowSurrogate(c1)) {
          cp = codePointFromSurrogatePair(c, c1);
          ++nextIndex;
        }
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    if (!finder.advanceForwards(category)) break;
    index = nextIndex;
  } while (index != count);
  return index;
}

STU_NO_INLINE
Int NSStringRef::indexOfFirstGraphemeClusterBreakNotBeforeImpl(const Int index) const {
  STU_DEBUG_ASSERT(0 < index && index < count());
  const BufferKind kind = kind_;
  Int index1 = index - 1;
  if (kind == BufferKind::ascii) {
    if (STU_LIKELY(asciiBuffer()[index1] != '\r') || asciiBuffer()[index] != '\n') {
      return index;
    }
    return index + 1;
  } else if (kind == BufferKind::utf16) {
    const Char16 c1 = utf16Buffer()[index1];
    const Char16 c0 = utf16Buffer()[index];
    if ((c1 | c0) < 0x300) {
      if (STU_LIKELY(c1 != '\r') || c0 != '\n') {
        return index;
      }
      return index + 1;
    }
    GraphemeClusterCategory category;
    if (c1 < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c1);
    } else {
      Char32 cp = c1;
      if (isLowSurrogate(c1)) {
        const Char16 c2 = utf16Buffer()[index1 - 1];
        if (isHighSurrogate(c2)) {
          cp = codePointFromSurrogatePair(c2, c1);
          --index1;
        }
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    return endIndexOfGraphemeClusterAtImpl_utf16Buffer(index1, category, index);
  } else {
    return indexOfFirstGraphemeClusterBreak_noBuffer(false, index);
  }
}

STU_NO_INLINE
Int NSStringRef::indexOfLastGraphemeClusterBreakBeforeImpl(Int index) const {
  using namespace grapheme_cluster;
  STU_DEBUG_ASSERT(0 < index && index <= count());
  const BufferKind kind = kind_;
  Int index1 = index - 1;
  if (index1 == 0) return 0;
  if (kind == BufferKind::ascii) {
    if (STU_LIKELY(asciiBuffer()[index - 2] != '\r') || asciiBuffer()[index1] != '\n') {
      return index1;
    }
    return index - 2;
  } else if (kind == BufferKind::utf16) {
    const Char16 c1 = utf16Buffer()[index1];
    const Char16 c2 = utf16Buffer()[index - 2];
    if ((c1 | c2) < 0x300) {
      if (STU_LIKELY(c2 != '\r') || c1 != '\n') {
        return index1;
      }
      return index - 2;
    }
    GraphemeClusterCategory category;
    if (c1 < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c1);
    } else {
      Char32 cp = c1;
      if (isLowSurrogate(c1) && isHighSurrogate(c2)) {
        if (--index1 == 0) return 0;
        cp = codePointFromSurrogatePair(c2, c1);
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    return indexOfLastGraphemeClusterBreakBeforeImpl_utf16Buffer(index1, category);
  } else {
    return indexOfLastGraphemeClusterBreakImpl_noBuffer(true, index);
  }
}
STU_NO_INLINE
Int NSStringRef
    ::indexOfLastGraphemeClusterBreakBeforeImpl_utf16Buffer(Int index,
                                                            GraphemeClusterCategory category) const
{
  using namespace grapheme_cluster;
  BreakFinder finder{*this};
  finder.startBackwardsSearchAt(index, category);
  const Char16* const utf16 = utf16Buffer();
  STU_DEBUG_ASSERT(index > 0);
  for (;;) {
    const Int endIndex = index;
    --index;
    const Char16 c = utf16[index];
    if (c < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c);
    } else {
      Char32 cp = c;
      if (isLowSurrogate(c) && index != 0) {
        const Char16 c1 = utf16[index - 1];
        if (isHighSurrogate(c1)) {
          cp = codePointFromSurrogatePair(c1, c);
          --index;
        }
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    if (finder.advanceBackwards(index, category)) {
      if (index != 0) continue;
      return 0;
    }
    // The finder may store the start of the emoji ZWJ sequence in finder.startIndex.
    return min(endIndex, finder.startIndex);
  } // for (;;)
}

STU_NO_INLINE
Int NSStringRef::startIndexOfGraphemeClusterAtImpl(const Int index) const {
  STU_DEBUG_ASSERT(0 < index && index < count());
  const BufferKind kind = kind_;
  if (kind == BufferKind::ascii) {
    if (STU_LIKELY(asciiBuffer()[index - 1] != '\r') || asciiBuffer()[index] != '\n') {
      return index;
    }
    return index - 1;
  } else if (kind == BufferKind::utf16) {
    const Char16 c0 = utf16Buffer()[index];
    const Char16 c1 = utf16Buffer()[index - 1];
    if ((c0 | c1) < 0x300) {
      if (STU_LIKELY(c1 != '\r') || c0 != '\n') {
        return index;
      }
      return index - 1;
    }
    GraphemeClusterCategory category;
    if (c0 < minSurrogateCodeUnit) { // Matches the inline branch in graphemeClusterCategory.
      category = graphemeClusterCategory(c0);
    } else {
      Char32 cp = c0;
      if (isHighSurrogate(c0)) {
        const Char16 c = utf16Buffer()[index + 1];
        if (isLowSurrogate(c)) {
          cp = codePointFromSurrogatePair(c0, c);
        }
      }
      STU_DEBUG_ASSERT(cp >= minSurrogateCodeUnit);
      STU_ASSUME(cp >= minSurrogateCodeUnit);
      category = graphemeClusterCategory(cp);
    }
    return indexOfLastGraphemeClusterBreakBeforeImpl_utf16Buffer(index, category);
  } else {
    return indexOfLastGraphemeClusterBreakImpl_noBuffer(false, index);
  }
}

} // stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
