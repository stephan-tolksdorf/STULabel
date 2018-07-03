// Copyright 2018 Stephan Tolksdorf

#import "CoreAnimationUtils.hpp"

#import "Once.hpp"

namespace stu_label {

UIWindow* window(CALayer* __unsafe_unretained layer) {
  STU_STATIC_CONST_ONCE(Class, uiViewClass, UIView.class);
  do {
    if (const __unsafe_unretained id delegate = layer.delegate;
        [delegate isKindOfClass:uiViewClass])
    {
      UIView* __unsafe_unretained const view = static_cast<UIView*>(delegate);
      if (view.layer == layer) {
        return view.window;
      }
    }
  } while ((layer = layer.superlayer));
  return nil;
}

STUPredefinedCGImageFormat contentsImageFormat(NSString* __unsafe_unretained contentsFormat,
                                               STUPredefinedCGImageFormat fallbackFormat)
{
  if (contentsFormat == kCAContentsFormatGray8Uint) {
    return STUPredefinedCGImageFormatGrayscale;
  } else if (contentsFormat == kCAContentsFormatRGBA16Float) {
    return STUPredefinedCGImageFormatExtendedRGB;
  } else if (contentsFormat == kCAContentsFormatRGBA8Uint) {
    return STUPredefinedCGImageFormatRGB;
  }
  if ([contentsFormat isEqualToString:kCAContentsFormatGray8Uint]) {
    return STUPredefinedCGImageFormatGrayscale;
  } else if ([contentsFormat isEqualToString:kCAContentsFormatRGBA16Float]) {
    return STUPredefinedCGImageFormatExtendedRGB;
  } else if ([contentsFormat isEqualToString:kCAContentsFormatRGBA8Uint]) {
    return STUPredefinedCGImageFormatRGB;
  }
  return fallbackFormat;
}

void setContentsImageFormat(CALayer* __unsafe_unretained layer, STUPredefinedCGImageFormat format) {
  NSString* __unsafe_unretained formatString = nil;
  switch (format) {
  case STUPredefinedCGImageFormatRGB:
    formatString = kCAContentsFormatRGBA8Uint;
    break;
  case STUPredefinedCGImageFormatExtendedRGB:
    formatString = kCAContentsFormatRGBA16Float;
    break;
  case STUPredefinedCGImageFormatGrayscale:
    formatString = kCAContentsFormatGray8Uint;
    break;
  default:
    STU_DEBUG_ASSERT(false && "invalid STUPredefinedCGImageFormat");
    formatString = kCAContentsFormatRGBA8Uint;
  }
  layer.contentsFormat = formatString;
}

} // namespace stu_label
