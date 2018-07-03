// Copyright 2018 Stephan Tolksdorf

#include "stu/FunctionRef.hpp"

#include "TestUtils.hpp"

using namespace stu;

TEST_CASE_START(FunctionRefTests)

static Int add3(Int value) {
  return value + 3;
}

static Int add4_noexcept(Int value) noexcept {
  return value + 4;
}

class Add {
  Int addend_;
public:
  explicit Add(Int addend)
  : addend_{addend} {}

  Int operator()(Int value) const noexcept { return addend_ + value; }
};

TEST(Basics) {
  static_assert(!isDefaultConstructible<FunctionRef<Int(Int)>>);
  {
    FunctionRef<Int(Int)> f = add3;
    static_assert(!noexcept(f(1)));
    CHECK_EQ(f(2), 5);
    f = add4_noexcept;
    CHECK_EQ(f(2), 6);
    static_assert(!isAssignable<FunctionRef<Int(Int)>&, Add>);
  }
  {
    const FunctionRef<Int(Int) noexcept> f = add4_noexcept;
    static_assert(noexcept(f(1)));
    CHECK_EQ(f(2), 6);
    static_assert(!isAssignable<FunctionRef<Int(Int) noexcept>&, FunctionRef<Int(Int)>>);
  }
  {
    static_assert(isSame<decltype(FunctionRef{Add{5}}), FunctionRef<Int(Int) noexcept>>);
    const auto result = FunctionRef{Add{5}}(-1);
    CHECK_EQ(result, 4);
  }
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(FunctionRef<void()>{static_cast<void(*)()>(nullptr)});
#endif
}

TEST(OptionalFunctionrRef) {
  Optional<FunctionRef<Int(Int)>> opt;
  CHECK(!opt);
  CHECK(opt == none);
  CHECK(!(opt != none));
  CHECK(none == opt);
  CHECK(!(none != opt));
  opt = add3;
  CHECK_EQ(opt(1), 4);
  CHECK_EQ(FunctionRef<Int(Int)>(opt)(2), 5);
  opt = none;
#if !STU_NO_EXCEPTIONS
  CHECK_THROWS(*opt, stu::BadOptionalAccess);
  CHECK_THROWS(opt(1), std::bad_function_call);
#endif
#if STU_ASSERT_MAY_THROW
  CHECK_FAILS_ASSERT(FunctionRef<Int(Int)>(opt));
#endif
}

TEST_CASE_END
