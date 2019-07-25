import CloudKit
import Foundation
import FoundationToolz
import SwiftyToolz

// TODO: Possibly improve performance: Load all CKRecords to memory at launch and store them back typically when we save the JSON file ... or/and: do file saving on background thread

public class CKRecordSystemFieldsCache
{
    // MARK: - Get CKRecord That Has Correct System Fields
    
    public func getCKRecord(for id: CKRecord.ID,
                            of type: CKRecord.RecordType) -> CKRecord
    {
        if let existingCKRecord = loadCKRecord(with: id)
        {
            return existingCKRecord
        }
    
        let newCKRecord = CKRecord(recordType: type, recordID: id)
        
        save(newCKRecord)
        
        return newCKRecord
    }
    
    // MARK: - Loading CloudKit Records
    
    private func loadCKRecord(with id: CKRecord.ID) -> CKRecord?
    {
        guard let directory = directory else { return nil }
        let file = directory.appendingPathComponent(id.recordName)
        guard FileManager.default.itemExists(file) else { return nil }
        
        do
        {
            let data = try Data(contentsOf: file)
            return CKRecord(fromSystemFieldEncoding: data)
        }
        catch
        {
            log(error: error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Saving CloudKit Records
    
    @discardableResult
    public func save(_ records: [CKRecord]) -> [URL?]?
    {
        guard let directory = directory else { return nil }
        
        return records.map
        {
            ckRecord in
            
            let recordUUID = ckRecord.recordID.recordName
            let file = directory.appendingPathComponent(recordUUID)
            return ckRecord.systemFieldEncoding.save(to: file)
        }
    }
    
    @discardableResult
    public func save(_ record: CKRecord) -> URL?
    {
        guard let directory = directory else { return nil }
        let recordUUID = record.recordID.recordName
        let file = directory.appendingPathComponent(recordUUID)
        return record.systemFieldEncoding.save(to: file)
    }
    
    // MARK: - Deleting CloudKit Records
    
    // TODO: write unit test for deletion funcs
    @discardableResult
    public func deleteCKRecords(with ids: [CKRecord.ID]) -> Bool
    {
        guard let directory = directory else { return false }
        
        var allGood = true
        
        for id in ids
        {
            let file = directory.appendingPathComponent(id.recordName)
            
            if !FileManager.default.remove(file)
            {
                allGood = false
            }
        }
        
        return allGood
    }
    
    @discardableResult
    public func clean() -> Bool
    {
        guard let directory = directory else { return false }
        
        return FileManager.default.remove(directory)
    }
    
    // MARK: - The CloudKit Record Cache Directory
    
    private(set) lazy var directory: URL? =
    {
        guard let docDirectory = URL.documentDirectory else { return nil }
        let cacheDir = docDirectory.appendingPathComponent(name)
        return FileManager.default.ensureDirectoryExists(cacheDir)
    }()
    
    // MARK: - Configuration
    
    public init(name: String)
    {
        self.name = name
    }
    
    private let name: String
}


