import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func fetchCKRecords(with ids: [CKRecord.ID]) -> SOPromise<Result<[CKRecord], Error>>
    {
        let operation = CKFetchRecordsOperation(recordIDs: ids)
        
        operation.perRecordCompletionBlock =
        {
            record, id, error in
            
            // for overall progress updates
        }
        
        return SOPromise
        {
            promise in
            
            setTimeout(on: operation, or: promise.fulfill)

            operation.fetchRecordsCompletionBlock =
            {
                recordsByID, error in
                
                if let recordsByID = recordsByID
                {
                    promise.fulfill(Array(recordsByID.values))
                }
                else
                {
                    let error: Error = error?.ckError ?? "Fetching CKRecords failed"
                    log(error)
                    promise.fulfill(error)
                }
            }
            
            perform(operation)
        }
    }
}
