// Copyright 2017–2018 Stephan Tolksdorf

#import "NSStringRef.hpp"

namespace stu_label {

struct OutEffectiveRange : Parameter<OutEffectiveRange, Range<Int>&> {
  using Parameter::Parameter;
};

struct OutEndOfLongestEffectiveRange : Parameter<OutEndOfLongestEffectiveRange, Int&> {
  using Parameter::Parameter;
};

using CFAttributedString = RemovePointer<CFAttributedStringRef>;

namespace detail {
  CFStringRef getStringWithoutRetain(NSAttributedString* attributedString);
}

/// A non-owning reference to an NSAttributedString instance.
class NSAttributedStringRef {
public:
  NSAttributedString* __unsafe_unretained const attributedString;
  const NSStringRef string;
private:
  using GetAttributesMethod = NSDictionary<NSAttributedStringKey, id>*
                                (*)(NSAttributedString*, SEL, NSUInteger, NSRangePointer);
  const GetAttributesMethod getAttributesMethod_;

public:
  explicit STU_INLINE
  NSAttributedStringRef(NSAttributedString* __unsafe_unretained attributedString,
                        Optional<Ref<TempStringBuffer>> optBuffer = none)
  : attributedString{attributedString},
    string{detail::getStringWithoutRetain(attributedString), optBuffer},
    getAttributesMethod_{reinterpret_cast<GetAttributesMethod>(
                           [attributedString methodForSelector:
                                               @selector(attributesAtIndex:effectiveRange:)])}
  {
    STU_DEBUG_ASSERT(attributedString != nil);
  }

  STU_INLINE
  id attributeAtIndex(CFString* key, Int index) const {
    return attributesAtIndex(index)[(__bridge NSAttributedStringKey)key];
  }

  STU_INLINE
  id attributeAtIndex(NSAttributedStringKey __unsafe_unretained key, Int index) const {
    return attributesAtIndex(index)[key];
  }

  STU_INLINE
  NSDictionary<NSAttributedStringKey, id>* attributesAtIndex(Int index) const {
    return getAttributesMethod_(attributedString, @selector(attributesAtIndex:effectiveRange:),
                                sign_cast(index), nullptr);
  }

  STU_INLINE
  NSDictionary<NSAttributedStringKey, id>* attributesAtIndex(Int index,
                                                             OutEffectiveRange outRange) const
  {
    NSRange range;
    NSDictionary<NSAttributedStringKey, id>* const attributes =
      getAttributesMethod_(attributedString, @selector(attributesAtIndex:effectiveRange:),
                           sign_cast(index), &range);
    outRange.value = Range<Int>{range};
    return attributes;
  }

  STU_INLINE
  id attributeAtIndex(CFString* key, Int index,
                      OutEndOfLongestEffectiveRange outEndOfLongestEffectiveRange) const
  {
    return attributeAtIndex((__bridge NSAttributedStringKey)key, index,
                            outEndOfLongestEffectiveRange);
  }

  STU_INLINE
  __nullable id attributeAtIndex(NSAttributedStringKey __unsafe_unretained key, Int index,
                                 OutEndOfLongestEffectiveRange outEndOfLongestEffectiveRange) const
  {
    return attributeAtStartOf(key, Range{index, string.count()}, outEndOfLongestEffectiveRange);
  }

  STU_INLINE
  __nullable id attributeAtStartOf(NSAttributedStringKey __unsafe_unretained key, Range<Int> range,
                                   OutEndOfLongestEffectiveRange outEndOfLongestEffectiveRange) const
  {
    STU_DEBUG_ASSERT(!range.isEmpty());
    NSRange effectiveRange;
    const id attribute = [attributedString attribute:key atIndex:sign_cast(range.start)
                               longestEffectiveRange:&effectiveRange
                                             inRange:sign_cast(range)];
    outEndOfLongestEffectiveRange.value = sign_cast(Range{effectiveRange}.end);
    return attribute;
  }
};

} // namespace stu_label
