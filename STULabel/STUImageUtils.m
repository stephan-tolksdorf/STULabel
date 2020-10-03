// Copyright 2017–2018 Stephan Tolksdorf

#import "STUImageUtils.h"

#import "stu/Assert.h"

#import <tgmath.h>

STU_EXPORT
STUCGImageFormat stuCGImageFormat(STUPredefinedCGImageFormat format,
                                  STUCGImageFormatOptions options)
{
  static bool casUseLA8; // iOS 9 doesn't support the grayscale + alpha pixel format.
  static CGColorSpaceRef grayGamma2_2;
  static CGColorSpaceRef sRGB;
  static CGColorSpaceRef extendedSRGB;

  static dispatch_once_t once;
  dispatch_once(&once, ^{
    grayGamma2_2 = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
    sRGB = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (@available(iOS 10, tvOS 10, macOS 10.12, *)) {
      casUseLA8 = true;
      extendedSRGB = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    }
  });

  const bool withoutAlpha = options & STUCGImageFormatWithoutAlphaChannel;

  uint8_t bitsPerComponent = 8;
  uint8_t bitsPerPixel;
  CGBitmapInfo bitmapInfo;
  CGColorSpaceRef colorSpace;

  switch (format) {
  case STUPredefinedCGImageFormatGrayscale:
    colorSpace = grayGamma2_2;
    if (withoutAlpha) {
      bitsPerPixel = 8;
      bitmapInfo = 0;
      break;
    }
    if (casUseLA8) {
      bitsPerPixel = 16;
      bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast; // LA8
      break;
    }
    STU_FALLTHROUGH
  case STUPredefinedCGImageFormatExtendedRGB:
    if (extendedSRGB) {
      colorSpace = extendedSRGB;
      bitsPerComponent = 16;
      bitsPerPixel = 64;
      bitmapInfo = kCGBitmapFloatComponents
                 | kCGImageByteOrder16Little
                 | (withoutAlpha ? kCGImageAlphaNoneSkipLast        // RGBX16
                                 : kCGImageAlphaPremultipliedLast); // RGBA16
      break;
    }
    STU_FALLTHROUGH
  case STUPredefinedCGImageFormatRGB:
    colorSpace = sRGB;
    bitsPerPixel = 32;
    bitmapInfo = kCGBitmapByteOrder32Little
               | (withoutAlpha ? kCGImageAlphaNoneSkipFirst        // BGRX8
                               : kCGImageAlphaPremultipliedFirst); // BGRA8
    break;
  }
  return (STUCGImageFormat){
           .colorSpace = colorSpace,
           .bitmapInfo = bitmapInfo,
           .bitsPerComponent = bitsPerComponent,
           .bitsPerPixel = bitsPerPixel
         };
}

STU_EXPORT
CGContextRef stu_createCGBitmapContext(size_t widthInPixels, size_t heightInPixels, CGFloat scale,
                                       __nullable CGColorRef backgroundColor,
                                       STUCGImageFormat imageFormat,
                                       void * __nullable data, size_t bytesPerRow)
               CF_RETURNS_RETAINED
{
#if STU_DEBUG
  STU_CHECK_MSG(scale > 0 || scale < 0, "scale must not be 0 or NaN");
  STU_CHECK_MSG(imageFormat.bitsPerPixel >= 8
                && (imageFormat.bitsPerPixel & (imageFormat.bitsPerPixel - 1)) == 0,
                "imageFormat.bitsPerPixel must be a power of 2 not less than 8");
  STU_ASSERT(!data || bytesPerRow != 0);
#else
  if (STU_UNLIKELY(!(   (scale > 0 || scale < 0)
                     && (imageFormat.bitsPerPixel >= 8
                         && (imageFormat.bitsPerPixel & (imageFormat.bitsPerPixel - 1)) == 0)
                     && (!data || bytesPerRow != 0))))
  {
    NSLog(@"Invalid argument passed to stu_createCGBitmapContext");
    return nil;
  }
#endif

  widthInPixels = MAX(1u, widthInPixels);
  heightInPixels = MAX(1u, heightInPixels);

  const CGContextRef context = CGBitmapContextCreate(data, widthInPixels, heightInPixels,
                                                     imageFormat.bitsPerComponent, bytesPerRow,
                                                     imageFormat.colorSpace,
                                                     imageFormat.bitmapInfo);
#if STU_DEBUG
  STU_CHECK_MSG(context != nil, "Failed to create bitmap context with the specified parameters");
#else
  if (STU_UNLIKELY(!context)) {
    NSLog(@"stu_createCGBitmapContext failed to create bitmap context with the specified parameters");
    return nil;
  }
#endif

  const CGFloat fHeightInPixels = (CGFloat)heightInPixels;

  if (backgroundColor) {
    CGContextSetFillColorWithColor(context, backgroundColor);
    CGContextFillRect(context, (CGRect){{0, 0}, {(CGFloat)widthInPixels, fHeightInPixels}});
  }
  if (scale != -1) {
    const CGFloat absScale = fabs(scale);
    const CGFloat d = scale > 0 ? -absScale : absScale;
    const CGFloat ty = scale > 0 ? fHeightInPixels : 0;
    CGContextConcatCTM(context, (CGAffineTransform){.a = absScale, .d = d, .ty = ty});
  }
  return context;
}

STU_EXPORT
CGImageRef stu_createCGImage(CGSize size, CGFloat scale,
                             __nullable CGColorRef backgroundColor,
                             STUCGImageFormat imageFormat,
                             void (^ STU_NOESCAPE __unsafe_unretained
                                     drawingBlock)(__nonnull CGContextRef context))
             CF_RETURNS_RETAINED
{
#if STU_DEBUG
  STU_CHECK_MSG(size.width >= 0 && size.height >= 0,
                "size.width and size.height must not be negative or NaN");
  STU_ASSERT(drawingBlock != nil);
#else
  if (STU_UNLIKELY(   !(size.width >= 0 && size.height >= 0)
                   || drawingBlock == nil))
  {
    NSLog(@"Invalid argument passed to stu_createCGImage");
    return nil;
  }
#endif

  // The other arguments are checked by stu_createCGBitmapContext.

  const CGFloat absScale = fabs(scale);
  CGFloat width  = nearbyint(size.width*absScale);
  CGFloat height = nearbyint(size.height*absScale);
  _Static_assert(sizeof(CGFloat) == 4 || sizeof(CGFloat) == 8, "Unexpected CGFloat type");
  _Static_assert(sizeof(size_t) == 4 || sizeof(size_t) == 8, "Unexpected size_t type");
  _Static_assert(sizeof(CGFloat) >= sizeof(size_t), "Unexpected CGFloat and size_t types");
  const CGFloat maxValue = sizeof(size_t) == 4
                         ? (sizeof(CGFloat) == 4 ? 4294967040.f // Float32(pow(2.0, 32)).nextDown
                                                 : (CGFloat)UINT32_MAX)
                         : (CGFloat)18446744073709549568ull; // Float64(pow(2.0, 64)).nextDown
  if (STU_UNLIKELY(!(width >= 1))) {
    width = 1;
  } else if (STU_UNLIKELY(width > maxValue)) {
    width = maxValue;
  }
  if (STU_UNLIKELY(!(height >= 1))) {
    height = 1;
  } else if (STU_UNLIKELY(height > maxValue)) {
    height = maxValue;
  }

  const CGContextRef context = stu_createCGBitmapContext((size_t)width, (size_t)height,
                                                         scale, backgroundColor, imageFormat,
                                                         nil, 0);
  if (!context) return nil;

  drawingBlock(context);

  const CGImageRef image = CGBitmapContextCreateImage(context);

  CFRelease(context);

  return image;
}
