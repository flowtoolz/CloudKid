import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func deleteCKRecords(of type: CKRecord.RecordType,
                         in zone: CKRecordZone.ID) -> Promise<DeletionResult>
    {
        firstly
        {
            queryCKRecords(of: type, in: zone)
        }
        .map(on: queue)
        {
            $0.map { $0.recordID }
        }
        .then(on: queue)
        {
            self.deleteCKRecords(with: $0)
        }
    }
    
    func deleteCKRecords(with ids: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        guard !ids.isEmpty else
        {
            log(warning: "Tried to delete CKRecords with empty array of IDs.")
            return .value(.empty)
        }
        
        return ids.count > maxBatchSize
            ? deleteCKRecordsInBatches(with: ids)
            : deleteCKRecordsInOneBatch(with: ids)
    }
    
    private func deleteCKRecordsInBatches(with ids: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        let batches = ids.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        let batchPromises = batches.map(deleteCKRecordsInOneBatch)
        
        var successes = [CKRecord.ID]()
        var failures = [DeletionFailure]()
        
        var sequentialBatches = Promise()
        
        for batchPromise in batchPromises
        {
            sequentialBatches = sequentialBatches.then
            {
                batchPromise.done
                {
                    deletionResult in
                    
                    successes += deletionResult.successes
                    failures += deletionResult.failures
                }
            }
        }
        
        return sequentialBatches.map
        {
            DeletionResult(successes: successes, failures: failures)
        }
    }

    private func deleteCKRecordsInOneBatch(with ids: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        let operation = CKModifyRecordsOperation(recordsToSave: nil,
                                                 recordIDsToDelete: ids)
        
        return Promise
        {
            resolver in
            
            setTimeout(on: operation, or: resolver)
            
            operation.modifyRecordsCompletionBlock =
            {
                _, idsOfDeletedRecords, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                    
                    if error.ckError?.code != .partialFailure
                    {
                        return resolver.reject(error.ckReadable)
                    }
                }
                
                let successes = idsOfDeletedRecords ?? []
                let failures = self.partialDeletionFailures(from: error)
                let result = DeletionResult(successes: successes, failures: failures)
                
                resolver.fulfill(result)
            }
            
            perform(operation)
        }
    }
    
    private func partialDeletionFailures(from error: Error?) -> [DeletionFailure]
    {
        guard let ckError = error?.ckError,
            ckError.code == .partialFailure,
            let errorsByID = ckError.partialErrorsByItemID,
            let errorsByRecordID = errorsByID as? [CKRecord.ID : Error] else { return [] }
        
        return errorsByRecordID.map { DeletionFailure($0.0, $0.1) }
    }
    
    struct DeletionResult
    {
        public static var empty: DeletionResult
        {
            DeletionResult(successes: [], failures: [])
        }
        
        public let successes: [CKRecord.ID]
        public let failures: [DeletionFailure]
    }

    struct DeletionFailure
    {
        init(_ id: CKRecord.ID, _ error: Error)
        {
            self.recordID = id
            self.error = error
        }
        
        public let recordID: CKRecord.ID
        public let error: Error
    }
}

private let maxBatchSize = 400
