// Copyright 2018 Stephan Tolksdorf

#include "stu/Array.hpp"

#include "TestUtils.hpp"

#include "AllocatorUtils.hpp"
#include "TestValue.hpp"

#include <tuple>

using namespace stu;

TEST_CASE_START(ArrayTests)

TEST(FixedArray) {
  using Fixed = stu::Fixed;
  constexpr Array<Int, Fixed, 3> array = {1, 2, 3};
  static_assert(sizeof(Array<Int, Fixed, 3>) == 3*sizeof(Int));
  static_assert(array[0] == 1);
  static_assert(array[1] == 2);
  static_assert(array[$ - 1] == 3);
  static_assert(sizeof(std::tuple<Int, Array<Int, Fixed, 0>>) == sizeof(Int));
}

TEST(AllocatedArray) {
  {
    Array<TestValue> array;
    CHECK_EQ(array.begin(), nullptr);
    CHECK_EQ(array.count(), 0);
  }
  using Alloc = MoveOnlyAllocatorRef;
  {
    Array<Int, Alloc> array{Alloc::create()};
    CHECK_EQ(array.begin(), nullptr);
    CHECK_EQ(array.count(), 0);
    array = Array<Int, Alloc>(zeroInitialized, Count{3}, Alloc::create());
    CHECK_EQ(array.count(), 3);
    for (Int i = 0; i < array.count(); ++i) {
      CHECK_EQ(array[i], 0);
    }
  }
  {
    Array<TestValue, Alloc> array(repeat(TestValue{1}, 3), Alloc::create());
    CHECK_EQ(array.count(), 3);
    TestValue* const p = array.begin();
    for (Int i = 0; i < array.count(); ++i) {
      CHECK_EQ(array[i], 1);
    }
    Array<TestValue, Alloc> array2{std::move(array)};
    CHECK_EQ(array.count(), 0);
    CHECK_EQ(array.begin(), nullptr);
    CHECK_EQ(array2.count(), 3);
    CHECK_EQ(array2.begin(), p);

    Array<TestValue, Alloc> array3{repeat(TestValue{3}, 7), Alloc::create()};
    TestValue* const p2 = array3.begin();
    array2 = std::move(array3);
    CHECK_EQ(array2.count(), 7);
    CHECK_EQ(array2.begin(), p2);

    ArrayRef<TestValue> arrayRef = std::move(array2).toNonOwningArrayRef();
    const Array<TestValue, Alloc> array4{arrayRef.begin(), arrayRef.count(),
                                         std::move(array2.allocator())};
    CHECK_EQ(array4.count(), 7);
    CHECK_EQ(array4.begin(), p2);

  #if !STU_NO_EXCEPTIONS
    {
      static int countDown = 5;
      struct Exception : std::exception {};
      struct Value : TestValue {
        using TestValue::TestValue;
        Value(const Value& other)
        : TestValue(other)
        {
          if (--countDown == 0) { throw Exception(); }
        }
      };
      try {
        Array<Value, Alloc>{repeat(Value{0}, 3), Alloc::create()};
        __builtin_trap();
      } catch (const Exception&) {}
    }
  #endif
  }

  CHECK_EQ(TestValue::liveValueCount(), 0);
  CHECK_EQ(MoveOnlyAllocatorRef::Allocator::instance.allocationCount(), 0);
}

TEST_CASE_END

