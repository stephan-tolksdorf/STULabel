// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelLayoutInfo.h"

#import "Internal/TextFrame.hpp"

namespace stu_label {

struct LabelParameters;

struct LabelTextFrameInfo {
  STUTextFrameFlags flags;
  STUTextLayoutMode textLayoutMode : STUTextLayoutModeBitSize;
  STULabelHorizontalAlignment horizontalAlignment : STULabelHorizontalAlignmentBitSize;
  STULabelVerticalAlignment verticalAlignment : STULabelVerticalAlignmentBitSize;
  bool isValid;
  Int32 lineCount;
  /// This rectangle is calculated from the frame's layoutBounds by extending the rectangle
  /// by the minimum amount required to ensure that the text has the horizontal and vertical
  /// alignment within the rectangle that was specified for the label.
  Rect<CGFloat> layoutBounds;
  CGSize frameSize;
  Size<CGFloat> minFrameSize;
  CGFloat firstBaseline;
  CGFloat lastBaseline;
  Float32 firstLineHeight;
  Float32 firstLineHeightAboveBaseline;
  Float32 lastLineHeight;
  Float32 lastLineHeightBelowBaseline;
  CGFloat textScaleFactor;

  bool isValidForSize(CGSize size, const DisplayScale& displayScale) const {
    return isValid && isValidForSizeImpl(size, displayScale);
  }

  CGSize sizeThatFits(const UIEdgeInsets&, const DisplayScale&) const;

  static const LabelTextFrameInfo empty;

private:
  bool isValidForSizeImpl(CGSize, const DisplayScale&) const;
};

LabelTextFrameInfo labelTextFrameInfo(const TextFrame&, STULabelVerticalAlignment,
                                      const DisplayScale&);

CGPoint textFrameOriginInLayer(const LabelTextFrameInfo&, const LabelParameters& params);

STULabelLayoutInfo stuLabelLayoutInfo(const LabelTextFrameInfo&, CGPoint textFrameOrigin,
                                      const DisplayScale&);

} // namespace stu_label
