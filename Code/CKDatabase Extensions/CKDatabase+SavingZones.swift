import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func save(_ zone: CKRecordZone.ID) -> SOPromise<Result<CKRecordZone, Error>>
    {
        let recordZone = CKRecordZone(zoneID: zone)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone],
                                                     recordZoneIDsToDelete: nil)
        
        return SOPromise
        {
            promise in
            
            operation.modifyRecordZonesCompletionBlock =
            {
                createdZones, _, error in
                
                if let createdZone = createdZones?.first
                {
                    promise.fulfill(.success(createdZone))
                }
                else
                {
                    let error = error ?? "Saving CKRecordZone failed"
                    log(error)
                    promise.fulfill(.failure(error))
                }
            }
            
            perform(operation)
        }
    }
}
