#import "STUParagraphStyle.h"

namespace stu_label {

struct ParagraphExtraStyle {
  STUFirstLineOffsetType firstLineOffsetType;
  CGFloat firstLineOffset;
  CGFloat minimumBaselineDistance;
  NSInteger numberOfInitialLines;
  CGFloat initialLinesHeadIndent;
  CGFloat initialLinesTailIndent;
};

}

@interface STUParagraphStyle () {
@package
  stu_label::ParagraphExtraStyle _style;
}
@end


