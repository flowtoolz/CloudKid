import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    // MARK: - Fetch Changes
    
    func fetchChanges(from zone: CKRecordZone.ID) -> ResultPromise<Changes>
    {
        let token = changeToken(for: zone)
        
        return SOPromise
        {
            promise in
            
            let fetch = CKFetchRecordZoneChangesOperation(zone: zone, token: token)
            {
                changes, error in
                
                if let changes = changes
                {
                    self.save(changes.serverChangeToken, for: zone)
                    
                    promise.fulfill(changes)
                }
                else
                {
                    let error: Error = (error?.ckReadable) ?? "Fetching changes failed"
                    log(error)
                    
                    // if this failed, it's unclear whether we've "used up" the change token, so we have to resync completely
                    self.save(nil, for: zone)
                    
                    promise.fulfill(error)
                }
            }
            
            perform(fetch)
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
        let token = NSKeyedUnarchiver.unarchiveObject(with: tokenData)
        return token as? CKServerChangeToken
    }

    private func save(_ changeToken: CKServerChangeToken?, for zone: CKRecordZone.ID)
    {
        let tokenKey = defaultsKeyForChangeToken(of: zone)
        
        guard let newToken = changeToken else
        {
            defaults.removeObject(forKey: tokenKey)
            return
        }
        
        let tokenData = NSKeyedArchiver.archivedData(withRootObject: newToken)
        defaults.set(tokenData, forKey: tokenKey)
    }
    
    private var defaults: UserDefaults { .standard }
    
    private func defaultsKeyForChangeToken(of zone: CKRecordZone.ID) -> String
    {
        "ChangeTokenForCKRecordZoneID" + zone.zoneName
    }
}

private extension CKFetchRecordZoneChangesOperation
{
    convenience init(zone: CKRecordZone.ID,
                     token: CKServerChangeToken?,
                     handleResult: @escaping (CKDatabase.Changes?, Error?) -> Void)
    {
        let zoneOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
        
        zoneOptions.previousServerChangeToken = token
        
        let options = [zone : zoneOptions]

        self.init(recordZoneIDs: [zone], optionsByRecordZoneID: options)
        
        var changes = CKDatabase.Changes()
        
        recordChangedBlock =
        {
            record in changes.changedCKRecords.append(record)
        }
        
        if token != nil // don't report past deletions when fetching changes for the first time
        {
            recordWithIDWasDeletedBlock =
            {
                id, _ in changes.idsOfDeletedCKRecords.append(id)
            }
        }
        
        recordZoneChangeTokensUpdatedBlock =
        {
            zoneID, serverToken, clientToken in
            
            guard zoneID == zone else
            {
                log(error: "Unexpected zone: \(zoneID.zoneName)")
                return
            }
            
            if serverToken != nil
            {
                changes.serverChangeToken = serverToken
            }
        }
        
        recordZoneFetchCompletionBlock =
        {
            zoneID, serverToken, clientToken, _, error in

            guard zoneID == zone else
            {
                log(error: "Unexpected zone: \(zoneID.zoneName)")
                return
            }
            
            if let error = error
            {
                log(error: error.ckReadable.message)
                return
            }
            
            if serverToken != nil
            {
                changes.serverChangeToken = serverToken
            }
        }
        
        fetchRecordZoneChangesCompletionBlock =
        {
            if let error = $0
            {
                log(error: error.ckReadable.message)
                handleResult(nil, error.ckReadable)
                return
            }
            
            handleResult(changes, nil)
        }
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
