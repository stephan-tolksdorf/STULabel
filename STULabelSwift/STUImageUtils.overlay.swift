// Copyright 2018 Stephan Tolksdorf

import STULabel.ImageUtils
import STULabel.MainScreenProperties

extension STUCGImageFormat {
  //  @inlinable // swift inlining bug
  public init(_ predefinedFormat: STUCGImageFormat.Predefined,
              _ options: STUCGImageFormat.Options = [])
  {
    self = __stuCGImageFormat(predefinedFormat, options)
  }

  @inlinable
  public var colorSpace: CGColorSpace {
    return __colorSpace.takeUnretainedValue()
  }

  @inlinable
  public var bitsPerComponent: Int {
    get { return Int(__bitsPerComponent) }
    set { __bitsPerComponent = UInt16(newValue) }
  }

  @inlinable
  public var bitsPerPixel: Int {
    get { return Int(__bitsPerPixel) }
    set { __bitsPerPixel = UInt16(newValue) }
  }

  @inlinable
  public static var rgb: STUCGImageFormat { return STUCGImageFormat(.rgb) }

  @inlinable
  public static var extendedRGB: STUCGImageFormat { return STUCGImageFormat(.extendedRGB) }

  @inlinable
  public static var grayscale: STUCGImageFormat { return STUCGImageFormat(.grayscale) }
}

/// - Parameters:
///   - size:
///     The size of the bitmap in pixels is determined by multiplying the width and height of
///     this `CGSize` with the absolute value of the specified scale and then rounding the
///     resulting values to integers.
///   - scale:
///     The CTM of the context passed to `drawingBlock` is scaled by the absolute value of this
///     argument. If the scale is positive, the context has a top-left origin (as is the UIKit
///     convention), otherwise a lower-left origin.
///   - format: The image format parameters.
///   - backgroundColor:
///     If not null, all pixels of the bitmap are initialized to this color
///     and the fill color of the context is also set to this color.
///   - drawingBlock: This block will be called in order to draw the image.
///
@inlinable
public func stu_createCGImage(size: CGSize, scale: CGFloat = stu_mainScreenScale(),
                              backgroundColor: CGColor? = nil,
                              _ format: STUCGImageFormat = .rgb,
                              _ drawingBlock: (CGContext) -> ())
         -> CGImage?
{
  return __stu_createCGImage(size, scale, backgroundColor, format, drawingBlock)
}

/// Wraps `CGBitmapContextCreate`.
///
/// - Note: The size of the bitmap in pixels is only determined by `widthInPixels` and
///         `heightInPixels`. The specified scale does NOT influence the size of the bitmap.
/// - Parameters:
///   - widthInPixels:
///     The width of the context, in pixels. Will be clamped to a value >= 1.
///   - heightInPixels:
///     The height of the context, in pixels. Will be clamped to a value >= 1.
///   - scale:
///     The CTM of the returned context is scaled by the absolute value of this argument.
///     If the scale is positive, the context has a top-left origin (as is the UIKit convention),
///     otherwise a lower-left origin.
///   - backgroundColor:
///     If not null, all pixels of the bitmap are initialized to this color
///     and the fill color of the context is also set to this color.
///   - format: The image format parameters for the bitmap context.
///   - data:
///     A pointer to the destination in memory where the drawing is to be rendered. The size of
///     this memory block should be at least pixelHeight*bytesPerRow bytes. Pass null if you want
///     this function to allocate and manage the memory for the bitmap.
///   - bytesPerRow
///     The number of bytes of memory to use per row of the bitmap. If `data` is null,
///     passing a value of 0 causes the value to be calculated automatically. If the `data`
///     argument is not null, this value must not be 0.
@inlinable
public func stu_createCGBitmapContext(widthInPixels: Int, heightInPixels: Int,
                                      scale: CGFloat = stu_mainScreenScale(),
                                      backgroundColor: CGColor? = nil,
                                      _ format: STUCGImageFormat = .rgb,
                                      data: UnsafeMutableRawPointer? = nil,
                                      bytesPerRow: Int = 0)
         -> CGContext?
{
  return __stu_createCGBitmapContext(max(1, widthInPixels), max(1, heightInPixels), scale,
                                     backgroundColor, format, data, bytesPerRow)
}

