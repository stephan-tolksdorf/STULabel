// Copyright 2017–2018 Stephan Tolksdorf

#include "Allocation.hpp"

namespace stu::detail {

[[noreturn]] STU_NO_INLINE
void throwBadAlloc() {
#ifdef __cpp_exceptions
  throw std::bad_alloc();
#else
  __builtin_trap();
#endif
}

}
