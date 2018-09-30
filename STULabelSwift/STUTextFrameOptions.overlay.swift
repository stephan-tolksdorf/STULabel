// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUTextFrameOptions {

@inlinable
public convenience init(_ configure: (STUTextFrameOptionsBuilder) -> Void) {
  self.init(__block:configure)
}

}
