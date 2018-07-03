// Copyright 2017 Stephan Tolksdorf

#import "stu/Config.hpp"

#define STU_STATIC_CONST_ONCE(Type, name, initializer) \
  static dispatch_once_t name##_once; \
  static Type name##_value; \
  dispatch_once(&name##_once, ^{ name##_value = initializer; }); \
  Type const& name = name##_value

