// Copyright 2017–2018 Stephan Tolksdorf

#if __has_feature(objc_arc)
  #error This file must be compiled with -fno-objc-arc
#endif

#import "STUPlaceholderObjects.h"

#import "STULabel/STUObjCRuntimeWrappers.h"

#import "STULabel/STUShapedString.h"

// We use forward declarations here so that we don't need to import the corresponding header files
// from this no-objc-arc file.

STU_EXTERN_C_BEGIN

STUShapedString * __nullable STUShapedStringCreate(__nullable Class cls,
                                                   NSAttributedString * __nonnull,
                                                   STUWritingDirection,
                                                   const STUCancellationFlag *)
                               NS_RETURNS_RETAINED;

STUTextFrame * __nonnull
  STUTextFrameCreateWithShapedString(__nullable Class cls,
                                     STUShapedString * __nonnull shapedString,
                                     CGSize size, CGFloat displayScale,
                                     STUTextFrameOptions * __nullable options)
    NS_RETURNS_RETAINED;

STUTextFrame * __nonnull
  STUTextFrameCreateWithShapedStringRange(__nullable Class cls,
                                          STUShapedString * __nonnull shapedString,
                                          NSRange stringRange,
                                          CGSize size, CGFloat displayScale,
                                          STUTextFrameOptions * __nullable options,
                                          const STUCancellationFlag*)
    NS_RETURNS_RETAINED;

STU_EXTERN_C_END

STU_DISABLE_CLANG_WARNING("-Wobjc-designated-initializers")
STU_DISABLE_CLANG_WARNING("-Wobjc-missing-super-calls")

@implementation STUUninitializedShapedString

- (STUShapedString *)initWithAttributedString:(NSAttributedString *)attributedString
{
  return (id)STUShapedStringCreate(nil, attributedString, stu_defaultBaseWritingDirection(), nil);
}


- (STUShapedString *)initWithAttributedString:(NSAttributedString *)attributedString
                  defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
{
  return (id)STUShapedStringCreate(nil, attributedString, baseWritingDirection, nil);
}

- (nullable STUShapedString *)initWithAttributedString:(NSAttributedString *)attributedString
                           defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
                                     cancellationFlag:(nullable const STUCancellationFlag *)
                                                         cancellationFlag
{
  return (id)STUShapedStringCreate(nil, attributedString, baseWritingDirection, cancellationFlag);
}

- (void)dealloc {}

- (instancetype)retain { return self;  }
- (oneway void)release { }
- (instancetype)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

@implementation STUUninitializedTextFrame

- (nonnull STUTextFrame *)initWithShapedString:(nonnull STUShapedString *)shapedString
                                          size:(CGSize)size
                                  displayScale:(CGFloat)displayScale
                                       options:(STUTextFrameOptions * __nullable)options
{
  return (id)STUTextFrameCreateWithShapedString(nil, shapedString, size, displayScale, options);
}


- (nullable STUTextFrame *)initWithShapedString:(nonnull STUShapedString *)shapedString
                                    stringRange:(NSRange)stringRange
                                           size:(CGSize)size
                                   displayScale:(CGFloat)displayScale
                                        options:(STUTextFrameOptions * __nullable)options
                              cancellationFlag:(nullable const STUCancellationFlag *)
                                                  cancellationFlag
{
  return (id)STUTextFrameCreateWithShapedStringRange(nil, shapedString, stringRange, size,
                                                     displayScale, options, cancellationFlag);
}

- (void)dealloc {}

- (instancetype)retain { return self;  }
- (oneway void)release { }
- (instancetype)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

STU_REENABLE_CLANG_WARNING
STU_REENABLE_CLANG_WARNING



