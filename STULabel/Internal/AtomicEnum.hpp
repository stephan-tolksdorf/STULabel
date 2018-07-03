// Copyright 2018 Stephan Tolksdorf

#include "Common.hpp"

#include <atomic>

namespace stu_label {

template <typename Enum>
struct AtomicEnum {
  static_assert(isEnum<Enum>);
  using Value = UnderlyingType<Enum>;

  std::atomic<Value> value;

  explicit AtomicEnum(Enum value) noexcept
  : value{static_cast<Value>(value)} {}

  STU_INLINE
  Enum load(std::memory_order mo) const {
    return static_cast<Enum>(value.load(mo));
  }

  STU_INLINE
  void store(Enum e, std::memory_order mo) {
    return value.store(static_cast<Value>(e), mo);
  }

  STU_INLINE
  Enum fetch_or(Enum e, std::memory_order mo) {
    return static_cast<Enum>(value.fetch_or(static_cast<Value>(e), mo));
  }

  STU_INLINE
  Enum fetch_and(Enum e, std::memory_order mo) {
    return static_cast<Enum>(value.fetch_and(static_cast<Value>(e), mo));
  }
};

} // namespace stu_label
