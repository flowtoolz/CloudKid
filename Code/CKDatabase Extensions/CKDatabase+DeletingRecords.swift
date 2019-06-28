import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func deleteCKRecords(ofType type: String,
                         inZone zoneID: CKRecordZone.ID) -> Promise<DeletionResult>
    {
        return firstly
        {
            queryCKRecords(ofType: type, inZone: zoneID)
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
    
    func deleteCKRecords(with ckRecordIDs: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        guard !ckRecordIDs.isEmpty else
        {
            log(warning: "Tried to delete CKRecords with empty array of IDs.")
            return .value(.empty)
        }
        
        return ckRecordIDs.count > maxBatchSize
            ? deleteCKRecordsInBatches(with: ckRecordIDs)
            : deleteCKRecordsInOneBatch(with: ckRecordIDs)
    }
    
    private func deleteCKRecordsInBatches(with ckRecordIDs: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        let batches = ckRecordIDs.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        let batchPromises = batches.map(deleteCKRecordsInOneBatch)
        
        return firstly
        {
            when(resolved: batchPromises)
        }
        .map(on: queue)
        {
            self.merge(batchPromiseResults: $0, from: batches)
        }
    }

    private func deleteCKRecordsInOneBatch(with ckRecordIDs: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        let operation = CKModifyRecordsOperation(recordsToSave: nil,
                                                 recordIDsToDelete: ckRecordIDs)
        
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
    
    private func merge(batchPromiseResults: [PromiseKit.Result<DeletionResult>],
                       from batches: [[CKRecord.ID]]) -> DeletionResult
    {
        var successes = [CKRecord.ID]()
        var failures = [DeletionFailure]()
        
        for batchIndex in 0 ..< batchPromiseResults.count
        {
            let batchPromiseResult = batchPromiseResults[batchIndex]
            
            switch batchPromiseResult
            {
            case .fulfilled(let deletionResult):
                successes += deletionResult.successes
                failures += deletionResult.failures
            case .rejected(let error):
                failures += batches[batchIndex].map { DeletionFailure($0, error) }
            }
        }
        
        return DeletionResult(successes: successes, failures: failures)
    }
    
    struct DeletionResult
    {
        static var empty: DeletionResult
        {
            return DeletionResult(successes: [], failures: [])
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