import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func fetchCKRecords(with ids: [CKRecord.ID]) -> Promise<[CKRecord]>
    {
        let operation = CKFetchRecordsOperation(recordIDs: ids)
        
        operation.perRecordCompletionBlock =
        {
            record, id, error in
            
            // for overall progress updates
        }
        
        return Promise
        {
            resolver in
            
            setTimeout(on: operation, or: resolver.reject)

            operation.fetchRecordsCompletionBlock =
            {
                recordsByID, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                }
                
                guard let recordsByID = recordsByID else
                {
                    resolver.resolve([], error?.ckReadable)
                    return
                }
        
                resolver.resolve(Array(recordsByID.values), error?.ckReadable)
            }
            
            perform(operation)
        }
    }
}
