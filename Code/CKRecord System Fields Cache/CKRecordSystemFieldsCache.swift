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
        let recordUUID = record.recordID.recordName
        let file = directory.appendingPathComponent(recordUUID)
        return record.systemFieldEncoding.save(to: file)
    }
    
    // MARK: - Deleting CloudKit Records
    
    // TODO: write unit test for deletion funcs
    @discardableResult
    public func deleteCKRecords(with ids: [CKRecord.ID]) -> Bool
    {
        var allGood = true
        
        for id in ids
        {
            let file = directory.appendingPathComponent(id.recordName)
            
            if FileManager.default.itemExists(file) && !FileManager.default.remove(file)
            {
                allGood = false
            }
        }
        
        return allGood
    }
    
    // MARK: - Configuration
    
    public init(directory: URL)
    {
        self.directory = directory
    }
    
    private let directory: URL
}


