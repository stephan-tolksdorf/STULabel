// Copyright 2016–2018 Stephan Tolksdorf

#import "STUTextFrame-Internal.hpp"

#import "stu/Assert.h"
#import "STUObjCRuntimeWrappers.h"

#import "STUTextAttributes-Internal.hpp"
#import "STUTextFrameOptions-Internal.hpp"
#import "STUTextFrameDrawingOptions-Internal.hpp"
#import "STUShapedString-Internal.hpp"
#import "STUTextLink-Internal.hpp"
#import "STUTextRectArray-Internal.hpp"

#import "Internal/TextFrame.hpp"
#import "Internal/TextFrameLayouter.hpp"

#import "Internal/InputClamping.hpp"
#import "Internal/STUPlaceholderObjects.h"
#import "Internal/TextLineSpan.hpp"

using namespace stu;
using namespace stu_label;

STU_EXPORT
NSRange STUTextFrameRangeGetRangeInTruncatedString(STUTextFrameRange range) {
  const UInt start = range.start.indexInTruncatedString
                   + range.start.isIndexOfInsertedHyphen;
  if (range.end <= range.start) {
    return {.location = start, .length = 0};
  }
  const UInt end = range.end.indexInTruncatedString
                 + range.end.isIndexOfInsertedHyphen;
  return {.location = start, .length = end - start};
}

@implementation STUTextFrame

STU_NO_INLINE
Unretained<STUTextFrame* __nonnull> stu_label::emptySTUTextFrame() {
  STU_STATIC_CONST_ONCE(STUTextFrame*, instance,
                        STUTextFrameCreateWithShapedStringRange(nil,
                          [STUShapedString emptyShapedStringWithDefaultBaseWritingDirection:
                                             STUWritingDirectionLeftToRight],
                          NSRange{}, CGSizeZero, 0, nil, nullptr));
  return instance;
}

+ (STUTextFrame*)emptyTextFrame {
  return emptySTUTextFrame().unretained;
}

+ (nonnull instancetype)allocWithZone:(struct _NSZone* __unused)zone {
  static Class textFrameClass;
  static STUUninitializedTextFrame* textFramePlaceholder;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    textFrameClass = STUTextFrame.class;
    textFramePlaceholder = stu_createClassInstance(STUUninitializedTextFrame.class, 0);
  });

  if (self == textFrameClass) {
    // The placeholder is a singleton without retain count and doesn't need to be retained here.
    return (__bridge_transfer id)(__bridge CFTypeRef)textFramePlaceholder;
  } else {
    return stu_createClassInstance(self, 0);
  }
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (nonnull instancetype)initWithShapedString:(nonnull STUShapedString*)shapedString
                                        size:(CGSize)size
                                displayScale:(CGFloat)displayScale
                                     options:(STUTextFrameOptions* __nullable)options
{
  return [self initWithShapedString:shapedString
                        stringRange:NSRange{0, sign_cast(shapedString->shapedString->stringLength)}
                               size:size
                       displayScale:displayScale
                            options:options cancellationFlag:nullptr];
}


- (nullable instancetype)initWithShapedString:(nonnull STUShapedString*)shapedString
                                  stringRange:(NSRange)stringRange
                                         size:(CGSize)size
                                 displayScale:(CGFloat)displayScale
                                      options:(STUTextFrameOptions* __nullable)options
                             cancellationFlag:(nullable const STUCancellationFlag*)
                                                 cancellationFlag
{
  return (id)STUTextFrameCreateWithShapedStringRange(self.class, shapedString, stringRange, size,
                                                     displayScale, options, cancellationFlag);
}

STUTextFrame* __nonnull
  STUTextFrameCreateWithShapedString(__nullable Class cls,
                                     STUShapedString* __unsafe_unretained __nonnull shapedString,
                                     CGSize frameSize, CGFloat displayScale,
                                     STUTextFrameOptions* __nullable options)
                           NS_RETURNS_RETAINED
{
  return STUTextFrameCreateWithShapedStringRange(
           cls, shapedString, NSRange{0, sign_cast(shapedString->shapedString->stringLength)},
           frameSize, displayScale, options, nullptr);
}

STU_NO_INLINE
STUTextFrame* __nullable
  STUTextFrameCreateWithShapedStringRange(
    __nullable Class cls,
    STUShapedString* NS_VALID_UNTIL_END_OF_SCOPE stuShapedString,
    NSRange stringRange,
    CGSize frameSize,
    CGFloat displayScale,
    STUTextFrameOptions* NS_VALID_UNTIL_END_OF_SCOPE __nullable options,
    const STUCancellationFlag* __nullable cancellationFlag)
  NS_RETURNS_RETAINED
{
  if (STU_UNLIKELY(!stuShapedString)) return nil;
  const ShapedString& shapedString = *stuShapedString->shapedString;
  STU_CHECK_MSG(stringRange.location <= sign_cast(shapedString.stringLength)
                && stringRange.length <= sign_cast(shapedString.stringLength)
                                         - stringRange.location,
                "Invalid string range.");

  static Class textFrameClass;
  static STUTextFrameOptions* defaultOptions;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    textFrameClass = STUTextFrame.class;
    defaultOptions = [[STUTextFrameOptions alloc] init];
  });
  if (!cls) {
    cls = textFrameClass;
  }
  if (!options) {
    options = defaultOptions;
  }

  ThreadLocalArenaAllocator::InitialBuffer<4096> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  TextFrameLayouter layouter{shapedString, Range<Int32>(stringRange),
                             options->_defaultTextAlignment, cancellationFlag};
  if (layouter.isCancelled()) return nil;
  layouter.layoutAndScale(frameSize, DisplayScale::create(displayScale), options);
  if (layouter.isCancelled()) return nil;
  if (layouter.needToJustifyLines()) {
    layouter.justifyLinesWhereNecessary();
    if (layouter.isCancelled()) return nil;
  }

  const UInt instanceSize = roundUpToMultipleOf<alignof(TextFrame)>(class_getInstanceSize(cls));
  const auto oso = TextFrame::objectSizeAndThisOffset(layouter);
  Byte* const p = static_cast<Byte*>(malloc(instanceSize + oso.size));
  memset(p, 0, instanceSize);
  STUTextFrame* const instance = stu_constructClassInstance(cls, p);
  STU_DEBUG_ASSERT([instance isKindOfClass:textFrameClass]);
  const_cast<STUTextFrameData*&>(instance->data) =
    new (p + instanceSize + oso.offset) TextFrame(std::move(layouter), oso.size - oso.offset);
  return instance;
}

- (void)dealloc {
  if (const STUTextFrameData* const frame = data) {
    down_cast<const TextFrame&>(*frame).~TextFrame();
  }
}

- (NSAttributedString*)originalAttributedString {
  return data->originalAttributedString;
}

- (NSRange)rangeInOriginalString {
  return Range<UInt>{data->rangeInOriginalString};
}

- (STUTextFrameLayoutInfo)layoutInfo {
  const TextFrame& tf = textFrameRef(self);
  const CGFloat scale = tf.textScaleFactor;
  CGFloat firstBaseline;
  CGFloat lastBaseline;
  Float32 firstLineAscent;
  Float32 firstLineLeading;
  Float32 firstLineHeight;
  Float32 lastLineDescent;
  Float32 lastLineLeading;
  Float32 lastLineHeight;
  if (!tf.lines().isEmpty()) {
    const TextFrameLine& firstLine = tf.lines()[0];
    const TextFrameLine& lastLine = tf.lines()[$ - 1];
    firstBaseline = scale*narrow_cast<CGFloat>(firstLine.originY);
    lastBaseline = scale*narrow_cast<CGFloat>(lastLine.originY);
    const Float32 scale32 = narrow_cast<Float32>(scale);
    firstLineAscent  = scale32*firstLine.ascent;
    firstLineLeading = scale32*firstLine.leading;
    firstLineHeight  = scale32*firstLine.height();
    lastLineDescent  = scale32*lastLine.descent;
    lastLineLeading  = scale32*lastLine.leading;
    lastLineHeight   = scale32*lastLine.height();
  } else {
   firstBaseline = 0;
   lastBaseline = 0;
   firstLineAscent = 0;
   firstLineLeading = 0;
   firstLineHeight = 0;
   lastLineDescent = 0;
   lastLineLeading = 0;
   lastLineHeight = 0;
  }
  return {
    .lineCount = tf.lineCount,
    .flags = tf.flags,
    .consistentAlignment = tf.consistentAlignment,
    .size = tf.size,
    .displayScale = tf.displayScale,
    .layoutBounds = tf.layoutBounds,
    .textScaleFactor = scale,
    .firstBaseline = firstBaseline,
    .lastBaseline = lastBaseline,
    .firstLineAscent = firstLineAscent,
    .firstLineLeading = firstLineLeading,
    .firstLineHeight = firstLineHeight,
    .lastLineDescent = lastLineDescent,
    .lastLineLeading = lastLineLeading,
    .lastLineHeight = lastLineHeight
  };
}

- (CGFloat)displayScale {
  return data->displayScale;
}

- (nonnull NSAttributedString*)truncatedAttributedString {
  return textFrameRef(*self->data).truncatedAttributedString().unretained;
}

- (nullable NSDictionary<NSString*, id>*)attributesAtIndex:(STUTextFrameIndex)index {
  return textFrameRef(self).attributesAt(index);
}

- (nullable NSDictionary<NSString*, id>*)attributesAtIndexInTruncatedString:(size_t)index {
  const TextFrame& tf = textFrameRef(self);
  return tf.attributesAt(tf.index(IndexInTruncatedString{index}));
}

- (STUTextFrameIndex)indexForIndexInOriginalString:(size_t)index
                            indexInTruncationToken:(size_t)indexInTruncationToken
{
  return textFrameRef(*data).index(IndexInOriginalString{index},
                                   IndexInTruncationToken{indexInTruncationToken});
}

- (STUTextFrameIndex)indexForIndexInTruncatedString:(size_t)index {
  return textFrameRef(*data).index(IndexInTruncatedString{index});
}

- (STUTextFrameRange)rangeForRangeInOriginalString:(NSRange)rangeInOriginalString {
  return textFrameRef(*data).range(RangeInOriginalString{rangeInOriginalString});
}

- (STUTextFrameRange)rangeForRangeInTruncatedString:(NSRange)rangeInTruncatedString {
  return textFrameRef(*data).range(RangeInTruncatedString{rangeInTruncatedString});
}

- (STUTextFrameRange)rangeForTextRange:(STUTextRange)range {
  return textFrameRef(*data).range(range);
}

- (NSRange)rangeInOriginalStringForIndex:(STUTextFrameIndex)index {
  return NSRange(textFrameRef(*data).rangeInOriginalString(index));
}

- (NSRange)rangeInOriginalStringForRange:(STUTextFrameRange)range {
  return NSRange(textFrameRef(*data).rangeInOriginalString(range));
}

- (void)getRangeInOriginalString:(NSRange* __nullable)outRange
                 truncationToken:(NSAttributedString* __nullable * __nullable)outToken
                    indexInToken:(NSUInteger* __nullable)outIndexInToken
                        forIndex:(STUTextFrameIndex)index
{
  TruncationTokenIndex tti;
  const Range<Int32> range = textFrameRef(self).rangeInOriginalString(index, Out{tti});
  if (outRange) {
    *outRange = NSRange(range);
  }
  if (outToken) {
    *outToken = tti.truncationToken;
  }
  if (outIndexInToken) {
    *outIndexInToken = sign_cast(tti.indexInToken);
  }
}

- (STUTextFrameRange)rangeOfLastTruncationToken {
  const TextFrame& tf = textFrameRef(self);
  if (tf.flags & STUTextFrameIsTruncated) {
    for (const TextFrameParagraph& para : tf.paragraphs().reversed()) {
      if (para.truncationTokenLength == 0) continue;
      return para.rangeOfTruncationToken();
    }
  }
  const TextFrameIndex index = tf.endIndex();
  return {index, index};
}

- (STUTextFrameGraphemeClusterRange)
    rangeOfGraphemeClusterClosestToPoint:(CGPoint)point
              ignoringTrailingWhitespace:(bool)ignoringTrailingWhitespace
                             frameOrigin:(CGPoint)frameOrigin
{
  return [self rangeOfGraphemeClusterClosestToPoint:point
                         ignoringTrailingWhitespace:ignoringTrailingWhitespace
                                        frameOrigin:frameOrigin
                                       displayScale:data->displayScale];
}

- (STUTextFrameGraphemeClusterRange)
    rangeOfGraphemeClusterClosestToPoint:(CGPoint)point
              ignoringTrailingWhitespace:(bool)ignoringTrailingWhitespace
                             frameOrigin:(CGPoint)frameOrigin
                            displayScale:(CGFloat)displayScale
{
  STU_CHECK_MSG(ignoringTrailingWhitespace,
                "Currently only ignoringTrailingWhitespace == true is supported.");
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const TextFrame& tf = textFrameRef(self);
  return narrow_cast<STUTextFrameGraphemeClusterRange>(
           tf.rangeOfGraphemeClusterClosestTo(point, TextFrameOrigin{frameOrigin}, displayScale));
}

- (nonnull STUTextRectArray*)rectsForRange:(STUTextFrameRange)range
                               frameOrigin:(CGPoint)frameOrigin
{
  return [self rectsForRange:range frameOrigin:frameOrigin displayScale:data->displayScale];
}

- (nonnull STUTextRectArray*)rectsForRange:(STUTextFrameRange)range
                               frameOrigin:(CGPoint)frameOrigin
                              displayScale:(CGFloat)displayScale
{
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const TextFrame& tf = textFrameRef(self);
  const TempArray<TextLineSpan> spans = tf.lineSpans(range);
  const TextFrameScaleAndDisplayScale scaleFactors{tf, displayScale};
  STUTextRectArray* const array = STUTextRectArrayCreate(nil, spans, tf.lines(),
                                                         TextFrameOrigin{frameOrigin},
                                                         scaleFactors);
  return array;
}

- (nonnull STUTextLinkArray*)rectsForAllLinksInTruncatedStringWithFrameOrigin:(CGPoint)frameOrigin {
  const TextFrame& tf = textFrameRef(self);
  return STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
           tf, frameOrigin, TextFrameScaleAndDisplayScale{tf, tf.displayScale});
}
- (nonnull STUTextLinkArray*)rectsForAllLinksInTruncatedStringWithFrameOrigin:(CGPoint)frameOrigin
                                                                 displayScale:(CGFloat)displayScale
{
  const TextFrame& tf = textFrameRef(self);
  return STUTextLinkArrayCreateWithTextFrameOriginAndDisplayScale(
           tf, frameOrigin, TextFrameScaleAndDisplayScale{tf, displayScale});
}

- (CGRect)imageBoundsForRange:(STUTextFrameRange)range
                  frameOrigin:(CGPoint)frameOrigin
                      options:(nullable STUTextFrameDrawingOptions *)options
             cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
{
  return STUTextFrameGetImageBoundsForRange(self, range, frameOrigin, data->displayScale, options,
                                            cancellationFlag);
}
- (CGRect)imageBoundsForRange:(STUTextFrameRange)range
                  frameOrigin:(CGPoint)frameOrigin
                 displayScale:(CGFloat)displayScale
                      options:(nullable STUTextFrameDrawingOptions *)options
             cancellationFlag:(nullable const STUCancellationFlag *)cancellationFlag
{
  return STUTextFrameGetImageBoundsForRange(self, range, frameOrigin, displayScale, options,
                                            cancellationFlag);
}


- (void)drawAtPoint:(CGPoint)frameOrigin {
  const CGContextRef context = UIGraphicsGetCurrentContext();
  if (!context) return;
  [self drawRange:STUTextFrameGetRange(self) atPoint:frameOrigin
        inContext:context isVectorContext:false contextBaseCTM_d:0
          options:nil cancellationFlag:nullptr];
}

- (void)drawRange:(STUTextFrameRange)range
          atPoint:(CGPoint)frameOrigin
          options:(nullable STUTextFrameDrawingOptions*)options
 cancellationFlag:(nullable const STUCancellationFlag*)cancellationFlag
{
  const CGContextRef context = UIGraphicsGetCurrentContext();
  if (!context) return;
  [self drawRange:range atPoint:frameOrigin
        inContext:context isVectorContext:false contextBaseCTM_d:0
          options:options cancellationFlag:cancellationFlag];
}

- (void)drawRange:(STUTextFrameRange)range
          atPoint:(CGPoint)frameOrigin
        inContext:(nonnull CGContextRef)context
  isVectorContext:(bool)isVectorContext
 contextBaseCTM_d:(CGFloat)contextBaseCTM_d
          options:(nullable STUTextFrameDrawingOptions*)options
 cancellationFlag:(nullable const STUCancellationFlag*)cancellationFlag
{
  if (!context) return;
  STUTextFrameDrawRange(self, range, frameOrigin, context, isVectorContext, contextBaseCTM_d,
                        options, cancellationFlag);
}

@end

// MARK: - Frame drawing

void STUTextFrameDrawRange(const STUTextFrame* NS_VALID_UNTIL_END_OF_SCOPE self,
                           STUTextFrameRange range,
                           CGPoint origin,
                           CGContext* context,
                           bool isVectorContext,
                           CGFloat contextBaseCTM_d,
                           const STUTextFrameDrawingOptions* __unsafe_unretained stuOptions,
                           const STUCancellationFlag* __nullable cancellationFlag)
{
  const TextFrame& textFrame = textFrameRef(self);
  ThreadLocalArenaAllocator::InitialBuffer<4096> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};
  const Range<TextFrameCompactIndex> fullRange = textFrame.range();
  const auto options = stuOptions ? stuOptions->impl : Optional<const TextFrameDrawingOptions&>();
  if ((!options || !options->highlightStyle()) && range == fullRange) {
    textFrame.draw(origin, *context, isVectorContext, contextBaseCTM_d, options, nil,
                   cancellationFlag);
  } else {
    TextStyleOverride styleOverride{textFrame, range, options};
    if (styleOverride.drawnRange.isEmpty()) return;
    const STUTextFrameDrawingOptions* NS_VALID_UNTIL_END_OF_SCOPE const retainedOptions = stuOptions;
    if (styleOverride.overrideRange.isEmpty() && styleOverride.drawnRange == fullRange) {
      textFrame.draw(origin, *context, isVectorContext, contextBaseCTM_d, options, nil,
                     cancellationFlag);
    } else {
      textFrame.draw(origin, *context, isVectorContext, contextBaseCTM_d, options,
                     &styleOverride, cancellationFlag);
    }
  }
}

// MARK: - Frame image bounds

CGRect STUTextFrameGetImageBoundsForRange(
         const STUTextFrame* __unsafe_unretained self,
         STUTextFrameRange range,
         CGPoint origin, CGFloat displayScale,
         const STUTextFrameDrawingOptions* __nullable  NS_VALID_UNTIL_END_OF_SCOPE stuOptions,
         const STUCancellationFlag* __nullable cancellationFlag)
{
  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const TextFrame& tf = textFrameRef(self);
  const Range<TextFrameCompactIndex> fullRange = tf.range();
  const auto options = stuOptions ? stuOptions->impl : Optional<const TextFrameDrawingOptions&>();
  const auto drawingMode = stuOptions ? options->drawingMode() : STUTextFrameDefaultDrawingMode;

  LocalFontInfoCache fontInfoCache;
  ImageBoundsContext context = {
    .cancellationFlag = *(cancellationFlag ?: &CancellationFlag::neverCancelledFlag),
    .drawingMode =  drawingMode,
    .displayScale = DisplayScale::create(displayScale),
    .fontInfoCache = fontInfoCache
  };

  if ((!options
       || (!options->highlightStyle() && drawingMode == STUTextFrameDefaultDrawingMode))
      && range == fullRange)
  {
    return tf.calculateImageBounds(TextFrameOrigin{origin}, context);
  }
  TextStyleOverride styleOverride{tf, range, options};
  if (styleOverride.drawnRange.isEmpty()) return CGRectZero;
  if (styleOverride.overrideRange.isEmpty() && styleOverride.drawnRange == fullRange) {
    return tf.calculateImageBounds(TextFrameOrigin{origin}, context);
  } else {
    context.styleOverride = Optional<TextStyleOverride&>{styleOverride};
    return tf.calculateImageBounds(TextFrameOrigin{origin}, context);
  }
}

