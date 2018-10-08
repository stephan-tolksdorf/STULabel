// Copyright 2017–2018 Stephan Tolksdorf

#import "STUDefines.h"

#import <UIKit/UIKit.h>

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef struct STUIndexAndDistance {
  size_t index;
  CGFloat distance;
} STUIndexAndDistance
  NS_REFINED_FOR_SWIFT;

/// An immutable array of text span rectangles and associated text layout information.
STU_EXPORT
@interface STUTextRectArray : NSObject <NSCopying>

/// All methods of a @c STUTextRectArray instance initialized with this initializer will forward
/// all calls to the specified argument array, or @c STUTextRectArray.empty if the argument is null.
/// Hence, if you want to create a subclass that doesn't just act as proxy class, you'll likely have
/// to override most of this class's methods, including @c isEqual and @c hash.
- (instancetype)initWithTextRectArray:(nullable STUTextRectArray *)textRectArray
  NS_SWIFT_NAME(init(_:))
  NS_DESIGNATED_INITIALIZER;

@property (readonly) CGRect bounds;

@property (readonly) size_t rectCount;
@property (readonly) NSRange textLineRange;

- (CGRect)rectAtIndex:(size_t)index;

/// Returns an @c NSArray of boxed copies of all rects, offset by the specified vector.
- (NSMutableArray<NSValue *> *)copyRectsWithOffset:(CGVector)offset;

- (size_t)textLineIndexForRectAtIndex:(size_t)index;

- (CGFloat)baselineForRectAtIndex:(size_t)index;

- (CGFloat)baselineForTextLineAtIndex:(size_t)textLineIndex;

/// Returns the index and distance of the rect closest to the specified point.
/// In case of a tie the index of the first rect with the minimum distance is returned.
///
/// If the array contains no rect or if the distance between the closest rect and the point is
/// greater than @c maxDistance, this method returns @c NSNotFound as the index and @c CGFLOAT_MAX
/// as the distance.
- (STUIndexAndDistance)findRectClosestToPoint:(CGPoint)point
                                  maxDistance:(CGFloat)maxDistance
  NS_REFINED_FOR_SWIFT;

@property (readonly)
  bool pathWithTextLinesExtendedToCommonHorizontalBoundsAndFilledTextLineGapsIsRectangular;

/// Creates a @c CGPath for the outline(s) of the text rects.
///
/// The time and space complexity of the implementation is amortized linear in the number of rects.
///
/// @note If you're calling this function in Objective-C code, you're responsible for releasing the
///       returned object. (In Swift code this is normally being done automatically.)
///
/// @param edgeInsets
///  These insets are applied to the rects before the path is constructed. Positive inset
///  values shrink the rects, negative ones expand the rects. Rects on the same text line that
///  overlap after the horizontal edge insets have been applied are merged. Similarly, rects
///  that overlap vertically after (not too large) insets have been applied are merged in certain
///  common situations.
///
/// @param cornerRadius
///  The maximum rounding radius for the corners in the constructed path. If you specify a positive
///  value for this parameter, you probably want to specify corresponding negative values for the
///  edge insets. (Note that vertically adjacent rects are fused only if you specify true for
///  @c fillTextLineGaps. Rounded rects without some minimum distance between them may look odd.)
///
/// @param extendTextLinesToCommonHorizontalBounds
///  Indicates whether rects at the left and right ends of text lines should be extended outwards
///  to the minimum common bounds. By specifying true for this parameter you can align the vertical
///  bounds of text rects that span multiple lines.
///
/// @param fillTextLineGaps
///  Indicates whether the paths of rects in adjacent text lines should be fused if the rects
///  overlap horizontally.
///
/// @param transform
///  A pointer to an affine transformation matrix, or null if no transformation is needed.
///  If non-null, this transformation is applied to the path before it is returned.
-   (CGPathRef)createPathWithEdgeInsets:(UIEdgeInsets)edgeInsets
                           cornerRadius:(CGFloat)cornerRadius
extendTextLinesToCommonHorizontalBounds:(bool)extendTextLinesToCommonHorizontalBounds
                       fillTextLineGaps:(bool)fillTextLineGaps
                              transform:(nullable const CGAffineTransform *)transform
    CF_RETURNS_RETAINED;

@property (class, readonly, nonnull) STUTextRectArray *emptyArray;

@end

STU_ASSUME_NONNULL_AND_STRONG_END

