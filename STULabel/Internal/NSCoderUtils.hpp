// Copyright 2017–2018 Stephan Tolksdorf

#import "Rect.hpp"

namespace stu_label {

template <typename T, EnableIf<isIntegral<T>> = 0>
STU_INLINE
void encode(NSCoder* coder, NSString* key, T value) {
  if constexpr (isSame<T, bool>) {
    [coder encodeBool:value forKey:key];
  } else if constexpr (sizeof(T) <= 4 && (isSigned<T> || sizeof(T) < 4)) {
    [coder encodeInt32:static_cast<Int32>(value) forKey:key];
  } else {
    static_assert(sizeof(T) <= 8);
    [coder encodeInt64:static_cast<Int64>(value) forKey:key];
  }
}

template <typename T, EnableIf<isIntegral<T>> = 0>
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<T> value) {
  if constexpr (isSame<T, bool>) {
    value = [coder decodeBoolForKey:key];
  } else if constexpr (sizeof(T) <= 4 && (isSigned<T> || sizeof(T) < 4)) {
    value = static_cast<T>([coder decodeInt32ForKey:key]);
  } else {
    static_assert(sizeof(T) <= 8);
    value = static_cast<T>([coder decodeInt64ForKey:key]);
  }
}

template <typename T, EnableIf<isEnum<T>> = 0>
STU_INLINE
void encode(NSCoder* coder, NSString* key, T value) {
  encode(coder, key, static_cast<UnderlyingType<T>>(value));
}
template <typename T, EnableIf<isEnum<T>> = 0>
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<T> outValue) {
  UnderlyingType<T> t;
  decode(coder, key, Out{t});
  outValue = static_cast<T>(t);
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, Float32 value) {
  [coder encodeFloat:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<Float32> outValue) {
  outValue = [coder decodeFloatForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, Float64 value) {
  [coder encodeDouble:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<Float64> outValue) {
  outValue = [coder decodeDoubleForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, CGSize value) {
  [coder encodeCGSize:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<CGSize> outValue) {
  outValue = [coder decodeCGSizeForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, CGRect value) {
  [coder encodeCGRect:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<CGRect> outValue) {
  outValue = [coder decodeCGRectForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, Rect<CGFloat> value) {
  [coder encodeCGRect:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<Rect<CGFloat>> outValue) {
  outValue = [coder decodeCGRectForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, UIEdgeInsets value) {
  [coder encodeUIEdgeInsets:value forKey:key];
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<UIEdgeInsets> outValue) {
  outValue = [coder decodeUIEdgeInsetsForKey:key];
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, NSObject<NSSecureCoding>* object) {
  if (object) {
    [coder encodeObject:object forKey:key];
  }
}
template <typename T, EnableIf<isConvertible<T*, NSObject<NSSecureCoding>*>> = 0>
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<T*> outObject) {
  outObject = down_cast<T*>([coder decodeObjectOfClass:[T self] forKey:key]);
}

STU_INLINE
void encode(NSCoder* coder, NSString* key, NSRange value) {
  encode(coder, key, [NSValue valueWithRange:value]);
}
STU_INLINE
void decode(NSCoder* coder, NSString* key, Out<NSRange> outValue) {
  NSValue* value = nil;
  decode(coder, key, Out{value});
  outValue = value.rangeValue;
}

} // namespace stu_label
