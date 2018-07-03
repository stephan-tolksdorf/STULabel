// Copyright 2017–2018 Stephan Tolksdorf

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SnapshotTestCase : XCTestCase

/// Must be set before one of the check... methods is called.
@property (nonatomic, nullable) NSString *imageBaseDirectory;

@property (nonatomic) bool shouldRecordSnapshotsInsteadOfCheckingThem;

- (void)checkSnapshotImage:(UIImage *)image
            testNameSuffix:(nullable NSString *)testNameSuffix
              testFilePath:(const char *)testFilePath
              testFileLine:(size_t)line
            referenceImage:(nullable UIImage *)referenceImage;

@end

NS_ASSUME_NONNULL_END


#define PATH_RELATIVE_TO_CURRENT_SOURCE_FILE_DIR(path) \
     [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] \
                                                stringByAppendingPathComponent:(path)]


#define CHECK_SNAPSHOT_IMAGE(image, testNameSuffixStringOrNil) \
  [self checkSnapshotImage:(image) testNameSuffix:(testNameSuffixStringOrNil) \
              testFilePath:__FILE__ testFileLine:__LINE__ referenceImage:nil]
