import CloudKit
import PromiseKit
import SwiftyToolz

public extension CKDatabase
{
    func saveDatabaseSubscription(with id: CKSubscription.ID) -> Promise<CKSubscription>
    {
        save(CKDatabaseSubscription(subscriptionID: id))
    }
    
    private func save(_ subscription: CKSubscription,
                      desiredKeys: [CKRecord.FieldKey]? = nil) -> Promise<CKSubscription>
    {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.desiredKeys = desiredKeys
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
                                                       subscriptionIDsToDelete: nil)
        
        return Promise
        {
            resolver in
            
            operation.modifySubscriptionsCompletionBlock =
            {
                savedSubscriptions, _, error in
                
                if let error = error
                {
                    log(error: error.ckReadable.message)
                }
                
                resolver.resolve(savedSubscriptions?.first, error?.ckReadable)
            }
            
            perform(operation)
        }
    }
}
