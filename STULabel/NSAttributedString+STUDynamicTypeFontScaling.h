// Copyright 2017–2018 Stephan Tolksdorf

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (STUDynamicTypeScaling)

- (NSAttributedString *)
    stu_copyWithFontsAdjustedForContentSizeCategory:(UIContentSizeCategory)category
      NS_RETURNS_RETAINED
      API_AVAILABLE(ios(10.0), tvos(10.0));
@end

@interface NSMutableAttributedString (STUDynamicTypeScaling)

- (void)stu_adjustFontsInRange:(NSRange)range
        forContentSizeCategory:(UIContentSizeCategory)category
  API_AVAILABLE(ios(10.0), tvos(10.0));

@end

NS_ASSUME_NONNULL_END
