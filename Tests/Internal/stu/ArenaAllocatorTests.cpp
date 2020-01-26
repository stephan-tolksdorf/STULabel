// Copyright 2018 Stephan Tolksdorf

#include "stu/ArenaAllocator.hpp"

#include "TestUtils.hpp"

using namespace stu;

TEST_CASE_START(ArenaAllocatorTests)

TEST(ZeroBuffer) {
  ArenaAllocator<>::InitialBuffer<0> buffer;
  ArenaAllocator<> alloc{Ref{buffer}};
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<Byte>(), 0);
  Byte* const p0 = alloc.allocate(1);
  p0[0] = 0;
  CHECK(p0 != (Byte*)(&buffer));
  alloc.deallocate(p0);
  const stu::Int minAllocationGap = ArenaAllocator<>::minAllocationGap;
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<Byte>(), 4096 - minAllocationGap);
}

TEST(AllocateDeallocate) {
  const stu::Int bufferSize = 64;
  ArenaAllocator<>::InitialBuffer<bufferSize> buffer;
  ArenaAllocator<> alloc{Ref{buffer}};
  constexpr stu::Int minAlignment = ArenaAllocator<>::minAlignment;
  const stu::Int minAllocationGap = ArenaAllocator<>::minAllocationGap;
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<uint32_t>(), (bufferSize - minAllocationGap)/4);

  if (minAllocationGap == 0) {
    Byte* const p00 = alloc.allocate(0);
    CHECK_EQ(p00, (Byte*)(&buffer));
    CHECK_EQ(p00, alloc.allocate(0));
    alloc.deallocate(p00, 0);
  }
  Byte* const p0 = alloc.allocate(1);
  p0[0] = 0;
  CHECK_EQ(p0, (Byte*)(&buffer));
  stu::Int* const p1 = alloc.allocate<Int>(1);
  p1[0] = 1;
  const stu::Int offset = roundUpToMultipleOf<minAlignment>(1 + minAllocationGap);
  CHECK_EQ((Byte*)p1, p0 + offset);
  const stu::Int offset2 = offset + roundUpToMultipleOf<minAlignment>((Int)sizeof(Int) + minAllocationGap);
  const stu::Int n = (bufferSize - offset2 - minAllocationGap)/(stu::Int)sizeof(stu::Int);
  CHECK_EQ(n, alloc.freeCapacityInCurrentBuffer<Int>());
  stu::Int* const p2 = alloc.allocate<Int>(n);
  CHECK_EQ((Byte*)p2, p0 + offset2);
  p2[0] = 2;
  p2[n - 1] = 2;
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<Byte>(), 0);
  alloc.deallocate(p2, n);
  stu::Int* const p3 = alloc.allocate<Int>(n);
  CHECK_EQ(p2, p3);
  alloc.deallocate(p3, n);
  alloc.deallocate(p1);
  alloc.deallocate(p0);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(p0));
#endif

  Byte* const p4 = alloc.allocate(bufferSize - minAllocationGap);
  CHECK_EQ(p0, p4);
  alloc.deallocate(p4, bufferSize - minAllocationGap);
  Byte* const p5 = alloc.allocate(1);
  CHECK_EQ(p0, p5);
  Byte* const p6 = alloc.allocate(bufferSize);
  CHECK(p6 != (Byte*)p1);
  alloc.deallocate(p6, bufferSize);
  const stu::Int n2 = alloc.freeCapacityInCurrentBuffer<Byte>() + 1;
  CHECK_EQ(n2, 4096 - minAllocationGap + 1);
  Byte* const p7 = alloc.allocate(n2);
  CHECK(p7 != (Byte*)p6);
  p7[0] = 7;
  p7[n2 - 1] = 7;
  alloc.deallocate(p7, n2);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&p7[0]));
  CHECK(__asan_address_is_poisoned(&p7[n2 - 1]));
#endif
  const stu::Int n3 = 8*4096 - 1 - minAllocationGap;
  Byte* const p8 = alloc.allocate(n3);
  p8[0] = 8;
  p8[n3 - 1] = 8;
  alloc.deallocate(p8, n3);
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<Byte>(), n3 + 1);
#if !STU_NO_EXCEPTIONS
  CHECK_THROWS_BAD_ALLOC(alloc.allocate(maxValue<UInt>/2 - 4094 - minAllocationGap));
#endif
}

TEST(IncreaseDecreaseCapacity) {
  const stu::Int bufferSize = 64;
  const stu::Int minAllocationGap = ArenaAllocator<>::minAllocationGap;
  ArenaAllocator<>::InitialBuffer<bufferSize> buffer;
  ArenaAllocator<> alloc{Ref{buffer}};
  Byte* const p0 = alloc.allocate(4);
  CHECK_EQ(alloc.increaseCapacity(p0, 4, 4, 6), p0);
  p0[4] = 0;
  p0[5] = 0;
  CHECK_EQ(alloc.increaseCapacity(p0, 6, 6, 8), p0);
  const int n = 8 + (int)alloc.freeCapacityInCurrentBuffer<Byte>();
  CHECK_EQ(n, bufferSize - minAllocationGap*(1 + sign_cast(ArenaAllocator<>::minAlignment)));
  CHECK_EQ(alloc.increaseCapacity(p0, 8, 8, n), p0);
  CHECK_EQ(alloc.decreaseCapacity(p0, 0, n, 0), p0);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&p0[0]));
  CHECK(__asan_address_is_poisoned(&p0[n - 1]));
#endif
  CHECK_EQ(alloc.increaseCapacity(p0, 0, 0, 1), p0);
  p0[0] = 1;
  Byte* const p1 = alloc.allocate(1);
  CHECK(p0 < p1);
  Byte* const p2 = alloc.increaseCapacity(p0, 1, 1, 2);
  CHECK(p1 < p2);
  CHECK_EQ(alloc.decreaseCapacity(p1, 0, 1, 0), p1);
  const int n2 = (int)alloc.freeCapacityInCurrentBuffer<Byte>() + 1;
  Byte* const p4 = alloc.increaseCapacity(p1, 0, 0, n2);
  CHECK(p1 != p4);
  p4[0] = 4;
  p4[n2 - 1] = 4;
  CHECK_EQ(alloc.decreaseCapacity(p4, 0, n2, 0), p4);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&p4[0]));
  CHECK(__asan_address_is_poisoned(&p4[n2 - 1]));
#endif
  alloc.deallocate(p4, 0);
  CHECK_EQ(alloc.freeCapacityInCurrentBuffer<Byte>(), 4096 - minAllocationGap);
}

TEST_CASE_END
