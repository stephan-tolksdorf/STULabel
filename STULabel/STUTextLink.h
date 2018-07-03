// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextRectArray.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

/// \brief An immutable object containing a text link's attribute value, string location and
/// associated text rects.
///
/// This library detects links by finding the maximal contiguous NSAttributedString subranges
/// with the same non-null values for the `NSLinkAttributeName` (`.link`) key, with equality
/// determined by `isEqual:`.
STU_EXPORT
@interface STUTextLink : STUTextRectArray

@property (readonly) id linkAttribute;

@property (readonly) NSRange rangeInTruncatedString;

/// The following is true for `STUTextLink` instances created by a `STUTextFrame` or
/// `STUTextLabel(Layer)`: TODO TODO
///
/// If `rangeInTruncatedString` overlaps with the range of a truncation token,
/// `rangeInOriginalString` includes the full subrange of the original string that was replaced
/// with the token.
///
/// If the text of the link was truncated, but `rangeInTruncatedString` does not overlap with a
/// token's range (because the token isn't linked or has a different link value), then
/// `rangeInOriginalString` may be larger than
///
///    textFrame.rangeInOriginalString(for:
///       textFrame.range(forRangeInTruncatedString: link.rangeInTruncatedString))
///
@property (readonly) NSRange rangeInOriginalString;

- (instancetype)initWithLinkAttributeValue:(id)linkAttributeValue
                     rangeInOriginalString:(NSRange)rangeInOriginalString
                    rangeInTruncatedString:(NSRange)rangeInTruncatedString
                             textRectArray:(nullable STUTextRectArray *)rectArray
  NS_SWIFT_NAME(init(linkAttributeValue:rangeInOriginalString:rangeInTruncatedString:_:))
  NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTextRectArray:(nullable STUTextRectArray *)textRectArray NS_UNAVAILABLE;
@end

/// \brief An immutable array of `STUTextLink` objects.
///
/// The `rangeInTruncatedString` and `rangeInOriginalString` string ranges of the links are all
/// non-empty. The `rangeInTruncatedString` of the links are non-overlapping and the links are
/// sorted in increasing order of `rangeInTruncatedString.start`.
///
/// This is an abstract base class. Any subclass must override `count`, `objectAtIndexedSubscript`,
/// `linkClosestToPoint...`, `linkMatchingAttributeValue...`.
STU_EXPORT
@interface STUTextLinkArray : NSObject <NSCopying, NSFastEnumeration>

@property (readonly) size_t count;

- (STUTextLink *)objectAtIndexedSubscript:(size_t)index;

- (nullable STUTextLink *)linkClosestToPoint:(CGPoint)point
                                 maxDistance:(CGFloat)maxDistance
  NS_SWIFT_NAME(link(closestTo:maxDistance:));

/// Returns the first link with the specified attribute value whose `rangeInOriginalString`
/// overlaps with the specified `rangeInOriginalString` and whose `rangeInTruncatedString`
/// overlaps with the specified `rangeInTruncatedString`. If no link is found whose
/// `rangeInTruncatedString` overlaps with the specified `rangeInTruncatedString`, the first
/// link that satisfies the other two criteria is returned, or nil, if there is no such link.
- (nullable STUTextLink *)linkMatchingAttributeValue:(nullable id)attributeValue
                               rangeInOriginalString:(NSRange)rangeInOriginalString
                              rangeInTruncatedString:(NSRange)rangeInTruncatedString;

/// Equivalent to
///
///   [self linkMatchingAttributeValue:link.linkAttributeValue
///              rangeInOriginalString:link.rangeInOriginalString
///             rangeInTruncatedString:link.rangeInTruncatedString]
- (nullable STUTextLink *)linkMatchingLink:(nullable STUTextLink *)link;

@property (class, readonly) STUTextLinkArray *emptyArray;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
