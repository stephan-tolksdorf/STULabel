// Copyright 2018 Stephan Tolksdorf

#import <UIKit/UIKit.h>

#import <Contacts/Contacts.h>

@interface STULabelAddToContactsViewController : UINavigationController
- (instancetype)initWithContact:(CNContact *)contact NS_DESIGNATED_INITIALIZER;


- (instancetype)initWithNavigationBarClass:(nullable Class)navigationBarClass toolbarClass:(nullable Class)toolbarClass NS_UNAVAILABLE;

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController NS_UNAVAILABLE;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
