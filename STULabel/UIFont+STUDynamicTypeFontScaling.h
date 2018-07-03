// Copyright 2017–2018 Stephan Tolksdorf

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIFont (STUDynamicTypeScaling)

- (UIFont *)stu_fontAdjustedForContentSizeCategory:(UIContentSizeCategory)category
  API_AVAILABLE(ios(10.0), tvos(10.0));

@end

NS_ASSUME_NONNULL_END
