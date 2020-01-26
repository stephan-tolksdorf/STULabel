// Copyright 2018 Stephan Tolksdorf

#pragma once

#include "stu/Allocation.hpp"

#include <unordered_map>

using Int = stu::Int;
using UInt = stu::UInt;
using Byte = stu::stu::Byte;

template <typename Allocator>
class ValidatingAllocator : public stu::AllocatorBase<ValidatingAllocator<Allocator>> {
  std::unordered_map<Byte*, UInt> allocations_;
  Allocator allocator_;
public:
  static constexpr unsigned minAlignment = Allocator::minAlignment;

  Int allocationCount() { return stu::sign_cast(allocations_.size()); }

  template <typename... Args>
  ValidatingAllocator(Args&&... args)
  : allocator_(std::forward<Args>(args)...)
  {}

  ~ValidatingAllocator() {
    if (!allocations_.empty()) {
      __builtin_trap();
    }
  }

private:
  friend stu::AllocatorBase<ValidatingAllocator<Allocator>>;

  Byte* allocateImpl(UInt size) {
    Byte* const result = allocator_.allocate(size, stu::unchecked);
    allocations_.emplace(result, size);
    return result;
  }

  void deallocateImpl(Byte* pointer, UInt minAllocationSize) noexcept {
    const auto iter = allocations_.find(pointer);
    if (iter == allocations_.end()) {
      __builtin_trap();
    }
    const auto [_, size] = *iter;
    if (size != minAllocationSize) {
      __builtin_trap();
    }
    allocations_.erase(iter);
    allocator_.deallocate(pointer, minAllocationSize, stu::unchecked);
  }

  Byte* increaseCapacityImpl(Byte* pointer, UInt usedSize, UInt oldSize, UInt newSize) {
    Byte* const result = allocator_.increaseCapacity(pointer, usedSize, oldSize, newSize,
                                                     stu::unchecked);
    updateAllocation(pointer, oldSize, result, newSize);
    return result;
  }

  Byte* decreaseCapacityImpl(Byte* pointer, UInt usedSize, UInt oldSize, UInt newSize) noexcept {
    Byte* const result = allocator_.decreaseCapacity(pointer, usedSize, oldSize, newSize,
                                                    stu::unchecked);
    updateAllocation(pointer, oldSize, result, newSize);
    return result;
  }

  void updateAllocation(Byte* oldPointer, UInt oldSize, Byte* newPointer, UInt newSize) {
    const auto iter = allocations_.find(oldPointer);
    if (iter == allocations_.end()) {
      __builtin_trap();
    }
    const auto [_, size] = *iter;
    if (size != oldSize) {
      __builtin_trap();
    }
    allocations_.erase(iter);
    allocations_.emplace(newPointer, newSize);
  }
};

using ValidatingMalloc = ValidatingAllocator<stu::Malloc>;

class MoveOnlyAllocatorRef {
protected:
  MoveOnlyAllocatorRef() = default;
public:
  static MoveOnlyAllocatorRef create() noexcept { return {}; }

  MoveOnlyAllocatorRef(MoveOnlyAllocatorRef&&) = default;
  MoveOnlyAllocatorRef& operator=(MoveOnlyAllocatorRef&&) = default;

  MoveOnlyAllocatorRef(const MoveOnlyAllocatorRef&) = delete;
  MoveOnlyAllocatorRef& operator=(const MoveOnlyAllocatorRef&) = delete;

  class Allocator : public ValidatingAllocator<stu::Malloc> {
  public:
    static Allocator instance;
  private:
    Allocator() = default;
    Allocator(const Allocator&) = delete;
    Allocator& operator=(const Allocator&) = delete;
    Allocator(const Allocator&&) = delete;
    Allocator& operator=(const Allocator&&) = delete;
  };

  Allocator& get() const noexcept { return Allocator::instance; }
};

class MoveOnlyAllocatorRefWithNonTrivialGet : public MoveOnlyAllocatorRef {
  MoveOnlyAllocatorRefWithNonTrivialGet() = default;
  void* field __unused;
public:
  static MoveOnlyAllocatorRefWithNonTrivialGet create() noexcept { return {}; }
};

template <>
struct stu::AllocatorRefHasNonTrivialGet<MoveOnlyAllocatorRefWithNonTrivialGet> : stu::True {};

