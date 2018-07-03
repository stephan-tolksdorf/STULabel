// Copyright 2017–2018 Stephan Tolksdorf

#import "STUBackgroundAttribute.h"
#import "STUTextAttachment.h"

#import <CoreText/CoreText.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

/// The value for this key must be an NSString with a locale identifier (in the format recognized
/// by `NSLocale`).
NS_SWIFT_NAME(stuHyphenationLocaleIdentifier)
extern const NSAttributedStringKey STUHyphenationLocaleIdentifierAttributeName;

typedef NS_ENUM(uint8_t, STUFirstLineOffsetType) {
  STUOffsetOfFirstBaselineFromDefault = 0,
  STUOffsetOfFirstBaselineFromTop = 1,
  STUOffsetOfFirstLineCenterFromTop = 2,
  STUOffsetOfFirstLineCapHeightCenterFromTop = 3,
  STUOffsetOfFirstLineXHeightCenterFromTop = 4
};

NS_SWIFT_NAME(stuFirstLineInParagraphOffset)
extern const NSAttributedStringKey STUFirstLineInParagraphOffsetAttributeName;

STU_EXPORT
@interface STUFirstLineInParagraphOffsetAttribute : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithFirstLineOffsetType:(STUFirstLineOffsetType)offsetType
                            firstLineOffset:(CGFloat)firstLineOffset
  NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

@property (readonly) STUFirstLineOffsetType firstLineOffsetType;

@property (readonly) CGFloat firstLineOffset;

@end

NS_SWIFT_NAME(stuTruncationScope)
extern const NSAttributedStringKey STUTruncationScopeAttributeName;

/// Equality for `STUTruncationScopeAttribute` instances is defined as pointer equality.
STU_EXPORT
@interface STUTruncationScopeAttribute : NSObject <NSSecureCoding>

- (instancetype)initWithMaxLineCount:(int32_t)maxLineCount;

- (instancetype)initWithMaxLineCount:(int32_t)maxLineCount
              lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                     truncationToken:(NSAttributedString * __nullable)truncationToken;

- (instancetype)initWithMaxLineCount:(int32_t)maxLineCount
              lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                     truncationToken:(NSAttributedString * __nullable)truncationToken
              truncatableStringRange:(NSRange)stringRange
  NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

@property (readonly) int32_t maxLineCount;

@property (readonly) CTLineTruncationType lastLineTruncationMode;

@property (readonly, nullable) NSAttributedString *truncationToken;

@property (readonly) NSRange truncatableStringRange;

@end

STU_ASSUME_NONNULL_AND_STRONG_END








