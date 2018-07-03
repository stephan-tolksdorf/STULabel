// Copyright 2018 Stephan Tolksdorf

#import "Color.hpp"
#import "TextStyle.hpp"
#import "Unretained.hpp"

namespace stu_label {

class TextFrameDrawingOptions {
public:
  bool isFrozen() const { return isFrozen_; }

  void freeze() {
    if (!isFrozen_) {
      isFrozen_ = true;
    }
  }

  void unfreeze_after_copy_initialization() { isFrozen_ = false; }

  STU_INLINE
  void assumeNotFrozen() const { STU_ASSUME(!isFrozen_); }

  STUTextFrameDrawingMode drawingMode() const { return drawingMode_; }
  void setDrawingMode(STUTextFrameDrawingMode drawingMode) {
    checkNotFrozen();
    drawingMode_ = drawingMode;
  }

  Unretained<STUTextHighlightStyle* __nullable> highlightStyle() const { return highlightStyle_; }

  void setHighlightStyle(STUTextHighlightStyle* __unsafe_unretained __nullable style) {
    checkNotFrozen();
    highlightStyle_ = style;
  }


  STUTextRange highlightRange() const {
    if (!hasHighlightTextFrameRange_) {
      return highlightTextRange_;
    } else {
      return STUTextRange{STUTextFrameRangeGetRangeInTruncatedString(highlightTextFrameRange_),
                          STURangeInTruncatedString};
    }
  }

  Optional<STUTextFrameRange> highlightTextFrameRange() const {
    if (hasHighlightTextFrameRange_) {
      return highlightTextFrameRange_;
    }
    return none;
  }

  void setHighlightRange(NSRange range, STUTextRangeType rangeType) {
    checkNotFrozen();
    hasHighlightTextFrameRange_ = false;
    highlightTextRange_ = STUTextRange{range, rangeType};
  }

  void setHighlightRange(STUTextFrameRange range) {
    checkNotFrozen();
    hasHighlightTextFrameRange_ = true;
    highlightTextFrameRange_ = range;
  }

  bool overrideColorsApplyToHighlightedText() const {
    return overrideColorsApplyToHighlightedText_;
  }
  void setOverrideColorsApplyToHighlightedText(bool value) {
    checkNotFrozen();
    overrideColorsApplyToHighlightedText_ = value;
  }

  TextFlags overrideColorFlags(bool textHasLink) const {
    TextFlags flags = overrideTextColor_.textFlags();
    if (textHasLink) {
      flags |= overrideLinkColor_.textFlags();
    }
    return flags;
  }

  TextFlags overrideColorsTextFlagsMask() const { return overrideColorsTextFlagsMask_; }

  ColorRef overrideTextColor() const { return overrideTextColor_; }
  Unretained<UIColor* __nullable> overrideTextUIColor() const { return overrideTextUIColor_; }

  void setOverrideTextColor(UIColor* __unsafe_unretained color) {
    checkNotFrozen();
    overrideTextUIColor_ = color;
    overrideTextColor_ = Color{color};
    setOverrideColorsMaskFlag(detail::everyRunFlag, color != nil);
  }

  ColorRef overrideLinkColor() const { return overrideLinkColor_; }
  Unretained<UIColor* __nullable> overrideLinkUIColor() const { return overrideLinkUIColor_; }

  void setOverrideLinkColor(UIColor* __unsafe_unretained color) {
    checkNotFrozen();
    overrideLinkUIColor_ = color;
    overrideLinkColor_ = Color{color};
    setOverrideColorsMaskFlag(TextFlags::hasLink, color != nil);
  }

private:

  void checkNotFrozen() {
    if (STU_UNLIKELY(isFrozen_)) {
      attemptedMutationOfFrozenObject();
    }
  }

  void attemptedMutationOfFrozenObject();

  void setOverrideColorsMaskFlag(TextFlags flag, bool value) {
    overrideColorsTextFlagsMask_ = (overrideColorsTextFlagsMask_ & ~flag)
                                 | (value ? flag : TextFlags{});
  }

  bool isFrozen_{};
  bool hasHighlightTextFrameRange_{};
  bool overrideColorsApplyToHighlightedText_{true};
  TextFlags overrideColorsTextFlagsMask_{};
  STUTextFrameDrawingMode drawingMode_{};
  union {
    STUTextFrameRange highlightTextFrameRange_;
    STUTextRange highlightTextRange_{NSRange{0, NSUIntegerMax}, STURangeInOriginalString};
  };
  Color overrideTextColor_;
  Color overrideLinkColor_;
  STUTextHighlightStyle* highlightStyle_; // arc
  UIColor* overrideTextUIColor_; // arc
  UIColor* overrideLinkUIColor_; // arc
};

} // stu_label
