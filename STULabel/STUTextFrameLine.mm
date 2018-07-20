// Copyright 2016–2018 Stephan Tolksdorf

#import "Internal/TextFrame.hpp"

using namespace stu;
using namespace stu_label;

STU_EXPORT
CGFloat STUTextFrameLineGetCapHeight(const STUTextFrameLine* __nonnull line) {
  return down_cast<const TextFrameLine*>(line)->maxFontMetricValue<FontMetric::capHeight>();
}

STU_EXPORT
CGFloat STUTextFrameLineGetXHeight(const STUTextFrameLine* __nonnull line) {
  return down_cast<const TextFrameLine*>(line)->maxFontMetricValue<FontMetric::xHeight>();
}

STU_EXPORT
STUTextFrameGraphemeClusterRange STUTextFrameLineGetRangeOfGraphemeClusterAtXOffset(
                                   const STUTextFrameLine* __nonnull line, Float64 xOffset)
{
  STU_CHECK_MSG(0 <= xOffset, "xOffset must be non-negative");
  STU_CHECK_MSG(xOffset <= line->width, "xOffset must not be greater than line.width");
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};
  return narrow_cast<STUTextFrameGraphemeClusterRange>(
           down_cast<const TextFrameLine*>(line)->rangeOfGraphemeClusterAtXOffset(xOffset));
}

