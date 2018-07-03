// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttributes.h"

#import "STUBackgroundAttribute-Internal.h"
#import "STUTextAttachment-Internal.hpp"

@interface STUFirstLineInParagraphOffsetAttribute() {
@package
  CGFloat _firstLineOffset;
  STUFirstLineOffsetType _firstLineOffsetType;
}
@end

@interface STUTruncationScopeAttribute () {
@package
  NSRange _truncatableStringRange;
  int32_t _maxLineCount;
  CTLineTruncationType _lastLineTruncationMode;
  NSAttributedString* __nullable _truncationToken;
}
@end

