import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    func perform(_ operation: CKDatabaseOperation)
    {
        operation.queuePriority = .normal
        operation.qualityOfService = .userInitiated
        add(operation)
    }
    
    func setTimeout(of seconds: Double = CKDatabase.timeoutAfterSeconds,
                    on operation: CKDatabaseOperation)
    {
        operation.configuration.timeoutIntervalForRequest = seconds
        operation.configuration.timeoutIntervalForResource = seconds
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
