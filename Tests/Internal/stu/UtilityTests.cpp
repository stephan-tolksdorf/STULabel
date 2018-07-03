// Copyright 2018 Stephan Tolksdorf

#include "stu/Utility.hpp"

#include "TestUtils.hpp"

#include <random>

using namespace stu;

TEST_CASE_START(UtilityTests)

template <typename UInt>
constexpr int countLeadingZeroBits_generic(UInt value) {
  static_assert(IntegerTraits<UInt>::isUnsigned);
  if (value == 0) return IntegerTraits<UInt>::bits;
  int result = 0;
  while ((value & (UInt(1) << (IntegerTraits<UInt>::bits - 1))) == 0) {
    value <<= 1;
    ++result;
  }
  return result;
}

TEST(CountLeadingZeroBits) {
  // TODO: Use explicit template parameter once Xcode's clang supports it.
  const auto test = [&](auto zero) {
    using T = decltype(zero);
    static_assert(isUnsigned<T>);
    const int bits = IntegerTraits<T>::bits;
    static_assert(countLeadingZeroBits(T(0u)) == bits);
    static_assert(countLeadingZeroBits(T(-1)) == 0);
    for (int i = 0; i < bits; ++i) {
      CHECK_EQ(countLeadingZeroBits(static_cast<T>(T(1) << i)), bits - 1 - i);
      CHECK_EQ(countLeadingZeroBits(static_cast<T>(T(-1) >> i)), i);
    }
    std::mt19937_64 rng(123);
    std::uniform_int_distribution<> ud(0, bits - 1);

    for (size_t i = 0; i < 100000; ++i) {
      T r = static_cast<T>(rng());
      const int s = ud(rng);
      r >>= s;
      const int n1 = countLeadingZeroBits(r);
      const int n2 = countLeadingZeroBits_generic(r);
      CHECK_EQ(n1, n2);
    }
  };

  test(UInt8{});
  test(UInt16{});
  test(stu::UInt32{});
  test(UInt64{});
}

TEST(IsPowerOfTwo) {
  static_assert(isPowerOfTwo(1) == true);
  static_assert(isPowerOfTwo(-2) == false);
  static_assert(isPowerOfTwo(0) == false);
  static_assert(isPowerOfTwo(1) == true);
  static_assert(isPowerOfTwo(2) == true);
  static_assert(isPowerOfTwo(3) == false);
  static_assert(isPowerOfTwo(4) == true);
  static_assert(isPowerOfTwo(5) == false);
  static_assert(isPowerOfTwo(6) == false);
  static_assert(isPowerOfTwo(7) == false);
  static_assert(isPowerOfTwo(8) == true);
  static_assert(isPowerOfTwo(9) == false);
  static_assert(isPowerOfTwo(1u << 31) == true);
  static_assert(isPowerOfTwo(1ll << 62) == true);
  static_assert(isPowerOfTwo(1ull << 63) == true);
}

TEST(RoundUpToPowerOfTwo) {
  static_assert(roundUpToPowerOfTwo(0u) == 0u);
  static_assert(roundUpToPowerOfTwo(1u) == 1u);
  static_assert(roundUpToPowerOfTwo(2u) == 2u);
  static_assert(roundUpToPowerOfTwo(3u) == 4u);
  static_assert(roundUpToPowerOfTwo(4u) == 4u);
  static_assert(roundUpToPowerOfTwo(5u) == 8u);
  static_assert(roundUpToPowerOfTwo(6u) == 8u);
  static_assert(roundUpToPowerOfTwo(7u) == 8u);
  static_assert(roundUpToPowerOfTwo(8u) == 8u);
  static_assert(roundUpToPowerOfTwo(9u) == 16u);
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 30) - 1) == uint32_t(1u << 30));
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 30)) == uint32_t(1u << 30));
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 30) + 1) == uint32_t(1u << 31));
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 31) - 1) == uint32_t(1u << 31));
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 31)) == uint32_t(1u << 31));
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 31) + 1) == uint32_t(1u << 31) + 1);
  static_assert(roundUpToPowerOfTwo(uint32_t(1u << 31) + 2) == uint32_t(1u << 31) + 2);
  static_assert(roundUpToPowerOfTwo(UINT32_MAX) == UINT32_MAX);
  static_assert(roundUpToPowerOfTwo((1ull << 63) - 1) == 1ull << 63);
  static_assert(roundUpToPowerOfTwo(UINT64_MAX) == UINT64_MAX);
}

TEST(RoundDownToMultipleOf) {
  static_assert(roundDownToMultipleOf<8>(0) == 0);
  static_assert(roundDownToMultipleOf<8>(1) == 0);
  static_assert(roundDownToMultipleOf<8>(7) == 0);
  static_assert(roundDownToMultipleOf<8>(8) == 8);
  static_assert(roundDownToMultipleOf<8>(9) == 8);
  static_assert(roundDownToMultipleOf<8>(15) == 8);
  static_assert(roundDownToMultipleOf<8>(16) == 16);
  static_assert(roundDownToMultipleOf<8>(17) == 16);
  static_assert(roundDownToMultipleOf<8>(24) == 24);
  static_assert(roundDownToMultipleOf<8>(25) == 24);
  static_assert(roundDownToMultipleOf<8>(INT_MAX) == (INT_MAX/8)*8);
  static_assert(roundDownToMultipleOf<8>(-1) == -8);
  static_assert(roundDownToMultipleOf<8>(-7) == -8);
  static_assert(roundDownToMultipleOf<8>(-8) == -8);
  static_assert(roundDownToMultipleOf<8>(-9) == -16);
  static_assert(roundDownToMultipleOf<8>(-15) == -16);
  static_assert(roundDownToMultipleOf<8>(-16) == -16);
  static_assert(roundDownToMultipleOf<8>(-17) == -24);
  static_assert(roundDownToMultipleOf<8>(-23) == -24);
  static_assert(roundDownToMultipleOf<8>(-24) == -24);
  static_assert(roundDownToMultipleOf<8>(INT_MIN) == INT_MIN);
}

TEST(RoundUpToMultipleOf) {
  static_assert(roundUpToMultipleOf<8>(0) == 0);
  static_assert(roundUpToMultipleOf<8>(1) == 8);
  static_assert(roundUpToMultipleOf<8>(7) == 8);
  static_assert(roundUpToMultipleOf<8>(8) == 8);
  static_assert(roundUpToMultipleOf<8>(9) == 16);
  static_assert(roundUpToMultipleOf<8>(16) == 16);
  static_assert(roundUpToMultipleOf<8>(17) == 24);
  static_assert(roundUpToMultipleOf<8>(24) == 24);
  static_assert(roundUpToMultipleOf<8>(25) == 32);
  static_assert(roundUpToMultipleOf<8>((INT_MAX/8)*8) == (INT_MAX/8)*8);
  static_assert(roundUpToMultipleOf<8>(-1) == 0);
  static_assert(roundUpToMultipleOf<8>(-7) == 0);
  static_assert(roundUpToMultipleOf<8>(-8) == -8);
  static_assert(roundUpToMultipleOf<8>(-9) == -8);
  static_assert(roundUpToMultipleOf<8>(-15) == -8);
  static_assert(roundUpToMultipleOf<8>(-16) == -16);
  static_assert(roundUpToMultipleOf<8>(-17) == -16);
  static_assert(roundUpToMultipleOf<8>(-23) == -16);
  static_assert(roundUpToMultipleOf<8>(-24) == -24);
  static_assert(roundUpToMultipleOf<8>(INT_MIN) == INT_MIN);
}

TEST(IsAligned) {
  UInt n = 0;
  CHECK(isAligned<UInt>(&n));
  CHECK(isAligned<alignof(UInt)>(&n));
  CHECK(!isAligned<UInt>(reinterpret_cast<Byte*>(&n) + 1));
  CHECK(!isAligned<alignof(UInt)>(reinterpret_cast<Byte*>(&n) + 1));
  CHECK(!isAligned<UInt>(reinterpret_cast<Byte*>(&n) + (alignof(UInt) - 1)));
  CHECK(!isAligned<alignof(UInt)>(reinterpret_cast<Byte*>(&n) + (alignof(UInt) - 1)));
  CHECK(isAligned<UInt>(reinterpret_cast<Byte*>(&n) + alignof(UInt)));
  CHECK(isAligned<alignof(UInt)>(reinterpret_cast<Byte*>(&n) + alignof(UInt)));
}

TEST_CASE_END
