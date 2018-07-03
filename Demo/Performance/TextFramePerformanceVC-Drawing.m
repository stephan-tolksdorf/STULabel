// Copyright 2018 Stephan Tolksdorf

#import "TextFramePerformanceVC-Drawing.h"

@import STULabel;

// We prevent tail calls here to ease analysis with Instruments.
#define PREVENT_TAIL_CALL asm volatile("":::"memory");

STU_NO_INLINE
void drawUsingSTUTextFrame(NSAttributedString * __unsafe_unretained attributedString,
                           CGSize size, CGPoint offset)
{
  {
    STUShapedString * const shapedString = [[STUShapedString alloc]
                                              initWithAttributedString:attributedString
                                              defaultBaseWritingDirection:STUWritingDirectionLeftToRight];
    STUTextFrame * const textFrame = [[STUTextFrame alloc] initWithShapedString:shapedString
                                                                           size:size options:nil];
    [textFrame drawAtPoint:offset];
  }
  PREVENT_TAIL_CALL
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

    const bool isRTL = ((NSParagraphStyle*)
                          [[attributedString attributesAtIndex:0 effectiveRange:nil]
                             objectForKey:NSParagraphStyleAttributeName])
                       .baseWritingDirection == NSWritingDirectionRightToLeft;
    const CGFloat dx = isRTL ? size.width - (CGFloat)width : 0;
    
    const CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, offset.x + dx, offset.y + ascent);
    CGContextScaleCTM(context, 1, -1);
    CTLineDraw(line, context);
    CGContextRestoreGState(context);
    CFRelease(line);
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingCTTypesetter(NSAttributedString * __unsafe_unretained attributedString,
                           CGSize __unused size, CGPoint offset)
{
  {
    const CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(
                                         (__bridge CFAttributedStringRef)attributedString);

    const CTLineRef line = CTTypesetterCreateLineWithOffset(typesetter, (CFRange){}, 0);

    CGFloat ascent;
    const double width = CTLineGetTypographicBounds(line, &ascent, nil, nil);

    const bool isRTL = ((NSParagraphStyle*)
                          [[attributedString attributesAtIndex:0 effectiveRange:nil]
                             objectForKey:NSParagraphStyleAttributeName])
                       .baseWritingDirection == NSWritingDirectionRightToLeft;
    const CGFloat dx = isRTL ? size.width - (CGFloat)width : 0;

    const CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, offset.x + dx, offset.y + ascent);
    CGContextScaleCTM(context, 1, -1);
    CTLineDraw(line, context);
    CGContextRestoreGState(context);
    CFRelease(line);
    CFRelease(typesetter);
  }
  PREVENT_TAIL_CALL
}

STU_NO_INLINE
void drawUsingCTFrame(NSAttributedString * __unsafe_unretained attributedString,
                           CGSize size, CGPoint offset)
{
  {
    const CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(
                                           (__bridge CFAttributedStringRef)attributedString);
    CGMutablePathRef path = CGPathCreateMutable();

    CGPathAddRect(path, nil, (CGRect){{}, (CGSize){size.width, size.height}});
    const CTFrameRef frame = CTFramesetterCreateFrame(framesetter, (CFRange){}, path, nil);
    CFRelease(path);

    const CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    CGContextTranslateCTM(context, offset.x, offset.y + size.height);
    CGContextScaleCTM(context, 1, -1);

    CTFrameDraw(frame, context);

    CGContextRestoreGState(context);

    CFRelease(frame);
    CFRelease(framesetter);
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
    [layoutManager addTextContainer:container];
    NSTextStorage * const storage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
    [storage addLayoutManager:layoutManager];
    const NSRange range = [layoutManager glyphRangeForTextContainer:container];
    [layoutManager drawBackgroundForGlyphRange:range atPoint:offset];
    [layoutManager drawGlyphsForGlyphRange:range atPoint:offset];
  }
  PREVENT_TAIL_CALL
}

