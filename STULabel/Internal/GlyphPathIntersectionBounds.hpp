// Copyright 2017–2018 Stephan Tolksdorf

#import "Common.hpp"

namespace stu_label {

struct LowerAndUpperInterval {
  Range<CGFloat> lower;
  Range<CGFloat> upper;
};

/// @brief Finds the x-axis bounds of the intersection of a path with one or two horizontal lines.
///
/// The implementation is optimized for a single line or two lines close to each other, like e.g.
/// text underlines.
///
/// @param lowerLineY The y interval for the lower horizontal line.
/// @param upperLineY
///   The y interval for the upper horizontal line.
///   If this interval has the same min value as lowerLineY, it is ignored and the returned upper
///   interval will always be empty.
/// @param maxError
///   The desired maximum absolute error of the endpoints of the returned intervals.
///   Must be greater than 0.
///
/// @pre lowerLineY.min <= upperLineY.min && lowerLineY.max <= uppeLineY.max
LowerAndUpperInterval findXBoundsOfPathIntersectionWithHorizontalLines(
                        __nonnull CGPathRef path,
                        Range<CGFloat> lowerLineY, Range<CGFloat> upperLineY,
                        CGFloat maxError);

} // namespace stu_label
