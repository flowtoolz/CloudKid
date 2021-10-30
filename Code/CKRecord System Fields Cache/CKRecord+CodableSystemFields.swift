import CloudKit

public extension CKRecord
{
    convenience init?(fromEncodedSystemFields data: Data?)
    {
        guard let data = data,
              let decoder = try? NSKeyedUnarchiver(forReadingFrom: data)
        else { return nil }
        
        decoder.requiresSecureCoding = true
        self.init(coder: decoder)
        decoder.finishDecoding()
    }
    
    func encodeSystemFields() -> Data
    {
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        return encoder.encodedData
    }
}
