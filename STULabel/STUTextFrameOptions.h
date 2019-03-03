// Copyright 2017–2018 Stephan Tolksdorf

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "STUDefines.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef NS_CLOSED_ENUM(uint8_t, STUTextLayoutMode) {
  /// @brief The default layout mode.
  ///
  /// In this mode the layout height of text lines (including line spacing) is calculated as
  /// follows:
  /// @code
  ///
  /// a = The line’s typographic ascent calculated from the line’s
  ///     font metrics both before and after font substitution.
  /// d = The line’s typographic descent calculated from the line’s
  ///     font metrics both before and after font substitution.
  /// g = The line’s typographic leading calculated from the line’s
  ///     font metrics both before and after font substitution.
  ///
  /// p = The line’s associated paragraph style.
  ///
  /// m = (a + d)*p.lineHeightMultiple
  ///     + max(g*p.lineHeightMultiple, p.lineSpacing)
  /// height = min(p.maximumLineHeight, max(p.minimumLineHeight, m))
  /// s = (height - (a + d))/2
  /// heightAboveBaseline = a + s
  /// heightBelowBaseline = d + s
  ///
  /// @endcode
  STUTextLayoutModeDefault = 0,

  /// @brief A layout mode that imitates Text Kit's line layout.
  ///
  /// In this mode the layout height of text lines (including line spacing) is calculated as
  /// follows:
  /// @code
  ///
  /// a = The line's typographic ascent calculated from only the
  ///     original font metrics, ignoring font substitution.
  /// d = The line's typographic descent calculated from only the
  ///     original font metrics, ignoring font substitution.
  /// g = The line's typographic leading calculated from only the
  ///     original font metrics, ignoring font substitution.
  ///
  /// p = The line's associated paragraph style.
  /// h = min(p.maximumLineHeight,
  ///         max((a + d)*p.lineHeightMultiple, p.minimumLineHeight))
  /// s = max(p.lineSpacing, g)
  ///
  /// heightAboveBaseline = h - d
  /// heightBelowBaseline = d + s
  /// height = heightAboveBaseline + heightBelowBaseline
  ///
  /// @endcode
  ///
  /// When @c STULabel and @c STULabelLayer calculate layout bounds in this mode they ignore
  /// any spacing below the last baseline in excess of the line's leading, i.e. they calculate the
  /// layout bounds as if s = g for the last line.
  STUTextLayoutModeTextKit = 1
};
enum { STUTextLayoutModeBitSize STU_SWIFT_UNAVAILABLE = 1 };

/// Alignment mode for text paragraphs that have no associated @c NSParagraphStyle attribute
/// or have a paragraph style attribute whose @c baseWritingDirection property is @c .natural and
/// whose @c textAlignment property is @c .natural or @c .justified.
typedef NS_CLOSED_ENUM(uint8_t, STUDefaultTextAlignment) {
  STUDefaultTextAlignmentLeft  = 0,
  STUDefaultTextAlignmentRight = 1,
  /// Left-aligned if the paragraph's detected base writing direction is left-to-right,
  /// otherwise right-aligned.
  STUDefaultTextAlignmentStart = 2,
  /// Right-aligned if the paragraph's detected base writing direction is left-to-right,
  /// otherwise left-aligned.
  STUDefaultTextAlignmentEnd   = 3
};

typedef NS_CLOSED_ENUM(uint8_t, STULastLineTruncationMode) {
  STULastLineTruncationModeEnd    = 0,
  STULastLineTruncationModeMiddle = 1,
  STULastLineTruncationModeStart  = 2,
  STULastLineTruncationModeClip   = 3
};

typedef NS_CLOSED_ENUM(uint8_t, STUBaselineAdjustment) {
  STUBaselineAdjustmentNone                          = 0,
  STUBaselineAdjustmentAlignFirstBaseline            = 1,
  STUBaselineAdjustmentAlignFirstLineCenter          = 2,
  STUBaselineAdjustmentAlignFirstLineCapHeightCenter = 3,
  STUBaselineAdjustmentAlignFirstLineXHeightCenter   = 4
};

/// Reserved for future use.
typedef NS_OPTIONS(uint32_t, STUHyphenationLocationOptions) {
  STUHyphenationLocationOptionsNone = 0
};

typedef struct STUHyphenationLocation {
  size_t index;
  UTF32Char hyphen;
  /// Reserved for future use. Must be STUHyphenationLocationOptionsNone.
  STUHyphenationLocationOptions options;
} STUHyphenationLocation;

// Must be thread-safe.
typedef STUHyphenationLocation
          (^ STULastHyphenationLocationInRangeFinder)(NSAttributedString *, NSRange);


// Must be thread-safe.
typedef NSRange (^ STUTruncationRangeAdjuster)(NSAttributedString *,
                                               NSRange fullRange, NSRange excisedRange);


@class STUTextFrameOptionsBuilder;

/// An immutable class storing @c STUTextFrame layout configuration options.
/// 
/// Equality for @c STUTextFrameOptions instances is defined as pointer equality.
/// (There doesn't seem to be a good use case for comparing @c STUTextFrameOptions instances
/// structurally, and we'd have to replace the block properties with object properties if we wanted
/// to define equality structurally).
STU_EXPORT
@interface STUTextFrameOptions : NSObject <NSCopying>

- (instancetype)initWithBuilder:(nullable STUTextFrameOptionsBuilder *)builder
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUTextFrameOptionsBuilder *builder))block
  // NS_SWIFT_NAME(init(_:)) // https://bugs.swift.org/browse/SR-6894
  // Use Swift's trailing closure syntax when calling this initializer.
  NS_REFINED_FOR_SWIFT;

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUTextFrameOptionsBuilder *builder))block;

/// Default value: @c .default
@property (readonly) STUTextLayoutMode textLayoutMode;

/// Default value: @c (STUDefaultTextAlignment)stu_defaultBaseWritingDirection()
@property (readonly) STUDefaultTextAlignment defaultTextAlignment;

/// Default value: 0
@property (readonly) NSInteger maximumNumberOfLines;

/// Default value: @c .end
@property (readonly) STULastLineTruncationMode lastLineTruncationMode;

/// If the text frame's last line is truncated, this string will be inserted into into the text at
/// the point where the truncation starts.
///
/// If this string is nil or empty, an ellipsis '…' character will be used as the truncation token.
///
/// Any string attribute that is consistent over the full excised range from the original text
/// (ignoring any trailing whitespace) will be copied to the truncation token, without overwriting
/// any attribute already present in the token.
///
/// Default value: @c nil
@property (readonly, nullable) NSAttributedString *truncationToken;

/// Default value: @c nil
@property (readonly, nullable) STUTruncationRangeAdjuster truncationRangeAdjuster;

/// Default value: 1
@property (readonly) CGFloat minimumTextScaleFactor;

/// Default value: @c .none
@property (readonly) STUBaselineAdjustment textScalingBaselineAdjustment;

/// Default value: @c nil
@property (readonly, nullable) STULastHyphenationLocationInRangeFinder
                                 lastHyphenationLocationInRangeFinder;

@end

/// Equality for @c STUTextFrameOptionsBuilder instances is defined as pointer equality.
STU_EXPORT
@interface STUTextFrameOptionsBuilder : NSObject

- (instancetype)initWithOptions:(nullable STUTextFrameOptions *)options
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

/// Default value: @c .default
@property (nonatomic) STUTextLayoutMode textLayoutMode;

/// Default value: @c (STUDefaultTextAlignment)stu_defaultBaseWritingDirection()
@property (nonatomic) STUDefaultTextAlignment defaultTextAlignment;

/// The maximum number of lines.
///
/// A value of 0 means that there is no maximum.
/// Default value: 0
@property (nonatomic) NSInteger maximumNumberOfLines;

/// Default value: @c .end
@property (nonatomic) STULastLineTruncationMode lastLineTruncationMode;

/// If the text frame's last line is truncated, this string will be inserted into into the text at
/// the point where the truncation starts.
///
/// If this string is nil or empty, an ellipsis '…' character will be used as the truncation token.
///
/// Any string attribute that is consistent over the full excised range from the original text
/// (ignoring any trailing whitespace) will be copied to the truncation token, without overwriting
/// any attribute already present in the token.
///
/// Default value: @c nil
@property (nonatomic, copy, nullable) NSAttributedString *truncationToken;

/// Default value: @c nil
@property (nonatomic) STUTruncationRangeAdjuster truncationRangeAdjuster;

/// Default value: 1
@property (nonatomic) CGFloat minimumTextScaleFactor;

/// Default value: 1/128.0 (May change in the future.)
@property (nonatomic) CGFloat textScaleFactorStepSize;

/// Default value: @c .none
@property (nonatomic) STUBaselineAdjustment textScalingBaselineAdjustment;

/// Default value: @c nil
@property (nonatomic, nullable) STULastHyphenationLocationInRangeFinder
                                  lastHyphenationLocationInRangeFinder;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
