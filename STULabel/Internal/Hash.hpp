// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

namespace stu_label {

// A simple hashing implementation sufficient for the limited purposes of this library.

// This "Murmur-inspired" hash combine function from Google's CityHash is currently also used by
// the Swift, LLVM and Facebook Folly projects.
[[nodiscard]] STU_CONSTEXPR
UInt64 hash(UInt64 low, UInt64 high) {
  const UInt64 f = 0x9ddfea08eb382d69;
  UInt64 a = (low ^ high)*f;
  a ^= (a >> 47);
  uint64_t b = (high ^ a)*f;
  b ^= (b >> 47);
  b *= f;
  return b;
}

[[nodiscard]] STU_CONSTEXPR
UInt64 hash(UInt64 value) {
  return hash(value & maxValue<UInt32>, value >> 32);
}

template <typename T>
[[nodiscard]] STU_CONSTEXPR
UInt64 hashPointer(T* pointer) {
  static_assert(sizeof(pointer) <= 8);
  return hash(reinterpret_cast<UInt64>(pointer));
}


template <typename Sink, typename T, EnableIf<(isIntegral<T> || isEnum<T>)> = 0>
STU_CONSTEXPR
void hashableBits(Sink sink, T value) {
  // Sign-extend the value to UInt64.
  sink(static_cast<UInt64>(value));
}

template <typename Sink, typename T, EnableIf<isOneOf<T, Float32, Float64>> = 0>
STU_CONSTEXPR
void hashableBits(Sink sink, T value) {
  using U = Conditional<sizeof(T) == 4, UInt32, UInt64>;
  sink(value == 0 ? U{0} // +0 or -0
       : bit_cast<U>(value));
}

template <typename Sink, typename T, EnableIf<isConvertible<T*, NSObject*>> = 0>
STU_INLINE
void hashableBits(Sink sink, T* __unsafe_unretained value) {
  sink(value.hash);
}

template <typename Sink, typename A, typename B, typename... Ts>
STU_CONSTEXPR
void hashableBits(Sink sink, const A& a, const B& b, const Ts&... rest);

template <typename Sink>
STU_CONSTEXPR
void hashableBits(Sink sink, CGPoint p) {
  return hashableBits(sink, p.x, p.y);
}

template <typename Sink>
STU_CONSTEXPR
void hashableBits(Sink sink, CGSize s) {
  return hashableBits(sink, s.width, s.height);
}

template <typename Sink>
STU_CONSTEXPR
void hashableBits(Sink sink, CGRect r) {
  return hashableBits(sink, r.origin.x, r.origin.y, r.size.width, r.size.height);
}

template <typename Sink>
STU_CONSTEXPR
void hashableBits(Sink sink, UIEdgeInsets e) {
  return hashableBits(sink, e.top, e.left, e.bottom, e.right);
}

template <typename Sink, typename Bound>
STU_CONSTEXPR
void hashableBits(Sink sink, const Range<Bound>& r) {
  return hashableBits(sink, r.start, r.end);
}


template <typename Sink, typename A, typename B, typename... Ts>
STU_CONSTEXPR
void hashableBits(Sink sink, const A& a, const B& b, const Ts&... rest) {
  hashableBits([&](auto... bitsA) STU_INLINE_LAMBDA {
    hashableBits([&](auto... bitsBAndRest) STU_INLINE_LAMBDA {
      sink(bitsA..., bitsBAndRest...);
    }, b, rest...);
  }, a);
}

namespace detail {
  template <int n, int... indices>
  STU_CONSTEXPR
  UInt64 hashPairwise(const UInt64 (& array)[n], Indices<indices...>) {
    static_assert(n/2 == sizeof...(indices));
    if constexpr (n == 2) {
      return hash(array[0], array[1]);
    } else if constexpr (sizeof...(indices)*2 == n) {
      const UInt64 reduced[] = {hash(array[2*indices], array[2*indices + 1])...};
      return hashPairwise(reduced, MakeIndices<n/4>{});
    } else {
      const UInt64 reduced[] = {hash(array[2*indices], array[2*indices + 1])..., array[n - 1]};
      return hashPairwise(reduced, MakeIndices<(n/2 + 1)/2>{});
    }
  }
}

template <typename A, typename... Ts,
          typename B = FirstType<Ts...>,
          EnableIf<(sizeof...(Ts) > 1)
                   || (isFloatingPoint<A> || !isSafelyConvertible<A, UInt64>)
                   || (sizeof...(Ts) == 1
                       && (isFloatingPoint<B> || !isSafelyConvertible<B, UInt64>))> = 0>
[[nodiscard]] STU_CONSTEXPR
UInt64 hash(const A& a, const Ts&... args) {
  UInt64 result = 0;
  hashableBits([&result](auto... bits) STU_INLINE_LAMBDA {
    if constexpr (sizeof...(bits) <= 1) {
      if constexpr (sizeof...(bits) == 1) {
        result = hash(bits...);
      }
    } else {
      const UInt64 array[] = {bits...};
      // Hashing the arguments recursively pairwise is a simple way to improve instruction-level
      // parallelism.
      result = detail::hashPairwise(array, MakeIndices<sizeof...(bits)/2>{});
    }
  }, a, args...);
  return result;
}

} // namespace stu_label
