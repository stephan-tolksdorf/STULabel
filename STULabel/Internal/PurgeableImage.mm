// Copyright 2018 Stephan Tolksdorf

#import "PurgeableImage.hpp"

#include "DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

namespace stu_label {

PurgeableImage::PurgeableImage(CGSize size, CGFloat scale, __nullable CGColorRef backgroundColor,
                               STUPredefinedCGImageFormat format,
                               STUCGImageFormatOptions formatOptions,
                               FunctionRef<void(CGContext*)> drawingFunction)
: PurgeableImage{SizeInPixels<UInt32>{size, scale}, scale, backgroundColor, format, formatOptions,
                 drawingFunction}
{}

PurgeableImage::PurgeableImage(SizeInPixels<UInt32> size, CGFloat scale,
                               __nullable CGColorRef backgroundColor,
                               STUPredefinedCGImageFormat format,
                               STUCGImageFormatOptions formatOptions,
                               FunctionRef<void(CGContext*)> drawingFunction)
: PurgeableImage{}
{
  size.width = max(1u, size.width);
  size.height = max(1u, size.height);

  const STUCGImageFormat imageFormat = stuCGImageFormat(format, formatOptions);

  UInt bytesPerRow;
  UInt allocationSize;
  NSPurgeableData* data;
  void* bytes;
  CGContextRef context;

  if (__builtin_mul_overflow(size.width, imageFormat.bitsPerPixel/8, &bytesPerRow)) goto Failure;
  if (bytesPerRow > stu::maxValue<UInt> - 31) goto Failure;
  bytesPerRow = roundUpToMultipleOf<32>(bytesPerRow);
  if (bytesPerRow/32 > stu::maxValue<UInt32>) goto Failure;

  if (__builtin_mul_overflow(bytesPerRow, size.height, &allocationSize)) goto Failure;

  data = [[NSPurgeableData alloc] initWithLength:allocationSize];
  bytes = [data mutableBytes];
  if (!bytes) goto Failure;

  // The memory allocated by NSPurgeableData should be page-aligned.
  STU_DEBUG_ASSERT((reinterpret_cast<uintptr_t>(bytes) & 4095) == 0);

  context = stu_createCGBitmapContext(size.width, size.height, scale, backgroundColor, imageFormat,
                                      bytes, bytesPerRow);
  if (!context) return; // stu_createCGBitmapContext already logs any error.
  drawingFunction(context);
  CGContextFlush(context);
  CFRelease(context);

  *this = PurgeableImage(data, size, format, formatOptions, bytesPerRow);
  return;

Failure:
#if STU_DEBUG
  STU_CHECK_MSG(false, "Failed to allocate purgeable image bitmap buffer");
#else
  NSLog(@"Failed to allocate purgeable image bitmap buffer");
#endif
  return;
}

void PurgeableImage::makePurgeableOnceAllCGImagesAreDestroyed() {
  if (!hasUnconsumedContentAccessBegin_) return;
  hasUnconsumedContentAccessBegin_ = false;
  [data_ endContentAccess];
}

bool PurgeableImage::tryMakeNonPurgeableUntilNextCGImageIsCreated() {
  if (hasUnconsumedContentAccessBegin_) {
    STU_DEBUG_ASSERT(data_ != nil);
    return true;
  }
  if (data_) {
    if ([data_ beginContentAccess]) {
      hasUnconsumedContentAccessBegin_ = true;
      return true;
    }
    data_ = nil;
  }
  return false;
}

static void endCGImageContentAccess(void* info, const void* __unused bytes, size_t __unused size) {
  [(__bridge_transfer NSPurgeableData*)info endContentAccess];
}

RC<CGImage> PurgeableImage::createCGImage() {
  if (hasUnconsumedContentAccessBegin_) {
    hasUnconsumedContentAccessBegin_ = false;
    STU_DEBUG_ASSERT(data_ != nil);
  } else {
    if (!data_) return nullptr;
    if (![data_ beginContentAccess]) {
      data_ = nil;
      return nullptr;
    }
  }
  const CGDataProviderRef dp = CGDataProviderCreateWithData((__bridge_retained void*)data_,
                                                            data_.bytes, data_.length,
                                                            endCGImageContentAccess);
  const STUCGImageFormat format = stuCGImageFormat(format_, formatOptions_);
  RC<CGImage> image = {CGImageCreate(size_.width, size_.height, format.bitsPerComponent,
                                     format.bitsPerPixel,
                                     static_cast<UInt>(bytesPerRowDiv32_)*32,
                                     format.colorSpace, format.bitmapInfo, dp,
                                     nullptr, true, kCGRenderingIntentPerceptual),
                       ShouldIncrementRefCount{false}};
  STU_DEBUG_ASSERT(image);
  CFRelease(dp);
  return image;
}

} // stu_label
