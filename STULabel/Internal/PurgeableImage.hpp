// Copyright 2018 Stephan Tolksdorf

#import "STULabel/STUImageUtils.h"

#import "Rect.hpp"

#import "stu/FunctionRef.hpp"

namespace stu_label {

template <typename Int>
struct SizeInPixels : Size<Int> {

  STU_INLINE_T
  SizeInPixels() = default;

  explicit STU_CONSTEXPR_T
  SizeInPixels(Size<Int> sizeInPixels) : Size<Int>{sizeInPixels} {}

  STU_CONSTEXPR_T
  SizeInPixels(Int widthInPixels, Int heightInPixels)
  : Size<Int>{widthInPixels, heightInPixels} {}

  STU_CONSTEXPR_T
  SizeInPixels(CGSize size, CGFloat scale) {
    const CGFloat absScale = abs(scale);
    CGFloat width  = nearbyint(size.width*absScale);
    CGFloat height = nearbyint(size.height*absScale);

    static_assert(isOneOf<CGFloat, Float32, Float64>);
    static_assert(isSame<Int, UInt32>, "Not yet implemented. You need to adapt the maxValue definition on the next line.");
    const CGFloat maxValue = isSame<CGFloat, Float64> ? CGFloat(UINT32_MAX)
                                                      : 4294967040.f; // Float32(1 << 32).nextDown
    if (STU_UNLIKELY(!(width >= 0))) {
      width = 0;
    } else if (STU_UNLIKELY(width > maxValue)) {
      width = maxValue;
    }
    if (STU_UNLIKELY(!(height >= 0))) {
      height = 0;
    } else if (STU_UNLIKELY(height > maxValue)) {
      height = maxValue;
    }
    *this = SizeInPixels{Size{static_cast<Int>(width), static_cast<Int>(height)}};
  }
};

/// The images created with `createCGImage()` reference the purgeable data and keep it from being
/// purged. The data automatically becomes purgeable when all CGImages referencing the data have
/// been destroyed (after at least one CGImage has been created or
/// `makePurgeableOnceAllCGImagesAreDestroyed` was called).
/// `createCGImage()` will return a null pointer if the data has been purged.
class PurgeableImage {
public:
  /// Returns null if the image was purged.
  RC<CGImage> createCGImage();

  bool isNonPurgeableUntilNextCGImageIsCreated() const { return hasUnconsumedContentAccessBegin_; }

  void makePurgeableOnceAllCGImagesAreDestroyed();

  bool tryMakeNonPurgeableUntilNextCGImageIsCreated();

  SizeInPixels<UInt32> sizeInPixels() const { return size_; }

  STU_INLINE
  PurgeableImage()
  : data_{}, size_{}, bytesPerRowDiv32_{}, formatOptions_{}, format_{},
    hasUnconsumedContentAccessBegin_{}
  {}

  explicit operator bool() const { return data_ != nullptr; }

  PurgeableImage(CGSize, CGFloat scale, __nullable CGColorRef backgroundColor,
                 STUPredefinedCGImageFormat, STUCGImageFormatOptions,
                 FunctionRef<void(CGContext*)> drawingFunction);

  PurgeableImage(SizeInPixels<UInt32>, CGFloat scale, __nullable CGColorRef backgroundColor,
                 STUPredefinedCGImageFormat, STUCGImageFormatOptions,
                 FunctionRef<void(CGContext*)> drawingFunction);

  STU_INLINE
  PurgeableImage(const PurgeableImage& other)
  : data_{}
  {
    assign(other);
  }
  STU_INLINE
  PurgeableImage& operator=(const PurgeableImage& other) {
    if (this != &other) {
      assign(other);
    }
    return *this;
  }

  STU_INLINE
  PurgeableImage(PurgeableImage&& other) noexcept
  : data_{}
  {
    assign(std::move(other));
  }
  STU_INLINE
  PurgeableImage& operator=(PurgeableImage&& other) {
    if (this != &other) {
      assign(std::move(other));
    }
    return *this;
  }

private:
  template <typename Other>
  STU_INLINE
  void assign(Other&& other) {
    data_ = other.data_;
    if constexpr (isSame<Other&&, const PurgeableImage&>) {
      hasUnconsumedContentAccessBegin_ = false;
    } else {
      static_assert(isOneOf<Other&&, PurgeableImage&&>);
      other.data_ = nil;
      hasUnconsumedContentAccessBegin_ = other.hasUnconsumedContentAccessBegin_;
      other.hasUnconsumedContentAccessBegin_ = false;
    }
    size_ = other.size_;
    bytesPerRowDiv32_ = other.bytesPerRowDiv32_;
    format_ = other.format_;
    formatOptions_ = other.formatOptions_;
  }

  STU_INLINE
  PurgeableImage(NSPurgeableData* data, SizeInPixels<UInt32> size,
                 STUPredefinedCGImageFormat format, STUCGImageFormatOptions formatOptions,
                 size_t bytesPerRow)
  : data_{data}, size_{size}, bytesPerRowDiv32_{narrow_cast<UInt32>(bytesPerRow/32)},
    formatOptions_{formatOptions}, format_{format},
    hasUnconsumedContentAccessBegin_{data != nil}
  {
    STU_DEBUG_ASSERT(0 < bytesPerRow && bytesPerRow%32 == 0);
  }

  NSPurgeableData* data_; // arc
  SizeInPixels<UInt32> size_;
  UInt32 bytesPerRowDiv32_;
  STUCGImageFormatOptions formatOptions_ : 8;
  STUPredefinedCGImageFormat format_;
  bool hasUnconsumedContentAccessBegin_;
};

} // namespace stu_label

template <> struct stu::IsBitwiseMovable<stu_label::PurgeableImage> : stu::True {};
