// Copyright 2017–2018 Stephan Tolksdorf

#include "stu/Config.h"

#undef STU_CHECK_MSG
#undef STU_ASSERT_MAY_THROW
#undef STU_CHECK
#undef STU_ASSERT
#undef STU_DEBUG_ASSERT
#undef STU_PRECONDITION

#define STU_CHECK_MSG(assertion, message) \
  (STU_LIKELY(assertion) ? (void)0 \
   : stu_assertion_failed(__FILE__, __LINE__, __PRETTY_FUNCTION__, message))

#if STU_DEBUG
  #define STU_CHECK(assertion) STU_CHECK_MSG(assertion, #assertion)
  #define STU_ASSERT_MAY_THROW 1
#else
  #define STU_CHECK(assertion) (STU_LIKELY(assertion) ? (void)0 : __builtin_trap())
  #define STU_ASSERT_MAY_THROW 0
#endif

#if defined(NDEBUG) // Release build without asserts

#define STU_ASSERT(assertion) STU_ASSUME(assertion)
#define STU_DEBUG_ASSERT(assertion) STU_ASSUME(assertion)

#elif !STU_DEBUG // Release build with asserts

#define STU_ASSERT(assertion) STU_CHECK(assertion)
#define STU_DEBUG_ASSERT(assertion)

#else // Debug build

#define STU_ASSERT(assertion) STU_CHECK(assertion)
#define STU_DEBUG_ASSERT(assertion) STU_ASSERT(assertion)

#endif

#define STU_PRECONDITION(condition) STU_ASSERT(condition)

#ifdef __cplusplus
extern "C"
#endif
void stu_assertion_failed(const char *fileName, int line, const char *functionName,
                          const char *condition)
       __attribute__((noreturn));

