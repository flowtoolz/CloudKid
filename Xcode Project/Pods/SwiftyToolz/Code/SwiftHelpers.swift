public typealias JSON = [String : Any]

public typealias Action = () -> Void

// MARK: - Object Identity

public func address(_ object: AnyObject) -> String
{
    return String(describing: Unmanaged.passUnretained(object).toOpaque())
}

public func hashValue(_ object: AnyObject) -> HashValue
{
    return ObjectIdentifier(object).hashValue
}

public typealias HashValue = Int

// MARK: - Type Inspection

public func isOptional(_ type: Any.Type) -> Bool
{
    return type is OptionalProtocol.Type
}

extension Optional: OptionalProtocol {}
protocol OptionalProtocol {}

public func typeName<T>(_ anything: T) -> String
{
    return String(describing: type(of: anything))
}

