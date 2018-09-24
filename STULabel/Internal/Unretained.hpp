// Copyright 2018 Stephan Tolksdorf

#import "stu/Comparable.hpp"

namespace stu_label {

/// A simple wrapper for an __unsafe_unretained Objective-C pointer, which is useful for
/// returning unretained pointers from functions in ARC code.
/// (LLVM currently can't optimize away the implicit autoreleases that are triggered when returning
/// an Objective-C pointer from an inline function.)
template <typename Pointer>
struct Unretained : stu::Comparable<Unretained<Pointer>> {
  static_assert(stu::isPointer<Pointer>);

  Pointer __unsafe_unretained unretained;

  /* implicit */ STU_CONSTEXPR_T
  Unretained(Pointer __unsafe_unretained pointer) : unretained(pointer) {}

  explicit STU_CONSTEXPR_T
  operator bool() const { return unretained; }

  STU_CONSTEXPR_T
  friend bool operator==(Unretained<Pointer> lhs, Unretained<Pointer> rhs) {
    return lhs.unretained == rhs.unretained;
  }

  STU_CONSTEXPR_T
  friend bool operator<(Unretained<Pointer> lhs, Unretained<Pointer> rhs) {
    return lhs.unretained < rhs.unretained;
  }
};

} // namespace stu_label
