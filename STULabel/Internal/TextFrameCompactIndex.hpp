// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STUTextFrame.h"

namespace stu_label {

using TextFrameIndex = STUTextFrameIndex;

struct IsIndexOfInsertedHyphen : Parameter<IsIndexOfInsertedHyphen> {
  using Parameter::Parameter;
};

struct TextFrameCompactIndex : Comparable<TextFrameCompactIndex> {
  UInt32 bits{};

  TextFrameCompactIndex() = default;

  /* implicit */ STU_CONSTEXPR
  TextFrameCompactIndex(TextFrameIndex index)
  : TextFrameCompactIndex(index.indexInTruncatedString,
                          IsIndexOfInsertedHyphen{index.isIndexOfInsertedHyphen})
  {}

  explicit STU_CONSTEXPR
  TextFrameCompactIndex(Int32 indexInTruncatedString,
                        IsIndexOfInsertedHyphen isIndexOfInsertedHyphen = IsIndexOfInsertedHyphen{false})
  : bits{(sign_cast(indexInTruncatedString) << 1) | static_cast<bool>(isIndexOfInsertedHyphen)}
  {
    STU_DEBUG_ASSERT(indexInTruncatedString >= 0);
  }

  STU_CONSTEXPR
  Int32 indexInTruncatedString() const { return bits >> 1; }

  STU_CONSTEXPR
  bool isIndexOfInsertedHyphen() const { return bits & 1; }

  STU_CONSTEXPR
  bool operator==(TextFrameCompactIndex other) const { return bits == other.bits; }

  STU_CONSTEXPR
  bool operator<(TextFrameCompactIndex other) const { return bits < other.bits; }

  TextFrameIndex withLineIndex(Int32 lineIndex) const {
    return {.indexInTruncatedString = sign_cast(indexInTruncatedString()),
            .isIndexOfInsertedHyphen = isIndexOfInsertedHyphen(),
            .lineIndex = sign_cast(lineIndex)};
  }

};

} // namespace stu_label


template <>
struct stu::RangeBase<stu_label::TextFrameCompactIndex> {
  STU_CONSTEXPR
  Range<Int32> rangeInTruncatedString() const {
    auto& r = static_cast<const Range<stu_label::TextFrameCompactIndex>&>(*this);
    return Range<Int32>{sign_cast((r.start.bits >> 1) + (r.start.bits & 1)),
                        sign_cast((r.end.bits >> 1) + (r.end.bits & 1))};

  }
};



