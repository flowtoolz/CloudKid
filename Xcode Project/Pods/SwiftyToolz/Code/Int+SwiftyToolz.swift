public extension Int
{
    func times(_ body: () throws -> Void) rethrows
    {
        if self > 0
        {
            for _ in 0 ..< self { try body() }
        }
    }
    
    static func random(max: Int = .max) -> Int
    {
        return Int.random(in: 0 ... max)
    }
}

public extension UInt8
{
    static var random: UInt8
    {
        return UInt8.random(in: 0 ... .max)
    }
}

public typealias Byte = UInt8
