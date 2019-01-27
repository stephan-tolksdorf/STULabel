// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension NSLayoutYAxisAnchor {

  /// Returns a constraint that relates the anchor to a position offset from the specified label
  /// baseline by a multiple of the text line height.
  ///
  /// If `self` is an anchor for a baseline of a `STULabel` view, the line height assumed for the
  /// computation is the maximum of the two line heights corresponding to the two involved text
  /// lines. The line height values are calculated like the values returned by
  /// `STULabel.layoutInfo`.
  ///
  /// To constrain `self` to a position above the label baseline, specify a negative multiplier.
  ///
  /// - Note: The constant value of the returned layout constraint is calculated from the specified
  ///         parameters and the content of the involved labels. It will be automatically updated
  ///         when the label content changes. Don't set the layout constaint's constant value
  ///         directly. If you want to change the offset, set the value of the
  ///         `stu_labelSpacingConstraintOffset` property.
  @inlinable
  public func stu_constraint(_ relation: NSLayoutConstraint.Relation,
                             to baseline: STUFirstOrLastBaseline, of label: STULabel,
                             plusLineHeightMultipliedBy lineHeightMultiplier: CGFloat,
                             plus offset: CGFloat = 0)
    -> NSLayoutConstraint
  {
    return __stu_constraint(relation, to: baseline, of: label,
                            plusLineHeightMultipliedBy: lineHeightMultiplier, plus: offset)
  }

  /// Returns a constraint that relates the anchor to a position above the specified label baseline,
  /// with a spacing specified as a multiple of the default spacing.
  ///
  /// If `self` is an anchor for a baseline of a `STULabel` view, the default spacing is
  /// calculated as the sum of the label text line's height above the baseline and the anchor text
  /// line's height below the baseline. If the anchor is not a `STULabel` baseline anchor, the
  /// default spacing equals the label text line's height above the baseline. The line height values
  /// are calculated like the values returned by `STULabel.layoutInfo`.
  ///
  /// - Note: This method is not practical for constraining a `UILabel` baseline to a `STULabel`
  ///         baseline.
  ///
  /// - Note: The constant value of the returned layout constraint is calculated from the specified
  ///         parameters and the content of the involved labels. It will be automatically updated
  ///         when the label content changes. Don't set the layout constaint's constant value
  ///         directly. If you want to change the offset, set the value of the
  ///         `stu_labelSpacingConstraintOffset` property.
  @inlinable
  public func stu_constraint(_ relation: NSLayoutConstraint.Relation,
                             toPositionAbove baseline: STUFirstOrLastBaseline, of label: STULabel,
                             spacingMultiplier multiplier: CGFloat = 1, offset: CGFloat = 0)
    -> NSLayoutConstraint
  {
    return __stu_constraint(relation, toPositionAbove: baseline, of: label,
                            spacingMultiplier: multiplier, offset: offset)
  }

  /// Returns a constraint that relates the anchor to a position below the specified label baseline,
  /// with a spacing specified as a multiple of the default spacing.
  ///
  /// If `self` is an anchor for a baseline of a `STULabel` view, the default spacing is
  /// calculated as the sum of the label text line's height below the baseline and the anchor text
  /// line's height above the baseline. If the anchor is not a `STULabel` baseline anchor, the
  /// default spacing equals the label text line's height below the baseline. The line height values
  /// are calculated like the values returned by `STULabel.layoutInfo`.
  ///
  /// - Note: This method is not practical for constraining a `UILabel` baseline to a `STULabel`
  ///         baseline.
  ///
  /// - Note: The constant value of the returned layout constraint is calculated from the specified
  ///         parameters and the content of the involved labels. It will be automatically updated
  ///         when the label content changes. Don't set the layout constaint's constant value
  ///         directly. If you want to change the offset, set the value of the
  ///         `stu_labelSpacingConstraintOffset` property.
  @inlinable
  public func stu_constraint(_ relation: NSLayoutConstraint.Relation,
                             toPositionBelow baseline: STUFirstOrLastBaseline, of label: STULabel,
                             spacingMultiplier multiplier: CGFloat = 1, offset: CGFloat = 0)
    -> NSLayoutConstraint
  {
    return __stu_constraint(relation, toPositionBelow: baseline, of: label,
                            spacingMultiplier: multiplier, offset: offset)
  }
}
