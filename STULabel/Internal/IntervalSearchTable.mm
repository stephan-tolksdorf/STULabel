// Copyright 2017 Stephan Tolksdorf

#import "IntervalSearchTable.hpp"

#import "stu/BinarySearch.hpp"

namespace stu_label {

Range<stu::Int> IntervalSearchTable::indexRange(Range<stu::Float32> yRange) const {
  const stu::Int start = binarySearchFirstIndexWhere(
                      endValues(), [&](stu::Float32 e) { return e >= yRange.start; }).indexOrArrayCount;
  const stu::Int end = binarySearchFirstIndexWhere(
                    startValues(), [&](stu::Float32 s) { return s > yRange.end; }).indexOrArrayCount;
  return {start, end};
}

} // stu_label
