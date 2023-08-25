// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextFrameAccessibilityElement.h"

#import "STULabel/STUTextLink-Internal.hpp"

#import "Internal/CoreAnimationUtils.hpp"
#import "Internal/InputClamping.hpp"
#import "Internal/Localized.hpp"
#import "Internal/TextLineSpansPath.hpp"

#include "Internal/DefineUIntOnCatalystToWorkAroundGlobalNamespacePollution.h"

using namespace stu_label;

@class STUTextFrameAccessibilitySubelement;

@interface STUTextFrameAccessibilityElement() {
@package // fileprivatef
  UIView* __weak _accessibilityContainer;
  CGRect _frame;
  __nullable STUTextLinkRangePredicate _linkActivationHandler;
@private
  CGFloat _displayScale;
  NSArray<STUTextFrameAccessibilitySubelement*>* _elements;
  bool _isAccessibilityElement;
  bool _representsUntruncatedText;
  bool _separatesParagraphs;
  bool _separatesLinkElements;
}
@end

namespace stu_label {
  struct InitParams {
    const STUTextFrameAccessibilityElement* textFrameAccessibilityElement;
    const TextFrame& textFrame;
    NSAttributedString* attributedString;
    NSStringRef string;
    bool isTruncatedString;
    bool separateParagraphs;
    bool separateLinkElements;
    TextFrameScaleAndDisplayScale scaleFactors;
    ArrayRef<const TextLineVerticalPosition> verticalPositions;
    Point<CGFloat> textFrameOrigin;
    __nullable STUTextLinkRangePredicate isDraggableLink;
  };
}

@interface STUTextFrameAccessibilitySubelement : UIAccessibilityElement
- (instancetype)initWithParams:(const InitParams&)params
                   stringRange:(NSRange)stringRange
    mutableAttributedSubstring:(nullable NSMutableAttributedString*)mutableAttributedSubstring
                     linkCount:(UInt)linkCount
                 fullRangeLink:(nullable id)linkValue
           fullRangeAttachment:(nullable STUTextAttachment*)attachment
  NS_DESIGNATED_INITIALIZER;

@property (nonatomic) CGRect accessibilityFrameInContainerSpace;

- (instancetype)init NS_UNAVAILABLE;
@end

@implementation STUTextFrameAccessibilitySubelement {
@package // fileprivate
  const STUTextFrameAccessibilityElement* __unsafe_unretained _textFrameElement;
  CGRect _boundsInTextFrame;
@private
  UILabel* _uiLabel;
  id _accessibilityLabel;
  id _linkValue;
  CGPathRef _path;
  UIAccessibilityTraits _accessibilityTraits;
  CGPoint _activationPoint;
  Range<stu::UInt32> _stringRange;
  STUTextRangeType _stringRangeType;
  bool _accessibilityLabelIsAttributed;
  bool _isDraggable;
@protected
  bool _isAccessibilityElement;
}

- (void)dealloc {
  if (_path) {
    CFRelease(_path);
  }
}

@synthesize accessibilityFrameInContainerSpace = _boundsInTextFrame;

- (const STUTextFrameAccessibilityElement*)accessibilityContainer {
  return _textFrameElement;
}
- (void)setAccessibilityContainer:(id)accessibilityContainer {
  STU_CHECK_MSG(accessibilityContainer == nil
                || [accessibilityContainer isKindOfClass:STUTextFrameAccessibilityElement.class],
                "Invalid accessibilityContainer");
  _textFrameElement = (const STUTextFrameAccessibilityElement*)accessibilityContainer;
}

- (BOOL)isAccessibilityElement {
  return _isAccessibilityElement;
}
- (void)setIsAccessibilityElement:(BOOL)isAccessibilityElement {
  _isAccessibilityElement = isAccessibilityElement;
  [super setIsAccessibilityElement:isAccessibilityElement];
}

- (UIAccessibilityTraits)accessibilityTraits {
  return _accessibilityTraits;
}
- (void)setAccessibilityTraits:(UIAccessibilityTraits)accessibilityTraits {
  _accessibilityTraits = accessibilityTraits;
}

- (CGRect)accessibilityFrame {
  if (!_textFrameElement) return _boundsInTextFrame;
  const CGRect frame = _boundsInTextFrame + _textFrameElement->_frame.origin;
  UIView* const view = _textFrameElement->_accessibilityContainer;
  const CGRect result = !view ? frame : UIAccessibilityConvertFrameToScreenCoordinates(frame, view);
  return result;
}
- (void)setAccessibilityFrame:(CGRect __unused)frame {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (nullable UIBezierPath*)accessibilityPath {
  if (!_path) return nil;
  const CGPoint origin = !_textFrameElement ? CGPoint{}
                       : _textFrameElement->_frame.origin;
  UIBezierPath* bezierPath;
  if (origin == CGPoint{}) {
    bezierPath = [UIBezierPath bezierPathWithCGPath:_path];
  } else {
    const CGAffineTransform translation = CGAffineTransformMakeTranslation(origin.x, origin.y);
    const CGPathRef translatedPath = CGPathCreateCopyByTransformingPath(_path, &translation);
    bezierPath = [UIBezierPath bezierPathWithCGPath:translatedPath];
    CFRelease(translatedPath);
  }
  UIView* const view = !_textFrameElement ? nil : _textFrameElement->_accessibilityContainer;
  return !view ? bezierPath : UIAccessibilityConvertPathToScreenCoordinates(bezierPath, view);
}
- (void)setAccessibilityPath:(UIBezierPath* __unused)path {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (CGPoint)accessibilityActivationPoint {
  if (!_textFrameElement) return _activationPoint;
  const CGPoint point = _activationPoint + _textFrameElement->_frame.origin;
  UIView* const view = _textFrameElement.accessibilityContainer;
  const CGPoint result = !view ? point
                        : UIAccessibilityConvertFrameToScreenCoordinates(CGRect{point, {}}, view)
                          .origin;
  return result;
}
- (void)setAccessibilityActivationPoint:(CGPoint __unused)point {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (BOOL)accessibilityActivate {
  if (_linkValue && _textFrameElement) {
    if (_textFrameElement->_linkActivationHandler) {
      const CGPoint point = _activationPoint + _textFrameElement->_frame.origin;
      return _textFrameElement->_linkActivationHandler(STUTextRange{_stringRange, _stringRangeType},
                                                       _linkValue, point);
    }
  }
  return false;
}

- (NSArray<UIAccessibilityLocationDescriptor*>*)accessibilityDragSourceDescriptors {
  if (!_isDraggable || !_textFrameElement) return nil;
  return @[[[UIAccessibilityLocationDescriptor alloc]
              initWithName:localizedForSystemLocale(@"Drag Item")
                     point:_activationPoint + _textFrameElement->_frame.origin
                    inView:_textFrameElement.accessibilityContainer]];
}

- (nullable NSString*)accessibilityLabel {
  return !_accessibilityLabel || !_accessibilityLabelIsAttributed
       ? _accessibilityLabel
       : static_cast<NSAttributedString*>(_accessibilityLabel).string;
}
- (nullable NSAttributedString*)accessibilityAttributedLabel {
  return !_accessibilityLabel || _accessibilityLabelIsAttributed
       ? _accessibilityLabel
       : [[NSAttributedString alloc] initWithString:_accessibilityLabel];
}
- (void)setAccessibilityLabel:(NSString*)accessibilityLabel {
  _accessibilityLabelIsAttributed = false;
  _accessibilityLabel = accessibilityLabel;
}
- (void)setAccessibilityAttributedLabel:(NSAttributedString*)accessibilityAttributedLabel {
  _accessibilityLabelIsAttributed = true;
  _accessibilityLabel = accessibilityAttributedLabel;
}

struct ActivationPoint {
  Float64 x;
  int32_t lineIndex;
  bool isTruncationToken;
};

/// Returns an activation point outside the layout bounds of any truncation token, if possible.
/// @pre !spans.isEmpty()
static ActivationPoint findActivationPoint(const ArrayRef<const TextLineSpan> spans,
                                           const ArrayRef<const TextFrameLine> lines)
{
  for (const TextLineSpan& span : spans) {
    const TextFrameLine& line = lines[span.lineIndex];
    const auto tokenX = line.origin().x + line.tokenXRange();
    Range<Float64> x = span.x;
    if (span.x.start < tokenX.start) {
      x.end = min(x.end, tokenX.start);
    } else if (x.end > tokenX.end) {
      x.start = max(x.start, tokenX.end);
    } else {
      continue;
    }
    return {x.center(), sign_cast(span.lineIndex), false};
  }
  return {spans[0].x.center(), sign_cast(spans[0].lineIndex), true};
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (instancetype)initWithParams:(const InitParams&)params
                   stringRange:(NSRange)stringRange
    mutableAttributedSubstring:(nullable NSMutableAttributedString* __unsafe_unretained)
                                 mutableAttributedSubstring
                     linkCount:(UInt)linkCount
                 fullRangeLink:(nullable __unsafe_unretained id)fullRangeLinkValue
           fullRangeAttachment:(nullable STUTextAttachment* __unsafe_unretained)attachment
{
  // Strip any trailing whitespace ending with a line terminator (to prevent Voice Over from saying
  // "new line".)
  if (stringRange.length != 0) {
    Range<Int> r = sign_cast(Range{stringRange});
    if (isLineTerminator(params.string[r.end - 1])) {
      r.end = params.string.indexOfEndOfLastCodePointWhere(r, isNotIgnorableAndNotWhitespace);
      stringRange.length = sign_cast(r.end) - stringRange.location;
    }
  }
  if (stringRange.length == 0) return nil;
  const TextFrame& tf = params.textFrame;
  const Range<TextFrameIndex> range = params.isTruncatedString
                                    ? tf.range(RangeInTruncatedString{stringRange})
                                    : tf.range(RangeInOriginalString{stringRange});
  TempArray<TextLineSpan> spans = tf.lineSpans(range);
  if (spans.isEmpty()) return nil;
  self = [super initWithAccessibilityContainer:params.textFrameAccessibilityElement];
  if (!self) return self;
  _textFrameElement = params.textFrameAccessibilityElement;
  _linkValue = fullRangeLinkValue;
  _stringRange = narrow_cast<Range<stu::UInt32>>(stringRange);
  _stringRangeType = params.isTruncatedString ? STURangeInTruncatedString
                                              : STURangeInOriginalString;

  const auto lines = tf.lines();

  ActivationPoint ap = findActivationPoint(spans, lines);
  ap.x *= tf.textScaleFactor;

  _activationPoint = CGPoint{narrow_cast<CGFloat>(ap.x),
                             narrow_cast<CGFloat>(params.verticalPositions[ap.lineIndex]
                                                  .y().center())};
  STU_DISABLE_LOOP_UNROLL
  for (auto& span : spans) {
    span.x *= tf.textScaleFactor;
  }
  const TextLineSpansPathBounds bounds = calculateTextLineSpansPathBounds(spans,
                                                                          params.verticalPositions);
  _boundsInTextFrame = narrow_cast<CGRect>(bounds.rect);

  if (bounds.pathExtendedToCommonHorizontalTextLineBoundsIsRect == false) {
    CGPath* const path = CGPathCreateMutable();
    _path = path;
    addLineSpansPath(*path, spans, params.verticalPositions, ShouldFillTextLineGaps{true},
                     ShouldExtendTextLinesToCommonHorizontalBounds{true});
  }

  if (!attachment){
    _accessibilityTraits = UIAccessibilityTraitStaticText;
    if (fullRangeLinkValue) {
      _accessibilityTraits |= UIAccessibilityTraitLink;
    }
    NSAttributedString* label = mutableAttributedSubstring
                                ?: [params.attributedString attributedSubstringFromRange:stringRange];
    if (fullRangeLinkValue || NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_9_x_Max) {
      NSMutableAttributedString* const mutableLabel = mutableAttributedSubstring
                                                      ?: [label mutableCopy];
      [mutableLabel removeAttribute:NSLinkAttributeName range:NSRange{0, stringRange.length}];
      label = mutableLabel;
    }
    label = [[label stu_attributedStringByReplacingSTUAttachmentsWithStringRepresentations] copy];
    { // Copy UIAccessibilitySpeechAttributeLanguage attribute to accessibilityLanguage property
      // if the attribute is effective over the full string range.
      const NSUInteger labelLength = label.length;
      NSRange effectiveRange;
      NSString* const language = [label attribute:UIAccessibilitySpeechAttributeLanguage
                                          atIndex:0 longestEffectiveRange:&effectiveRange
                                          inRange:NSRange{0, labelLength}];
      if (language && effectiveRange == NSRange{0, labelLength}) {
        self.accessibilityLanguage = language;
      }
    }
    if (linkCount > 0 && !fullRangeLinkValue && !TARGET_OS_SIMULATOR) {
      // We want VoiceOver to announce the presence of links when reading text, like it does for
      // UILabel and UITextView. Unfortunately, UIAccessibility doesn't do this for normal
      // accessibilityAttributedLabel values with NSLinkAttributeName attributes and there's no
      // other public API for this purpose. To work around this limitation we let an UILabel
      // create the appropriately attributed accessibility label for us.

      // In iOS 11.3, -[UILabelAccessibility _accessibilityLabel:] started to aggressively cache the
      // accessibility label by unretained pointer address of the UILabel instance, which forces us
      // to create fresh UILabel instances for every accessibility element with embedded links and
      // to keep the instance alive for the lifetime of the element. We don't do this on the
      // simulator to conserve resources in automated UI tests.
      _uiLabel = [[UILabel alloc] init];
      _uiLabel.attributedText = label;
      if (@available(iOS 11, tvOS 11, *)) {
        _accessibilityLabelIsAttributed = true;
        _accessibilityLabel = _uiLabel.accessibilityAttributedLabel;
      } else {
        _accessibilityLabel = _uiLabel.accessibilityLabel;
      }
    } else {
      if (@available(iOS 11, tvOS 11, *)) {
        _accessibilityLabelIsAttributed = true;
        _accessibilityLabel = label;
      } else {
        _accessibilityLabel = label.string;
      }
    }
  } else { // attachment
    UIAccessibilityTraits traits = attachment.accessibilityTraits;
    if (!(traits & (UIAccessibilityTraitStaticText | UIAccessibilityTraitButton))) {
      traits |= UIAccessibilityTraitImage;
    }
    if (fullRangeLinkValue && !(traits & UIAccessibilityTraitButton)) {
      traits |= UIAccessibilityTraitLink;
    }
    _accessibilityTraits = traits;
    if (@available(iOS 11, tvOS 11, *)) {
      if (NSAttributedString* const label = attachment.accessibilityAttributedLabel) {
        _accessibilityLabelIsAttributed = true;
        _accessibilityLabel = label;
      }
      if (NSAttributedString* const hint = attachment.accessibilityAttributedHint) {
        self.accessibilityAttributedHint = hint;
      }
      if (NSAttributedString* const value = attachment.accessibilityAttributedValue) {
        self.accessibilityAttributedValue = value;
      }
    } else {
      if (NSString* const label = attachment.accessibilityLabel) {
        _accessibilityLabel = label;
      }
      if (NSString* const hint = attachment.accessibilityHint) {
        self.accessibilityHint = hint;
      }
      if (NSString* const value = attachment.accessibilityValue) {
        self.accessibilityValue = value;
      }
    }
    if (NSString* const language = attachment.accessibilityLanguage
                                   ?: [params.attributedString
                                        attribute:UIAccessibilitySpeechAttributeLanguage
                                         atIndex:stringRange.location effectiveRange:nil])
    {
      self.accessibilityLanguage = language;
    }
  }
  if (params.isDraggableLink
      && fullRangeLinkValue
      && (!ap.isTruncationToken
          || [fullRangeLinkValue isEqual: [tf.attributesAt(range.start)
                                             objectForKey:NSLinkAttributeName]])
      && params.isDraggableLink(STUTextRange{stringRange,
                                             params.isTruncatedString ? STURangeInTruncatedString
                                                                      : STURangeInOriginalString},
                                fullRangeLinkValue,
                                _activationPoint + params.textFrameOrigin))
  {
    _isDraggable = true;
  }
  return self;
}

@end

@interface STUTextFrameAccessibilityRotorLinkElement : STUTextFrameAccessibilitySubelement
@end
@implementation STUTextFrameAccessibilityRotorLinkElement

- (instancetype)initWithParams:(const InitParams&)params
                   stringRange:(NSRange)stringRange
    mutableAttributedSubstring:(nullable NSMutableAttributedString* __unsafe_unretained)
                                 mutableAttributedSubstring
                     linkCount:(UInt)linkCount
                 fullRangeLink:(nullable __unsafe_unretained id)linkValue
           fullRangeAttachment:(nullable STUTextAttachment* __unsafe_unretained)attachment
{
  if ((self = [super initWithParams:params
                        stringRange:stringRange
         mutableAttributedSubstring:mutableAttributedSubstring
                          linkCount:(UInt)linkCount
                      fullRangeLink:linkValue
                fullRangeAttachment:attachment]))
  {
    _isAccessibilityElement = false;
  }
  return self;
}

- (NSString*)accessibilityLabel {
  if (!_isAccessibilityElement) return nil;
  return [super accessibilityLabel];
}

- (NSAttributedString*)accessibilityAttributedLabel {
  if (!_isAccessibilityElement) return nil;
  return [super accessibilityAttributedLabel];
}

- (void)accessibilityElementDidLoseFocus {
 self.isAccessibilityElement = false;
}

@end

static UIAccessibilityCustomRotor* createLinkRotorForAccessibilityContainer(
                                     const NSObject* container, Range<UInt> elementRange)
                                   NS_RETURNS_RETAINED API_AVAILABLE(ios(10.0), tvos(10.0))
{
  STU_ASSERT(!elementRange.isEmpty());
  const NSObject* __weak weakContainer = container;
  __block UInt currentIndex = elementRange.start;
  const UIAccessibilityCustomRotorSearch searchBlock =
     ^UIAccessibilityCustomRotorItemResult* __nullable
       (UIAccessibilityCustomRotorSearchPredicate* predicate)
  {
    NSArray* const elements = weakContainer.accessibilityElements;
    if (elements.count < elementRange.end) return nil;
    UInt index = currentIndex;
    NSObject* currentElement = elements[index];
    if (predicate.currentItem.targetElement == currentElement) {
      if (predicate.searchDirection == UIAccessibilityCustomRotorDirectionNext) {
        index += 1;
      } else {
        index -= 1; // May wrap around.
      }
      if (!elementRange.contains(index)) {
        return nil;
      }
    } else {
      index = elementRange.start;
    }
    currentIndex = index;
    currentElement = elements[index];
    currentElement.isAccessibilityElement = true;
    return [[UIAccessibilityCustomRotorItemResult alloc] initWithTargetElement:currentElement
                                                                   targetRange:nil];
  };

  if (@available(iOS 11, tvOS 11, *)) {
    return  [[UIAccessibilityCustomRotor alloc]
               initWithSystemType:UIAccessibilityCustomSystemRotorTypeLink
                  itemSearchBlock:searchBlock];
  } else {
    auto* const rotor = [[UIAccessibilityCustomRotor alloc]
                          initWithName:localizedForSystemLocale(@"Links")
                       itemSearchBlock:searchBlock];
    rotor.accessibilityLanguage = systemLocalizationLanguage();
    return rotor;
  }
}



@implementation STUTextFrameAccessibilityElement

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (instancetype)initWithAccessibilityContainer:(UIView*)view
                                     textFrame:(NS_VALID_UNTIL_END_OF_SCOPE STUTextFrame*)textFrame
                        originInContainerSpace:(CGPoint)originInContainerSpace
                                  displayScale:(CGFloat)displayScale
                      representUntruncatedText:(bool)representUntruncatedText
                            separateParagraphs:(bool)separateParagraphs
                          separateLinkElements:(bool)separateLinkElements
                               isDraggableLink:(__nullable STUTextLinkRangePredicate)isDraggableLink
                         linkActivationHandler:(__nullable STUTextLinkRangePredicate)
                                                 linkActivationHandler
{
  STU_CHECK(is_main_thread());
  self = [super initWithAccessibilityContainer:view];
  if (!self) return self;
  _accessibilityContainer = view;
  _isAccessibilityElement = false; // Since this element has subelements.
  _frame = CGRect{clampPointInput(originInContainerSpace), CGSize{}};
  _linkActivationHandler = linkActivationHandler;
  _displayScale = clampDisplayScaleInput(displayScale);
  _representsUntruncatedText = representUntruncatedText;
  _separatesParagraphs = separateParagraphs;
  _separatesLinkElements = separateLinkElements;
  if (NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_9_x_Max) {
    separateLinkElements = true; // There's no way to provide a custom link rotor on iOS 9.
  }
  if (!textFrame) {
    _elements = @[];
    return self;
  }
  ThreadLocalArenaAllocator::InitialBuffer<4096> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};
  const TextFrame& tf = textFrameRef(textFrame);
  const auto scaleFactors = TextFrameScaleAndDisplayScale{tf, displayScale};
  const auto lines = tf.lines();
  TempArray<TextLineVerticalPosition> verticalPositions{uninitialized, Count{lines.count()}, alloc};
  for (Int i = 0; i < lines.count(); ++i) {
    const TextFrameLine& line = lines[i];
    TextLineVerticalPosition vp = textLineVerticalPosition(line, scaleFactors.displayScale);
    vp.scale(scaleFactors.textFrameScale);
    verticalPositions[i] = vp;
  }
  NSAttributedString* __unsafe_unretained const attributedString =
    representUntruncatedText ? tf.originalAttributedString
                             : tf.truncatedAttributedString().unretained;
  if (@available(iOS 11, *)) {
  } else {
    isDraggableLink = nil;
  }
  const InitParams params = {
    .textFrameAccessibilityElement = self,
    .textFrame = tf,
    .attributedString = attributedString,
    .string = NSStringRef{attributedString.string},
    .isTruncatedString = !representUntruncatedText,
    .separateParagraphs = separateParagraphs,
    .separateLinkElements = separateLinkElements,
    .scaleFactors = scaleFactors,
    .verticalPositions = verticalPositions,
    .textFrameOrigin = originInContainerSpace,
    .isDraggableLink = isDraggableLink
  };
  NSMutableArray<STUTextFrameAccessibilitySubelement*>* const elements = [[NSMutableArray alloc]
                                                                            init];
  if (!separateParagraphs) {
    const Range<Int> fullRange = representUntruncatedText ? tf.rangeInOriginalString()
                                                          : tf.rangeInTruncatedString();
    addAccessibilityElementsForRange(params, Range<UInt>{fullRange}, elements);
  } else {
    for (const TextFrameParagraph& para : tf.paragraphs()) {
      const Range<Int> range = representUntruncatedText ? para.rangeInOriginalString
                                                        : para.rangeInTruncatedString;
      addAccessibilityElementsForRange(params, Range<UInt>{range}, elements);
    }
  }
  stu_label::Rect<CGFloat> bounds = {};
  for (STUTextFrameAccessibilitySubelement* const subelement in elements) {
    bounds = bounds.convexHull(subelement.accessibilityFrameInContainerSpace);
  }
  _frame.size = CGSize{bounds.x.end, bounds.y.end};
  _elements = [elements copy];
  return self;
}

- (void)dealloc {
  for (STUTextFrameAccessibilitySubelement* e in self->_elements) {
    e->_textFrameElement = nil;
  }
}

- (UIView*)accessibilityContainer {
  return _accessibilityContainer;
}
- (void)setAccessibilityContainer:(nullable id)accessibilityContainer {
  STU_CHECK_MSG(accessibilityContainer == nil || [accessibilityContainer isKindOfClass:UIView.class],
                "The accessibilityContainer of a STUTextFrameAccessibilityElement must be a UIView");
  _accessibilityContainer = accessibilityContainer;
  [super setAccessibilityContainer:accessibilityContainer];
}

- (BOOL)isAccessibilityElement {
  return _isAccessibilityElement;
}
- (void)setIsAccessibilityElement:(BOOL)isAccessibilityElement {
  _isAccessibilityElement = isAccessibilityElement;
}

- (NSArray<STUTextFrameAccessibilitySubelement*>*)accessibilityElements {
  return _elements;
}
- (void)setAccessibilityElements:(NSArray*)elements {
  if (elements == _elements) return;
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

@synthesize accessibilityFrameInContainerSpace = _frame;

- (CGPoint)textFrameOriginInContainerSpace {
  return _frame.origin;
}
- (void)setTextFrameOriginInContainerSpace:(CGPoint)origin {
  _frame.origin = origin;
}

- (CGRect)accessibilityFrame {
  UIView* const view = _accessibilityContainer;
  return !view ? _frame : UIAccessibilityConvertFrameToScreenCoordinates(_frame, view);
}
- (void)setAccessibilityFrame:(CGRect __unused)frame {
  [self doesNotRecognizeSelector:_cmd];
  __builtin_trap();
}

- (bool)representsUntruncatedText { return _representsUntruncatedText; }
- (bool)separatesParagraphs { return _separatesParagraphs; }
- (bool)separatesLinkElements { return _separatesLinkElements; }

static NSRange trimStringRange(const NSStringRef& string, const NSRange nsRange) {
  Range<Int> range{nsRange};
  range.start = string.indexOfFirstCodePointWhere(range, isNotIgnorableAndNotWhitespace);
  if (!range.isEmpty()) {
    range.end = string.indexOfEndOfLastCodePointWhere(range, isNotIgnorableAndNotWhitespace);
  }
  return Range<UInt>{range};
}

STU_NO_INLINE
static void addElementsForRangeThatMayContainLinks(
              const InitParams& params,
              const NSRange stringRange,
              NSMutableArray<STUTextFrameAccessibilitySubelement*>* __unsafe_unretained const array)
{
  {
    const NSRange trimmedStringRange = trimStringRange(params.string, stringRange);
    if (trimmedStringRange.length == 0) return;
    NSRange firstRange;
    const id linkValue = [params.attributedString attribute:NSLinkAttributeName
                                                    atIndex:trimmedStringRange.location
                                      longestEffectiveRange:&firstRange inRange:trimmedStringRange];
    if (firstRange == trimmedStringRange) {
      if (auto* const e = [[STUTextFrameAccessibilitySubelement alloc]
                             initWithParams:params
                               stringRange:linkValue ? trimmedStringRange : stringRange
                mutableAttributedSubstring:nil
                                 linkCount:linkValue ? 1 : 0
                             fullRangeLink:linkValue
                       fullRangeAttachment:nil])
      {
        [array addObject:e];
      }
      return;
    }
  }

  const bool createRotorLinks = NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max;

  const UInt index = array.count;
  NSMutableAttributedString* __block mutableSubtring = nil;
  [params.attributedString enumerateAttribute:NSLinkAttributeName inRange:stringRange
                                      options:0 // We need the longest effective range.
                                   usingBlock:^(id linkValue, NSRange linkRange, BOOL*)
  {
    if (!linkValue) return;
    if (STUTextFrameAccessibilitySubelement* const linkElement =
          [[(createRotorLinks ? STUTextFrameAccessibilityRotorLinkElement.class
                              : STUTextFrameAccessibilitySubelement.class) alloc]
             initWithParams:params
                stringRange:linkRange
 mutableAttributedSubstring:nil
                  linkCount:1
              fullRangeLink:linkValue
        fullRangeAttachment:nil])
    {
      [array addObject:linkElement];
      return;
    }
    if (!mutableSubtring) {
      mutableSubtring = [[NSMutableAttributedString alloc]
                           initWithAttributedString:[params.attributedString
                                                       attributedSubstringFromRange:stringRange]];
    }
    [mutableSubtring removeAttribute:NSLinkAttributeName
                               range:Range{linkRange} - stringRange.location];
  }];
  const UInt linkCount = array.count - index;
  auto* const textElement = [[STUTextFrameAccessibilitySubelement alloc]
                               initWithParams:params
                                  stringRange:stringRange
                   mutableAttributedSubstring:mutableSubtring
                                    linkCount:linkCount
                                fullRangeLink:nil
                          fullRangeAttachment:nil];
  if (!textElement) {
    STU_DEBUG_ASSERT(linkCount == 0);
    return;
  }
  if (linkCount == 0) {
    [array addObject:textElement];
    return;
  }
  [array insertObject:textElement atIndex:index];
  if (createRotorLinks) {
  STU_DISABLE_CLANG_WARNING("-Wunguarded-availability")
    textElement.accessibilityCustomRotors =
      @[createLinkRotorForAccessibilityContainer(params.textFrameAccessibilityElement,
                                                 range(index + 1, Count{linkCount}))];
  STU_REENABLE_CLANG_WARNING
  }
}

static void forEachRangeSeparatedByAccessibleAttachments(
              NSAttributedString* __unsafe_unretained const attributedString,
              const Range<UInt> fullRange,
              const FunctionRef<void(Range<UInt>, STUTextAttachment* __nullable)> body)
{
  __block UInt start = fullRange.start;
  [attributedString enumerateAttribute:STUAttachmentAttributeName inRange:fullRange
                               options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                            usingBlock:^(id value, NSRange attribRange, BOOL*)
  {
    if (!value) return;
    STUTextAttachment* const attachment = value;
    if (!attachment.isAccessibilityElement) return;
    if (start < attribRange.location) {
      body(Range{start, attribRange.location}, nil);
    }
    // Iterate over the attachment range char by char.
    for (const auto i : Range{attribRange}.iter()) {
      body(Range{i, i + 1}, attachment);
    }
    start = Range{attribRange}.end;
  }];
  if (start < fullRange.end) {
    body(Range{start, fullRange.end}, nil);
  }
}

STU_NO_INLINE
static void addAccessibilityElementsForRange(
              const InitParams& params, const Range<UInt> fullRange,
              NSMutableArray<STUTextFrameAccessibilitySubelement*>* __unsafe_unretained const array)
{
  if (!params.separateLinkElements) {
    forEachRangeSeparatedByAccessibleAttachments(params.attributedString, fullRange,
      [&](const Range<UInt> range,
          STUTextAttachment* __unsafe_unretained __nullable const attachment)
    {
      if (!attachment) {
        addElementsForRangeThatMayContainLinks(params, range, array);
        return;
      }
      STU_DEBUG_ASSERT(range.count() == 1);
      const id linkValue = [params.attributedString attribute:NSLinkAttributeName
                                                      atIndex:range.start effectiveRange:nil];
      if (auto* const e = [[STUTextFrameAccessibilitySubelement alloc]
                             initWithParams:params
                                stringRange:range
                 mutableAttributedSubstring:nil
                                  linkCount:0
                              fullRangeLink:linkValue
                        fullRangeAttachment:attachment])
      {
        [array addObject:e];
      }
    });
    return;
  }
  [params.attributedString enumerateAttribute:NSLinkAttributeName inRange:fullRange
                                      options:0 // We want the longest effective range.
                                   usingBlock:^(const __unsafe_unretained __nullable id linkValue,
                                                const NSRange attribRange, BOOL*)
  {
    forEachRangeSeparatedByAccessibleAttachments(params.attributedString, attribRange,
      [&](Range<UInt> subrange, STUTextAttachment* __unsafe_unretained __nullable const attachment)
    {
      if (!attachment) {
        const NSRange trimmedRange = trimStringRange(params.string, subrange);
        if (trimmedRange.length == 0) return;
        if (linkValue) {
          subrange = trimmedRange;
        }
      }
      if (auto* const e = [[STUTextFrameAccessibilitySubelement alloc]
                             initWithParams:params
                                stringRange:subrange
                 mutableAttributedSubstring:nil
                                  linkCount:linkValue ? 1 : 0
                              fullRangeLink:linkValue
                        fullRangeAttachment:attachment])
      {
        [array addObject:e];
      }
    });
  }];
}

@end

