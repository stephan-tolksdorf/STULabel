
#import "STUDefines.h"

#import <UIKit/UIKit.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef NS_ENUM(uint8_t, STUFirstLineOffsetType) {
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
  NS_REFINED_FOR_SWIFT;

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUParagraphStyleBuilder *builder))block;

- (instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

- (void)encodeWithCoder:(NSCoder *)encoder;

@property (readonly) STUFirstLineOffsetType firstLineOffsetType;

@property (readonly) CGFloat firstLineOffset;

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

STU_EXPORT
@interface STUParagraphStyleBuilder : NSObject

- (instancetype)initWithParagraphStyle:(nullable STUParagraphStyle *)paragraphStyle
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (void)setFirstLineOffset:(CGFloat)firstLineOffset
                      type:(STUFirstLineOffsetType)firstLineOffsetType;

@property (nonatomic, readonly) STUFirstLineOffsetType firstLineOffsetType;

@property (nonatomic, readonly) CGFloat firstLineOffset;


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

