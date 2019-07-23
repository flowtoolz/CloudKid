import CloudKit
import FoundationToolz
import SwiftyToolz
import PromiseKit

public extension CKDatabase
{
    func queryCKRecords(of type: CKRecord.RecordType,
                        in zone: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        let query = CKQuery(recordType: type, predicate: .all)
        return perform(query, in: zone)
    }
    
    func perform(_ query: CKQuery, in zone: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        return perform(query, in: zone, cursor: nil)
    }
    
    private func perform(_ query: CKQuery,
                         in zone: CKRecordZone.ID,
                         cursor: CKQueryOperation.Cursor?) -> Promise<[CKRecord]>
    {
        return firstly
        {
            performAndReturnCursor(query, in: zone, cursor: cursor)
        }
        .then(on: queue)
        {
            (records, newCursor) -> Promise<[CKRecord]> in
            
            guard let newCursor = newCursor else
            {
                return .value(records)
            }
            
            return firstly
            {
                self.perform(query, in: zone, cursor: newCursor)
            }
            .map(on: self.queue)
            {
                records + $0
            }
        }
    }
    
    private func performAndReturnCursor(_ query: CKQuery,
                                        in zone: CKRecordZone.ID,
                                        cursor: CKQueryOperation.Cursor?) -> Promise<([CKRecord], CKQueryOperation.Cursor?)>
    {
        return Promise
        {
            resolver in
        
            let queryOperation = CKQueryOperation(query: query)
            queryOperation.zoneID = zone
            
            setTimeout(on: queryOperation, or: resolver)
            
            var records = [CKRecord]()
            
            queryOperation.recordFetchedBlock =
            {
                records.append($0)
            }
            
            queryOperation.queryCompletionBlock =
            {
                cursor, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                    log("Fetched \(records.count) records before the error occured.")
                }
                
                resolver.resolve((records, cursor), error?.ckReadable)
            }
            
            self.perform(queryOperation)
        }
    }
}
