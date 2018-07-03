// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Assert.h"
#include "stu/Dollar.hpp"
#include "stu/Optional.hpp"
#include "stu/Range.hpp"
#include "stu/Ref.hpp"
#include "stu/Utility.hpp"

#include <algorithm>
#include <initializer_list>

namespace stu {

template <typename T>
class ArrayRef;

template <typename Int>
struct StartIndexAndCount {
  Int startIndex;
  Int count;
};

template <typename LowerBound, typename UpperBound = LowerBound>
struct IndexRange {
  LowerBound startIndex;
  UpperBound endIndex;

  STU_CONSTEXPR_T
  IndexRange(LowerBound startIndex, UpperBound endIndex)
  : startIndex{std::move(startIndex)}, endIndex{std::move(endIndex)}
  {}

  template <typename Int,
            EnableIf<isSame<LowerBound, UpperBound> && DelayCheckToInstantiation<Int>::value> = 0>
  STU_CONSTEXPR_T
  IndexRange(LowerBound start, Count<Int> count)
  : startIndex{std::move(start)}, endIndex{startIndex + count.value}
  {}

  template <bool enable = true, EnableIf<enable && isSame<LowerBound, UpperBound>> = 0>
  STU_CONSTEXPR_T
  IndexRange(Range<LowerBound> range)
  : startIndex{std::move(range.start)}, endIndex{std::move(range.end)}
  {}

  template <typename R,
            EnableIf<isSame<LowerBound, UpperBound>
                     && !isSame<RemoveCVReference<R>, Range<LowerBound>>
                     && isSafelyConvertible<RangeBound<R>, LowerBound>> = 0>
  STU_CONSTEXPR_T
  IndexRange(R&& range)
  : IndexRange(Range<LowerBound>{std::move(range)})
  {}

  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, Int> && isSame<UpperBound, Int>> = 0>
  STU_CONSTEXPR
  bool isValidForArrayWithLength(Int length) const {
    return 0 <= startIndex && startIndex <= length
        && 0 <= endIndex && endIndex <= length;
  }

  template <typename Int,
            EnableIf<isInteger<Int>
                     && isSame<LowerBound, Int> && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  bool isValidForArrayWithLength(Int length) const {
    return 0 <= startIndex && startIndex <= length
        && endIndex.value <= 0 && endIndex.value + length >= 0;
  }

  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, OffsetFromEnd<Int>>
                                    && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  bool isValidForArrayWithLength(Int length) const {
    return startIndex.value <= 0 && startIndex.value + length >= 0
        && endIndex.value <= 0 && endIndex.value + length >= 0;
  }

  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, Int> && isSame<UpperBound, Int>> = 0>
  STU_CONSTEXPR
  Range<Int> forArrayWithLength(Int length, Unchecked) const {
    discard(length);
    return {startIndex, endIndex};
  }

  template <typename Int,
            EnableIf<isInteger<Int>
                     && isSame<LowerBound, Int> && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  Range<Int> forArrayWithLength(Int length, Unchecked) const {
    return {startIndex, length + endIndex.value};
  }

  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, OffsetFromEnd<Int>>
                                    && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  Range<Int> forArrayWithLength(Int length, Unchecked) const {
    return {this->startIndex.value + length, this->endIndex.value + length};
  }

  /// \pre isValidIndexRangeForArrayWithLength(length)
  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, Int> && isSame<UpperBound, Int>> = 0>
  STU_CONSTEXPR
  StartIndexAndCount<Int> startIndexAndCountForArrayWithLength(Int length, Unchecked) const {
    discard(length);
    return {startIndex, max(0, endIndex - startIndex)};
  }

  template <typename Int,
            EnableIf<isInteger<Int>
                     && isSame<LowerBound, Int> && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  StartIndexAndCount<Int> startIndexAndCountForArrayWithLength(Int length, Unchecked) const {
    return {startIndex, max(0, length + endIndex.value - startIndex)};
  }

  template <typename Int,
            EnableIf<isInteger<Int> && isSame<LowerBound, OffsetFromEnd<Int>>
                                    && isSame<UpperBound, OffsetFromEnd<Int>>> = 0>
  STU_CONSTEXPR
  StartIndexAndCount<Int> startIndexAndCountForArrayWithLength(Int length, Unchecked) const {
    return {startIndex.value + length, max(0, endIndex.value - startIndex.value)};
  }
};

/// \brief A CRTP base class for array-like container classes.
///
/// The template parameter `CR` is the return type of the `operator[](Int) const`,
/// the template parameter `R` is the return type of the non-const `operator[](Int)`.
///
/// If the derived class is primarily used as a mutable container class,
/// `CR` should equal `const Value&`. If the derived class is primarily used
/// as a reference to a container, `CR` should equal `R`.
///
/// The derived class's count, begin and end members should be noexcept.
template <typename Derived, typename R, typename CR,
          typename ArrayRef = stu::ArrayRef<RemoveReference<R>>,
          typename ArrayRef_const = stu::ArrayRef<RemoveReference<CR>>>
class ArrayBase {
public:
  using Value = RemoveReference<R>;
  using ValueRef = R;
  using ValueRef_const = CR;
  static_assert(isSame<R, CR> || isSame<CR, const Value&>);

private:
  using ConstValueRef = Conditional<isReference<R>, const Value&, ValueRef_const>;

  STU_CONSTEXPR_T
  const Derived& derived() const noexcept { return down_cast<const Derived&>(*this); }

  STU_CONSTEXPR_T
  Derived& derived() noexcept { return down_cast<Derived&>(*this); }

protected:
  STU_CONSTEXPR_T ArrayBase() = default;

  STU_CONSTEXPR_T ArrayBase(const ArrayBase&) = default;
  STU_CONSTEXPR_T ArrayBase& operator=(const ArrayBase&) = default;

public:
  STU_CONSTEXPR_T
  bool isEmpty() const {
    return derived().count() == 0;
  }

  template <bool enable = isSame<ArrayRef, stu::ArrayRef<RemoveReference<R>>>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T
  UInt arraySizeInBytes() const {
    return sizeof(Value)*sign_cast(derived().count());
  }

  STU_CONSTEXPR_T
  auto end() noexcept {
    static_assert(noexcept(derived().begin() + derived().count()));
    return derived().begin() + derived().count();
  }
  STU_CONSTEXPR_T
  auto end() const noexcept {
    static_assert(noexcept(derived().begin() + derived().count()));
    return derived().begin() + derived().count();
  }

  STU_CONSTEXPR_T
  auto reversed() noexcept {
    const auto arrayRef = ArrayRef{derived().begin(), derived().count(), unchecked};
    return typename ArrayRef::Reversed(arrayRef);
  }
  STU_CONSTEXPR_T
  auto reversed() const noexcept {
    const auto arrayRef = ArrayRef_const{derived().begin(), derived().count(), unchecked};
    return typename ArrayRef_const::Reversed(arrayRef);
  }

  STU_CONSTEXPR
  bool isValidIndex(Int index) const {
    const Int count = derived().count();
    return 0 <= index && index < count;
  }

  STU_CONSTEXPR
  void assumeValidIndex(Int index) const {
    const Int count = derived().count();
    STU_ASSUME(0 <= index && index < count);
    discard(index);
    discard(count);
  }
  template <typename UInt, EnableIf<isUnsigned<UInt> && !isSafelyConvertible<UInt, Int>> = 0>
  STU_CONSTEXPR
  void assumeValidIndex(UInt index) const {
    const auto count = sign_cast(derived().count());
    STU_ASSUME(index < count);
    discard(index);
    discard(count);
  }

  template <typename U>
  STU_INLINE
  bool aliases(const U& value) {
    return reinterpret_cast<UInt>(&value) - reinterpret_cast<UInt>(derived().begin())
           < sign_cast(derived().count())*sizeof(Value);
  }

  STU_CONSTEXPR
  ValueRef operator[](Int index) {
    static_assert(noexcept(derived().count()));
    static_assert(noexcept(derived().begin()));
    const Int count = derived().count();
    STU_PRECONDITION(0 <= index && index < count);
    return derived().begin()[index];
  }

  STU_CONSTEXPR
  ValueRef_const operator[](Int index) const {
    static_assert(noexcept(derived().count()));
    static_assert(noexcept(derived().begin()));
    const Int count = derived().count();
    STU_PRECONDITION(0 <= index && index < count);
    return derived().begin()[index];
  }

  template <typename UInt, EnableIf<isUnsigned<UInt> && !isSafelyConvertible<UInt, Int>> = 0>
  STU_CONSTEXPR
  ValueRef operator[](UInt index) {
    const auto count = sign_cast(derived().count());
    STU_PRECONDITION(index < count);
    return derived().begin()[index];
  }

  template <typename UInt, EnableIf<isUnsigned<UInt> && !isSafelyConvertible<UInt, Int>> = 0>
  STU_CONSTEXPR
  ValueRef_const operator[](UInt index) const {
    const auto count = sign_cast(derived().count());
    STU_PRECONDITION(index < count);
    return derived().begin()[index];
  }

  STU_CONSTEXPR
  ValueRef operator[](OffsetFromEnd<Int> offsetFromEnd) {
    const Int count = derived().count();
    STU_PRECONDITION(offsetFromEnd.value < 0 && count + offsetFromEnd.value >= 0);
    const Int index = count + offsetFromEnd.value;
    return derived().begin()[index];
  }

  STU_CONSTEXPR
  ValueRef_const operator[](OffsetFromEnd<Int> offsetFromEnd) const {
    const Int count = derived().count();
    STU_PRECONDITION(offsetFromEnd.value < 0 && count + offsetFromEnd.value >= 0);
    const Int index = count + offsetFromEnd.value;
    return derived().begin()[index];
  }

  STU_CONSTEXPR
  ArrayRef operator[](IndexRange<Int> indexRange) {
    return subarray(indexRange);
  }

  STU_CONSTEXPR
  ArrayRef_const operator[](IndexRange<Int> indexRange) const {
    return subarray(indexRange);
  }

  STU_CONSTEXPR
  ArrayRef operator[](IndexRange<Int, OffsetFromEnd<Int>> indexRange) {
    return subarray(indexRange);
  }

  STU_CONSTEXPR
  ArrayRef_const operator[](IndexRange<Int, OffsetFromEnd<Int>> indexRange) const {
    return subarray(indexRange);
  }

  STU_CONSTEXPR
  ArrayRef operator[](IndexRange<OffsetFromEnd<Int>> indexRange) {
    return subarray(indexRange);
  }

  STU_CONSTEXPR
  ArrayRef_const operator[](IndexRange<OffsetFromEnd<Int>> indexRange) const {
    return subarray(indexRange);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> indexWhere(Predicate&& predicate) const {
    return indexWhereImpl(IndexRange<Int>{0, derived().count()}, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> indexWhere(IndexRange<Int> indexRange, Predicate&& predicate) const {
    return indexWhereImpl(indexRange, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> indexWhere(IndexRange<Int, OffsetFromEnd<Int>> indexRange,
                           Predicate&& predicate) const {
    return indexWhereImpl(indexRange, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> indexWhere(IndexRange<OffsetFromEnd<Int>> indexRange, Predicate&& predicate) const
  {
    return indexWhereImpl(indexRange, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> lastIndexWhere(Predicate&& predicate) const {
    return lastIndexWhere(IndexRange<Int>{0, derived().count()}, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> lastIndexWhere(IndexRange<Int> indexRange, Predicate&& predicate) const {
    return lastIndexWhere(indexRange, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> lastIndexWhere(IndexRange<Int, OffsetFromEnd<Int>> indexRange,
                               Predicate&& predicate) const {
    return lastIndexWhere(indexRange, predicate);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(ConstValueRef)>> = 0>
  STU_CONSTEXPR
  Optional<Int> lastIndexWhere(IndexRange<OffsetFromEnd<Int>> indexRange,
                               Predicate&& predicate) const
  {
    return lastIndexWhere(indexRange, predicate);
  }

  template <typename LessThan,
            EnableIf<!isConst<Value>
                     && isCallable<LessThan, bool(ConstValueRef, ConstValueRef)>> = 0>
  void sort(LessThan&& lessThan) {
    std::sort(derived().begin(), derived().end(), lessThan);
  }

private:
  template <typename LB, typename UB>
  STU_CONSTEXPR
  ArrayRef subarray(IndexRange<LB, UB> indexRange) {
    const Int count = derived().count();
    STU_PRECONDITION(indexRange.isValidForArrayWithLength(count));
    const auto [i, n] = indexRange.startIndexAndCountForArrayWithLength(count, unchecked);
    return {derived().begin() + i, n, unchecked};
  }

  template <typename LB, typename UB>
  STU_CONSTEXPR
  ArrayRef_const subarray(IndexRange<LB, UB> indexRange) const {
    const Int count = derived().count();
    STU_PRECONDITION(indexRange.isValidForArrayWithLength(count));
    const auto [i, n] = indexRange.startIndexAndCountForArrayWithLength(count, unchecked);
    return {derived().begin() + i, n, unchecked};
  }


  template <typename LB, typename UB, typename Predicate>
  STU_CONSTEXPR
  Optional<Int> indexWhereImpl(IndexRange<LB, UB> indexRange, Predicate& predicate) const {
    const Int count = derived().count();
    STU_PRECONDITION(indexRange.isValidForArrayWithLength(count));
    const Range<Int> range = indexRange.forArrayWithLength(count, unchecked);
    for (Int i = range.start; i < range.end; ++i) {
      const ConstValueRef value = derived().begin()[i];
      if (predicate(value)) {
        return i;
      }
    }
    return none;
  }

  template <typename LB, typename UB, typename Predicate>
  STU_CONSTEXPR
  Optional<Int> lastIndexWhereImpl(IndexRange<LB, UB> indexRange, Predicate& predicate) const {
    const Int count = derived().count();
    STU_PRECONDITION(indexRange.isValidForArrayWithLength(count));
    const Range<Int> range = indexRange.forArrayWithLength(count, unchecked);
    Int i = range.end;
    while (range.start < i) {
      --i;
      const ConstValueRef value = derived().begin()[i];
      if (predicate(value)) {
        return i;
      }
    }
    return none;
  }
};

template <typename T>
class ReversedArrayRef;


template <typename T>
class InitializerList {
  std::initializer_list<T> list;
public:
  /* implicit */ STU_CONSTEXPR_T
  InitializerList(std::initializer_list<T> list)
  : list{list} {}

  STU_CONSTEXPR_T
  const T* begin() const noexcept { return list.begin(); }

  STU_CONSTEXPR_T
  const T* end() const noexcept { return list.end(); }

  STU_CONSTEXPR_T
  Int count() const noexcept { return sign_cast(list.size()); }
};

/// A non-owning reference to an array.
template <typename T>
class ArrayRef : public ArrayBase<ArrayRef<T>, T&, T&> {
  using Base = ArrayBase<ArrayRef<T>, T&, T&>;

protected:
  T* begin_{};
  Int count_{};

public:
  using Iterator = T*;

  STU_CONSTEXPR_T
  ArrayRef() noexcept = default;

  STU_CONSTEXPR
  ArrayRef(T* array, Int count) noexcept(!STU_ASSERT_MAY_THROW)
  : ArrayRef{array, count, unchecked}
  {
    STU_PRECONDITION(count >= 0);
  }

  STU_CONSTEXPR_T
  ArrayRef(T* array, Int count, Unchecked) noexcept
  : begin_{array}, count_{count}
  {}

  STU_CONSTEXPR
  ArrayRef(T* arrayBegin, T* arrayEnd) noexcept(!STU_ASSERT_MAY_THROW)
  : ArrayRef{arrayBegin, arrayEnd - arrayBegin}
  {}

  STU_CONSTEXPR_T
  ArrayRef(T* arrayBegin, T* arrayEnd, Unchecked) noexcept
  : ArrayRef{arrayBegin, arrayEnd - arrayBegin, unchecked}
  {}

  template <typename Array, typename U, typename CU,
            EnableIf<!isSame<Array, ArrayRef> && isConvertibleArrayPointer<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(ArrayBase<Array, U&, CU&>& other) noexcept
  : ArrayRef{down_cast<Array&>(other).begin(), down_cast<Array&>(other).count(), unchecked}
  {}

  template <typename Array, typename U, typename CU,
            EnableIf<!isSame<Array, ArrayRef> && isConvertibleArrayPointer<CU*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(const ArrayBase<Array, U&, CU&>& other) noexcept
  : ArrayRef{down_cast<const Array&>(other).begin(), down_cast<const Array&>(other).count(),
             unchecked}
  {}

  template <typename Array,
            EnableIf<isConstructible<ArrayRef, Array&>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(Ref<Array> other) noexcept
  : ArrayRef{other.get()}
  {}

  template <typename T2, int N,
            EnableIf<!isCharacter<T2> && isConst<T> && isConvertibleArrayPointer<T2*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(T2 (& array)[N]) noexcept
  : ArrayRef{array, N, unchecked}
  {}

  template <typename T2, int N,
            EnableIf<!isCharacter<T2> && !isConst<T> && isConvertibleArrayPointer<T2*, T*>> = 0>
  explicit STU_CONSTEXPR_T
  ArrayRef(T2 (& array)[N]) noexcept
  : ArrayRef{array, N, unchecked}
  {}

  template <bool enable = !isIntegral<T> && !isPointer<T>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(std::initializer_list<RemoveConst<T>> list) noexcept
  : ArrayRef{list.begin(), sign_cast(list.size()), unchecked}
  {}

  /* implicit */ STU_CONSTEXPR_T
  ArrayRef(InitializerList<RemoveConst<T>> list) noexcept
  : ArrayRef{list.begin(), list.count(), unchecked}
  {}

  STU_CONSTEXPR_T T* begin() const noexcept { return begin_; }

  STU_CONSTEXPR_T
  Int count() const noexcept {
    STU_ASSUME(count_ >= 0);
    return count_;
  }

  using Reversed = ReversedArrayRef<ArrayRef<T>>;
};

template <typename T, int n>
ArrayRef(T (& array)[n]) -> ArrayRef<T>;

template <typename Array, typename U, typename CU>
ArrayRef(ArrayBase<Array, U&, CU&>& other) -> ArrayRef<U>;

template <typename Array, typename U, typename CU>
ArrayRef(const ArrayBase<Array, U&, CU&>& other) -> ArrayRef<CU>;

template <typename T>
STU_CONSTEXPR_T
ArrayRef<const T> arrayRef(std::initializer_list<T> list) {
  return {list};
}

template <typename T>
STU_CONSTEXPR_T
ArrayRef<T> const_array_cast(ArrayRef<const T> array) {
  return {const_cast<T*>(array.begin()), array.count(), unchecked};
}

template <typename ArrayRef>
class ReversedArrayRef
      : public ArrayBase<ReversedArrayRef<ArrayRef>,
                         typename ArrayRef::ValueRef,
                         typename ArrayRef::ValueRef,
                         ReversedArrayRef<ArrayRef>>
{
public:
  using Iterator = ReversedIterator<typename ArrayRef::Iterator>;
  using Reversed = ArrayRef;

  ArrayRef reversed{};

  STU_CONSTEXPR_T
  ReversedArrayRef() = default;

  STU_CONSTEXPR_T
  explicit ReversedArrayRef(ArrayRef array) noexcept
  : reversed{array} {}

  STU_CONSTEXPR
  ReversedArrayRef(Iterator begin, Int count) noexcept(!STU_ASSERT_MAY_THROW)
  : ReversedArrayRef{begin, count, unchecked}
  {
    STU_PRECONDITION(count >= 0);
  }

  STU_CONSTEXPR_T
  ReversedArrayRef(Iterator begin, Int count, Unchecked) noexcept
  : ReversedArrayRef{ArrayRef{begin.reversed - count, count, unchecked}}
  {}

  STU_CONSTEXPR_T explicit operator ArrayRef() const noexcept { return reversed; }

  STU_CONSTEXPR_T Int count() const noexcept { return reversed.count(); }

  STU_CONSTEXPR_T Iterator begin() const noexcept { return Iterator{reversed.end()}; }
};

} // namespace stu

