// Copyright 2017–2018 Stephan Tolksdorf

#pragma once

#import "STUDefines.h"

#import <stdatomic.h>
#import <stdbool.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

/// @note
///  @c STUCancellationFlag values are NOT reference-counted. You must manually ensure that a
///  @c STUCancellationFlag instance remains valid and is not moved in memory while it is being
///  used.
/// @warning
///  Swift 4 does not support using @c STUCancellationFlag and similar C structs wrapping atomic
///  variables directly in Swift properties or local variables,
///  see https://twitter.com/jckarter/status/962776179269775360
typedef struct STUCancellationFlag {
  _Atomic(bool) isCancelled;
} STUCancellationFlag;

/// Sets the value of the cancellation flag to true.
static STU_INLINE
void STUCancellationFlagSetCancelled(STUCancellationFlag *token) {
  atomic_store_explicit(&token->isCancelled, true, memory_order_relaxed);
}

/// @returns The current value of the cancellation flag.
///
/// @note This function uses a relaxed memory order load, so calling this function does NOT
///       establish a "happens-before" relationship with a previous call to
///       @c STUCancellationFlagSetCancelled (unless you add the appropriate fences).
static STU_INLINE __attribute__((warn_unused_result))
bool STUCancellationFlagGetValue(const STUCancellationFlag *token) {
  // http://www.open-std.org/jtc1/SC22/WG14/www/docs/dr_459.htm
  return STU_UNLIKELY(atomic_load_explicit((_Atomic(bool)*)&token->isCancelled, // const cast
                                           memory_order_relaxed));
}

STU_ASSUME_NONNULL_AND_STRONG_END
