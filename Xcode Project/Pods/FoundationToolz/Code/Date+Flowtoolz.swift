import Foundation

public extension Date
{
    var utcString: String
    {
        if #available(OSX 10.12, *)
        {
            return ISO8601DateFormatter().string(from: self)
        }
        else
        {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            return formatter.string(from: self)
        }
    }

    static func dayFromJSONDateString(_ json: String) -> Date?
    {
        let onlyDayString = json.components(separatedBy: "T")[0]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"//'T'HH:mm:ss.sssz"
        
        guard let date = formatter.date(from: onlyDayString) else
        {
            return nil
        }
        
        return date
    }
    
    func stringWithFormat(format: String) -> String
    {
        let formatter = DateFormatter()
        
        formatter.dateFormat = format
        
        return formatter.string(from: self)
    }

    init?(fromString string: String, withFormat format: String)
    {
        let formatter = DateFormatter()
        
        formatter.dateFormat = format
        
        guard let date = formatter.date(from: string) else
        {
            return nil
        }
        
        self = date
    }
    
    func plus(months: Int) -> Date?
    {
        return Calendar.current.date(byAdding: .month, value: months, to: self)
    }
    
    func plus(days: Int) -> Date?
    {
        return Calendar.current.date(byAdding: .day, value: days, to: self)
    }
    
    func days(since date: Date) -> Int?
    {
        let calendar = Calendar.current
        
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: date),
                                       to: calendar.startOfDay(for: self)).day
    }
}
