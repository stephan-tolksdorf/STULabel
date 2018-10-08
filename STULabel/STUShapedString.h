// Copyright 2017–2018 Stephan Tolksdorf

#import "STUCancellationFlag.h"

#import <UIKit/UIKit.h>

STU_EXTERN_C_BEGIN
STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef NS_ENUM(uint8_t, STUWritingDirection) {
  STUWritingDirectionLeftToRight = NSWritingDirectionLeftToRight,
  STUWritingDirectionRightToLeft = NSWritingDirectionRightToLeft
};

STU_INLINE NS_SWIFT_NAME(STUWritingDirection.init(_:))
STUWritingDirection stuWritingDirection(UIUserInterfaceLayoutDirection direction) {
  _Static_assert(STUWritingDirectionLeftToRight == (STUWritingDirection)false, "");
  _Static_assert(STUWritingDirectionRightToLeft == (STUWritingDirection)true, "");
  return (STUWritingDirection)(direction == UIUserInterfaceLayoutDirectionRightToLeft);
}

/// Returns `NSParagraphStyle.defaultWritingDirection(forLanguage: nil)`,
/// which equals `UIApplication.sharedApplication.userInterfaceLayoutDirection`.
STUWritingDirection stu_defaultBaseWritingDirection(void);

STU_EXPORT
@interface STUShapedString : NSObject

/// Calls
///     self.init(attributedString, defaultBaseWritingDirection: stu_defaultBaseWritingDirection(),
///               cancellationFlag: nil)
///
/// - Precondition: `attributedString.length < 2^30`
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
  NS_SWIFT_NAME(init(_:));
/// Calls
///     self.init(attributedString, defaultBaseWritingDirection: baseWritingDirection,
///               cancellationFlag: nil)
///
/// - Precondition: `attributedString.length < 2^30`
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
             defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
  NS_SWIFT_NAME(init(_:defaultBaseWritingDirection:));

/// - Precondition: `attributedString.length < 2^30`
- (nullable instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                      defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
                                 cancellationFlag:(nullable const STUCancellationFlag*)
                                                     cancellationFlag
  NS_DESIGNATED_INITIALIZER
  NS_SWIFT_NAME(init(_:defaultBaseWritingDirection:cancellationFlag:));

@property (readonly) NSAttributedString *attributedString;

/// The length of the string in UTF-16 code units, i.e. @c self.attributedString.length.
@property (readonly) NSUInteger length
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // var length: Int

/// The writing direction that is assumed for text paragraphs that satisfy both of the following
/// conditions:
/// 1) The paragraph has no associated @c NSParagraphStyle or the @c baseWritingDirection of the
///    style is @c NSWritingDirectionNatural.
/// 2) The writing direction of the paragraph cannot be detected using the Unicode Bidirectional
///    algorithm rules P2 and P3, or more specifically, @c stu_detectBaseWritingDirection with
///    `skipIsolatedText == (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max)`
///    returns @c NSWritingDirectionNatural for the string range of the paragraph.
@property (readonly) STUWritingDirection defaultBaseWritingDirection;

/// Indicates whether the @c defaultBaseWritingDirection was assumed for any paragraph in the
/// string.
@property (readonly) bool defaultBaseWritingDirectionWasUsed;

- (nonnull instancetype)init NS_UNAVAILABLE;

+ (nonnull STUShapedString *)emptyShapedStringWithDefaultBaseWritingDirection:
                               (STUWritingDirection)baseWritingDirection;

@end

/// Determines the writing direction of the specified string range using the Unicode Bidi algorithm
/// rules P2 and P3 (ignoring any paragraph separator). See http://unicode.org/reports/tr9/#P2
///
/// Finds the first Unicode code point with Bidi type L, AL, or R in the specified string range.
/// If @c skipIsolatedText, any code point between an Unicode directional isolate initiator and its
/// matching PDI or, if it has no matching PDI, the end of the string range, is ignored.
///
/// Returns @c NSWritingDirectionLeftToRight if the found code point is of Bidi type L,
/// returns NSWritingDirectionRightToRight if the found code point is of Bidi type R or AL, and
/// otherwise returns @c NSWritingDirectionNatural.
///
/// \pre @c range must be a valid UTF-16 index range for @c string.
NSWritingDirection stu_detectBaseWritingDirection(NSString *string, NSRange range,
                                                  bool skipIsolatedText);

STU_ASSUME_NONNULL_AND_STRONG_END
STU_EXTERN_C_END
