// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

extension STULabelOverlayStyle {

@inlinable
public convenience init(_ configure: (STULabelOverlayStyleBuilder) -> Void) {
  self.init(__block:configure)
}

}
