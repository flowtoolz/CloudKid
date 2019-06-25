import Foundation
import Reachability
import Network

public class NetworkReachability
{
    // MARK: - Initialization
    
    public static let shared = NetworkReachability()
    
    private init()
    {
        if #available(OSX 10.14, iOS 12.0, tvOS 12.0, *)
        {
            pathMonitor.pathUpdateHandler = notifyObserversWithNetworkPath
            pathMonitor.start(queue: DispatchQueue(label: "Network Reachability Monitor",
                                                   qos: .default))
        }
        else
        {
            initialzeWithReachabilityPod()
        }
    }
    
    // MARK: - Based on Network Framework (Mojave+)
    
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, *)
    private func notifyObserversWithNetworkPath(_ networkPath: NWPath)
    {
        let connectivity: Update =
        {
            guard networkPath.status == .satisfied else { return .noInternet }
            return networkPath.isExpensive ? .expensiveInternet : .fullInternet
        }()
        
        notifyObservers(of: connectivity)
    }
    
    // MARK: - Based On Reachability Cocoapod
    
    private func initialzeWithReachabilityPod()
    {
        guard let reachability = reachability else
        {
            print("ERROR: Reachability object couldn't be created.")
            return
        }
        
        reachability.whenReachable = notifyObserversWithReachability
        reachability.whenUnreachable = notifyObserversWithReachability
        
        do
        {
            try reachability.startNotifier()
        }
        catch let error
        {
            print("ERROR: \(error.localizedDescription)")
        }
    }
    
    private func notifyObserversWithReachability(_ reachability: Reachability)
    {
        let connectivity: Update =
        {
            switch reachability.connection
            {
            case .none: return .noInternet
            case .wifi: return .fullInternet
            case .cellular: return .expensiveInternet
            }
        }()
        
        notifyObservers(of: connectivity)
    }
    
    public var connection: Reachability.Connection?
    {
        return reachability?.connection
    }
    
    private let reachability = Reachability()
    
    // MARK: - Primitive Observability
    
    public func notifyOfChanges(_ observer: AnyObject,
                                action: @escaping (Update) -> Void)
    {
        observers.append(WeakObserver(observer: observer, notify: action))
    }
    
    public func stopNotifying(_ observer: AnyObject)
    {
        // TODO: use SwiftyToolz to properly hash observers
        observers.removeAll { $0.observer === observer }
    }
    
    private func notifyObservers(of connectivity: Update)
    {
        observers.removeAll { $0.observer == nil }
        observers.forEach { $0.notify(connectivity) }
    }
    
    private var observers = [WeakObserver]()
    
    private struct WeakObserver
    {
        weak var observer: AnyObject?
        let notify: (Update) -> Void
    }
    
    public enum Update { case noInternet, expensiveInternet, fullInternet }
}

@available(OSX 10.14, iOS 12.0, tvOS 12.0, *)
private let pathMonitor = NWPathMonitor()
