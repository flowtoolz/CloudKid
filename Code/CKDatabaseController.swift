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
    
    public init(scope: CKDatabase.Scope, cacheName: String)
    {
        switch scope
        {
        case .public:
            ckDatabase = ckContainer.publicCloudDatabase
        case .private:
            ckDatabase = ckContainer.privateCloudDatabase
        case .shared:
            ckDatabase = ckContainer.sharedCloudDatabase
        @unknown default:
            log(error: "Unknown CKDatabase.Scope: \(scope)")
            ckDatabase = ckContainer.privateCloudDatabase
        }
        
        ckRecordSystemFieldsCache = CKRecordSystemFieldsCache(name: cacheName)
    }
    
    public func create(_ zone: CKRecordZone.ID) -> Promise<CKRecordZone>
    {
        return ckDatabase.save(zone)
    }
    
    public func createDatabaseSubscription(with id: CKSubscription.ID) -> Promise<CKSubscription>
    {
        return ckDatabase.saveDatabaseSubscription(with: id)
    }
    
    public func ensureAccountAccess() -> Promise<Void>
    {
        return ckContainer.ensureAccountAccess()
    }
    
    // MARK: - Fetch
    
    public func queryCKRecords(of type: CKRecord.RecordType,
                               in zone: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        return firstly
        {
            ckDatabase.queryCKRecords(of: type, in: zone)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
    }
    
    public func perform(_ query: CKQuery,
                        in zone: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        return firstly
        {
            ckDatabase.perform(query, in: zone)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
    }
    
    public func fetchChanges(from zone: CKRecordZone.ID) -> Promise<CKDatabase.Changes>
    {
        return firstly
        {
            ckDatabase.fetchChanges(from: zone)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0.changedCKRecords)
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.idsOfDeletedCKRecords)
        }
    }
    
    public func hasChangeToken(for zone: CKRecordZone.ID) -> Bool
    {
        return ckDatabase.hasChangeToken(for: zone)
    }
    
    public func deleteChangeToken(for zone: CKRecordZone.ID)
    {
        ckDatabase.deleteChangeToken(for: zone)
    }
    
    // MARK: - Save and Delete
    
    public func save(_ records: [CKRecord]) -> Promise<CKDatabase.SaveResult>
    {
        return firstly
        {
            ckDatabase.save(records)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.save($0.successes)
        }
    }
    
    public func deleteCKRecords(of type: CKRecord.RecordType,
                                in zone: CKRecordZone.ID) -> Promise<CKDatabase.DeletionResult>
    {
        return firstly
        {
            ckDatabase.deleteCKRecords(of: type, in: zone)
        }
        .get(on: ckDatabase.queue)
        {
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.successes)
        }
    }
    
    public func deleteCKRecords(with ids: [CKRecord.ID]) -> Promise<CKDatabase.DeletionResult>
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
    
    public func getCKRecordWithCachedSystemFields(for id: CKRecord.ID,
                                                  of type: CKRecord.RecordType) -> CKRecord
    {
        return ckRecordSystemFieldsCache.getCKRecord(for: id, of: type)
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
    
    // MARK: - Observability of Database Notifications
    
    public func handleDatabaseNotification(with userInfo: JSON)
    {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
            notification.containerIdentifier == ckContainer.containerIdentifier
        else
        {
            return
        }
        
        guard case .database = notification.notificationType,
            let dbNotification = notification as? CKDatabaseNotification
        else
        {
            log(error: "Received CloudKit notification of unexpected type: \(notification.debugDescription).")
            return
        }
        
        guard dbNotification.databaseScope == ckDatabase.databaseScope else
        {
            return
        }
        
        send(.didReceiveDatabaseNotification)
    }
    
    public typealias Message = Event?
    public let messenger = Messenger<Event?>()
    public enum Event { case didReceiveDatabaseNotification }
}
