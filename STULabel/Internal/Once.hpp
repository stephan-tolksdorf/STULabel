// Copyright 2017 Stephan Tolksdorf

#import "stu/TypeTraits.hpp"

#import <dispatch/dispatch.h>

#if !DISPATCH_ONCE_INLINE_FASTPATH
  #error This implementation depends on the libdispatch fast path.
#endif

namespace stu_label {
  /// Must only be used as a zero-initialized static/global.
  struct Once {
    dispatch_once_t once;

    STU_INLINE_T
    bool isInitialized() {
      static_assert(stu::isSame<dispatch_once_t, long>);
      if (DISPATCH_EXPECT(this->once, ~0L) == ~0L) {
        dispatch_compiler_barrier();
        DISPATCH_COMPILER_CAN_ASSUME(this->once == ~0L);
        return true;
      }
      return false;
    }

    STU_INLINE
    void initialize(void* __nullable context, dispatch_function_t function) {
      #pragma push_macro("dispatch_once_f")
      #undef dispatch_once_f
      dispatch_once_f(&this->once, context, function);
      #pragma pop_macro("dispatch_once_f")
      DISPATCH_COMPILER_CAN_ASSUME(this->once == ~0L);
    }
  };
}

#define STU_STATIC_CONST_ONCE_WITH_INVOKE_ATTRIBUTE(Type, name, invokeAttribute, initializer) \
  static ::stu_label::Once name##_once; \
  static Type name##_value; \
  struct name##_initializer { \
    static STU_NO_INLINE invokeAttribute void invoke() { name##_once.initialize(nullptr, body); } \
  private: \
    static void body(void*) { name##_value = initializer; } \
  }; \
  if (!name##_once.isInitialized()) { \
		name##_initializer::invoke(); \
	} \
  Type const& name = name##_value

#define STU_STATIC_CONST_ONCE(Type, name, initializer) \
  STU_STATIC_CONST_ONCE_WITH_INVOKE_ATTRIBUTE(Type, name, , initializer)

#define STU_STATIC_CONST_ONCE_PRESERVE_MOST(Type, name, initializer) \
  STU_STATIC_CONST_ONCE_WITH_INVOKE_ATTRIBUTE(Type, name, STU_PRESERVE_MOST, initializer)

