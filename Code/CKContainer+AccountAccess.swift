import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKContainer
{
    func ensureAccountAccess() async throws
    {
        switch try await accountStatus()
        {
        case .couldNotDetermine:
            throw "Could not determine iCloud account status."
        case .available:
            break
        case .restricted:
            throw "iCloud account is restricted."
        case .noAccount:
            throw "Cannot access the iCloud account."
        case .temporarilyUnavailable:
            throw "iCloud account is temporarily unavailable."
        @unknown default:
            throw "Unknown account status"
        }
    }
}

let iCloudQueue = DispatchQueue(label: "iCloud", qos: .userInitiated)
