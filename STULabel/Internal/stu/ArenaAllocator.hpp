// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Array.hpp"
#include "stu/Vector.hpp"
#include "stu/Utility.hpp"

namespace stu {

// Inspired by LLVM's BumpPtrAllocator.

template <typename AllocatorRef = stu::Malloc>
class ArenaAllocator
      : public AllocatorBase<ArenaAllocator<AllocatorRef>>
{
  using Base = AllocatorBase<ArenaAllocator<AllocatorRef>>;
  friend Base;
public:
  static constexpr unsigned minAlignment = max(alignof(void*), alignof(double));
  static_assert(isAllocatorRef<AllocatorRef>);

  template <unsigned size>
  class InitialBuffer {
    friend ArenaAllocator;
    alignas(minAlignment) ArrayStorage<Byte, roundUpToMultipleOf<minAlignment>(size)> bytes_;
  public:
  #if STU_USE_ADDRESS_SANITIZER
    InitialBuffer() noexcept {
      if (size > 0) {
        sanitizer::poison(bytes_.begin(), bytes_.count());
      }
    }
    ~InitialBuffer() {
      if (size > 0) {
        sanitizer::unpoison(bytes_.begin(), bytes_.count());
      }
    }
  #else
    InitialBuffer() noexcept = default;
  #endif

    InitialBuffer(const InitialBuffer& other) = delete;
    InitialBuffer& operator=(const InitialBuffer& other) = delete;
  };

  template <auto size, EnableIf<isDefaultConstructible<AllocatorRef>> = 0>
  explicit STU_INLINE
  ArenaAllocator(Ref<InitialBuffer<size>> buffer) noexcept
  : ArenaAllocator{buffer, AllocatorRef{}} {}

  template <auto size>
  STU_INLINE
  ArenaAllocator(Ref<InitialBuffer<size>> buffer, AllocatorRef allocator) noexcept
  : buffer_{buffer.get().bytes_.begin()},
    bufferSize_{sign_cast(buffer.get().bytes_.count())},
    previousBuffers_{std::move(allocator)}
  {}

  STU_INLINE
  ~ArenaAllocator() {
    if (previousBuffers_.isEmpty()) return;
    destructor_slowPath();
  }

  ArenaAllocator(const ArenaAllocator&) = delete;
  ArenaAllocator& operator=(const ArenaAllocator&) = delete;

  STU_INLINE
  ArenaAllocator(ArenaAllocator&& other) noexcept
  : buffer_(std::exchange(other.buffer_, nullptr)),
    bufferSize_(std::exchange(other.bufferSize_, 0)),
    index_(std::exchange(other.index_, 0)),
    previousBuffers_(std::move(other.previousBuffers_))
  {}

  ArenaAllocator& operator=(ArenaAllocator&&) = delete;

  template <typename T>
  STU_INLINE
  Int freeCapacityInCurrentBuffer() {
    const UInt freeSpace = bufferSize_ - index_;
    if constexpr (minAllocationGap > 0) {
      if (STU_UNLIKELY(freeSpace < minAllocationGap)) return 0;
    }
    return sign_cast((freeSpace - minAllocationGap)/sizeof(T));
  }

  STU_CONSTEXPR_T
  const AllocatorRef& allocator() const & { return previousBuffers_.allocator(); }
  STU_CONSTEXPR_T AllocatorRef& allocator() & { return previousBuffers_.allocator(); }
  STU_CONSTEXPR_T AllocatorRef&& allocator() && { return std::move(previousBuffers_).allocator(); }

  static constexpr UInt minAllocationGap =
                                         #if STU_USE_ADDRESS_SANITIZER
                                           1;
                                         #else
                                           0;
                                         #endif
private:
  Byte* buffer_{};
  UInt  bufferSize_{};
  UInt  index_{};
  Vector<Pair<Byte*, UInt>, 1, AllocatorRef> previousBuffers_;

  STU_INLINE __attribute__((alloc_size(1 + 1)))
  Byte* allocateImpl(UInt size) {
    const UInt roundedUpSize = roundUpToMultipleOf<minAlignment>(size + minAllocationGap);
    const UInt nextIndex = index_ + roundedUpSize;
    if (STU_LIKELY(nextIndex <= bufferSize_)) {
      Byte* const pointer = buffer_ + index_;
      index_ = nextIndex;
      sanitizer::unpoison(pointer, size);
      return pointer;
    }
    return allocate_slowPath(size);
  }

  STU_INLINE
  void deallocateImpl(Byte* pointer, UInt minSize) noexcept {
  #if STU_USE_ADDRESS_SANITIZER
    if (minSize > 0
        && (   __asan_address_is_poisoned(pointer + minSize - 1)
            || __asan_address_is_poisoned(pointer)))
    {
      __builtin_trap();
    }
  #endif
    sanitizer::poison(pointer, minSize);
    const UInt roundedUpSize = roundUpToMultipleOf<minAlignment>(minSize + minAllocationGap);
    const uintptr_t index = reinterpret_cast<uintptr_t>(pointer)
                          - reinterpret_cast<uintptr_t>(buffer_);
    if (index + roundedUpSize == index_) {
      index_ = index;
    }
  }

  STU_INLINE __attribute__((alloc_size(1 + 4)))
  Byte* increaseCapacityImpl(Byte* pointer, UInt usedSize, UInt oldSize, UInt newSize) {
    const uintptr_t index = reinterpret_cast<uintptr_t>(pointer)
                          - reinterpret_cast<uintptr_t>(buffer_);
    const UInt roundedUpOldSize = roundUpToMultipleOf<minAlignment>(oldSize + minAllocationGap);
    const UInt roundedUpNewSize = roundUpToMultipleOf<minAlignment>(newSize + minAllocationGap);
    const uintptr_t oldEndIndex = index + roundedUpOldSize;
    const uintptr_t newEndIndex = index + roundedUpNewSize;
    if (oldEndIndex == index_ && newEndIndex <= bufferSize_) {
      sanitizer::unpoison(pointer + oldSize, newSize - oldSize);
      index_ = newEndIndex;
      return pointer;
    } else {
      Byte* const newPointer = allocateImpl(newSize);
      memcpy(newPointer, pointer, usedSize);
      sanitizer::poison(pointer, oldSize);
      return newPointer;
    }
  }

  STU_INLINE __attribute__((alloc_size(1 + 4)))
  Byte* decreaseCapacityImpl(Byte* pointer, UInt usedSize __unused, UInt oldSize, UInt newSize)
          noexcept
  {
    const uintptr_t index = reinterpret_cast<uintptr_t>(pointer)
                          - reinterpret_cast<uintptr_t>(buffer_);
    const UInt roundedUpOldSize = roundUpToMultipleOf<minAlignment>(oldSize + minAllocationGap);
    const UInt roundedUpNewSize = roundUpToMultipleOf<minAlignment>(newSize + minAllocationGap);
    const uintptr_t oldEndIndex = index + roundedUpOldSize;
    const uintptr_t newEndIndex = index + roundedUpNewSize;
  #if STU_USE_ADDRESS_SANITIZER
    if (oldSize > 0
        && (   __asan_address_is_poisoned(pointer + oldSize - 1)
            || __asan_address_is_poisoned(pointer)))
    {
      __builtin_trap();
    }
  #endif
    sanitizer::poison(pointer + newSize, oldSize - newSize);
    if (oldEndIndex == index_) {
      index_ = newEndIndex;
    }
    return pointer;
  }

  STU_NO_INLINE
  Byte* allocate_slowPath(UInt size) {
    const UInt roundedUpSize = roundUpToMultipleOf<minAlignment>(size + minAllocationGap);
    UInt bufferSize = max(2*bufferSize_, roundedUpSize);
    if (STU_UNLIKELY(bufferSize > IntegerTraits<UInt>::max/2 - 4095)) detail::badAlloc();
    bufferSize = roundUpToMultipleOf<4096>(bufferSize);
    previousBuffers_.ensureFreeCapacity(1);
    Byte *buffer = allocator().get().template allocate<Byte>(bufferSize);
    previousBuffers_.append(pair(buffer_, bufferSize_));
    buffer_ = buffer;
    bufferSize_ = bufferSize;
    index_ = roundedUpSize;
    sanitizer::poison(buffer + size, bufferSize - size);
    return buffer;
  }

  STU_NO_INLINE
  void destructor_slowPath()
         noexcept(noexcept(allocator().get().deallocate(buffer_, bufferSize_)))
  {
    STU_DEBUG_ASSERT(!previousBuffers_.isEmpty());
    allocator().get().deallocate(buffer_, bufferSize_);
    for (auto pair : previousBuffers_[{1, $}].reversed()) {
      const auto [buffer, size] = pair;
      allocator().get().deallocate(buffer, size);
    }
    // The initial buffer wasn't allocated.
    const auto [buffer, size] = previousBuffers_[0];
    sanitizer::poison(buffer, size);
  }
};

extern template struct detail::VectorBase<ArenaAllocator<Malloc>, false>;

// extern template class ArenaAllocator<Malloc>; // clang bug

} // namespace stu
