// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

class IntervalSearchTable {
  const Float32* values_;
  Int count_;
public:
  static constexpr UInt arrayElementSize = 2*sizeof(Float32);

  STU_CONSTEXPR
  static UInt sizeInBytesForCount(Int count) { return arrayElementSize*sign_cast(count); };

  /// `increasingStartValues` and `increasingEndValues` must contain the (non-strictly)
  /// monotonically increasing start and end value of the intervals to search.
  ///
  /// \pre
  ///   `increasingEndValues.end()   == increasingStartValues.start()`,
  ///   `increasingEndValues.count() == increasingStartValues.count()`
  STU_INLINE
  IntervalSearchTable(ArrayRef<const Float32> increasingEndValues,
                      ArrayRef<const Float32> increasingStartValues)

  : values_{increasingEndValues.begin()},
    count_{increasingEndValues.count()}
  {
    STU_PRECONDITION(increasingEndValues.end()   == increasingStartValues.begin());
    STU_PRECONDITION(increasingEndValues.count() == increasingStartValues.count());
    discard(increasingStartValues);
  }

  ArrayRef<const Float32> endValues() const {
    return {values_, count_, unchecked};
  }

  ArrayRef<const Float32> startValues() const {
    return {values_ + count_, count_, unchecked};
  };


  Range<Int> indexRange(Range<Float32> yRange) const;
};


} // namespace stu_label

#include "UndefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"
