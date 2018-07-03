// Copyright 2018 Stephan Tolksdorf

#include "stu/BinarySearch.hpp"

#include "stu/Vector.hpp"

#include "TestUtils.hpp"

using namespace stu;

TEST_CASE_START(BinarySearchTests)

TEST(BinarySearch) {
  for (int i = 0; i < 256; ++i) {
    Vector<Int, 9> vector;
    for (int j = 0; j < 8; ++j) {
      if ((i >> j) & 1) {
        vector.append(j);
      }
    }
    for (int j = -1; j < 10; ++j) {
      const auto predicate = [j](Int x) { return x >= j; };
      const Int expected = vector.indexWhere(predicate).value_or(vector.count());
      const auto result = binarySearchFirstIndexWhere(vector, predicate);
      CHECK_EQ(result.arrayCount, vector.count());
      CHECK_EQ(result.indexOrArrayCount, expected);
      CHECK_EQ(result.indexIsArrayCount(), result.indexOrArrayCount == result.arrayCount);
    }
  }
}

TEST_CASE_END
