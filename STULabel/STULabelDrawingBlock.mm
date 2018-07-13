// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelDrawingBlock-Internal.h"

#import "STUObjCRuntimeWrappers.h"

#import "STUTextFrame-Internal.hpp"

#import "Internal/Once.hpp"

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
  STULabelDrawingBlockParametersCreate(
    STUTextFrame* textFrame, STUTextFrameRange range, CGPoint textFrameOrigin,
    CGContext* context, CGFloat contextBaseCTM_d, bool pixelAlignBaselines,
    STUTextFrameDrawingOptions * __nullable options,
    const STUCancellationFlag* __nullable cancellationFlag)
  NS_RETURNS_RETAINED
{
  STU_STATIC_CONST_ONCE(Class, cls, STULabelDrawingBlockParameters.class);
  STULabelDrawingBlockParameters* const p = stu_createClassInstance(cls, 0);
  p->_textFrame = textFrame;
  p->_range = range;
  p->_textFrameOrigin = textFrameOrigin;
  p->_context = context;
  p->_contextBaseCTM_d = contextBaseCTM_d;
  p->_pixelAlignBaselines = pixelAlignBaselines;
  p->_options = options;
  p->_cancellationToken = cancellationFlag;
  return p;
}

- (void)draw {
  STUTextFrameDrawRange(_textFrame, _range, _textFrameOrigin,
                        _context, _contextBaseCTM_d, _pixelAlignBaselines,
                        _options, _cancellationToken);
}

@end


