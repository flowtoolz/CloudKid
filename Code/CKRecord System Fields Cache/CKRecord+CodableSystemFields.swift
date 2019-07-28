import CloudKit

public extension CKRecord
{
    convenience init?(fromSystemFieldEncoding data: Data?)
    {
        guard let data = data else { return nil }
        let decoder = NSKeyedUnarchiver(forReadingWith: data)
        decoder.requiresSecureCoding = true
        self.init(coder: decoder)
        decoder.finishDecoding()
    }
    
    var systemFieldEncoding: Data
    {
        let data = NSMutableData()
        let encoder = NSKeyedArchiver(forWritingWith: data)
        encoder.requiresSecureCoding = true
        encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        return data as Data
    }
}
