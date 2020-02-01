// Copyright 2016–2018 Stephan Tolksdorf

#include "stu_mutex.h"

STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
STU_DISABLE_CLANG_WARNING("-Wunreachable-code")

#if !STU_ALWAYS_HAS_OS_LOCK

STU_EXPORT STU_NO_INLINE
void stu_mutex_destroy(stu_mutex * __nonnull mutex) {
  if (&os_unfair_lock_lock) return;
  pthread_mutex_destroy(&mutex->pthread_mutex);
}

STU_EXPORT STU_NO_INLINE
bool stu_mutex_trylock(stu_mutex * __nonnull mutex) {
  if (&os_unfair_lock_trylock) {
    return os_unfair_lock_trylock(&mutex->unfair_lock);
  }
  return pthread_mutex_trylock(&mutex->pthread_mutex) == 0;
}

STU_EXPORT STU_NO_INLINE
void stu_mutex_lock(stu_mutex * __nonnull mutex) {
  if (&os_unfair_lock_lock) {
    os_unfair_lock_lock(&mutex->unfair_lock);
    return;
  }
  pthread_mutex_lock(&mutex->pthread_mutex);
}

STU_EXPORT STU_NO_INLINE
void stu_mutex_unlock(stu_mutex * __nonnull mutex) {
  if (&os_unfair_lock_unlock) {
    os_unfair_lock_unlock(&mutex->unfair_lock);
    return;
  }
  pthread_mutex_unlock(&mutex->pthread_mutex);
}

#endif // STU_ALWAYS_HAS_OS_LOCK

STU_REENABLE_CLANG_WARNING
STU_REENABLE_CLANG_WARNING
