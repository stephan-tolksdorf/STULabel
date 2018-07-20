// Copyright 2017 Stephan Tolksdorf

#import "Common.hpp"

namespace stu_label {

STU_CONSTEXPR
bool operator==(NSRange lhs, NSRange rhs) {
  return lhs.location == rhs.location && lhs.length == rhs.length;
}
STU_CONSTEXPR bool operator!=(NSRange lhs, NSRange rhs) { return !(lhs == rhs); }

STU_CONSTEXPR
bool operator==(CGPoint lhs, CGPoint rhs) {
  return lhs.x == rhs.x && lhs.y == rhs.y;
}
STU_CONSTEXPR bool operator!=(CGPoint lhs, CGPoint rhs) { return !(lhs == rhs); }

STU_CONSTEXPR
bool operator==(CGSize lhs, CGSize rhs) {
  return lhs.width == rhs.width && lhs.height == rhs.height;
}
STU_CONSTEXPR bool operator!=(CGSize lhs, CGSize rhs) { return !(lhs == rhs); }

STU_CONSTEXPR
bool operator==(const CGRect& lhs, const CGRect& rhs) {
  return lhs.origin == rhs.origin && lhs.size == rhs.size;
}
STU_CONSTEXPR bool operator!=(const CGRect& lhs, const CGRect& rhs) { return !(lhs == rhs); }

STU_CONSTEXPR
bool operator==(const CGAffineTransform& lhs, const CGAffineTransform& rhs) {
  return lhs.a  == rhs.a
      && lhs.d  == rhs.d
      && lhs.tx == rhs.tx
      && lhs.ty == rhs.ty
      && lhs.b  == rhs.b
      && lhs.c  == rhs.c;
}
STU_CONSTEXPR
bool operator!=(const CGAffineTransform& lhs, const CGAffineTransform& rhs) {
  return !(lhs == rhs);
}

STU_CONSTEXPR
bool operator==(const UIEdgeInsets& lhs, const UIEdgeInsets& rhs) {
  return lhs.top == rhs.top
      && lhs.left == rhs.left
      && lhs.bottom == rhs.bottom
      && lhs.right == rhs.right;
}
STU_CONSTEXPR
bool operator!=(const UIEdgeInsets& lhs, const UIEdgeInsets& rhs) { return !(lhs == rhs); }


template <typename T, typename U,
          EnableIf<isConvertible<T*, id> && (isConvertible<T*, U*> || isConvertible<U*,T*>)> = 0>
STU_INLINE
bool equal(T* __unsafe_unretained obj1, U* __unsafe_unretained obj2) {
  return (obj1 == obj2 || (obj1 && obj2 && [obj1 isEqual:obj2]));
}

template <typename T, int n>
STU_CONSTEXPR
bool equal(T (& array1)[n], T (& array2)[n]) {
  for (int i = 0; i < n; ++i) {
    if (!equal(array1[i], array2[i])) return false;
  }
  return true;
}

template <typename T, EnableIf<!isPointer<T>> = 0>
STU_CONSTEXPR
bool equal(T obj1, T obj2) {
  return obj1 == obj2;
}


} // namespace stu_label
