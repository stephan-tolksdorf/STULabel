// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUBackgroundAttribute {

@inlinable
public convenience init(_ configure: (STUBackgroundAttributeBuilder) -> Void) {
  self.init(__block:configure)
}

}
