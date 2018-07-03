// Copyright 2018 Stephan Tolksdorf

#include "stu/Allocation.hpp"

#include "TestUtils.hpp"

#include "AllocatorUtils.hpp"

using namespace stu;

TEST_CASE_START(AllocationTests)

#if STU_ASSERT_MAY_THROW
TEST(AllocatorBasePreconditionAssert) {
  ValidatingMalloc allocator;
#if !STU_NO_EXCEPTIONS
  CHECK_THROWS_BAD_ALLOC(allocator.allocate(maxValue<UInt>/2 + 1));
  CHECK_THROWS_BAD_ALLOC(allocator.allocate<UInt>(maxValue<UInt>/2 + 1));
#endif
  UInt* p = allocator.allocate<UInt>(2);
#if !STU_NO_EXCEPTIONS
  CHECK_THROWS_BAD_ALLOC(allocator.increaseCapacity(p, UInt{0}, UInt{2}, UInt{maxValue<Int>} + 1));
#endif
  CHECK_FAILS_ASSERT(allocator.increaseCapacity(p, 0, 2, 1));
  CHECK_FAILS_ASSERT(allocator.increaseCapacity(p, 3, 2, 2));
  CHECK_FAILS_ASSERT(allocator.decreaseCapacity(p, 2, 2, 3));
  CHECK_FAILS_ASSERT(allocator.decreaseCapacity(p, 3, 2, 2));
  allocator.deallocate(p, 2);
}
#endif

TEST(Malloc) {
  static_assert(isAllocator<Malloc>);
  static_assert(isAllocatorRef<Malloc>);
  ValidatingMalloc allocator;
  Int* p = allocator.allocate<Int>(1);
  *p = 1;
  allocator.deallocate(p);
  p = allocator.allocate<Int>(2);
  p[0] = 1;
  p[1] = 2;
  p = allocator.decreaseCapacity(p, 1, 2, 1);
  CHECK_EQ(p[0], 1);
  p = allocator.increaseCapacity(p, 1, 1, 2);
  CHECK_EQ(p[0], 1);
  p[1] = 2;
  p = allocator.increaseCapacity(p, 2, 2, 3);
  CHECK_EQ(p[0], 1);
  CHECK_EQ(p[1], 2);
  p[2] = 3;
  p = allocator.decreaseCapacity(p, 0, 3, 0);
  CHECK(p != nullptr);
  allocator.deallocate(p, 0);
  p = allocator.allocate<Int>(0);
  CHECK(p != nullptr);
  allocator.deallocate(p, 0);
}

TEST_CASE_END
