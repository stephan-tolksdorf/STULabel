
#import "STUDefines.h"

#import <UIKit/UIKit.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef NS_CLOSED_ENUM(uint8_t, STUFirstLineOffsetType) {
  /// Offset of the first baseline from the default position.
  STUOffsetOfFirstBaselineFromDefault = 0,

  /// Offset of the first baseline from the top of the paragraph.
  ///
  /// The offset value must be non-negative.
  STUOffsetOfFirstBaselineFromTop = 1,

  /// Offset from the top of the paragraph to the vertical center of the first text line's layout
  /// bounds.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY
  ///        + (line.heightBelowBaseline - line.heightAboveBaseline)/2
  ///        - paragraph.minY
  /// @endcode
  ///
  /// See the documentation for the @c STUTextLayoutMode cases for a definition of a line's
  /// @c heightAboveBaseline and @c heightBelowBaseline.
  ///
  /// The offset value must be non-negative.
  STUOffsetOfFirstLineCenterFromTop = 2,

  /// Offset from the top of the paragraph to the the vertical center above the baseline of the
  /// first text line's (largest) uppercase letters.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY - line.maxCapHeight/2 - paragraph.minY
  /// @endcode
  ///
  /// The offset value must be non-negative.
  STUOffsetOfFirstLineCapHeightCenterFromTop = 3,

  /// Offset from the top of the paragraph to the vertical center above the baseline of the first
  /// text line's (largest) lowercase letters.
  ///
  /// Definition:
  /// @code
  /// offset = line.baselineY - line.maxXHeight/2 - paragraph.minY
  /// @endcode
  ///
  /// The offset value must be non-negative.
  STUOffsetOfFirstLineXHeightCenterFromTop = 4
};

/// The attributed string key for the @c STUParagraphStyle attribute.
NS_SWIFT_NAME(stuParagraphStyle)
extern const NSAttributedStringKey STUParagraphStyleAttributeName;

@class STUParagraphStyleBuilder;

/// Instances of this immutable class can be used in attributed strings to specify some
/// paragraph style properties that cannot be set with an @c NSParagraphStyle.
///
/// Use the key @c STUParagraphStyleAttributeName (@c stuParagraphStyle) when adding this attribute
/// to an attributed string.
STU_EXPORT
@interface STUParagraphStyle : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithBuilder:(nullable STUParagraphStyleBuilder *)builder
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUParagraphStyleBuilder *builder))block
  // NS_SWIFT_NAME(init(_:)) // https://bugs.swift.org/browse/SR-6894
  // Use Swift's trailing closure syntax when calling this initializer.
  NS_REFINED_FOR_SWIFT;

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUParagraphStyleBuilder *builder))block;

- (instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

- (void)encodeWithCoder:(NSCoder *)encoder;

@property (readonly) STUFirstLineOffsetType firstLineOffsetType NS_REFINED_FOR_SWIFT;

@property (readonly) CGFloat firstLineOffset NS_REFINED_FOR_SWIFT;

/// The minimum vertical distance between adjacent baselines in the paragraph.
///
/// Setting a @c minimumBaselineDistance greater than the default line height is a convenient way
/// to ensure a constant baseline distance even if the text lines have different ascent to descent
/// proportions. (See the documentation of @c STUTextLayoutMode for a specification of how the
/// layout algorithm calculates the default line height.)
///
/// If the @c minimumBaselineDistance is greater than the default line height, half the difference
/// will be added as additional spacing both before the first line and after the last line in the
/// paragraph. (So that e.g. the text of multiple vertically adjacent labels views with the same
/// @c minimumBaselineDistance will appear approximately evenly spaced.) If you don't want the
/// first baseline of the paragraph pushed down by an increased @c minimumBaselineDistance,
/// you can can counter this by specifying an appropriate @c firstLineOffset.
///
/// The maximum @c minimumBaselineDistance of two adjacent paragraphs determines the effective
/// minimum baseline distance between the last baseline of the leading paragraph and the first
/// baseline of the following paragraph, except if the following paragraph has
/// a non-default @c firstLineOffsetType or the @c firstLineOffset is negative.
///
/// The setter of this property replaces negative values with zero.
///
/// @note Any display scale rounding of baseline coordinates happens @b after minimum baseline
///       distances have been applied.
@property (readonly) CGFloat minimumBaselineDistance;

/// If this value is greater than zero, it dermines the maximum number of lines at the beginning of
/// the paragraph (the "initial lines") that should be indented as specified by
/// @c initialLinesHeadIndent and @c initialLinesTailIndent.
///
/// If this value is greater than zero, any indentation specified by an @c NSParagraphStyle
/// will not apply to the initial lines (but @c headIndent and @c tailIndent still apply to the
/// following lines).
///
/// Setting an @c numberOfInitialLines value greater than 1 can be useful e.g. for reserving space
/// for an icon or "drop cap" at the top of a paragraph.
///
/// If this property is zero, it has no effect.
@property (readonly) NSInteger numberOfInitialLines;

/// This value determines the indentation of the initial lines of the paragraph on the left (right)
/// side if the paragraph's base writing direction is left-to-right (right-to-left).
///
/// The setter of this property replaces negatives values with zero.
@property (readonly) CGFloat initialLinesHeadIndent;

/// This value determines the indentation of the initial lines of the paragraph on the right (left)
/// side if the paragraph's base writing direction is left-to-right (right-to-left).
///
/// Following the @c NSLayoutConvention.tailIndent convention, the indentation is specified as a
/// @b negative @b value.
@property (readonly) CGFloat initialLinesTailIndent;

@end

/// Equality for @c STUParagraphStyleBuilder instances is defined as pointer equality.
STU_EXPORT
@interface STUParagraphStyleBuilder : NSObject

- (instancetype)initWithParagraphStyle:(nullable STUParagraphStyle *)paragraphStyle
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (void)setFirstLineOffset:(CGFloat)firstLineOffset
                      type:(STUFirstLineOffsetType)firstLineOffsetType
  NS_REFINED_FOR_SWIFT;

@property (nonatomic, readonly) STUFirstLineOffsetType firstLineOffsetType NS_REFINED_FOR_SWIFT;

@property (nonatomic, readonly) CGFloat firstLineOffset NS_REFINED_FOR_SWIFT;

/// The minimum vertical distance between adjacent baselines in the paragraph.
///
/// Setting a @c minimumBaselineDistance greater than the default line height is a convenient way
/// to ensure a constant baseline distance even if the text lines have different ascent to descent
/// proportions. (See the documentation of @c STUTextLayoutMode for a specification of how the
/// layout algorithm calculates the default line height.)
///
/// If the @c minimumBaselineDistance is greater than the default line height, half the difference
/// will be added as additional spacing both before the first line and after the last line in the
/// paragraph. (So that e.g. the text of multiple vertically adjacent labels views with the same
/// @c minimumBaselineDistance will appear approximately evenly spaced.) If you don't want the
/// first baseline of the paragraph pushed down by an increased @c minimumBaselineDistance,
/// you can can counter this by specifying an appropriate @c firstLineOffset.
///
/// The maximum @c minimumBaselineDistance of two adjacent paragraphs determines the effective
/// minimum baseline distance between the last baseline of the leading paragraph and the first
/// baseline of the following paragraph, except if the following paragraph has
/// a non-default @c firstLineOffsetType or the @c firstLineOffset is negative.
///
/// The setter of this property replaces negative values with zero.
///
/// @note Any display scale rounding of baseline coordinates happens @b after minimum baseline
///       distances have been applied.
@property (nonatomic) CGFloat minimumBaselineDistance;

/// If this value is greater than zero, it dermines the maximum number of lines at the beginning of
/// the paragraph (the "initial lines") that should be indented as specified by
/// @c initialLinesHeadIndent and @c initialLinesTailIndent.
///
/// If this value is greater than zero, any indentation specified by an @c NSParagraphStyle
/// will not apply to the initial lines (but @c headIndent and @c tailIndent still apply to the
/// following lines).
///
/// Setting an @c numberOfInitialLines value greater than 1 can be useful e.g. for reserving space
/// for an icon or "drop cap" at the top of a paragraph.
///
/// If this property is zero, it has no effect.
///
/// The setter of this property replaces negatives values with zero.
@property (nonatomic) NSInteger numberOfInitialLines;

/// This value determines the indentation of the initial lines of the paragraph on the left (right)
/// side if the paragraph's base writing direction is left-to-right (right-to-left).
///
/// The setter of this property replaces negatives values with zero.
///
/// If @c numberOfInitialLines is zero, this property has no effect.
@property (nonatomic) CGFloat initialLinesHeadIndent;

/// This value determines the indentation of the initial lines of the paragraph on the right (left)
/// side if the paragraph's base writing direction is left-to-right (right-to-left).
///
/// Following the @c NSLayoutConvention.tailIndent convention, the indentation is specified as a
/// @b negative @b value.
///
/// The setter of this property replaces positive values with zero.
///
/// If @c numberOfInitialLines is zero, this property has no effect.
@property (nonatomic) CGFloat initialLinesTailIndent;

@end

STU_ASSUME_NONNULL_AND_STRONG_END

