// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTruncationScope.h"

@interface STUTruncationScope () {
@package
  NSRange _truncatableStringRange;
  int32_t _maximumNumberOfLines;
  CTLineTruncationType _lastLineTruncationMode;
  NSAttributedString* __nullable _truncationToken;
  NSAttributedString* __nullable _fixedTruncationToken;
}
@end
