public extension Error
{
    var readable: ReadableError
    {
        if let readableError = self as? ReadableError
        {
            return readableError
        }
        else
        {
            return .message(localizedDescription)
        }
    }
}

public enum ReadableError: Error, CustomDebugStringConvertible
{
    public var localizedDescription: String
    {
        return message
    }
    
    public var debugDescription: String
    {
        return message
    }
    
    public var message: String
    {
        switch self
        {
        // TODO: can we make this more readable with https://github.com/mxcl/LegibleError ?
        case .message(let text): return text
        }
    }
    
    case message(_ text: String)
}
