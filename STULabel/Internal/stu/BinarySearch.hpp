// Copyright 2017 Stephan Tolksdorf


#include "ArrayRef.hpp"
#include "Casts.hpp"
#include "Optional.hpp"

namespace stu {

struct ArrayBinarySearchResult {
  Int indexOrArrayCount;
  Int arrayCount;

  bool indexIsArrayCount() const { return indexOrArrayCount == arrayCount; }
};

/// Returns the index of the first element in the array for which the predicate returns `true`,
/// or `partitionedArray.count()` if there is no such element.
///
/// \pre The array must be partitioned such that all elements for which `predicate` returns `true`
/// are placed after all elements for which it returns `false`.
template <typename Array, typename Predicate,
          typename T = typename decltype(ArrayRef(declval<const Array&>()))::Value,
          EnableIf<isCallable<Predicate, bool(const T&)>> = 0>
STU_INLINE
ArrayBinarySearchResult
  binarySearchFirstIndexWhere(const Array& partitionedArray, Predicate&& predicate)
{
  const ArrayRef<const T> array{partitionedArray};
  const Int arrayCount = array.count();
  // See https://arxiv.org/abs/1509.05053 for an interesting discussion on binary search
  // performance on modern processors.
  //
  // Note that the performance of this function is quite sensitive to small changes of the
  // loop implementation.
  // A self-imposed implementation restriction is that the predicate should only be called in
  // one place, in order to minimize code-bloat after inlining.
  const T* p = array.begin();
	for (UInt n = sign_cast(arrayCount);;) {
    const T* ph;
    const T* ph1;
    if (UInt h = n/2; STU_LIKELY(h != 0)) {
      n -= h; // Anticipates the next non-final iteration.
      // Reducing the search area by h + 1 instead of h when the predicate evaluates to false,
      // doesn't seem to be a profitable optimization (rather the opposite).
      ph = p + h;
      __builtin_prefetch(p + n/2);
      __builtin_prefetch(ph + n/2);
      ph1 = ph;
    } else {
      if (n == 0) break;
      // This case needs to be handled differently in order for the loop to terminate.
      n = 0;
      ph = p;
      ph1 = p + 1;
    }
		p = predicate(*ph) ? p : ph1;
	}
  const Int index = p - array.begin();
  STU_ASSUME(0 <= index && index <= arrayCount);
  return {index, arrayCount};
}

} // namespace stu
