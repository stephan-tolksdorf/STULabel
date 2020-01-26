// Copyright 2018 Stephan Tolksdorf

#include "stu/Range.hpp"

#include "TestUtils.hpp"

using namespace stu;

TEST_CASE_START(RangeTests)

TEST(Range) {
  {
    Range<stu::Int32> r{1, 2};
    r += 1;
    CHECK_EQ(r, Range<Int32>(2, 3));
  }
  CHECK_EQ(Range<Int32>(1, 2) + 1, Range<Int32>(2, 3));
  CHECK_EQ(Range<Int32>(1, 2) + 1LL, Range<Int64>(2, 3));
  CHECK_EQ(1 + Range<Int32>(1, 2), Range<Int32>(2, 3));
  CHECK_EQ(1LL + Range<Int32>(1, 2), Range<Int64>(2, 3));

  {
    Range<stu::Int32> r{1, 2};
    r -= 1;
    CHECK_EQ(r, Range<Int32>(0, 1));
  }
  CHECK_EQ(Range<Int32>(1, 2) - 1, Range<Int32>(0, 1));
  CHECK_EQ(Range<Int32>(1, 2) - 1LL, Range<Int64>(0, 1));

  {
    Range<stu::Int32> r{1, 2};
    r *= 2;
    CHECK_EQ(r, Range<Int32>(2, 4));
  }
  CHECK_EQ(Range<Int32>(1, 2) * 2, Range<Int32>(2, 4));
  CHECK_EQ(Range<Int32>(1, 2) * 2LL, Range<Int64>(2, 4));
  CHECK_EQ(2 * Range<Int32>(1, 2), Range<Int32>(2, 4));
  CHECK_EQ(2LL * Range<Int32>(1, 2), Range<Int64>(2, 4));

  {
    Range<stu::Int32> r{1, 2};
    r *= -2;
    CHECK_EQ(r, Range<Int32>(-4, -2));
  }
  CHECK_EQ(Range<Int32>(1, 2) * -2, Range<Int32>(-4, -2));
  CHECK_EQ(Range<Int32>(1, 2) * -2LL, Range<Int64>(-4, -2));
  CHECK_EQ(-2 * Range<Int32>(1, 2), Range<Int32>(-4, -2));
  CHECK_EQ(-2LL * Range<Int32>(1, 2), Range<Int64>(-4, -2));

  {
    Range<stu::Int32> r{1, 2};
    r /= 2;
    CHECK_EQ(r, Range<Int32>(0, 1));
  }
  CHECK_EQ(Range<Int32>(1, 2) / 2, Range<Int32>(0, 1));
  CHECK_EQ(Range<Int32>(1, 2) / 2LL, Range<Int64>(0, 1));

  {
    Range<stu::Int32> r{1, 2};
    r /= -2;
    CHECK_EQ(r, Range<Int32>(-1, 0));
  }
  CHECK_EQ(Range<Int32>(1, 2) / -2, Range<Int32>(-1, 0));
  CHECK_EQ(Range<Int32>(1, 2) / -2LL, Range<Int64>(-1, 0));
}


TEST_CASE_END

