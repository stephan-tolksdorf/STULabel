// Copyright 2017–2018 Stephan Tolksdorf

#import "ThreadLocalAllocator.hpp"

namespace stu_label {

#if STU_HAS_THREAD_LOCAL

thread_local ThreadLocalArenaAllocator* ThreadLocalArenaAllocator::instance_pointer;

#else

static pthread_key_t createThreadLocalArenaAllocatorPThreadKey() {
  pthread_key_t key;
  const int RC = pthread_key_create(&key, nullptr);
  STU_CHECK(RC == 0);
  return key;
}

const pthread_key_t ThreadLocalArenaAllocator::instance_key = createThreadLocalArenaAllocatorPThreadKey();

#endif

}
