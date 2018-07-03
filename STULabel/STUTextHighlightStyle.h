// Copyright 2017 Stephan Tolksdorf

#import "STUTextAttributes.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

@class STUTextHighlightStyleBuilder;

/// An immutable set of parameters for the formatting of highlighted text.
///
/// The default value of all properties is 0/null.
STU_EXPORT
@interface STUTextHighlightStyle : NSObject <NSCopying>

- (instancetype)initWithBuilder:(nullable STUTextHighlightStyleBuilder *)builder
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUTextHighlightStyleBuilder *builder))block
  // NS_SWIFT_NAME(init(_:)) // https://bugs.swift.org/browse/SR-6894
  NS_REFINED_FOR_SWIFT;

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUTextHighlightStyleBuilder *builder))block;

- (BOOL)isEqual:(nullable id)object;

- (NSUInteger)hash;

@property (readonly, nullable) UIColor *textColor;

/// The stroke width is interpreted the same way the value for the `NSStrokeWidthAttributeName`
/// text attribute is interpreted: The stroke thickness is calculated by multiplying the absolute
/// value of the specified width by 0.01 times the point size of the font. If the specified width is
/// positive, the text is only stroked, not filled. If the specified width is negative, the text is
/// both filled and stroked.
@property (readonly) CGFloat strokeWidth;
@property (readonly, nullable) UIColor *strokeColor;

@property (readonly) NSUnderlineStyle underlineStyle;
@property (readonly, nullable) UIColor *underlineColor;

@property (readonly) NSUnderlineStyle strikethroughStyle;
@property (readonly, nullable) UIColor *strikethroughColor;

@property (readonly, nullable) UIColor *shadowColor;
// CGSize is the type that UIKit and CoreAnimation use for shadow offsets, curiously.
@property (readonly) CGSize shadowOffset;
@property (readonly) CGFloat shadowBlurRadius;

@property (readonly, nullable) STUBackgroundAttribute *background;

@end

/// The default value of all properties is 0/null.
STU_EXPORT
@interface STUTextHighlightStyleBuilder : NSObject

- (instancetype)initWithStyle:(nullable STUTextHighlightStyle *)style
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

/// A null text color has no effect on the highlighted text.
@property (nonatomic, nullable) UIColor *textColor;

/// Sets the stroke width and color.
///
/// The stroke width is interpreted the same way the value for the `NSStrokeWidthAttributeName`
/// text attribute is interpreted: The stroke thickness is calculated by multiplying the absolute
/// value of the specified width by 0.01 times the point size of the font. If the specified width is
/// positive, the text is only stroked, not filled. If the specified width is negative, the text is
/// both filled and stroked.
///
/// If the width is not 0 and the color null, the stroke effect has the color of the text.
///
/// If the width is 0 and the color non-null, any stroke effect in the highlighted text is removed.
///
/// If the width is 0 and the color null, there is no effect on the highlighted text.
- (void)setStrokeWidth:(CGFloat)width
                 color:(nullable UIColor *)color;

@property (nonatomic, readonly) CGFloat strokeWidth;

@property (nonatomic, readonly, nullable) UIColor *strokeColor;

/// Sets the underline style and color.
///
/// If the style is not 0 (`.none`) and the color null, the underline(s) have the color of the text.
///
/// If the style is 0 and the color non-null or if the color is non-null and has a 0 alpha value,
/// any underline in the highlighted text is removed.
///
/// If the style is 0 and the color null, there is no effect on the highlighted text.
- (void)setUnderlineStyle:(NSUnderlineStyle)style color:(nullable UIColor *)color;

@property (nonatomic, readonly) NSUnderlineStyle underlineStyle;
@property (nonatomic, readonly, nullable) UIColor *underlineColor;

/// Sets the strikethrough style and color.
///
/// If the style is not 0 (`.none`) and the color null, the strikethrough line(s) have the color of
/// the text.
///
/// If the style is 0 and the color non-null or if the color is non-null and has a 0 alpha value,
/// any strikethrough in the highlighted text is removed.
///
/// If the style is 0 and the color null, there is no effect on the highlighted text.
- (void)setStrikethroughStyle:(NSUnderlineStyle)style color:(nullable UIColor *)color;

@property (nonatomic, readonly) NSUnderlineStyle strikethroughStyle;
@property (nonatomic, readonly, nullable) UIColor *strikethroughColor;

/// Sets the shadow offset, blur radius and color.
///
/// If the color is null, the shadow will use the default `NSShadow` color.
///
/// If the color is non-null and has a 0 alpha value, any shadow effect in the highlighted text is
/// removed.
///
/// If the color is null and the offset and blur radius are 0, there is no effect on the highlighted
/// text.
- (void)setShadowOffset:(CGSize)offset
             blurRadius:(CGFloat)blurRadius
                  color:(nullable UIColor *)color;

// CGSize is the type that UIKit and CoreAnimation use for shadow offsets, curiously.
@property (nonatomic, readonly) CGSize shadowOffset;
@property (nonatomic, readonly) CGFloat shadowBlurRadius;
@property (nonatomic, readonly, nullable) UIColor *shadowColor;

/// If the background is non-null but has a null or 0-alpha color and no border, any background in
/// the highlighted text is removed.
///
/// A null background has no effect on the highlighted text.
@property (nonatomic, nullable) STUBackgroundAttribute *background;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
