
// Copyright 2016–2018 Stephan Tolksdorf

#import "STUCancellationFlag.h"
#import "STUShapedString.h"
#import "STUStartEndRange.h"
#import "STUTextFlags.h"
#import "STUTextFrameDrawingOptions.h"
#import "STUTextFrameOptions.h"
#import "STUTextFrameRange.h"
#import "STUTextHighlightStyle.h"
#import "STUTextLink.h"
#import "STUTextRectArray.h"

#import <CoreText/CoreText.h>

STU_EXTERN_C_BEGIN
STU_ASSUME_NONNULL_AND_STRONG_BEGIN

// Note: The numerical values of the enum constants and the size of the enum types may change
//       in the future, even in a minor update to this library. Backwards *binary* compatibility
//       is not a goal of this open-source project.

typedef NS_OPTIONS(uint16_t, STUTextFrameFlags) {
  // The STUTextFlags are all mapped one-to-one.
  STUTextFrameHasLink           = STUTextHasLink,
  STUTextFrameHasBackground     = STUTextHasBackground,
  STUTextFrameHasShadow         = STUTextHasShadow,
  STUTextFrameHasUnderline      = STUTextHasUnderline,
  STUTextFrameHasStrikethrough  = STUTextHasStrikethrough,
  STUTextFrameHasStroke         = STUTextHasStroke,
  STUTextFrameHasTextAttachment = STUTextHasAttachment,
  STUTextFrameHasBaselineOffset = STUTextHasBaselineOffset,

  STUTextFrameMayNotBeGrayscale = STUTextMayNotBeGrayscale,
  STUTextFrameUsesExtendedColor = STUTextUsesExtendedColor,

  STUTextFrameIsTruncated            = 1 << STUTextFlagsBitSize,
  STUTextFrameIsScaled               = 1 << (STUTextFlagsBitSize + 1),
  STUTextFrameHasMaxTypographicWidth = 1 << (STUTextFlagsBitSize + 2)
} NS_SWIFT_NAME(STUTextFrame.Flags);
enum { STUTextFrameFlagsBitSize STU_SWIFT_UNAVAILABLE = STUTextFlagsBitSize + 3 };

typedef NS_ENUM(uint8_t, STUTextFrameConsistentAlignment)  {
  STUTextFrameConsistentAlignmentNone   = 0,
  STUTextFrameConsistentAlignmentLeft   = 1,
  STUTextFrameConsistentAlignmentCenter = 2,
  STUTextFrameConsistentAlignmentRight  = 3
} NS_SWIFT_NAME(STUTextFrame.ConsistentAlignment);
enum { STUTextFrameConsistentAlignmentBitSize STU_SWIFT_UNAVAILABLE = 2 };

typedef struct STUTextFrameGraphemeClusterRange {
  STUTextFrameRange range NS_REFINED_FOR_SWIFT;
  /// The typographic bounds (not the glyph image bounds) of the grapheme cluster.
  CGRect bounds;
  /// The writing direction of the glyph run that contains the grapheme cluster.
  STUWritingDirection writingDirection;
  /// Indicates whether the bounds rectangle is a strict subrectangle of the typographic bounds of a
  /// ligature glyph.
  bool isLigatureFraction;
} NS_SWIFT_NAME(STUTextFrame.GraphemeClusterRange)
  STUTextFrameGraphemeClusterRange;

typedef struct STUTextFrameLayoutInfo {
  int32_t lineCount;
  STUTextFrameFlags flags;
  /// The mode in which the text layout was calculated.
  STUTextLayoutMode layoutMode;
  /// The consistent alignment of all paragraphs, or @c .none if the alignment is inconsistent.
  STUTextFrameConsistentAlignment consistentAlignment;
  /// The minimum X value of the layout bounds of all text lines in the coordinate system of the
  /// (scaled) text frame.
  double minX;
  /// The maximum X value of the layout bounds of all text lines in the coordinate system of the
  /// (scaled) text frame, where the maximum X value of a line's layout bounds is calculated as
  /// @c line.originX + @c line.width.
  double maxX;
  /// The Y-coordinate of the first baseline in the coordinate system of the (scaled) text frame.
  double firstBaseline;
  /// The Y-coordinate of the last baseline in the coordinate system of the (scaled) text frame.
  double lastBaseline;
  /// The value that the line layout algorithm would calculate for the distance between the first
  /// baseline and the baseline of the (hypothetical) next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float firstLineHeight;
  /// The part of the first line's layout height that lies above the baseline.
  float firstLineHeightAboveBaseline;
  /// The value that the line layout algorithm would calculate for the distance between the last
  /// baseline and the baseline of the hypothetical next line if the next line had the
  /// same typographic metrics and were in the same paragraph.
  float lastLineHeight;
  /// The part of the last line's layout height that lies below the baseline.
  float lastLineHeightBelowBaseline;
  /// The part of the last line's layout height that lies below the baseline, excluding any line
  /// spacing. This is the height below the baseline that is assumed when deciding whether the
  /// line fits the text frame's size.
  float lastLineHeightBelowBaselineWithoutSpacing;
  /// The part of the last line's layout height that lies below the baseline, with only a minimal
  /// layout-mode-dependent amount of spacing included. This is the height below the baseline
  /// assumed for a label's intrinsic content height.
  float lastLineHeightBelowBaselineWithMinimalSpacing;
  /// The size that was specified when the @c STUTextFrame instance was initialized. This size can
  /// be much larger than the layout bounds of the text, particularly if the text frame was created
  ///  by a label view, which may create text frames with e.g. a height of @c CGFLOAT_MAX.
  CGSize size;
  /// The scale factor that was applied to shrink the text to fit the text frame's size. This value
  /// is always between 0 (exclusive) and 1 (inclusive). It only can be less than 1 if the
  /// @c STUTextFrameOptions.minimumTextScaleFactor was less than 1.
  CGFloat textScaleFactor;
} NS_SWIFT_NAME(STUTextFrame.LayoutInfo)
  STUTextFrameLayoutInfo;

STU_EXPORT
@interface STUTextFrame : NSObject

- (instancetype)initWithShapedString:(STUShapedString *)shapedString
                                size:(CGSize)size
                        displayScale:(CGFloat)displayScale
                             options:(nullable STUTextFrameOptions *)options
  STU_SWIFT_UNAVAILABLE;

- (nullable instancetype)initWithShapedString:(STUShapedString *)shapedString
                                  stringRange:(NSRange)stringRange
                                         size:(CGSize)size
                                 displayScale:(CGFloat)displayScale
                                      options:(nullable STUTextFrameOptions *)options
                             cancellationFlag:(nullable const STUCancellationFlag *)
                                                 cancellationFlag
  NS_SWIFT_NAME(init(_:stringRange:size:displayScaleOrZero:options:cancellationFlag:))
  NS_DESIGNATED_INITIALIZER;

/// The attributed string of the @c STUShapedString from which the text frame was created.
@property (readonly) NSAttributedString *originalAttributedString;

/// The UTF-16 range in the original string from which the @c STUTextFrame was created.
///
/// This range equals the string range that was passed to the initializer, except if the
/// specified @c STUTextFrameOptions.lastLineTruncationMode was @c .clip and the full (sub)string
/// didn't fit the frame size, in which case this range will be shorter.
@property (readonly) NSRange rangeInOriginalString;

/// The displayScale that was specified when the @c STUTextFrame instance was initialized,
/// or 0 if the specified value was outside the valid range.
@property (readonly) CGFloat displayScale
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // var displayScale: CGFloat?

/// @note In the returned layout info only @c minX, @c maxX, @c firstBaseline and @c lastBaseline
///       depend on the specified @c frameOrigin.
///       Only @c firstBaseline and @c lastBaseline depend on the specified @c displayScale.
- (STUTextFrameLayoutInfo)layoutInfoForFrameOrigin:(CGPoint)frameOrigin
                                      displayScale:(CGFloat)displayScale
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__layoutInfo(frameOrigin:displayScale:));
  // func layoutInfo(frameOrigin: CGPoint, displayScale: CGFloat?) -> LayoutInfo

/// Equivalent to the other @c layoutInfo overload with @c self.displayScale as the @c displayScale
/// argument.
- (STUTextFrameLayoutInfo)layoutInfoForFrameOrigin:(CGPoint)frameOrigin
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func layoutInfo(frameOrigin: CGPoint) -> LayoutInfo

/// The @c self.rangeInOriginalString substring of @c self.originalAttributedString, truncated in
/// the same way it is truncated when the text is drawn, i.e. with truncation tokens replacing text
/// that doesn't fit the frame size.
///
/// This value is lazily computed and cached.
///
/// @note This string does NOT contain any hyphens that were automatically during line breaking.
///
/// @note This string contains the text with the original font sizes, even when the text is scaled
///       down when it is drawn, i.e. when @c layoutInfo.textScaleFactor < 1.
///
@property (readonly) NSAttributedString *truncatedAttributedString;

- (nullable NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(STUTextFrameIndex)index
  NS_SWIFT_NAME(attributes(at:));

- (nullable NSDictionary<NSAttributedStringKey, id> *)attributesAtIndexInTruncatedString:(size_t)index
  NS_SWIFT_NAME(attributes(atUTF16IndexInTruncatedString:));

/// Returns the text frame index for the position identified by the combination of
/// @c indexInOriginalString and @c indexInTruncationToken. When @c indexInOriginalString falls into
/// a range of the original string that was replaced by a truncation token,
/// @c indexInTruncationToken identifies the position in the token that the returned index should
/// represent. Otherwise @c indexInTruncationToken is ignored.
/// @param indexInOriginalString
///  A UTF-16 code unit index into @c self.originalAttributedString.
///  This value will be clamped to @c self.rangeInOriginalString.
/// @param indexInTruncationToken
///  A UTF-16 code unit index into the truncation token replacing the range of the original
///  string into which @c indexInOriginalString falls.
///  This value is ignored if @c indexInOriginalString does not fall into a string range replaced by
///  a truncation token and otherwise will be clamped to the integer range
///  [0, length-of-the-truncation-token].
- (STUTextFrameIndex)indexForIndexInOriginalString:(size_t)indexInOriginalString
                            indexInTruncationToken:(size_t)indexInTruncationToken
  NS_SWIFT_NAME(index(forUTF16IndexInOriginalString:indexInTruncationToken:));

/// @param indexInTruncatedString
///  A UTF-16 code unit index into @c self.truncatedAttributedString.
///  This value will be clamped to the integer range [0, @c self.truncatedAttributedString.length].
- (STUTextFrameIndex)indexForIndexInTruncatedString:(size_t)indexInTruncatedString
  NS_SWIFT_NAME(index(forUTF16IndexInTruncatedString:));

- (STUTextFrameRange)fullRange
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
// var indices: Range<Index>

/// Returns the text frame range corresponding to the specified range in the original string,
/// including the full truncation token(s) replacing any part of that range.
///
/// @param rangeInOriginalString
///  The UTF-16 code unit range in @c self.originalAttributedString.
///  This range will be clamped to @c self.rangeInOriginalString.
- (STUTextFrameRange)rangeForRangeInOriginalString:(NSRange)rangeInOriginalString
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__range(forRangeInOriginalString:));
// func range(forRangeInOriginalString range: NSRange) -> Range<Index>

/// @param rangeInTruncatedString
///  The UTF-16 code unit range in @c self.truncatedAttributedString.
///  This range will be clamped to the integer range [0, @c self.rangeInTruncatedString.length].
- (STUTextFrameRange)rangeForRangeInTruncatedString:(NSRange)rangeInTruncatedString
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__range(forRangeInTruncatedString:));
  // func range(forRangeInTruncatedString range: NSRange) -> Range<Index>

- (STUTextFrameRange)rangeForTextRange:(STUTextRange)textRange
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func range(for textRange: STUTextRange) -> Range<Index>

/// Returns the UTF-16 code unit range in @c self.originalAttributedString corresponding to the
/// specified text frame index.
/// The returned range only has a non-null length when the index falls into the range of a
/// truncation token, in which case the returned range is the full range in the original string
/// that was replaced by the truncation token.
- (NSRange)rangeInOriginalStringForIndex:(STUTextFrameIndex)index;

/// Returns the UTF-16 code unit range in @c self.originalAttributedString corresponding to the
/// specified text frame range, including any subrange in the original string that was replaced by a
/// truncation token whose text frame range overlaps with the specified range.
- (NSRange)rangeInOriginalStringForRange:(STUTextFrameRange)range
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__rangeInOriginalString(for:));
  // func rangeInOriginalString(for range: Range<Index>) -> NSRange

/// @param outRange
///  If @c outRange is non-null, @c *outRange is assigned the UTF-16 code unit range in
///  @c self.originalAttributedString corresponding to the specified text frame index.
///  This range only has a non-null length when the index falls into the range of a
///  truncation token, in which case the returned range is the full range in the original string
///  that was replaced by the truncation token.
/// @param outToken
///  If @c outToken is non-null, @c *outToken is assigned the truncation token at the specified text
///  frame index or @c nil if there is no truncation token at the index
/// @param outIndexInToken
///  If @c outIndexInToken is non-null, @c *outIndexInToken is assigned the UTF-16 code point index
///  in the truncation token corresponding to the specified text frame index or
///  @c STUTextFrameIndexZero if there is no truncation token at the text frame index.
/// @param index
///  The text frame index.
- (void)getRangeInOriginalString:(NSRange * __nullable)outRange
                 truncationToken:(NSAttributedString * __nullable * __nullable)outToken
                    indexInToken:(NSUInteger * __nullable)outIndexInToken
                        forIndex:(STUTextFrameIndex)index
  NS_REFINED_FOR_SWIFT;
  // func rangeInOriginalStringAndTruncationTokenIndex(for index: Index)
  //   -> (NSRange, (truncationToken: NSAttributedString, indexInToken: Int)?)

/// The text frame range of the last truncation token,
/// or the empty range `[self rangeForIndexInTruncatedString:self.truncatedAttributedString.length]`
/// if there is no truncation token in the text frame's text.
@property (readonly) STUTextFrameRange rangeOfLastTruncationToken
  // var rangeOfLastTruncationToken: Range<Index> { get }
  NS_REFINED_FOR_SWIFT;

/// @pre `ignoringTrailingWhitespace == true` (A limitation of the current implementation.)
- (STUTextFrameGraphemeClusterRange)
    rangeOfGraphemeClusterClosestToPoint:(CGPoint)point
              ignoringTrailingWhitespace:(bool)ignoringTrailingWhitespace
                             frameOrigin:(CGPoint)frameOrigin
                            displayScale:(CGFloat)displayScale
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__rangeOfGraphemeCluster(closestTo:ignoringTrailingWhitespace:frameOrigin:displayScale:));
  // func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool,
  //                             frameOrigin: CGPoint, displayScale: CGFloat?)
  //   -> STUTextFrameGraphemeClusterRange

/// Equivalent to the other @c rangeOfGraphemeClusterClosestToPoint overload
/// with @c self.displayScale as the @c displayScale argument.
- (STUTextFrameGraphemeClusterRange)
    rangeOfGraphemeClusterClosestToPoint:(CGPoint)point
              ignoringTrailingWhitespace:(bool)ignoringTrailingWhitespace
                             frameOrigin:(CGPoint)frameOrigin
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func rangeOfGraphemeCluster(closestTo point: CGPoint, ignoringTrailingWhitespace: Bool,
  //                             frameOrigin: CGPoint)
  //   -> STUTextFrameGraphemeClusterRange


- (STUTextRectArray *)rectsForRange:(STUTextFrameRange)range
                        frameOrigin:(CGPoint)frameOrigin
                       displayScale:(CGFloat)displayScale
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__rects(_:frameOrigin:displayScale:));
  // func rects(for range: Range<Index>, frameOrigin: CGPoint, displayScale: CGFloat?)
  //   -> STUTextRectArray

/// Equivalent to the other @c rectsForRange overload
/// with @c self.displayScale as the @c displayScale argument.
- (STUTextRectArray *)rectsForRange:(STUTextFrameRange)range
                        frameOrigin:(CGPoint)frameOrigin
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func rects(for range: Range<Index>, frameOrigin: CGPoint) -> STUTextRectArray


- (STUTextLinkArray *)rectsForAllLinksInTruncatedStringWithFrameOrigin:(CGPoint)frameOrigin
                                                          displayScale:(CGFloat)displayScale
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__rectsForAllLinksInTruncatedString(frameOrigin:displayScale:));
  // func rectsForAllLinksInTruncatedString(frameOrigin: CGPoint, displayScale: CGFloat?)
  //   -> STUTextLinkArray

/// Equivalent to the other @c rectsForAllLinksInTruncatedStringWithFrameOrigin overload
/// with @c self.displayScale as the @c displayScale argument.
- (STUTextLinkArray *)rectsForAllLinksInTruncatedStringWithFrameOrigin:(CGPoint)frameOrigin
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func rectsForAllLinksInTruncatedString(frameOrigin: CGPoint) -> STUTextLinkArray

- (CGRect)imageBoundsForRange:(STUTextFrameRange)range
                  frameOrigin:(CGPoint)frameOrigin
                 displayScale:(CGFloat)displayScale
                      options:(nullable STUTextFrameDrawingOptions *)options
             cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
  NS_REFINED_FOR_SWIFT NS_SWIFT_NAME(__imageBounds(_:frameOrigin:displayScale:_:_:));
  // func imageBounds(for range: Range<Index>? = nil,
  //                  frameOrigin: CGPoint,
  //                  displayScale: CGFloat?,
  //                  options: STUTextFrameDrawingOptions? = nil,
  //                  cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil) -> CGRect

/// Equivalent to the other @c imageBoundsForRange overload
/// with @c self.displayScale as the @c displayScale argument.
- (CGRect)imageBoundsForRange:(STUTextFrameRange)range
                  frameOrigin:(CGPoint)frameOrigin
                      options:(nullable STUTextFrameDrawingOptions *)options
             cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func imageBounds(for range: Range<Index>? = nil,
  //                  frameOrigin: CGPoint,
  //                  options: STUTextFrameDrawingOptions? = nil,
  //                  cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil) -> CGRect

/// Draws the text frame into the current UIKit graphics context.
///
/// Equivalent to
/// @code
///     [self drawRange:self.fullRange
///             atPoint:frameOrigin
///           inContext:UIGraphicsGetCurrentContext()
///    contextBaseCTM_d:0
/// pixelAlignBaselines:true
///             options:nil
///    cancellationFlag:nullptr];
/// @endcode
- (void)drawAtPoint:(CGPoint)frameOrigin
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;

/// Draws the specified subrange of the text frame.
///
/// Equivalent to
/// @code
///     [self drawRange:range
///             atPoint:frameOrigin
///           inContext:UIGraphicsGetCurrentContext()
///    contextBaseCTM_d:0
/// pixelAlignBaselines:true
///             options:options
///    cancellationFlag:cancellationFlag]
/// @endcode
- (void)drawRange:(STUTextFrameRange)range
          atPoint:(CGPoint)frameOrigin
          options:(nullable STUTextFrameDrawingOptions *)options
 cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
  NS_REFINED_FOR_SWIFT STU_SWIFT_UNAVAILABLE;
  // func draw(range: Range<Index>? = nil,
  //           at frameOrigin: CGPoint = .zero,
  //           options: STUTextFrameDrawingOptions = nil,
  //           cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)

/// Draws the specified subrange of the text frame into the specified Core Graphics context.
///
/// @param range The range of the text frame to draw.
/// @param frameOrigin The origin of the text frame in the coordinate system of the context.
/// @param context
///  The Core Graphics context to draw into. This method may leave the context's color, line width,
///  text drawing mode and text matrix properties in a changed state when it returns.
///  If the context is null, this method does nothing.
/// @param contextBaseCTM_d
///  The @c d element in the base CTM matrix of @c context. (The base CTM is independent of the
///  normal CTM and determines how shadows and patterns are drawn. For inexplicable reasons Apple
///  provides no public functions for getting or setting this matrix. UIKit, WebKit, etc. use
///  private API functions for this purpose, of course.)
///  If the context was created directly with a Core Graphics function, this value should be 1.
///  If the context was created by UIKit or by Quartz Core, this value should be minus the initial
///  scale of the context. If you specify 0 for this parameter and true for @c pixelAlignBaselines,
///  the base CTM @c d will be calculated from the current CTM based on the assumption that
///  no scale changing transform was applied to the context after creating it. If you specify 0 for
///  this parameter and false for @c pixelAlignBaselines, the base CTM @c d is assumed to be 1.
/// @param pixelAlignBaselines
///  Indicates whether the vertical position of text baselines and certain text decorations should
///  be rounded to pixel boundaries. Normally you should specify true for this parameter, unless the
///  context is a PDF context or the context is a bitmap context that has been configured to allow
///  vertical subpixel positioning of glyphs (by explicitly setting both
///  @c setShouldSubpixelPositionFonts(true) and @c setShouldSubpixelQuantizeFonts(false).
///  If you specify false for @c pixelAlignBaselines but draw into a context that doesn't allow
///  vertical subpixel positioning of text (the default), text decorations may be mispositioned by
///  up to one pixel, because Core Graphics will round the vertical text position up to the next
///  pixel boundary (at least when the text isn't rotated) even if this method doesn't.
///  (Core Graphics provides no public API functions for obtaining the type of the context or the
///  current values of the subpixel configuration options.)
/// @param options
///  An optional options object that allows you e.g. to only draw the foreground or the background
///  of the text frame range, to highlight a subrange or to override the color of links.
/// @param cancellationFlag
///  The optional cancellation token for cancelling the drawing from another thread.
  - (void)drawRange:(STUTextFrameRange)range
            atPoint:(CGPoint)frameOrigin
          inContext:(nullable CGContextRef)context
   contextBaseCTM_d:(CGFloat)contextBaseCTM_d
pixelAlignBaselines:(bool)pixelAlignBaselines
            options:(nullable STUTextFrameDrawingOptions *)options
   cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
  NS_REFINED_FOR_SWIFT
  NS_SWIFT_NAME(__draw(range:at:in:contextBaseCTM_d:pixelAlignBaselines:options:cancellationFlag:));
  // func draw(range: Range<Index>? = nil,
  //           at frameOrigin: CGPoint = .zero,
  //           in context: CGContext, contextBaseCTM_d: CGFloat, pixelAlignBaselines: Bool,
  //           options: STUTextFrameDrawingOptions = nil,
  //           cancellationFlag: UnsafePointer<STUCancellationFlag>? = nil)

@property (class, readonly) STUTextFrame *emptyTextFrame;

- (instancetype)init NS_UNAVAILABLE;

@end

STU_ASSUME_NONNULL_AND_STRONG_END
STU_EXTERN_C_END
