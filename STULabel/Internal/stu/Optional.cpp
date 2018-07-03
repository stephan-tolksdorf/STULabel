// Copyright 2017–2018 Stephan Tolksdorf

#include "stu/Optional.hpp"

#if !STU_NO_EXCEPTIONS

const char* stu::BadOptionalAccess::what() const noexcept {
  return "Attempt to unwrap empty stu::Optional<T>";
}

[[noreturn]] STU_NO_INLINE
void stu::detail::throwBadOptionalAccess() {
  throw BadOptionalAccess();
}

#endif
