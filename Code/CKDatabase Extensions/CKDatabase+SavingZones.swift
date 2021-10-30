import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func save(_ zone: CKRecordZone.ID) -> ResultPromise<CKRecordZone>
    {
        let recordZone = CKRecordZone(zoneID: zone)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone],
                                                     recordZoneIDsToDelete: nil)
        
        return .init
        {
            promise in
            
            operation.modifyRecordZonesCompletionBlock =
            {
                createdZones, _, error in
                
                if let createdZone = createdZones?.first
                {
                    promise.fulfill(createdZone)
                }
                else
                {
                    let error = error ?? "Saving CKRecordZone failed"
                    log(error)
                    promise.fulfill(error)
                }
            }
            
            perform(operation)
        }
    }
}
