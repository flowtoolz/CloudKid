import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKContainer
{
    func ensureAccountAccess() -> Promise<Void>
    {
        firstly
        {
            fetchAccountStatus()
        }
        .map(on: iCloudQueue)
        {
            status -> Void in
            
            let errorMessage: String? =
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
            
            if let errorMessage = errorMessage
            {
                log(error: errorMessage)
                throw errorMessage
            }
        }
    }
    
    func fetchAccountStatus() -> Promise<CKAccountStatus>
    {
        Promise
        {
            resolver in
            
            accountStatus
            {
                status, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                }
                
                resolver.resolve(status, error?.ckReadable)
            }
        }
    }
}

let iCloudQueue = DispatchQueue(label: "iCloud", qos: .userInitiated)
