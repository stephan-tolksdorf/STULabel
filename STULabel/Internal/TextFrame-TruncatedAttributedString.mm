// Copyright 2017–2018 Stephan Tolksdorf

#import "TextFrame.hpp"

namespace stu_label {

NSDictionary<NSString*, id>* __nullable TextFrame::attributesAt(TextFrameIndex index) const {
  if (index.indexInTruncatedString == sign_cast(truncatedStringLength)) {
    return nil;
  }
  TruncationTokenIndex tti;
  const Range<Int32> range = rangeInOriginalString(index, Out{tti});
  if (!tti.truncationToken) {
    return [originalAttributedString attributesAtIndex:sign_cast(range.start) effectiveRange:nil];
  } else {
    return [tti.truncationToken attributesAtIndex:sign_cast(tti.indexInToken) effectiveRange:nil];
  }
}

static
NSAttributedString* __nonnull creatTextFrameTruncatedAttributedString(const TextFrame& textFrame)
                                NS_RETURNS_RETAINED
{
  Range<Int32> rangeInOriginalString = textFrame.rangeInOriginalString();
  ArrayRef<const TextFrameParagraph> paras = textFrame.paragraphs();
  for (Int i = paras.count(); i > 0; --i) {
    auto& para = paras[i - 1];
    if (!Range{para.rangeInTruncatedString}.isEmpty()) {
      paras = paras[{0, i}];
      rangeInOriginalString.end = para.rangeInOriginalString.end;
      break;
    }
  }
  NSMutableAttributedString* mutableString;
  if (textFrame.rangeInOriginalStringIsFullString
      && rangeInOriginalString == textFrame.rangeInOriginalString())
  {
    mutableString = [textFrame.originalAttributedString mutableCopy];
  } else {
    NSAttributedString* const substring = [textFrame.originalAttributedString
                                            attributedSubstringFromRange:
                                              NSRange(rangeInOriginalString)];
    if (!(textFrame.flags & STUTextFrameIsTruncated)) {
      return substring;
    }
    mutableString = [substring mutableCopy];
  }
  for (auto para = paras.begin(), end = paras.end(); para < end; ++para) {
    NSAttributedString* __unsafe_unretained const token = para->truncationToken;
    const Int32 index = para->rangeOfTruncationTokenInTruncatedString().start;
    const Int32 excisionStartInOriginalString = para->excisedRangeInOriginalString().start;
    while (para->excisedStringRangeIsContinuedInNextParagraph && para + 1 < end) {
      ++para;
    }
    const Int32 excisionEndInOriginalString = para->excisedRangeInOriginalString().end;
    const Int32 excisionLength = excisionEndInOriginalString - excisionStartInOriginalString;
    if (excisionLength) {
      const NSRange range{sign_cast(index), sign_cast(excisionLength)};
      if (token) {
        [mutableString replaceCharactersInRange:range withAttributedString:token];
      } else {
        [mutableString deleteCharactersInRange:range];
      }
    } else if (token) {
      [mutableString insertAttributedString:token atIndex:sign_cast(index)];
    }
  }
  return [mutableString copy];
}

Unretained<NSAttributedString* __nonnull> TextFrame::truncatedAttributedString() const {
  if (!(flags & STUTextFrameIsTruncated) && rangeInOriginalStringIsFullString) {
    return originalAttributedString;
  }
  _Atomic(CFAttributedStringRef)* const pAttributedString =
    const_cast<_Atomic(CFAttributedStringRef)*>(&_truncatedAttributedString);
  if (atomic_load_explicit(pAttributedString, memory_order_relaxed)) {
    return (__bridge NSAttributedString*)atomic_load_explicit(pAttributedString,
                                                              memory_order_acquire);
  }
  CFAttributedStringRef expected = nil;
  CFAttributedStringRef retained = (__bridge_retained CFAttributedStringRef)
                                     creatTextFrameTruncatedAttributedString(*this);
  if (atomic_compare_exchange_strong_explicit(pAttributedString, &expected, retained,
                                              memory_order_release, memory_order_acquire))
  {
    return (__bridge NSAttributedString*)retained;
  } else {
    discard((__bridge_transfer NSAttributedString*)(retained)); // Release again.
    return (__bridge NSAttributedString*)expected;
  }
}
  
}
