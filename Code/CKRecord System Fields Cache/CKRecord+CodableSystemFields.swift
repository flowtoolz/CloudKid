import CloudKit

public extension CKRecord
{
    convenience init?(fromEncodedSystemFields data: Data?)
    {
        guard let data = data else { return nil }
        let decoder = NSKeyedUnarchiver(forReadingWith: data)
        decoder.requiresSecureCoding = true
        self.init(coder: decoder)
        decoder.finishDecoding()
    }
    
    func encodeSystemFields() -> Data
    {
        let data = NSMutableData()
        let encoder = NSKeyedArchiver(forWritingWith: data)
        encoder.requiresSecureCoding = true
        encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        return data as Data
    }
}
