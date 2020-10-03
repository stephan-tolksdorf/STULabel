// Copyright 2016–2018 Stephan Tolksdorf

#pragma once

#ifdef __cplusplus
  #define STU_EXTERN_C_BEGIN extern "C" {
  #define STU_EXTERN_C_END   }
#else
  #define STU_EXTERN_C_BEGIN
  #define STU_EXTERN_C_END
#endif

#ifdef STU_IMPLEMENTATION
  #define STU_EXPORT __attribute__((visibility ("default")))
#else
  #define STU_EXPORT         
#endif

#define STU_INLINE inline __attribute__((always_inline))

#define STU_NO_INLINE __attribute__((noinline))

#define STU_NO_RETURN __attribute__((noreturn))

#define STU_NOESCAPE __attribute__((noescape))

#define STU_ALIGN_AS(Type) __attribute__((aligned(__alignof__(Type))))

#define STU_FALLTHROUGH __attribute__((fallthrough));

#ifdef __cplusplus
  #define STU_LIKELY(expr)   __builtin_expect(static_cast<bool>(expr), true)
  #define STU_UNLIKELY(expr) __builtin_expect(static_cast<bool>(expr), false)
#else
  #define STU_LIKELY(expr)   __builtin_expect(!!(expr), true)
  #define STU_UNLIKELY(expr) __builtin_expect(!!(expr), false)
#endif

#define STU_WARN_UNUSED_RESULT __attribute__((warn_unused_result))

#define STU_STRINGIZE(x) #x
#define STU_CONCATENATE(x, y) x##y

#define STU_UNAVAILABLE(messageString) \
  __attribute__((__unavailable__(messageString)));

#define STU_SWIFT_UNAVAILABLE \
  __attribute__((__availability__(swift, unavailable)))

#define STU_DISABLE_CLANG_WARNING(warning_string) \
  _Pragma("clang diagnostic push") \
  _Pragma(STU_STRINGIZE(clang diagnostic ignored warning_string))

#define STU_REENABLE_CLANG_WARNING \
  _Pragma("clang diagnostic pop")

// clang's Wobjc-property-no-attribute warning will be triggered if any header with a readwrite
// property declaration that doesn't specify strong, weak or assign is included from non-ARC code,
// even if that property is implemented in a different file using ARC. That seems overzealous.

#define STU_ASSUME_NONNULL_AND_STRONG_BEGIN \
  _Pragma("clang assume_nonnull begin") \
  STU_DISABLE_CLANG_WARNING("-Wobjc-property-no-attribute")

#define STU_ASSUME_NONNULL_AND_STRONG_END \
  STU_REENABLE_CLANG_WARNING \
  _Pragma("clang assume_nonnull end")

