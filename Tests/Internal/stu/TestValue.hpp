// Copyright 2018 Stephan Tolksdorf

#pragma once

#include "stu/ArrayRef.hpp"
#include "stu/Comparable.hpp"

#include <exception>
#include <unordered_set>

using Int = stu::Int;

class TestValueCopyException : std::exception {
public:
  TestValueCopyException() {}
};

enum class TestValueState {
  destroyed = - 1,
  uninitialized = 0,
  defaultConstructed,
  constructedFromInt,
  copyConstructed,
  copyConstructedFromValueB,
  moveConstructed,
  moveConstructedFromValueB,
  assignedFromInt,
  copyAssigned,
  copyAssignedFromValueB,
  moveAssigned,
  moveAssignedFromValueB,
  movedFrom,
};

class TestValueB : public stu::Comparable<TestValueB> {
public:
  using State = TestValueState;

  int value;
  State state;
  bool throwOnCopy{false};

  static std::unordered_set<const TestValueB*> addresses;

  static Int liveValueCount() {
    return static_cast<Int>(addresses.size());
  }

private:
  static void addAddress(const TestValueB* p) {
    const auto pair = addresses.insert(p);
    if (!pair.second) { // a value already exists at this address
      __builtin_trap();
    }
  }

  static void removeAddress(const TestValueB* p) {
    const auto n = addresses.erase(p);
    if (n != 1) {
      __builtin_trap();
    }
  }

public:
  bool isInitialized() const noexcept {
    return (int)state > 0 && addresses.count(this) == 1;
  }

  TestValueB() noexcept {
    addAddress(this);
    value = 0;
    state = State::defaultConstructed;
  }

  ~TestValueB()  {
    if (!isInitialized()) {
      __builtin_trap();
    }
    removeAddress(this);
    this->value = INT32_MIN;
    state = State::destroyed;
  }

  TestValueB(int value) noexcept {
    addAddress(this);
    this->value = value;
    state = State::constructedFromInt;
  }

  TestValueB(TestValueB&& other) noexcept {
    addAddress(this);
    this->value = other.value;
    state = State::moveConstructed;
    other.value = 0;
    other.state = State::movedFrom;
  }

  TestValueB& operator=(TestValueB&& other) {
    if (!isInitialized()) {
      __builtin_trap();
    }
    this->value = other.value;
    state = State::moveAssigned;
    other.value = 0;
    other.state = State::movedFrom;
    return *this;
  }

  bool operator==(const TestValueB& other) const noexcept {
    return value == other.value;
  }

  bool operator<(const TestValueB& other) const noexcept {
    return value < other.value;
  }
};

inline bool operator==(stu::ArrayRef<const TestValueB> array1,
                       stu::ArrayRef<const int> array2) noexcept
{
  if (array1.count() != array2.count()) return false;
  for (Int i = 0; i < array1.count(); ++i) {
    if (array1[i].value != array2[i]) return false;
  }
  return true;
}

inline bool operator==(stu::ArrayRef<const int> array1,
                       stu::ArrayRef<const TestValueB> array2) noexcept
{
  return array2 == array1;
}

class TestValue : public stu::Comparable<TestValue> {
public:
  using State = TestValueState;

  int value;
  State state;
  bool throwOnCopy{false};

  static std::unordered_set<const TestValue*> addresses;

  static Int liveValueCount() {
    return static_cast<Int>(addresses.size());
  }

private:
  static void addAddress(const TestValue* p) {
    const auto pair = addresses.insert(p);
    if (!pair.second) { // a value already exists at this address
      __builtin_trap();
    }
  }

  static void removeAddress(const TestValue* p) {
    const auto n = addresses.erase(p);
    if (n != 1) {
      __builtin_trap();
    }
  }

public:
  bool isInitialized() const noexcept {
    return (int)state > 0 && addresses.count(this) == 1;
  }

  TestValue() noexcept {
    addAddress(this);
    value = 0;
    state = State::defaultConstructed;
  }

  ~TestValue()  {
    if (!isInitialized()) {
      __builtin_trap();
    }
    removeAddress(this);
    this->value = INT32_MIN;
    state = State::destroyed;
  }

  TestValue(int value) noexcept {
    addAddress(this);
    this->value = value;
    state = State::constructedFromInt;
  }

  TestValue(const TestValue& other) {
    if (other.throwOnCopy) {
    #ifdef __cpp_exceptions
      throw TestValueCopyException();
    #else
      __builtin_trap();
    #endif
    }
    addAddress(this);
    this->value = other.value;
    state = State::copyConstructed;
  }

  TestValue(const TestValueB& other) {
    if (other.throwOnCopy) {
    #ifdef __cpp_exceptions
      throw TestValueCopyException();
    #else
      __builtin_trap();
    #endif

    }
    addAddress(this);
    this->value = other.value;
    state = State::copyConstructedFromValueB;
  }

  TestValue(TestValue&& other) noexcept {
    addAddress(this);
    this->value = other.value;
    state = State::moveConstructed;
    other.value = 0;
    other.state = State::movedFrom;
  }

  TestValue(TestValueB&& other) noexcept {
    addAddress(this);
    this->value = other.value;
    state = State::moveConstructedFromValueB;
    other.value = 0;
    other.state = State::movedFrom;
  }

  TestValue& operator=(int other) noexcept {
    if (!isInitialized()) {
      __builtin_trap();
    }
    value = other;
    state = State::assignedFromInt;
    return *this;
  }

  TestValue& operator=(const TestValue& other) {
    if (other.throwOnCopy) {
    #ifdef __cpp_exceptions
      throw TestValueCopyException();
    #else
      __builtin_trap();
    #endif

    }
    if (!isInitialized()) {
      __builtin_trap();
    }
    this->value = other.value;
    state = State::copyAssigned;
    return *this;
  }

  TestValue& operator=(const TestValueB& other) {
    if (other.throwOnCopy) {
    #ifdef __cpp_exceptions
      throw TestValueCopyException();
    #else
      __builtin_trap();
    #endif
    }
    if (!isInitialized()) {
      __builtin_trap();
    }
    this->value = other.value;
    state = State::copyAssignedFromValueB;
    return *this;
  }

  TestValue& operator=(TestValue&& other) noexcept {
    if (!isInitialized()) {
      __builtin_trap();
    }
    this->value = other.value;
    state = State::moveAssigned;
    other.value = 0;
    other.state = State::movedFrom;
    return *this;
  }

  TestValue& operator=(TestValueB&& other) noexcept {
    if (!isInitialized()) {
      __builtin_trap();
    }
    this->value = other.value;
    state = State::moveAssignedFromValueB;
    other.value = 0;
    other.state = State::movedFrom;
    return *this;
  }

  bool operator==(const TestValue& other) const noexcept {
    return value == other.value;
  }

  bool operator<(const TestValue& other) const noexcept {
    return value < other.value;
  }
};

inline bool operator==(stu::ArrayRef<const TestValue> array1,
                       stu::ArrayRef<const int> array2) noexcept
{
  if (array1.count() != array2.count()) return false;
  for (Int i = 0; i < array1.count(); ++i) {
    if (array1[i].value != array2[i]) return false;
  }
  return true;
}

inline bool operator==(stu::ArrayRef<const int> array1,
                       stu::ArrayRef<const TestValue> array2) noexcept
{
  return array2 == array1;
}

