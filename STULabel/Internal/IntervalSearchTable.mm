// Copyright 2017 Stephan Tolksdorf

#import "IntervalSearchTable.hpp"

#import "stu/BinarySearch.hpp"

namespace stu_label {

Range<Int> IntervalSearchTable::indexRange(Range<Float32> yRange) const {
  const Int start = binarySearchFirstIndexWhere(
                      endValues(), [&](Float32 e) { return e >= yRange.start; }).indexOrArrayCount;
  const Int end = binarySearchFirstIndexWhere(
                    startValues(), [&](Float32 s) { return s > yRange.end; }).indexOrArrayCount;
  return {start, end};
}

} // stu_label
