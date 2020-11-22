import CloudKit
import SwiftObserver
import SwiftyToolz

public extension CKDatabase
{
    func saveDatabaseSubscription(with id: CKSubscription.ID) -> ResultPromise<CKSubscription>
    {
        save(CKDatabaseSubscription(subscriptionID: id))
    }
    
    private func save(
        _ subscription: CKSubscription,
        desiredKeys: [CKRecord.FieldKey]? = nil) -> ResultPromise<CKSubscription>
    {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.desiredKeys = desiredKeys
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
                                                       subscriptionIDsToDelete: nil)
        
        return Promise
        {
            promise in
            
            operation.modifySubscriptionsCompletionBlock =
            {
                savedSubscriptions, _, error in
                
                if let savedSubscription = savedSubscriptions?.first
                {
                    promise.fulfill(savedSubscription)
                }
                else
                {
                    let error = error ?? "Saving CKSubscription failed"
                    log(error)
                    promise.fulfill(error)
                }
            }
            
            perform(operation)
        }
    }
}
