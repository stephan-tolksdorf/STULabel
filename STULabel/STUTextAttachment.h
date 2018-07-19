// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <UIKit/UIKit.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

NS_SWIFT_NAME(stuAttachment)
extern const NSAttributedStringKey STUAttachmentAttributeName;

@class STUTextAttachment;

typedef NS_OPTIONS(uint8_t, STUTextAttachmentColorInfo) {
  STUTextAttachmentIsGrayscale  = 1,
  /// Indicates that the attachment needs a bitmap context with a wide-gamut color space and more
  /// than 8-bits per color channel for optimal display quality.
  STUTextAttachmentUsesExtendedColors = 2
};

/// An immutable drawable object (e.g. an image) that should be displayed inline (like a text glyph)
/// when rendering a `NSAttributedString`.
///
/// `STUTextAttachment` instances are meant to be used as values for the
/// `STUAttachmentAttributeName` (`.stuAttachment`) key in `NSAttributedString` instances
/// that are displayed in `STULabel` views or rendered with the help of `STUTextFrame` instances.
///
/// `STUTextAttachment` is a replacement for `NSTextAttachment` that is more suitable for the
/// purposes of this library.
///
/// `STUTextAttachment` is meant to be used as a base class, e.g. for `STUImageTextAttachment`,
/// but you can also use it directly in order to create blank spaces in the running text, so that
/// you can e.g. place subviews over their locations.
///
/// @note
///  Subclasses of `STUTextAttachment` are expected to be immutable and the `drawInContext:` method
///  must be thread-safe.
///
/// In attributed strings an attachment should normally only be set as an attribute on a U+FFFC
/// character (`NSAttachmentCharacter`). When it is set on multiple characters, it will be drawn
/// multiple times.
///
/// CoreText does not support attachments directly and requires a `CTRunDelegate` attribute for
/// every attachment in order to compute correct typographic bounds.
///
/// In Objective-C code you can use the `+[NSAttributedString stu_newWithSTUAttachment:]` factory
/// method to conveniently create an attributed string containing a single U+FFFC character with
/// the specified attachment and an appropriate run delegate as attributes. In Swift code this
/// factory method is available as the initializer
/// `NSAttributedString(stu_attachment: myAttachment)`.
///
/// `CTRunDelegate` instances do not support `NSCoding`. Hence, if you need to archive an
/// `NSAttributedString` containing run delegates, you first need to remove the run delegates,
/// e.g. by using the `-[NSAttributedString stu_attributedStringByRemovingCTRunDelegates]`
/// method. To add back missing run delegates for `STUTextAttachment` instances you can use the
/// `-[NSAttributedString stu_attributedStringByAddingCTRunDelegatesForSTUAttachments]` method.
///
/// You can make a `STUTextAttachment` value individually accessible in a `STULabel` by setting
/// `isAccessibilityElement` to true and defining appropriate accessibility properties. However,
/// specifying an appropriate `stringRepresentation` when constructing the attachment is often
/// already enough to ensure good accessibility.
///
/// Equality for `STUTextAttachment` instances is defined as pointer equality.
STU_EXPORT
@interface STUTextAttachment : NSObject <NSSecureCoding>

/// @param width The typographic width of the attachment. Must be positive.
/// @param ascent The typographic ascent of the attachment. Usually this is a positive value.
/// @param descent
///        The typographic descent of the attachment. Usually this is a positive value (in contrast
///        to `UIFont.descender`, which returns the font's descent multiplied by -1).
/// @param leading
///        The typographic leading (minimum 'line gap') of the attachment. Must be non-negative.
/// @param imageBounds
///        The bounds of any content that may be drawn for the attachment relative to the
///        typographic origin of the attachment on the baseline of the line of text (assumes the
///        default UIKit upper-left-origin coordinate system).
/// @param colorInfo
///        Indicates whether the image is grayscale or needs an extended-color bitmap context for
///        optimal display quality.
/// @param stringRepresentation Represents the attachment in text-only contexts.
///
/// @pre width > 0 && ascent > -descent
- (instancetype)initWithWidth:(CGFloat)width
                       ascent:(CGFloat)ascent
                      descent:(CGFloat)descent
                      leading:(CGFloat)leading
                  imageBounds:(CGRect)imageBounds
                    colorInfo:(STUTextAttachmentColorInfo)colorInfo
         stringRepresentation:(nullable NSString *)stringRepresentation
  NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

/// The typographic width of the attachment.
@property (readonly) CGFloat width;

/// The typographic ascent of the attachment.
@property (readonly) CGFloat ascent;

/// The typographic descent of the attachment.
@property (readonly) CGFloat descent;

/// The typographic leading of the attachment.
@property (readonly) CGFloat leading;

/// The typographic bounds of the attachment relative to the baseline of the line of text.
///
/// Returns
/// @code
///    CGRect(origin: CGPoint(x: 0, y: -(ascent + leading/2)),
///           size: CGSize(width: width,
///                        height: ascent + descent + leading)).
/// @endcode
///
///
/// @note These bounds assume the default UIKit upper-left-origin coordinate system. This is
///       in contrast to the `NSTextAttachment.bounds` property which assumes a lower-left-origin
///       coordinate system.
@property (readonly) CGRect typographicBounds;

/// The bounds of any content that may be drawn for the attachment relative to the typographic
/// origin of the attachment on the baseline of the line of text.
///
/// These bounds may differ from the typographic bounds e.g. for a `STUImageAttachment`
/// with non-zero padding or for a custom attachment that may draw beyond the typographic bounds.
///
/// @note These bounds assume the default UIKit upper-left-origin coordinate system. This is
///       in contrast to the `NSTextAttachment.bounds` property which assumes a lower-left-origin
///       coordinate system.
@property (readonly) CGRect imageBounds;

/// Indicates whether the image is grayscale or needs an extended-color bitmap context for optimal
/// display quality.
@property (readonly) STUTextAttachmentColorInfo colorInfo;

/// This string may be used to represent the attachment in contexts where attachments are not
/// supported, e.g. for a `UIDragPreview` title or in accessibility labels (when the attachment
/// is not itself an accessibility element).
@property (readonly, nullable) NSString *stringRepresentation;

/// This method can be overridden in subclasses to draw the attachment. The default implementation
/// does nothing.
///
/// @note This method must be thread-safe.
///
/// @note If this method changes graphics context properties other than the colors, the line width
///       or the text matrix, it must restore the original values before returning.
///
/// @param context
///        The context to draw into. Equals `UIGraphicsGetCurrentContext()` at the time this method
///        is called.
///
/// @param imageBounds
///        The attachment's `imageBounds` in the coordinate system of the graphics context.
- (void)drawInContext:(CGContextRef)context imageBounds:(CGRect)imageBounds;

/// Creates a new CTRunDelegate with the appropriate parameters for this attachment
///
/// The returned run delegate retains a strong reference to the attachment.
///
/// @returns The created CTRunDelegate as an opaque object pointer.
- (id)newCTRunDelegate NS_RETURNS_RETAINED;

- (instancetype)init NS_UNAVAILABLE;

@end

STU_EXPORT
@interface STUImageTextAttachment : STUTextAttachment

- (instancetype)initWithImage:(UIImage *)image
               verticalOffset:(CGFloat)verticalOffset
         stringRepresentation:(nullable NSString *)string;

- (instancetype)initWithImage:(UIImage *)image
                    imageSize:(CGSize)imageSize
               verticalOffset:(CGFloat)verticalOffset
                      padding:(UIEdgeInsets)padding
                      leading:(CGFloat)leading
         stringRepresentation:(nullable NSString *)stringRepresentation
  NS_DESIGNATED_INITIALIZER;

/// Initializes the `STUImageTextAttachment` with the properties of the specified
/// `NSTextAttachment` such that the appearance when displayed is similar.
///
/// Currently the implementation only supports `NSTextAttachment` instances with a non-nil `image`
/// property. If the `image` property is nil, this initializer returns nil.
///
/// If `attachment.isAccessibilityElement` is true, this initializer copies non-null
/// `accessibilityTraits`, `accessibilityAttributedLabel`, `accessibilityAttributedHint`,
/// `accessibilityAttributedValue` and `accessibilityLanguage` properties from the attachment.
- (nullable instancetype)initWithNSTextAttachment:(NSTextAttachment *)attachment
                             stringRepresentation:(nullable NSString *)stringRepresentation;

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
  NS_DESIGNATED_INITIALIZER;

@property (readonly) UIImage *image;

// Unavailable base class initializer.
- (instancetype)initWithWidth:(CGFloat)width
                       ascent:(CGFloat)ascent
                      descent:(CGFloat)descent
                      leading:(CGFloat)leading
                  imageBounds:(CGRect)imageBounds
                    colorInfo:(STUTextAttachmentColorInfo)colorInfo
         stringRepresentation:(nullable NSString *)stringRepresentation
  NS_UNAVAILABLE;
@end

STU_EXPORT
@interface NSAttributedString (STUTextAttachment)

+ (instancetype)stu_newWithSTUAttachment:(STUTextAttachment *)attachment
  NS_SWIFT_NAME(init(stu_attachment:)) NS_RETURNS_RETAINED;

- (NSAttributedString *)stu_attributedStringByConvertingNSTextAttachmentsToSTUTextAttachments;

- (NSAttributedString *)stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations;

- (NSAttributedString *)stu_attributedStringByRemovingCTRunDelegates;

- (NSAttributedString *)stu_attributedStringByAddingCTRunDelegatesForSTUAttachments;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
