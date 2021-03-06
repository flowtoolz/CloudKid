import CloudKit
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
    
    public func create(_ zone: CKRecordZone.ID) -> ResultPromise<CKRecordZone>
    {
        ckDatabase.save(zone)
    }
    
    public func createDatabaseSubscription(with id: CKSubscription.ID)
        -> ResultPromise<CKSubscription>
    {
        ckDatabase.saveDatabaseSubscription(with: id)
    }
    
    public func ensureAccountAccess() -> ResultPromise<Void>
    {
        ckContainer.ensureAccountAccess()
    }
    
    // MARK: - Fetch
    
    public func queryCKRecords(of type: CKRecord.RecordType,
                               in zone: CKRecordZone.ID) -> ResultPromise<[CKRecord]>
    {
        promise
        {
            ckDatabase.queryCKRecords(of: type, in: zone)
        }
        .whenSucceeded
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
        failed:
        {
            log($0)
        }
    }
    
    public func perform(_ query: CKQuery,
                        in zone: CKRecordZone.ID) -> ResultPromise<[CKRecord]>
    {
        promise
        {
            ckDatabase.perform(query, in: zone)
        }
        .whenSucceeded
        {
            self.ckRecordSystemFieldsCache.save($0)
        }
        failed:
        {
            log($0)
        }
    }
    
    public func fetchChanges(from zone: CKRecordZone.ID)
        -> ResultPromise<CKDatabase.Changes>
    {
        promise
        {
            ckDatabase.fetchChanges(from: zone)
        }
        .whenSucceeded
        {
            self.ckRecordSystemFieldsCache.save($0.changedCKRecords)
            self.ckRecordSystemFieldsCache.deleteCKRecords(with: $0.idsOfDeletedCKRecords)
        }
        failed: { _ in }
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
    
    public func save(_ records: [CKRecord]) -> ResultPromise<CKDatabase.SaveResult>
    {
        promise
        {
            ckDatabase.save(records)
        }
        .whenSucceeded
        {
            self.process($0)
        }
        failed: { _ in }
    }
    
    private func process(_ saveResult: CKDatabase.SaveResult)
    {
        ckRecordSystemFieldsCache.save(saveResult.successes)
        
        let conflictingServerRecords = saveResult.conflicts.map { $0.serverRecord }
        ckRecordSystemFieldsCache.save(conflictingServerRecords)
        
        let idsOfRecordsNotSaved = saveResult.partialFailures.map { $0.record.recordID }
        ckRecordSystemFieldsCache.deleteCKRecords(with: idsOfRecordsNotSaved)
    }
    
    public func deleteCKRecords(of type: CKRecord.RecordType,
                                in zone: CKRecordZone.ID)
        -> ResultPromise<CKDatabase.DeletionResult>
    {
        promise
        {
            ckDatabase.deleteCKRecords(of: type, in: zone)
        }
        .whenSucceeded
        {
            self.process($0)
        }
        failed: { _ in }
    }
    
    public func deleteCKRecords(with ids: [CKRecord.ID])
        -> Promise<CKDatabase.DeletionResult>
    {
        let deletionPromise = ckDatabase.deleteCKRecords(with: ids)
        deletionPromise.whenFulfilled(process)
        return deletionPromise
    }
    
    private func process(_ result: CKDatabase.DeletionResult)
    {
        ckRecordSystemFieldsCache.deleteCKRecords(with: result.successes)
        
        let idsOfRecordsNotDeleted = result.partialFailures.map { $0.recordID }
        ckRecordSystemFieldsCache.deleteCKRecords(with: idsOfRecordsNotDeleted)
    }
    
    // MARK: - System Fields Cache
    
    public func getCKRecordWithCachedSystemFields(for id: CKRecord.ID,
                                                  of type: CKRecord.RecordType) -> CKRecord
    {
        ckRecordSystemFieldsCache.getCKRecord(for: id, of: type)
    }
    
    public func clearCachedSystemFields()
    {
        ckRecordSystemFieldsCache.clear()
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
    
    public func handleDatabaseNotification(with userInfo: [String : Any])
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
