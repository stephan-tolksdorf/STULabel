// Copyright 2017–2018 Stephan Tolksdorf

#import "LabelParameters.hpp"

namespace stu_label {

STU_NO_INLINE
void LabelParametersWithoutSize::ensureDrawingOptionsIsNotFrozen_slowPath() {
  const bool wasNull = drawingOptions == nil;
  drawingOptions = STUTextFrameDrawingOptionsCopy(drawingOptions);
  if (wasNull) {
    drawingOptions->impl.setHighlightRange(NSRange{}, STURangeInTruncatedString);
  }
}

LabelParameters::ChangeStatus LabelParameters::setEdgeInsets(UIEdgeInsets edgeInsets) {
  if (edgeInsets == UIEdgeInsets{}) {
    if (!edgeInsetsAreNonZero_) {
      return ChangeStatus::noChange;
    }
    edgeInsetsAreNonZero_ = false;
  } else {
    edgeInsets = roundLabelEdgeInsetsToScale(edgeInsets, displayScale_);
    const CGFloat edgesWidth  = edgeInsets.left + edgeInsets.right;
    const CGFloat edgesHeight = edgeInsets.top + edgeInsets.bottom;
    if (STU_UNLIKELY(edgesWidth > size_.width || edgesHeight > size_.height)) {
      if (edgesWidth > size_.width) {
        edgeInsets.left *= (size_.width/edgesWidth);
        edgeInsets.right = size_.width - edgeInsets_.left;
      }
      if (edgesHeight > size_.height) {
        edgeInsets.top *= (size_.height/edgesHeight);
        edgeInsets.bottom = size_.height - edgeInsets.top;
      }
      edgeInsets = roundLabelEdgeInsetsToScale(edgeInsets, displayScale_);
    }
    if (edgeInsets == edgeInsets_) return ChangeStatus::noChange;
    edgeInsetsAreNonZero_ = edgeInsets != UIEdgeInsets{};
  }
  edgeInsets_ = edgeInsets;
  return ChangeStatus::edgeInsetsChanged;
}

CGSize maxTextFrameSizeForLabelSize(CGSize size, const UIEdgeInsets& insets,
                                    const DisplayScale& scale)
{
  const UIEdgeInsets roundedInsets = roundLabelEdgeInsetsToScale(insets, scale);
  return {max(0.f, size.width - (roundedInsets.left + roundedInsets.right)),
          max(0.f, floorToScale(size.height, scale) - (roundedInsets.top + roundedInsets.bottom))};
}


} // stu_label
