import Foundation

public extension Decodable
{
    init?(filePath: String)
    {
        let fileUrl = URL(fileURLWithPath: filePath)
        
        self.init(fileURL: fileUrl)
    }
    
    init?(fileURL: URL?)
    {
        if let decodedSelf = Self(jsonData: Data(fileURL: fileURL))
        {
            self = decodedSelf
        }
        else
        {
            return nil
        }
    }
    
    init?(jsonData: Data?)
    {
        guard let jsonData = jsonData else { return nil }
        
        do
        {
            self = try JSONDecoder().decode(Self.self, from: jsonData)
        }
        catch
        {
            return nil
        }
    }
}

public extension Encodable
{
    @discardableResult
    func save(to filePath: String) -> URL?
    {
        return self.encode()?.save(to: filePath)
    }
    
    @discardableResult
    func save(to fileUrl: URL) -> URL?
    {
        return self.encode()?.save(to: fileUrl)
    }
    
    func encode() -> Data?
    {
        let jsonEncoder = JSONEncoder()
        
        jsonEncoder.outputFormatting = .prettyPrinted
        
        return try? jsonEncoder.encode(self)
    }
}
