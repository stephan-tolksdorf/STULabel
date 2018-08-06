// Copyright 2017–2018 Stephan Tolksdorf

#import "CoreGraphicsUtils.hpp"

namespace stu_label {

template <typename T>
struct Rect;

template <typename T>
struct Point {
  T x;
  T y;

  STU_CONSTEXPR_T
  Point() : x{}, y{} {}

  explicit STU_INLINE_T
  Point(Uninitialized) {}

  STU_CONSTEXPR_T
  Point(T x, T y)
  : x{std::move(x)}, y{std::move(y)}
  {}

  template <typename U, EnableIf<isSafelyConvertible<U, T> && !isSame<U, T>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Point(const Point<U>& other)
  : x(other.x), y(other.y)
  {}

  template <typename U, EnableIf<isNonSafelyConvertible<U, T>> = 0>
  explicit STU_CONSTEXPR_T
  Point(const Point<U>& other)
  : x{static_cast<T>(other.x)}, y{static_cast<T>(other.y)}
  {}

  template <bool enable = isSafelyConvertible<CGFloat, T>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Point(CGPoint other)
  : x{other.x}, y{other.y}
  {}

  template <bool enable = isSafelyConvertible<CGFloat, T>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Point(CGVector vector)
  : x{vector.dx}, y{vector.dy}
  {}

  template <bool enable = isSafelyConvertible<T, CGFloat>, EnableIf<enable && 1> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator CGPoint() const {
    return {.x = static_cast<CGFloat>(x), .y = static_cast<CGFloat>(y)};
  }

  template <bool enable = isNonSafelyConvertible<T, CGFloat>, EnableIf<enable && 2> = 0>
  explicit STU_CONSTEXPR_T
  operator CGPoint() const {
    return {.x = static_cast<CGFloat>(x), .y = static_cast<CGFloat>(y)};
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Point roundedToNearbyInt() const {
    return {std::nearbyint(x), std::nearbyint(y)};
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  void roundToNearbyInt() {
    *this = roundedToNearbyInt();
  }

  STU_CONSTEXPR
  Point<T> clampedTo(Rect<T> rect) const {
    return {clamp(rect.x.start, x, rect.x.end),
            clamp(rect.y.start, y, rect.y.end)};
  }

  STU_CONSTEXPR
  T squaredDistance() const {
    return x*x + y*y;
  }

  /// The Euclidean norm.
  STU_CONSTEXPR
  T distance() const {
    return sqrt(squaredDistance());
  }


  STU_CONSTEXPR
  Point& operator+=(const Point& other) {
    x += other.x;
    y += other.y;
    return *this;
  }

  STU_CONSTEXPR
  Point& operator-=(const Point& other) {
    x -= other.x;
    y -= other.y;
    return *this;
  }

  STU_CONSTEXPR
  Point& operator*=(const T& scale) {
    x *= scale;
    y *= scale;
    return *this;
  }

  STU_CONSTEXPR
  Point& operator/=(const T& scale) {
    x /= scale;
    y /= scale;
    return *this;
  }

  STU_CONSTEXPR
  friend Point operator+(Point lhs, const Point& rhs) {
    lhs += rhs;
    return lhs;
  }

  STU_CONSTEXPR
  friend Point operator-(Point lhs, const Point& rhs) {
    lhs -= rhs;
    return lhs;
  }

  STU_CONSTEXPR
  friend Point operator*(Point point, const T& scale) {
    point *= scale;
    return point;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Point<U> operator*(const Point<T>& point, const U& scale) {
    Point<U> result{point};
    result *= scale;
    return result;
  }


  STU_CONSTEXPR
  friend Point operator*(const T& scale, const Point& point) {
    return point*scale;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Point<U> operator*(const U& scale, const Point<T>& point) {
    return point*scale;
  }

  STU_CONSTEXPR
  friend Point operator/(Point point, const T& scale) {
    point /= scale;
    return point;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Point<U> operator/(const Point<T>& point, const U& scale) {
    Point<U> result{point};
    result /= scale;
    return result;
  }

  STU_CONSTEXPR
  friend bool operator==(const Point& lhs, const Point& rhs) {
    return lhs.x == rhs.x && lhs.y == rhs.y;
  }
  STU_CONSTEXPR
  friend bool operator!=(const Point& lhs, const Point& rhs) { return !(lhs == rhs); }
};

Point(CGPoint) -> Point<CGFloat>;

} // namespace stu_label

template <typename T>
struct stu::IsMemberwiseConstructible<stu_label::Point<T>> : stu::IsMemberwiseConstructible<T> {};

namespace stu_label {

template <typename T>
struct Size {
  T width;
  T height;

  STU_CONSTEXPR_T
  Size() : width{}, height{} {}

  explicit STU_INLINE_T
  Size(Uninitialized) {}

  STU_CONSTEXPR_T
  Size(T width, T height)
  : width{width}, height{height}
  {}

  template <typename U, EnableIf<isSafelyConvertible<U, T> && !isSame<U, T>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Size(const Size<U>& other)
  : width(other.width), height(other.height)
  {}

  template <typename U, EnableIf<isNonSafelyConvertible<U, T>> = 0>
  explicit STU_CONSTEXPR_T
  Size(const Size<U>& other)
  : width{static_cast<T>(other.width)}, height{static_cast<T>(other.height)}
  {}

  template <bool enable = isSafelyConvertible<CGFloat, T>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Size(CGSize other)
  : width{other.width}, height{other.height}
  {}

  template <bool enable = isSafelyConvertible<T, CGFloat>, EnableIf<enable && 1> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator CGSize() const {
    return {.width = static_cast<CGFloat>(width), .height = static_cast<CGFloat>(height)};
  }

  template <bool enable = isNonSafelyConvertible<T, CGFloat>, EnableIf<enable && 2> = 0>
  explicit STU_CONSTEXPR_T
  operator CGSize() const {
    return {.width = static_cast<CGFloat>(width), .height = static_cast<CGFloat>(height)};
  }

  /// Returns width()*height(), which may be negative or overflow.
  STU_CONSTEXPR_T T area() const {
    return width*height;
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Size roundedToNearbyInt() const {
    return {std::nearbyint(width), std::nearbyint(height)};
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  void roundToNearbyInt() {
    *this = roundedToNearbyInt();
  }

  STU_CONSTEXPR
  Size& operator*=(const T& scale) {
    width *= scale;
    height *= scale;
    return *this;
  }

  STU_CONSTEXPR
  Size& operator/=(const T& scale) {
    width /= scale;
    height /= scale;
    return *this;
  }

  STU_CONSTEXPR
  friend Size operator*(Size size, const T& scale) {
    size *= scale;
    return size;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Size<U> operator*(const Size<T>& size, const U& scale) {
    Size<U> result{size};
    result *= scale;
    return result;
  }

  STU_CONSTEXPR
  friend Size operator*(const T& scale, const Size& size) {
    return size*scale;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Size<U> operator*(const U& scale, const Size<T>& size) {
    return size*scale;
  }

  STU_CONSTEXPR
  friend Size operator/(Size size, const T& scale) {
    size /= scale;
    return size;
  }
  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Size<U> operator/(const Size<T>& size, const U& scale) {
    Size<U> result{size};
    result /= scale;
    return result;
  }

  STU_CONSTEXPR
  friend bool operator==(const Size& lhs, const Size& rhs) {
    return lhs.width == rhs.width && lhs.height == rhs.height;
  }
  STU_CONSTEXPR
  friend bool operator!=(const Size& lhs, const Size& rhs) { return !(lhs == rhs); }
  
};

Size(CGSize) -> Size<CGFloat>;

} // namespace stu_label

template <typename T>
struct stu::IsMemberwiseConstructible<stu_label::Size<T>> : stu::IsMemberwiseConstructible<T> {};

namespace stu_label {

template <typename T>
struct EdgeInsets {
  T top;
  T left;
  T bottom;
  T right;

  EdgeInsets() = delete;

  template <bool enable = isSafelyConvertible<T, CGFloat>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator UIEdgeInsets() const {
    return {.top = top, .left = left, .bottom = bottom, .right = right};
  }
};

template <typename T>
struct Rect {
  Range<T> x;
  Range<T> y;

  /// Rects with a non-positive width or height are considered empty.
  STU_CONSTEXPR bool isEmpty() const { return x.isEmpty() || y.isEmpty(); }

  STU_CONSTEXPR
  static const Rect infinitelyEmpty() {
    return {Range<T>::infinitelyEmpty(), Range<T>::infinitelyEmpty()};
  }

  /// Returns x.end - x.start, which may be negative or overflow.
  template <bool enable = isSigned<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T T width() const { return x.end - x.start; }

  /// Returns y.end - y.start, which may be negative or overflow.
  template <bool enable = isSigned<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T T height() const { return y.end - y.start; }

  /// Returns {x.end - x.start, y.end - y.start}, which may have negative components or overflow.
  template <bool enable = isSigned<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR_T Size<T> size() const { return Size<T>(x.end - x.start, y.end - y.start); }

  /// Returns width()*height(), which may be negative or overflow.
  STU_CONSTEXPR_T T area() const {
    return width()*height();
  }

  STU_CONSTEXPR_T Point<T> origin() const { return {x.start, y.start}; }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  /// Returns (x.start + x.end)/2, (y.start + y.end)/2}, which may overflow.
  STU_CONSTEXPR_T Point<T> center() const {
    return {(x.start + x.end)/2, (y.start + y.end)/2};
  }

  STU_CONSTEXPR_T
  Rect() = default;

  explicit STU_INLINE_T
  Rect(Uninitialized)
  : x{uninitialized}, y{uninitialized} {}

  STU_CONSTEXPR_T
  Rect(Range<T> x, Range<T> y)
  : x{x}, y{y}
  {}

  STU_CONSTEXPR_T
  Rect(Point<T> origin, Size<T> size)
  : x{origin.x, origin.x + size.width},
    y{origin.y, origin.y + size.height}
  {}

  template <bool enable = isSafelyConvertible<CGFloat, T>, EnableIf<enable> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Rect(CGRect r)
  : x{r.origin.x, r.origin.x + r.size.width},
    y{r.origin.y, r.origin.y + r.size.height}
  {}

  template <typename U, EnableIf<isSafelyConvertible<U, T> && !isSame<U, T>> = 0>
  /* implicit */ STU_CONSTEXPR_T
  Rect(const Rect<U>& other)
  : x(other.x), y(other.y)
  {}

  template <typename U, EnableIf<isNonSafelyConvertible<U, T>> = 0>
  explicit STU_CONSTEXPR_T
  Rect(const Rect<U>& other)
  : x(other.x), y(other.y)
  {}

  template <bool enable = isSafelyConvertible<T, CGFloat>, EnableIf<enable && 1> = 0>
  /* implicit */ STU_CONSTEXPR_T
  operator CGRect() const {
    return {origin(), size()};
  }

  template <bool enable = isNonSafelyConvertible<T, CGFloat>, EnableIf<enable && 2> = 0>
  explicit STU_CONSTEXPR_T
  operator CGRect() const {
    return {static_cast<CGPoint>(origin()), static_cast<CGSize>(size())};
  }

  [[nodiscard]] STU_CONSTEXPR
  bool contains(Point<T> point) const {
     return x.contains(point.x) && y.contains(point.y);
  }

  [[nodiscard]] STU_CONSTEXPR
  bool contains(Rect other) const {
     return x.contains(other.x) && y.contains(other.y);
  }

  [[nodiscard]] STU_CONSTEXPR
  bool overlaps(Rect other) const {
     return x.overlaps(other.x) && y.overlaps(other.y);
  }

  [[nodiscard]] STU_CONSTEXPR
  Rect intersection(Rect other) const {
    return {x.intersection(other.x), y.intersection(other.y)};
  }

  STU_CONSTEXPR
  void intersect(Rect other) {
    x.intersect(other.x);
    y.intersect(other.y);
  }

  [[nodiscard]] STU_CONSTEXPR
  Rect clampedTo(Rect other) const {
    return {x.clampedTo(other.x), y.clampedTo(other.y)};
  }

  STU_CONSTEXPR
  void clampTo(Rect other) {
    x.clampTo(other.x);
    y.clampTo(other.y);
  }

  [[nodiscard]] STU_CONSTEXPR
  Rect convexHull(Rect other) {
    return {x.convexHull(other.x), y.convexHull(other.y)};
  }

  [[nodiscard]] STU_CONSTEXPR
  Rect outset(T d) const {
    return {Range{x.start - d, x.end + d},
            Range{y.start - d, y.end + d}};
  }

  [[nodiscard]] STU_CONSTEXPR
  Rect inset(EdgeInsets<T> insets) const {
    return {Range{x.start + insets.left, x.end - insets.right},
            Range{y.start + insets.top,  y.end - insets.bottom}};
  }

  template <bool enable = isSafelyConvertible<CGFloat, T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Rect inset(UIEdgeInsets insets) const {
    return {Range{x.start + insets.left, x.end - insets.right},
            Range{y.start + insets.top,  y.end - insets.bottom}};
  }

  [[nodiscard]] STU_INLINE
  T squaredDistanceTo(Point<T> p) const {
    return (p - p.clampedTo(*this)).squaredDistance();
  }

  [[nodiscard]] STU_INLINE
  T distanceTo(Point<T> p) const {
    return sqrt(squaredDistanceTo(p));
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  [[nodiscard]] STU_CONSTEXPR
  Rect roundedToNearbyInt() const {
    return {x.roundedToNearbyInt(), y.roundedToNearbyInt()};
  }

  template <bool enable = isFloatingPoint<T>, EnableIf<enable> = 0>
  STU_CONSTEXPR
  void roundToNearbyInt() {
    *this = roundedToNearbyInt();
  }

  STU_CONSTEXPR
  friend bool operator==(const Rect& lhs, const Rect& rhs) {
    return lhs.x == rhs.x && lhs.y == rhs.y;
  }
  STU_CONSTEXPR
  friend bool operator!=(const Rect& lhs, const Rect& rhs) { return !(lhs == rhs); }

  STU_CONSTEXPR
  Rect& operator+=(const Point<T>& offset) {
    x += offset.x;
    y += offset.y;
    return *this;
  }

  STU_CONSTEXPR
  Rect& operator-=(const Point<T>& offset) {
    x -= offset.x;
    y -= offset.y;
    return *this;
  }

  STU_CONSTEXPR
  Rect& operator*=(const T& scale) {
    x *= scale;
    y *= scale;
    return *this;
  }

  STU_CONSTEXPR
  Rect& operator/=(const T& scale) {
    x /= scale;
    y /= scale;
    return *this;
  }

  STU_CONSTEXPR
  friend Rect operator+(Rect rect, const Point<T>& offset) {
    rect += offset;
    return rect;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator+(const Rect& rect, const Point<U>& offset) {
    Rect<U> r{rect};
    r += offset;
    return r;
  }

  STU_CONSTEXPR
  friend Rect operator+(const Point<T>& offset, const Rect& rect) {
    return rect + offset;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator+(const Point<U>& offset, const Rect& rect) {
    return rect + offset;
  }

  STU_CONSTEXPR
  friend Rect operator-(Rect rect, const Point<T>& offset) {
    rect -= offset;
    return rect;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator-(const Rect<T>& rect, const Point<U>& offset) {
    Rect<U> r{rect};
    r -= offset;
    return r;
  }

  STU_CONSTEXPR
  friend Rect operator*(Rect<T> rect, const T& scale) {
    rect *= scale;
    return rect;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator*(const Rect<T>& rect, const U& scale) {
    Rect<U> r{rect};
    r *= scale;
    return r;
  }

  STU_CONSTEXPR
  friend Rect operator*(const T& scale, const Rect& rect) {
    return rect*scale;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator*(const U& scale, const Rect<T>& rect) {
    return rect*scale;
  }


  STU_CONSTEXPR
  friend Rect operator/(Rect rect, const T& scale) {
    rect /= scale;
    return rect;
  }

  template <typename U, EnableIf<!isSame<T, U> && isSafelyConvertible<T, U>> = 0>
  STU_CONSTEXPR
  friend Rect<U> operator/(const Rect<T>& rect, const U& scale) {
    Rect<U> r{rect};
    r /= scale;
    return r;
  }
};

Rect(CGRect) -> Rect<CGFloat>;
Rect(CGPoint, CGSize) -> Rect<CGFloat>;

} // namespace stu_label

template <typename T>
struct stu::IsMemberwiseConstructible<stu_label::Rect<T>>
    :  stu::IsMemberwiseConstructible<stu::Range<T>> {};

