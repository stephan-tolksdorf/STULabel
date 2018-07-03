// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttachment.h"

#import "Internal/DrawingContext.hpp"

@interface STUTextAttachment()  {
@package
  CGFloat _width;
  CGFloat _ascent;
  CGFloat _descent;
  stu_label::Rect<CGFloat> _imageBounds;
  NSString* _stringRepresentation;
  STUTextAttachmentColorInfo _colorInfo;
}
@end

namespace stu_label {
  void drawAttachment(const STUTextAttachment*, CGFloat xOffset, Int glyphCount,
                      stu_label::DrawingContext& context);

}

