// Copyright 2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, STULabelHorizontalAlignment) {
  STULabelHorizontalAlignmentLeft   = 0,
  STULabelHorizontalAlignmentRight  = 1,
  STULabelHorizontalAlignmentCenter = 2
};

typedef NS_ENUM(uint8_t, STULabelVerticalAlignment) {
  STULabelVerticalAlignmentTop             = 0,
  STULabelVerticalAlignmentBottom          = 1,
  STULabelVerticalAlignmentCenter          = 2,
  STULabelVerticalAlignmentCenterCapHeight = 3,
  STULabelVerticalAlignmentCenterXHeight   = 4
};
enum { STULabelVerticalAlignmentBitSize STU_SWIFT_UNAVAILABLE = 3 };

/// Alignment mode for text paragraphs that have no associated `NSParagraphStyle` attribute
/// or have a paragraph style attribute whose `baseWritingDirection` property is `.natural` and
/// whose `textAlignment` property is `.natural` or `.justified`. (If either of these two properties
/// has a different value, it determines the paragraph's alignment.)
typedef NS_ENUM(uint8_t, STULabelDefaultTextAlignment) {
  /// Left-aligned if the label's `effectiveUserInterfaceLayoutDirection` is `.leftToRight`,
  /// otherwise right-aligned.
  STULabelDefaultTextAlignmentLeading   = 0,
  /// Right-aligned if the label's `effectiveUserInterfaceLayoutDirection` is `.leftToRight`,
  /// otherwise left-aligned.
  STULabelDefaultTextAlignmentTrailing  = 1,
  /// Left-aligned if the paragraph's detected base writing direction is left-to-right,
  /// otherwise right-aligned.
  STULabelDefaultTextAlignmentTextStart = 2,
  /// Right-aligned if the paragraph's detected base writing direction is left-to-right,
  /// otherwise left-aligned.
  STULabelDefaultTextAlignmentTextEnd   = 3
};
enum { STULabelDefaultTextAlignmentBitSize STU_SWIFT_UNAVAILABLE = 2 };
