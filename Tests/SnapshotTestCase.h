// Copyright 2017–2018 Stephan Tolksdorf

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SnapshotTestCase : XCTestCase

/// Must be set before one of the check... methods is called.
@property (nonatomic, nullable) NSString *imageBaseDirectory;

// All boolean properties are reset to false during each call to setUp.

@property (nonatomic) bool shouldRecordSnapshotsInsteadOfCheckingThem;

/// Does not affect checkSnapshotImage.
@property (nonatomic) bool shouldUseExtendedColorSpace;

/// Only affects checkSnapshotOfView
@property (nonatomic) bool shouldUseDrawViewHierarchyInRect;

- (void)setUp NS_REQUIRES_SUPER;

- (void)checkSnapshotOfView:(UIView *)view
             testNameSuffix:(nullable NSString *)testNameSuffix
               testFilePath:(const char *)testFilePath
               testFileLine:(size_t)testFileLine
  __attribute__((__availability__(swift, unavailable)));

- (void)checkSnapshotOfView:(UIView *)view
              contentsScale:(CGFloat)scale
         beforeLayoutAction:(nullable void (NS_NOESCAPE ^)(void))beforeLayoutAction
             testNameSuffix:(nullable NSString *)testNameSuffix
               testFilePath:(const char *)testFilePath
               testFileLine:(size_t)testFileLine
  NS_REFINED_FOR_SWIFT;

- (void)checkSnapshotOfLayer:(CALayer *)CALayer
              testNameSuffix:(nullable NSString *)testNameSuffix
                testFilePath:(const char *)testFilePath
                testFileLine:(size_t)testFileLine
  __attribute__((__availability__(swift, unavailable)));

- (void)checkSnapshotOfLayer:(CALayer *)CALayer
               contentsScale:(CGFloat)scale
          beforeLayoutAction:(nullable void (NS_NOESCAPE ^)(void))beforeLayoutAction
              testNameSuffix:(nullable NSString *)testNameSuffix
                testFilePath:(const char *)testFilePath
                testFileLine:(size_t)testFileLine
  NS_REFINED_FOR_SWIFT;

- (void)checkSnapshotImage:(UIImage *)image
            testNameSuffix:(nullable NSString *)testNameSuffix
              testFilePath:(const char *)testFilePath
              testFileLine:(size_t)testFileLine
            referenceImage:(nullable UIImage *)referenceImage
  NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END


#define PATH_RELATIVE_TO_CURRENT_SOURCE_FILE_DIR(path) \
     [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] \
                                                stringByAppendingPathComponent:(path)]

#define CHECK_VIEW_SNAPSHOT(view, testNameSuffixStringOrNil) \
  [self checkSnapshotOfView:(view) \
             testNameSuffix:(testNameSuffixStringOrNil) \
               testFilePath:__FILE__ testFileLine:__LINE__ referenceImage:nil]

#define CHECK_LAYER_SNAPSHOT(layer, testNameSuffixStringOrNil) \
  [self checkSnapshotOfLayer:(layer) \
              testNameSuffix:(testNameSuffixStringOrNil) \
                testFilePath:__FILE__ testFileLine:__LINE__ referenceImage:nil]

#define CHECK_SNAPSHOT_IMAGE(image, testNameSuffixStringOrNil) \
  [self checkSnapshotImage:(image) testNameSuffix:(testNameSuffixStringOrNil) \
              testFilePath:__FILE__ testFileLine:__LINE__ referenceImage:nil]
