// Copyright 2018 Stephan Tolksdorf

// It's 2018 and Swift still doesn't have a PRNG that is seedable, i.e. that can be used for
// reproducable test cases.

// We don't care too much about the statistical qualities of the generated random numbers here,
// so we just std::minstd_rand

private var _randState: Int32 = 1
private let _randModulus: Int32 = 2147483647

func seedRand(_ index: Int) {
  _randState = Int32(1 + index)%_randModulus
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
                      _ pNumerator: Int32, _ pDenominator: Int32) -> [NSRange]
{
  let stringLength = CFStringGetLength(string)
  let tokenizer = CFStringTokenizerCreate(nil, string, CFRange(location: 0, length: stringLength),
                                          kCFStringTokenizerUnitWord, locale as CFLocale)
  var ranges = [NSRange]()
  var currentRange: Range<Int>?
  while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
    let r = Range(CFStringTokenizerGetCurrentTokenRange(tokenizer))
    if rand(pDenominator) < pNumerator {
      if currentRange == nil {
        currentRange = r
      } else {
        currentRange = currentRange!.lowerBound..<r.upperBound
      }
      continue
    }
    if let range = currentRange {
      ranges.append(NSRange(range))
      currentRange = nil
    }
  }
  if let range = currentRange {
    ranges.append(NSRange(range))
  }
  return ranges
}
