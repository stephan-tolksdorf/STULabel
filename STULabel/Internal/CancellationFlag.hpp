// Copyright 2018 Stephan Tolksdorf

#import "STULabel/STUCancellationFlag.h"

#import "Common.hpp"

#include <stdatomic.h>

namespace stu_label {

STU_INLINE_T
bool isCancelled(const STUCancellationFlag& flag) {
  return STUCancellationFlagGetValue(&flag);
}

struct CancellationFlag : STUCancellationFlag {
  static const CancellationFlag neverCancelledFlag;

  STU_CONSTEXPR_T
  CancellationFlag() : STUCancellationFlag{} {}

  explicit STU_INLINE_T
  operator bool() const { return STUCancellationFlagGetValue(this); }

  void setCancelled() { return STUCancellationFlagSetCancelled(this); }

  void clear() {
    atomic_store_explicit(&isCancelled, false, memory_order_relaxed);
  }

};

} // namespace stu_label
