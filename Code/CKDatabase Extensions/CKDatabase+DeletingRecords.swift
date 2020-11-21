import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func deleteCKRecords(of type: CKRecord.RecordType,
                         in zone: CKRecordZone.ID) -> SOPromise<Result<DeletionResult, Error>>
    {
        promise
        {
            queryCKRecords(of: type, in: zone)
        }
        .onSuccess
        {
            self.deleteCKRecords(with: $0.map { $0.recordID })
        }
    }
    
    func deleteCKRecords(with ids: [CKRecord.ID]) -> SOPromise<Result<DeletionResult, Error>>
    {
        guard !ids.isEmpty else
        {
            log(warning: "Tried to delete CKRecords with empty array of IDs.")
            return .fulfilled(.empty)
        }
        
        return ids.count > maxBatchSize
            ? deleteCKRecordsInBatches(with: ids)
            : deleteCKRecordsInOneBatch(with: ids)
    }
    
    private func deleteCKRecordsInBatches(with ids: [CKRecord.ID])
        -> SOPromise<Result<DeletionResult, Error>>
    {
        var batches = ids.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        
        var successes = [CKRecord.ID]()
        var failures = [DeletionFailure]()
        
        func deleteSequentially(_ handleCompletion: @escaping () -> Void)
        {
            guard batches.count > 0 else { return handleCompletion() }
            
            let batch = batches.remove(at: 0)
            
            deleteCKRecordsInOneBatch(with: batch).observedOnce
            {
                if case .success(let deletionResult) = $0
                {
                    successes += deletionResult.successes
                    failures += deletionResult.failures
                }
                
                deleteSequentially(handleCompletion)
            }
        }
        
        return SOPromise
        {
            promise in
            
            deleteSequentially
            {
                promise.fulfill(DeletionResult(successes: successes, failures: failures))
            }
        }
    }

    private func deleteCKRecordsInOneBatch(with ids: [CKRecord.ID])
        -> SOPromise<Result<DeletionResult, Error>>
    {
        let operation = CKModifyRecordsOperation(recordsToSave: nil,
                                                 recordIDsToDelete: ids)
        
        return SOPromise
        {
            promise in
            
            setTimeout(on: operation, or: promise.fulfill)
            
            operation.modifyRecordsCompletionBlock =
            {
                _, idsOfDeletedRecords, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                    
                    if error.ckError?.code != .partialFailure
                    {
                        return promise.fulfill(error.ckReadable)
                    }
                }
                
                let successes = idsOfDeletedRecords ?? []
                let failures = self.partialDeletionFailures(from: error)
                let result = DeletionResult(successes: successes, failures: failures)
                
                promise.fulfill(result)
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
