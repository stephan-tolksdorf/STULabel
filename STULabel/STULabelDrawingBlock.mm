// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelDrawingBlock-Internal.hpp"
#import "STULabelSwiftExtensions.h"

#import "STUObjCRuntimeWrappers.h"

#import "Internal/TextFrame.hpp"

#import "Internal/Once.hpp"

using namespace stu_label;

@implementation STULabelDrawingBlockParameters {
  // Explicitly declare the ivars so that we don't have to annotate them as "nonatomic".
  STUTextFrame* _textFrame;
  STUTextFrameRange _range;
  CGPoint _textFrameOrigin;
  CGContextRef _context;
  bool _pixelAlignBaselines;
  CGFloat _contextBaseCTM_d;
  STUTextFrameDrawingOptions* _options;
  const STUCancellationFlag* _cancellationToken;
}

- (nonnull STUTextFrame*)textFrame { return _textFrame; }
- (STUTextFrameRange)range { return _range; }
- (CGPoint)textFrameOrigin { return _textFrameOrigin; }
- (nonnull CGContextRef)context { return _context; }
- (CGFloat)contextBaseCTM_d { return _contextBaseCTM_d; }
- (bool)pixelAlignBaselines { return _pixelAlignBaselines; }
- (STUTextFrameDrawingOptions*)options { return _options; }
- (nullable const STUCancellationFlag*)cancellationFlag { return _cancellationToken; }

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

STULabelDrawingBlockParameters* __nonnull
  stu_label::createLabelDrawingBlockParametersInstance(
    STUTextFrame* textFrame, STUTextFrameRange range, CGPoint textFrameOrigin,
    CGContext* context, ContextBaseCTM_d contextBaseCTM_d, PixelAlignBaselines pixelAlignBaselines,
    STUTextFrameDrawingOptions * __nullable options,
    const STUCancellationFlag* __nullable cancellationFlag)
  NS_RETURNS_RETAINED
{
  STU_STATIC_CONST_ONCE(Class, cls, STULabelDrawingBlockParameters.class);
  STU_ANALYZER_ASSUME(cls != nil);
  STULabelDrawingBlockParameters* const p = stu_createClassInstance(cls, 0);
  p->_textFrame = textFrame;
  p->_range = range;
  p->_textFrameOrigin = textFrameOrigin;
  p->_context = context;
  p->_contextBaseCTM_d = contextBaseCTM_d.value;
  p->_pixelAlignBaselines = pixelAlignBaselines.value;
  p->_options = options;
  p->_cancellationToken = cancellationFlag;
  return p;
}

- (void)draw {
  drawTextFrame(_textFrame, _range, _textFrameOrigin,
                _context, ContextBaseCTM_d{_contextBaseCTM_d},
                PixelAlignBaselines{_pixelAlignBaselines}, _options, _cancellationToken);
}

STU_EXPORT
STUTextFrameWithOrigin STULabelDrawingBlockParametersGetTextFrameWithOrigin(
                          STULabelDrawingBlockParameters *self)
{
  CGFloat displayScale = 0;
  if (self->_pixelAlignBaselines) {
    displayScale = TextFrame::assumedScaleForCTM(CGContextGetCTM(self->_context));
  }
  return {self->_textFrame, self->_textFrameOrigin, .displayScale = displayScale};
}

@end


