// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#ifndef __OBJC__
  #error This header requires Objective-C
#endif

#include "stu/Range.hpp"
#include "stu/RefCounting.hpp"

#include <Foundation/Foundation.h>

namespace stu {

namespace detail {
  template <typename T>
  using DecltypeStaticCastToId =
                               #if __has_feature(objc_arc)
                                 decltype((__bridge id)declval<T>());
                               #else
                                 decltype(static_cast<id>(declval<T>()));
                               #endif
}

template <typename T>
constexpr bool isBridgableToId = !isConvertible<T, id>
                              && canApply<detail::DecltypeStaticCastToId, T>;

namespace detail {
  template <typename T> struct IsBlock : False {};
  template <typename R, typename... Args>
  struct IsBlock<R(^)(Args...)> : True {};
};

template <typename T>
constexpr bool isBlock = detail::IsBlock<__strong T>::value;

template <>
struct RangeConversion<NSRange> {
  STU_CONSTEXPR
  static Range<NSUInteger> toRange(NSRange range) noexcept {
    return {range.location, range.location + range.length};
  }

  STU_CONSTEXPR
  static NSRange fromRange(Range<NSUInteger> range) noexcept {
    return {range.start, range.end - range.start};
  }
};

template <>
struct RangeConversion<CFRange> {
  STU_CONSTEXPR
  static Range<Int> toRange(CFRange range) noexcept {
    return {range.location, range.location + range.length};
  }

  STU_CONSTEXPR
  static CFRange fromRange(Range<Int> range) noexcept {
    return {range.start, range.end - range.start};
  }
};

/// RefCountTraits specialization for CoreFoundation types
/// (except RemovePointer<CFTypeRef>, i.e. const void).
template <typename T>
struct RefCountTraits<T, EnableIf<isBridgableToId<T*>>> {
  STU_INLINE static void incrementRefCount(T* instance) {
    CFRetain(instance);
  }

  STU_INLINE static void decrementRefCount(T* instance) {
    CFRelease(instance);
  }
};

/// RefCountTraits specialization for Objective-C types.
template <typename T>
struct RefCountTraits<T, EnableIf<isConvertible<T*, id>>> {
  STU_INLINE static void incrementRefCount(T* __unsafe_unretained instance) {
  #if __has_feature(objc_arc)
    (void)(__bridge T*)(__bridge_retained CFTypeRef)instance; // objc_retain(instance);
  #else
    [instance retain];
  #endif
  }

  STU_INLINE static void decrementRefCount(T* __unsafe_unretained instance) {
  #if __has_feature(objc_arc)
    (void)(__bridge_transfer T*)(__bridge CFTypeRef)instance; // objc_release(instance);
  #else
    [instance release];
  #endif
  }
};

} // namespace stu
