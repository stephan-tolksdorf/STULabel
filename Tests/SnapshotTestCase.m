// Copyright 2017–2018 Stephan Tolksdorf

#import "SnapshotTestCase.h"

#import <Accelerate/Accelerate.h>

static CGColorSpaceRef sRGB;
static CGColorSpaceRef grayGamma2_2;
static CGColorSpaceRef displayP3;
static CGColorSpaceRef extendedSRGB;

static void initStaticColorSpacesOnce() {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    sRGB = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    grayGamma2_2 = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunguarded-availability"
    if (kCGColorSpaceDisplayP3) {
      displayP3 = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    }
    if (kCGColorSpaceExtendedSRGB) {
      extendedSRGB = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    }
    #pragma clang diagnostic pop
  });
}

static inline bool isColorSpaceEqualToSpace(__nonnull CGColorSpaceRef space1,
                                            __nonnull CGColorSpaceRef space2)
{
  return space1 == space2 || CFEqual(space1, space2);
}


static NSString *escapeFilename(NSString *fileName) {
  return [[[fileName stringByReplacingOccurrencesOfString:@":"  withString:@"_"]
                     stringByReplacingOccurrencesOfString:@"/"  withString:@"_"]
                     stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
}


@implementation SnapshotTestCase {
  NSString* _imageBaseDirectory;
  NSString* _subpath; ///< "TestClass/testMethodName"
  NSString* _fullpath; ///< _imageBaseDirectory / _subpath
  NSFileManager* _fileManager;
}

- (id)initWithInvocation:(NSInvocation *)invocation {
  initStaticColorSpacesOnce();
  if ((self = [super initWithInvocation:invocation])) {
    _fileManager = NSFileManager.defaultManager;
    NSString *name = NSStringFromClass(self.class);
    const NSRange i = [name rangeOfString:@"." options:NSBackwardsSearch];
    if (i.location != NSNotFound) {
      name = [name substringFromIndex:i.location + 1];
    }
    _subpath = [escapeFilename(name) stringByAppendingPathComponent:
                                       escapeFilename(NSStringFromSelector(invocation.selector))];
  }
  return self;
}

#define fatalError(format, ...) \
  (NSLog((format), ##__VA_ARGS__), __builtin_trap())

- (void)setImageBaseDirectory:(NSString *)imageBaseDirectory {
  if (!imageBaseDirectory) {
    fatalError(@"SnapshotTestCase.imageBaseDirectory must not be nil");
  }
  _imageBaseDirectory = imageBaseDirectory;
  _fullpath = [_imageBaseDirectory stringByAppendingPathComponent:_subpath];
}

- (void)checkSnapshotImage:(UIImage *)image
            testNameSuffix:(NSString *)suffix
              testFilePath:(const char *)testFilePath
              testFileLine:(size_t)line
            referenceImage:(nullable UIImage *)referenceImage;
{
  #define reportFailureOrError(isFailure, format, ...) \
    _XCTFailureHandler(self, (isFailure), testFilePath, line, \
                      _XCTFailureDescription(_XCTAssertion_Fail, 0), (format), ##__VA_ARGS__)
  // For test failures:
  #define reportFailure(format, ...) reportFailureOrError(true, format, ##__VA_ARGS__)
  // For violated preconditions and errors that occur while we check the image:
  #define reportError(format, ...) reportFailureOrError(false, format, ##__VA_ARGS__)

  if (!_fullpath) {
    reportError(@"SnapshotTestCase.imageBaseDirectory must be set before checkSnapshotImage"
                 " is called");
    return;
  }
  if (!image) {
    reportFailure(@"The image is nil");
    return;
  }
  if (image.imageOrientation != UIImageOrientationUp) {
    reportError(@"The imageOrientation of snapshot images must be .up");
    return;
  }
  {
    const CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
      reportError(@"The image must have a non-nil CGImage property");
      return;
    }
    if (CGImageIsMask(cgImage)) {
      reportError(@"The image must must not be a mask image (i.e. have only an alpha channel)");
      return;
    }
  }

  image = convertImageToFormatExactlyRepresentableAsPNG(image);

  NSString * const escapedSuffix = suffix ? escapeFilename(suffix) : nil;
  NSString * const path = [!escapedSuffix ? _fullpath
                                          : [_fullpath stringByAppendingString:escapedSuffix]
                             stringByAppendingString:@".png"];
  if (_shouldRecordSnapshotsInsteadOfCheckingThem) {
    [self stu_createDirectoryIfNecesary:[path stringByDeletingLastPathComponent]];
    [self stu_savePNGImage:image path:path];
    reportFailure(@"Saved a reference image. Rerun the test with"
                   " shouldRecordSnapshotsInsteadOfCheckingThem set to false!");
    return;
  }
  if (!referenceImage) {
    if (![_fileManager fileExistsAtPath:path]) {
      reportError(@"Missing snapshot image at '%@'. Did you forget to record a reference snapshot"
                  " by running the test with shouldRecordSnapshotsInsteadOfCheckingThem set to"
                  " true?", path);
      return;
    }
    referenceImage = [self stu_loadPNGImageAtPath:path];
  }
  const CGFloat imageScale = referenceImage.scale;
  const CGFloat referenceImageScale = referenceImage.scale;
  if (imageScale != referenceImageScale) {
    reportFailure(@"The scale of the snapshot image (%f) is different from the scale of the"
                  " reference image (%f)", image.scale, referenceImageScale);
    return;
  }
  const CGImageRef cgImage = image.CGImage;
  const CGImageRef cgReferenceImage = referenceImage.CGImage;
  const size_t width = CGImageGetWidth(cgReferenceImage);
  const size_t height = CGImageGetHeight(cgReferenceImage);
  const bool sizeIsDifferent = width != CGImageGetWidth(cgImage)
                            || height != CGImageGetHeight(cgImage);
  UIImage *diffImage = nil;
  if (!sizeIsDifferent) {
    const CGImageRef cgDiffImage = createDiffImage(cgImage, cgReferenceImage);
    if (!cgDiffImage) { // No difference.
      return;
    }
    diffImage = [[UIImage alloc] initWithCGImage:cgDiffImage scale:imageScale
                                     orientation:UIImageOrientationUp];
    CFRelease(cgDiffImage);
  }
  NSString *diffPath;
  const char* const env_diffDir = getenv("IMAGE_DIFF_DIR");
  if (env_diffDir) {
    diffPath = [[NSString alloc] initWithUTF8String:env_diffDir];
  } else {
    diffPath = NSTemporaryDirectory();
  }
  diffPath = [diffPath stringByAppendingPathComponent:_subpath];
  if (escapedSuffix) {
    diffPath = [diffPath stringByAppendingString:escapedSuffix];
  }
  [self stu_createDirectoryIfNecesary:[diffPath stringByDeletingLastPathComponent]];
  [self stu_savePNGImage:referenceImage path:[diffPath stringByAppendingString:@"_reference.png"]];
  [self stu_savePNGImage:image path:[diffPath stringByAppendingString:@"_failed.png"]];
  if (!sizeIsDifferent) {
    [self stu_savePNGImage:diffImage path:[diffPath stringByAppendingString:@"_diff.png"]];
    reportFailure(@"The snapshot is different from the reference image."
                  " The image diff has been saved to: %@_diff.png", diffPath);
  } else {
    reportFailure(@"The size (%@) of the snapshot image is different from the size of the reference"
                  " image (%@). Both images have been saved to: '%@(_failed|_reference).png'.",
                  NSStringFromCGSize(image.size), NSStringFromCGSize(referenceImage.size),
                  diffPath);
  }
  #undef reportFailure
  #undef reportError
}

- (void)stu_createDirectoryIfNecesary:(NSString *)directory {
  NSError *error;
  if ([_fileManager createDirectoryAtPath:directory
              withIntermediateDirectories:true attributes:nil error:&error])
  {
    return;
  }
  fatalError(@"SnapshotTestCase failed to create directory '%@': %@",
             directory, error.localizedDescription);

}

- (void)stu_savePNGImage:(UIImage *)image path:(NSString *)path {
  NSError *error;
  if ([UIImagePNGRepresentation(image) writeToFile:path options:NSDataWritingAtomic error:&error]) {
    return;
  }
  fatalError(@"SnapshotTestCase failed to save image at '%@': %@",
             path, error.localizedDescription);
}

- (UIImage *)stu_loadPNGImageAtPath:(NSString *)path {
  static NSDictionary *options;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    options = @{(__bridge NSString *)kCGImageSourceShouldCache: @false,
                (__bridge NSString *)kCGImageSourceShouldAllowFloat: @true};
  });

  NSError *error;
  NSData * const data = [NSData dataWithContentsOfFile:path options:0 error:&error];
  const CGImageSourceRef source = !data ? nil
                                : CGImageSourceCreateWithData((__bridge CFDataRef)(data), nil);
  const CGImageRef image = !source ? nil
                         : CGImageSourceCreateImageAtIndex(source, 0,
                                                           (__bridge CFDictionaryRef)options);
  if (!image) {
    fatalError(@"SnapshotTestCase failed to open image at '%@': %@",
               path, error.localizedDescription);
  }
  const CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
  const CFNumberRef dpi = CFDictionaryGetValue(props, kCGImagePropertyDPIWidth);
  CGFloat scale = 1;
  if (dpi && CFNumberGetValue(dpi, kCFNumberCGFloatType, &scale)) {
    scale /= 72;
  }
  CFRelease(props);
  UIImage * const uiImage = [[UIImage alloc] initWithCGImage:image scale:scale
                                                 orientation:UIImageOrientationUp];
  CFRelease(image);
  CFRelease(source);
  return uiImage;
}

typedef struct {
  CGColorSpaceRef colorSpace;
  CGBitmapInfo bitmapInfo;
  uint16_t bitsPerPixel;
  uint16_t bitsPerComponent;
} BitmapFormat;

static bool isBitmapFormatEqualToFormat(BitmapFormat format1, BitmapFormat format2) {
  return format1.bitmapInfo == format2.bitmapInfo
      && format1.bitsPerPixel == format2.bitsPerPixel
      && format1.bitsPerComponent == format2.bitsPerComponent
      && isColorSpaceEqualToSpace(format1.colorSpace, format2.colorSpace);
}

static BitmapFormat bitmapFormatOfCGImage(CGImageRef image) {
  return (BitmapFormat){.colorSpace       = CGImageGetColorSpace(image),
                        .bitmapInfo       = CGImageGetBitmapInfo(image),
                        .bitsPerPixel     = (uint16_t)CGImageGetBitsPerPixel(image),
                        .bitsPerComponent = (uint16_t)CGImageGetBitsPerComponent(image)};
}

static inline bool bitmapInfoHasNoAlphaChannel(CGBitmapInfo info) {
  switch (info & kCGBitmapAlphaInfoMask) {
  case kCGImageAlphaNone:
  case kCGImageAlphaNoneSkipFirst:
  case kCGImageAlphaNoneSkipLast:
    return true;
  default:
    return false;
  }
}

static UIImage *convertImageToFormatExactlyRepresentableAsPNG(UIImage *uiImage) {
  const CGImageRef image = uiImage.CGImage;
  const CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
  const bool isPersistableSpace =  isColorSpaceEqualToSpace(colorSpace, sRGB)
                                || isColorSpaceEqualToSpace(colorSpace, grayGamma2_2)
                                || (displayP3 && isColorSpaceEqualToSpace(colorSpace, displayP3));
  const CGBitmapInfo bitmapInfo =  CGImageGetBitmapInfo(image);
  const bool hasFloatComponents = bitmapInfo & kCGBitmapFloatComponents;
  if (!hasFloatComponents && isPersistableSpace) {
    return uiImage;
  }
  const bool noAlpha = bitmapInfoHasNoAlphaChannel(bitmapInfo);
  const CGColorSpaceRef persistableSpace =
      isPersistableSpace ? colorSpace
    : CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelMonochrome ? grayGamma2_2
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunguarded-availability"
    : CGColorSpaceIsWideGamutRGB && CGColorSpaceIsWideGamutRGB(colorSpace) ? displayP3
    #pragma clang diagnostic pop
    : sRGB;
  vImage_CGImageFormat format = {.colorSpace = persistableSpace,
                                 .bitsPerComponent = (uint32_t)CGImageGetBitsPerComponent(image),
                                 .renderingIntent = kCGRenderingIntentRelativeColorimetric};
  if (format.bitsPerComponent != 8 && format.bitsPerComponent != 16) {
    fatalError(@"SnapshotTestCase image format not supported");
  }
  if (persistableSpace == grayGamma2_2) {
    format.bitsPerPixel = (noAlpha ? 1 : 2)*format.bitsPerComponent;
    format.bitmapInfo = noAlpha ? 0 : (CGBitmapInfo)kCGImageAlphaLast;
  } else {
    format.bitsPerPixel = (noAlpha ? 3 : 4)*format.bitsPerComponent;
    format.bitmapInfo = (CGBitmapInfo)(noAlpha ? kCGImageAlphaNoneSkipLast : kCGImageAlphaLast);
  }
  vImage_Buffer buffer;
  vImage_Error error = vImageBuffer_InitWithCGImage(&buffer, &format, nil, image,
                                                    kvImagePrintDiagnosticsToConsole);
  if (error) {
    fatalError(@"SnapshotTestCase image format conversion failed");
  }
  const CGImageRef newImage = vImageCreateCGImageFromBuffer(&buffer, &format, nil, nil, 0, &error);
  if (!newImage) {
    fatalError(@"SnapshotTestCase image format conversion failed");
  }
  return [[UIImage alloc] initWithCGImage:newImage scale:uiImage.scale
                              orientation:uiImage.imageOrientation];
}

static bool imageDataIsEqual(size_t width, size_t height, size_t bytesPerPixel,
                             const uint8_t *bytes1, size_t bytesPerRow1,
                             const uint8_t *bytes2, size_t bytesPerRow2)
{
  const size_t usedBytesPerRow = width*bytesPerPixel;
  if (bytesPerRow1 == bytesPerRow2) {
    if (memcmp(bytes1, bytes2, bytesPerRow1*height) == 0) return true;
    if (bytesPerRow1 == usedBytesPerRow) return false;
  }
  for (size_t i = 0; i < height; ++i) {
    if (memcmp(bytes1 + i*bytesPerRow1, bytes2 + i*bytesPerRow2, usedBytesPerRow) != 0) {
      return false;
    }
  }
  return true;
}

__attribute__((always_inline))
static inline void diffMaskLoop(size_t width, size_t height, size_t bytesPerPixel,
                                const uint8_t *bytes1, size_t bytesPerRow1,
                                const uint8_t *bytes2, size_t bytesPerRow2,
                                uint8_t *outMask, size_t outMaskBytesPerRow)
{
  const size_t n = width/8;
  const size_t r = width%8;
  for (size_t i = 0; i < height; ++i) {
    const uint8_t *p1 = &bytes1[i*bytesPerRow1];
    const uint8_t *p2 = &bytes2[i*bytesPerRow2];
    uint8_t *pOut = &outMask[i*outMaskBytesPerRow];
    for (size_t j = 0; j < n; ++j) {
      // The *most* significant bit in the mask byte represents the first mask pixel.
      uint8_t m = __builtin_memcmp(p1, p2, bytesPerPixel) == 0;
      p1 += bytesPerPixel;
      p2 += bytesPerPixel;
      for (size_t k = 1; k < 8; ++k) {
        m <<= 1;
        m |= __builtin_memcmp(p1, p2, bytesPerPixel) == 0;
        p1 += bytesPerPixel;
        p2 += bytesPerPixel;
      }
      *pOut = m;
      ++pOut;
    }
    if (r != 0) {
      uint8_t m = __builtin_memcmp(p1, p2, bytesPerPixel) == 0;
      size_t c = r;
      while (--c) {
        p1 += bytesPerPixel;
        p2 += bytesPerPixel;
        m <<= 1;
        m |= __builtin_memcmp(p1, p2, bytesPerPixel) == 0;
      }
      *pOut = (uint8_t)(m << (8 - r));
    }
  }
}

static void freeData(void *info, const void *data __unused, size_t size __unused) {
  free(info);
}


/// Creates a 1-bit-per-pixel mask where each bit indicates whether the corresponding pixels of the
/// two images are identical.
__attribute__((noinline))
static CGImageRef createDiffMask(size_t width, size_t height, size_t bytesPerPixel,
                                 const uint8_t* bytes1, size_t bytesPerRow1,
                                 const uint8_t* bytes2, size_t bytesPerRow2)
{
  const size_t n = ((width + 63)/64)*8; ///< Rounded up bytes per row.
  uint8_t* const mask = malloc(height*n);
  switch (bytesPerPixel) {
  case 1:
    diffMaskLoop(width, height, 1, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  case 2:
    diffMaskLoop(width, height, 2, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  case 3:
    diffMaskLoop(width, height, 3, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  case 4:
    diffMaskLoop(width, height, 4, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  case 6:
    diffMaskLoop(width, height, 6, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  case 8:
    diffMaskLoop(width, height, 8, bytes1, bytesPerRow1, bytes2, bytesPerRow2, mask, n);
    break;
  default:
    __builtin_trap();
  }
  const CGDataProviderRef dp = CGDataProviderCreateWithData(mask, mask, height*n, freeData);
  const CGImageRef image = CGImageMaskCreate(width, height, 1, 1, n, dp, nil, false);
  CFRelease(dp);
  return image;
}

/// Returns nil if the two argument images are identical, otherwise an image depicting the
/// difference of the two images.
static __nullable CGImageRef createDiffImage(CGImageRef image,
                                             CGImageRef referenceImage) CF_RETURNS_RETAINED
{
  const size_t width = CGImageGetWidth(referenceImage);
  const size_t height = CGImageGetHeight(referenceImage);
  if (width != CGImageGetWidth(image) || height != CGImageGetHeight(image)) {
    __builtin_trap();
  }
  const BitmapFormat format = bitmapFormatOfCGImage(referenceImage);

  const CFDataRef rData = CGDataProviderCopyData(CGImageGetDataProvider(referenceImage));
  const void* const rBytes = CFDataGetBytePtr(rData);
  const size_t rBytesPerRow = CGImageGetBytesPerRow(referenceImage);

  CFDataRef data;
  const void* bytes;
  size_t bytesPerRow;
  vImage_Buffer vbuffer;
  vImage_CGImageFormat vformat;
  if (isBitmapFormatEqualToFormat(bitmapFormatOfCGImage(image), format)) {
    data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    bytes = CFDataGetBytePtr(data);
    bytesPerRow = CGImageGetBytesPerRow(image);
    vbuffer.data = nil;
  } else {
    vformat = (vImage_CGImageFormat){
      .bitsPerComponent = format.bitsPerComponent,
      .bitsPerPixel = format.bitsPerPixel,
      .colorSpace = format.colorSpace,
      .bitmapInfo = format.bitmapInfo,
      .renderingIntent = kCGRenderingIntentRelativeColorimetric
    };
    const vImage_Error error = vImageBuffer_InitWithCGImage(
                                 &vbuffer, &vformat, nil, image,
                                 kvImagePrintDiagnosticsToConsole);
    if (error) {
      fatalError(@"SnapshotTestCase image image conversion failed");
    }
    data = nil;
    bytes = vbuffer.data;
    bytesPerRow = vbuffer.rowBytes;
  }

  const size_t bytesPerPixel = format.bitsPerPixel/8;
  const size_t usedBytesPerRow = width*bytesPerPixel;
  if (format.bitsPerPixel%8 || usedBytesPerRow > MIN(bytesPerRow, rBytesPerRow)) {
    fatalError(@"SnapshotTestCase image format not supported");
  }
  const bool isEqual = imageDataIsEqual(width, height, bytesPerPixel,
                                        bytes, bytesPerRow, rBytes, rBytesPerRow);
  CGImageRef diffImage = nil;
  if (!isEqual) {
    const CGImageRef diffMask = createDiffMask(width, height, bytesPerPixel,
                                               bytes, bytesPerRow, rBytes, rBytesPerRow);
    // CGBitmapContextCreate doesn't allow 16-bit integer channels.
    const bool useFloats = format.bitsPerComponent > 8;
    const size_t bitsPerComponent = useFloats ? 16 : 8;
    // Gray + Alpha pixel formats are not supported on iOS 9.
    const CGColorSpaceRef colorSpace =
      CGColorSpaceGetModel(format.colorSpace) == kCGColorSpaceModelMonochrome
      && kCFCoreFoundationVersionNumber <= kCFCoreFoundationVersionNumber_iOS_9_x_Max
      ? sRGB : format.colorSpace;
    const CGContextRef context = CGBitmapContextCreate(
                                   nil, width, height, bitsPerComponent, 0, colorSpace,
                                   kCGImageAlphaPremultipliedLast
                                   | (!useFloats ? 0
                                      : kCGBitmapFloatComponents | kCGImageByteOrder16Little));
    const CGRect rect = {0, 0, width, height};
    CGContextClipToMask(context, rect, diffMask);
    CGContextDrawImage(context, rect, referenceImage);
    CGContextSetBlendMode(context, kCGBlendModeDifference);
    if (data) {
      CGContextDrawImage(context, rect, image);
    } else {
      // We converted the original image data before comparing it, so let's also use the converted
      // image for drawing the diff.
      vImage_Error error;
      const CGImageRef converted = vImageCreateCGImageFromBuffer(
                                     &vbuffer, &vformat, nil, nil,
                                     kvImageNoAllocate | kvImagePrintDiagnosticsToConsole, &error);
      if (!converted) __builtin_trap();
      vbuffer.data = nil; // Ownership was transferred to the image.
      CGContextDrawImage(context, rect, converted);
      CFRelease(converted);
    }
    diffImage = CGBitmapContextCreateImage(context);
    CFRelease(context);
    CFRelease(diffMask);
  }

  if (data) {
    CFRelease(data);
  } else if (vbuffer.data) {
    free(vbuffer.data);
  }
  CFRelease(rData);

  return diffImage;
}

@end
