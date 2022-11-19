![](Documentation/Header/Header.jpg)

## What?

CloudKid simplifies basic uses of CloudKit:
 - Ensuring iCloud account access
 - Fetching records
 - Fetching changes
 - Saving records
 - Querying for records
 - Creating zones and subscription
 - Responding to database notifications
 - Resolving data conflicts

## How?

CloudKid abstracts away the technical details of CloudKit:
  * Local caching of `CKRecord`objects for recommended conflict resolution approach via saving
  * Using proper CloudKit operations for everything, no CloudKit convenience methods internally
  * Providing meaningful result types for `CKModifyRecordsOperation`
  * Handling partial CloudKit errors
  * Splitting batch operations into batches of acceptable size
  * Transforming errors of type `CKError` into readable errors that can be displayed
  * Providing a meaningful result type for change fetches
  * Detecting save conflicts and providing a meaningful conflict type for conflict resolution
  * Producing a timeout error in case CloudKit operations don't respond
