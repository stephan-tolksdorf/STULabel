// Copyright 2017–2018 Stephan Tolksdorf

#import "ThreadLocalAllocator.hpp"

namespace stu_label {

/// Merges adjacent intervals.
template <typename Bound>
class SortedIntervalBuffer {
  TempVector<Range<Bound>> array_;
  Int previousIndex_{};

public:
  SortedIntervalBuffer(MaxInitialCapacity capacity)
  : array_{capacity}
  {}

  STU_INLINE ArrayRef<const Range<Bound>> intervals() const { return array_; };

  STU_INLINE Int capacity() const { return array_.capacity(); }
  STU_INLINE void setCapacity(Int capacity) { array_.setCapacity(capacity); }

  /// Merges adjacent intervals, discards empty intervals.
  void add(Range<Bound> interval);

  STU_INLINE operator TempArray<Range<CGFloat>>() && { return std::move(array_); }
};

template <typename Bound>
void SortedIntervalBuffer<Bound>::add(Range<Bound> interval) {
  if (interval.isEmpty()) return;
  Int count = array_.count();
  Int i = previousIndex_;
  if (count > 0) {
    STU_ASSERT(0 <= i && i < count);
    if (interval.start > array_[i].end) {
      do ++i;
      while (i < count && interval.start > array_[i].end);
    } else {
      while (i > 0 && interval.start <= array_[i - 1].end) {
        --i;
      }
    }
  }
  // array_[i - 1].end < interval.start <= array_[i].end
  if (i == count || interval.end < array_[i].start) {
    array_.insert(i, interval);
    return;
  }
  // array_[i].start <= interval.end
  // Replace existing interval(s).
  Int j = i;
  while (j + 1 < count && interval.end >= array_[j + 1].start) {
    ++j;
  }
  // array_[j].start <= interval.end < array_[j + 1].start
  array_[i].start = min(interval.start, array_[i].start);
  array_[i].end = max(interval.end, array_[j].end);
  previousIndex_ = i;
  array_.removeRange({i + 1, j + 1});
}

extern template class SortedIntervalBuffer<CGFloat>;

} // stu_label

