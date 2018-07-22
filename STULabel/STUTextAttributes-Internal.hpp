// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttributes.h"

#import "STUBackgroundAttribute-Internal.h"
#import "STUParagraphStyle-Internal.hpp"
#import "STUTextAttachment-Internal.hpp"


@interface STUTruncationScopeAttribute () {
@package
  NSRange _truncatableStringRange;
  int32_t _maximumLineCount;
  CTLineTruncationType _lastLineTruncationMode;
  NSAttributedString* __nullable _truncationToken;
  NSAttributedString* __nullable _fixedTruncationToken;
}
@end

