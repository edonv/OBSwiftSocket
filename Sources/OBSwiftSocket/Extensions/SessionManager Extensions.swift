//
//  SessionManager Extensions.swift
//  
//
//  Created by Edon Valdman on 7/29/22.
//

import Foundation
import Combine
import JSONValue

extension OBSSessionManager {
    public func getStudioModeStateOnce() throws -> AnyPublisher<Bool, Error> {
        return try sendRequest(OBSRequests.GetStudioModeEnabled())
            .map(\.studioModeEnabled)
            // If error is thrown because studio mode is not active, replace that error with nil
            .replaceError(with: false) { error -> Bool in
                guard case Errors.requestResponseNotSuccess(let status) = error else { return false }
                return status.code == .studioModeNotActive
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the state of Studio Mode every time it changes.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `Bool` that re-publishes every time the state of Studio Mode changes.
    public func studioModeStatePublisher() throws -> AnyPublisher<Bool, Error> {
        // Get initial value
        return try getStudioModeStateOnce()
            // Merge with listener for future values
            .merge(with: try listenForEvent(OBSEvents.StudioModeStateChanged.self, firstOnly: false)
                    .map(\.studioModeEnabled))
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// A pair of a program and preview scene names. If `previewScene` is `nil`, OBS is in Studio Mode.
    public  typealias SceneNamePair = (programScene: String, previewScene: String?)
    
    /// Creates a `Publisher` that returns `SceneNamePair`s every time the current program and preview
    /// scenes change.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `SceneNamePair` that re-publishes every time the current
    /// program and preview scenes change.
    public func currentSceneNamePairPublisher() throws -> AnyPublisher<SceneNamePair, Error> {
        // Get initial program scene
        let programScene = try sendRequest(OBSRequests.GetCurrentProgramScene())
            .map(\.currentProgramSceneName)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.CurrentProgramSceneChanged.self,
                                            firstOnly: false)
                    .map(\.sceneName))
            .removeDuplicates()
        
        // Get initial preview scene
        let previewScene = try sendRequest(OBSRequests.GetCurrentPreviewScene())
            .map { $0.currentPreviewSceneName as String? }
            // If error is thrown because studio mode is not active, replace that error with nil
            .replaceError(with: nil) { error -> Bool in
                guard case Errors.requestResponseNotSuccess(let status) = error else { return false }
                return status.code == .studioModeNotActive
            }
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.CurrentPreviewSceneChanged.self,
                                            firstOnly: false)
                    .map { $0.sceneName as String? })
            .removeDuplicates()
            .combineLatest(programScene,
                           try studioModeStatePublisher()) { latestPreviewSceneName, latestProgramSceneName, studioModeEnabled -> String? in
                return studioModeEnabled
                    ? (latestPreviewSceneName ?? latestProgramSceneName)
                    : nil
            }
            .removeDuplicates()
        
        // Combine values together
        return Publishers.CombineLatest(programScene, previewScene)
            .map { $0 as SceneNamePair }
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the current scene list, updating with any changes.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene list that re-publishes every time the list changes.
    public func sceneListPublisher() throws -> AnyPublisher<[OBSRequests.Subtypes.Scene], Error> {
        // Get initial value
        let getCurrentSceneList = try sendRequest(OBSRequests.GetSceneList())
            .tryMap { try $0.typedScenes() }
        
        // Listen for updates
        let eventListener = try listenForEvent(OBSEvents.SceneListChanged.self, firstOnly: false)
            .tryMap { try $0.typedScenes() }
        
        return Publishers.Merge(getCurrentSceneList, eventListener)
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the provided scene's list of scene items, updating with any changes.
    /// - Parameter sceneName: Name of the scene to get the scene list for.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene item list that re-publishes every time the list changes.
    public func sceneItemListPublisher(forScene sceneName: String) throws -> AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error> {
        // Get initial value
        let getCurrentSceneItemList = try sendRequest(OBSRequests.GetSceneItemList(sceneName: sceneName))
        
        // Listen for updates to scene item list
        let itemCreatedListener = try listenForEvent(OBSEvents.SceneItemCreated.self, firstOnly: false)
            .map(\.sceneName)
        let itemRemovedListener = try listenForEvent(OBSEvents.SceneItemRemoved.self, firstOnly: false)
            .map(\.sceneName)
        let listReindexedListener = try listenForEvent(OBSEvents.SceneItemListReindexed.self, firstOnly: false)
            .map(\.sceneName)
        
        let eventListener = Publishers.Merge3(itemCreatedListener,
                                              itemRemovedListener,
                                              listReindexedListener)
            // Make sure it was the requested scene that was updated
            .filter { updatedScene in updatedScene == sceneName }
            .tryFlatMap { try self.sendRequest(OBSRequests.GetSceneItemList(sceneName: $0)) }
        
        return Publishers.Merge(getCurrentSceneItemList, eventListener)
            .tryMap { try $0.typedSceneItems() }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the active scene's list of scene items, updating with any changes.
    ///
    /// If the active scene changes, the returned `Publisher` will re-publish with the newly-active scene's list.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene item list that re-publishes every time the list or
    /// active scene changes. This includes if Studio Mode is enabled and the preview scene changes.
    public func activeSceneItemListPublisher() throws -> AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error> {
        try currentSceneNamePairPublisher()
            .map { $0.previewScene ?? $0.programScene }
            .tryFlatMap { try self.sceneItemListPublisher(forScene: $0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// A tuple pairing a scene item's enabled and locked statuses.
    public typealias SceneItemStatePair = (isEnabled: Bool, isLocked: Bool)
    
    /// Creates a `Publisher` that returns `SceneItemStatePair`s every time the provided scene item's
    /// state changes.
    /// - Parameters:
    ///   - sceneName: Name of the scene that the scene item is in.
    ///   - sceneItemId: Unique ID of the scene item.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `SceneItemStatePair` for the requested scene item that
    /// re-publishes every time its state changes.
    public func sceneItemStatePublisher(inScene sceneName: String, with sceneItemId: Int) throws -> AnyPublisher<SceneItemStatePair, Error> {
        // Get initial enabled value
        let enabledStatus = try sendRequest(OBSRequests.GetSceneItemEnabled(sceneName: sceneName, sceneItemId: sceneItemId))
            .map(\.sceneItemEnabled)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemEnableStateChanged.self, firstOnly: false)
                    .filter { [sceneName] event in event.sceneName == sceneName }
                    .map(\.sceneItemEnabled))

        // Get initial locked value
        let lockedStatus = try sendRequest(OBSRequests.GetSceneItemLocked(sceneName: sceneName, sceneItemId: sceneItemId))
            .map(\.sceneItemLocked)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemLockStateChanged.self, firstOnly: false)
                    .filter { [sceneName] event in event.sceneName == sceneName }
                    .map(\.sceneItemLocked))
        
        // Combine values together
        return Publishers.CombineLatest(enabledStatus, lockedStatus)
            .map { ($0, $1) as SceneItemStatePair }
            .eraseToAnyPublisher()
    }
}
