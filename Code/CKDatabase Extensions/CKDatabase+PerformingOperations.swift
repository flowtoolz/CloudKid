import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func perform(_ operation: CKDatabaseOperation)
    {
        operation.queuePriority = .high
        operation.qualityOfService = .userInitiated
        add(operation)
    }
    
    func setTimeout(of seconds: Double = CKDatabase.timeoutAfterSeconds,
                       on operation: CKDatabaseOperation,
                       or handleTimeout: @escaping (ReadableError) -> Void)
    {
        if #available(OSX 10.13, *)
        {
            operation.configuration.timeoutIntervalForRequest = seconds
            operation.configuration.timeoutIntervalForResource = seconds
        }
        else
        {
            queue.asyncAfter(deadline: .now() + .milliseconds(Int(seconds * 1000)))
            {
                handleTimeout(.message("iCloud database operation didn't respond and was cancelled after \(seconds) seconds."))
            }
        }
    }
    
    #if DEBUG
    static let timeoutAfterSeconds: Double = 5
    #else
    static let timeoutAfterSeconds: Double = 20
    #endif
    
    // TODO: Retry requests if error has ckShouldRetry, wait ckError.retryAfterSeconds ...
    
    func retry(after seconds: Double, action: @escaping () -> Void)
    {
        let retryTime = DispatchTime.now() + seconds
        
        queue.asyncAfter(deadline: retryTime, execute: action)
    }
    
    var queue: DispatchQueue { iCloudQueue }
}
