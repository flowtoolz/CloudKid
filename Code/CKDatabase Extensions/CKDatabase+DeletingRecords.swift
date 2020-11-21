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
        .mapSuccess
        {
            .success($0.map { $0.recordID })
        }
        .onSuccess
        {
            self.deleteCKRecords(with: $0).map { .success($0) }
        }
    }
    
    func deleteCKRecords(with ids: [CKRecord.ID]) -> SOPromise<DeletionResult>
    {
        guard !ids.isEmpty else
        {
            log(warning: "Tried to delete CKRecords with empty array of IDs.")
            return .fulfilled(.empty)
        }
        
        let call = ids.count > maxBatchSize ? deleteCKRecordsInBatches : deleteCKRecordsInOneBatch
        
        return SOPromise { call(ids, $0.fulfill) }
    }
    
    private func deleteCKRecordsInBatches(
        with ids: [CKRecord.ID],
        handleResult: @escaping (DeletionResult) -> Void)
    {
        var batches = ids.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        
        var successes = [CKRecord.ID]()
        var failures = [DeletionFailure]()
        var nonPartialErrors = [Error]()
        
        func deleteBatchesSequentially(_ handleCompletion: @escaping () -> Void)
        {
            guard batches.count > 0 else { return handleCompletion() }
            
            let batch = batches.remove(at: 0)
            
            deleteCKRecordsInOneBatch(with: batch)
            {
                deletionResult in
                
                successes += deletionResult.successes
                failures += deletionResult.failures
                nonPartialErrors += deletionResult.nonPartialErrors
                
                deleteBatchesSequentially(handleCompletion)
            }
        }
        
        deleteBatchesSequentially
        {
            handleResult(DeletionResult(successes: successes,
                                        failures: failures,
                                        nonPartialErrors: nonPartialErrors))
        }
    }

    private func deleteCKRecordsInOneBatch(
        with ids: [CKRecord.ID],
        handleResult: @escaping (DeletionResult) -> Void)
    {
        let operation = CKModifyRecordsOperation(recordsToSave: nil,
                                                 recordIDsToDelete: ids)
        
        setTimeout(on: operation) { handleResult(.error($0)) }
        
        operation.modifyRecordsCompletionBlock =
        {
            _, idsOfDeletedRecords, error in
            
            let successes = idsOfDeletedRecords ?? []
            var failures = [DeletionFailure]()
            var nonPartialErrors = [Error]()
            
            if let error = error
            {
                log(error.ckReadable)
                
                if error.ckError?.code == .partialFailure
                {
                    failures = self.partialDeletionFailures(from: error)
                }
                else
                {
                    nonPartialErrors = [error]
                }
            }
            
            handleResult(DeletionResult(successes: successes,
                                        failures: failures,
                                        nonPartialErrors: nonPartialErrors))
        }
        
        perform(operation)
    }
    
    private func partialDeletionFailures(from error: Error) -> [DeletionFailure]
    {
        guard let ckError = error.ckError,
            ckError.code == .partialFailure,
            let errorsByID = ckError.partialErrorsByItemID,
            let errorsByRecordID = errorsByID as? [CKRecord.ID : Error] else { return [] }
        
        return errorsByRecordID.map { DeletionFailure($0.0, $0.1) }
    }
    
    struct DeletionResult
    {
        public static var empty: DeletionResult
        {
            DeletionResult(successes: [], failures: [], nonPartialErrors: [])
        }
        
        public static func error(_ error: Error) -> DeletionResult
        {
            DeletionResult(successes: [], failures: [], nonPartialErrors: [error])
        }
        
        public let successes: [CKRecord.ID]
        public let failures: [DeletionFailure]
        public let nonPartialErrors: [Error]
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
