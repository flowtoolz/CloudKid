import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    func fetchCKRecords(with ids: [CKRecord.ID]) async throws -> [CKRecord]
    {
        let fetchResult = try await records(for: ids, desiredKeys: nil)
        
        // TODO: at least log partial errors
        return fetchResult.values.compactMap { try? $0.get() }
    }
}
