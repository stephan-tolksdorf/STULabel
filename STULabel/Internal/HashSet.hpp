// Copyright 2017–2018 Stephan Tolksdorf

#import "ThreadLocalAllocator.hpp"

namespace stu_label {

/// A simple hash set using open addressing, quadratic probing and power of 2 array lengths.
template <typename Value, typename AllocatorRef>
class UIntHashSet {
  static_assert(isUnsignedInteger<Value>);
public:
  struct Bucket {
    Value valuePlus1;
    Value hashCode;

    STU_INLINE_T bool isEmpty() const { return valuePlus1 == 0; }
  };

private:
  Array<Bucket, AllocatorRef> buckets_;
  Int count_{};

public:
  explicit STU_INLINE_T
  UIntHashSet(Uninitialized, AllocatorRef alloc = AllocatorRef{})
  : buckets_{alloc}
  {}

  STU_INLINE
  void initializeWithBucketCount(Int bucketCount) {
    STU_ASSERT(buckets_.begin() == nullptr);
    STU_CHECK(bucketCount >= 4 && isPowerOfTwo(bucketCount));
    buckets_ = Array<Bucket, AllocatorRef>(zeroInitialized, Count{bucketCount},
                                           buckets_.allocator());
  }

  STU_INLINE
  void initializeWithExistingBuckets(ArrayRef<const Bucket> existingBuckets) {
    STU_ASSERT(buckets_.begin() == nullptr);
    Int n = max(16, existingBuckets.count() + existingBuckets.count()/2 + 1);
    n = sign_cast(roundUpToPowerOfTwo(sign_cast(n)));
    initializeWithBucketCount(n);
    count_ = insertBucketsIntoZeroInitializedArray(existingBuckets, buckets_);
  }

  UIntHashSet(const UIntHashSet&) = delete;
  UIntHashSet& operator=(const UIntHashSet&) = delete;

  STU_INLINE_T
  Int count() const {
    STU_ASSUME(count_ >= 0);
    return count_;
  }

  STU_INLINE_T
  ArrayRef<const Bucket> buckets() const { return buckets_; }

  template <typename IsEqual>
  STU_INLINE
  Optional<Value> find(UInt64 hashCode, IsEqual&& isEqual) {
    static_assert(isCallable<IsEqual&, bool(Value)>);
    const auto hash = narrow_cast<decltype(Bucket{}.hashCode)>(hashCode);
    STU_ASSERT(buckets_.count() > 0);
    Prober prober{Ref{buckets_}};
    prober.initWithHashCode(hash);
    for (;;) {
      Bucket& bucket = prober.nextBucket();
      if (!bucket.isEmpty()) {
        const Value value = bucket.valuePlus1 - 1;
        if (bucket.hashCode != hash || !isEqual(value)) continue;
        return value;
      }
      return none;
    }
  }

  struct InsertResult {
    Value value;
    bool inserted;
  };

  /// @pre index < maxValue<Value>
  template <typename IsEqual>
  STU_INLINE
  InsertResult insert(UInt64 hashCode, Value newValue, IsEqual&& isEqual) {
    static_assert(isCallable<IsEqual&, bool(Value)>);
    const auto hash = narrow_cast<decltype(Bucket{}.hashCode)>(hashCode);
    STU_ASSERT(buckets_.count() > 0);
    Value newValuePlus1;
    if (STU_UNLIKELY(__builtin_add_overflow(newValue, 1, &newValuePlus1))) {
      STU_CHECK(false);
    }
    Prober prober{Ref{buckets_}};
    prober.initWithHashCode(hash);
    for (;;) {
      Bucket& bucket = prober.nextBucket();
      if (!bucket.isEmpty()) {
        const Value oldValue = bucket.valuePlus1 - 1;
        if (bucket.hashCode != hash || !isEqual(oldValue)) {
          STU_DEBUG_ASSERT(newValue != oldValue);
          continue;
        }
        return {oldValue, false};
      }
      bucket.valuePlus1 = newValuePlus1;
      bucket.hashCode = hash;
      count_ += 1;
      if (STU_UNLIKELY(shouldGrow())) {
        grow();
      }
      return {newValue, true};
    }
  }

  STU_INLINE
  void insertNew(UInt64 hashCode, Value value) {
    insert(hashCode, value,
           [value](Value other) {
             STU_DEBUG_ASSERT(value != other);
             discard(value, other);
             return false;
           });
  }

  STU_INLINE
  void removeAll() {
    array_utils::initializeArray(buckets_.begin(), buckets_.count());
    count_ = 0;
  }

private:
  class Prober {
    Bucket* buckets_;
    UInt mask_;
    UInt index_;
    UInt counter_;
  public:
    STU_INLINE
    explicit Prober(ArrayRef<Bucket> buckets)
    : buckets_(buckets.begin()), mask_(sign_cast(buckets.count()) - 1) {}

    STU_INLINE
    void initWithHashCode(UInt hashCode) {
      index_ = hashCode & mask_;
      counter_ = 0;
    }

    STU_INLINE
    Bucket& nextBucket() {
      Bucket& bucket = buckets_[index_];
      index_ = (index_ + ++counter_) & mask_;
      return bucket;
    }
  };

  STU_INLINE
  bool shouldGrow() const {
    return count() + count()/2 > buckets_.count();
  }

  STU_NO_INLINE
  void grow() {
    Array<Bucket, AllocatorRef> newBuckets{zeroInitialized, Count{buckets().count()*2},
                                           buckets_.allocator()};
    insertBucketsIntoZeroInitializedArray(buckets(), newBuckets);
    buckets_ = std::move(newBuckets);
  }

  STU_NO_INLINE
  static Int insertBucketsIntoZeroInitializedArray(ArrayRef<const Bucket> oldBuckets,
                                                   ArrayRef<Bucket> newBuckets)
  {
    Prober prober{newBuckets};
    Int count = 0;
    for (const Bucket& oldBucket : oldBuckets) {
      if (oldBucket.isEmpty()) continue;
      ++count;
      prober.initWithHashCode(oldBucket.hashCode);
      for (;;) {
        Bucket& newBucket = prober.nextBucket();
        if (!newBucket.isEmpty()) {
          STU_DEBUG_ASSERT(oldBucket.valuePlus1 != newBucket.valuePlus1);
          continue;
        }
        newBucket.valuePlus1 = oldBucket.valuePlus1;
        newBucket.hashCode = oldBucket.hashCode;
        break; // inner loop
      }
    }
    return count;
  }
};

template <typename Value>
using TempIndexHashTable = UIntHashSet<Value, ThreadLocalAllocatorRef>;

extern template class UIntHashSet<UInt16, Malloc>;
extern template class UIntHashSet<UInt16, ThreadLocalAllocatorRef>;

} // namespace stu_label
