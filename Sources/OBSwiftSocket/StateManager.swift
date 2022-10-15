//
//  StateManager.swift
//  
//
//  Created by Edon Valdman on 8/18/22.
//

import Foundation
import Combine
import CombineExtensions

/// Protocol to use for structuring a class for managing state and observers.
///
/// Observers created in ``StateManagerProtocol/setUpObservers()`` should be end by setting/assigning
/// values to [@Published](https://developer.apple.com/documentation/combine/published) properties.
/// That way, the properties themselves can be observed via wrapped
/// [Publisher](https://developer.apple.com/documentation/combine/publisher)s in a
/// [UIKit](https://developer.apple.com/documentation/uikit) context.
///
/// In a [SwiftUI](https://developer.apple.com/documentation/swiftui) context, this can be used as a
/// [@StateObject](https://developer.apple.com/documentation/swiftui/stateobject) at the top of the
/// [View](https://developer.apple.com/documentation/swiftui/view) hierarchy
/// that can then be passed via [.environmentObject(_:)](https://developer.apple.com/documentation/swiftui/view/environmentobject(_:)),
/// which would then be received as an
/// [@EnvironmentObject](https://developer.apple.com/documentation/swiftui/environmentobject) as needed
/// further down in hierarchy. In this scenario, changes to
/// [@Published](https://developer.apple.com/documentation/combine/published) properties will causes the
/// [View](https://developer.apple.com/documentation/swiftui/view) to automatically update as needed.
public protocol StateManagerProtocol: ObservableObject {
    /// Session to be used to observe changes to state.
    var session: OBSSessionManager { get set }
    
    /// Set for storing all observers.
    var observers: Set<AnyCancellable> { get set }
    
    /// Intialize from an existing session.
    ///
    /// This should be used to set ``StateManagerProtocol/session``, initialize
    /// ``StateManagerProtocol/observers``, and give your
    /// [@Published](https://developer.apple.com/documentation/combine/published) properties initial values.
    /// - Parameter session: Reference to an existing session to use.
    init(session: OBSSessionManager)
    
    /// Initialize all state observers.
    ///
    /// It is recommended that you precede all publisher chains with
    /// ``StateManagerProtocol/session``\.``OBSSessionManager/waitUntilConnected``.
    func setUpObservers()
}

public extension StateManagerProtocol {
    /// Calls ``OBSSessionManager/sendRequest(_:)-4ef80`` on the contained ``StateManagerProtocol/session``.
    /// - Parameters:
    ///   - request: ``OBSRequest`` to send.
    ///   - waitUntilConnected: If `true`, `request` won't be sent until ``OBSSessionManager/waitUntilConnected``
    ///   is `true`.
    /// - Returns: A [Publisher](https://developer.apple.com/documentation/combine/publisher) containing a
    /// response in the form of the associated ``OBSRequest/ResponseType``.
    func sendRequest<R: OBSRequest>(_ request: R, _ waitUntilConnected: Bool = true) -> AnyPublisher<R.ResponseType, Error> {
        if waitUntilConnected {
            return session.waitUntilConnected
                .tryFlatMap { try self.session.sendRequest(request) }
                .eraseToAnyPublisher()
        } else {
            return Just(())
                .setFailureType(to: Error.self)
                .tryFlatMap { try self.session.sendRequest(request) }
                .eraseToAnyPublisher()
        }
    }
    
    /// Stores a [Cancellable](https://developer.apple.com/documentation/combine/cancellable) in ``StateManagerProtocol/observers``.
    ///
    /// This is to provide accessible storage for miscellaneous `Cancellable`s that might not be able to have
    /// local storage.
    func storeCancellable(_ cancellable: AnyCancellable) {
        cancellable.store(in: &observers)
    }
    
    /// Similar to ``StateManagerProtocol/storeCancellable(_:)``, except the
    /// [Cancellable](https://developer.apple.com/documentation/combine/cancellable) is created inside
    /// the function.
    /// - Parameters:
    ///   - publisher: The [Publisher](https://developer.apple.com/documentation/combine/publisher) to store.
    ///   - receiveCompletion: The closure to execute on completion.
    ///   - receiveValue: The closure to execute on receipt of a value.
    func storePublisher<P: Publisher>(_ publisher: P,
                                      receiveCompletion: ((Subscribers.Completion<P.Failure>) -> Void)? = nil,
                                      receiveValue: ((P.Output) -> Void)? = nil) {
        publisher
            .sink(receiveCompletion: receiveCompletion ?? { _ in },
                  receiveValue: receiveValue ?? { _ in })
            .store(in: &observers)
    }
}

