// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#include "stu/Config.h"

#define STU_CONSTEXPR constexpr __attribute__((always_inline))

#define STU_INLINE_LAMBDA __attribute__((always_inline))

#ifdef __cplusplus
  #define STU_LIKELY(expr)   __builtin_expect(static_cast<bool>(expr), true)
  #define STU_UNLIKELY(expr) __builtin_expect(static_cast<bool>(expr), false)
#else
  #define STU_LIKELY(expr)   __builtin_expect(!!(expr), true)
  #define STU_UNLIKELY(expr) __builtin_expect(!!(expr), false)
#endif

// We'll use 'artificial' here instead of 'nodebug' once clang & LLDB on Mac support it.
#define STU_CONSTEXPR_T constexpr __attribute__((always_inline, nodebug))

#define STU_NOEXCEPT_AUTO_RETURN(expr) noexcept(noexcept(expr)) { return expr; }

#ifdef __cpp_exceptions
  #define STU_NO_EXCEPTIONS 0
#else
  #define STU_NO_EXCEPTIONS 1
#endif

#include <stddef.h>
#include <stdint.h>

namespace stu {

#if defined(__LP64__) || defined(_WIN64)
  using Int = ptrdiff_t;
  using UInt = size_t;
#else
  using Int = long;
  using UInt = unsigned long;
#endif

using Int8 = int8_t;
using UInt8 = uint8_t;

using Int16 = int16_t;
using UInt16 = uint16_t;

using Int32 = int32_t;
using UInt32 = uint32_t;

using Int64 = int64_t;
using UInt64 = uint64_t;

#if defined(__SIZEOF_INT128__)
  #define STU_HAS_INT128 1
  typedef  __int128_t  Int128;
  typedef __uint128_t UInt128;
#else
  #define STU_HAS_INT128 0
#endif

using Float32 = float;
using Float64 = double;

using Char16 = char16_t;
using Char32 = char32_t;

// #ifdef __cpp_lib_byte
//   #define STU_HAS_BYTE 1
//   using Byte = std::byte; // Leads to ambiguity issues in Objective C++ code due to the typedef in MacTypes.h
// #else
  #define STU_HAS_BYTE 0
  using Byte = UInt8;
// #endif

} // namespace stu
