
import CoreGraphics

@inlinable
internal func roundToScale<F: BinaryFloatingPoint>(_ value: F, _ scale: F) -> F {
  guard scale > 0 else { return value }
  return (value*scale).rounded(.toNearestOrEven)/scale
}

@inlinable
internal func ceilToScale<F: BinaryFloatingPoint>(_ value: F, _ scale: F) -> F {
  guard scale > 0 else { return value }
  let scaledValue = value*scale;
  let roundedValue = scaledValue.rounded(.toNearestOrEven)/scale
  let ceiledValue  = scaledValue.rounded(.up)/scale
  let maxRelDiff = (MemoryLayout<F>.size <= 4 ? 32 : 128) * F.ulpOfOne
  return abs(roundedValue - value) <= abs(value)*maxRelDiff
       ? roundedValue : ceiledValue;
}


