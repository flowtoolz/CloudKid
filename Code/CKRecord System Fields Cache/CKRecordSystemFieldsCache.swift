import CloudKit
import Foundation
import FoundationToolz
import SwiftyToolz

// TODO: Possibly improve performance: Load all CKRecords to memory at launch and store them back typically when we save the JSON file ... or/and: do file saving on background thread

class CKRecordSystemFieldsCache
{
    // MARK: - Get CKRecord That Has Correct System Fields
    
    func getCKRecord(for id: CKRecord.ID,
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
        return CKRecord(fromEncodedSystemFields: Data(from: file))
    }
    
    // MARK: - Saving CloudKit Records
    
    @discardableResult
    func save(_ ckRecords: [CKRecord]) -> [URL?]?
    {
        ckRecords.map(save)
    }
    
    @discardableResult
    func save(_ ckRecord: CKRecord) -> URL?
    {
        let ckRecordName = ckRecord.recordID.recordName
        let file = directory.appendingPathComponent(ckRecordName)
        return ckRecord.encodeSystemFields().save(to: file)
    }
    
    // MARK: - Deleting CloudKit Records
    
    // TODO: write unit test for deletion funcs
    func deleteCKRecords(with ids: [CKRecord.ID])
    {
        ids.map
        {
            directory.appendingPathComponent($0.recordName)
        }
        .forEach
        {
            FileManager.default.remove($0)
        }
    }
    
    // MARK: - Configuration
    
    init(directory: URL)
    {
        self.directory = directory
    }
    
    private let directory: URL
}
