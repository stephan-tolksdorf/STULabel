// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelPrerenderer-Internal.hpp"

#import "Internal/LabelPrerenderer.hpp"

using namespace stu;
using namespace stu_label;

@implementation STULabelPrerenderer (Interface)

- (bool)isFrozen {
  return prerenderer->isFrozen();
}

- (nullable NSAttributedString*)attributedText {
  return prerenderer->attributedString();
}
- (void)setAttributedText:(nullable NSAttributedString* __unsafe_unretained)attributedString {
  prerenderer->setAttributedString(attributedString);
}

- (STULabelDefaultTextAlignment)defaultTextAlignment {
  return prerenderer->defaultTextAlignment();
}
- (void)setDefaultTextAlignment:(STULabelDefaultTextAlignment)defaultTextAlignment {
  prerenderer->setDefaultTextAlignment(defaultTextAlignment);
}

- (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirection {
  return prerenderer->userInterfaceLayoutDirection();
}
- (void)setUserInterfaceLayoutDirection:(UIUserInterfaceLayoutDirection)userInterfaceLayoutDirection {
  prerenderer->setUserInterfaceLayoutDirection(userInterfaceLayoutDirection);
}

- (bool)hasShapedText { return prerenderer->hasShapedString(); }

- (STUShapedString*)shapedText {
  return prerenderer->shapedString().unretained;
}
- (void)setShapedText:(nullable STUShapedString*)shapedString {
  prerenderer->setShapedString(shapedString);
}

- (CGSize)size { return prerenderer->size(); }

- (STULabelPrerendererSizeOptions)sizeOptions { return prerenderer->sizeOptions(); }

- (UIEdgeInsets)contentInsets { return prerenderer->contentInsets(); }

- (STUDirectionalEdgeInsets)directionalContentInsets {
  return prerenderer->directionalContentInsets();
}

- (void)setWidth:(CGFloat)width maxHeight:(CGFloat)maxHeight
   contentInsets:(UIEdgeInsets)contentInsets
{
  prerenderer->setSizeAndContentInsets(CGSize{width, maxHeight}, contentInsets,
                                       STUShrinkLabelHeightToFit);
}
- (void)setWidth:(CGFloat)width maxHeight:(CGFloat)maxHeight
   directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets
{
  prerenderer->setSizeAndContentInsets(CGSize{width, maxHeight}, contentInsets,
                                       STUShrinkLabelHeightToFit);
}

- (void)setMaxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight
      contentInsets:(UIEdgeInsets)contentInsets
{
  prerenderer->setSizeAndContentInsets(CGSize{maxWidth, maxHeight}, contentInsets,
                                       STUShrinkLabelWidthToFit | STUShrinkLabelHeightToFit);
}
- (void)setMaxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight
      directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets
{
  prerenderer->setSizeAndContentInsets(CGSize{maxWidth, maxHeight}, contentInsets,
                                       STUShrinkLabelWidthToFit | STUShrinkLabelHeightToFit);
}

- (void)setSize:(CGSize)size contentInsets:(UIEdgeInsets)contentInsets
        options:(STULabelPrerendererSizeOptions)options
{
  prerenderer->setSizeAndContentInsets(size, contentInsets, options);
}
- (void)setSize:(CGSize)size directionalContentInsets:(STUDirectionalEdgeInsets)contentInsets
        options:(STULabelPrerendererSizeOptions)options
{
  prerenderer->setSizeAndContentInsets(size, contentInsets, options);
}

- (CGFloat)displayScale {
  return prerenderer->params().displayScale();
}
- (void)setDisplayScale:(CGFloat)scale {
  prerenderer->setDisplayScale(scale);
}

- (STULabelVerticalAlignment)verticalAlignment {
  return prerenderer->params().verticalAlignment;
}
- (void)setVerticalAlignment:(STULabelVerticalAlignment)verticalAlignment {
  prerenderer->setVerticalAlignment(verticalAlignment);
}

- (void)setTextFrameOptions:(nullable STUTextFrameOptions*)textFrameOptions {
  prerenderer->setTextFrameOptions(textFrameOptions);
}

- (STUTextLayoutMode)textLayoutMode {
  return prerenderer->textLayoutMode();
}
- (void)setTextLayoutMode:(STUTextLayoutMode)textLayoutMode {
  prerenderer->setTextLayoutMode(textLayoutMode);
}

- (NSInteger)maximumNumberOfLines {
  return prerenderer->maxLineCount();
}
- (void)setMaximumNumberOfLines:(NSInteger)maximumNumberOfLines {
  prerenderer->setMaxLineCount(maximumNumberOfLines);
}

- (STULastLineTruncationMode)lastLineTruncationMode {
  return prerenderer->lastLineTruncationMode();
}
- (void)setLastLineTruncationMode:(STULastLineTruncationMode)lastLineTruncationMode {
  prerenderer->setLastLineTruncationMode(lastLineTruncationMode);
}

- (nullable NSAttributedString*)truncationToken {
  return prerenderer->truncationToken();
}
- (void)setTruncationToken:(nullable NSAttributedString* __unsafe_unretained)truncationToken {
  prerenderer->setTruncationToken(truncationToken);
}

- (nullable STUTruncationRangeAdjuster)truncationRangeAdjuster {
  return prerenderer->truncationRangeAdjuster();
}
- (void)setTruncationRangeAdjuster:(nullable STUTruncationRangeAdjuster __unsafe_unretained)finder {
  prerenderer->setTruncationRangeAdjuster(finder);
}

- (CGFloat)minimumTextScaleFactor {
  return prerenderer->minTextScaleFactor();
}
- (void)setMinimumTextScaleFactor:(CGFloat)minimumTextScaleFactor {
  prerenderer->setMinTextScaleFactor(minimumTextScaleFactor);
}

- (CGFloat)textScaleFactorStepSize {
  return prerenderer->textScaleFactorStepSize();
}
- (void)setTextScaleFactorStepSize:(CGFloat)textScaleFactorStepSize {
  prerenderer->setTextScaleFactorStepSize(textScaleFactorStepSize);
}

- (STUBaselineAdjustment)textScalingBaselineAdjustment {
  return prerenderer->textScalingBaselineAdjustment();
}
- (void)setTextScalingBaselineAdjustment:(STUBaselineAdjustment)baselineAdjustment {
  prerenderer->setTextScalingBaselineAdjustment(baselineAdjustment);
}

- (nullable STULastHyphenationLocationInRangeFinder)lastHyphenationLocationInRangeFinder {
  return prerenderer->lastHyphenationLocationInRangeFinder();
}
- (void)setLastHyphenationLocationInRangeFinder:
          (nullable STULastHyphenationLocationInRangeFinder __unsafe_unretained)finder
{
  prerenderer->setLastHyphenationLocationInRangeFinder(finder);
}

- (nullable CGColorRef)backgroundColor {
  return prerenderer->params().backgroundColor();
}
- (void)setBackgroundColor:(nullable CGColorRef)backgroundColor {
  prerenderer->setBackgroundColor(backgroundColor);
}

- (bool)isHighlighted {
  return prerenderer->params().isHighlighted();
}
- (void)setHighlighted:(bool)highlighted {
  prerenderer->setIsHighlighted(highlighted);
}

- (nullable STUTextHighlightStyle*)highlightStyle {
  return prerenderer->params().highlightStyle().unretained;
}
- (void)setHighlightStyle:(nullable STUTextHighlightStyle* __unsafe_unretained)highlightStyle {
  prerenderer->setHighlightStyle(highlightStyle);
}

- (STUTextRange)highlightRange {
  return prerenderer->params().highlightRange();
}
- (void)setHighlightRange:(STUTextRange)highlightRange {
  prerenderer->setHighlightRange(highlightRange.range, highlightRange.type);
}
- (void)setHighlightRange:(NSRange)range type:(STUTextRangeType)rangeType {
  prerenderer->setHighlightRange(range, rangeType);
}

- (bool)overrideColorsApplyToHighlightedText {
  return prerenderer->params().overrideColorsApplyToHighlightedText();
}
- (void)setOverrideColorsApplyToHighlightedText:(bool)overrideColorsApplyToHighlightedText {
  prerenderer->setOverrideColorsApplyToHighlightedText(overrideColorsApplyToHighlightedText);
}

- (nullable UIColor*)overrideTextColor  {
  return prerenderer->params().overrideTextColor().unretained;
}
- (void)setOverrideTextColor:(nullable UIColor* __unsafe_unretained)overrideTextColor {
  prerenderer->setOverrideTextColor(overrideTextColor);
}

- (nullable UIColor*)overrideLinkColor  {
  return prerenderer->params().overrideLinkColor().unretained;
}
- (void)setOverrideLinkColor:(nullable UIColor* __unsafe_unretained)overrideLinkColor {
  prerenderer->setOverrideLinkColor(overrideLinkColor);
}

- (nullable STULabelDrawingBlock)drawingBlock {
  return prerenderer->params().drawingBlock;
}
- (void)setDrawingBlock:(nullable STULabelDrawingBlock __unsafe_unretained)drawingBlock {
  prerenderer->setDrawingBlock(drawingBlock);
}

- (STULabelDrawingBlockColorOptions)drawingBlockColorOptions {
  return prerenderer->params().drawingBlockColorOptions;
}
- (void)setDrawingBlockColorOptions:(STULabelDrawingBlockColorOptions)colorOptions {
  prerenderer->setDrawingBlockColorOptions(colorOptions);
}

- (STULabelDrawingBounds)drawingBlockImageBounds {
  return prerenderer->params().drawingBlockImageBounds;
}
- (void)setDrawingBlockImageBounds:(STULabelDrawingBounds)drawingBounds {
  prerenderer->setDrawingBlockImageBounds(drawingBounds);
}

- (bool)clipsContentToBounds {
  return prerenderer->params().clipsContentToBounds;
}
- (void)setClipsContentToBounds:(bool)clipsContentToBounds {
  prerenderer->setClipsContentToBounds(clipsContentToBounds);
}

- (bool)neverUsesGrayscaleBitmapFormat {
  return prerenderer->params().neverUseGrayscaleBitmapFormat;
}
- (void)setNeverUsesGrayscaleBitmapFormat:(bool)neverUsesGrayscaleBitmapFormat {
  prerenderer->setNeverUsesGrayscaleBitmapFormat(neverUsesGrayscaleBitmapFormat);
}

- (bool)neverUsesExtendedRGBBitmapFormat {
  return prerenderer->params().neverUsesExtendedRGBBitmapFormat;
}
- (void)setNeverUsesExtendedRGBBitmapFormat:(bool)neverUsesExtendedRGBBitmapFormat {
  prerenderer->setNeverUsesExtendedRGBBitmapFormat(neverUsesExtendedRGBBitmapFormat);
}

- (bool)releasesShapedStringAfterRendering {
  return prerenderer->params().releasesShapedStringAfterRendering;
}
- (void)setReleasesShapedStringAfterRendering:(bool)releasesShapedStringAfterRendering {
  prerenderer->setReleasesShapedStringAfterRendering(releasesShapedStringAfterRendering);
}

- (bool)releasesTextFrameAfterRendering {
  return prerenderer->params().releasesTextFrameAfterRendering;
}
- (void)setReleasesTextFrameAfterRendering:(bool)releasesTextFrameAfterRendering {
  prerenderer->setReleasesTextFrameAfterRendering(releasesTextFrameAfterRendering);
}

- (bool)hasLayoutInfo { return prerenderer->hasLayoutInfo(); }

- (STULabelLayoutInfo)layoutInfo { return prerenderer->layoutInfo(); }

- (CGSize)sizeThatFits { return prerenderer->sizeThatFits(); }

- (bool)tryGetSizeThatFits:(nullable CGSize*)outSizeThatFits
                layoutInfo:(nullable STULabelLayoutInfo*)outLayoutInfo
{
  return prerenderer->tryGetSizeThatFitsAndLayoutInfo(outSizeThatFits, outLayoutInfo);
}

- (STUTextLinkArray*)links { return prerenderer->links().unretained; }

- (bool)hasTextFrame { return prerenderer->hasTextFrame(); }

- (STUTextFrame*)textFrame { return prerenderer->textFrame().unretained; }

- (void)render { prerenderer->render(); }

- (void)renderAsync {
  prerenderer->renderAsyncOnQueue(nullptr);
}

- (void)renderAsyncOnQueue:(nullable dispatch_queue_t)queue {
  prerenderer->renderAsyncOnQueue(queue);
}

- (void)renderUsingScheduler:(nonnull STU_NOESCAPE STULabelRenderTaskSchedulerBlock)scheduler {
  prerenderer->renderUsingScheduler(scheduler);
}

@end

