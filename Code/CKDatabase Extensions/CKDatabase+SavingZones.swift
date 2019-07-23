import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func save(_ zone: CKRecordZone.ID) -> Promise<CKRecordZone>
    {
        let recordZone = CKRecordZone(zoneID: zone)
        
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone],
                                                     recordZoneIDsToDelete: nil)
        
        return Promise
        {
            resolver in
            
            operation.modifyRecordZonesCompletionBlock =
            {
                createdZones, _, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                }
                
                resolver.resolve(error?.ckReadable, createdZones?.first)
            }
            
            perform(operation)
        }
    }
}
