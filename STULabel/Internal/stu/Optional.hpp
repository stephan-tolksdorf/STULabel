// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Assert.h"
#include "stu/InOut.hpp"
#include "stu/Utility.hpp"
#include "stu/Ref.hpp"

#include <exception>

namespace stu {

/// std::nullopt_t with a nicer name.
constexpr struct None { explicit None() = default; } none;

template <typename T>
class Optional;

namespace detail {
  template <typename T>
  struct IsOptionalImpl : False {};

  template <typename T>
  struct IsOptionalImpl<Optional<T>> : True {};
}

template <typename T>
constexpr bool isOptional = detail::IsOptionalImpl<RemoveCVReference<T>>::value;

#if !STU_NO_EXCEPTIONS
class BadOptionalAccess : public std::exception {
public:
  BadOptionalAccess() = default;

  virtual const char* what() const noexcept override;
};
#endif

namespace detail {
  template <typename T, bool = std::is_trivially_copyable<T>::value>
  class OptionalBase;

#if !STU_NO_EXCEPTIONS
  [[noreturn]]
  void throwBadOptionalAccess();
#endif

  [[noreturn]]
  STU_INLINE void badOptionalAccess() {
  #if STU_NO_EXCEPTIONS
    __builtin_trap();
  #else
    throwBadOptionalAccess();
  #endif
  }
}

template <typename T> class OptionalValueStorage;

/// Like std::optional, but has a customizable data representation (through `OptionalValueStorage`),
/// has specializations for references and doesn't allow mixed optional/non-optional inequality
/// comparisons.
template <typename T>
class Optional : private detail::OptionalBase<T> {
  static_assert(!isConst<T>);
  static_assert(isNothrowDestructible<T>);
  static_assert(!isReference<T>); // We have separate specializations for references.

  // The following static assert is meant to protect against inadvertent specializations of
  // OptionalValueStorage for primitive types, which can e.g. happen when OptionalValueStorage is
  // specialized for a typedef.
  static_assert(isDerivedFrom<OptionalValueStorage<T>, NotSpecialized>
                || isClass<T> || isEnum<T> ,
                "OptionalValueStorage<T> must not be specialized for primitive types");

public:
  static constexpr bool isSpecialized = false;

  STU_CONSTEXPR_T
  Optional() noexcept = default;

  /* implicit */ STU_CONSTEXPR_T
  Optional(const None&) noexcept {}

  template <typename U, EnableIf<isSafelyConvertible<U&&, T>> = 0>
  /* implicit */ STU_CONSTEXPR
  Optional(U&& value) noexcept(isNothrowConstructible<T, U&&>) {
    this->constructValue(std::forward<U>(value));
  }

  template <typename... Args, EnableIf<isConstructible<T, Args&&...>> = 0>
  explicit STU_CONSTEXPR
  Optional(InPlace, Args&&... args) noexcept(isNothrowConstructible<T, Args&&...>) {
    this->constructValue(std::forward<Args>(args)...);
  }

  STU_CONSTEXPR
  Optional(const Optional& other) = default;

  STU_CONSTEXPR
  Optional(Optional&& other) = default;

  template <typename U, typename R = decltype(*declval<const Optional<U>&>()),
            EnableIf<isSafelyConvertible<R, T>> = 0>
  /* implicit */ STU_CONSTEXPR
  Optional(const Optional<U>& other) noexcept(isNothrowConstructible<T, R>) {
    if (other) {
      this->constructValue(*other);
    }
  }

  template <typename U, typename R = decltype(*declval<const Optional<U>&>()),
            EnableIf<isNonSafelyConvertible<R, T>> = 0>
  explicit STU_CONSTEXPR
  Optional(const Optional<U>& other) noexcept(isNothrowConstructible<T, R>) {
    if (other) {
      this->constructValue(*other);
    }
  }

  template <typename U, typename R = decltype(*declval<Optional<U>&&>()),
            EnableIf<isSafelyConvertible<R, T>> = 0>
  /* implicit */ STU_CONSTEXPR
  Optional(Optional<U>&& other) noexcept(isNothrowConstructible<T, R>) {
    if (other) {
      this->constructValue(*std::move(other));
    }
  }

  template <typename U, typename R = decltype(*declval<Optional<U>&&>()),
            EnableIf<isNonSafelyConvertible<R, T>> = 0>
  explicit STU_CONSTEXPR
  Optional(Optional<U>&& other) noexcept(isNothrowConstructible<T, R>) {
    if (other) {
      this->constructValue(*std::move(other));
    }
  }

  STU_CONSTEXPR
  Optional& operator=(const Optional& other) = default;

  STU_CONSTEXPR
  Optional& operator=(Optional&& other) = default;

  STU_CONSTEXPR
  Optional& operator=(None) noexcept {
    if (this->hasValue()) {
      static_assert(noexcept(this->clearValue()));
      this->clearValue();
    }
    return *this;
  }

  template <typename U, EnableIf<isAssignable<T&, U&&> && isConstructible<T, U&&>> = 0>
  STU_CONSTEXPR
  Optional& operator=(U&& value)
              noexcept(isNothrowAssignable<T&, U&&> && isNothrowConstructible<T, U&&>)
  {
    if (this->hasValue()) {
      this->value() = std::forward<U>(value);
    } else {
      this->constructValue(std::forward<U>(value));
    }
    return *this;
  }

  template <typename U, typename R = decltype(*declval<const Optional<U>&>()),
            EnableIf<isAssignable<T&, R> && isConstructible<T, R>> = 0>
  STU_CONSTEXPR
  Optional& operator=(const Optional<U>& other)
              noexcept(isNothrowAssignable<T&, R> && isNothrowConstructible<T, R>)
  {
    if (other) {
      *this = *other;
    } else {
      *this = none;
    }
    return *this;
  }

  template <typename U, typename R = decltype(*declval<Optional<U>&&>()),
            EnableIf<isAssignable<T&, R> && isConstructible<T, R>> = 0>
  STU_CONSTEXPR
  Optional& operator=(Optional<U>&& other)
              noexcept(isNothrowAssignable<T&, R> && isNothrowConstructible<T, R>)
  {
    if (other) {
      *this = std::move(*other);
    } else {
      *this = none;
    }
    return *this;
  }

  explicit STU_CONSTEXPR
  operator bool() const noexcept {
    static_assert(noexcept(this->hasValue()));
    return this->hasValue();
  }

  STU_CONSTEXPR
  const T& operator*() const & noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return this->value();
  }

  STU_CONSTEXPR
  T& operator*() & noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return this->value();
  }

  STU_CONSTEXPR
  const T&& operator*() const && noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return static_cast<const T&&>(this->value());
  }

  STU_CONSTEXPR
  T&& operator*() && noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return static_cast<T&&>(this->value());
  }

  STU_CONSTEXPR
  const T* operator->() const noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return &this->value();
  }

  STU_CONSTEXPR
  T* operator->() noexcept(!STU_ASSERT_MAY_THROW) {
    assertHasValue();
    return &this->value();
  }

  template <typename U>
  STU_CONSTEXPR
  T value_or(U&& fallbackValue) const & {
    return *this ? **this : std::forward<U>(fallbackValue);
  }

  template <typename U>
  STU_CONSTEXPR
  T value_or(U&& fallbackValue) && {
    return *this ? *std::move(*this) : std::forward<U>(fallbackValue);
  }

  STU_CONSTEXPR
  const OptionalValueStorage<T>& storage() const {
    return *this;
  }

  // For micro-optimization purposes (USE WITH CARE)
  STU_CONSTEXPR
  const T& assumeNotNone() const & noexcept {
    const bool hasValue{*this};
    STU_ASSUME(hasValue);
    discard(hasValue);
    return this->value();
  }
  STU_CONSTEXPR
  T& assumeNotNone() & noexcept {
    const bool hasValue{*this};
    STU_ASSUME(hasValue);
    discard(hasValue);
    return this->value();
  }
  STU_CONSTEXPR
  const T&& assumeNotNone() const && noexcept {
    const bool hasValue{*this};
    STU_ASSUME(hasValue);
    discard(hasValue);
    return static_cast<const T&&>(this->value());
  }
  STU_CONSTEXPR
  T&& assumeNotNone() && noexcept {
    const bool hasValue{*this};
    STU_ASSUME(hasValue);
    discard(hasValue);
    return static_cast<T&&>(this->value());
  }

private:
  STU_CONSTEXPR void assertHasValue() const {
    static_assert(noexcept(this->hasValue()));
    if (STU_UNLIKELY(!this->hasValue())) {
      detail::badOptionalAccess();
    }
  }
public:

  template <typename... Args, EnableIf<isConstructible<T, Args&&...>> = 0>
  STU_CONSTEXPR
  T& emplace(Args&&... args) {
    *this = none;
    this->constructValue(std::forward<Args>(args)...);
    return this->value();
  }

  STU_CONSTEXPR
  friend bool operator==(const Optional<T>& lhs, const None&) noexcept { return  !lhs; }
  STU_CONSTEXPR
  friend bool operator!=(const Optional<T>& lhs, const None&) noexcept { return !!lhs; }
  STU_CONSTEXPR
  friend bool operator==(const None&, const Optional<T>& rhs) noexcept { return  !rhs; }
  STU_CONSTEXPR
  friend bool operator!=(const None&, const Optional<T>& rhs) noexcept { return !!rhs; }

  template <typename U, EnableIf<!isOptional<U> && isEqualityComparable<T, U>> = 0>
  STU_CONSTEXPR
  friend bool operator==(const Optional& lhs, const U& rhs)
                noexcept(isNothrowEqualityComparable<T, U>)
  {
    return !!lhs && *lhs == rhs;
  }

  template <typename U, EnableIf<!isOptional<U> && isEqualityComparable<T, U>> = 0>
  STU_CONSTEXPR
  friend bool operator!=(const Optional& lhs, const U& rhs)
                noexcept(isNothrowEqualityComparable<T, U>)
  {
    return !(lhs == rhs);
  }

  template <typename U, EnableIf<!isOptional<U> && isEqualityComparable<U, T>> = 0>
  STU_CONSTEXPR
  friend bool operator==(const U& lhs, const Optional& rhs)
                noexcept(isNothrowEqualityComparable<U, T>)
  {
    return !!rhs && lhs == *rhs;
  }
  template <typename U, EnableIf<!isOptional<U> && isEqualityComparable<U, T>> = 0>
  STU_CONSTEXPR
  friend bool operator!=(const U& lhs, const Optional& rhs)
                noexcept(isNothrowEqualityComparable<U, T>)
  {
    return !(lhs == rhs);
  }

  template <typename U, EnableIf<isEqualityComparable<T, U> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  friend bool operator==(const Optional& lhs, const Optional<U>& rhs)
                noexcept(isNothrowEqualityComparable<T, U>)
  {
    return !!lhs == !!rhs && (!lhs || *lhs == *rhs);
  }
  template <typename U, EnableIf<isEqualityComparable<T, U> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  friend bool operator!=(const Optional& lhs, const Optional<U>& rhs)
                noexcept(isNothrowEqualityComparable<T, U>)
  {
    return !(lhs == rhs);
  }

  template <typename U, EnableIf<isLessThanComparable<T, U> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  bool operator<(const Optional<U>& other) noexcept(isNothrowLessThanComparable<T, U>) {
    return !!other && (!*this || **this < *other);
  }
  template <typename U, EnableIf<isLessThanComparable<U, T> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  bool operator>(const Optional<U>& other) noexcept(isNothrowLessThanComparable<U, T>) {
    return other < *this;
  }
  template <typename U, EnableIf<isLessThanComparable<U, T> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  bool operator<=(const Optional<U>& other) noexcept(isNothrowLessThanComparable<U, T>) {
    return !(other < *this);
  }
  template <typename U, EnableIf<isLessThanComparable<T, U> && !Optional<U>::isSpecialized> = 0>
  STU_CONSTEXPR
  bool operator>=(const Optional<U>& other) noexcept(isNothrowLessThanComparable<T, U>) {
    return !(*this < other);
  }

  // We don't allow mixed optional and non-optional <, >, <=, >= comparisons.

  template <typename U> bool operator< (const U& other) = delete;
  template <typename U> bool operator> (const U& other) = delete;
  template <typename U> bool operator<=(const U& other) = delete;
  template <typename U> bool operator>=(const U& other) = delete;
};

template <typename T>
struct IsBitwiseCopyable<Optional<T>> : IsBitwiseCopyable<T> {};

template <typename T>
struct IsBitwiseMovable<Optional<T>> : IsBitwiseMovable<T> {};

template <typename T>
struct IsBitwiseZeroConstructible<Optional<T>>
   : BoolConstant<isBitwiseZeroConstructible<T>
                  && std::is_base_of_v<NotSpecialized, Optional<T>>> {};

template <typename T>
class Optional<T&> {
  T* __unsafe_unretained pointer_{};
public:
  using Value = T;

  STU_CONSTEXPR_T
  Optional() noexcept = default;

  /* implicit */ STU_CONSTEXPR_T
  Optional(const None&) noexcept {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(T& value) noexcept : pointer_(&value) {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(Ref<T> ref) noexcept : pointer_(ref.pointer()) {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(T* pointer) noexcept : pointer_(pointer) {}

  STU_CONSTEXPR_T
  Optional(const Optional& other) noexcept = default;

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Optional(const Optional<U&>& other) noexcept
  : pointer_(static_cast<U*>(other)) {}

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Optional(const Optional<Ref<U>>& other) noexcept
  : pointer_(static_cast<U*>(other)) {}

  template <typename U, EnableIf<isConst<T> && isConvertible<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR
  Optional(const Optional<U>& other) noexcept
  : pointer_(other ? &*other : nullptr) {}

  template <typename U, EnableIf<!isConst<T> && isConvertible<U*, T*>> = 0>
  explicit STU_CONSTEXPR
  Optional(const Optional<U>& other) noexcept
  : pointer_(other ? &*other : nullptr) {}


  STU_CONSTEXPR_T
  Optional& operator=(None) noexcept {
    pointer_ = nullptr;
    return *this;
  }

  STU_CONSTEXPR_T
  Optional& operator=(const Optional& other) noexcept = default;

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Optional& operator=(U* other) noexcept {
    pointer_ = other;
    return *this;
  }

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Optional& operator=(const Optional<U&>& other) noexcept {
    pointer_ = static_cast<U*>(other);
    return *this;
  }

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Optional& operator=(const Optional<Ref<U>>& other) noexcept {
    pointer_ = static_cast<U*>(other);
    return *this;
  }

  // Disable all other (converting) assignments.
  template <typename Other>
  Optional& operator=(const Other&) = delete;

  explicit STU_CONSTEXPR_T
  operator bool() const noexcept { return pointer_; }

  explicit STU_CONSTEXPR_T
  operator T*() const { return pointer_; }

  STU_CONSTEXPR_T
  T& operator*() const noexcept(!STU_ASSERT_MAY_THROW) { return *pointer_; }

  STU_CONSTEXPR_T
  T* operator->() const noexcept(!STU_ASSERT_MAY_THROW) { return pointer_; }

  STU_CONSTEXPR_T
  T& assumeNotNone() const noexcept {
    STU_ASSUME(!!pointer_);
    return *pointer_;
  }

  template <typename U, EnableIf<isConvertible<U&&, T&>> = 0>
  STU_CONSTEXPR
  T& emplace(U&& arg) {
    pointer_ = &implicit_cast<T&>(std::forward<U>(arg));
    return *pointer_;
  }

  // For optional references we only define comparisons with none.

  STU_CONSTEXPR_T friend bool operator==(Optional lhs, None) noexcept { return  !lhs; }
  STU_CONSTEXPR_T friend bool operator!=(Optional lhs, None) noexcept { return !!lhs; }
  STU_CONSTEXPR_T friend bool operator==(None, Optional rhs) noexcept { return  !rhs; }
  STU_CONSTEXPR_T friend bool operator!=(None, Optional rhs) noexcept { return !!rhs; }
};

template <typename T>
class Optional<T&&> {
  static_assert(!isSame<T, T>, "Optional rvalue references are not supported.");
};

template <typename T>
class Optional<Ref<T>> {
  T* pointer_{};
public:
  using Value = T;

  STU_CONSTEXPR_T
  Optional() noexcept = default;

  /* implicit */ STU_CONSTEXPR_T
  Optional(const None&) noexcept {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(Ref<T> ref) noexcept : pointer_(ref.pointer()) {}

  explicit STU_CONSTEXPR_T
  Optional(T* pointer) noexcept : pointer_(pointer) {}

  STU_CONSTEXPR_T
  Optional(const Optional& other) noexcept = default;

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Optional(const Optional<Ref<U>>& other) noexcept
  : pointer_(static_cast<U*>(other)) {}

  STU_CONSTEXPR_T
  Optional& operator=(None) noexcept {
    pointer_ = nullptr;
  }

  STU_CONSTEXPR_T
  Optional& operator=(const Optional& other) noexcept = default;

  template <typename U, EnableIf<isConvertible<U*, T*>> = 0>
  STU_CONSTEXPR_T
  Optional& operator=(const Optional<Ref<U>>& other) noexcept
  {
    pointer_ = static_cast<U*>(other);
    return *this;
  }

  // Ref<T>'s constructor is explicit, so there's no need to disable certain
  // assignments like in Optional<T&>.

  explicit STU_CONSTEXPR_T
  operator bool() const { return pointer_; }

  explicit STU_CONSTEXPR_T
  operator T*() const { return pointer_; }

  STU_CONSTEXPR_T
  T& operator*() const noexcept(!STU_ASSERT_MAY_THROW) { return *pointer_; }

  STU_CONSTEXPR_T
  T* operator->() const noexcept(!STU_ASSERT_MAY_THROW) { return pointer_; }

  STU_CONSTEXPR_T
  T& assumeNotNone() const noexcept {
    STU_ASSUME(!!pointer_);
    return *pointer_;
  }

  template <typename U, EnableIf<isConstructible<Ref<T>, U&&>> = 0>
  STU_CONSTEXPR
  T& emplace(U&& arg) {
    pointer_ = Ref<T>(std::forward<U>(arg)).pointer();
    return *pointer_;
  }

  // For optional references we only define comparisons with none.

  STU_CONSTEXPR_T friend bool operator==(Optional lhs, None) noexcept { return  !lhs; }
  STU_CONSTEXPR_T friend bool operator!=(Optional lhs, None) noexcept { return !!lhs; }
  STU_CONSTEXPR_T friend bool operator==(None, Optional rhs) noexcept { return  !rhs; }
  STU_CONSTEXPR_T friend bool operator!=(None, Optional rhs) noexcept { return !!rhs; }
};

template <typename T>
class Optional<Out<T>> {
  T* pointer_{};
public:
  using Value = T;

  STU_CONSTEXPR_T
  Optional() noexcept = default;

  /* implicit */ STU_CONSTEXPR_T
  Optional(const None&) noexcept {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(Out<T> out) noexcept : pointer_(&out.get()) {}

  STU_CONSTEXPR_T Optional(const Optional& other) noexcept = default;
  STU_CONSTEXPR_T Optional& operator=(const Optional& other) noexcept = default;

  STU_CONSTEXPR_T
  Optional& operator=(None) noexcept {
    pointer_ = nullptr;
    return *this;
  }

  explicit STU_CONSTEXPR_T
  operator bool() const noexcept { return pointer_; }

  explicit STU_CONSTEXPR_T
  operator T*() const noexcept { return pointer_; }

  STU_CONSTEXPR_T
  T& operator*() const noexcept(!STU_ASSERT_MAY_THROW) { return *pointer_; }

  STU_CONSTEXPR_T
  T* operator->() const noexcept(!STU_ASSERT_MAY_THROW) { return pointer_; }

  STU_CONSTEXPR_T
  T& assumeNotNone() const noexcept {
    STU_ASSUME(!!pointer_);
    return *pointer_;
  }

  template <typename U, EnableIf<isConstructible<Out<T>, U&&>> = 0>
  STU_CONSTEXPR_T
  T& emplace(U&& arg) {
    pointer_ = &Out<T>(std::forward<U>(arg)).get();
    return *pointer_;
  }

  // For optional references we only define comparisons with none.

  STU_CONSTEXPR_T friend bool operator==(Optional lhs, None) noexcept { return  !lhs; }
  STU_CONSTEXPR_T friend bool operator!=(Optional lhs, None) noexcept { return !!lhs; }
  STU_CONSTEXPR_T friend bool operator==(None, Optional rhs) noexcept { return  !rhs; }
  STU_CONSTEXPR_T friend bool operator!=(None, Optional rhs) noexcept { return !!rhs; }
};


namespace detail {
  template <typename T, bool = isTriviallyDestructible<T>>
  struct OptionalValueStorageBase;
}

/// Used by Optional<T> to store the optional T instance.
///
/// Can be specialized to provide an implementation that has a more compact data representation
/// than the default implementation, e.g. when a particular value can be reserved to represent
/// the empty optional.
///
/// If T is not trivially copyable, the `Optional<T>` does not use the copy & move contructors and
/// assignment operators of OptionalValueStorage<T>.
template <typename T>
class OptionalValueStorage : public NotSpecialized, private detail::OptionalValueStorageBase<T> {
  using Base = detail::OptionalValueStorageBase<T>;
  using Base::value_;
  using Base::hasValue_;

public:
  /// \post !hasValue()
  STU_CONSTEXPR OptionalValueStorage() noexcept = default;

  STU_CONSTEXPR bool hasValue() const noexcept { return hasValue_; }

  // Instead of defining the following two members, a specialization can also make a data member of
  // type T with the name 'value_' public.

  /// \pre hasValue()
  STU_CONSTEXPR const T& value() const noexcept { return this->value_; }
  /// \pre hasValue()
  STU_CONSTEXPR       T& value()       noexcept { return this->value_; }

  /// Constructs the value with the specified args.
  ///
  /// \pre  !hasValue()
  /// \post  hasValue()
  template <typename... Args>
  STU_CONSTEXPR
  void constructValue(Args&&... args) noexcept(isNothrowConstructible<T, Args&&...>) {
    new (&this->value_) T(std::forward<Args>(args)...);
    this->hasValue_ = true;
  }

  /// \pre   hasValue()
  /// \post !hasValue()
  STU_CONSTEXPR
  void clearValue() noexcept {
    static_assert(isNothrowDestructible<T>);
    value_.~T();
    hasValue_ = false;
  }
};

namespace detail {

template <typename T, bool /* = isTriviallyDestructible<T> */ >
struct OptionalValueStorageBase {
  union {
    Byte dummy_;
    T value_;
  };
  bool hasValue_;

  STU_CONSTEXPR OptionalValueStorageBase() noexcept : dummy_{}, hasValue_{false} {}
};

template <typename T>
struct OptionalValueStorageBase<T, false> {
  union {
    Byte dummy_;
    T value_;
  };
  bool hasValue_;

  STU_INLINE OptionalValueStorageBase() noexcept : dummy_{}, hasValue_{false} {}

  STU_INLINE
  ~OptionalValueStorageBase() {
    if (hasValue_) {
      value_.~T();
    }
  }
};

template <typename T>
using DecltypeValueGetter = decltype(declval<T&>().value());

template <typename T, bool = canApply<DecltypeValueGetter, OptionalValueStorage<T>>>
class OptionalValueStorageWithValueGetters           : public OptionalValueStorage<T> {};
template <typename T>
class OptionalValueStorageWithValueGetters<T, false> : public OptionalValueStorage<T> {
public:
  // The OptionalValueStorage<T> specialization doesn't define a value() function,
  // so we assume it makes a `T value_` field accessible.
  STU_CONSTEXPR const T& value() const { return this->value_; }
  STU_CONSTEXPR       T& value()       { return this->value_; }
};

template <typename T, bool /* = std::is_trivially_copyable<T> */>
class OptionalBase           : public OptionalValueStorageWithValueGetters<T> {};
template <typename T>
class OptionalBase<T, false> : public OptionalValueStorageWithValueGetters<T> {
public:
  STU_CONSTEXPR
  OptionalBase() noexcept = default;

  STU_CONSTEXPR
  OptionalBase(const OptionalBase& other) noexcept(isNothrowCopyConstructible<T>) {
    if (other.hasValue()) {
      this->constructValue(other.value());
    }
  }

  STU_CONSTEXPR
  OptionalBase(OptionalBase&& other) noexcept(isNothrowMoveConstructible<T>) {
    if (other.hasValue()) {
      this->constructValue(std::move(other.value()));
    }
  }

  STU_CONSTEXPR
  OptionalBase& operator=(const OptionalBase& other)
    noexcept(isNothrowCopyAssignable<T> && isNothrowCopyConstructible<T>)
  {
    if (other.hasValue()) {
      if (!this->hasValue()) {
        this->constructValue(other.value());
      } else {
        this->value() = other.value();
      }
    }
    return *this;
  }

  STU_CONSTEXPR
  OptionalBase& operator=(OptionalBase&& other) noexcept(isNothrowMoveConstructible<T>) {
    if (this->hasValue()) {
      static_assert(noexcept(this->clearValue()));
      this->clearValue();
    }
    if (other.hasValue()) {
      this->constructValue(std::move(other.value()));
    }
    return *this;
  }
};

} // namespace detail

} // namespace stu
