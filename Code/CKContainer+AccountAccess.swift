import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKContainer
{
    func ensureAccountAccess() -> ResultPromise<Void>
    {
        promise
        {
            fetchAccountStatus()
        }
        .mapSuccess
        {
            status in
           
            let potentialErrorMessage: String? =
            {
                switch status
                {
                case .couldNotDetermine: return "Could not determine iCloud account status."
                case .available: return nil
                case .restricted: return "iCloud account is restricted."
                case .noAccount: return "Cannot access the iCloud account."
                @unknown default: return "Unknown account status."
                }
            }()
            
            if let errorMessage = potentialErrorMessage
            {
                let error = ReadableError(errorMessage)
                log(error)
                throw error
            }
        }
    }
    
    func fetchAccountStatus() -> ResultPromise<CKAccountStatus>
    {
        Promise
        {
            promise in
            
            accountStatus
            {
                status, error in
                
                if let error = error
                {
                    log(error)
                    promise.fulfill(error)
                }
                else
                {
                    promise.fulfill(status)
                }
            }
        }
    }
}

let iCloudQueue = DispatchQueue(label: "iCloud", qos: .userInitiated)
