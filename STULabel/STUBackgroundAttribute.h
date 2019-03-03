// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <UIKit/UIKit.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

extern const NSAttributedStringKey STUBackgroundAttributeName
  NS_SWIFT_NAME(stuBackground);

@class STUBackgroundAttributeBuilder;

STU_EXPORT
@interface STUBackgroundAttribute : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithBuilder:(nullable STUBackgroundAttributeBuilder *)builder
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBlock:(void (^ STU_NOESCAPE)(STUBackgroundAttributeBuilder *builder))block
  // NS_SWIFT_NAME(init(_:)) // https://bugs.swift.org/browse/SR-6894
  // Use Swift's trailing closure syntax when calling this initializer.
  NS_REFINED_FOR_SWIFT;

- (instancetype)copyWithUpdates:(void (^ STU_NOESCAPE)(STUBackgroundAttributeBuilder *builder))block;

- (instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

- (void)encodeWithCoder:(NSCoder *)encoder;

@property (readonly, nullable) UIColor *color;

/// Default value: true
@property (readonly) bool fillTextLineGaps;

/// Default value: true
@property (readonly) bool extendTextLinesToCommonHorizontalBounds;

@property (readonly) CGFloat cornerRadius;

/// The insets from the edge of the background to the typographic bounds of the text to which this
/// attribute is applied to. Positive inset values expand the drawn background, negative ones shrink
/// it.
///
/// Default value: @c .zero
@property (readonly) UIEdgeInsets edgeInsets;

@property (readonly, nullable) UIColor *borderColor;

@property (readonly) CGFloat borderWidth;

/// Can be used to make @c STUBackgroundAttribute objects compare unequal when all other attributes
/// are equal.
@property (readonly) NSInteger discriminator;

@end

STU_EXPORT
@interface STUBackgroundAttributeBuilder : NSObject

- (instancetype)initWithBackgroundAttribute:(nullable STUBackgroundAttribute *)backgroundAttribute
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

@property (nonatomic, nullable) UIColor *color;

/// Default value: true
@property (nonatomic) bool fillTextLineGaps;

/// Default value: true
@property (nonatomic) bool extendTextLinesToCommonHorizontalBounds;

@property (nonatomic) CGFloat cornerRadius;

/// The insets from the edge of the background to the typographic bounds of the text to which this
/// attribute is applied to. Positive inset values expand the drawn background, negative ones shrink
/// it.
///
/// Default value: @c .zero
@property (nonatomic) UIEdgeInsets edgeInsets;

@property (nonatomic, nullable) UIColor *borderColor;

@property (nonatomic) CGFloat borderWidth;

/// Can be used to make @c STUBackgroundAttribute objects compare unequal when all other properties
/// are equal.
@property (nonatomic) NSInteger discriminator;

@end

STU_ASSUME_NONNULL_AND_STRONG_END

