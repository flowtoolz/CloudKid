import CloudKit
import FoundationToolz
import SwiftyToolz

public extension CKDatabase
{
    func queryCKRecords(of type: CKRecord.RecordType,
                        in zone: CKRecordZone.ID) async throws -> [CKRecord]
    {
        try await perform(CKQuery(recordType: type, predicate: .all),
                          in: zone)
    }
    
    func perform(_ query: CKQuery,
                 in zone: CKRecordZone.ID) async throws -> [CKRecord]
    {
        let result = try await records(matching: query,
                                       inZoneWith: zone,
                                       desiredKeys: nil)
        
        // TODO: at least log partial errors
        let matchingRecords = result.matchResults.compactMap { try? $0.1.get() }
        
        if let cursor = result.queryCursor // start recursion
        {
            let moreMatchingRecords = try await recursivelyQueryCKRecords(with: cursor)
            return matchingRecords + moreMatchingRecords
        }
        else // no recursion
        {
            return matchingRecords
        }
    }
    
    private func recursivelyQueryCKRecords(with cursor: CKQueryOperation.Cursor) async throws -> [CKRecord]
    {
        let result = try await records(continuingMatchFrom: cursor)
        
        // TODO: at least log partial errors
        let matchingRecords = result.matchResults.compactMap { try? $0.1.get() }
        
        if let anotherCursor = result.queryCursor // recursion
        {
            let moreMatchingRecords = try await recursivelyQueryCKRecords(with: anotherCursor)
            return matchingRecords + moreMatchingRecords
        }
        else // base case
        {
            return matchingRecords
        }
    }
}
