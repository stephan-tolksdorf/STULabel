// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

namespace stu_label {

class IntervalSearchTable {
  const stu::Float32* values_;
  stu::Int count_;
public:
  static constexpr stu::UInt arrayElementSize = 2*sizeof(stu::Float32);

  STU_CONSTEXPR
  static stu::UInt sizeInBytesForCount(stu::Int count) { return arrayElementSize*sign_cast(count); };

  /// `increasingStartValues` and `increasingEndValues` must contain the (non-strictly)
  /// monotonically increasing start and end value of the intervals to search.
  ///
  /// \pre
  ///   `increasingEndValues.end()   == increasingStartValues.start()`,
  ///   `increasingEndValues.count() == increasingStartValues.count()`
  STU_INLINE
  IntervalSearchTable(ArrayRef<const stu::Float32> increasingEndValues,
                      ArrayRef<const stu::Float32> increasingStartValues)

  : values_{increasingEndValues.begin()},
    count_{increasingEndValues.count()}
  {
    STU_PRECONDITION(increasingEndValues.end()   == increasingStartValues.begin());
    STU_PRECONDITION(increasingEndValues.count() == increasingStartValues.count());
    discard(increasingStartValues);
  }

  ArrayRef<const stu::Float32> endValues() const {
    return {values_, count_, unchecked};
  }

  ArrayRef<const stu::Float32> startValues() const {
    return {values_ + count_, count_, unchecked};
  };


  Range<stu::Int> indexRange(Range<stu::Float32> yRange) const;
};


} // namespace stu_label
