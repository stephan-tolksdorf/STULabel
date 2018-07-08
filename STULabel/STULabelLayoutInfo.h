// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelAlignment.h"
#import "STUTextFrame.h"

typedef struct STULabelLayoutInfo {
  /// The layout bounds of the text within the label. This rectangle is calculated from the
  /// the typographic bounds of the visible text within the label by extending the rectangle by the
  /// minimum amount required to ensure that the text has the same horizontal and vertical alignment
  /// within the rectangle as it should have in the full label.
  CGRect layoutBounds;
  int32_t lineCount;
  STUTextFrameFlags textFrameFlags;
  STULabelHorizontalAlignment horizontalAlignment;
  STULabelVerticalAlignment verticalAlignment;
  CGFloat firstBaseline;
  CGFloat lastBaseline;
  float firstLineAscent;
  float firstLineLeading;
  /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float firstLineHeight;
  float lastLineDescent;
  float lastLineLeading;
  /// The value that the line layout algorithm would calculate for the distance between the last
  /// baseline and the baseline of the hypothetical next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float lastLineHeight;
  CGPoint textFrameOrigin;
  /// The scale factor that was applied to shrink the text to fit the label's size. This value is
  /// always between 0 (exclusive) and 1 (inclusive). It only can be less than 1 if the label's
  /// `minimumTextScaleFactor` is less than 1.
  CGFloat textScaleFactor;
  /// The label's layer.contentsScale.
  CGFloat displayScale;
} STULabelLayoutInfo;

