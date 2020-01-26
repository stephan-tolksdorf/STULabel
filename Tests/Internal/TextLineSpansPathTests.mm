// Copyright 2017–2018 Stephan Tolksdorf

#import "TextLineSpansPath.hpp"

#import "STUImageUtils.h"

#import "Equal.hpp"
#import "Rect.hpp"

#import "stu/Vector.hpp"

#import "SnapshotTestCase.h"

using namespace stu;
using namespace stu_label;

using SRect = stu_label::Rect<CGFloat>;

static RC<CGPath> createMutableCGPath() {
  return {CGPathCreateMutable(), ShouldIncrementRefCount{false}};
}

static Vector<Vector<CGPoint>> getLinearSubpaths(CGPath& path) {
  Vector<Vector<CGPoint>> subpaths;
  struct State {
    Vector<Vector<CGPoint>>& subpaths;
    bool lastSubpathIsClosed;
  } state{subpaths, true};
  CGPathApply(&path, &state, [](void* statePtr, const CGPathElement* element) {
    State& state = *down_cast<State*>(statePtr);
    switch (element->type) {
    case kCGPathElementMoveToPoint:
      STU_CHECK(state.lastSubpathIsClosed);
      state.lastSubpathIsClosed = false;
      state.subpaths.append(Vector<CGPoint>{Capacity{8}});
      state.subpaths[$ - 1].append(element->points[0]);
      return;
    case kCGPathElementAddLineToPoint:
      STU_CHECK(!state.lastSubpathIsClosed);
      state.subpaths[$ - 1].append(element->points[0]);
      return;
    case kCGPathElementCloseSubpath:
      STU_CHECK(!state.lastSubpathIsClosed);
      state.lastSubpathIsClosed = true;
      return;
    default:
      STU_CHECK_MSG(false, "Unexpected CGPath element");
    }
  });
  return subpaths;
}

UIImage* createImage(CGSize size, CGFloat scale, UIColor* backgroundColor,
                     STUPredefinedCGImageFormat format, FunctionRef<void(CGContext*)> closure)
{
  const auto options = backgroundColor ? STUCGImageFormatWithoutAlphaChannel
                                       : STUCGImageFormatOptionsNone;
  auto cgImage = stu_createCGImage(size, scale, backgroundColor.CGColor,
                                   stuCGImageFormat(format, options),
                                   ^(CGContextRef context) { closure(context); });
  const auto image = [[UIImage alloc] initWithCGImage:cgImage scale:scale
                                          orientation:UIImageOrientationUp];
  CFRelease(cgImage);
  return image;
}

struct AddLineSpansPathArgs {
  bool fillTextLineGaps;
  bool shouldExtendToCommonBounds;
  UIEdgeInsets edgeInsets;
  CGFloat cornerRadius;
  Optional<SRect> clipRect;
  Optional<CGAffineTransform> transform;
};

RC<CGPath> createPathWithSpans(ArrayRef<const TextLineSpan> spans,
                               ArrayRef<const TextLineVerticalPosition> vps,
                               AddLineSpansPathArgs args = AddLineSpansPathArgs{})
{
  RC<CGPath> path = createMutableCGPath();
  ThreadLocalArenaAllocator::InitialBuffer<1024> buffer;
  ThreadLocalArenaAllocator alloc{Ref{buffer}};
  addLineSpansPath(*path, spans, vps,
                   ShouldFillTextLineGaps{args.fillTextLineGaps},
                   ShouldExtendTextLinesToCommonHorizontalBounds{args.shouldExtendToCommonBounds},
                   args.edgeInsets, CornerRadius{args.cornerRadius},
                   args.clipRect ? &*args.clipRect : nullptr,
                   args.transform ? &*args.transform : nullptr);
  return path;
}

UIImage* createPathImageWithSpans(ArrayRef<const TextLineSpan> spans,
                                  ArrayRef<const TextLineVerticalPosition> vps,
                                  AddLineSpansPathArgs args)
{
  RC<CGPath> path = createPathWithSpans(spans, vps, args);
  const CGRect rect = CGPathGetBoundingBox(path.get());
  const CGSize size = {rect.origin.x + rect.size.width,
                       rect.origin.y + rect.size.height};

  return createImage(size, 1, UIColor.whiteColor, STUPredefinedCGImageFormatGrayscale,
           [&](CGContextRef context)
         {
           CGContextSetFillColorWithColor(context, UIColor.blackColor.CGColor);
           CGContextAddPath(context, path.get());
           CGContextFillPath(context);
         });
}

Vector<TextLineSpan> createSpansForStars(CGFloat nonStarWidth, CGFloat starWidth,
                                         const char* const string)
{
  const stu::Int length = sign_cast(strlen(string));
  Vector<TextLineSpan> vector;
  stu::Int lineStartSpanIndex = 0;
  stu::UInt32 lineIndex = 0;
  CGFloat x = 0;
  for (stu::Int i = 0; i < length; ++i) {
    const char c = string[i];
    if (c != '*' && c != '\n') {
      x += nonStarWidth;
    } else if (c == '*') {
      CGFloat xStart = x;
      x += starWidth;
      while (string[i + 1] == '*') {
        ++i;
        x += starWidth;
      }
      vector.append(TextLineSpan{.x = range(xStart, x), .lineIndex = lineIndex,
                                 .isLeftEndOfLine = vector.count() == lineStartSpanIndex});
    } else { // c == '\n'
      lineIndex += 1;
      x = 0;
      if (lineStartSpanIndex < vector.count()) {
        vector[$ - 1].isRightEndOfLine = true;
      }
      lineStartSpanIndex = vector.count();
    }
  }
  if (lineStartSpanIndex < vector.count()) {
    vector[$ - 1].isRightEndOfLine = true;
  }
  return vector;
}

@interface TextLineSpansPathTests : SnapshotTestCase
@end

@implementation TextLineSpansPathTests

- (void)setUp {
  [super setUp];
  self.imageBaseDirectory = PATH_RELATIVE_TO_CURRENT_SOURCE_FILE_DIR(@"ReferenceImages");
}

using LS = TextLineSpan;
using VP = TextLineVerticalPosition;

- (void)assertLinearCGPath:(CGPath &)path
                    equals:(ArrayRef<const ArrayRef<const CGPoint>>)expectedSubpaths
{
  Vector<Vector<CGPoint>> subpaths = getLinearSubpaths(path);
  XCTAssertEqual(subpaths.count(), expectedSubpaths.count());
  for (Int i = 0; i < subpaths.count(); ++i) {
    const ArrayRef<const CGPoint> subpathPoints = subpaths[i];
    const ArrayRef<const CGPoint> expectedPoints = expectedSubpaths[i];
    XCTAssertEqual(subpathPoints.count(), expectedPoints.count());
    for (Int j = 0; j < subpathPoints.count(); ++j) {
      XCTAssertEqual(subpathPoints[j], expectedPoints[j]);
    }
  }
}


- (void)testAddLineSpansPathWithSimpleLinearPaths {
  self.continueAfterFailure = false;
  const TextLineVerticalPosition vs[] = {{.baseline = 10, .ascent = 1/4., .descent = 1/2.},
                                         {.baseline = 11, .ascent = 1/8., .descent = 1/16.},
                                         {.baseline = 12, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 13, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 14, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 15, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 16, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 17, .ascent = 1/4., .descent = 1/4.},
                                         {.baseline = 18, .ascent = 1/4., .descent = 1/4.}};

  const auto t = [&](stu::Int i) { return narrow_cast<CGFloat>(vs[i].baseline - vs[i].ascent); };
  const auto b = [&](stu::Int i) { return narrow_cast<CGFloat>(vs[i].baseline + vs[i].descent); };

  {
    auto path = createPathWithSpans({}, vs);
    [self assertLinearCGPath:*path equals:{}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}}, vs);
    [self assertLinearCGPath:*path equals:{{{{1, t(0)}, {3, t(0)}, {3, b(0)}, {1, b(0)}}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}}, vs,
                                    {.clipRect = SRect{range(0, 1.1f), range(0, t(0) + 0.1f)}});
    [self assertLinearCGPath:*path equals:{{{1, t(0)}, {3, t(0)}, {3, b(0)}, {1, b(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}}, vs,
                                    {.clipRect = SRect{range(0, 1.f), range(0, t(0))}});
    [self assertLinearCGPath:*path equals:{}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0},
                                     {.x = {4, 5}, .lineIndex = 0}}, vs);
    [self assertLinearCGPath:*path equals:{{{1, t(0)}, {3, t(0)}, {3, b(0)}, {1, b(0)}},
                                           {{4, t(0)}, {5, t(0)}, {5, b(0)}, {4, b(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0},
                                     {.x = {4, 5}, .lineIndex = 0}},
                                    vs, {.clipRect = SRect{Range{4, 6.f}, Range{t(0), b(0)}}});
    [self assertLinearCGPath:*path equals:{{{4, t(0)}, {5, t(0)}, {5, b(0)}, {4, b(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}}, vs,
                                    {.edgeInsets = UIEdgeInsets{.left = -0.5}});
    [self assertLinearCGPath:*path equals:{{{0.5, t(0)}, {3, t(0)}, {3, b(0)}, {0.5, b(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}}, vs,
                                    {.edgeInsets = UIEdgeInsets{.right = -0.5}});
    [self assertLinearCGPath:*path equals:{{{1, t(0)}, {3.5, t(0)}, {3.5, b(0)}, {1, b(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0},
                                     {.x = {1, 3}, .lineIndex = 1}}, vs);
    [self assertLinearCGPath:*path equals:{{{1, t(0)}, {3, t(0)}, {3, b(0)}, {1, b(0)}},
                                           {{1, t(1)}, {3, t(1)}, {3, b(1)}, {1, b(1)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0},
                                     {.x = {1, 3}, .lineIndex = 1}}, vs,
                                    {.fillTextLineGaps = true});
    [self assertLinearCGPath:*path equals:{{{3, t(0)}, {3, b(1)}, {1, b(1)}, {1, t(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0,
                                      .isLeftEndOfLine = true, .isRightEndOfLine = true},
                                     {.x = {1.5, 2.5}, .lineIndex = 1,
                                      .isLeftEndOfLine = true, .isRightEndOfLine = true}},
                                    vs, {.fillTextLineGaps = true,
                                         .shouldExtendToCommonBounds = true});
    [self assertLinearCGPath:*path equals:{{{3, t(0)}, {3, b(1)}, {1, b(1)}, {1, t(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {-1, 0}, .lineIndex = 0},
                                     {.x = {1, 3}, .lineIndex = 0},
                                     {.x = {1, 3}, .lineIndex = 1}},
                                    vs, {.fillTextLineGaps = true});
    [self assertLinearCGPath:*path equals:{{{0, t(0)}, {0, b(0)}, {-1, b(0)}, {-1, t(0)}},
                                           {{3, t(0)}, {3, b(1)}, {1, b(1)}, {1, t(0)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {1, 3}, .lineIndex = 0}, {.x = {4, 5}, .lineIndex = 0},
                                     {.x = {2, 4}, .lineIndex = 1},
                                     {.x = {2, 4}, .lineIndex = 3}},
                                    vs, {.fillTextLineGaps = true});
    [self assertLinearCGPath:*path equals:{{{3, t(0)}, {3, t(1)}, {4, t(1)}, {4, b(1)},
                                            {2, b(1)}, {2, b(0)}, {1, b(0)}, {1, t(0)}},
                                           {{5, t(0)}, {5, b(0)}, {4, b(0)}, {4, t(0)}},
                                           {{2, t(3)}, {4, t(3)}, {4, b(3)}, {2, b(3)}}}];
  }
  {
    auto path = createPathWithSpans({{.x = {2, 4}, .lineIndex = 0},
                                     {.x = {1, 3}, .lineIndex = 1}, {.x = {4, 5}, .lineIndex = 1},
                                     {.x = {2, 4}, .lineIndex = 3}},
                                    vs, {.fillTextLineGaps = true});
    [self assertLinearCGPath:*path equals:{{{4, t(0)}, {4, b(0)}, {3, b(0)}, {3, b(1)},
                                            {1, b(1)}, {1, t(1)}, {2, t(1)}, {2, t(0)}},
                                           {{5, t(1)}, {5, b(1)}, {4, b(1)}, {4, t(1)}},
                                           {{2, t(3)}, {4, t(3)}, {4, b(3)}, {2, b(3)}}}];
  }
  {
    auto path = createPathWithSpans({
      {.x = {0, 5}, .lineIndex = 0},
      {.x = {0, 1}, .lineIndex = 1}, {.x = {4, 5}, .lineIndex = 1},
      {.x = {0, 1}, .lineIndex = 2}, {.x = {2, 3}, .lineIndex = 2}, {.x = {4, 5}, .lineIndex = 2},
      {.x = {0, 1}, .lineIndex = 3}, {.x = {4, 5}, .lineIndex = 3},
      {.x = {0, 5}, .lineIndex = 4}
    }, vs, {.fillTextLineGaps = true});
    [self assertLinearCGPath:*path equals:{{{5, t(0)}, {5, b(4)}, {0, b(4)}, {0, t(0)}},
                                           {{1, b(0)}, {1, t(4)}, {4, t(4)}, {4, b(0)}},
                                           {{3, t(2)}, {3, b(2)}, {2, b(2)}, {2, t(2)}}}];
  }
}

- (void)testAddLineSpansPath {
  self.continueAfterFailure = true;
  const TextLineVerticalPosition vs[] = {{.baseline = 10,  .ascent = 6, .descent = 4},
                                         {.baseline = 25,  .ascent = 6, .descent = 4},
                                         {.baseline = 40,  .ascent = 6, .descent = 4},
                                         {.baseline = 55,  .ascent = 6, .descent = 4},
                                         {.baseline = 70,  .ascent = 6, .descent = 4},
                                         {.baseline = 85,  .ascent = 6, .descent = 4},
                                         {.baseline = 100, .ascent = 6, .descent = 4},
                                         {.baseline = 115, .ascent = 6, .descent = 4},
                                         {.baseline = 130, .ascent = 6, .descent = 4},
                                         {.baseline = 145, .ascent = 6, .descent = 4},
                                         {.baseline = 160, .ascent = 6, .descent = 4}};
  const auto createImageForStars = [&](const CGFloat nonStarWidth, const CGFloat starWidth,
                                       AddLineSpansPathArgs args,
                                       const char* const string) -> UIImage*
  {
    const auto spans = createSpansForStars(nonStarWidth, starWidth, string);
    return createPathImageWithSpans(spans, vs, args);
  };

  const char* const str1 =
    "  *****  *****  *   *   *      *****   *****   *****  *        ********* \n"
    "  *        *    *   *   *      *   *   *   *   *      *     *  *       * \n"
    "  *****    *    *   *   *      *****   *****   *****  *        * ***** * \n"
    "      *    *    *   *   *      *   *   *   *   *      *     *  * *   * * \n"
    "  *****    *    *****   *****  *   *   *****   *****  *****    * * * * * \n"
    "                                                            *  * *   * * \n"
    "  * **   ** **   **        *       ***     ***  *** *          * ***** * \n"
    "   *  ** **  ** **** **** ** **  *** *** *** * ** ***          *       * \n"
    "  *          *          **      *        ***   ****            ********* \n"
    "                                                                         \n"
    "    ********                                                             \n";

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true}, str1),
                       @"_1");
  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true, .cornerRadius = 100}, str1),
                       @"_1_rounded");
  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true, .cornerRadius = 100,
                        .transform = CGAffineTransformMakeTranslation(15, 15)}, str1),
                       @"_1_rounded_shifted");

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{2, 2, 2, 2},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_inset_2"
                       #if !CGFLOAT_IS_DOUBLE
                        "_32bit"
                       #endif
                       );

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{5, 5, 5, 5},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_inset_5");
  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{.top = 5, .bottom = 5},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_inset_v5");
  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{.left = 5, .right = 5},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_inset_h5");
  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{20, 20, 20, 20},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_inset_20");

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{-2, -2, -2, -2},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_outset_2"
                      #if !CGFLOAT_IS_DOUBLE
                        "_32bit"
                       #endif
                      );

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{-5, -5, -5, -5},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_outset_5");

  CHECK_SNAPSHOT_IMAGE(createImageForStars(10, 10,
                       {.fillTextLineGaps = true,
                        .edgeInsets = UIEdgeInsets{-20, -20, -20, -20},
                        .cornerRadius = 100}, str1),
                       @"_1_rounded_outset_20");
}

@end

