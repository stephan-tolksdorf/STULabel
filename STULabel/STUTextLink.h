// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextRectArray.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

/// An immutable object containing a text link's attribute value, string location and
/// associated text rects.
///
/// This library detects links by finding the maximal contiguous @c NSAttributedString subranges
/// with the same non-null values for the @c NSLinkAttributeName (@c .link) key, with equality
/// determined by @c isEqual.
STU_EXPORT
@interface STUTextLink : STUTextRectArray

@property (readonly) id linkAttribute;

@property (readonly) NSRange rangeInTruncatedString;

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

/// An immutable array of @c STUTextLink objects.
///
/// In @c STUTextLinkArray instances created by a @c STUTextFrame or @c STUTextLabel(Layer)
/// the @c rangeInTruncatedString and @c rangeInOriginalString string ranges of the links are all
/// non-empty, the @c rangeInTruncatedString of the links are non-overlapping and the links are
/// sorted in increasing order of @c rangeInTruncatedString.start.
///
/// This is an abstract base class. Any subclass must override @c count,
/// @c objectAtIndexedSubscript, @c linkClosestToPoint..., @c linkMatchingAttributeValue....
STU_EXPORT
@interface STUTextLinkArray : NSObject <NSCopying, NSFastEnumeration>

@property (readonly) size_t count;

- (STUTextLink *)objectAtIndexedSubscript:(size_t)index;

- (nullable STUTextLink *)linkClosestToPoint:(CGPoint)point
                                 maxDistance:(CGFloat)maxDistance
  NS_SWIFT_NAME(link(closestTo:maxDistance:));

/// Returns the first link with the specified attribute value whose @c rangeInOriginalString
/// overlaps with the specified @c rangeInOrsiginalString and whose @c rangeInTruncatedString
/// overlaps with the specified @c rangeInTruncatedString. If no link is found whose
/// @c rangeInTruncatedString overlaps with the specified @c rangeInTruncatedString, the first
/// link that satisfies the other two criteria is returned, or @c nil, if there is no such link.
- (nullable STUTextLink *)linkMatchingAttributeValue:(nullable id)attributeValue
                               rangeInOriginalString:(NSRange)rangeInOriginalString
                              rangeInTruncatedString:(NSRange)rangeInTruncatedString;

/// Returns the first link matching the attribute value and string ranges of the specified link.
///
/// Equivalent to
/// @code
///   link(matchingAttributeValue: link.linkAttributeValue,
///        rangeInOriginalString: link.rangeInOriginalString,
///        rangeInTruncatedString: link.rangeInTruncatedString)
/// @endcode
- (nullable STUTextLink *)linkMatchingLink:(nullable STUTextLink *)link;

@property (class, readonly) STUTextLinkArray *emptyArray;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
