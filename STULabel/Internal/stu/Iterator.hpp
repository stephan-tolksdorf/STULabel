// Copyright 2017 Stephan Tolksdorf

#pragma once

#import "stu/Casts.hpp"
#import "stu/Comparable.hpp"
#import "stu/TypeTraits.hpp"

#include <cstddef>
#include <iterator>

namespace stu {

namespace detail {
  template <typename IteratorCategory, typename T>
  using IsIteratorImpl = std::is_convertible<typename std::iterator_traits<T>::iterator_category,
                                             IteratorCategory>;
}

template <typename IteratorCategory, typename T>
constexpr bool isIterator = appliedIsTrue<detail::IsIteratorImpl, IteratorCategory, T>;

template <typename IteratorCategory, typename T>
constexpr bool isInputIterator = isIterator<std::input_iterator_tag, T>;

template <typename T>
constexpr bool isForwardIterator = isIterator<std::forward_iterator_tag, T>;

template <typename T>
constexpr bool isBidirectionalIterator = isIterator<std::bidirectional_iterator_tag, T>;

template <typename T>
constexpr bool isRandomAccessIterator = isIterator<std::random_access_iterator_tag, T>;

namespace detail {
  template <typename T>
  using IteratorReferenceTypeImpl = typename std::iterator_traits<T>::reference;
}

namespace detail {
  template <typename Iterator>
  using IteratorReferenceTypeImpl = typename std::iterator_traits<Iterator>::reference;
}

template <typename Iterator>
using IteratorReferenceType = Apply<detail::IteratorReferenceTypeImpl, Iterator>;

template <typename Iterator>
using IteratorValueType = RemoveReference<IteratorReferenceType<Iterator>>;

namespace detail {
  template <typename T>
  struct MemberAccessOperatorProxy {
    T value;

    STU_CONSTEXPR
    T* operator->() noexcept { return &value; }
  };
}

/// \brief A CRTP base class for implementing iterator classes.
///
/// The derived class only has to define a minimum number of operations.
/// For an input or forward iterator, the derived class has to define
/// dereference, equality and pre-increment operators. For a bidirectional
/// iterator the derived class has to additionally define a pre-decrement
/// operator. For a random access iterator, the derived class also has to
/// define `+=` and `-=` operators (and if the derived class doesn't define
/// pre-increment or pre-decrement operators, there are default implementations
/// that use the `+=` and `-=` operators).
///
/// IMPORTANT:
/// This class defines `operator[]` as `*(iter + index)`, which leads to
/// undefined behaviour if the dereference operator returns a reference to
/// a value stored within the iterator. Hence, don't define such "stashing"
/// random access iterators or provide your own `operator[]`.
///
template <typename Derived, typename IteratorCategory, typename ReferenceType,
          typename DifferenceType = std::ptrdiff_t>
struct IteratorBase : Comparable<Derived> {
  using iterator_category = IteratorCategory;
  using Reference = ReferenceType;
  using reference = Reference;
  using Value = RemoveReference<Reference>;
  using value_type = Value;
  using Pointer = Conditional<isReference<Reference>, Value*,
                              detail::MemberAccessOperatorProxy<Value>>;
  using pointer = Pointer;
  using Difference = Conditional<isType<DifferenceType>, DifferenceType, std::ptrdiff_t>;
  using difference_type = Difference;

  STU_CONSTEXPR_T
  const Derived& derived() const noexcept { return down_cast<const Derived&>(*this); }

  STU_CONSTEXPR_T
  Derived& derived() noexcept { return down_cast<Derived&>(*this); }

protected:
  static constexpr bool isBidirectionalIterator =
    isConvertible<IteratorCategory, std::bidirectional_iterator_tag>;

  static constexpr bool isRandomAccessIterator =
    isConvertible<IteratorCategory, std::random_access_iterator_tag>;

public:
  template <bool enable = isReference<Reference>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Pointer operator->() const
    STU_NOEXCEPT_AUTO_RETURN(Pointer{&derived().operator*()})

  template <bool disable = isReference<Reference>, EnableIf<!disable> = 0>
  STU_CONSTEXPR
  Pointer operator->() const // Returns a MemberAccessOperatorProxy.
    STU_NOEXCEPT_AUTO_RETURN(Pointer{derived().operator*()})

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Reference operator[](Difference index) const
    STU_NOEXCEPT_AUTO_RETURN(Reference{*(derived() + index)})

  STU_CONSTEXPR
  Derived& operator++() noexcept(isNothrowCompoundAddable<Derived, difference_type>) {
    static_assert(isRandomAccessIterator,
                  "If this iterator is not a random access iterator, "
                  "the derived class must define an `operator++`.");
    return derived() += Difference(1);
  }

  template <bool enable = isBidirectionalIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Derived& operator--() noexcept(isNothrowCompoundSubtractable<Derived, difference_type>) {
    static_assert(isRandomAccessIterator,
                  "If this iterator is not a random access iterator, "
                  "the derived class must define an `operator--`.");
    return derived() -= Difference(1);
  }

  STU_CONSTEXPR
  Derived operator++(int)
    noexcept(isNothrowIncrementable<Derived> && isNothrowCopyConstructible<Derived>)
  {
    Derived temp(derived());
    ++derived();
    return temp;
  }

  template <bool enable = isBidirectionalIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Derived operator--(int)
    noexcept(isNothrowDecrementable<Derived> && isNothrowCopyConstructible<Derived>)
  {
    Derived temp(derived());
    --derived();
    return temp;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Derived operator+(Difference offset) const
    noexcept(isNothrowCopyConstructible<Derived>
             && isNothrowCompoundAddable<Derived, Difference>)
  {
    Derived temp(derived());
    temp += offset;
    return temp;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Derived operator-(Difference offset) const
    noexcept(isNothrowCopyConstructible<Derived>
             && isNothrowCompoundSubtractable<Derived, Difference>)
  {
    Derived temp(derived());
    temp -= offset;
    return temp;
  }
};

template <typename Iterator>
class ReversedIterator
        : public IteratorBase<ReversedIterator<Iterator>,
                              typename std::iterator_traits<Iterator>::iterator_category,
                              typename std::iterator_traits<Iterator>::reference,
                              typename std::iterator_traits<Iterator>::difference_type>
{
  using Base = typename ReversedIterator::IteratorBase;
  static_assert(isBidirectionalIterator<Iterator>);
  static_assert(isNothrowCopyConstructible<Iterator>);
  static_assert(isNothrowMoveConstructible<Iterator>);
  using Base::isRandomAccessIterator;
public:
  using Difference = typename Base::Difference;
  using Reference = typename Base::Reference;

  Iterator reversed{};

  ReversedIterator() noexcept = default;

  explicit STU_CONSTEXPR
  ReversedIterator(const Iterator& iterator) noexcept : reversed(iterator) {}

  explicit STU_CONSTEXPR
  ReversedIterator(Iterator&& iterator) noexcept : reversed(std::move(iterator)) {}

  STU_CONSTEXPR Reference operator*() const noexcept {
    Iterator temp{reversed};
    --temp;
    return *temp;
  }

  STU_CONSTEXPR
  ReversedIterator& operator++() noexcept(isNothrowDecrementable<Iterator>) {
    --reversed;
    return *this;
  }

  STU_CONSTEXPR
  ReversedIterator& operator--() noexcept(isNothrowIncrementable<Iterator>) {
    ++reversed;
    return *this;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Difference operator-(ReversedIterator other) const noexcept {
    return other.reversed - reversed;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  ReversedIterator& operator+=(Difference n) noexcept {
    reversed -= n;
    return *this;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  ReversedIterator& operator-=(Difference n) noexcept {
    reversed += n;
    return *this;
  }

  STU_CONSTEXPR
  bool operator==(const ReversedIterator& other) const
         noexcept(isNothrowEqualityComparable<Iterator>)
  {
    return other.reversed == reversed;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  bool operator<(const ReversedIterator& other) const
         noexcept(isNothrowLessThanComparable<Iterator>)
  {
    return other.reversed < reversed;
  }
};

template <typename T>
using CountingIteratorCategory =
        Conditional<!(isEqualityComparable<T> && isIncrementable<T>), NoType,
        Conditional<!isDecrementable<T>, std::forward_iterator_tag,
        Conditional<!(isLessThanComparable<T> && isIntegral<DifferenceType<T>> && isOffsetable<T>),
                    std::bidirectional_iterator_tag, std::random_access_iterator_tag>>>;


template <typename T,
          typename IteratorCategory = CountingIteratorCategory<T>>
struct CountingIterator
       : IteratorBase<CountingIterator<T>, IteratorCategory, T, DifferenceType<T>>
{
protected:
  using Base = IteratorBase<CountingIterator<T>, IteratorCategory, T, DifferenceType<T>>;
  using Base::isBidirectionalIterator;
  using Base::isRandomAccessIterator;
public:
  using Difference = typename Base::Difference;

  T value{};

  STU_CONSTEXPR
  CountingIterator() = default;

  STU_CONSTEXPR
  explicit CountingIterator(const T& value) noexcept(isNothrowCopyConstructible<T>)
  : value{value}
  {}

  STU_CONSTEXPR
  explicit CountingIterator(T&& value) noexcept(isNothrowMoveConstructible<T>)
  : value{std::move(value)}
  {}

  STU_CONSTEXPR
  T operator*() const noexcept(isNothrowCopyConstructible<T>) {
    return value;
  }

  STU_CONSTEXPR
  CountingIterator& operator++() noexcept(isNothrowIncrementable<T>) {
    ++value;
    return *this;
  }

  template <bool enable = isBidirectionalIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  CountingIterator& operator--() noexcept(isNothrowDecrementable<T>) {
    --value;
    return *this;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  Difference operator-(CountingIterator other) noexcept(isNothrowSubtractable<T>) {
    return value - other.value;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  CountingIterator& operator+=(Difference difference)
    noexcept(isNothrowCompoundAddable<T, Difference>)
  {
    value += difference;
    return *this;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  CountingIterator& operator-=(Difference difference)
    noexcept(isNothrowCompoundSubtractable<T, Difference>)
  {
    value -= difference;
    return *this;
  }

  STU_CONSTEXPR
  bool operator==(const CountingIterator& other) const
        noexcept(isNothrowEqualityComparable<T>)
  {
    return value == other.value;
  }

  template <bool enable = isRandomAccessIterator, EnableIf<enable> = 0>
  STU_CONSTEXPR
  bool operator<(const CountingIterator& other) const
         noexcept(isNothrowLessThanComparable<T>)
  {
    return value < other.value;
  }
};


} // namespace stu

