// Copyright 2017–2018 Stephan Tolksdorf

#import "STULabelPrerenderer.h"

namespace stu_label {
  class LabelPrerenderer;

  namespace detail { void labelPrerendererObjCObjectWasDestroyed(LabelPrerenderer&); }
}

STU_EXTERN_C_BEGIN

@interface STULabelPrerenderer () {
@package
  stu_label::LabelPrerenderer* prerenderer;
}
@end

STULabelPrerenderer* STULabelPrerendererAlloc(Class prerendererClass) NS_RETURNS_RETAINED;

STU_EXTERN_C_END
