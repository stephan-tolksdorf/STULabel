// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Assert.h"
#include "stu/Casts.hpp"
#include "stu/MinMax.hpp"
#include "stu/Ref.hpp"
#include "stu/ScopeGuard.hpp"
#include "stu/Utility.hpp"

#include <cstdlib>

namespace stu {

// The Allocator concept used here is sufficient for the limited needs of this library, but would be
// inadequate for a general-purpose base library.

template <typename Derived>
class AllocatorBase;

namespace detail { struct AllocatorBaseTag {}; }

/// An Allocator must publicly derive from AllocatorBase.
template <typename T>
constexpr bool isAllocator = isDerivedFrom<RemoveCV<T>, detail::AllocatorBaseTag>;

template <typename AllocatorRef>
using AllocatorTypeOfRef = decltype(declval<const RemoveCVReference<AllocatorRef>&>().get());

namespace detail {
  template <typename T>
  struct IsAllocatorRefImpl {
    using Allocator = Apply<AllocatorTypeOfRef, T>;

    static constexpr bool value = isAllocator<Allocator>;

    static_assert(!value || noexcept(declval<T>().get()),
                  "The AllocatorRef's get method must be declared as noexcept.");

    static_assert(!value || isNothrowMoveConstructible<T>,
                  "An AllocatorRef must be nothrow move-constructible.");

    static_assert(!value || !isMoveAssignable<T> || isNothrowMoveAssignable<T>,
                  "A move-assignable AllocatorRef must be nothrow move-assignable");

    static_assert(!value || isNothrowMoveConstructible<Allocator>,
                  "The value returned the AllocatorRef's get() must be nothrow move-constructible.");
  };
}

/// An AllocatorRef must define a get() member function that returns an Allocator object or
/// reference and it must be nothrow move-constructible.
template <typename T>
constexpr bool isAllocatorRef = detail::IsAllocatorRefImpl<RemoveCVReference<T>>::value;

namespace detail {
  [[noreturn]]
  void throwBadAlloc();

  [[noreturn]]
  STU_INLINE void badAlloc() {
  #if STU_NO_EXCEPTIONS
    __builtin_trap();
  #else
    throwBadAlloc();
  #endif
  }
};

// The derived class has to implement and make accessible to AllocatorBase:
//
//   static constexpr int minAlignment;
//
//   // \pre size <= IntegerTraits<UInt>::max/2
//   Byte* allocateImpl(UInt size);
//
//   // \pre minAllocationSize <= (size of the allocation at pointer)
//   void deallocateImpl(Byte* pointer, UInt minAllocationSize) noexcept(!STU_ASSERT_MAY_THROW);
//
//   // \pre newSize <= IntegerTraits<UInt>::max/2
//   Byte* increaseCapacityImpl(Byte* pointer, UInt usedSize, UInt oldSize, UInt newSize);
//   Byte* decreaseCapacityImpl(Byte* pointer, UInt usedSize, UInt oldSize, UInt newSize)
//           noexcept(!STU_ASSERT_MAY_THROW);
//
template <typename Derived>
class AllocatorBase : public detail::AllocatorBaseTag {
  STU_CONSTEXPR_T
  Derived& derived() noexcept { return down_cast<Derived&>(*this); }

  STU_CONSTEXPR_T
  const Derived& derived() const noexcept { return down_cast<const Derived&>(*this); }

public:
  /// \pre 0 ≤ `capacity` ≤ `(maxValue<UInt>/2)/sizeof(UInt)`
  template <typename T = Byte, typename Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* allocate(Int capacity) {
    static_assert(alignof(T) <= Derived::minAlignment);
    static_assert(sizeof(Int) <= sizeof(UInt));
    if (static_cast<UInt>(capacity) > IntegerTraits<UInt>::max/(2*sizeof(T))) {
      detail::badAlloc();
    }
    return allocate<T>(capacity, unchecked);
  }
  /// \pre 0 ≤ `capacity` ≤ `(maxValue<UInt>/2)/sizeof(UInt)`
  template <typename T = Byte, typename Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* allocate(Int capacity, Unchecked) {
    static_assert(alignof(T) <= Derived::minAlignment);
    static_assert(sizeof(Int) <= sizeof(UInt));
    Byte* const p = derived().allocateImpl(static_cast<UInt>(capacity)*sizeof(T));
    return reinterpret_cast<T*>(p);
  }

  /// \pre The allocation at `pointer` must have capacity greater than or equal to `minCapacity`.
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  STU_INLINE
  void deallocate(T* pointer, Int minCapacity = 1) noexcept(!STU_ASSERT_MAY_THROW) {
    STU_DEBUG_ASSERT(pointer != nullptr && minCapacity >= 0);
    deallocate(pointer, minCapacity, unchecked);
  }
  /// \pre The allocation at `pointer` must have capacity greater than or equal to `minCapacity`.
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  STU_INLINE
  void deallocate(T* pointer, Int minCapacity, Unchecked) noexcept(!STU_ASSERT_MAY_THROW)
  {
    static_assert(alignof(T) <= Derived::minAlignment);
    Byte* const bytePointer = const_cast<Byte*>(reinterpret_cast<const Byte*>(pointer));
    static_assert(sizeof(Int) <= sizeof(UInt));
    const UInt minAllocationSize = static_cast<UInt>(minCapacity)*sizeof(T);
    static_assert(STU_ASSERT_MAY_THROW
                  || noexcept(derived().deallocate(bytePointer, minAllocationSize)));
    derived().deallocateImpl(bytePointer, minAllocationSize);
  }

  /// \pre The capacity of the allocation at `pointer` must have capacity of `oldCapacity`.
  /// \pre 0 ≤ `usedCount` ≤ `oldCapacity` ≤ `newCapacity`
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* increaseCapacity(T* pointer, Int usedCount, Int oldCapacity, Int newCapacity) {
    STU_DEBUG_ASSERT(pointer != nullptr);
    STU_PRECONDITION(0 <= usedCount && usedCount <= oldCapacity && oldCapacity <= newCapacity);
    static_assert(sizeof(Int) <= sizeof(UInt));
    if (static_cast<UInt>(newCapacity) > IntegerTraits<UInt>::max/(2*sizeof(T))) {
      detail::badAlloc();
    }
    return increaseCapacity(pointer, usedCount, oldCapacity, newCapacity, unchecked);
  }
  /// \pre The capacity of the allocation at `pointer` must have capacity of `oldCapacity`.
  /// \pre 0 ≤ `usedCount` ≤ `oldCapacity` ≤ `newCapacity` ≤ `(maxValue<UInt>/2)/sizeof(T)`
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* increaseCapacity(T* pointer, Int usedCount, Int oldCapacity, Int newCapacity, Unchecked) {
    static_assert(isBitwiseMovable<T>);
    static_assert(alignof(T) <= Derived::minAlignment);
    static_assert(sizeof(Int) <= sizeof(UInt));
    Byte* const newPointer = derived().increaseCapacityImpl(
                               reinterpret_cast<Byte*>(pointer),
                               static_cast<UInt>(usedCount)*sizeof(T),
                               static_cast<UInt>(oldCapacity)*sizeof(T),
                               static_cast<UInt>(newCapacity)*sizeof(T));
    return reinterpret_cast<T*>(newPointer);
  }

  /// \pre The capacity of the allocation at `pointer` must have capacity of `oldCapacity`.
  /// \pre 0 ≤ `usedCount` ≤ `newCapacity` ≤ `oldCapacity`
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* decreaseCapacity(T* pointer, Int usedCount, Int oldCapacity, Int newCapacity)
        noexcept(!STU_ASSERT_MAY_THROW)
  {
    STU_DEBUG_ASSERT(pointer != nullptr);
    STU_PRECONDITION(0 <= usedCount && usedCount <= newCapacity && newCapacity <= oldCapacity);
    return decreaseCapacity(pointer, usedCount, oldCapacity, newCapacity, unchecked);
  }
  /// \pre The capacity of the allocation at `pointer` must have capacity of `oldCapacity`.
  /// \pre 0 ≤ `usedCount` ≤ `newCapacity` ≤ `oldCapacity`
  template <typename T, typename Int = stu::Int, EnableIf<isInteger<Int>> = 0>
  [[nodiscard]] STU_INLINE
  T* decreaseCapacity(T* pointer, Int usedCount, Int oldCapacity, Int newCapacity, Unchecked)
      noexcept(!STU_ASSERT_MAY_THROW)
  {
    static_assert(isBitwiseMovable<T>);
    static_assert(alignof(T) <= Derived::minAlignment);
    static_assert(STU_ASSERT_MAY_THROW
                  || noexcept((Byte*)derived().decreaseCapacityImpl((Byte*)0,
                                                                    (UInt)0, (UInt)0, (UInt)0)));
    static_assert(sizeof(Int) <= sizeof(UInt));
    Byte* const newPointer = derived().decreaseCapacityImpl(
                               reinterpret_cast<Byte*>(pointer),
                               static_cast<UInt>(usedCount)*sizeof(T),
                               static_cast<UInt>(oldCapacity)*sizeof(T),
                               static_cast<UInt>(newCapacity)*sizeof(T));
    return reinterpret_cast<T*>(newPointer);
  }
};

class Malloc : public AllocatorBase<Malloc> {
public:
  static constexpr unsigned minAlignment = sizeof(Int) == 8 ? 16 : 8;

  Malloc get() const noexcept { return {}; }

private:
  friend AllocatorBase<Malloc>;

  [[nodiscard]] STU_INLINE __attribute__((alloc_size(1 + 1)))
  Byte* allocateImpl(UInt size) {
    void* const pointer = std::malloc(max(1u, size));
    if (STU_UNLIKELY(!pointer)) {
      detail::badAlloc();
    }
    return static_cast<Byte*>(pointer);
  }

  STU_INLINE
  void deallocateImpl(Byte* pointer, UInt minAllocationSize) noexcept {
    // Our precondition, that minAllocationSize is not greater than the actual allocation size,
    // currently isn't enough to use the sized deallocation function of most malloc libraries.
    discard(minAllocationSize);
    std::free(pointer);
  }

  [[nodiscard]] STU_INLINE __attribute__((alloc_size(1 + 4)))
  Byte* increaseCapacityImpl(Byte* pointer, UInt usedSize __unused, UInt oldSize __unused,
                             UInt newSize)
  {
    void* const newPointer = std::realloc(pointer, max(1u, newSize));
    if (STU_UNLIKELY(!newPointer)) {
      detail::badAlloc();
    }
    return static_cast<Byte*>(newPointer);
  }

  [[nodiscard]] STU_INLINE __attribute__((alloc_size(1 + 4)))
  Byte* decreaseCapacityImpl(Byte* pointer, UInt usedSize __unused, UInt oldSize __unused,
                             UInt newSize) noexcept
  {
    newSize = max(1u, newSize);
    void* const newPointer = std::realloc(pointer, newSize);
    return static_cast<Byte*>(newPointer) ?: pointer;
  }
};

// A type trait for optimization purposes that can be specialized if necessary.
template <typename AllocatorRef>
struct AllocatorRefHasNonTrivialGet {
private:
  using Allocator = AllocatorTypeOfRef<AllocatorRef>;
public:
  static constexpr bool value = sizeof(AllocatorRef)
                              < (isReference<Allocator> ? sizeof(void*) : sizeof(Allocator));
};

#if !defined(STU_USE_ADDRESS_SANITIZER)
  #if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
    #define STU_USE_ADDRESS_SANITIZER 1
  #else
    #define STU_USE_ADDRESS_SANITIZER 0
  #endif
#endif

#if STU_USE_ADDRESS_SANITIZER

extern "C" STU_NO_THROW
void __sanitizer_annotate_contiguous_container(
         const void* begin, const void* endOfBuffer,
         const void* oldEndOfInitialized, const void* newEndOfInitialized);

extern "C" STU_NO_THROW
bool __asan_address_is_poisoned(void const volatile* address);

extern "C" STU_NO_THROW
void __asan_poison_memory_region(void const volatile* address, std::size_t size);

extern "C" STU_NO_THROW
void __asan_unpoison_memory_region(void const volatile* address, std::size_t size);

#define STU_NO_ADDRESS_SANITATION __attribute__((no_sanitize_address))

namespace sanitizer {
  template <typename T, typename Int, EnableIf<!isVoid<T>> = 0>
  STU_INLINE
  void annotateContiguousArray(T* address, Int capacity, Int oldLength, Int newLength) {
    __sanitizer_annotate_contiguous_container(address, address + capacity,
                                              address + oldLength, address + newLength);
  }

  template <typename T, typename Int>
  STU_INLINE
  void poison(T* address, Int length) {
    __asan_poison_memory_region(address, static_cast<std::size_t>(length)*sizeof(T));
  }

  template <typename T, typename Int>
  STU_INLINE
  void unpoison(T* address, Int length) {
    __asan_unpoison_memory_region(address, static_cast<std::size_t>(length)*sizeof(T));
  }
} // namespace asan

#else // !STU_USE_ADDRESS_SANITIZER

#define STU_NO_ADDRESS_SANITATION

namespace sanitizer {

  template <typename T, typename Int, EnableIf<!isVoid<T>> = 0>
  STU_CONSTEXPR
  void annotateContiguousArray(T* address __unused, Int capacity __unused,
                               Int oldLength __unused, Int newLength __unused)
  {}

  template <typename T, typename Int>
  STU_CONSTEXPR
  void poison(T* address __unused, Int length __unused) {}

  template <typename T, typename Int>
  STU_CONSTEXPR
  void unpoison(T* address __unused, Int length __unused) {}
} // namespace asan

#endif // !STU_USE_ADDRESS_SANITIZER

} // namespace stu
