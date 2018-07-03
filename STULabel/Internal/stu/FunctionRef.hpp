// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Optional.hpp"

namespace stu {

template <typename Signature>
class FunctionRef;

namespace detail {
  template <typename Signature> struct FunctionRefBase;

  template <typename T> struct FunctionRefSignatureImpl { using Type = NoType; };
  template <typename S> struct FunctionRefSignatureImpl<         FunctionRef<S>> { using Type = S;};
  template <typename S> struct FunctionRefSignatureImpl<Optional<FunctionRef<S>>>{ using Type = S;};
  template <typename T>
  using FunctionRefSignature = typename FunctionRefSignatureImpl<RemoveCVReference<T>>::Type;
}

template <typename T, typename Signature>
constexpr bool isFunctionRef = isConvertible<detail::FunctionRefSignature<T>, Signature*>;

template <typename Signature>
class Optional<FunctionRef<Signature>>
      : private detail::FunctionRefBase<Signature>
{
  using Base = detail::FunctionRefBase<Signature>;
  using Base::callable_;
  using Base::forwarder_;
  template <typename> friend class FunctionRef;
  template <typename> friend class Optional;

public:
  STU_CONSTEXPR_T
  Optional() noexcept
  : Base{nullptr, Base::nullFunctionCall} {}

  /* implicit */ STU_CONSTEXPR_T
  Optional(None) noexcept
  : Optional{} {}

  template <typename Callable,
            EnableIf<isCallable<Callable&&, Signature>
                     && !isSame<RemoveCVReference<Callable>, Optional>> = 0>
  /* implicit */ STU_CONSTEXPR
  Optional(Callable&& callable) noexcept {
    if constexpr (isFunctionRef<Callable, Signature>) {
      callable_ = callable.callable_;
      forwarder_ = callable.forwarder_;
    } else {
      using C = RemoveReference<Callable>;
      using F = Conditional<std::is_function_v<C>, C*, C>;
      if constexpr (!isPointer<F>) {
        callable_ = const_cast<void*>(implicit_cast<const void*>(&callable));
        forwarder_ = &Base::template call<F>;
      } else { // callable is a function pointer
        callable_ = const_cast<void*>(reinterpret_cast<const void*>(callable));
        forwarder_ = callable ? &Base::template call<F> : Base::nullFunctionCall;
      }
    }
    STU_ASSUME(callable_ != nullptr);
  }

  STU_CONSTEXPR_T Optional(const Optional&) noexcept = default;
  STU_CONSTEXPR_T Optional& operator=(const Optional&) noexcept = default;

  STU_CONSTEXPR_T
  Optional& operator=(None) noexcept {
    this->callable_ = nullptr;
    this->forwarder_ = Base::nullFunctionCall;
    return *this;
  }

  // Prevents some unsafe assignments.
  template <typename Other,
            EnableIf<!isFunctionRef<Other, Signature>
                     && !std::is_function_v<RemovePointer<RemoveReference<Other>>>> = 0>
  Optional& operator=(Other&& other) = delete;

  STU_CONSTEXPR_T
  explicit operator bool() const noexcept {
    return this->callable_ != nullptr;
  }

  STU_CONSTEXPR
  FunctionRef<Signature> operator*() const noexcept(!STU_ASSERT_MAY_THROW) {
    if (STU_UNLIKELY(!*this)) detail::badOptionalAccess();
    return FunctionRef<Signature>{*this};
  }

  using Base::operator();

  // For optional references we only define comparisons with none.

  STU_CONSTEXPR_T friend bool operator==(Optional lhs, None) noexcept { return  !lhs; }
  STU_CONSTEXPR_T friend bool operator!=(Optional lhs, None) noexcept { return !!lhs; }
  STU_CONSTEXPR_T friend bool operator==(None, Optional rhs) noexcept { return  !rhs; }
  STU_CONSTEXPR_T friend bool operator!=(None, Optional rhs) noexcept { return !!rhs; }
};

/// A non-owning reference to a function.
template <typename Signature>
class FunctionRef
      : private detail::FunctionRefBase<Signature>
{
  using Base = detail::FunctionRefBase<Signature>;
  using Base::callable_;
  using Base::forwarder_;
public:

  template <typename Callable,
            EnableIf<isCallable<Callable&&, Signature>
                     && !isSame<RemoveCVReference<Callable>, FunctionRef>
                     && !isPointer<RemoveReference<Callable>>
                     && !isOptional<Callable>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  FunctionRef(Callable&& callable) noexcept
  : FunctionRef{Optional<FunctionRef<Signature>>{std::forward<Callable>(callable)}, unchecked}
  {}

  template <typename Function,
            EnableIf<isCallable<Function*, Signature>> = 0>
  explicit STU_CONSTEXPR
  FunctionRef(Function* callable) noexcept(!STU_ASSERT_MAY_THROW)
  : FunctionRef{Optional<FunctionRef<Signature>>{callable}}
  {}

  explicit STU_CONSTEXPR
  FunctionRef(Optional<FunctionRef<Signature>> other) noexcept(!STU_ASSERT_MAY_THROW)
  : FunctionRef{other, unchecked}
  {
    STU_PRECONDITION(callable_ != nullptr);
  }
private:
  STU_CONSTEXPR
  FunctionRef(Optional<FunctionRef<Signature>> other, Unchecked) noexcept {
    callable_ = other.callable_;
    forwarder_ = other.forwarder_;
  }
public:

  STU_CONSTEXPR_T FunctionRef(const FunctionRef&) noexcept = default;
  STU_CONSTEXPR_T FunctionRef& operator=(const FunctionRef&) noexcept = default;

  // Prevents some unsafe assignments.
  template <typename Other,
            EnableIf<!isFunctionRef<Other, Signature>
                     && !std::is_function_v<RemovePointer<RemoveReference<Other>>>> = 0>
  FunctionRef& operator=(Other&& other) = delete;

  using Base::operator();

private:
  template <typename> friend class FunctionRef;
  template <typename> friend class Optional;
};

template <typename Callable, typename Signature = CallableSignature<Callable>>
FunctionRef(Callable&&) -> FunctionRef<Signature>;

namespace detail {
  template <typename ReturnValue, typename... Args>
  struct FunctionRefBase<ReturnValue(Args...) noexcept> {
    using Signature = ReturnValue(Args...) noexcept;

    STU_CONSTEXPR ReturnValue operator()(Args... args) const noexcept {
      return forwarder_(callable_, std::forward<Args>(args)...);
    }

    template <typename Callable>
    static ReturnValue call(void* p, Args... args) noexcept {
      if constexpr (isPointer<Callable>) {
        static_assert(std::is_function_v<RemovePointer<Callable>>);
        return reinterpret_cast<Callable>(p)(std::forward<Args>(args)...);
      } else {
        return static_cast<Callable&&>(*(down_cast<AddPointer<Callable>>(p)))
               (std::forward<Args>(args)...);
      }
    }

    static ReturnValue nullFunctionCall(void* null __unused, Args... args __unused) noexcept {
      __builtin_trap();
    }

    using ForwarderFunction = ReturnValue(void* p, Args... args) noexcept;

    void* callable_;
    ForwarderFunction* forwarder_;
  };

  template <typename ReturnValue, typename... Args>
  struct FunctionRefBase<ReturnValue(Args...)> {
    using Signature = ReturnValue(Args...);

    STU_CONSTEXPR
    ReturnValue operator()(Args... args) const {
      return forwarder_(callable_, std::forward<Args>(args)...);
    }

    template <typename Callable>
    STU_CONSTEXPR
    static ReturnValue call(void* p, Args... args) {
      if constexpr (isPointer<Callable>) {
        static_assert(std::is_function_v<RemovePointer<Callable>>);
        return reinterpret_cast<Callable>(p)(std::forward<Args>(args)...);
      } else {
        return static_cast<Callable&&>(*(down_cast<AddPointer<Callable>>(p)))
               (std::forward<Args>(args)...);
      }
    }

    static ReturnValue nullFunctionCall(void* null __unused, Args... args __unused) {
    #if STU_NO_EXCEPTIONS
      __builtin_trap();
    #else
      throw std::bad_function_call();
    #endif
    }

    using ForwarderFunction = ReturnValue(void* p, Args... args);

    void* callable_;
    ForwarderFunction* forwarder_;
  };
}

} // namespace stu
