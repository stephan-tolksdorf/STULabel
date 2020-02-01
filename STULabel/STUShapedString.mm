// Copyright 2017–2018 Stephan Tolksdorf

#import "STUShapedString-Internal.hpp"
#import "STULabelSwiftExtensions.h"

#import "STUObjCRuntimeWrappers.h"
#import "STUTextAttributes-Internal.hpp"
#import "stu/Assert.h"

#import "Internal/CancellationFlag.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/Once.hpp"
#import "Internal/ShapedString.hpp"
#import "Internal/STUPlaceholderObjects.h"
#import "Internal/TextStyleBuffer.hpp"
#import "Internal/UnicodeCodePointProperties.hpp"

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu;
using namespace stu_label;

STU_EXPORT
STUWritingDirection stu_defaultBaseWritingDirection() {
  STU_STATIC_CONST_ONCE(STUWritingDirection, value, ({
    // This is the default value used by CoreText and the value returned by
    // UIApplication.sharedApplication.userInterfaceLayoutDirection
    const NSWritingDirection value = [NSParagraphStyle defaultWritingDirectionForLanguage:nil];
    STU_CHECK(value == NSWritingDirectionLeftToRight || value == NSWritingDirectionRightToLeft);
    static_cast<STUWritingDirection>(value);
  }));
  return value;
}

STU_EXPORT
NSWritingDirection stu_detectBaseWritingDirection(NSString* __unsafe_unretained nsString,
                                                  NSRange range, bool skipIsolatedText)
{
  if (!nsString) return NSWritingDirectionNatural;
  const NSStringRef string{nsString};
  return detectBaseWritingDirection(string, Range<Int>{range}, SkipIsolatedText{skipIsolatedText});
}

NSAttributedString* stu_emptyAttributedString() {
  STU_STATIC_CONST_ONCE(NSAttributedString*, instance, [[NSAttributedString alloc] init]);
  return instance;
}

@implementation STUShapedString

- (NSAttributedString*)attributedString {
  return shapedString->attributedString;
}

- (NSUInteger)length {
  return sign_cast(shapedString->stringLength);
}

STU_EXPORT
size_t STUShapedStringGetLength(STUShapedString* self) {
  return sign_cast(self->shapedString->stringLength);
}

- (STUWritingDirection)defaultBaseWritingDirection {
  return shapedString->defaultBaseWritingDirection;
}

- (bool)defaultBaseWritingDirectionWasUsed {
  return shapedString->defaultBaseWritingDirectionWasUsed;
}

+ (nonnull instancetype)allocWithZone:(struct _NSZone* __unused)zone {
  static Class shapedStringClass;
  static STUShapedString* shapedStringPlaceholder;
  static dispatch_once_t once;
  dispatch_once_f(&once, nullptr, [](void *) {
    shapedStringClass = STUShapedString.class;
    shapedStringPlaceholder = stu_createClassInstance(STUUninitializedShapedString.class, 0);
  });

  if (self == shapedStringClass) {
    // The placeholder is a singleton without retain count and doesn't need to be retained.
    return (__bridge_transfer id)(__bridge CFTypeRef)shapedStringPlaceholder;
  } else {
    return stu_createClassInstance(self, 0);
  }
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

// The initWith... signatures must be kept in sync with the ones of STUUninitializedShapedString
// in Internal/STUPlaceholderObjects.m

- (instancetype)initWithAttributedString:(NSAttributedString*)attributedString {
  return [self initWithAttributedString:attributedString
            defaultBaseWritingDirection:stu_defaultBaseWritingDirection()
                      cancellationFlag:nil];
}

- (instancetype)initWithAttributedString:(NSAttributedString*)attributedString
              defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
{
  return [self initWithAttributedString:attributedString
            defaultBaseWritingDirection:baseWritingDirection
                      cancellationFlag:nil];
}

- (nullable instancetype)initWithAttributedString:(NSAttributedString*)attributedString
                      defaultBaseWritingDirection:(STUWritingDirection)baseWritingDirection
                                cancellationFlag:(nullable const STUCancellationFlag*)
                                                    cancellationFlag
{
  return STUShapedStringCreate(nil, attributedString, baseWritingDirection, cancellationFlag);
}


STUShapedString* __nullable
  STUShapedStringCreate(__nullable Class cls,
                        NSAttributedString* __unsafe_unretained attributedString,
                        STUWritingDirection baseWritingDirection,
                        const STUCancellationFlag* __nullable cancellationFlag)
    NS_RETURNS_RETAINED
{
  STU_CHECK_MSG(attributedString != nil, "NSAttributedString argument is null.");

  STU_STATIC_CONST_ONCE(Class, shapedStringClass, STUShapedString.class);
  STU_ANALYZER_ASSUME(shapedStringClass != nil);

  if (!cls) {
    cls = shapedStringClass;
  }

  baseWritingDirection = clampBaseWritingDirection(baseWritingDirection);

  ThreadLocalArenaAllocator::InitialBuffer<2048> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};

  const UInt instanceSize = roundUpToMultipleOf<alignof(ShapedString)>(class_getInstanceSize(cls));

  Byte* p;
  ShapedString* const shapedString = ShapedString::create(
                                       attributedString, baseWritingDirection, cancellationFlag,
                                       [&](UInt size) -> void* {
                                         p = static_cast<Byte*>(malloc(instanceSize + size));
                                         if (!p) __builtin_trap();
                                         return p + instanceSize;
                                       });
  if (!shapedString) return nil;

  memset(p, 0, instanceSize);
  STUShapedString* const instance = stu_constructClassInstance(cls, p);
  STU_DEBUG_ASSERT([instance isKindOfClass:shapedStringClass]);
  const_cast<ShapedString*&>(instance->shapedString) = shapedString;

  return instance;
}

- (void)dealloc {
  if (shapedString) {
    shapedString->~ShapedString();
  }
}

STU_NO_INLINE
Unretained<STUShapedString* __nonnull>
  stu_label::emptyShapedString(STUWritingDirection baseWritingDirection)
{
  switch (clampBaseWritingDirection(baseWritingDirection)) {
  case STUWritingDirectionLeftToRight: {
    STU_STATIC_CONST_ONCE(STUShapedString*, emptyLTRShapedString,
                          STUShapedStringCreate(nil, stu_emptyAttributedString(),
                                                STUWritingDirectionLeftToRight, nullptr));
    return emptyLTRShapedString;
  }
  case STUWritingDirectionRightToLeft: {
    STU_STATIC_CONST_ONCE(STUShapedString*, emptyRTLShapedString,
                          STUShapedStringCreate(nil, stu_emptyAttributedString(),
                                                STUWritingDirectionRightToLeft, nullptr));
    return emptyRTLShapedString;
  }
  }
}

+ (nonnull STUShapedString*)emptyShapedStringWithDefaultBaseWritingDirection:
                              (STUWritingDirection)baseWritingDirection
{
  return emptyShapedString(baseWritingDirection).unretained;
}

@end

