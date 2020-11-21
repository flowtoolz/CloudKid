import CloudKit
import FoundationToolz
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func queryCKRecords(of type: CKRecord.RecordType,
                        in zone: CKRecordZone.ID) -> SOPromise<Result<[CKRecord], Error>>
    {
        let query = CKQuery(recordType: type, predicate: .all)
        return perform(query, in: zone)
    }
    
    func perform(_ query: CKQuery,
                 in zone: CKRecordZone.ID) -> SOPromise<Result<[CKRecord], Error>>
    {
        perform(query, in: zone, cursor: nil)
    }
    
    private func perform(
        _ query: CKQuery,
        in zone: CKRecordZone.ID,
        cursor: CKQueryOperation.Cursor?)
        -> SOPromise<Result<[CKRecord], Error>>
    {
        promise
        {
            performAndReturnCursor(query, in: zone, cursor: cursor)
        }
        .onSuccess
        {
            (records, newCursor) -> SOPromise<Result<[CKRecord], Error>> in
            
            guard let newCursor = newCursor else
            {
                return .fulfilled(records)
            }
            
            return promise
            {
                self.perform(query, in: zone, cursor: newCursor)
            }
            .mapSuccess
            {
                .success(records + $0)
            }
        }
    }
    
    private func performAndReturnCursor(
        _ query: CKQuery,
        in zone: CKRecordZone.ID,
        cursor: CKQueryOperation.Cursor?
    )
        -> SOPromise<Result<([CKRecord], CKQueryOperation.Cursor?), Error>>
    {
        SOPromise
        {
            promise in
        
            let queryOperation = CKQueryOperation(query: query)
            queryOperation.zoneID = zone
            
            setTimeout(on: queryOperation, or: promise.fulfill)
            
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
                    log(error)
                    log("Fetched \(records.count) records before the error occured.")
                    promise.fulfill(error)
                }
                else
                {
                    promise.fulfill((records, cursor))
                }
            }
            
            self.perform(queryOperation)
        }
    }
}
