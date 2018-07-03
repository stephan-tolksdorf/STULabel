// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyle.hpp"

#import "stu/FunctionRef.hpp"

namespace stu_label {

struct TextFrame;
struct TextFrameParagraph;

struct ShouldStop {
  bool value;

  STU_CONSTEXPR ShouldStop() : value{false} {}
  STU_CONSTEXPR explicit ShouldStop(bool value) : value{value} {}

  STU_CONSTEXPR explicit operator bool() const { return value; }
  STU_CONSTEXPR bool operator==(ShouldStop other) { return value == other.value; }
  STU_CONSTEXPR bool operator!=(ShouldStop other) { return !(*this == other); }
};
constexpr ShouldStop stop = ShouldStop{true};

struct StyledStringRange {
  Range<Int32> stringRange;
  int32_t offsetInTruncatedString;
  bool isTruncationTokenRange;
};

namespace detail {

ShouldStop forEachStyledStringRange(
             const TextFrame& textFrame,
             const TextFrameParagraph& paragraph, Range<Int32> lineIndexRange,
             Optional<TextStyleOverride&> styleOverride,
             FunctionRef<ShouldStop(const TextStyle&, StyledStringRange)> body);
}

} // namespace stu_label
