// Copyright 2017–2018 Stephan Tolksdorf

#if !__has_feature(objc_arc)
  #error This header must only be included from files compiled with ARC support enabled
#endif

// We can't call this header "Config.hpp" due to https://github.com/CocoaPods/CocoaPods/issues/7807

#if defined(NDEBUG)
  #error NDEBUG is defined. Do you really want to disable all runtime bounds checking in STULabel?
#endif

#import "stu/ArrayRef.hpp"
#import "stu/NSFoundationSupport.hpp"
#import "stu/Optional.hpp"
#import "stu/OptionsEnum.hpp"

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

namespace stu_label {
  using namespace stu;
  using stu::Int32;
  using stu::UInt32;
  using stu::Fixed;
}
