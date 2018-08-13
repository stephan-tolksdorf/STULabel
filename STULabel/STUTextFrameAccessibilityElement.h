// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrame.h"

STU_ASSUME_NONNULL_AND_STRONG_BEGIN

typedef bool (^ STUTextLinkRangePredicate)(STUTextRange range, id linkValue, CGPoint point);

@class STUTextFrameAccessibilitySubelement;

/// Must only by used on the main thread.
STU_EXPORT
@interface STUTextFrameAccessibilityElement : UIAccessibilityElement

- (instancetype)initWithAccessibilityContainer:(UIView *)view
                                     textFrame:(STUTextFrame *)textFrame
                        originInContainerSpace:(CGPoint)originInContainerSpace
                                  displayScale:(CGFloat)displayScale
                      representUntruncatedText:(bool)representUntruncatedText
                            separateParagraphs:(bool)separateParagraphs
                          separateLinkElements:(bool)separateLinkElements
                               isDraggableLink:(__nullable STUTextLinkRangePredicate)isDraggableLink
                         linkActivationHandler:(__nullable STUTextLinkRangePredicate)
                                                 linkActivationHandler

  NS_DESIGNATED_INITIALIZER;

STU_DISABLE_CLANG_WARNING("-Wproperty-attribute-mismatch")
@property (nullable, weak) UIView *accessibilityContainer;
STU_REENABLE_CLANG_WARNING

/// Gets & sets accessibilityFrameInContainerSpace.origin.
@property (nonatomic) CGPoint textFrameOriginInContainerSpace;

@property (nonatomic) CGRect accessibilityFrameInContainerSpace;

@property (readonly) bool representsUntruncatedText;
@property (readonly) bool separatesParagraphs;
@property (readonly) bool separatesLinkElements;

@property (readonly) NSArray<STUTextFrameAccessibilitySubelement *> *accessibilityElements;

- (instancetype)init NS_UNAVAILABLE;
- (void)setAccessibilityElements:(nullable NSArray *)accessibilityElements NS_UNAVAILABLE;
- (void)setAccessibilityFrame:(CGRect)accessibilityFrame
  STU_UNAVAILABLE("Set textFrameOriginInContainerSpace or accessibilityFrameInContainerSpace instead.");

@end

STU_ASSUME_NONNULL_AND_STRONG_END
