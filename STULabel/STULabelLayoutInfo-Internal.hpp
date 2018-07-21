// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelLayoutInfo.h"

#import "Internal/TextFrame.hpp"

namespace stu_label {

struct LabelParameters;

struct LabelTextFrameInfo {
  STUTextFrameFlags flags;
  STULabelHorizontalAlignment horizontalAlignment : 3;
  STULabelVerticalAlignment verticalAlignment : 3;
  bool isValid;
  Int32 lineCount;
  CGSize frameSize;
  /// This rectangle is calculated from the frame's typographic bounds by extending the rectangle
  /// by the minimum amount required to ensure that the text has the horizontal and vertical
  /// alignment within the rectangle that was specified for the label.
  Rect<CGFloat> layoutBounds;
  Size<CGFloat> minFrameSize;
  CGFloat spacingBelowLastBaseline;
  CGFloat firstBaseline;
  CGFloat lastBaseline;
  CGFloat textScaleFactor;
  Float32 firstLineAscent;
  Float32 firstLineLeading;
  Float32 firstLineHeight;
  Float32 lastLineDescent;
  Float32 lastLineLeading;
  Float32 lastLineHeight;

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
