import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    func deleteCKRecords(of type: CKRecord.RecordType,
                         in zone: CKRecordZone.ID) async throws -> DeletionResult
    {
        let records = try await queryCKRecords(of: type, in: zone)
        let recordIDs = records.map { $0.recordID }
        return try await deleteCKRecords(with: recordIDs)
    }
    
    func deleteCKRecords(with ids: [CKRecord.ID]) async throws -> DeletionResult
    {
        guard !ids.isEmpty else
        {
            log(warning: "Tried to delete CKRecords with empty array of IDs.")
            return .empty
        }
        
        let modificationResult = try await modifyRecords(saving: [],
                                                         deleting: ids)
        
        var successes = [CKRecord.ID]()
        var failures = [CKRecord.ID: Error]()
        
        for deleteResult in modificationResult.deleteResults
        {
            switch deleteResult.value
            {
            case .success:
                successes += deleteResult.key
            case .failure(let error):
                log(error.ckReadable)
                failures[deleteResult.key] = error
            }
        }
        return .init(successes: successes, failures: failures)
    }
    
    struct DeletionResult
    {
        public static var empty: DeletionResult
        {
            DeletionResult(successes: [], failures: [:])
        }
        
        public let successes: [CKRecord.ID]
        public let failures: [CKRecord.ID: Error]
    }
}
