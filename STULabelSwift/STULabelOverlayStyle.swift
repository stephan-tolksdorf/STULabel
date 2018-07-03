// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STULabelOverlayStyle {

@_transparent
public convenience init(_ configure: (STULabelOverlayStyleBuilder) -> Void) {
  self.init(__block:configure)
}

}
