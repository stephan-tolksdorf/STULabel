// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STULabel.h"

#import "STULabelTiledLayer.h"

typedef void (^ STULabelSubrangeDrawingBlock)(CGContextRef, CGRect,
                                              const STUCancellationFlag * __nullable);

@interface STULabelSubrangeView : UIView
@property (nonatomic, nullable) STULabelSubrangeDrawingBlock drawingBlock;
@end

@interface STULabelTiledSubrangeView : STULabelSubrangeView
@end
