// Copyright 2018 Stephan Tolksdorf

#import <UIKit/UIKit.h>

#import <Contacts/Contacts.h>

@interface STULabelAddToContactsViewController : UINavigationController
- (instancetype)initWithContact:(CNContact *)contact NS_DESIGNATED_INITIALIZER;
@end
