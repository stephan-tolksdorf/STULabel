// Copyright 2018 Stephan Tolksdorf

#include "stu/Vector.hpp"

#include "TestUtils.hpp"

#include "AllocatorUtils.hpp"
#include "TestValue.hpp"

#include <tuple>

#include <vector>

@import Foundation;

using namespace stu;

TEST_CASE_START(VectorTests)

TEST(Append) {
  const auto test = [&](auto& vector) {
    for (int i = 1; i <= 16; ++i) {
      vector.append(i);
      CHECK_EQ(vector.count(), i);
      CHECK_EQ(vector.capacity(), i == 1 ? 2 : (int)roundUpToPowerOfTwo(unsigned(i)));
      for (int j = 0; j < i; ++j) {
        CHECK_EQ(vector[j], j + 1);
      }
    }
  };
  {
    Vector<int> vector;
    test(vector);
  }
  {
    ValidatingMalloc alloc;
    Vector<int, 0, Ref<ValidatingMalloc>> vector{Ref{alloc}};
    test(vector);
  }
  {
    Vector<int, 0, MoveOnlyAllocatorRefWithNonTrivialGet> vector{MoveOnlyAllocatorRefWithNonTrivialGet::create()};
    test(vector);
  }
}

TEST(AppendArray) {
  const auto test = [&](auto& vector) {
    vector.append(ArrayRef<int>());
    CHECK_EQ(vector.count(), 0);
    CHECK_EQ(vector.capacity(), 0);
    vector.append(arrayRef({1, 2, 3}));
    CHECK_EQ(vector.count(), 3);
    CHECK_EQ(vector.capacity(), 3);
  #if STU_ASSERT_MAY_THROW
    {
      ArrayRef<const int> aliased = vector[{0, 1}];
      CHECK_FAILS_ASSERT(vector.append(aliased));
    }
  #endif
    vector.append(arrayRef({4, 5}));
    CHECK_EQ(vector.count(), 5);
    CHECK_EQ(vector.capacity(), 6);
  };
  {
    Vector<int> vector;
    test(vector);
  }
  {
    ValidatingMalloc alloc;
    Vector<int, 0, Ref<ValidatingMalloc>> vector{Ref{alloc}};
    test(vector);
  }
  {
    Vector<int, 0, MoveOnlyAllocatorRefWithNonTrivialGet> vector{MoveOnlyAllocatorRefWithNonTrivialGet::create()};
    test(vector);
  }
}

struct ValueWithUninitializedConstructor {
  int value;
  /* implicit */ ValueWithUninitializedConstructor(Uninitialized) : value{-123} {}
};

template <typename T>
using DecltypeAppendRepeatedUninitialized = decltype(declval<Vector<T>>().append(repeat(uninitialized, 1)));

TEST(AppendUninitialized) {
  static_assert(canApply<DecltypeAppendRepeatedUninitialized, int>);
  static_assert(!canApply<DecltypeAppendRepeatedUninitialized, ValueWithUninitializedConstructor>);
  using Alloc = MoveOnlyAllocatorRef;
  {
    Vector<ValueWithUninitializedConstructor, 0, Alloc> vector(Alloc::create());
    // Check that the right method is called.
    vector.append(uninitialized);
    CHECK_EQ(vector[0].value, -123);
  };

  Vector<int, 0, Alloc> vector(Alloc::create());
  vector.append(uninitialized);
  CHECK_EQ(vector.count(), 1);
  CHECK_EQ(vector.capacity(), 2);
  vector.append(uninitialized);
  CHECK_EQ(vector.count(), 2);
  CHECK_EQ(vector.capacity(), 2);
  vector.append(repeat(uninitialized, 3));
  CHECK_EQ(vector.count(), 5);
  CHECK_EQ(vector.capacity(), 5);
  vector.append(repeat(uninitialized, 1));
  CHECK_EQ(vector.count(), 6);
  CHECK_EQ(vector.capacity(), 10);
  vector.append(repeat(uninitialized, 1));
  CHECK_EQ(vector.count(), 7);
  CHECK_EQ(vector.capacity(), 10);
}

TEST(Insert) {
  using Alloc = MoveOnlyAllocatorRef;
  Vector<int, 0, Alloc> vector(Alloc::create());
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.insert(-1, 0));
  CHECK_FAILS_ASSERT(vector.insert(1, 0));
#endif
  vector.insert(0, 1);
  CHECK_EQ(vector[0], 1);
  CHECK_EQ(vector.count(), 1);
  CHECK_EQ(vector.capacity(), 2);
  vector.insert(1, 3);
  CHECK_EQ(vector.count(), 2);
  CHECK_EQ(vector.capacity(), 2);
  CHECK_EQ(vector[1], 3);
  vector.insert(1, 2);
  CHECK_EQ(vector.count(), 3);
  CHECK_EQ(vector.capacity(), 4);
  CHECK_EQ(vector[1], 2);
  vector.insert(0, -1);
  CHECK_EQ(vector.count(), 4);
  CHECK_EQ(vector.capacity(), 4);
  CHECK_EQ(vector[0], -1);
  vector.insert(1, 0);
  CHECK_EQ(vector.count(), 5);
  CHECK_EQ(vector.capacity(), 8);
  for (int i = 0; i < vector.count(); ++i) {
    CHECK_EQ(vector[i], i - 1);
  }
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.insert(-1, 0));
  CHECK_FAILS_ASSERT(vector.insert(vector.count() + 1, 0));
#endif
}

struct TestValueWithDestructor {
  Int value;

  TestValueWithDestructor(Int value) : value{value} {}
  ~TestValueWithDestructor() {
    value = -123;
  }
};

template <> struct stu::IsBitwiseMovable<TestValueWithDestructor> : stu::True {};

TEST(RemoveLast) {
  using Alloc = MoveOnlyAllocatorRef;
  Vector<TestValueWithDestructor, 0, Alloc> vector(Alloc::create());
 #if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.removeLast());
  CHECK_FAILS_ASSERT(vector.removeLast(1));
  CHECK_FAILS_ASSERT(vector.removeLast(maxValue<Int>));
#endif
  vector.removeLast(0);
  vector.removeLast(-1);
  vector.removeLast(minValue<Int>);
  vector.append(1);
  CHECK_EQ(vector[0].value, 1);
  vector.removeLast();
  CHECK_EQ(vector.count(), 0);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(vector.begin()));
#else
  CHECK_EQ(vector.begin()[0].value, -123);
#endif
  vector.append(2);
  vector.append(3);
  vector.append(4);
  vector.removeLast(0);
  CHECK_EQ(vector.count(), 3);
  CHECK_EQ(vector[2].value, 4);
  vector.removeLast(2);
  CHECK_EQ(vector.count(), 1);
  CHECK_EQ(vector[0].value, 2);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&vector.begin()[1]));
  CHECK(__asan_address_is_poisoned(&vector.begin()[2]));
#else
  CHECK_EQ(vector.begin()[1].value, -123);
  CHECK_EQ(vector.begin()[2].value, -123);
#endif
}

TEST(RemoveRange) {
  using Alloc = MoveOnlyAllocatorRef;
  Vector<TestValueWithDestructor, 0, Alloc> vector(Alloc::create());
  vector.removeRange({0, 0});
  vector.removeRange({0, $});
  vector.removeRange({$, $});
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.removeRange({0, -1}));
  CHECK_FAILS_ASSERT(vector.removeRange({0, 1}));
  CHECK_FAILS_ASSERT(vector.removeRange({-1, $}));
  CHECK_FAILS_ASSERT(vector.removeRange({$ - 1, $}));
#endif
  vector.append(1);
  vector.removeRange({0, $});
  CHECK_EQ(vector.count(), 0);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&vector.begin()[0]));
#else
  CHECK_EQ(vector.begin()[0].value, -123);
#endif
  vector.append(2);
  vector.append(3);
  vector.append(4);
  vector.append(5);
  vector.removeRange({1, 3});
  CHECK_EQ(vector.count(), 2);
  CHECK_EQ(vector[0].value, 2);
  CHECK_EQ(vector[1].value, 5);
#if STU_USE_ADDRESS_SANITIZER
  CHECK(__asan_address_is_poisoned(&vector.begin()[2]));
  CHECK(__asan_address_is_poisoned(&vector.begin()[3]));
#else
  CHECK_EQ(vector.begin()[2].value, -123);
#endif
}

TEST(SetCapacity) {
  Vector<int> vector;
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.setCapacity(-1));
  CHECK_FAILS_ASSERT(vector.trimFreeCapacity(-1));
#endif

  vector.append(1);
  vector.append(2);
  vector.append(3);
  CHECK_EQ(vector.capacity(), 4);
  CHECK_EQ(vector.freeCapacity(), 1);
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(vector.setCapacity(2));
#endif
  vector.trimFreeCapacity();
  CHECK_EQ(vector.capacity(), 3);
  vector.setCapacity(5);
  for (int i = 0; i < 3; ++i) {
    CHECK_EQ(vector[i], i + 1);
  }
  CHECK_EQ(vector.count(), 3);
  CHECK_EQ(vector.capacity(), 5);
  const auto p = vector.begin();
  vector.setCapacity(5);
  CHECK_EQ(vector.capacity(), 5);
  CHECK_EQ(vector.begin(), p);
  vector.ensureFreeCapacity(2);
  CHECK_EQ(vector.capacity(), 5);
  CHECK_EQ(vector.begin(), p);
  vector.ensureFreeCapacity(3);
  CHECK_EQ(vector.capacity(), 10);
  for (int i = 0; i < 3; ++i) {
    CHECK_EQ(vector[i], i + 1);
  }
  const auto p2 = vector.begin();
  vector.trimFreeCapacity(7);
  CHECK_EQ(vector.capacity(), 10);
  CHECK_EQ(vector.begin(), p2);
  vector.trimFreeCapacity(5);
}

TEST(EmbeddedAndExternalStorage) {
  const auto test = [&](auto& vector) {
    CHECK_EQ(vector.capacity(), 3);
    const auto* const p = vector.begin();
  #if STU_USE_ADDRESS_SANITIZER
    CHECK(__asan_address_is_poisoned(&p[0]));
    CHECK(__asan_address_is_poisoned(&p[1]));
    CHECK(__asan_address_is_poisoned(&p[2]));
  #endif

    vector.trimFreeCapacity(); // Should have no effect here.
    CHECK_EQ(vector.capacity(), 3);
    vector.setCapacity(1); // Should have no effect here.
    CHECK_EQ(vector.capacity(), 3);

    vector.append(1);
    vector.append(2);
    vector.append(3);
    CHECK_EQ(vector.capacity(), 3);
    CHECK_EQ(vector.begin(), p);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(vector[i].value, i + 1);
    }
    vector.append(4);
    CHECK_EQ(vector.capacity(), 6);
  #if STU_USE_ADDRESS_SANITIZER
    CHECK(__asan_address_is_poisoned(&p[0]));
    CHECK(__asan_address_is_poisoned(&p[1]));
    CHECK(__asan_address_is_poisoned(&p[2]));
  #endif
    for (int i = 0; i < 4; ++i) {
      CHECK_EQ(vector[i].value, i + 1);
    }

    // Check that the capacity is rounded up to an even number.
    vector.setCapacity(5);
    CHECK_EQ(vector.capacity(), 6);
    vector.trimFreeCapacity(1);
    CHECK_EQ(vector.capacity(), 6);
    vector.removeLast();
    CHECK_EQ(vector.count(), 3);
    vector.trimFreeCapacity(1);
    CHECK_EQ(vector.capacity(), 4);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(vector[i].value, i + 1);
    }

    vector.removeAll();
    vector.trimFreeCapacity();
    CHECK_EQ(vector.begin(), nullptr);
    CHECK_EQ(vector.capacity(), 0);
  };

  {
    using Alloc = MoveOnlyAllocatorRef;
    Vector<TestValueWithDestructor, 3, Alloc> vector{Alloc::create()};
    test(vector);
  }
  {
    VectorStorage<TestValueWithDestructor, 3> storage;
    Vector<TestValueWithDestructor, -1> vector{Ref{storage}};
    test(vector);
  }
  {
    using Alloc = MoveOnlyAllocatorRef;
    VectorStorage<TestValueWithDestructor, 3> storage;
    Vector<TestValueWithDestructor, -1, Alloc> vector{Ref{storage}, Alloc::create()};
    test(vector);
  }
}

TEST(MoveConstructor) {
  
  using Alloc = MoveOnlyAllocatorRef;
  {
    Vector<Int, 0, Alloc> vector{Alloc::create()};
    vector.append(1);
    vector.append(2);
    vector.append(3);
    const auto p = vector.begin();
    Vector<Int, 0, Alloc> vector2{std::move(vector)};
    CHECK_EQ(vector.begin(), nullptr);
    CHECK_EQ(vector.count(), 0);
    CHECK_EQ(vector.capacity(), 0);
    CHECK_EQ(vector2.begin(), p);
    CHECK_EQ(vector2.count(), 3);
    CHECK_EQ(vector2.capacity(), 4);
  }
  {
    Vector<Int, 3, Alloc> vector{Alloc::create()};
    const auto p = vector.begin();
    vector.append(1);
    vector.append(2);
    vector.append(3);
    Vector<Int, 5, Alloc> vector2{std::move(vector)};
    CHECK_EQ(vector.begin(), p);
    CHECK_EQ(vector.count(), 0);
    CHECK_EQ(vector.capacity(), 3);
    CHECK_EQ(vector2.count(), 3);
    CHECK_EQ(vector2.capacity(), 5);
    for (int i = 0; i < 3; ++i) {
      CHECK_EQ(vector2[i], i + 1);
    }
    vector2.append(4);
    vector2.append(5);
    vector2.append(6);
    const auto p2 = vector2.begin();
    const auto capacity = vector2.capacity();
    Vector<Int, 5, Alloc> vector3{std::move(vector2)};
    CHECK_EQ(vector2.begin(), nullptr);
    CHECK_EQ(vector2.capacity(), 0);
    CHECK_EQ(vector3.begin(), p2);
    CHECK_EQ(vector3.capacity(), capacity);
    for (int i = 0; i < 6; ++i) {
      CHECK_EQ(vector3[i], i + 1);
    }
    Vector<Int, 5, Alloc> vector4{std::move(vector2)};
  }
  {
    VectorStorage<Int, 3> externalStorage;
    Vector<Int, -1, Alloc> vector{Ref{externalStorage}, Alloc::create()};
    vector.append(-1);
    vector.append(-2);
    const auto p = vector.begin();
    Vector<Int, 1, Alloc> vector2{std::move(vector)};
    CHECK_EQ(vector2.begin(), p);
    CHECK_EQ(vector2.count(), 2);
    CHECK_EQ(vector2.capacity(), 3);
    CHECK_EQ(vector2[0], -1);
    CHECK_EQ(vector2[1], -2);
  }
}

TEST(MoveToArray) {
  // TODO: Use explicit lambda template parameter when Xcode supports that.
  auto test = [&](Int n, auto&& vector) {
    using Alloc = RemoveReference<decltype(vector.allocator())>;
    const auto* const p = vector.begin();
    for (Int i = 0; i < n; ++i) {
      vector.append(i + 1);
    }
    Array<Int, Alloc> array = std::move(vector);
    if (RemoveReference<decltype(vector)>::embeddedStorageCapacity > 0) {
      for (Int i = 0; i < n; ++i) {
      #if STU_USE_ADDRESS_SANITIZER
        CHECK(__asan_address_is_poisoned(&p[i]));
      #else
        discard(p);
      #endif
      }
    }
    Array<Int, Alloc> array2 = std::move(vector);
  };

  using AllocRef = MoveOnlyAllocatorRef;
  for (Int n = 0; n < 7; ++n) {
    test(n, Vector<Int>{});
    test(n, Vector<Int, 3>{});
    test(n, Vector<Int, 0, AllocRef>{AllocRef::create()});
    test(n, Vector<Int, 3, AllocRef>{AllocRef::create()});
  }
}

TEST_CASE_END

