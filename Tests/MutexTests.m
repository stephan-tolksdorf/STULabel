// Copyright 2018 Stephan Tolksdorf

@import STULabel.Mutex;

@import XCTest;


@interface MutexTests : XCTestCase

@end

@implementation MutexTests

- (void)testInitializer {
  stu_mutex mutex = STU_MUTEX_INIT;
  stu_mutex mutex2;
  stu_mutex_init(&mutex2);
  XCTAssertTrue(memcmp(&mutex, &mutex2, sizeof(mutex)) == 0);
#if !STU_ALWAYS_HAS_OS_LOCK
  pthread_mutex_t phtread_mutex = PTHREAD_MUTEX_INITIALIZER;
  XCTAssertTrue(memcmp(&mutex.pthread_mutex, &phtread_mutex, sizeof(phtread_mutex)) == 0);
#endif
  STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
  os_unfair_lock unfair_lock = OS_UNFAIR_LOCK_INIT;
  XCTAssertTrue(memcmp(&mutex.unfair_lock, &unfair_lock, sizeof(unfair_lock)) == 0);
  STU_REENABLE_CLANG_WARNING
}

- (void)testLocking {
  stu_mutex mutex = STU_MUTEX_INIT;
  XCTAssertTrue(stu_mutex_trylock(&mutex));
  XCTAssertTrue(!stu_mutex_trylock(&mutex));
  stu_mutex_unlock(&mutex);
  XCTAssertTrue(stu_mutex_trylock(&mutex));
  XCTAssertTrue(!stu_mutex_trylock(&mutex));
  stu_mutex_unlock(&mutex);
  stu_mutex_lock(&mutex);
  stu_mutex_unlock(&mutex);
  XCTAssertTrue(stu_mutex_trylock(&mutex));
  XCTAssertTrue(!stu_mutex_trylock(&mutex));
  stu_mutex_destroy(&mutex);
  mutex = STU_MUTEX_INIT;
  XCTAssertTrue(stu_mutex_trylock(&mutex));
  XCTAssertTrue(!stu_mutex_trylock(&mutex));
  stu_mutex_unlock(&mutex);
  stu_mutex_destroy(&mutex);
}

@end
