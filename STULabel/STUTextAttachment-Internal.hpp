// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttachment.h"

#import "Internal/DrawingContext.hpp"

@interface STUTextAttachment()  {
@package
  CGFloat _width;
  CGFloat _ascent;
  CGFloat _descent;
  CGFloat _leading;
  stu_label::FontMetrics _metrics;
  stu_label::Rect<CGFloat> _imageBounds;
  NSString* _stringRepresentation;
  STUTextAttachmentColorInfo _colorInfo;
}
@end

namespace stu_label {

  extern const NSAttributedStringKey fixForRDAR36622225AttributeName;

  void drawAttachment(const STUTextAttachment*, CGFloat xOffset, CGFloat baselineOffset,
                      Int glyphCount, stu_label::DrawingContext& context);

}

