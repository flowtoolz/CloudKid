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
        
        let save = records.count > maxBatchSize ? saveInBatches : saveInOneBatch
        
        return SOPromise { save(records, $0.fulfill) }
    }
    
    private func saveInBatches(
        _ records: [CKRecord],
        handleResult: @escaping (SaveResult) -> Void)
    {
        var batches = records.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        
        var successes = [CKRecord]()
        var partialFailures = [SaveResult.PartialFailure]()
        var conflicts = [SaveConflict]()
        var nonPartialErrors = [Error]()
        
        func saveBatchesSequentially(_ handleCompletion: @escaping () -> Void)
        {
            guard batches.count > 0 else { return handleCompletion() }
            
            let batch = batches.remove(at: 0)
            
            saveInOneBatch(batch)
            {
                saveResult in
                
                successes += saveResult.successes
                partialFailures += saveResult.partialFailures
                conflicts += saveResult.conflicts
                nonPartialErrors += saveResult.nonPartialErrors
            }
        }
        
        saveBatchesSequentially
        {
            handleResult(.init(successes: successes,
                               conflicts: conflicts,
                               partialFailures: partialFailures,
                               nonPartialErrors: nonPartialErrors))
        }
    }

    private func saveInOneBatch(
        _ records: [CKRecord],
        handleResult: @escaping (SaveResult) -> Void)
    {
        let operation = CKModifyRecordsOperation(recordsToSave: records,
                                                 recordIDsToDelete: nil)

        var conflicts = [SaveConflict]()
        var partialFailures = [SaveResult.PartialFailure]()
        var nonPartialErrors = [Error]()
        
        operation.perRecordCompletionBlock =
        {
            record, error in
            
            guard let error = error else { return }
            
            if let conflict = SaveConflict(from: error)
            {
                conflicts += conflict
            }
            else
            {
                partialFailures += SaveResult.PartialFailure(record, error)
            }
        }
        
        setTimeout(on: operation) { handleResult(.error($0)) }
        
        operation.modifyRecordsCompletionBlock =
        {
            updatedRecords, _, error in
            
            if let error = error
            {
                log(error.ckReadable)
                nonPartialErrors = [error]
            }
            
            handleResult(.init(successes: updatedRecords ?? [],
                               conflicts: conflicts,
                               partialFailures: partialFailures,
                               nonPartialErrors: nonPartialErrors))
        }
        
        perform(operation)
    }
    
    struct SaveResult
    {
        public static var empty: SaveResult
        {
            SaveResult(successes: [],
                       conflicts: [],
                       partialFailures: [],
                       nonPartialErrors: [])
        }
        
        public static func error(_ error: Error) -> SaveResult
        {
            SaveResult(successes: [],
                       conflicts: [],
                       partialFailures: [],
                       nonPartialErrors: [error])
        }
        
        public let successes: [CKRecord]
        public let conflicts: [SaveConflict]
        public let partialFailures: [PartialFailure]
        public let nonPartialErrors: [Error]
        
        public struct PartialFailure
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
}

private let maxBatchSize = 400
