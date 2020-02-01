// Copyright 2017–2018 Stephan Tolksdorf

#import "ThreadLocalAllocator.hpp"

#import "Hash.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {
namespace detail {
  template <typename Key, typename = int>
  struct HashTableBucket_Key {
    Key key_;
    STU_CONSTEXPR bool isEmpty() const { return !key_; }
    STU_CONSTEXPR const Key& key() const { return key_; }
  };

  template <typename Key>
  struct HashTableBucket_Key<Key, EnableIf<isInteger<Key>>> {
    Key keyPlus1;
    STU_CONSTEXPR bool isEmpty() const { return keyPlus1 == minValue<Key>; }
    STU_CONSTEXPR Key key() const { return keyPlus1 - 1; }
  };

  template <typename Key, typename HashCode>
  struct HashTableBucket_Key_HashCode : HashTableBucket_Key<Key> {
    stu_label::HashCode<HashCode> hashCode;
  };

  template <typename Key>
  struct HashTableBucket_Key_HashCode<Key, NoType> : HashTableBucket_Key<Key> {};

  template <typename Hasher, typename Key>
  using DecltypeHasherHashValue = decltype(Hasher::hash(std::declval<Key>()).value);
} // namespace detail

template <typename Key, typename HashCode, typename... Value>
struct HashTableBucket;

template <typename Key, typename HashCode, typename Value>
struct HashTableBucket<Key, HashCode, Value> : detail::HashTableBucket_Key_HashCode<Key, HashCode> {
  Value value;
};

template <typename Key, typename HashCode>
struct HashTableBucket<Key, HashCode>
: detail::HashTableBucket_Key_HashCode<Key, HashCode> {};

} // namespace stu_label

template <typename K, typename H>
struct stu::IsBitwiseCopyable<stu_label::HashTableBucket<K, H>>
       : stu::BoolConstant<stu::isBitwiseCopyable<K>> {};

template <typename K, typename H>
struct stu::IsBitwiseMovable<stu_label::HashTableBucket<K, H>>
       : stu::BoolConstant<stu::isBitwiseMovable<K>> {};

template <typename K, typename H>
struct stu::IsBitwiseZeroConstructible<stu_label::HashTableBucket<K, H>>
       : stu::BoolConstant<stu::isBitwiseZeroConstructible<K>> {};

template <typename K, typename H, typename V>
struct stu::IsBitwiseCopyable<stu_label::HashTableBucket<K, H, V>>
       : stu::BoolConstant<stu::isBitwiseCopyable<stu_label::HashTableBucket<K, H>>
                           && stu::isBitwiseCopyable<V>> {};

template <typename K, typename H, typename V>
struct stu::IsBitwiseMovable<stu_label::HashTableBucket<K, H, V>>
       : stu::BoolConstant<stu::isBitwiseMovable<stu_label::HashTableBucket<K, H>>
                           && stu::isBitwiseMovable<V>> {};

template <typename K, typename H, typename V>
struct stu::IsBitwiseZeroConstructible<stu_label::HashTableBucket<K, H, V>>
       : stu::BoolConstant<stu::isBitwiseZeroConstructible<stu_label::HashTableBucket<K, H>>
                           && stu::isBitwiseZeroConstructible<V>> {};

namespace stu_label {

struct MinBucketCount : Parameter<MinBucketCount, Int> { using Parameter::Parameter; };

namespace detail { template <typename Key, typename Value, typename Hasher> struct HashTableBase; }

/// Uses open addressing, quadratic probing and power of 2 array lengths.
///
/// @note If `Key` is an integer type, `maxValue<Key>` is reserved and cannot be inserted into the
///       HashTable.
template <typename Key, typename Value, typename AllocatorRef, typename Hasher = NoType>
class HashTable : private detail::HashTableBase<Key, Value, Hasher> {
  using Base = detail::HashTableBase<Key, Value, Hasher>;

  static_assert(isExplicitlyConvertible<Key, bool>);
  static_assert(isBitwiseZeroConstructible<Key>);
  static_assert(!isType<Value> || isBitwiseZeroConstructible<Value>);
  static_assert(isBitwiseMovable<Key>);
  static_assert(!isType<Value> || isBitwiseMovable<Value>);

  static_assert(!isInteger<Key> || isUnsigned<Key>);

  using Base::hasValue;
  using Base::hasHasher;
  using Base::storesHashCodes;
  using typename Base::KeyHashCode;
  using typename Base::Prober;


public:
  using typename Base::Bucket;

private:
  Array<Bucket, AllocatorRef> buckets_;
  Int count_{};

public:
  explicit STU_INLINE_T
  HashTable(Uninitialized, AllocatorRef alloc = AllocatorRef{})
  : buckets_{alloc}
  {}

  STU_INLINE_T
  const AllocatorRef& allocator() const { return buckets_.allocator(); }

  STU_INLINE
  void initializeWithBucketCount(Int bucketCount) {
    STU_ASSERT(buckets_.begin() == nullptr);
    STU_CHECK(bucketCount >= 4 && isPowerOfTwo(bucketCount));
    buckets_ = Array<Bucket, AllocatorRef>(zeroInitialized, Count{bucketCount},
                                           buckets_.allocator());
  }

  template <bool enable = isBitwiseCopyable<Bucket>, EnableIf<enable> = 0>
  STU_INLINE
  void initializeWithExistingBuckets(ArrayRef<const Bucket> existingBuckets) {
    STU_ASSERT(buckets_.begin() == nullptr);
    Int n = max(16, existingBuckets.count() + existingBuckets.count()/2 + 1);
    n = sign_cast(roundUpToPowerOfTwo(sign_cast(n)));
    initializeWithBucketCount(n);
    count_ = insertBucketsIntoZeroInitializedArray(existingBuckets, buckets_);
  }

  template <typename Predicate,
            EnableIf<isCallable<Predicate, bool(const Key&)>> = 0>
  void filterAndRehash(MinBucketCount minBucketCount, Predicate&& predicate) {
    Bucket* const end = buckets_.end();
    Int d = 0;
    for (Bucket* p = buckets_.begin(); p != end; ++p) {
      if (!p->isEmpty() && predicate(p->key())) {
        if (d == 0) continue;
        p[d] = std::move(*p);
      } else {
        --d;
      }
      p->~Bucket();
    }
    const Int count = buckets_.count() + d;
    STU_DEBUG_ASSERT(0 <= count && count <= count_);
    const Int n = sign_cast(roundUpToPowerOfTwo(sign_cast(count + count/2 + 1)));
    Array<Bucket, AllocatorRef> buckets = std::move(buckets_);
    buckets_.allocator() = buckets.allocator();
    count_ = 0;
    initializeWithBucketCount(max(minBucketCount.value, n));
    count_ = insertBucketsIntoZeroInitializedArray(std::move(buckets), count, buckets_);
    STU_DEBUG_ASSERT(count_ == count);
  }

  void removeAll() {
    array_utils::destroyArray(buckets_.begin(), buckets_.count());
    array_utils::initializeArray(buckets_.begin(), buckets_.count());
    count_ = 0;
  }

  HashTable(const HashTable&) = delete;
  HashTable& operator=(const HashTable&) = delete;

  HashTable(HashTable&&) = default;
  HashTable& operator=(HashTable&&) = default;

  STU_INLINE_T
  Int count() const {
    STU_ASSUME(count_ >= 0);
    return count_;
  }

  STU_INLINE_T
  ArrayRef<const Bucket> buckets() const { return buckets_; }

  using typename Base::KeyOrValue;// Conditional<hasValue, ValueRef, KeyRef>;

  template <typename KeyIsEqualTo, EnableIf<hasHasher && isType<KeyIsEqualTo>> = 0>
  STU_INLINE
  Optional<KeyOrValue> find(const Key& key, KeyIsEqualTo&& keyIsEqualTo) {
    return find(Hasher::hash(key), keyIsEqualTo);
  }

  template <typename KeyIsEqualTo>
  STU_INLINE
  Optional<KeyOrValue> find(HashCode<UInt64> hashCode, KeyIsEqualTo&& keyIsEqualTo) {
    static_assert(isCallable<KeyIsEqualTo&, bool(Key)>);
    const KeyHashCode hash = narrow_cast<KeyHashCode>(hashCode);
    STU_ASSERT(buckets_.count() > 0);
    Prober prober{Ref{buckets_}};
    prober.initWithHashCode(hash);
    for (;;) {
      Bucket& bucket = prober.nextBucket();
      if (!bucket.isEmpty()) {
        if constexpr (storesHashCodes) {
          if (bucket.hashCode != hash) continue;
        }
        const Key key = bucket.key();
        if (!keyIsEqualTo(key)) continue;
        if constexpr (hasValue) {
          return bucket.value;
        } else {
          return key;
        }
      }
      return none;
    }
  }

  struct InsertResult {
    KeyOrValue value;
    bool inserted;
  };

  template <typename KeyIsEqualTo, EnableIf<!hasValue && hasHasher && isType<KeyIsEqualTo>> = 0>
  STU_INLINE
  InsertResult insert(Key key, KeyIsEqualTo&& keyIsEqualTo) {
    return insert(Hasher::hash(key), keyIsEqualTo,
                  [&]() STU_INLINE_LAMBDA { return std::move(key); },
                  []() STU_INLINE_LAMBDA { return none; });
  }

  template <typename IsEqual, typename GetValue,
            EnableIf<hasValue && hasHasher && isType<IsEqual>> = 0>
  STU_INLINE
  InsertResult insert(Key key, IsEqual&& isEqual, GetValue&& getValue) {
    return insert(Hasher::hash(key), isEqual,
                  [&]() STU_INLINE_LAMBDA { return std::move(key); },
                  getValue);
  }

  template <typename KeyIsEqualTo, EnableIf<!hasValue && isType<KeyIsEqualTo>> = 0>
  STU_INLINE
  InsertResult insert(HashCode<UInt64> hashCode, Key newKey, KeyIsEqualTo&& keyIsEqualTo) {
    return insert(hashCode, keyIsEqualTo,
                  [&]() STU_INLINE_LAMBDA { return std::move(newKey); },
                  []() STU_INLINE_LAMBDA { return none; });
  }

  template <typename KeyIsEqualTo, typename GetKey, EnableIf<!hasValue && isType<KeyIsEqualTo>> = 0>
  STU_INLINE
  InsertResult insert(HashCode<UInt64> hashCode, KeyIsEqualTo&& keyIsEqualTo, GetKey&& getKey) {
    return insert(hashCode, keyIsEqualTo, getKey,
                  []() STU_INLINE_LAMBDA { return none; });
  }

  template <typename KeyIsEqualTo, typename GetKey, typename GetValue>
  STU_INLINE
  InsertResult insert(HashCode<UInt64> hashCode,
                      KeyIsEqualTo&& keyIsEqualTo, GetKey&& getKey,
                      GetValue&& getValue)
  {
    static_assert(isCallable<KeyIsEqualTo&, bool(const Key&)>);
    static_assert(hasValue || isSame<decltype(getValue()), None>);
    const KeyHashCode hash = narrow_cast<KeyHashCode>(hashCode);
    STU_ASSERT(buckets_.count() > 0);
    Prober prober{Ref{buckets_}};
    prober.initWithHashCode(hash);
    for (;;) {
      Bucket& bucket = prober.nextBucket();
      if (!bucket.isEmpty()) {
        if constexpr (storesHashCodes) {
           if (bucket.hashCode != hash) continue;
        }
        if (!keyIsEqualTo(bucket.key())) {
          if constexpr (isIntegral<Key>) {
            STU_DEBUG_ASSERT(getKey() != bucket.key());
          }
          continue;
        }
        if constexpr (hasValue) {
          return {bucket.value, false};
        } else {
          return {bucket.key(), false};
        }
      }
      constexpr bool resultIsKeyValue = isSame<KeyOrValue, Key>;
      Conditional<resultIsKeyValue, Key, Int> key;
      if constexpr (!isInteger<Key>) {
        bucket.key_ = getKey();
        STU_CHECK(!!bucket.key_);
      } else {
        key = getKey();
        if (STU_UNLIKELY(__builtin_add_overflow(key, 1, &bucket.keyPlus1))) {
          STU_CHECK(false && "The key must be less than maxValue<Key>");
        }
      }
      if constexpr (storesHashCodes) {
        bucket.hashCode = hash;
      }
      if constexpr (hasValue) {
        bucket.value = getValue();
      }
      count_ += 1;
      Bucket* p = &bucket;
      if (STU_UNLIKELY(shouldGrow())) {
        if constexpr (needToTrackBucketWhenResizingArrayAfterInsert) {
          p = grow(p);
        } else {
          grow();
        }
      }
      if constexpr (hasValue) {
        return {p->value, true};
      } else if constexpr (resultIsKeyValue) {
        return {key, true};
      } else {
        return {p->key(), true};
      }
    }
  }

  template <bool enable = hasHasher && !hasValue, EnableIf<enable> = 0>
  STU_INLINE
  void insertNew(Key key) {
    insertNew(Hasher::hash(key), key);
  }

  template <bool enable = !hasValue, EnableIf<enable> = 0>
  STU_INLINE
  void insertNew(HashCode<UInt64> hashCode, Key key) {
    insert(hashCode,
           [key](const Key& other) STU_INLINE_LAMBDA {
             if constexpr (isEqualityComparable<Key>) {
               STU_DEBUG_ASSERT(key != other);
             }
             discard(key, other);
             return false;
           },
           [&]() STU_INLINE_LAMBDA { return std::move(key); },
           []() STU_INLINE_LAMBDA { return none; });
  }

  template <typename T, EnableIf<hasHasher && hasValue && isType<T>> = 0>
  STU_INLINE
  void insertNew(Key key, T&& value) {
    insertNew(Hasher::hash(key), key, std::forward<T>(value));
  }

  template <typename T, EnableIf<hasValue && isType<T>> = 0>
  STU_INLINE
  void insertNew(HashCode<UInt64> hashCode, Key key, T&& value) {
    insert(hashCode,
           [&](const Key& other) STU_INLINE_LAMBDA {
             if constexpr (isEqualityComparable<Key>) {
               STU_DEBUG_ASSERT(key != other);
             }
             discard(key, other);
             return false;
           },
           [&]() STU_INLINE_LAMBDA { return std::move(key); },
           [&]() STU_INLINE_LAMBDA { return std::forward<T>(value); });
  }

private:
  STU_INLINE
  bool shouldGrow() const {
    return count() + count()/2 >= buckets_.count();
  }

  using Base::needToTrackBucketWhenResizingArrayAfterInsert;
  using Base::insertBucketsIntoZeroInitializedArray;
  using typename Base::InsertBucketsResult;

  template <bool enable = !needToTrackBucketWhenResizingArrayAfterInsert, EnableIf<enable> = 0>
  STU_NO_INLINE 
  void grow() {
    Array<Bucket, AllocatorRef> newBuckets{zeroInitialized,
                                           Count{buckets().count()*2}, buckets_.allocator()};
    Int count;
    if constexpr (isBitwiseCopyable<Bucket>) {
      count = insertBucketsIntoZeroInitializedArray(buckets(), newBuckets);
    } else {
      const Int bucketCount = buckets_.count();
      count = insertBucketsIntoZeroInitializedArray({std::move(buckets_), bucketCount}, newBuckets);
    }
    STU_ASSERT(count == count_);
    buckets_ = std::move(newBuckets);
  }

  template <bool enable = needToTrackBucketWhenResizingArrayAfterInsert, EnableIf<enable> = 0>
  STU_NO_INLINE
  Bucket* grow(const Bucket* trackedBucket) {
    Array<Bucket, AllocatorRef> newBuckets{zeroInitialized,
                                           Count{buckets().count()*2}, buckets_.allocator()};
    InsertBucketsResult result;
    if constexpr (isBitwiseCopyable<Bucket>) {
      result = insertBucketsIntoZeroInitializedArray(buckets(), trackedBucket, newBuckets);
    } else {
      const Int bucketCount = buckets_.count();
      result = insertBucketsIntoZeroInitializedArray(std::move(buckets_), bucketCount,
                                                     trackedBucket, newBuckets);
    }
    STU_ASSERT(result.count == count_);
    buckets_ = std::move(newBuckets);
    return result.trackedBucket;
  }
};

} // namespace stu_label

namespace stu_label {

template <typename T>
STU_CONSTEXPR
auto isEqualTo(T value) {
  return [value = std::move(value)]
         (const T& other) STU_INLINE_LAMBDA {
            return value == other;
         };
};

template <typename Key, typename AllocatorRef>
using HashSet = HashTable<Key, NoType, AllocatorRef>;

template <typename Index>
using TempIndexHashSet = HashSet<Index, ThreadLocalAllocatorRef>;

namespace detail {

template <typename Key, typename Value, typename Hasher>
struct HashTableBase {

  static constexpr bool hasValue  = isType<Value>;
  static constexpr bool hasHasher = isType<Hasher>;
  static constexpr bool storesHashCodes = !hasHasher;

  using KeyHashCode = Conditional<storesHashCodes,
                                  HashCode<UInt_<8*min(sizeof(Key), sizeof(Int))>>,
                                  HashCode<UInt>>;
  using StoredHashCodeValue = Conditional<storesHashCodes, typename KeyHashCode::Value, NoType>;

  using Bucket = Conditional<hasValue,
                             HashTableBucket<Key, StoredHashCodeValue, Value>,
                             HashTableBucket<Key, StoredHashCodeValue>>;


  using KeyRef = Conditional<isInteger<Key> || isPointer<Key>, Key, const Key&>;
  using KeyOrValue = Conditional<hasValue, Value&, KeyRef>;

  static constexpr bool needToTrackBucketWhenResizingArrayAfterInsert = !isSame<KeyOrValue, Key>;

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
    void initWithHashCode(KeyHashCode hashCode) {
      index_ = hashCode.value & mask_;
      counter_ = 0;
    }

    STU_INLINE
    Bucket& nextBucket() {
      Bucket& bucket = buckets_[index_];
      index_ = (index_ + ++counter_) & mask_;
      return bucket;
    }
  };

  using OldBuckets = Conditional<isBitwiseCopyable<Bucket>, ArrayRef<const Bucket>,
                                 ArrayRef<Bucket>>;

  struct OldBucketWithTrackedBucket : OldBuckets {
    const Bucket* trackedBucket;
  };

  struct CountAndTrackedBucket {
    Int count;
    Bucket* trackedBucket;
  };

  using MoveBucketsFirstArg = Conditional<needToTrackBucketWhenResizingArrayAfterInsert, OldBucketWithTrackedBucket,
                                          OldBuckets>;

  using InsertBucketsResult = Conditional<needToTrackBucketWhenResizingArrayAfterInsert, CountAndTrackedBucket, Int>;

  /// Also destroys the old buckets if `!isBitwiseCopyable<Bucket>`.
  STU_NO_INLINE
  static InsertBucketsResult moveBucketsIntoZeroInitializedArrayImpl(
                                MoveBucketsFirstArg oldBuckets, ArrayRef<Bucket> newBuckets)
  {
    constexpr bool destroyOldBuckets = !isBitwiseCopyable<Bucket>;
    static_assert(!destroyOldBuckets || !isConst<typename MoveBucketsFirstArg::Value>);
    Prober prober{newBuckets};
    Int count = 0;
    Bucket* newTrackedBucket = nullptr;
    for (auto& oldBucket : oldBuckets) {
      if (!oldBucket.isEmpty()) {
        ++count;
        KeyHashCode hashCode;
        if constexpr (storesHashCodes) {
          hashCode = oldBucket.hashCode;
        } else {
          hashCode = Hasher::hash(oldBucket.keyPlus1 - 1);
        }
        prober.initWithHashCode(hashCode);
        for (;;) {
          Bucket& newBucket = prober.nextBucket();
          if (!newBucket.isEmpty()) {
            STU_DEBUG_ASSERT(oldBucket.key() != newBucket.key());
            continue;
          }
          if constexpr (!isInteger<Key>) {
            newBucket.key_ = std::move(oldBucket.key_);
          } else {
            newBucket.keyPlus1 = oldBucket.keyPlus1;
          }
          if constexpr (storesHashCodes) {
            newBucket.hashCode = oldBucket.hashCode;
          }
          if constexpr (hasValue) {
            newBucket.value = std::move(oldBucket.value);
          }
          if constexpr (needToTrackBucketWhenResizingArrayAfterInsert) {
            if (&oldBucket == oldBuckets.trackedBucket) {
              newTrackedBucket = &newBucket;
            }
          }
          break;
        } // for (;;)
      }
      if constexpr (destroyOldBuckets) {
        oldBucket.~Bucket();
      }
    } // for
    if constexpr (needToTrackBucketWhenResizingArrayAfterInsert) {
      return {count, newTrackedBucket};
    } else {
      return count;
    }
  }

  template <bool enable = needToTrackBucketWhenResizingArrayAfterInsert, EnableIf<enable> = 0>
  STU_INLINE
  static Int moveBucketsIntoZeroInitializedArrayImpl(OldBuckets oldBuckets,
                                                     ArrayRef<Bucket> newBuckets)
  {
    return moveBucketsIntoZeroInitializedArrayImpl({oldBuckets, nullptr}, newBuckets).count;
  }

  template <bool enable = isBitwiseCopyable<Bucket>, EnableIf<enable> = 0>
  STU_INLINE
  static Int insertBucketsIntoZeroInitializedArray(ArrayRef<const Bucket> oldBuckets,
                                                   ArrayRef<Bucket> newBuckets)
  {
    return moveBucketsIntoZeroInitializedArrayImpl(oldBuckets, newBuckets);
  }

  template <bool enable = isBitwiseCopyable<Bucket> && needToTrackBucketWhenResizingArrayAfterInsert,
            EnableIf<enable> = 0>
  STU_INLINE
  static CountAndTrackedBucket insertBucketsIntoZeroInitializedArray(
                                 ArrayRef<const Bucket> oldBuckets, const Bucket* trackedOldBucket,
                                 ArrayRef<Bucket> newBuckets)
  {
    return moveBucketsIntoZeroInitializedArrayImpl({oldBuckets, trackedOldBucket}, newBuckets);
  }

  template <typename AllocatorRef>
  STU_INLINE
  static Int insertBucketsIntoZeroInitializedArray(Array<Bucket, AllocatorRef>&& oldBuckets,
                                                   Int oldInitializedCount,
                                                   ArrayRef<Bucket> newBuckets)
  {
    const auto result = moveBucketsIntoZeroInitializedArrayImpl(
                          ArrayRef{oldBuckets.begin(), oldInitializedCount}, newBuckets);
    oldBuckets.allocator().deallocate(oldBuckets.begin(), oldBuckets.count());
    discard(std::move(oldBuckets).toNonOwningArrayRef());
    return result;
  }

  template <typename AllocatorRef,
            EnableIf<needToTrackBucketWhenResizingArrayAfterInsert && isType<AllocatorRef>> = 0>
  STU_INLINE
  static CountAndTrackedBucket insertBucketsIntoZeroInitializedArray(
                                 Array<Bucket, AllocatorRef>&& oldBuckets,
                                 Int oldInitializedCount,
                                 const Bucket* trackedOldBucket,
                                 ArrayRef<Bucket> newBuckets)
  {
    const auto result = moveBucketsIntoZeroInitializedArrayImpl(
                          {ArrayRef{oldBuckets.begin(), oldInitializedCount}, trackedOldBucket},
                          newBuckets);
    oldBuckets.allocator().deallocate(oldBuckets.begin(), oldBuckets.count());
    discard(std::move(oldBuckets).toNonOwningArrayRef());
    return result;
  }
};

} // namespace detail

extern template class HashTable<UInt16, NoType, Malloc>;
extern template class HashTable<UInt16, NoType, ThreadLocalAllocatorRef>;

} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
