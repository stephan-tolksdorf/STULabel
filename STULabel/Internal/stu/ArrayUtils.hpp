// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Allocation.hpp"
#include "stu/ArrayRef.hpp"
#include "stu/Iterator.hpp"

#include <cstring>

namespace stu {

namespace array_utils {

template <typename T, EnableIf<isTriviallyDestructible<T>> = 0>
STU_CONSTEXPR
void destroyArray(T* __unused array, Int __unused count) noexcept {}

template <typename T, EnableIf<!isTriviallyDestructible<T> && !isVoid<T>> = 0>
STU_NO_INLINE
void destroyArray(T* array, Int count) noexcept {
  static_assert(isNothrowDestructible<T>);
  STU_DEBUG_ASSERT(count >= 0);
  Int n = count;
  while (n != 0) {
    --n;
    array[n].~T(); // Will eventually trigger an error if count is negative.
  }
}

template <typename AllocatorRef, typename T,
          EnableIf<isAllocatorRef<AllocatorRef> && isTriviallyDestructible<T>> = 0>
STU_INLINE
void destroyAndDeallocate(AllocatorRef&& allocator, T* array, Int count)
       noexcept(!STU_ASSERT_MAY_THROW)
{
  allocator.get().deallocate(array, count);
}

namespace detail {
  template <typename Allocator, typename T,
            EnableIf<isAllocator<Allocator> && isTrivial<Allocator>> = 0>
  STU_NO_INLINE
  void destroyAndDeallocateImpl(T* array, Int count) noexcept(!STU_ASSERT_MAY_THROW) {
    destroyArray(array, count);
    Allocator{}.deallocate(array, count);
  }

  template <typename AllocatorRef, typename T,
            EnableIf<!isAllocator<AllocatorRef> && isTrivial<AllocatorRef>> = 0>
  STU_NO_INLINE
  void destroyAndDeallocateImpl(T* array, Int count) noexcept(!STU_ASSERT_MAY_THROW) {
    destroyArray(array, count);
    AllocatorRef::create().get().deallocate(array, count);
  }

  template <typename Allocator, typename T,
            EnableIf<isAllocator<Allocator>> = 0>
  STU_NO_INLINE
  void destroyAndDeallocateImpl(Allocator& allocator, T* array, Int count)
         noexcept(!STU_ASSERT_MAY_THROW)
  {
    destroyArray(array, count);
    allocator.deallocate(array, count);
  }

  template <typename AllocatorRef, typename T,
            EnableIf<!isAllocator<AllocatorRef>> = 0>
  STU_NO_INLINE
  void destroyAndDeallocateImpl(AllocatorRef& allocator, T* array, Int count)
        noexcept(!STU_ASSERT_MAY_THROW)
  {
    destroyArray(array, count);
    allocator.get().deallocate(array, count);
  }
}

template <typename AllocatorRef, typename T,
          EnableIf<isAllocatorRef<AllocatorRef> && !isTriviallyDestructible<T>> = 0>
STU_INLINE
void destroyAndDeallocate(AllocatorRef&& allocator, T* array, Int count) noexcept {
  if constexpr (AllocatorRefHasNonTrivialGet<AllocatorRef>::value) {
    if constexpr (isTrivial<AllocatorRef> && isEmpty<AllocatorRef>) {
      detail::destroyAndDeallocateImpl<AllocatorRef>(array, count);
    } else {
      detail::destroyAndDeallocateImpl(allocator, array, count);
    }
  } else {
    using Allocator = AllocatorTypeOfRef<AllocatorRef>;
    if constexpr (isTrivial<Allocator> && isEmpty<Allocator>) {
      detail::destroyAndDeallocateImpl<Allocator>(array, count);
    } else {
      detail::destroyAndDeallocateImpl(allocator.get(), array, count);
    }
  }
}


// ============================================================================
// MARK: initializeArray (transactional)
// ============================================================================


/// \brief Zero-initializes the range [array, array + length).
template <typename T, EnableIf<isTriviallyConstructible<T>> = 0>
STU_INLINE
void initializeArray(T* array, Int length) noexcept {
  static_assert(!isConst<T>);
  if (length != 0) {
    memset(array, 0, sign_cast(length)*sizeof(T));
  }
}

/// \brief Initializes the range [array, array + length) to the specified value.
STU_INLINE
void initializeArray(UInt8* array, Int length, UInt8 value) noexcept {
  if (length != 0) {
    memset(array, value, sign_cast(length));
  }
}

#if STU_HAS_BYTE
STU_INLINE
void initializeArray(Byte* array, Int length, Byte value) noexcept {
  initializeArray(reinterpret_cast<UInt8*>(array), length, static_cast<UInt8>(value));
}
#endif

/// \brief Initializes the range [array, array + length) to the specified value.
STU_INLINE
void initializeArray(Int8* array, Int length, Int8 value) noexcept {
  initializeArray(reinterpret_cast<UInt8*>(array), length, static_cast<UInt8>(value));
}

/// \brief Initializes the range [array, array + length) to the specified value.
STU_INLINE
void initializeArray(char* array, Int length, char value) noexcept {
  initializeArray(reinterpret_cast<UInt8*>(array), length, static_cast<UInt8>(value));
}

/// \brief Constructs all elements in the range [array, array + length)
///        with the specified constructor arguments.
///
/// T must be nothrow-destructible.
///
/// This function's behaviour is transactional.
template <typename T, typename... Arguments, EnableIf<!isOneOf<T, char, Int8, UInt8, Byte>> = 0>
void initializeArray(T* array, Int length, Arguments... arguments)
       noexcept(noexcept(T(arguments...)))
{
  static_assert(!isConst<T>);
  static_assert(isNothrowDestructible<T>);

  T* const arrayBegin = array;

  auto guard = scopeGuardIf<!noexcept(T(arguments...))>([&] {
    destroyArray(arrayBegin, array - arrayBegin);
  });

  T* const arrayEnd = array + length;
  for (; array != arrayEnd; ++array) {
    STU_ASSUME(array != nullptr);
    new (array) T(arguments...); // Will eventually trigger an error if length is negative.
  }

  guard.dismiss();
}

// ============================================================================
// MARK: copyConstructArray
//      (transactional; arrays must not overlap)
// ============================================================================

/// \brief Copies [source, source + length) to the uninitialized range
///        [destination, destination + length). Returns source + length;
template <typename T, typename U,
          EnableIf<isConvertibleArrayPointer<const U*, const T*> && isBitwiseCopyable<T>> = 0>
STU_INLINE
const U* copyConstructArray(const U* source, Int length, T* destination) noexcept {
  if (length != 0) {
    STU_DEBUG_ASSERT(length >= 0);
    memcpy(destination, source, sign_cast(length)*sizeof(T));
  }
  return source + length;
}

/// \brief Copies [source, source + length) to the uninitialized range
///        [destination, destination + length). Returns source + length;
template <typename U, typename T,
          EnableIf<!(isConvertibleArrayPointer<const U*, const T*> && isBitwiseCopyable<T>)
                   && isNothrowConstructible<T, U&>> = 0>
const U* copyConstructArray(const U* source, Int length, T* destination) noexcept {
  static_assert(!isConst<T>);
  STU_DEBUG_ASSERT(length >= 0);
  for (Int i = 0; i < length; ++i) {
    T* const p = &destination[i];
    STU_ASSUME(p != nullptr);
    new (p) T(source[i]);
  }
  return source + length;
}

/// \brief Copies [source, source + length) to the uninitialized range
///        [destination, destination + length). Returns source + length.
///
/// T must be nothrow-destructible.
///
/// This function's behaviour is transactional.
template <typename InputIterator, typename T,
          typename R = IteratorReferenceType<InputIterator>,
          EnableIf<!(isPointer<InputIterator> && isNothrowConstructible<T, R>)> = 0>
InputIterator copyConstructArray(InputIterator source, Int length, T* destination)
                noexcept(isNothrowIncrementable<InputIterator> && noexcept(T(*source)))
{
  static_assert(!isConst<T>);
  static_assert(isNothrowDestructible<T>);

  STU_DEBUG_ASSERT(length >= 0);

  T* const destinationBegin = destination;
  auto guard = ScopeGuard{[&] {
                 destroyArray(destinationBegin, destination - destinationBegin);
               }};

  T* const destinationEnd = destination + length;
  for (; destination != destinationEnd; ++destination, ++source) {
    STU_ASSUME(destination != nullptr);
    new (destination) T(*source);
  }

  guard.dismiss();

  return source;
}

template <typename T, typename Array,
          typename U = RemoveReference<decltype(declval<const Array&>()[0])>,
          EnableIf<isConvertible<const Array&, ArrayRef<const U>>> = 0>
STU_INLINE
void copyConstructArray(const Array& array, T* destination) {
  static_assert(!isConst<T>);
  const ArrayRef<const U> arrayRef{array};
  copyConstructArray(arrayRef.begin(), arrayRef.count(), destination);
}

} // namespace ArrayUtils

} // namespace stu
