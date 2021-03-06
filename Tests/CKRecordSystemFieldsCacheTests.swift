import XCTest
@testable import CloudKid
import CloudKit

class CKRecordSystemFieldsCacheTests: XCTestCase
{
    func testCacheDirectoryExists()
    {
        XCTAssertNotNil(cache.directory)
    }
    
    func testThatCKRecordsCanBeSavedToCacheFolder()
    {
        let id = "\(#function)"
        
        removeCachedFile(with: id)

        let ckRecord = makeTestCKRecord(with: id)
        
        guard let savedFile = cache.save(ckRecord) else
        {
            return XCTFail("Couldn't save record to cache")
        }
        
        XCTAssert(FileManager.default.fileExists(atPath: savedFile.path))
    }
    
    func testThatRetrievingUncachedRecordCreatesANewOne()
    {
        let id = "\(#function)"
        
        guard let file = removeCachedFile(with: id) else
        {
            return XCTFail("Couldn't get file URL")
        }
        
        let newRecord = cache.getCKRecord(with: id,
                                          type: "TestType",
                                          zoneID: testZoneID)
        
        XCTAssertEqual(newRecord.recordID.recordName, id)
        XCTAssert(FileManager.default.fileExists(atPath: file.path))
    }
    
    func testThatMultipleCKRecordsCanBeCached()
    {
        let id1 = "\(#function)1"
        removeCachedFile(with: id1)
        let ckRecord1 = makeTestCKRecord(with: id1)
        
        let id2 = "\(#function)2"
        removeCachedFile(with: id2)
        let ckRecord2 = makeTestCKRecord(with: id2)
        
        guard let savedFiles = cache.save([ckRecord1, ckRecord2]) else
        {
            return XCTFail("Couldn't save records to cache")
        }
        
        XCTAssertEqual(savedFiles.count, 2)
        XCTAssert(FileManager.default.fileExists(atPath: savedFiles[0]?.path ?? "nil URL"))
        XCTAssert(FileManager.default.fileExists(atPath: savedFiles[1]?.path ?? "nil URL"))
        
        let cachedRecord1 = cache.getCKRecord(with: id1,
                                              type: "TestType",
                                              zoneID: testZoneID)
        XCTAssertEqual(cachedRecord1.recordID.recordName, id1)
        
        let cachedRecord2 = cache.getCKRecord(with: id2,
                                              type: "TestType",
                                              zoneID: testZoneID)
        XCTAssertEqual(cachedRecord2.recordID.recordName, id2)
    }
    
    @discardableResult
    private func removeCachedFile(with id: String) -> URL?
    {
        guard let file = cache.directory?.appendingPathComponent(id) else
        {
            return nil
        }
        
        try? FileManager.default.removeItem(at: file)
        XCTAssert(!FileManager.default.fileExists(atPath: file.path))
        
        return file
    }
    
    private func makeTestCKRecord(with id: String) -> CKRecord
    {
        return CKRecord(recordType: "TestRecordType",
                        recordID: CKRecord.ID(recordName: id,
                                              zoneID: testZoneID))
    }
    
    private let testZoneID = CKRecordZone.ID(zoneName: "TestZone",
                                             ownerName: "TestOwner")
    
    // MARK: - The Cache Being Tested
    
    private let cache = CKRecordSystemFieldsCache(name: "iCloud Cache Test")
}
