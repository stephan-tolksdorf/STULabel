// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelSubrangeView.h"

#import "LabelRendering.hpp"

using namespace stu;
using namespace stu_label;

@implementation STULabelSubrangeView

- (instancetype)init {
  self = [super init];
  self.opaque = false;
  return self;
}

- (void)drawRect:(CGRect)rect {
  if (_drawingBlock) {
    _drawingBlock(UIGraphicsGetCurrentContext(), rect, nullptr);
  }
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor {
  // When the view of a UITargetedDragPreview instance is inserted into the view hierarchy, its
  // contentScaleFactor is reset to the screen's scale. Since we don't do the insertion ourselves
  // and we don't want the view to appear pixelated when when it's the subview of a zoomed-in label,
  // we clamp the scale here.
  [super setContentScaleFactor:max(contentScaleFactor, self.superview.contentScaleFactor)];
}

@end

@implementation STULabelTiledSubrangeView

+ (Class)layerClass {
  return STULabelTiledLayer.class;
}

- (void)setDrawingBlock:(STULabelSubrangeDrawingBlock)drawingBlock {
  [super setDrawingBlock:drawingBlock];
  [((STULabelTiledLayer*)self.layer) setDrawingBlock: drawingBlock];
}

@end
