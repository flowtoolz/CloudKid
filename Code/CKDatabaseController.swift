import CloudKit
import PromiseKit
import SwiftObserver
import SwiftyToolz

/**
 A wrapper around a CKDatabase in the default CKContainer
 
 It provides controlled access to the CKDatabase and cares for observability, setup, availability checking and cashing of CKRecord system fields.
 */
public class CKDatabaseController: CustomObservable
{
    // MARK: - Setup
    
    public init(databaseScope: CKDatabase.Scope, cacheName: String)
    {
        switch databaseScope
        {
        case .public:
            ckDatabase = ckContainer.publicCloudDatabase
        case .private:
            ckDatabase = ckContainer.privateCloudDatabase
        case .shared:
            ckDatabase = ckContainer.sharedCloudDatabase
        @unknown default:
            log(error: "Unknown CKDatabase.Scope: \(databaseScope)")
            ckDatabase = ckContainer.privateCloudDatabase
        }
        
        ckRecordSystemFieldsCache = CKRecordSystemFieldsCache(name: cacheName)
    }
    
    public func createZone(with id: CKRecordZone.ID) -> Promise<CKRecordZone>
    {
        return ckDatabase.createZone(with: id)
    }
    
    public func createDatabaseSubscription(withID id: String) -> Promise<CKSubscription>
    {
        return ckDatabase.createSubscription(withID: id)
    }
    
    public func ensureAccountAccess() -> Promise<Void>
    {
        return ckContainer.ensureAccountAccess()
    }
    
    // MARK: - Fetch
    
    public func queryCKRecords(ofType type: CKRecord.RecordType,
                               inZone zoneID: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        return firstly
        {
            ckDatabase.queryCKRecords(ofType: type, inZone: zoneID)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
    }
    
    public func perform(_ query: CKQuery,
                        inZone zoneID: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        return firstly
        {
            ckDatabase.perform(query, inZone: zoneID)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
    }
    
    public func fetchChanges(fromZone zoneID: CKRecordZone.ID) -> Promise<CKDatabase.Changes>
    {
        return firstly
        {
            ckDatabase.fetchChanges(fromZone: zoneID)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0.changedCKRecords)
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.idsOfDeletedCKRecords)
        }
    }
    
    public var hasChangeToken: Bool { return ckDatabase.hasServerChangeToken }
    
    // MARK: - Save and Delete
    
    public func save(_ ckRecords: [CKRecord]) -> Promise<SaveResult>
    {
        return firstly
        {
            ckDatabase.save(ckRecords)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0.successes)
        }
    }
    
    public func deleteCKRecords(ofType type: String,
                                inZone zoneID: CKRecordZone.ID) -> Promise<DeletionResult>
    {
        return firstly
        {
            ckDatabase.deleteCKRecords(ofType: type, inZone: zoneID)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.successes)
        }
    }
    
    public func deleteCKRecords(withIDs ids: [CKRecord.ID]) -> Promise<DeletionResult>
    {
        return firstly
        {
            ckDatabase.deleteCKRecords(with: ids)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.successes)
        }
    }
    
    // MARK: - System Fields Cache
    
    public func getCKRecordWithCachedSystemFields(id: String,
                                                  type: CKRecord.RecordType,
                                                  zoneID: CKRecordZone.ID) -> CKRecord
    {
        return ckRecordSystemFieldsCache.getCKRecord(with: id, type: type, zoneID: zoneID)
    }
    
    private let ckRecordSystemFieldsCache: CKRecordSystemFieldsCache

    // MARK: - Basics: Container and Database
    
    public func perform(_ operation: CKDatabaseOperation)
    {
        ckDatabase.perform(operation)
    }
    
    public var queue: DispatchQueue { return ckDatabase.queue }
    
    private let ckDatabase: CKDatabase
    private let ckContainer = CKContainer.default()
    
    // MARK: - Observability of Notifications
    
    public func handlePushNotification(with userInfo: [String : Any])
    {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else
        {
            return
        }
        
        guard case .database = notification.notificationType,
            let dbNotification = notification as? CKDatabaseNotification
        else
        {
            return log(error: "Received unexpected iCloud notification: \(notification.debugDescription).")
        }
        
        send(dbNotification)
    }
    
    public typealias Message = CKDatabaseNotification?
    public let messenger = Messenger<CKDatabaseNotification?>()
}