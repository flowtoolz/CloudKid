import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func save(_ ckRecords: [CKRecord]) -> Promise<CKSaveResult>
    {
        guard !ckRecords.isEmpty else
        {
            log(warning: "Tried to save empty array of CKRecords.")
            return .value(.empty)
        }
        
        return ckRecords.count > maxBatchSize
            ? saveInBatches(ckRecords)
            : saveInOneBatch(ckRecords)
    }
    
    private func saveInBatches(_ ckRecords: [CKRecord]) -> Promise<CKSaveResult>
    {
        let batches = ckRecords.splitIntoSlices(ofSize: maxBatchSize).map(Array.init)
        let batchPromises = batches.map(saveInOneBatch)
        
        return firstly
        {
            when(resolved: batchPromises)
        }
        .map(on: queue)
        {
            self.merge(batchPromiseResults: $0, from: batches)
        }
    }

    private func saveInOneBatch(_ ckRecords: [CKRecord]) -> Promise<CKSaveResult>
    {
        let operation = CKModifyRecordsOperation(recordsToSave: ckRecords,
                                                 recordIDsToDelete: nil)

        var conflicts = [CKSaveConflict]()
        var failures = [CKSaveFailure]()
        
        operation.perRecordCompletionBlock =
        {
            record, error in
            
            guard let error = error else { return }
            
            if let conflict = CKSaveConflict(from: error)
            {
                conflicts.append(conflict)
            }
            else
            {
                failures.append(CKSaveFailure(record, error))
            }
        }
        
        return Promise
        {
            resolver in
            
            setTimeout(on: operation, or: resolver)
            
            operation.modifyRecordsCompletionBlock =
            {
                updatedRecords, _, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                    
                    if error.ckError?.code != .partialFailure
                    {
                        return resolver.reject(error.ckReadable)
                    }
                }
                
                let result = CKSaveResult(successes: updatedRecords ?? [],
                                        conflicts: conflicts,
                                        failures: failures)
                
                resolver.fulfill(result)
            }
            
            perform(operation)
        }
    }
    
    private func merge(batchPromiseResults: [PromiseKit.Result<CKSaveResult>],
                       from batches: [[CKRecord]]) -> CKSaveResult
    {
        var successes = [CKRecord]()
        var conflicts = [CKSaveConflict]()
        var failures = [CKSaveFailure]()
        
        for batchIndex in 0 ..< batchPromiseResults.count
        {
            let batchPromiseResult = batchPromiseResults[batchIndex]
            
            switch batchPromiseResult
            {
            case .fulfilled(let saveResult):
                successes += saveResult.successes
                conflicts += saveResult.conflicts
                failures += saveResult.failures
            case .rejected(let error):
                failures += batches[batchIndex].map { CKSaveFailure($0, error) }
            }
        }
        
        return CKSaveResult(successes: successes,
                            conflicts: conflicts,
                            failures: failures)
    }
}

public struct CKSaveResult
{
    static var empty: CKSaveResult
    {
        return CKSaveResult(successes: [], conflicts: [], failures: [])
    }
    
    public let successes: [CKRecord]
    public let conflicts: [CKSaveConflict]
    public let failures: [CKSaveFailure]
}

public struct CKSaveConflict
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

public struct CKSaveFailure
{
    init(_ record: CKRecord, _ error: Error)
    {
        self.record = record
        self.error = error
    }
    
    public let record: CKRecord
    public let error: Error
}

private let maxBatchSize = 400
