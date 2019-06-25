public extension Copyable
{
    var copy: Self { return Self(with: self) }
}

public protocol Copyable: AnyObject
{
    init(with original: Self)
}
