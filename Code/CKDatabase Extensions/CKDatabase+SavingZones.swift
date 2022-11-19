import CloudKit

public extension CKDatabase
{
    func createZone(withID zoneID: CKRecordZone.ID) async throws -> CKRecordZone
    {
        try await save(CKRecordZone(zoneID: zoneID))
    }
}
