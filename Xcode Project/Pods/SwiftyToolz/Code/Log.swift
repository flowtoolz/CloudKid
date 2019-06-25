public func log(error: String,
                title: String? = nil,
                forUser: Bool = false,
                file: String = #file,
                function: String = #function,
                line: Int = #line)
{
    Log.shared.log(message: error,
                   title: title,
                   level: .error,
                   forUser: forUser,
                   file: file,
                   function: function,
                   line: line)
}

public func log(warning: String,
                title: String? = nil,
                forUser: Bool = false,
                file: String = #file,
                function: String = #function,
                line: Int = #line)
{
    Log.shared.log(message: warning,
                   title: title,
                   level: .warning,
                   forUser: forUser,
                   file: file,
                   function: function,
                   line: line)
}

public func log(_ message: String = "",
                title: String? = nil,
                forUser: Bool = false,
                file: String = #file,
                function: String = #function,
                line: Int = #line)
{
    Log.shared.log(message: message,
                   title: title,
                   level: .info,
                   forUser: forUser,
                   file: file,
                   function: function,
                   line: line)
}

public extension Log
{
    func log(message: String,
             title: String? = nil,
             level: Level = .info,
             forUser: Bool = false,
             file: String = #file,
             function: String = #function,
             line: Int = #line)
    {
        guard level.integer >= minimumLevel.integer else { return }
        
        var filename = file
        
        if let lastSlashIndex = filename.lastIndex(of: "/")
        {
            filename.removeSubrange(filename.startIndex ... lastSlashIndex)
        }
        
        let entry = Entry(message: message,
                          title: title,
                          level: level,
                          forUser: forUser,
                          file: filename,
                          function: function,
                          line: line)
    
        print(string(for: entry))
        
        LogObservation.notifyObservers(about: entry)
    }
    
    func string(for entry: Entry) -> String
    {
        var logString = prefix
        
        if entry.level != .info
        {
            if logString.count > 0 { logString += " " }
            
            logString += entry.level.rawValue.uppercased()
        }
        
        if logString.count > 0 { logString += ": " }
        
        logString += entry.message
        logString += " (\(entry.context))"
        
        return logString
    }
    
    func notify(_ observer: LogObserver)
    {
        LogObservation.notify(observer)
    }
    
    func stopNotifying(_ observer: LogObserver)
    {
        LogObservation.stopNotifying(observer)
    }
}

fileprivate struct LogObservation
{
    static func notify(_ observer: LogObserver)
    {
        observers[hashValue(observer)] = WeakObserver(observer: observer)
    }
    
    static func stopNotifying(_ observer: LogObserver)
    {
        observers[hashValue(observer)] = nil
    }
    
    static func notifyObservers(about entry: Log.Entry)
    {
        observers.remove { $0.observer == nil }
        observers.values.forEach { $0.observer?.process(entry) }
    }
    
    static var observers = [HashValue : WeakObserver]()
    
    struct WeakObserver
    {
        weak var observer: LogObserver?
    }
}

public protocol LogObserver: AnyObject
{
    func process(_ entry: Log.Entry)
}

public class Log
{
    // MARK: - Singleton Access
    
    public static let shared = Log()
    
    private init() {}
    
    // MARK: - Logging
    
    public var prefix = ""
    
    public struct Entry: Codable, Equatable
    {
        public var context: String
        {
            return "\(file), \(function), line \(line)"
        }
        
        public var message = ""
        public var title: String?
        public var level = Level.info
        public var forUser = false
        public var file = ""
        public var function = ""
        public var line = 0
    }
    
    // MARK: - Log Levels
    
    public var minimumLevel: Level = .info
    
    public enum Level: String, Codable, Equatable
    {
        var integer: Int
        {
            switch self
            {
            case .info: return 0
            case .warning: return 1
            case .error: return 2
            case .off: return 3
            }
        }
        
        case info, warning, error, off
    }
}
