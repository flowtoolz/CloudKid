public extension String
{
    init?(withNonEmpty string: String?)
    {
        guard let string = string, string != "" else { return nil }
        
        self = string
    }
    
    static func makeUUID() -> String
    {
        // create random bytes
        
        var bytes = [Byte]()
        
        16.times { bytes.append(Byte.random) }
        
        // indicate UUID version and variant
        
        bytes[6] = (bytes[6] & 0x0f) | 0x40 // version 4
        bytes[8] = (bytes[8] & 0x3f) | 0x80 // variant 1
        
        // create string representation
        
        let ranges = [0 ..< 4, 4 ..< 6, 6 ..< 8, 8 ..< 10, 10 ..< 16]
        
        return ranges.map
        {
            var string = ""
            
            for i in $0
            {
                string += String(bytes[i], radix: 16, uppercase: false)
            }
            
            return string
        }.joined(separator: "-")
    }
}
