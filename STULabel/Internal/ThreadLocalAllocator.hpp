// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

#import "stu/ArenaAllocator.hpp"

#if !TARGET_OS_SIMULATOR || TARGET_RT_64_BIT
  #define STU_HAS_THREAD_LOCAL 1
#else
  // https://twitter.com/gparker/status/921133893406748672
  #define STU_HAS_THREAD_LOCAL 0
#endif

#if !STU_HAS_THREAD_LOCAL
  #import <pthread.h>
#endif

namespace stu_label {

class ThreadLocalArenaAllocator : public ArenaAllocator<> {
#if STU_HAS_THREAD_LOCAL
  static thread_local ThreadLocalArenaAllocator* instance_pointer;
#else
  static const pthread_key_t instance_key;
#endif
public:
  STU_INLINE_T
  static ThreadLocalArenaAllocator* instance() {
  #if STU_HAS_THREAD_LOCAL
    return instance_pointer;
  #else
    return static_cast<ThreadLocalArenaAllocator*>(pthread_getspecific(instance_key));
  #endif
  }

  template <auto size>
  explicit STU_INLINE
  ThreadLocalArenaAllocator(Ref<InitialBuffer<size>> buffer)
  : ArenaAllocator(buffer)
  {
    STU_ASSERT(ThreadLocalArenaAllocator::instance() == nullptr);
  #if STU_HAS_THREAD_LOCAL
    ThreadLocalArenaAllocator::instance_pointer = this;
  #else
    pthread_setspecific(instance_key, this);
  #endif
  }

  ~ThreadLocalArenaAllocator() {
  #if STU_HAS_THREAD_LOCAL
    ThreadLocalArenaAllocator::instance_pointer = nullptr;
  #else
    pthread_setspecific(instance_key, nullptr);
  #endif
  }

  ThreadLocalArenaAllocator(const ThreadLocalArenaAllocator&) = delete;
  ThreadLocalArenaAllocator(ThreadLocalArenaAllocator&&) = delete;

  ThreadLocalArenaAllocator& operator=(const ThreadLocalArenaAllocator&) = delete;
  ThreadLocalArenaAllocator& operator=(ThreadLocalArenaAllocator&&) = delete;
};

class ThreadLocalAllocatorRef {
public:
  STU_INLINE
  ThreadLocalAllocatorRef()
  : arenaAlloctor_{ThreadLocalArenaAllocator::instance()}
  {
  #if STU_DEBUG
    if (!arenaAlloctor_) { // Someone forgot to construct a ThreadLocalArenaAllocator.
      __builtin_trap();
    }
  #endif
  }

  /* implicit */ STU_INLINE
  ThreadLocalAllocatorRef(ThreadLocalArenaAllocator& allocator)
  : arenaAlloctor_{&allocator}
  {}

  STU_INLINE
  ArenaAllocator<>& get() const noexcept { return *arenaAlloctor_; }


  // For internal data structure optimization purposes only:

  STU_CONSTEXPR
  static ThreadLocalAllocatorRef null() noexcept { return ThreadLocalAllocatorRef{nullptr}; }
  STU_CONSTEXPR
  bool isNull() const noexcept { return !arenaAlloctor_; }

private:
  explicit STU_CONSTEXPR
  ThreadLocalAllocatorRef(std::nullptr_t)
  : arenaAlloctor_{}
  {}

  ArenaAllocator<>* arenaAlloctor_;
};

template <typename T>
using TempArray = Array<T, ThreadLocalAllocatorRef>;


struct MaxInitialCapacity : Parameter<MaxInitialCapacity, Int> {
  using Parameter::Parameter;
};

template <typename T, int minEmbeddedStorageCapacity = 0>
class TempVector : public Vector<T, minEmbeddedStorageCapacity, ThreadLocalAllocatorRef> {
  using Base = Vector<T, minEmbeddedStorageCapacity, ThreadLocalAllocatorRef>;
public:
  using Base::Base;

  explicit STU_INLINE
  TempVector(MaxInitialCapacity maxInitialCapacity,
             ThreadLocalAllocatorRef allocator = ThreadLocalAllocatorRef{})
  : Base{UninitializedArray<T, ThreadLocalAllocatorRef>{
           Capacity{min(maxInitialCapacity.value,
                        allocator.get().freeCapacityInCurrentBuffer<T>())}}}
  {}
};

/// Only use this constant when you can be sure that only the TempVector makes ThreadLocalAllocator
/// allocations while the vector is alive.
constexpr MaxInitialCapacity freeCapacityInCurrentThreadLocalAllocatorBuffer = MaxInitialCapacity{4096};

} // namespace stu_label

template <typename T>
class stu::OptionalValueStorage<stu::Array<T, stu_label::ThreadLocalAllocatorRef>> {
public:
  Array<T, stu_label::ThreadLocalAllocatorRef> value_{stu_label::ThreadLocalAllocatorRef::null()};

  STU_INLINE
  bool hasValue() const noexcept { return !value_.allocator().isNull(); }

  STU_INLINE
  void clearValue() noexcept {
    value_ = Array<T, stu_label::ThreadLocalAllocatorRef>{stu_label::ThreadLocalAllocatorRef::null()};
  }

  STU_INLINE
  void constructValue(stu::Array<T, stu_label::ThreadLocalAllocatorRef> array) {
    value_ = std::move(array);
  }
};
