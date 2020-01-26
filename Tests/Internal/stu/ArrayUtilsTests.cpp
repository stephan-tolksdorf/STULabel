// Copyright 2018 Stephan Tolksdorf

#include "stu/ArrayUtils.hpp"

#include "TestUtils.hpp"

#include "TestValue.hpp"
#include "AllocatorUtils.hpp"

#include <list>

using namespace stu;
using namespace stu::array_utils;

TEST_CASE_START(ArrayUtils)

TEST(DestroyArray) {
  TestValue* values = Malloc().allocate<TestValue>(3);
  for (int i = 0; i < 3; ++i) {
    new (values + i) TestValue(i + 1);
  }
  destroyArray((TestValue*)nullptr, 0);
  destroyArray(values, 0);
  destroyArray(values, 3);
  CHECK_EQ(TestValue::liveValueCount(), 0);
  Malloc().deallocate(values, 3);
}

TEST(DeleteArray) {
  auto test = [&](auto alloc) {
    TestValue* values = alloc.get().template allocate<TestValue>(3);
    for (int i = 0; i < 3; ++i) {
      new (values + i) TestValue(i + 1);
    }
    destroyAndDeallocate(std::move(alloc), values, 3);
    CHECK_EQ(TestValue::liveValueCount(), 0);
  };
  test(Malloc());
  test(MoveOnlyAllocatorRef::create());
  test(MoveOnlyAllocatorRefWithNonTrivialGet::create());
  test(Ref{MoveOnlyAllocatorRef::Allocator::instance});
  CHECK_EQ(MoveOnlyAllocatorRef::Allocator::instance.allocationCount(), 0);
}

TEST(InitializeArray) {
  {
    std::tuple<Int, Int> array[3];
    initializeArray(array, 3);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], (std::tuple<Int, Int>(0, 0)));
    }
    initializeArray(array, 3, 1, 2);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], (std::tuple<Int, Int>(1, 2)));
    }
  }
  {
    initializeArray((UInt8*)nullptr, 0, 7);
    UInt8 array[3];
    initializeArray(array, 3, 7);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], 7);
    }
  }
  {
    initializeArray((stu::Int8*)nullptr, 0, 7);
    stu::Int8 array[3];
    initializeArray(array, 3, 7);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], 7);
    }
  }
  {
    initializeArray((char*)nullptr, 0, 7);
    char array[3];
    initializeArray(array, 3, 7);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], 7);
    }
  }
#if STU_HAS_BYTE
  {
    initializeArray((Byte*)nullptr, 0, 7);
    Byte array[3];
    initializeArray(array, 3, 7);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], 7);
    }
  }
#endif
#if !STU_NO_EXCEPTIONS
  {
    static int countDown = 3;
    struct Exception : std::exception {};
    struct Value : TestValue {
      Value(int value) : TestValue{value} {
        if (--countDown == 0) throw Exception{};
      };
    };

    ValidatingMalloc alloc;
    Value* array = alloc.allocate<Value>(3);
    try {
      initializeArray(array, 3, 0);
      __builtin_trap();
    } catch (const Exception&) {};
    CHECK(TestValue::liveValueCount() == 0);
    alloc.deallocate(array, 3);
  }
#endif
}

TEST(CopyConstructArray) {
  {
    int* const newArray = nullptr;
    CHECK_EQ(copyConstructArray((const int*)nullptr, 0, newArray), newArray);
  }
  ValidatingMalloc alloc;
  {
    int array[3] = {1, 2, 3};
    int* const newArray = alloc.allocate<int>(3);
    CHECK_EQ(copyConstructArray(array, 3, newArray), array + 3);
    for (Int i = 0; i < 3; ++i) {
      CHECK_EQ(newArray[i], i + 1);
      newArray[i] = 0;
    }
    copyConstructArray(ArrayRef{array}, newArray);
    for (Int i = 0; i < 3; ++i) {
      CHECK_EQ(newArray[i], i + 1);
    }
    alloc.deallocate(newArray, 3);
  }
  {
    std::tuple<int> array[3] = {1, 2, 3};
    std::tuple<int>* const newArray = alloc.allocate<std::tuple<int>>(3);
    CHECK_EQ(copyConstructArray(array, 3, newArray), array + 3);
    for (Int i = 0; i < 3; ++i) {
      CHECK_EQ(std::get<0>(array[i]), i + 1);
    }
    alloc.deallocate(newArray, 3);
  }
  {
    std::list<TestValue> list = {1, 2, 3};
    TestValue* const array = alloc.allocate<TestValue>(3);
    CHECK_EQ(copyConstructArray(list.begin(), 3, array), list.end());
    for (Int i = 0; i < 3; ++i) {
      CHECK_EQ(array[i], i + 1);
    }
    destroyArray(array, 3);
  #if !STU_NO_EXCEPTIONS
    list.back().throwOnCopy = true;
    try {
      copyConstructArray(list.begin(), 3, array);
      __builtin_trap();
    } catch (TestValueCopyException&) {}
  #endif
    alloc.deallocate(array, 3);
  }
}

TEST_CASE_END
