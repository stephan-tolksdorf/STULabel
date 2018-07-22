// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <UIKit/UIKit.h>

#import <CoreText/CoreText.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

// TODO: Rename to STUTruncationScope

NS_SWIFT_NAME(stuTruncationScope)
extern const NSAttributedStringKey STUTruncationScopeAttributeName;

/// Equality for `STUTruncationScopeAttribute` instances is defined as pointer equality.
STU_EXPORT
@interface STUTruncationScopeAttribute : NSObject <NSSecureCoding>

- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount;

- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount
                  lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                         truncationToken:(NSAttributedString * __nullable)truncationToken;

- (instancetype)initWithMaximumLineCount:(int32_t)maximumLineCount
                  lastLineTruncationMode:(CTLineTruncationType)lastLineTruncationMode
                         truncationToken:(NSAttributedString * __nullable)truncationToken
                  truncatableStringRange:(NSRange)stringRange
  NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder *)decoder
  NS_DESIGNATED_INITIALIZER;

@property (readonly) int32_t maximumLineCount;

@property (readonly) CTLineTruncationType lastLineTruncationMode;

@property (readonly, nullable) NSAttributedString *truncationToken;

@property (readonly) NSRange truncatableStringRange;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
