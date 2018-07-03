// Copyright 2017 Stephan Tolksdorf

#import "STUBackgroundAttribute.h"

@interface STUBackgroundAttribute () {
@package
  UIColor *_color;
  bool _fillTextLineGaps;
  bool _extendTextLinesToCommonHorizontalBounds;
  CGFloat _cornerRadius;
  UIEdgeInsets _edgeInsets;
  UIColor *_borderColor;
  CGFloat _borderWidth;
}
@end
