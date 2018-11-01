// Copyright 2018 Stephan Tolksdorf

#import "STUTextHighlightStyle.h"
#import "STUTextFrameRange.h"
#import "STUTextRange.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef NS_ENUM(uint32_t, STUTextFrameDrawingMode) {
  STUTextFrameDefaultDrawingMode NS_SWIFT_NAME(default) = 0,
  STUTextFrameDrawOnlyBackground NS_SWIFT_NAME(onlyBackground) = 1,
  STUTextFrameDrawOnlyForeground NS_SWIFT_NAME(onlyForeground) = 2,
} NS_SWIFT_NAME(STUTextFrame.DrawingMode);

NS_SWIFT_NAME(STUTextFrame.DrawingOptions) STU_EXPORT
@interface STUTextFrameDrawingOptions : NSObject <NSCopying>

@property (nonatomic, readonly) bool isFrozen;

- (void)freeze;

// None of the property setters may be called after the object has been frozen.
// (This is checked by an always-on assert).

@property (nonatomic) STUTextFrameDrawingMode drawingMode;

@property (nonatomic, nullable) STUTextHighlightStyle *highlightStyle;

/// Default value: `STUTextRange(range: NSRange(location: 0, length: .max), .rangeInOriginalString)`
@property (nonatomic) STUTextRange highlightRange;

/// @post `self.highlightTextFrameRange == nil`
- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType
  NS_SWIFT_NAME(setHighlightRange(_:type:));

/// Sets the specified STUTextFrameRange as the highlight range.
///
/// @note A @c STUTextFrameDrawingOptions instance with a @c STUTextFrameRange highlight range must
///       only be used together with @c STUTextFrame instances for which the range is valid.
- (void)setHighlightTextFrameRange:(STUTextFrameRange)textFrameRange
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__setHighlightRange(_:));
  // public func setHighlightRange(_ textFrameRange: Range<STUTextFrame.Index>)

- (bool)getHighlightTextFrameRange:(nullable STUTextFrameRange *)outTextFrameRange
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__getHighlightTextFrameRange(_:));
  // public var highlightTextFrameRange: Optional<Range<STUTextFrame.Index>> { get }


/// Default value: true
@property (nonatomic) bool overrideColorsApplyToHighlightedText;

/// Default value: `nil`
@property (nonatomic, nullable) UIColor *overrideTextColor;

/// Default value: `nil`
@property (nonatomic, nullable) UIColor *overrideLinkColor;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
