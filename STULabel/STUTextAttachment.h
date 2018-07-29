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
/// when rendering an @c NSAttributedString.
///
/// @c STUTextAttachment instances are meant to be used as values for the
/// @c STUAttachmentAttributeName (@c .stuAttachment) key in @c NSAttributedString instances
/// that are displayed in @c STULabel views or rendered with the help of @c STUTextFrame instances.
///
/// @c STUTextAttachment is a replacement for @c NSTextAttachment that is more suitable for the
/// purposes of this library.
///
/// @c STUTextAttachment is meant to be used as a base class, e.g. for @c STUImageTextAttachment,
/// but you can also use it directly in order to create blank spaces in the running text, so that
/// you can e.g. place subviews over their locations.
///
/// @note
///  Subclasses of @c STUTextAttachment are expected to be immutable and the @c drawInContext method
///  must be thread-safe.
///
/// In attributed strings an attachment should normally only be set as an attribute on a U+FFFC
/// character (@c NSAttachmentCharacter). When it is set on multiple characters, it will be drawn
/// multiple times.
///
/// Core Text does not support attachments directly and requires a @c CTRunDelegate attribute for
/// every attachment in order to compute correct typographic bounds.
///
/// In Objective-C code you can use the `+[NSAttributedString stu_newWithSTUAttachment:]` factory
/// method to conveniently create an attributed string containing a single U+FFFC character with
/// the specified attachment and an appropriate run delegate as attributes. In Swift code this
/// factory method is available as the initializer
/// `NSAttributedString(stu_attachment: myAttachment)`.
///
/// @c CTRunDelegate instances do not support @c NSCoding. Hence, if you need to archive an
/// @c NSAttributedString containing run delegates, you first need to remove the run delegates,
/// e.g. by using the `-[NSAttributedString stu_attributedStringByRemovingCTRunDelegates]`
/// method. To add back missing run delegates for @c STUTextAttachment instances you can use the
/// `-[NSAttributedString stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments]` method.
///
/// You can make a @c STUTextAttachment value individually accessible in a @c STULabel by setting
/// @c isAccessibilityElement to true and defining appropriate accessibility properties. However,
/// specifying an appropriate @c stringRepresentation when constructing the attachment is often
/// already enough to ensure good accessibility.
///
/// Equality for @c STUTextAttachment instances is defined as pointer equality.
STU_EXPORT
@interface STUTextAttachment : NSObject <NSSecureCoding>

/// @param width The typographic width of the attachment. Must be positive.
/// @param ascent The typographic ascent of the attachment. Usually this is a positive value.
/// @param descent
///        The typographic descent of the attachment. Usually this is a non-negative value (in
///        contrast to @c UIFont.descender, which returns the font's descent multiplied by -1).
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
/// @pre `width > 0 && ascent > -descent`
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
///       in contrast to the @c NSTextAttachment.bounds property which assumes a lower-left-origin
///       coordinate system.
@property (readonly) CGRect typographicBounds;

/// The bounds of any content that may be drawn for the attachment relative to the typographic
/// origin of the attachment on the baseline of the line of text.
///
/// These bounds may differ from the typographic bounds e.g. for a @c STUImageAttachment
/// with non-zero padding or for a custom attachment that may draw beyond the typographic bounds.
///
/// @note These bounds assume the default UIKit upper-left-origin coordinate system. This is
///       in contrast to the @c NSTextAttachment.bounds property which assumes a lower-left-origin
///       coordinate system.
@property (readonly) CGRect imageBounds;

/// Indicates whether the image is grayscale or needs an extended-color bitmap context for optimal
/// display quality.
@property (readonly) STUTextAttachmentColorInfo colorInfo;

/// This string may be used to represent the attachment in contexts where attachments are not
/// supported, e.g. for a @c UIDragPreview title or in accessibility labels (when the attachment
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
///        The context to draw into. Equals @c UIGraphicsGetCurrentContext() at the time this method
///        is called.
///
/// @param imageBounds
///        The attachment's @c imageBounds in the coordinate system of the graphics context.
- (void)drawInContext:(CGContextRef)context imageBounds:(CGRect)imageBounds;

/// Creates a new @c CTRunDelegate with the appropriate parameters for this attachment
///
/// The returned run delegate retains a strong reference to the attachment.
///
/// @returns The created @c CTRunDelegate as an opaque object pointer.
- (id)newCTRunDelegate NS_RETURNS_RETAINED;

- (instancetype)init NS_UNAVAILABLE;

@end

/// An immutable image text attachment.
STU_EXPORT
@interface STUImageTextAttachment : STUTextAttachment

/// Initializes the image attachment.
///
/// Calls
/// @code
/// [self initWithImage:image
///           imageSize:image.size
///      verticalOffset:verticalOffset
///             padding:UIEdgeInsetsZero
///             leading:0
///stringRepresentation:stringRepresentation]
/// @endcode
- (instancetype)initWithImage:(UIImage *)image
               verticalOffset:(CGFloat)verticalOffset
         stringRepresentation:(nullable NSString *)string;

/// Initializes the image attachment.
///
/// Calls the base class initializer as follows (after clamping the arguments to valid values):
/// @code
/// [super initWithWidth:imageSize.width
///                      + padding.left + padding.right
///               ascent:imageSize.height
///                      + padding.top - verticalOffset
///              descent:padding.bottom + verticalOffset
///              leading:leading
///          imageBounds:CGRect(x: padding.left,
///                             y: verticalOffset - imageSize.height,
///                             width: imageSize.width,
///                             height: imageSize.height}
///            colorInfo:colorInfoInferredFromImage
/// stringRepresentation:stringRepresentation];
/// @endcode
- (instancetype)initWithImage:(UIImage *)image
                    imageSize:(CGSize)imageSize
               verticalOffset:(CGFloat)verticalOffset
                      padding:(UIEdgeInsets)padding
                      leading:(CGFloat)leading
         stringRepresentation:(nullable NSString *)stringRepresentation
  NS_DESIGNATED_INITIALIZER;

/// Initializes the @c STUImageTextAttachment with the properties of the specified
/// @c NSTextAttachment such that the appearance when displayed is similar.
///
/// Currently the implementation only supports @c NSTextAttachment instances with a non-null
/// @c image property. If the @c image property is null, this initializer returns null.
///
/// If @c attachment.isAccessibilityElement is true, this initializer copies non-null
///  @c accessibilityTraits, @c accessibilityAttributedLabel, @c accessibilityAttributedHint,
/// @c accessibilityAttributedValue and @c accessibilityLanguage properties from the attachment.
- (nullable instancetype)initWithNSTextAttachment:(NSTextAttachment *)attachment
                             stringRepresentation:(nullable NSString *)stringRepresentation
  NS_SWIFT_NAME(init(_:stringRepresentation:));

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

- (NSAttributedString *)stu_attributedStringByAddingCTRunDelegatesForSTUTextAttachments;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
