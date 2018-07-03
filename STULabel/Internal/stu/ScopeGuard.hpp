// Copyright 2017 Stephan Tolksdorf

#pragma once

#include "stu/TypeTraits.hpp"

namespace stu {

template <typename ScopeExitHandler, bool enable = true>
class STU_APPEARS_UNUSED ScopeGuard {
public:
  STU_INLINE_T
  explicit ScopeGuard(ScopeExitHandler&& handler)
  : handler_(std::move(handler)), dismissed_(false) {}

  ScopeGuard(const ScopeGuard&) = delete;
  ScopeGuard& operator=(const ScopeGuard&) = delete;

  STU_INLINE
  ~ScopeGuard() {
    if (!dismissed_) handler_();
  }

  STU_INLINE
  void dismiss() { dismissed_ = true; }

public:
  ScopeExitHandler handler_;
  bool dismissed_;
};

// Dummy implementation for statically disabled scope guards.
template <typename ScopeExitHandler>
class STU_APPEARS_UNUSED ScopeGuard<ScopeExitHandler, false> {
public:
  STU_CONSTEXPR_T
  explicit ScopeGuard(ScopeExitHandler&&) {}

  ScopeGuard(const ScopeGuard&) = delete;
  ScopeGuard& operator=(const ScopeGuard&) = delete;

  STU_INLINE
  constexpr void dismiss() {}
};

template <bool enable, typename ScopeExitHandler>
STU_INLINE_T
ScopeGuard<ScopeExitHandler, enable> scopeGuardIf(ScopeExitHandler&& handler) {
  return ScopeGuard<ScopeExitHandler, enable>(std::forward<ScopeExitHandler>(handler));
}

} // namespace stu

