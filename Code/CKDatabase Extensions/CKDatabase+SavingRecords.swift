import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    func save(_ records: [CKRecord]) async throws -> SaveResult
    {
        guard !records.isEmpty else
        {
            log(warning: "Tried to save empty array of CKRecords.")
            return .empty
        }
        
        // TODO: review whether save policy is correct
        let saveResults = try await modifyRecords(saving: records,
                                                  deleting: [],
                                                  savePolicy: .allKeys,
                                                  atomically: true).saveResults

        var successes = [CKRecord]()
        var conflicts = [SaveResult.Conflict]()
        var failures = [SaveResult.Failure]()
        
        for saveResult in saveResults
        {
            switch saveResult.value
            {
            case .success(let savedRecord):
                successes += savedRecord
                
            case .failure(let error):
                if let conflict = SaveResult.Conflict(from: error)
                {
                    conflicts += conflict
                }
                else
                {
                    failures += SaveResult.Failure(saveResult.key, error)
                }
            }
        }
        
        return .init(successes: successes,
                     conflicts: conflicts,
                     failures: failures)
    }
    
    struct SaveResult
    {
        public static var empty: SaveResult
        {
            SaveResult(successes: [], conflicts: [], failures: [])
        }
        
        public let successes: [CKRecord]
        
        public let conflicts: [Conflict]
        
        public struct Conflict
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
        
        public let failures: [Failure]
        
        public struct Failure
        {
            init(_ recordID: CKRecord.ID, _ error: Error)
            {
                self.recordID = recordID
                self.error = error
            }
            
            public let recordID: CKRecord.ID
            public let error: Error
        }
    }
}
