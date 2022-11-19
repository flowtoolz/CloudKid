import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    func saveDatabaseSubscription(with id: CKSubscription.ID) async throws -> CKSubscription
    {
        try await save(CKDatabaseSubscription(subscriptionID: id))
    }
}
