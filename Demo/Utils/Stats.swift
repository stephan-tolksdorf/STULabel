// Copyright 2018 Stephan Tolksdorf

import CoreFoundation

struct Stats {
  let count: Int
  let min: Double
  let max: Double
  let mean: Double
  let stddev: Double
}

struct IncremantalStatsCalculator {
  private(set) var count: Double = 0
  private(set) var min: Double = .nan
  private(set) var max: Double = .nan
  private(set) var mean: Double = .nan
  private var m2: Double = .nan
  private(set) var lastValue: Double = .nan

  var variance: Double { return count <= 1 ? 0 : m2/(count - 1) }

  var stddev: Double { return sqrt(variance) }

  var stats: Stats {
    return Stats(count: Int(count), min: min, max: max, mean: mean, stddev: stddev)
  }

  mutating func addMeasurement(_ value: Double) {
    guard count != 0
    else {
      reset(firstValue: value)
      return
    }
    // https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_Online_algorithm
    count += 1
    min = Swift.min(min, value)
    max = Swift.max(max, value)
    let d1 = value - mean
    mean += d1/count
    let d2 = value - mean
    m2 += d1*d2
    lastValue = value
  }

  mutating func reset(firstValue: Double? = nil) {
    if let firstValue = firstValue {
      count = 1
      min = firstValue
      max = firstValue
      mean = firstValue
      m2 = 0
      lastValue = firstValue
    } else {
      count = 0
      min = .nan
      max = .nan
      mean = .nan
      m2 = .nan
      lastValue = .nan
    }
  }
}
