// Copyright 2016–2018 Stephan Tolksdorf

#pragma once

#include "STUDefines.h"

#ifndef STU_ALWAYS_HAS_OS_LOCK
  #define STU_ALWAYS_HAS_OS_LOCK 0
#endif

#include <os/lock.h>

#if !STU_ALWAYS_HAS_OS_LOCK
  #include <pthread.h>
#endif

STU_EXTERN_C_BEGIN

/// A mutex type that uses os_unfair_lock where available and otherwise falls back to using
/// pthread_mutex_t.
///
/// Must be initialized with @c STU_MUTEX_INIT or @c stu_mutex_init and destroyed with
/// @c stu_mutex_destroy.
///
/// @warning
///  This type has to be handled like @c pthread_mutex_t or @c os_unfair_lock. If you're not
///  familiar with these types and know how to use them, then you shouldn't use @c stu_mutex.
///
/// @warning
///  Swift 4 does not support using @c stu_mutex and similar C structs wrapping atomic variables
///  directly in Swift properties, see https://twitter.com/jckarter/status/962776179269775360
#if STU_ALWAYS_HAS_OS_LOCK
  typedef struct stu_mutex { os_unfair_lock unfair_lock; } stu_mutex;
#else
  typedef union stu_mutex {
    pthread_mutex_t pthread_mutex;
    struct {
      long _padding; // Ensures that PTHREAD_MUTEX_INITIALIZER zero-initializes unfair_lock.
    STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
      os_unfair_lock unfair_lock;
    STU_REENABLE_CLANG_WARNING
    };
  } stu_mutex;
#endif

#if !STU_ALWAYS_HAS_OS_LOCK
  #define STU_MUTEX_INIT (stu_mutex){.pthread_mutex = PTHREAD_MUTEX_INITIALIZER}
  void stu_mutex_destroy(stu_mutex * __nonnull mutex);
  bool stu_mutex_trylock(stu_mutex * __nonnull mutex);
  void stu_mutex_lock(stu_mutex * __nonnull mutex);
  void stu_mutex_unlock(stu_mutex * __nonnull mutex);
#else
  #define STU_MUTEX_INIT (stu_mutex){.unfair_lock = OS_UNFAIR_LOCK_INIT}
  static STU_INLINE void stu_mutex_destroy(stu_mutex * __nonnull) { /* do nothing */ }

  static STU_INLINE bool stu_mutex_trylock(stu_mutex * __nonnull mutex) {
    return os_unfair_lock_trylock(&mutex->unfair_lock);
  }

  static STU_INLINE void stu_mutex_lock(stu_mutex * __nonnull mutex) {
    os_unfair_lock_lock(&mutex->unfair_lock);
  }

  static STU_INLINE void stu_mutex_unlock(stu_mutex * __nonnull mutex) {
    os_unfair_lock_unlock(&mutex->unfair_lock);
  }
#endif

/// Initializes the mutex. Equivalent to `*mutex = STU_MUTEX_INIT`.
static STU_INLINE void stu_mutex_init(stu_mutex * __nonnull mutex) {
  *mutex = STU_MUTEX_INIT;
}

STU_EXTERN_C_END
