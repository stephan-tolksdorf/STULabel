// Copyright 2016–2018 Stephan Tolksdorf

#import "STULabel/STUTextFrame-Unsafe.h"

#import "Kerning.hpp"
#import "NSAttributedStringRef.hpp"

namespace stu_label {

struct TruncatableTextLine {
  const NSAttributedStringRef& attributedString;
  Range<Int> stringRange;
  NSArrayRef<CTRun*> runs;
  Float64 width;
  bool isRightToLeftLine;
  Range<Int> truncatableStringRange;
};

#if STU_TRUNCATION_TOKEN_KERNING
struct TokenForKerningPurposes {
  NSArrayRef<CTRun*> runs;
  Float64 width;
  NSAttributedStringRef attributedString;
};
#endif

struct ExcisedGlyphRange {
  Range<Int> stringRange;
  RunGlyphIndex start;
  RunGlyphIndex end;
  Float64 adjustedWidthLeftOfExcision;
  Float64 adjustedWidthRightOfExcision;
};


/// @note
///  The implementation treats any trailing whitespace as regular text.
///  (Which means that you'll likely have to adapt the implementation if you need to truncate
///  CTLine instances that may contain trailing whitespace.)
///
/// @pre line.width > maxWidth
/// @pre line.truncationRange ⊆ line.stringRange
/// @pre line.truncationRange == line.stringRange || line.truncationType != kCTLineTruncationMiddle
ExcisedGlyphRange findRangeToExciseForTruncation(
                    const TruncatableTextLine& line,
                    CTLineTruncationType truncationType, Float64 maxWidth,
                    __nullable STUTruncationRangeAdjuster truncationRangeAdjuster
                  #if STU_TRUNCATION_TOKEN_KERNING
                    , const TokenForKerningPurposes& tokenRuns
                  #endif
                    );

} // namespace stu_label
