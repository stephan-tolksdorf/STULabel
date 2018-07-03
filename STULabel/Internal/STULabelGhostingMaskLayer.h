// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabel/STULayerWithNullDefaultActions.h"
#import "STULabel/STUTextLink.h"

NS_ASSUME_NONNULL_BEGIN

@interface STULabelGhostingMaskLayer : STUShapeLayerWithNullDefaultActions

- (void)setMaskedLayerFrame:(CGRect)maskedLayerFrame links:(STUTextLinkArray *)links;

- (bool)hasGhostedLink:(STUTextLink *)link;

- (void)ghostLink:(STUTextLink *)link;

/// Returns true if this was the last ghosted link.
- (bool)unghostLink:(STUTextLink *)link;

@end

NS_ASSUME_NONNULL_END
