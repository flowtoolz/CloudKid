import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKContainer
{
    func ensureAccountAccess() -> SOPromise<Result<Void, Error>>
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
                return .failure(error)
            }
            else
            {
                return .success(())
            }
        }
    }
    
    func fetchAccountStatus() -> SOPromise<Result<CKAccountStatus, Error>>
    {
        SOPromise
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
