// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUTextFrameOptions {

@_transparent
public convenience init(_ configure: (STUTextFrameOptionsBuilder) -> Void) {
  self.init(__block:configure)
}

}
