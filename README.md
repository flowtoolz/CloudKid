![](Documentation/Header/Header.jpg)

## What CloudKid does

* Simplifying basic usage of CloudKit:
  - Ensuring iCloud account access
  - Fetching records
  - Fetching changes
  - Saving records
  - Querying for records
  - Creating zones and subscription
  - Responding to database notifications
* Abstracting away technical details of CloudKit:
  * Local caching of `CKRecord`objects for recommended conflict resolution approach via saving
  * Transforming all asynchronous operations into PromiseKit promises
  * Using proper CloudKit operations for everything, no CloudKit convenience methods internally
  * Providing meaningful result types for `CKModifyRecordsOperation`
  * Catching partial CloudKit errors
  * Splitting batch operations into batches of acceptable size
  * Transforming errors of type `CKError` into readable errors that can be displayed
  * Providing a meaningful result type for change fetches
  * Logging errors exactly where they occur for debugging (instead of only propagating them through promises)
  * Providing and consistently using one serial iCloud `DispatchQueue` to avoid race conditions

