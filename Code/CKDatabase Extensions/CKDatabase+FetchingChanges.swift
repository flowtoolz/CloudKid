import CloudKit
import SwiftyToolz

public extension CKDatabase
{
    // MARK: - Fetch Changes
    
    func fetchChanges(from zone: CKRecordZone.ID) async throws -> Changes
    {
        let token = changeToken(for: zone)

        do
        {
            let changesTuple = try await recordZoneChanges(inZoneWith: zone,
                                                           since: token)
            
            let changedRecords = changesTuple.modificationResultsByID
                .values
                .compactMap { try? $0.get() }
                .map { $0.record }
            
            let idsOfDeletedRecords = changesTuple.deletions.map { $0.recordID }
            
            let changes = Changes(changedCKRecords: changedRecords,
                                  idsOfDeletedCKRecords: idsOfDeletedRecords,
                                  serverChangeToken: changesTuple.changeToken)
         
            save(changes.serverChangeToken, for: zone)
            
            return changes
        }
        catch
        {
            log(error.readable)
            
            // if this failed, it's unclear whether we've "used up" the change token, so we have to resync completely
            save(nil, for: zone)
            
            throw error
        }
    }
    
    // MARK: - Server Change Token Per Zone
    
    func hasChangeToken(for zone: CKRecordZone.ID) -> Bool
    {
        changeToken(for: zone) != nil
    }
    
    func deleteChangeToken(for zone: CKRecordZone.ID)
    {
        save(nil, for: zone)
    }
    
    private func changeToken(for zone: CKRecordZone.ID) -> CKServerChangeToken?
    {
        let tokenKey = defaultsKeyForChangeToken(of: zone)
        guard let tokenData = defaults.data(forKey: tokenKey) else { return nil }
        
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self,
                                                       from: tokenData)
    }

    private func save(_ changeToken: CKServerChangeToken?, for zone: CKRecordZone.ID)
    {
        let tokenKey = defaultsKeyForChangeToken(of: zone)
        
        guard let newToken = changeToken else
        {
            defaults.removeObject(forKey: tokenKey)
            return
        }
        
        do
        {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: newToken,
                                                             requiringSecureCoding: false)
            defaults.set(tokenData, forKey: tokenKey)
        }
        catch
        {
            log(error.readable)
        }
    }
    
    private var defaults: UserDefaults { .standard }
    
    private func defaultsKeyForChangeToken(of zone: CKRecordZone.ID) -> String
    {
        "ChangeTokenForCKRecordZoneID" + zone.zoneName
    }
}

public extension CKDatabase
{
    struct Changes
    {
        public var hasChanges: Bool
        {
            !changedCKRecords.isEmpty || !idsOfDeletedCKRecords.isEmpty
        }
        
        public var changedCKRecords = [CKRecord]()
        public var idsOfDeletedCKRecords = [CKRecord.ID]()
        public var serverChangeToken: CKServerChangeToken? = nil
    }
}
