// Copyright 2017–2018 Stephan Tolksdorf

#import "TextStyle.hpp"

#import "STULabel/STUParagraphStyle-Internal.hpp"

#import "Font.hpp"
#import "HashTable.hpp"

#include <exception>

namespace stu_label {

extern NSString* const STUOriginalFontAttributeName;

/// @note
///  The TextStyle data may contain non-owning references to attributes of the
///  NSAttributedString(s). Hence, the attributed strings (or a copy of them) must be kept alive
///  (and not be mutated) for as long as the style data is in use. Furthermore, the ColorRefs store
///  CGColor pointers obtained from the UIColor's CGColor property, without retaining them. So,
///  in theory, the CGColor's lifetime may end when the current autorelease pool is emptied
///  (though in practice all UIColor subclasses cache the returned CGColor objects).
class TextStyleBuffer {
public:
  using ColorHashBucket = TempIndexHashSet<UInt16>::Bucket;

  explicit STU_INLINE
  TextStyleBuffer(Ref<LocalFontInfoCache> fontInfoCache,
                  ThreadLocalAllocatorRef allocator,
                  Pair<ArrayRef<const ColorRef>, ArrayRef<const ColorHashBucket>> existingColors
                  = Pair<ArrayRef<ColorRef>, ArrayRef<ColorHashBucket>>{})
  : fontIndices_{uninitialized, allocator}, colorIndices_{uninitialized, allocator},
    oldColors_{existingColors}, localFontInfoCache_{fontInfoCache.get()}
  {
    STU_ASSERT(existingColors.first.count() == existingColors.second.count());
  }

#if STU_DEBUG
  ~TextStyleBuffer() {
    if (!std::uncaught_exceptions()) {
      STU_DEBUG_ASSERT(!needToFixAttachmentAttributes_);
    }
  }
#endif

  STU_INLINE_T ArrayRef<const Byte> data() const { return data_; }
  STU_INLINE_T ArrayRef<const FontRef> fonts() const { return fonts_; }

  /// Doesn't reset fonts or colors.
  STU_INLINE
  void clearData() {
    STU_DEBUG_ASSERT(!needToFixAttachmentAttributes_);
    data_.removeAll();
    nextUTF16Index_ = 0;
    lastStyleSize_ = 0;
    lastStyle_ = nil;
  }

  void setData(ArrayRef<const Byte> data) {
    STU_DEBUG_ASSERT(!needToFixAttachmentAttributes_);
    STU_DEBUG_ASSERT(nextUTF16Index_ == 0 && lastStyleSize_ == 0 && lastStyle_ == nullptr);
    data_.removeAll();
    data_.append(data);
  }

  STU_INLINE_T
  ArrayRef<const ColorRef> colors() const {
    return !oldColors_.first.isEmpty() ? oldColors_.first : colors_;
  }
  STU_INLINE_T
  ArrayRef<const ColorHashBucket> colorHashBuckets() const {
    return !oldColors_.first.isEmpty() ? oldColors_.second : colorIndices_.buckets();
  }

  STU_INLINE_T
  UInt8 lastStyleSize() const { return lastStyleSize_; }

  struct ParagraphAttributes {
    NSParagraphStyle* __unsafe_unretained __nullable style;
    ParagraphExtraStyle* __nullable extraStyle;
    STUTruncationScope* __unsafe_unretained __nullable truncationScope;
    /// NSWritingDirection isn't a paragraph-level attribute, but we check for its presence during
    /// the processing of the paragraph.
    bool hasWritingDirectionAttribute;
  };

  TextFlags encodeStringRangeStyle(Range<Int> stringRange,
                                   NSDictionary<NSAttributedStringKey, id>* __nullable attributes,
                                   Optional<Out<ParagraphAttributes>> = none);

  void addStringTerminatorStyle();

  TextFlags encode(NSAttributedString* __nonnull);

  bool needToFixAttachmentAttributes() const { return needToFixAttachmentAttributes_; }

  void fixAttachmentAttributesIn(NSMutableAttributedString* __nonnull);

  // Only used in tests.
  void clearNeedToFixAttachmentAttributesFlag() {
    needToFixAttachmentAttributes_ = false;
  }

  // 43691 would trigger a HashTable bucket array resize to 2^17 buckets and we only use 16-bit hash
  // codes.
  static constexpr Int maxFontCount = 43690;

private:
  FontIndex addFont(FontRef);
  ColorIndex addColor(UIColor*);
  TextFlags colorFlags(ColorIndex) const;

  TempVector<FontRef> fonts_;
  TempVector<ColorRef> colors_;
  TempVector<Byte> data_;

  Int32 nextUTF16Index_{};
  UInt8 lastStyleSize_{};
  bool needToFixAttachmentAttributes_{};

  const stu_label::TextStyle* __nullable lastStyle_{};

  TempIndexHashSet<UInt16> fontIndices_; // uninitialized
  TempIndexHashSet<UInt16> colorIndices_; // uninitialized

  Pair<ArrayRef<const ColorRef>, ArrayRef<const ColorHashBucket>> oldColors_;

  LocalFontInfoCache& localFontInfoCache_;
};

} // namespace stu_label
