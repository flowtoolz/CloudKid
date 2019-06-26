import CloudKit
import SwiftyToolz
import PromiseKit

public extension CKDatabase
{
    // MARK: - Fetch Changes
    
    func fetchChanges(fromZone zoneID: CKRecordZone.ID) -> Promise<Changes>
    {
        return Promise
        {
            resolver in
            
            let token = changeToken(forZone: zoneID)
            
            let fetch = CKFetchRecordZoneChangesOperation(zoneID: zoneID, token: token)
            {
                changes, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                    
                    // if this failed, it's unclear whether we've "used up" the change token, so we have to resync completely
                    self.save(changeToken: nil, forZone: zoneID)
                }
                else
                {
                    self.save(changeToken: changes?.serverChangeToken, forZone: zoneID)
                }
                
                resolver.resolve(changes, error?.ckReadable)
            }
            
            perform(fetch)
        }
    }
    
    // MARK: - Server Change Token Per Zone
    
    func hasChangeToken(forZone zoneID: CKRecordZone.ID) -> Bool
    {
        return changeToken(forZone: zoneID) != nil
    }
    
    private func changeToken(forZone zoneID: CKRecordZone.ID) -> CKServerChangeToken?
    {
        let tokenKey = defaultsKeyForChangeToken(ofZone: zoneID)
        guard let tokenData = defaults.data(forKey: tokenKey) else { return nil }
        let token = NSKeyedUnarchiver.unarchiveObject(with: tokenData)
        return token as? CKServerChangeToken
    }

    private func save(changeToken: CKServerChangeToken?,
                      forZone zoneID: CKRecordZone.ID)
    {
        let tokenKey = defaultsKeyForChangeToken(ofZone: zoneID)
        
        guard let newToken = changeToken else
        {
            defaults.removeObject(forKey: tokenKey)
            return
        }
        
        let tokenData = NSKeyedArchiver.archivedData(withRootObject: newToken)
        defaults.set(tokenData, forKey: tokenKey)
    }
    
    private var defaults: UserDefaults { return UserDefaults.standard }
    
    private func defaultsKeyForChangeToken(ofZone zoneID: CKRecordZone.ID) -> String
    {
        return "ChangeTokenForCKRecordZoneID" + zoneID.zoneName
    }
}

private extension CKFetchRecordZoneChangesOperation
{
    convenience init(zoneID fetchZoneID: CKRecordZone.ID,
                     token: CKServerChangeToken?,
                     handleResult: @escaping (CKDatabase.Changes?, Error?) -> Void)
    {
        let zoneOptions = CKFetchRecordZoneChangesOperation.ZoneOptions()
        
        zoneOptions.previousServerChangeToken = token
        
        let options = [fetchZoneID : zoneOptions]

        self.init(recordZoneIDs: [fetchZoneID], optionsByRecordZoneID: options)
        
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
            
            guard zoneID == fetchZoneID else
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

            guard zoneID == fetchZoneID else
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
        public var changedCKRecords = [CKRecord]()
        public var idsOfDeletedCKRecords = [CKRecord.ID]()
        public var serverChangeToken: CKServerChangeToken? = nil
    }
}
