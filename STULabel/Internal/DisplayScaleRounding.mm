// Copyright 2017–2018 Stephan Tolksdorf

#import "DisplayScaleRounding.hpp"

#import "STULabel/STUMainScreenProperties.h"

namespace stu_label {


Optional<DisplayScale> DisplayScale::create(const CGFloat scale) {
  if (!(scale > 0) || scale > maxValue<Float32>) return none;
  DisplayScale result{scale, unchecked};
  if (result.scale_f32_ == 0 || !(result.inverseScale_f32_ > 0)) return none;
  return result;
}

DisplayScale DisplayScale::createOrIfInvalidGetMainSceenScale(const CGFloat scale) {
  if (Optional<DisplayScale> displayScale = DisplayScale::create(scale)) {
    return DisplayScale{*displayScale};
  }
  return DisplayScale{*DisplayScale::create(stu_mainScreenScale())};
}

}
