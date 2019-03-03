
// Copyright 2018 Stephan Tolksdorf

#import <UIKit/UIKit.h>

typedef NS_CLOSED_ENUM(uint8_t, STUFirstOrLastBaseline) {
  STUFirstBaseline,
  STULastBaseline,
};

@class STULabel;

@interface NSLayoutYAxisAnchor (STULabelSpacing)

// See also NSLayoutAnchor+STULabelSpacing.overlay.swift in STULabelSwift

// We only define the most general variants of the constraint creation methods here.
// If you want to use these methods from Objective-C, please define yourself a category with
// wrapper methods that have shorter names and only require the parameters that you need for your
// purposes.

/// Returns a constraint that relates the anchor to a position offset from the specified label
/// baseline by a multiple of the text line height.
///
/// If @c self is an anchor for a baseline of a @c STULabel view, the line height assumed for the
/// computation is the maximum of the two line heights corresponding to the two involved baseline
/// anchors. The line height values are calculated like the values returned by
/// @c STULabel.layoutInfo.
///
/// To constrain @c self to a position above the label baseline, specify a negative multiplier.
///
/// @note The constant value of the returned layout constraint is calculated from the specified
///       parameters and content of the involved labels. It will be automatically updated when the
///       label content changes. Don't set the layout constaint's constant value directly.
///       If you want to change the offset, set the @c stu_labelSpacingConstraintOffset property.
- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                                to:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel *)label
                        plusLineHeightMultipliedBy:(CGFloat)lineHeightMultiplier
                                              plus:(CGFloat)offset
  NS_REFINED_FOR_SWIFT
  NS_SWIFT_NAME(__stu_constraint(_:to:of:plusLineHeightMultipliedBy:plus:));
  //
  // func stu_constraint(_ relation: NSLayoutConstraint.Relation,
  //                     to baseline: STUFirstOrLastBaseline, of label: STULabel,
  //                     plusLineHeightMultipliedBy lineHeightMultiplier: CGFloat,
  //                     plus offset: CGFloat = 0)
  //   -> NSLayoutConstraint

/// Returns a constraint that relates the anchor to a position above the specified label baseline,
/// with a spacing specified as a multiple of the default spacing.
///
/// If @c self is an anchor for a baseline of a @c STULabel view, the default spacing is
/// calculated as the sum of the label text line's height above the baseline and the anchor text
/// line's height below the baseline. If the anchor is not a @c STULabel baseline anchor, the
/// default spacing equals the label text line's height above the baseline. The line height values
/// are calculated like the values returned by @c STULabel.layoutInfo.
///
/// - Note: This method is not practical for constraining a @c UILabel baseline to a @c STULabel
///         baseline.
///
/// - Note: The constant value of the returned layout constraint is calculated from the specified
///         parameters and the content of the involved labels. It will be automatically updated
///         when the label content changes. Don't set the layout constaint's constant value
///         directly. If you want to change the offset, set the value of the
///         @c stu_labelSpacingConstraintOffset property.
- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                   toPositionAbove:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel *)label
                                 spacingMultiplier:(CGFloat)spacingMultiplier
                                            offset:(CGFloat)offset
  NS_REFINED_FOR_SWIFT
  NS_SWIFT_NAME(__stu_constraint(_:toPositionAbove:of:spacingMultiplier:offset:));
  // func stu_constraint(_ relation: NSLayoutConstraint.Relation,
  //                     toPositionAbove baseline: STUFirstOrLastBaseline, of label: STULabel,
  //                     spacingMultiplier multiplier: CGFloat = 1, offset: CGFloat = 0)
  //   -> NSLayoutConstraint


/// Returns a constraint that relates the anchor to a position below the specified label baseline,
/// with a spacing specified as a multiple of the default spacing.
///
/// If @c self is an anchor for a baseline of a @c STULabel view, the default spacing is
/// calculated as the sum of the label text line's below above the baseline and the anchor text
/// line's height above the baseline. If the anchor is not a @c STULabel baseline anchor, the
/// default spacing equals the label text line's height below the baseline. The line height values
/// are calculated like the values returned by @c STULabel.layoutInfo.
///
/// - Note: This method is not practical for constraining a @c UILabel baseline to a @c STULabel
///         baseline.
///
/// - Note: The constant value of the returned layout constraint is calculated from the specified
///         parameters and the content of the involved labels. It will be automatically updated
///         when the label content changes. Don't set the layout constaint's constant value
///         directly. If you want to change the offset, set the value of the
///         @c stu_labelSpacingConstraintOffset property.
- (NSLayoutConstraint *)stu_constraintWithRelation:(NSLayoutRelation)relation
                                   toPositionBelow:(STUFirstOrLastBaseline)baseline
                                                of:(STULabel *)label
                                 spacingMultiplier:(CGFloat)spacingMultiplier
                                            offset:(CGFloat)offset
  NS_REFINED_FOR_SWIFT
  NS_SWIFT_NAME(__stu_constraint(_:toPositionBelow:of:spacingMultiplier:offset:));
  // func stu_constraint(_ relation: NSLayoutConstraint.Relation,
  //                     toPositionBelow baseline: STUFirstOrLastBaseline, of label: STULabel,
  //                     spacingMultiplier multiplier: CGFloat = 1, offset: CGFloat = 0)
  //   -> NSLayoutConstraint

@end

@interface NSLayoutConstraint (STULabelSpacing)

/// Indicates whether the layout constraint was created with one of the @c STULabelSpacing extension
/// methods.
@property (readonly) bool stu_isLabelSpacingConstraint;

/// The line height or spacing multiplier of a constraint created with one of the
/// @c STULabelSpacing extension methods.
///
/// If the constraint was not created with one of @c STULabelSpacing extension methods,
/// the getter returns 0 and the setter does nothing.
@property (nonatomic, setter = stu_setLabelSpacingConstraintMultiplier:)
          CGFloat stu_labelSpacingConstraintMultiplier;

/// The spacing offset of a constraint created with one of the
/// @c STULabelSpacing extension methods.
///
/// If the constraint was not created with one of @c STULabelSpacing extension methods,
/// the getter returns 0 and the setter does nothing.
@property (nonatomic, setter = stu_setLabelSpacingConstraintOffset:)
          CGFloat stu_labelSpacingConstraintOffset;

@end
