
#import "STULabel.h"

NS_ASSUME_NONNULL_BEGIN

STU_EXTERN_C_BEGIN

NS_SWIFT_NAME(getter:STUShapedString.length(self:))
size_t STUShapedStringGetLength(STUShapedString *self);

typedef struct NS_REFINED_FOR_SWIFT STUTextFrameWithOrigin {
  STUTextFrame * __unsafe_unretained textFrame;
  CGPoint origin;
  CGFloat displayScale;
} STUTextFrameWithOrigin;

STUTextFrameWithOrigin STULabelGetTextFrameWithOrigin(STULabel *label) NS_REFINED_FOR_SWIFT;

STUTextFrameWithOrigin STULabelLayerGetTextFrameWithOrigin(STULabelLayer *labelLayer)
                         NS_REFINED_FOR_SWIFT;

STUTextFrameWithOrigin STULabelDrawingBlockParametersGetTextFrameWithOrigin(
                          STULabelDrawingBlockParameters *params) NS_REFINED_FOR_SWIFT;

STU_EXTERN_C_END

NS_ASSUME_NONNULL_END
