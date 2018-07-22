// Copyright 2018 Stephan Tolksdorf

@_exported import STULabel

public extension STUParagraphStyle {

@_transparent
public convenience init(_ configure: (STUParagraphStyleBuilder) -> Void) {
  self.init(__block:configure)
}

}
