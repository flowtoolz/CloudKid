import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func fetchCKRecords(with ids: [CKRecord.ID]) -> ResultPromise<[CKRecord]>
    {
        let operation = CKFetchRecordsOperation(recordIDs: ids)
        
        operation.perRecordCompletionBlock =
        {
            record, id, error in
            
            // for overall progress updates
        }
        
        return Promise
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
