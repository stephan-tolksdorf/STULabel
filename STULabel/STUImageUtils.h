// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

STU_EXTERN_C_BEGIN

typedef NS_ENUM(uint8_t, STUPredefinedCGImageFormat) {
  STUPredefinedCGImageFormatRGB         NS_SWIFT_NAME(rgb) = 0,
  STUPredefinedCGImageFormatExtendedRGB                    = 1,
  STUPredefinedCGImageFormatGrayscale                      = 2
} NS_SWIFT_NAME(STUCGImageFormat.Predefined);
enum { STUPredefinedCGImageFormatBitSize STU_SWIFT_UNAVAILABLE = 2 };

typedef NS_OPTIONS(uint32_t, STUCGImageFormatOptions) {
  STUCGImageFormatOptionsNone         = 0,
  STUCGImageFormatWithoutAlphaChannel = 1
} NS_SWIFT_NAME(STUCGImageFormat.Options);

typedef struct STUCGImageFormat {
  __nonnull CGColorSpaceRef colorSpace NS_REFINED_FOR_SWIFT;
  CGBitmapInfo bitmapInfo;
  uint16_t bitsPerComponent NS_REFINED_FOR_SWIFT;
  uint16_t bitsPerPixel NS_REFINED_FOR_SWIFT;

  // public init(_ predefinedFormat: STUCGImageFormat.Predefined,
  //             _ options: STUCGImageFormat.Options = [])
  
} STUCGImageFormat;

STUCGImageFormat stuCGImageFormat(STUPredefinedCGImageFormat, STUCGImageFormatOptions)
  NS_REFINED_FOR_SWIFT;

/// @param size
///        The size of the bitmap in pixels is determined by multiplying the width and height of
///        this @c CGSize with the absolute value of the specified scale and then rounding the
///        resulting values to integers.
/// @param scale
///        The CTM of the context passed to @c drawingBlock is scaled by the absolute value of this
///        argument. If the scale is positive, the context has a top-left origin (as is the UIKit
///        convention), otherwise a lower-left origin.
/// @param backgroundColor
///        If not null, all pixels of the bitmap are initialized to this color
///        and the fill color of the context is also set to this color.
/// @param format The image format parameters.
/// @param drawingBlock This block will be called in order to draw the image.
__nullable CGImageRef stu_createCGImage(CGSize size, CGFloat scale,
                                        __nullable CGColorRef backgroundColor,
                                        STUCGImageFormat format,
                                        void (^ STU_NOESCAPE __nonnull
                                              drawingBlock)(__nonnull CGContextRef context))
  CF_RETURNS_RETAINED
  NS_REFINED_FOR_SWIFT;

/// Wraps @c CGBitmapContextCreate.
///
/// @note The size of the bitmap in pixels is only determined by @c widthInPixels and
///       @c heightInPixels. The specified scale does NOT influence the size of the bitmap.
///
/// @param widthInPixels
///        The width of the context, in pixels. Will be clamped to a value >= 1.
/// @param heightInPixels
///        The height of the context, in pixels. Will be clamped to a value >= 1.
/// @param scale
///        The CTM of the returned context is scaled by the absolute value of this argument.
///        If the scale is positive, the context has a top-left origin (as is the UIKit convention),
///        otherwise a lower-left origin.
/// @param backgroundColor
///        If not null, all pixels of the bitmap are initialized to this color
///        and the fill color of the context is also set to this color.
/// @param format The image format parameters for the bitmap context.
/// @param data
///        A pointer to the destination in memory where the drawing is to be rendered. The size of
///        this memory block should be at least pixelHeight*bytesPerRow bytes. Pass null if you want
///        this function to allocate and manage the memory for the bitmap.
/// @param bytesPerRow
///        The number of bytes of memory to use per row of the bitmap. If @c data is null,
///        passing a value of 0 causes the value to be calculated automatically. If the `data`
///        argument is not null, this value must not be 0.
__nullable CGContextRef stu_createCGBitmapContext(size_t widthInPixels, size_t heightInPixels,
                                                  CGFloat scale,
                                                  __nullable CGColorRef backgroundColor,
                                                  STUCGImageFormat format,
                                                  void* __nullable data, size_t bytesPerRow)
  CF_RETURNS_RETAINED
  NS_REFINED_FOR_SWIFT;

STU_EXTERN_C_END
