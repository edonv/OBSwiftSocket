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
/// Observers created in `setUpObservers()` should be end by setting/assigning values to `@Published`
/// properties. That way, the properties themselves can be observed via wrapped `Publishers` in a `UIKit`
/// context.
///
/// In a SwiftUI context, this can be used as a `@StateObject` at the top of the `View` hierarchy
/// that can then be passed via `.environmentObject(_:)`, which would then be received as an
/// `@EnvironmentObject` as needed further down in hierarchy. In this scenario, changes to `@Published`
/// properties will causes the `View` to automatically update as needed.
public protocol StateManagerProtocol: ObservableObject {
    /// Session to be used to observe changes to state.
    var session: OBSSessionManager { get set }
    
    /// Set for storing all observers.
    var observers: Set<AnyCancellable> { get set }
    
    /// Intialize from an existing session.
    ///
    /// This should be used to set `session`, initialize `observers`, and give your `@Published`
    /// properties initial values.
    /// - Parameter session: Reference to an existing session to use.
    init(session: OBSSessionManager)
    
    /// Initialize all state observers.
    ///
    /// It is recommended that you precede all publisher chains with `session.waitUntilConnected`.
    func setUpObservers()
}

public extension StateManagerProtocol {
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
    
    func storeCancellable(_ cancellable: AnyCancellable) {
        cancellable.store(in: &observers)
    }
    
    func storePublisher<P: Publisher>(_ publisher: P,
                                      receiveCompletion: ((Subscribers.Completion<P.Failure>) -> Void)? = nil,
                                      receiveValue: ((P.Output) -> Void)? = nil) {
        publisher
            .sink(receiveCompletion: receiveCompletion ?? { _ in },
                  receiveValue: receiveValue ?? { _ in })
            .store(in: &observers)
    }
}

