// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STULabelLayer-Internal.hpp"

#import "STULabel/STUTextFrame-Internal.hpp"
#import "STULabel/STUTextFrameDrawingOptions-Internal.hpp"
#import "STULabel/STUTextHighlightStyle-Internal.hpp"

#import "Color.hpp"
#import "DisplayScaleRounding.hpp"
#import "InputClamping.hpp"
#import "TextFrame.hpp"

namespace stu_label {

struct LabelParametersWithoutSize {
  STUWritingDirection defaultBaseWritingDirection : 1;
  STULabelDefaultTextAlignment defaultTextAlignment : STULabelDefaultTextAlignmentBitSize;
  STULabelVerticalAlignment verticalAlignment : STULabelVerticalAlignmentBitSize;
private:
  ColorFlags backgroundColorFlags_ : ColorFlagsBitSize;
  STUTextRangeType highlightRangeType_ : STUTextRangeTypeBitSize;
public:
  STULabelDrawingBlockColorOptions drawingBlockColorOptions : STULabelDrawingBlockColorOptionsBitSize;
  STULabelDrawingBounds drawingBlockImageBounds : STULabelDrawingBoundsBitSize;
  bool clipsContentToBounds : 1;
  bool neverUseGrayscaleBitmapFormat : 1;
  bool neverUsesExtendedRGBBitmapFormat : 1;
  bool neverUsesExtendedRGBBitmapFormatWasExplicitlySet : 1;
  bool releasesShapedStringAfterRendering : 1;
  bool releasesShapedStringAfterRenderingWasExplicitlySet : 1;
  bool releasesTextFrameAfterRendering : 1;
  bool releasesTextFrameAfterRenderingWasExplicitlySet : 1;
  bool alwaysUsesContentSublayer : 1;

protected:
  bool isHighlighted_ : 1;
  bool isEffectivelyHighlighted_ : 1;
  bool edgeInsetsAreNonZero_ : 1;

private:
  NSRange highlightRange_{NSRange{0, NSUIntegerMax}};
  RC<CGColor> backgroundColor_;
public:
  STUTextFrameDrawingOptions* drawingOptions;
  STULabelDrawingBlock drawingBlock;
protected:
  DisplayScale displayScale_{DisplayScale::one()};
  UIEdgeInsets edgeInsets_;

public:
  STU_INLINE_T
  const DisplayScale& displayScale() const { return displayScale_; }

  void setDisplayScale_assumingSizeAndEdgeInsetsAreAlreadyCorrectlyRounded(
         const DisplayScale& displayScale)
  {
    displayScale_ = displayScale;
  }

  STU_INLINE_T
  const bool edgeInsetsAreZero() const { return !edgeInsetsAreNonZero_; }

  STU_INLINE_T
  const UIEdgeInsets& edgeInsets() const { return edgeInsets_; }


  STU_INLINE_T
  CGColor* __nullable backgroundColor() const { return backgroundColor_.get(); }

  STU_INLINE_T
  ColorFlags backgroundColorFlags() const { return backgroundColorFlags_; }

  STU_INLINE
  void setBackgroundColor(CGColor* __nullable color) {
    backgroundColor_ = color;
    backgroundColorFlags_ = colorFlags(color);
  }

private:
  void ensureDrawingOptionsIsNotFrozen() {
    if (!drawingOptions || drawingOptions->impl.isFrozen()) {
      ensureDrawingOptionsIsNotFrozen_slowPath();
      drawingOptions->impl.assumeNotFrozen();
    }
  }
  void ensureDrawingOptionsIsNotFrozen_slowPath();

public:
  /// NOT thread-safe.
  void freezeDrawingOptions() const {
    if (drawingOptions) {
      drawingOptions->impl.freeze();
    }
  }
  /// NOT thread-safe.
  Unretained<STUTextFrameDrawingOptions* __nullable> frozenDrawingOptions() const {
    freezeDrawingOptions();
    return drawingOptions;
  }

  bool isEffectivelyHighlighted() const {
    return isEffectivelyHighlighted_;
  }
private:
  void updateIsEffectivelyHighlighted() {
    const bool isHighlighted = isHighlighted_
                               && drawingOptions && drawingOptions->impl.highlightStyle()
                               && highlightRange_.length != 0;
    if (isEffectivelyHighlighted_ == isHighlighted) return;
    isEffectivelyHighlighted_ = isHighlighted;
    ensureDrawingOptionsIsNotFrozen();
    const auto range = isHighlighted ? highlightRange_ : NSRange{};
    const auto rangeType = isHighlighted ? highlightRangeType_ : STURangeInTruncatedString;
    drawingOptions->impl.setHighlightRange(range, rangeType);
  }

public:
  bool isHighlighted() const {
    return isHighlighted_;
  }
  void setIsHighlighted(bool value) {
    if (isHighlighted_ == value) return;
    isHighlighted_ = value;
    updateIsEffectivelyHighlighted();
  }

  STUTextRange highlightRange() const {
    return {highlightRange_, highlightRangeType_};
  }
  bool setHighlightRange(NSRange range, STUTextRangeType rangeType) {
    rangeType = clampTextRangeType(rangeType);
    if (highlightRange() == STUTextRange{range, rangeType}) {
      return false;
    }
    highlightRange_ = range;
    highlightRangeType_ = rangeType;
    const bool wasHighlighted = isEffectivelyHighlighted_;
    updateIsEffectivelyHighlighted();
    if (isEffectivelyHighlighted_ && wasHighlighted) {
      ensureDrawingOptionsIsNotFrozen();
      drawingOptions->impl.setHighlightRange(range, rangeType);
    }
    return true;
  }

  Unretained<STUTextHighlightStyle* __nullable> highlightStyle() const {
    return drawingOptions ? drawingOptions->impl.highlightStyle() : nil;
  }
  bool setHighlightStyle(STUTextHighlightStyle*  __unsafe_unretained __nullable style) {
    if (style == (!drawingOptions ? nil : drawingOptions->impl.highlightStyle())) {
      return false;
    }
    ensureDrawingOptionsIsNotFrozen();
    drawingOptions->impl.setHighlightStyle(style);
    updateIsEffectivelyHighlighted();
    return true;
  }

  bool overrideColorsApplyToHighlightedText() const {
    return drawingOptions ? drawingOptions->impl.overrideColorsApplyToHighlightedText() : true;
  }
  bool setOverrideColorsApplyToHighlightedText(bool value) {
    if (value == overrideColorsApplyToHighlightedText()) return false;
    ensureDrawingOptionsIsNotFrozen();
    drawingOptions->impl.setOverrideColorsApplyToHighlightedText(value);
    return true;
  }

  Unretained<UIColor* __nullable> overrideTextColor() const {
    return drawingOptions ? drawingOptions->impl.overrideTextUIColor() : nil;
  }
  bool setOverrideTextColor(UIColor* __unsafe_unretained __nullable color) {
    if (color == overrideTextColor()) return false;
    ensureDrawingOptionsIsNotFrozen();
    drawingOptions->impl.setOverrideTextColor(color);
    return true;
  }

  Unretained<UIColor* __nullable> overrideLinkColor() const {
    return drawingOptions ? drawingOptions->impl.overrideLinkUIColor() : nil;
  }
  bool setOverrideLinkColor(UIColor* __unsafe_unretained __nullable color) {
    if (color == overrideLinkColor()) return false;
    ensureDrawingOptionsIsNotFrozen();
    drawingOptions->impl.setOverrideLinkColor(color);
    return true;
  }
};


enum class LabelParameterChangeStatus {
  noChange = 0,
  sizeChanged = 1,
  edgeInsetsChanged = 2,
  displayScaleChanged = 4
};

} // namespace stu_label

template <> struct stu::IsOptionsEnum<stu_label::LabelParameterChangeStatus> : True {};

namespace stu_label {

struct LabelParameters : LabelParametersWithoutSize {
private:
  CGSize size_;

public:
  using ChangeStatus = LabelParameterChangeStatus;

  STU_INLINE_T
  const CGSize& size() const { return size_; }

  STU_INLINE_T
  void setSize_afterBaseAssignment_alreadyCeiledToScale(CGSize size) {
    size_ = size;
  }

  STU_INLINE_T
  void swapLeftAndRightContentInsets() {
    std::swap(edgeInsets_.left, edgeInsets_.right);
  }

  ChangeStatus setEdgeInsets(UIEdgeInsets edgeInsets);

  ChangeStatus setSizeAndIfChangedUpdateEdgeInsets(CGSize size, UIEdgeInsets edgeInsets) {
    size = ceilToScale(size, displayScale_);
    if (size == size_) return ChangeStatus::noChange;
    size_ = size;
    return setEdgeInsets(edgeInsets) | ChangeStatus::sizeChanged;
  }

  ChangeStatus setSizeAndEdgeInsets(CGSize size, UIEdgeInsets edgeInsets) {
    size = ceilToScale(size, displayScale_);
    ChangeStatus status = size == size ? ChangeStatus::noChange : ChangeStatus::sizeChanged;
    size_ = size;
    return setEdgeInsets(edgeInsets) | status;
  }

  ChangeStatus setDisplayScaleAndIfChangedUpdateSizeAndEdgeInsets(
                  const DisplayScale& displayScale, CGSize size, UIEdgeInsets edgeInsets)
  {
    if (displayScale_ == displayScale) {
      return ChangeStatus::noChange;
    }
    displayScale_ = displayScale;
    return setSizeAndEdgeInsets(size, edgeInsets) | ChangeStatus::displayScaleChanged;
  }

  CGSize maxTextFrameSize() const {
   return {size_.width - (edgeInsets_.left + edgeInsets_.right),
           size_.height - (edgeInsets_.top + edgeInsets_.bottom)};
  }

  void shrinkSizeToFitTextBounds(const Rect<CGFloat>& bounds,
                                 STULabelPrerendererSizeOptions options)
  {
    const CGSize sizeThatFits = ceilToScale(bounds.inset(-edgeInsets_), displayScale_).size();
    if (options & STUShrinkLabelWidthToFit) {
      size_.width = min(size_.width, sizeThatFits.width);
    }
    if (options & STUShrinkLabelHeightToFit) {
      size_.height = min(size_.height, sizeThatFits.height);
    }
  }
};

class LabelPrerenderer;
class LabelLayer;
void invalidateLayout(STULabelLayer* self);
void invalidateShapedString(STULabelLayer* self);


STU_INLINE
STUDirectionalEdgeInsets directionalEdgeInsets(UIEdgeInsets insets,
                                                STUWritingDirection layoutDirection)
{
  return {.top = insets.top, .bottom = insets.bottom,
          .leading = layoutDirection == STUWritingDirectionLeftToRight
                   ? insets.left : insets.right,
          .trailing = layoutDirection == STUWritingDirectionLeftToRight
                    ? insets.right : insets.left};
}

STU_INLINE
UIEdgeInsets edgeInsets(STUDirectionalEdgeInsets insets, STUWritingDirection layoutDirection) {
  return {.top = insets.top, .bottom = insets.bottom,
          .left  = layoutDirection == STUWritingDirectionLeftToRight
                 ? insets.leading : insets.trailing,
          .right = layoutDirection == STUWritingDirectionLeftToRight
                 ? insets.trailing : insets.leading};
}


template <typename Derived>
class LabelPropertiesCRTPBase {
  static_assert(isOneOf<Derived, LabelPrerenderer, LabelLayer>);

  STU_INLINE_T       Derived& derived()       { return static_cast<      Derived&>(*this); }
  STU_INLINE_T const Derived& derived() const { return static_cast<const Derived&>(*this); }

  /// Returns true if the textFrameOptions were changed and the layout may need to be invalidated.
  [[nodiscard]]
  bool updateTextFrameOptionsDefaultTextAlignment() {
    Derived& d = derived();
    const auto defaultTextAlignment = stuDefaultTextAlignment(d.params_.defaultTextAlignment,
                                                              d.params_.defaultBaseWritingDirection);
    if (d.textFrameOptions_->_options.defaultTextAlignment == defaultTextAlignment) return false;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.defaultTextAlignment = defaultTextAlignment;
    return true;
  }

  void ensureTextFrameOptionsIsPrivate() {
    Derived& d = derived();
    if (!d.textFrameOptionsIsPrivate_) {
      ensureTextFrameOptionsIsPrivate_slowPath();
    }
  }
  STU_NO_INLINE
  void ensureTextFrameOptionsIsPrivate_slowPath() {
    Derived& d = derived();
    d.textFrameOptionsIsPrivate_ = true;
    STU_DEBUG_ASSERT(d.textFrameOptions_ != nil);
    d.textFrameOptions_ = STUTextFrameOptionsCopy(d.textFrameOptions_);
  }

public:
  const LabelParameters& params() const {
    return derived().params_;
  }

  UIUserInterfaceLayoutDirection userInterfaceLayoutDirection() const {
    static_assert((int)UIUserInterfaceLayoutDirectionLeftToRight == (int)STUWritingDirectionLeftToRight);
    static_assert((int)UIUserInterfaceLayoutDirectionRightToLeft == (int)STUWritingDirectionRightToLeft);
    return static_cast<UIUserInterfaceLayoutDirection>(derived().params_.defaultBaseWritingDirection);
  }

  void setUserInterfaceLayoutDirection(UIUserInterfaceLayoutDirection layoutDirection) {
    Derived& d = derived();
    d.checkNotFrozen();
    const STUWritingDirection direction = stuWritingDirection(layoutDirection);
    if (d.params_.defaultBaseWritingDirection == direction) return;
    d.params_.defaultBaseWritingDirection = direction;
    bool mayNeedToInvalidateLayout = false;
    if (d.contentInsetsAreDirectional_
        && d.contentInsets_.left != d.contentInsets_.right)
    {
      mayNeedToInvalidateLayout = true;
      std::swap(d.contentInsets_.left, d.contentInsets_.right);
      d.params_.swapLeftAndRightContentInsets();
    }
    mayNeedToInvalidateLayout |= updateTextFrameOptionsDefaultTextAlignment();
    if (d.shapedString_
        && d.shapedString_->shapedString->defaultBaseWritingDirectionWasUsed
        && d.shapedString_->shapedString->defaultBaseWritingDirection != direction)
    {
      d.invalidateShapedString();
    } else if (mayNeedToInvalidateLayout) {
      d.invalidateLayout();
    }
  }

  const UIEdgeInsets& contentInsets() const { return derived().contentInsets_; }

  STUDirectionalEdgeInsets directionalContentInsets() const {
    const Derived& d = derived();
    return directionalEdgeInsets(d.contentInsets_, d.params_.defaultBaseWritingDirection);
  }

  STULabelDefaultTextAlignment defaultTextAlignment() const {
    return derived().params_.defaultTextAlignment;
  }
  void setDefaultTextAlignment(STULabelDefaultTextAlignment defaultTextAlignment) {
    Derived& d = derived();
    d.checkNotFrozen();
    defaultTextAlignment = clampDefaultTextAlignment(defaultTextAlignment);
    if (d.params_.defaultTextAlignment == defaultTextAlignment) return;
    d.params_.defaultTextAlignment = defaultTextAlignment;
    if (updateTextFrameOptionsDefaultTextAlignment()) {
      d.invalidateLayout();
    }
  }

  void setTextFrameOptions(STUTextFrameOptions* __unsafe_unretained __nullable options) {
    Derived& d = derived();
    d.checkNotFrozen();
    if (!options) {
      options = defaultLabelTextFrameOptions().unretained;
    }
    if (d.textFrameOptions_ == options) return;
    d.textFrameOptions_ = options;
    d.textFrameOptionsIsPrivate_ = false;
    discard(updateTextFrameOptionsDefaultTextAlignment());
    d.invalidateLayout();
  }

  STUTextLayoutMode textLayoutMode() {
    return derived().textFrameOptions_->_options.textLayoutMode;
  }
  void setTextLayoutMode(STUTextLayoutMode textLayoutMode) {
    Derived& d = derived();
    d.checkNotFrozen();
    textLayoutMode = clampTextLayoutMode(textLayoutMode);
    if (textLayoutMode == d.textFrameOptions_->_options.textLayoutMode) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.textLayoutMode = textLayoutMode;
    d.invalidateLayout();
  }

  Int maxLineCount() const {
    return derived().textFrameOptions_->_options.maximumNumberOfLines;
  }
  void setMaxLineCount(Int maxLineCount) {
    Derived& d = derived();
    d.checkNotFrozen();
    maxLineCount = clampMaxLineCount(maxLineCount);
    if (maxLineCount == d.textFrameOptions_->_options.maximumNumberOfLines) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.maximumNumberOfLines = maxLineCount;
    d.invalidateLayout();
  }

  STULastLineTruncationMode lastLineTruncationMode() const {
    return derived().textFrameOptions_->_options.lastLineTruncationMode;
  }
  void setLastLineTruncationMode(STULastLineTruncationMode lastLineTruncationMode) {
    Derived& d = derived();
    d.checkNotFrozen();
    lastLineTruncationMode = clampLastLineTruncationMode(lastLineTruncationMode);
    if (lastLineTruncationMode == d.textFrameOptions_->_options.lastLineTruncationMode) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.lastLineTruncationMode = lastLineTruncationMode;
    d.invalidateLayout();
  }

  NSAttributedString* __nullable truncationToken() const {
    return derived().textFrameOptions_->_options.truncationToken;
  }
  void setTruncationToken(NSAttributedString* __unsafe_unretained __nullable truncationToken) {
    Derived& d = derived();
    d.checkNotFrozen();
    if (truncationToken == d.textFrameOptions_->_options.truncationToken) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.truncationToken = [truncationToken copy];
    d.textFrameOptions_->_options.fixedTruncationToken =
      [d.textFrameOptions_->_options.truncationToken
         stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments];
    d.invalidateLayout();
  }

  __nullable STUTruncationRangeAdjuster truncationRangeAdjuster() const {
    return derived().textFrameOptions_->_options.truncationRangeAdjuster;
  }
  void setTruncationRangeAdjuster(STUTruncationRangeAdjuster __unsafe_unretained adjuster) {
    Derived& d = derived();
    d.checkNotFrozen();
    if (adjuster == d.textFrameOptions_->_options.truncationRangeAdjuster) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.truncationRangeAdjuster = adjuster;
    d.invalidateLayout();
  }

  CGFloat minTextScaleFactor() const {
    return derived().textFrameOptions_->_options.minimumTextScaleFactor;
  }
  void setMinTextScaleFactor(CGFloat minTextScaleFactor) {
    Derived& d = derived();
    d.checkNotFrozen();
    minTextScaleFactor = clampMinTextScaleFactor(minTextScaleFactor);
    if (minTextScaleFactor == d.textFrameOptions_->_options.minimumTextScaleFactor) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.minimumTextScaleFactor = minTextScaleFactor;
    d.invalidateLayout();
  }

  CGFloat textScaleFactorStepSize() const {
    return derived().textFrameOptions_->_options.textScaleFactorStepSize;
  }
  void setTextScaleFactorStepSize(CGFloat textScaleFactorStepSize) {
    Derived& d = derived();
    d.checkNotFrozen();
    textScaleFactorStepSize = clampTextScaleFactorStepSize(textScaleFactorStepSize);
    if (textScaleFactorStepSize == d.textFrameOptions_->_options.textScaleFactorStepSize) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.textScaleFactorStepSize = textScaleFactorStepSize;
    d.invalidateLayout();
  }

  STUBaselineAdjustment textScalingBaselineAdjustment() const {
    return derived().textFrameOptions_->_options.textScalingBaselineAdjustment;
  }
  void setTextScalingBaselineAdjustment(STUBaselineAdjustment baselineAdjustment) {
    Derived& d = derived();
    d.checkNotFrozen();
    baselineAdjustment = clampBaselineAdjustment(baselineAdjustment);
    if (baselineAdjustment == d.textFrameOptions_->_options.textScalingBaselineAdjustment) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.textScalingBaselineAdjustment = baselineAdjustment;
    d.invalidateLayout();
  }

  __nullable STULastHyphenationLocationInRangeFinder lastHyphenationLocationInRangeFinder() const {
    return derived().textFrameOptions_->_options.lastHyphenationLocationInRangeFinder;
  }
  void setLastHyphenationLocationInRangeFinder(STULastHyphenationLocationInRangeFinder
                                                 __unsafe_unretained finder) {
    Derived& d = derived();
    d.checkNotFrozen();
    if (finder == d.textFrameOptions_->_options.lastHyphenationLocationInRangeFinder) return;
    ensureTextFrameOptionsIsPrivate();
    d.textFrameOptions_->_options.lastHyphenationLocationInRangeFinder = finder;
    d.invalidateLayout();
  }
};


inline UIEdgeInsets roundLabelEdgeInsetsToScale(UIEdgeInsets insets, const DisplayScale& scale) {
  return {.top = roundToScale(insets.top, scale),
          .bottom = roundToScale(insets.bottom, scale),
          .left = insets.left,
          .right = insets.right};
}

CGSize maxTextFrameSizeForLabelSize(CGSize size, const UIEdgeInsets& insets,
                                    const DisplayScale& scale);

STU_INLINE
UIEdgeInsets roundAndClampEdgeInsetsForSize(UIEdgeInsets edgeInsets, CGSize size,
                                            const DisplayScale& scale)
{
  edgeInsets.top    = roundToScale(edgeInsets.top, scale);
  edgeInsets.bottom = roundToScale(edgeInsets.bottom, scale);
  const CGFloat edgesWidth  = edgeInsets.left + edgeInsets.right;
  const CGFloat edgesHeight = edgeInsets.top + edgeInsets.bottom;
  if (STU_UNLIKELY(edgesWidth > size.width)) {
    edgeInsets.left *= (size.width/edgesWidth);
    edgeInsets.right = size.width - edgeInsets.left;
  }
  if (STU_UNLIKELY(edgesHeight > size.height)) {
    edgeInsets.top *= (size.height/edgesHeight);
    edgeInsets.bottom = size.height - edgeInsets.top;
    edgeInsets.top    = floorToScale(edgeInsets.top, scale);
    edgeInsets.bottom = floorToScale(edgeInsets.bottom, scale);
  }
  return edgeInsets;
}

} // namespace stu_label


