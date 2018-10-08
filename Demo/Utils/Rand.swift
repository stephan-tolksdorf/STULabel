// Copyright 2018 Stephan Tolksdorf

import Foundation

// We need a pseudorandom number generator that is seedable, so that we can reproduce test cases.
// Swift still doesn't have one. Since we don't care too much about the statistical qualities of the
// generated random numbers here, we just std::minstd_rand

private var _randState: Int32 = 1
private let _randModulus: Int32 = 2147483647

func randState() -> Int32 {
  return _randState
}


func seedRand(_ index: Int32) {
  _randState = (1 + index)%_randModulus
}

func rand() -> Int {
  _randState = Int32((Int64(_randState) * 48271)%Int64(_randModulus))
  return Int(_randState)
}

func rand(_ upperBound: Int32) -> Int {
  precondition(0 < upperBound && upperBound <= _randModulus)
  let ub = _randModulus%upperBound
  while true {
    let r = Int32(rand())
    if r < ub { continue }
    return Int(r%upperBound)
  }
}

func randU01() -> Double {
  return Double(rand())/Double(_randModulus)
       + Double(rand())/(Double(_randModulus)*Double(_randModulus))
}

extension Range where Bound == Int {
  init(_ other: CFRange) {
    self = other.location..<(other.location + other.length)
  }
}

func randomWordRanges(_ string: CFString, _ locale: CFLocale,
                      _ p0: Double, _ p1: Double) -> [NSRange]
{
  let stringLength = CFStringGetLength(string)
  let tokenizer = CFStringTokenizerCreate(nil, string, CFRange(location: 0, length: stringLength),
                                          kCFStringTokenizerUnitWord, locale as CFLocale)
  var ranges = [NSRange]()
  while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
    if randU01() > p0 { continue }
    let r0 = Range(CFStringTokenizerGetCurrentTokenRange(tokenizer))
    var r1 = r0
    while randU01() <= p1 {
      if CFStringTokenizerAdvanceToNextToken(tokenizer) == [] { break; }
      r1 = Range(CFStringTokenizerGetCurrentTokenRange(tokenizer))
    }
    ranges.append(NSRange(r0.lowerBound..<r1.upperBound))
    CFStringTokenizerAdvanceToNextToken(tokenizer)
  }
  return ranges
}

func randomCharacterRanges(_ string: String, _ p0: Double, _ p1: Double) -> [NSRange] {
  var i = string.startIndex
  let end = string.endIndex
  var ranges = [NSRange]()
  while i != end {
    let i0 = i
    i = string.index(after: i)
    if randU01() > p0 { continue }
    while i != end && randU01() <= p1 {
      i = string.index(after: i)
    }
    ranges.append(NSRange(i0.encodedOffset..<i.encodedOffset))
    if i != end {
      i = string.index(after: i)
    }
  }
  return ranges
}
