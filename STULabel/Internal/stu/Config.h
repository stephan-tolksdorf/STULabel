// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#if defined(DEBUG) && DEBUG
  #define STU_DEBUG 1
#else
  #define STU_DEBUG 0
#endif

#define STU_INLINE inline __attribute__((always_inline))

// We'll use 'artificial' here instead of 'nodebug' once clang & LLDB on Mac support it.
#define STU_INLINE_T inline __attribute__((always_inline, nodebug))

#define STU_NO_INLINE __attribute__((noinline))

#if defined(__x86_64__) || defined(__aarch64__)
  #define STU_PRESERVE_MOST __attribute__((preserve_most))
#else
  #define STU_PRESERVE_MOST
#endif

#define STU_NO_RETURN __attribute__((noreturn))

#define STU_NO_THROW __attribute__((nothrow))

#define STU_PURE __attribute__((pure))

#define STU_APPEARS_UNUSED __attribute__((__unused__))

#if STU_DEBUG
  #define STU_ASSUME(condition) (void)0
#else
  #define STU_ASSUME(condition) __builtin_assume(!!(condition))
#endif

#ifdef __clang_analyzer__
  #define STU_ANALYZER_ASSUME(condition) ((condition) ? (void)0 : __builtin_unreachable())
#else
  #define STU_ANALYZER_ASSUME(condition)
#endif

#define STU_STRINGIZE(x) #x

#define STU_CONCATENATE(x, y) x##y

#define STU_DISABLE_CLANG_WARNING(warning_string) \
  _Pragma("clang diagnostic push") \
  _Pragma(STU_STRINGIZE(clang diagnostic ignored warning_string))

#define STU_REENABLE_CLANG_WARNING \
  _Pragma("clang diagnostic pop")

#define STU_DISABLE_LOOP_UNROLL _Pragma("clang loop unroll (disable)")
