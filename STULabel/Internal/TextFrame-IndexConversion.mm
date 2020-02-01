// Copyright 2017–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

#import "stu/BinarySearch.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

TextFrameIndex TextFrame::index(IndexInOriginalString unsignedIndexInOriginalString,
                                IndexInTruncationToken indexInTruncationToken) const
{
  const Range<UInt32> fullRangeInOriginalString = Range<UInt32>(rangeInOriginalString());
  if (unsignedIndexInOriginalString >= fullRangeInOriginalString.end) {
    return endIndex();
  }
  if (unsignedIndexInOriginalString <= fullRangeInOriginalString.start) {
    if (indexInTruncationToken <= 0u) {
      return TextFrameIndex{};
    }
    unsignedIndexInOriginalString.value = fullRangeInOriginalString.start;
  }
  const Int32 indexInOriginalString = static_cast<Int32>(unsignedIndexInOriginalString.value);
  const Int32 lineIndex = narrow_cast<Int32>(
                            binarySearchFirstIndexWhere(lineStringIndices(),
                              [&](const StringStartIndices& si)
                              { return si.startIndexInOriginalString > indexInOriginalString; }
                            ).indexOrArrayCount - 1);
  const Int32 paraIndex = lines()[lineIndex].paragraphIndex;
  const TextFrameParagraph& para = paragraphs()[paraIndex];
  Int32 index;
  if (indexInOriginalString < para.excisedRangeInOriginalString().start) {
    index = para.rangeInTruncatedString.start
          + (indexInOriginalString - para.rangeInOriginalString.start);
  } else if (indexInOriginalString >= para.excisedRangeInOriginalString().end
             && indexInOriginalString < para.rangeInOriginalString.end)
  {
    index = para.rangeInTruncatedString.end
          + (indexInOriginalString - para.rangeInOriginalString.end);
  } else {
    if (STU_UNLIKELY(indexInOriginalString >= para.rangeInOriginalString.end)) {
      STU_ASSERT(indexInOriginalString >= para.excisedRangeInOriginalString().end
                 && para.excisedStringRangeIsContinuedInNextParagraph);
      auto* p = &para + 1;
      while (indexInOriginalString >= p->rangeInOriginalString.end) {
        STU_ASSERT(p->excisedStringRangeIsContinuedInNextParagraph);
        ++p;
      }
      if (indexInOriginalString >= p->excisedRangeInOriginalString().end) {
        index = p->rangeInTruncatedString.end
              + (indexInOriginalString - p->rangeInOriginalString.end);
        goto Return;
      }
    }
    index = para.rangeOfTruncationTokenInTruncatedString().start
          + narrow_cast<Int32>(min(indexInTruncationToken.value,
                                   sign_cast(para.truncationTokenLength)));
  }
Return:
  return STUTextFrameIndex{.indexInTruncatedString = sign_cast(index),
                           .lineIndex = sign_cast(lineIndex)};
}

TextFrameIndex TextFrame::index(IndexInTruncatedString unsignedIndexInTruncatedString) const {
  if (unsignedIndexInTruncatedString >= sign_cast(truncatedStringLength)) {
    return endIndex();
  }
  if (unsignedIndexInTruncatedString == 0u) {
    return TextFrameIndex{};
  }
  const Int32 indexInTruncatedString = static_cast<Int32>(unsignedIndexInTruncatedString.value);
  const Int32 lineIndex = narrow_cast<Int32>(
                            binarySearchFirstIndexWhere(lineStringIndices(),
                              [&](const StringStartIndices& si)
                              { return si.startIndexInTruncatedString > indexInTruncatedString; }
                            ).indexOrArrayCount - 1);
  STU_DEBUG_ASSERT(0 <= lineIndex && lineIndex < lineCount);
  return STUTextFrameIndex{.indexInTruncatedString = sign_cast(indexInTruncatedString),
                           .lineIndex = sign_cast(lineIndex)};
}

Range<TextFrameIndex> TextFrame::range(RangeInOriginalString<NSRange> rangeInOriginalString) const {
  const NSRange range = rangeInOriginalString.value;
  NSUInteger rangeEnd;
  if (__builtin_add_overflow(range.location, range.length, &rangeEnd)) {
    rangeEnd = NSUIntegerMax;
  }
  if (Range<UInt>(range.location, rangeEnd).contains(this->rangeInOriginalString())) {
    return STUTextFrameRange{TextFrameIndex{}, endIndex()};
  }
  const auto start = index(IndexInOriginalString{range.location}, IndexInTruncationToken{});
  const auto end = range.location == rangeEnd ? start
                 : index(IndexInOriginalString{rangeEnd},
                         IndexInTruncationToken{UInt32{INT32_MAX}});
  return TextFrameRange{start, end};
}

Range<TextFrameIndex> TextFrame::range(RangeInTruncatedString<NSRange> rangeInTruncatedString) const {
  const NSRange range = rangeInTruncatedString.value;
  if (range.location == 0 && range.length >= sign_cast(truncatedStringLength)) {
    return TextFrameRange{TextFrameIndex{}, endIndex()};
  }
  const auto start = index(IndexInTruncatedString{range.location});
  TextFrameIndex end;
  if (range.length == 0) {
    end = start;
  } else {
    NSUInteger rangeEnd;
    if (__builtin_add_overflow(range.location, range.length, &rangeEnd)) {
      rangeEnd = NSUIntegerMax;
    }
    end = index(IndexInTruncatedString{rangeEnd});
  }
  return STUTextFrameRange{start, end};
}

Optional<TextFrameIndex> TextFrame::normalize(TextFrameIndex index) const {
  const Int32 indexInTruncatedString = sign_cast(index.indexInTruncatedString);
  const UInt32 lineIndex = index.lineIndex;
  if (STU_LIKELY(lineIndex < sign_cast(lineCount))) {
    const StringStartIndices* const indices = this->lineStringIndices().begin();
    const Int32 start = indices[lineIndex].startIndexInTruncatedString;
    const Int32 end = indices[lineIndex + 1].startIndexInTruncatedString;
    if (start <= indexInTruncatedString) {
      if (indexInTruncatedString < end) {
        if (!index.isIndexOfInsertedHyphen
            || (indexInTruncatedString == end - 1 && lines().begin()[lineIndex].hasInsertedHyphen))
        {
          return index;
        }
      } else if (indexInTruncatedString == end) {
        return TextFrameIndex{.isIndexOfInsertedHyphen = index.isIndexOfInsertedHyphen,
                              .indexInTruncatedString = index.indexInTruncatedString,
                              .lineIndex = min(lineIndex + 1, sign_cast(lineCount) - 1)};
      }
    }
  } else if (lineCount == 0 && index == TextFrameIndex{}) {
    return index;
  }
  return none;
}

Range<Int32>
TextFrame::rangeInOriginalString(STUTextFrameIndex index,
                                 Optional<Out<TruncationTokenIndex>> outTokenIndex) const
{
  if (const auto normalizedIndex = normalize(index)) {
    index = *normalizedIndex;
  } else {
    STU_CHECK_MSG(false, "Invalid STUTextFrameIndex");
  }
  const Int32 indexInTruncatedString = sign_cast(index.indexInTruncatedString);
  if (indexInTruncatedString == truncatedStringLength) {
    if (outTokenIndex) {
      *outTokenIndex = TruncationTokenIndex{};
    }
    return {rangeInOriginalString().end, Count{0}};
  }
  const UInt32 lineIndex = index.lineIndex;
  const TextFrameLine& line = lines().begin()[lineIndex];
  Int32 indexInOriginalString;
  if (!line.hasTruncationToken && indexInTruncatedString <= line.rangeInTruncatedString.end) {
    indexInOriginalString = line.rangeInOriginalString.start
                          + (indexInTruncatedString - line.rangeInTruncatedString.start)
                          + index.isIndexOfInsertedHyphen;
  } else {
    const TextFrameParagraph& para = paragraphs().begin()[line.paragraphIndex];
    const Range<Int32> tokenRange = para.rangeOfTruncationTokenInTruncatedString();
    if (indexInTruncatedString < tokenRange.start) {
      indexInOriginalString = para.rangeInOriginalString.start
                            + (indexInTruncatedString - para.rangeInTruncatedString.start);
    } else if (indexInTruncatedString >= tokenRange.end) {
      const TextFrameParagraph* p = &para;
      while (p->rangeInTruncatedString.end < indexInTruncatedString) {
        STU_ASSERT(p->excisedStringRangeIsContinuedInNextParagraph);
        p += 1;
      }
      indexInOriginalString = p->rangeInOriginalString.end
                            + (indexInTruncatedString - p->rangeInTruncatedString.end);
    } else {
      const Int32 start = para.excisedRangeInOriginalString().start;
      const TextFrameParagraph* lastPara = &para;
      while (lastPara->excisedStringRangeIsContinuedInNextParagraph) {
        ++lastPara;
      }
      const Int32 end = lastPara->excisedRangeInOriginalString().end;
      if (outTokenIndex) {
        *outTokenIndex = TruncationTokenIndex{
                           .indexInToken = indexInTruncatedString - tokenRange.start,
                           .tokenLength = para.truncationTokenLength,
                           .truncationToken = para.truncationToken};
      }
      return {start, end};
    }
  }
  if (outTokenIndex) {
    *outTokenIndex = TruncationTokenIndex{};
  }
  return {indexInOriginalString, Count{0}};
}

Range<Int32> TextFrame::rangeInOriginalString(STUTextFrameRange range) const {
  const Range<Int32> startRange = rangeInOriginalString(range.start);
  const Int32 start = startRange.start + range.start.isIndexOfInsertedHyphen;
  const Int32 end = range.end <= range.start
                  ? startRange.end + range.start.isIndexOfInsertedHyphen
                  : rangeInOriginalString(range.end).end + range.end.isIndexOfInsertedHyphen;
  return {start, end};
}

} // stu_label
