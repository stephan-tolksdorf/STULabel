// Copyright 2018 Stephan Tolksdorf

#import "TextFramePerformanceVC-Drawing.h"

@import STULabel;

// We prevent tail calls here to simplify profiling with Instruments.
#define PREVENT_TAIL_CALL asm volatile("":::"memory");

STU_NO_INLINE
void drawUsingSTUTextFrame(NSAttributedString * __unsafe_unretained attributedString,
                           CGSize size, CGPoint offset)
{
  {
    STUShapedString * const shapedString =
      [[STUShapedString alloc] initWithAttributedString:attributedString
                            defaultBaseWritingDirection:STUWritingDirectionLeftToRight];

    STUTextFrame * const textFrame = [[STUTextFrame alloc] initWithShapedString:shapedString
                                                                           size:size
                                                                   displayScale:0
                                                                        options:nil];
    [textFrame drawAtPoint:offset];
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingNSStringDrawing(NSAttributedString * __unsafe_unretained attributedString,
                              CGSize size, CGPoint offset)
{
  {
    const NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin
                                         | NSStringDrawingUsesFontLeading
                                         | NSStringDrawingTruncatesLastVisibleLine;
    [attributedString drawWithRect:(CGRect){offset, size} options:options context:nil];
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void measureAndDrawUsingNSStringDrawing(NSAttributedString* __unsafe_unretained attributedString,
                                        CGSize size, CGPoint offset)
{
  {
    const NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin
                                         | NSStringDrawingUsesFontLeading
                                         | NSStringDrawingTruncatesLastVisibleLine;
    const CGRect bounds = [attributedString boundingRectWithSize:size options:options context:nil];
    if (bounds.size.width > size.width || bounds.size.height > size.height) {
      __builtin_trap();
    }
    [attributedString drawWithRect:(CGRect){offset, size} options:options context:nil];
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingTextKit(NSAttributedString * __unsafe_unretained attributedString,
                      CGSize size, CGPoint offset)
{
  {
    NSLayoutManager * const layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer * const container = [[NSTextContainer alloc] initWithSize:size];
    container.lineFragmentPadding = 0;
    container.lineBreakMode = NSLineBreakByTruncatingTail;
    [layoutManager addTextContainer:container];
    NSTextStorage * const storage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
    [storage addLayoutManager:layoutManager];
    const NSRange range = [layoutManager glyphRangeForTextContainer:container];
    [layoutManager drawBackgroundForGlyphRange:range atPoint:offset];
    [layoutManager drawGlyphsForGlyphRange:range atPoint:offset];
  }
  PREVENT_TAIL_CALL
}



static bool isRightToLeftLine(CTLineRef line) {
  const CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
  const CFIndex runCount = CFArrayGetCount(glyphRuns);
  if (runCount == 0) return false;
  const CTRunRef firstRun = CFArrayGetValueAtIndex(glyphRuns, 0);
  if (runCount == 1) {
    return (CTRunGetStatus(firstRun) & kCTRunStatusRightToLeft);
  }
  const CTRunRef lastRun = CFArrayGetValueAtIndex(glyphRuns, runCount - 1);
  return CTRunGetStringRange(lastRun).location < CTRunGetStringRange(firstRun).location;
}

STU_NO_INLINE
void drawUsingCTLine(NSAttributedString * __unsafe_unretained attributedString,
                     CGSize __unused size, CGPoint offset)
{
  {
    const CTLineRef line = CTLineCreateWithAttributedString(
                             (__bridge CFAttributedStringRef)attributedString);
    CGFloat ascent;
    const double width = CTLineGetTypographicBounds(line, &ascent, nil, nil);
    const bool isRTL = isRightToLeftLine(line);

    const CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1, -1);
    const CGPoint p = {.x = offset.x + (isRTL ? size.width - (CGFloat)width : 0),
                       .y = offset.y + ascent};
    CGContextSetTextMatrix(context, (CGAffineTransform){.a = 1, .d = 1, .tx = p.x, .ty = -p.y});
    CTLineDraw(line, context);
    CGContextScaleCTM(context, 1, -1);

    CFRelease(line);
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingCTTypesetter(NSAttributedString * __unsafe_unretained attributedString,
                           CGSize __unused size, CGPoint offset)
{
  {
    const CFIndex stringLength = (CFIndex)attributedString.length;
    if (stringLength == 0) return;

    const CFIndex maxLineCount = 32;
    CTLineRef lines[maxLineCount];
    CGPoint origins[maxLineCount];

    const CTTypesetterRef ts = CTTypesetterCreateWithAttributedString(
                                 (__bridge CFAttributedStringRef)attributedString);
    CFIndex stringIndex = 0;
    CGFloat y = 0;
    CFIndex truncationStart = -1;
    CFIndex lineIndex;
    bool isRTL = false;
    for (lineIndex = 0; stringIndex < stringLength && lineIndex < maxLineCount; ++lineIndex) {
      CTLineRef line;
      CFIndex nextStringIndex;
      if (truncationStart < 0) {
        const CFIndex n = CTTypesetterSuggestLineBreak(ts, stringIndex, size.width);
        assert(n > 0);
        line = CTTypesetterCreateLine(ts, (CFRange){stringIndex, n});
        nextStringIndex = stringIndex + n;
        if (lineIndex == 0) {
          isRTL = isRightToLeftLine(line);
        }
      } else {
        const CTLineRef untruncated = CTTypesetterCreateLine(
                                        ts, (CFRange){stringIndex, stringLength - stringIndex});
        NSDictionary<NSAttributedStringKey, id> * const attributes =
          [attributedString attributesAtIndex:(NSUInteger)truncationStart effectiveRange:0];
        NSAttributedString* const tokenString = [[NSAttributedString alloc]
                                                  initWithString:@"…" attributes:attributes];
        const CTLineRef token = CTLineCreateWithAttributedString((CFAttributedStringRef)tokenString);
        line = CTLineCreateTruncatedLine(untruncated, size.width, kCTLineTruncationEnd,
                                         token);
        CFRelease(token);
        CFRelease(untruncated);
        nextStringIndex = stringLength;
      }
      CGFloat ascent;
      CGFloat descent;
      CGFloat leading;
      const double width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
      const CGFloat nextY = y + (ascent + descent + leading);
      if (lineIndex != 0 && nextY >= size.height) { // Backtrack and truncate the rest.
        truncationStart = stringIndex;
        CFRelease(line);
        --lineIndex;
        line = lines[lineIndex];
        CTLineGetTypographicBounds(line, &ascent, nil, nil);
        y = origins[lineIndex].y - ascent;
        stringIndex = CTLineGetStringRange(line).location;
        CFRelease(line);
        --lineIndex;
        continue;
      }
      lines[lineIndex] = line;
      origins[lineIndex].y = y + ascent;
      origins[lineIndex].x = isRTL ? (size.width - (CGFloat)width) : 0;
      y = nextY;
      stringIndex = nextStringIndex;
    }
    const CFIndex lineCount = lineIndex;

    const CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1, -1);
    for (lineIndex = 0; lineIndex < lineCount; ++lineIndex) {
      const CGPoint p = {.x = offset.x + origins[lineIndex].x,
                         .y = offset.y + origins[lineIndex].y};
      CGContextSetTextMatrix(context, (CGAffineTransform){.a = 1, .d = 1, .tx = p.x, .ty = -p.y});
      CTLineDraw(lines[lineIndex], context);
      CFRelease(lines[lineIndex]);
    }
    CGContextScaleCTM(context, 1, -1);
    CFRelease(ts);
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingCTFrame(NSAttributedString * __unsafe_unretained attributedString,
                      CGSize size, CGPoint offset)
{
  {
    const CFIndex stringLength = (CFIndex)attributedString.length;
    const CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(
                                           (__bridge CFAttributedStringRef)attributedString);
    const CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, nil, (CGRect){{}, (CGSize){size.width, size.height}});
    const CTFrameRef frame = CTFramesetterCreateFrame(framesetter, (CFRange){}, path, nil);
    CFRelease(path);

    const CFArrayRef lines = CTFrameGetLines(frame);
    const CFIndex lineCount = CFArrayGetCount(lines);
    if (lineCount == 0) return;

    const CGContextRef context = UIGraphicsGetCurrentContext();

    CTLineRef lastLine = CFArrayGetValueAtIndex(lines, lineCount - 1);

    const CFRange lastLineStringRange = CTLineGetStringRange(lastLine);
    const CFIndex endStringIndex = lastLineStringRange.location + lastLineStringRange.length;

    if (endStringIndex == stringLength) {
      CGContextSaveGState(context);
      CGContextConcatCTM(context, (CGAffineTransform){.a = 1, .d = -1,
                                                      .tx = offset.x,
                                                      .ty = size.height + offset.y});
      CTFrameDraw(frame, context);
      CGContextRestoreGState(context);
    } else { // Truncate last line.
      CGFloat oldLastLineAscent;
      CTLineGetTypographicBounds(lastLine, &oldLastLineAscent, nil, nil);
      const CTTypesetterRef ts = CTFramesetterGetTypesetter(framesetter);
      const CTLineRef untruncated = CTTypesetterCreateLine(
                                      ts, (CFRange){lastLineStringRange.location,
                                                    stringLength - lastLineStringRange.location});
      NSDictionary<NSAttributedStringKey, id> * const attributes =
        [attributedString attributesAtIndex:(NSUInteger)endStringIndex effectiveRange:0];
      NSAttributedString* const tokenString = [[NSAttributedString alloc]
                                                initWithString:@"…" attributes:attributes];
      const CTLineRef token = CTLineCreateWithAttributedString((CFAttributedStringRef)tokenString);
      lastLine = CTLineCreateTruncatedLine(untruncated, size.width, kCTLineTruncationEnd,
                                          token);
      CFRelease(token);
      CFRelease(untruncated);
      CGFloat newLastLineAscent;
      double lastLinewidth = CTLineGetTypographicBounds(lastLine, &newLastLineAscent, nil, nil);

      CGContextScaleCTM(context, 1, -1);
      for (CFIndex i = 0; i < lineCount - 1; ++i) {
        CGPoint p;
        CTFrameGetLineOrigins(frame, (CFRange){i, 1}, &p);
        p.x += offset.x;
        p.y = (size.height - p.y) + offset.y;
        CGContextSetTextMatrix(context, (CGAffineTransform){.a = 1, .d = 1, .tx = p.x, .ty = -p.y});
        CTLineDraw(CFArrayGetValueAtIndex(lines, i), context);
      }
      {
        const bool isLTR = CTRunGetStringRange(CFArrayGetValueAtIndex(CTLineGetGlyphRuns(lastLine),
                                                                      0)).location
                            == lastLineStringRange.location;
        CGPoint p;
        CTFrameGetLineOrigins(frame, (CFRange){lineCount - 1, 1}, &p);
        p.x = (isLTR ? 0 : size.width - (CGFloat)lastLinewidth) + offset.x;
        p.y = (size.height - p.y) + (newLastLineAscent - oldLastLineAscent) + offset.y;
        CGContextSetTextMatrix(context, (CGAffineTransform){.a = 1, .d = 1, .tx = p.x, .ty = -p.y});
        CTLineDraw(lastLine, context);
      }
      CGContextScaleCTM(context, 1, -1);
      CFRelease(lastLine);
    }

    CFRelease(frame);
    CFRelease(framesetter);
  }
  PREVENT_TAIL_CALL
}
