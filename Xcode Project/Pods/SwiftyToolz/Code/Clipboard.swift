public class Clipboard<Object: Copyable>
{
    public init() {}
    
    public var count: Int { return copies?.count ?? 0 }
    
    public func removeAll()
    {
        originals = nil
        copies = nil
    }
    
    // originals
    
    public func popOriginalsOrMakeCopies() -> [Object]?
    {
        if let result = originals
        {
            originals = nil
            return result
        }
        
        return copies?.map { $0.copy }
    }
    
    public func storeCopiesAndOriginals(of objects: [Object])
    {
        storeCopies(of: objects)
        originals = objects
    }
    
    private var originals: [Object]?
    
    // copies
    
    public func storeCopies(of objects: [Object])
    {
        copies = objects.map { $0.copy }
    }
    
    private var copies: [Object]?
}
