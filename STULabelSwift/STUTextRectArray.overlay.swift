// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension STUTextRectArray {

  /// Returns the index and distance of the rect closest to the specified point.
  /// In case of a tie the index of the first rect with the minimum distance is returned.
  ///
  /// If the array contains no rect or if the distance between the closest rect and the point is
  /// greater than `maxDistance`, this method returns nil.
  @inlinable
  public func findRect(closestTo point: CGPoint, maxDistance: CGFloat)
           -> (index: Int, distance: CGFloat)?
  {
    let r = self.__findRectClosest(to: point, maxDistance: maxDistance)
    if r.index != NSNotFound {
      return (index: r.index, r.distance)
    }
    return nil
  }
}
