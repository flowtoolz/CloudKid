import CloudKit
import SwiftObserver
import SwiftyToolz

/**
 A wrapper around a CKDatabase in the default CKContainer
 
 It provides controlled access to the CKDatabase and cares for observability, setup, availability checking and cashing of CKRecord system fields.
 */
public class CKDatabaseController: SwiftObserver.ObservableObject
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
    
    public func createZone(withID zoneID: CKRecordZone.ID) async throws -> CKRecordZone
    {
        try await ckDatabase.createZone(withID: zoneID)
    }
    
    public func createDatabaseSubscription(with id: CKSubscription.ID) async throws
        -> CKSubscription
    {
        try await ckDatabase.saveDatabaseSubscription(with: id)
    }
    
    public func ensureAccountAccess() async throws
    {
        try await ckContainer.ensureAccountAccess()
    }
    
    // MARK: - Fetch
    
    public func queryCKRecords(of type: CKRecord.RecordType,
                               in zone: CKRecordZone.ID) async throws -> [CKRecord]
    {
        let records = try await ckDatabase.queryCKRecords(of: type, in: zone)
        ckRecordSystemFieldsCache.save(records)
        return records
    }
    
    public func perform(_ query: CKQuery,
                        in zone: CKRecordZone.ID) async throws -> [CKRecord]
    {
        
        let records = try await ckDatabase.perform(query, in: zone)
        ckRecordSystemFieldsCache.save(records)
        return records
    }
    
    public func fetchChanges(from zone: CKRecordZone.ID) async throws
        -> CKDatabase.Changes
    {
        let changes = try await ckDatabase.fetchChanges(from: zone)
        
        ckRecordSystemFieldsCache.save(changes.changedCKRecords)
        ckRecordSystemFieldsCache.deleteCKRecords(with: changes.idsOfDeletedCKRecords)
        
        return changes
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
    
    public func save(_ records: [CKRecord]) async throws -> CKDatabase.SaveResult
    {
        let saveResult = try await ckDatabase.save(records)
        process(saveResult)
        return saveResult
    }
    
    private func process(_ saveResult: CKDatabase.SaveResult)
    {
        ckRecordSystemFieldsCache.save(saveResult.successes)
        
        let conflictingServerRecords = saveResult.conflicts.map { $0.serverRecord }
        ckRecordSystemFieldsCache.save(conflictingServerRecords)
        
        let idsOfRecordsNotSaved = saveResult.failures.map { $0.recordID }
        ckRecordSystemFieldsCache.deleteCKRecords(with: idsOfRecordsNotSaved)
    }
    
    public func deleteCKRecords(of type: CKRecord.RecordType,
                                in zone: CKRecordZone.ID) async throws
        -> CKDatabase.DeletionResult
    {
        
        let deletionResult = try await ckDatabase.deleteCKRecords(of: type, in: zone)
        process(deletionResult)
        return deletionResult
    }
    
    public func deleteCKRecords(with ids: [CKRecord.ID]) async throws
        -> CKDatabase.DeletionResult
    {
        let deletionResult = try await ckDatabase.deleteCKRecords(with: ids)
        process(deletionResult)
        return deletionResult
    }
    
    private func process(_ result: CKDatabase.DeletionResult)
    {
        ckRecordSystemFieldsCache.deleteCKRecords(with: result.successes)
        let idsOfRecordsNotDeleted = Array(result.failures.keys)
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
