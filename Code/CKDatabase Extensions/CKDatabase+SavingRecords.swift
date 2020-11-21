import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func save(_ records: [CKRecord]) -> ResultPromise<SaveResult>
    {
        guard !records.isEmpty else
        {
            log(warning: "Tried to save empty array of CKRecords.")
            return .fulfilled(.empty)
        }
        
        return records.count > maxBatchSize
            ? saveInBatches(records)
            : saveInOneBatch(records)
    }
    
    private func saveInBatches(_ records: [CKRecord]) -> ResultPromise<SaveResult>
    {
        var batches = records.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        
        var successes = [CKRecord]()
        var failures = [SaveFailure]()
        var conflicts = [SaveConflict]()
        
        func saveBatchesSequentially(_ handleCompletion: @escaping () -> Void)
        {
            guard batches.count > 0 else { return handleCompletion() }
            
            let batch = batches.remove(at: 0)
            
            saveInOneBatch(batch).observedOnce
            {
                if case .success(let saveResult) = $0
                {
                    successes += saveResult.successes
                    failures += saveResult.failures
                    conflicts += saveResult.conflicts
                }
            }
        }
        
        
        return SOPromise
        {
            promise in
            
            saveBatchesSequentially
            {
                promise.fulfill(SaveResult(successes: successes,
                                           conflicts: conflicts,
                                           failures: failures))
            }
        }
    }

    private func saveInOneBatch(_ records: [CKRecord]) -> ResultPromise<SaveResult>
    {
        let operation = CKModifyRecordsOperation(recordsToSave: records,
                                                 recordIDsToDelete: nil)

        var conflicts = [SaveConflict]()
        var failures = [SaveFailure]()
        
        operation.perRecordCompletionBlock =
        {
            record, error in
            
            guard let error = error else { return }
            
            if let conflict = SaveConflict(from: error)
            {
                conflicts.append(conflict)
            }
            else
            {
                failures.append(SaveFailure(record, error))
            }
        }
        
        return SOPromise
        {
            promise in
            
            setTimeout(on: operation, or: promise.fulfill)
            
            operation.modifyRecordsCompletionBlock =
            {
                updatedRecords, _, error in
                
                if let error = error
                {
                    log(error.ckReadable)
                    
                    if error.ckError?.code != .partialFailure
                    {
                        return promise.fulfill(error.ckReadable)
                    }
                }
                
                let result = SaveResult(successes: updatedRecords ?? [],
                                        conflicts: conflicts,
                                        failures: failures)
                
                promise.fulfill(result)
            }
            
            perform(operation)
        }
    }
    
    struct SaveResult
    {
        public static var empty: SaveResult
        {
            SaveResult(successes: [], conflicts: [], failures: [])
        }
        
        public let successes: [CKRecord]
        public let conflicts: [SaveConflict]
        public let failures: [SaveFailure]
    }
    
    struct SaveConflict
    {
        init?(from error: Error?)
        {
            guard let ckError = error?.ckError,
                case .serverRecordChanged = ckError.code,
                let clientRecord = ckError.clientRecord,
                let serverRecord = ckError.serverRecord else { return nil }
            
            self.clientRecord = clientRecord
            self.serverRecord = serverRecord
            
            // server can't provide ancestor when client record wasn't fetched from server, because the client record's change tag wouldn't match any previous change tag of that record on the server
            self.ancestorRecord = ckError.ancestorRecord
        }
        
        public let clientRecord: CKRecord
        public let serverRecord: CKRecord
        public let ancestorRecord: CKRecord?
    }
    
    struct SaveFailure
    {
        init(_ record: CKRecord, _ error: Error)
        {
            self.record = record
            self.error = error
        }
        
        public let record: CKRecord
        public let error: Error
    }
}

private let maxBatchSize = 400
