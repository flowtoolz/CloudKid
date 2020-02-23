import CloudKit
import PromiseKit
import SwiftObserver
import SwiftyToolz

/**
 A wrapper around a CKDatabase in the default CKContainer
 
 It provides controlled access to the CKDatabase and cares for observability, setup, availability checking and cashing of CKRecord system fields.
 */
public class CKDatabaseController: Observable
{
    // MARK: - Setup
    
    public init(scope: CKDatabase.Scope, cacheDirectory: URL)
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
        
        ckRecordSystemFieldsCache = CKRecordSystemFieldsCache(directory: cacheDirectory)
    }
    
    public func create(_ zone: CKRecordZone.ID) -> Promise<CKRecordZone>
    {
        ckDatabase.save(zone)
    }
    
    public func createDatabaseSubscription(with id: CKSubscription.ID) -> Promise<CKSubscription>
    {
        ckDatabase.saveDatabaseSubscription(with: id)
    }
    
    public func ensureAccountAccess() -> Promise<Void>
    {
        ckContainer.ensureAccountAccess()
    }
    
    // MARK: - Fetch
    
    public func queryCKRecords(of type: CKRecord.RecordType,
                               in zone: CKRecordZone.ID) -> Promise<[CKRecord]>
    {
        firstly
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
        firstly
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
        firstly
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
        ckDatabase.hasChangeToken(for: zone)
    }
    
    public func deleteChangeToken(for zone: CKRecordZone.ID)
    {
        ckDatabase.deleteChangeToken(for: zone)
    }
    
    // MARK: - Save and Delete
    
    public func save(_ records: [CKRecord]) -> Promise<CKDatabase.SaveResult>
    {
        firstly
        {
            ckDatabase.save(records)
        }
        .get(on: ckDatabase.queue)
        {
            self.process($0)
        }
    }
    
    private func process(_ saveResult: CKDatabase.SaveResult)
    {
        ckRecordSystemFieldsCache.save(saveResult.successes)
        
        let conflictingServerRecords = saveResult.conflicts.map { $0.serverRecord }
        ckRecordSystemFieldsCache.save(conflictingServerRecords)
        
        let idsOfRecordsNotSaved = saveResult.failures.map { $0.record.recordID }
        ckRecordSystemFieldsCache.deleteCKRecords(with: idsOfRecordsNotSaved)
    }
    
    public func deleteCKRecords(of type: CKRecord.RecordType,
                                in zone: CKRecordZone.ID) -> Promise<CKDatabase.DeletionResult>
    {
        firstly
        {
            ckDatabase.deleteCKRecords(of: type, in: zone)
        }
        .get(on: ckDatabase.queue)
        {
            self.process($0)
        }
    }
    
    public func deleteCKRecords(with ids: [CKRecord.ID]) -> Promise<CKDatabase.DeletionResult>
    {
        firstly
        {
            ckDatabase.deleteCKRecords(with: ids)
        }
        .get(on: ckDatabase.queue)
        {
            self.process($0)
        }
    }
    
    private func process(_ result: CKDatabase.DeletionResult)
    {
        ckRecordSystemFieldsCache.deleteCKRecords(with: result.successes)
        
        let idsOfRecordsNotDeleted = result.failures.map { $0.recordID }
        ckRecordSystemFieldsCache.deleteCKRecords(with: idsOfRecordsNotDeleted)
    }
    
    // MARK: - System Fields Cache
    
    public func getCKRecordWithCachedSystemFields(for id: CKRecord.ID,
                                                  of type: CKRecord.RecordType) -> CKRecord
    {
        ckRecordSystemFieldsCache.getCKRecord(for: id, of: type)
    }
    
    private let ckRecordSystemFieldsCache: CKRecordSystemFieldsCache

    // MARK: - Basics: Container and Database
    
    public func perform(_ operation: CKDatabaseOperation)
    {
        ckDatabase.perform(operation)
    }
    
    public var queue: DispatchQueue { ckDatabase.queue }
    
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
    
    public let messenger = Messenger<Event?>()
    public enum Event { case didReceiveDatabaseNotification }
}
