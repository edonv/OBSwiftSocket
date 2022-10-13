//
//  SessionManager Extensions.swift
//  
//
//  Created by Edon Valdman on 7/29/22.
//

import Foundation
import Combine
import JSONValue
import CombineExtensions

extension OBSSessionManager {
    public func getStudioModeStateOnce() throws -> AnyPublisher<Bool, Error> {
        return try sendRequest(OBSRequests.GetStudioModeEnabled())
            .map(\.studioModeEnabled)
            // If error is thrown because studio mode is not active, replace that error with false
            .replaceError(with: false) { error -> Bool in
                guard case Errors.requestResponseNotSuccess(let status) = error else { return false }
                return status.code == .studioModeNotActive
            }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the state of Studio Mode every time it changes.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `Bool` that re-publishes every time the state of Studio Mode changes.
    public func studioModeStatePublisher() throws -> AnyPublisher<Bool, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.studioModeState }) {
            return pub
        }
        
        // Get initial value
        let pub = try getStudioModeStateOnce()
            // Merge with listener for future values
            .merge(with: try listenForEvent(OBSEvents.StudioModeStateChanged.self, firstOnly: false)
                    .map(\.studioModeEnabled))
            .removeDuplicates()
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.studioModeState = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.studioModeState = pub
        }
        
        return pub
    }
    
    /// A pair of a program and preview scene names. If `previewScene` is `nil`, OBS is in Studio Mode.
    public typealias SceneNamePair = (programScene: String, previewScene: String?)
    
    /// Creates a `Publisher` that returns `SceneNamePair`s every time the current program and preview
    /// scenes change.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `SceneNamePair` that re-publishes every time the current
    /// program and preview scenes change.
    public func currentSceneNamePairPublisher() throws -> AnyPublisher<SceneNamePair, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.currentSceneNamePair }) {
            return pub
        }
        
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
                           try studioModeStatePublisher())
            .scan(nil) { latestOutputPreview, combinedTuple -> String? in
                var (latestPreview, latestProgram, studioModeEnabled) = combinedTuple
                if latestOutputPreview == nil {
                    latestPreview = nil
                }
                
                return studioModeEnabled
                    ? (latestPreview ?? latestProgram)
                    : nil
            }
            .removeDuplicates()
        
        // Combine values together
        let pub = Publishers.CombineLatest(programScene, previewScene)
            .map { $0 as SceneNamePair }
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.currentSceneNamePair = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.currentSceneNamePair = pub
        }
        
        return pub
    }
    
    /// Creates a `Publisher` that returns the current scene list, updating with any changes.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene list that re-publishes every time the list changes.
    public func sceneListPublisher() throws -> AnyPublisher<[OBSRequests.Subtypes.Scene], Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.sceneList }) {
            return pub
        }
        
        // Get initial value
        let getCurrentSceneList = try sendRequest(OBSRequests.GetSceneList())
            .tryMap { try $0.typedScenes() }
        
        // Listen for updates
        let eventListener = try listenForEvent(OBSEvents.SceneListChanged.self, firstOnly: false)
            .tryMap { try $0.typedScenes() }
        
        let pub = Publishers.Merge(getCurrentSceneList, eventListener)
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.sceneList = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.sceneList = pub
        }
        
        return pub
    }
    
    /// Creates a `Publisher` that returns the provided scene's list of scene items, updating with any changes.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameter sceneName: Name of the scene to get the scene list for.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene item list that re-publishes every time the list changes.
    public func sceneItemListPublisher(forScene sceneName: String) throws -> AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.sceneItemList[sceneName] }) {
            return pub
        }
        
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
        
        let pub = Publishers.Merge(getCurrentSceneItemList, eventListener)
            .tryMap { try $0.typedSceneItems() }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.sceneItemList.removeValue(forKey: sceneName)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.sceneItemList[sceneName] = pub
        }
        
        return pub
    }
    
    /// Creates a `Publisher` that returns the active scene's list of scene items, updating with any changes.
    ///
    /// If the active scene changes, the returned `Publisher` will re-publish with the newly-active scene's list.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene item list that re-publishes every time the list or
    /// active scene changes. This includes if Studio Mode is enabled and the preview scene changes.
    public func activeSceneItemListPublisher() throws -> AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.activeSceneItemList }) {
            return pub
        }
        
        let pub = try currentSceneNamePairPublisher()
            .map { $0.previewScene ?? $0.programScene }
            .tryFlatMap { try self.sceneItemListPublisher(forScene: $0) }
            .removeDuplicates()
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.activeSceneItemList = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.activeSceneItemList = pub
        }
        
        return pub
    }
    
    /// A tuple pairing a scene item's enabled and locked statuses.
    public typealias SceneItemStatePair = (isEnabled: Bool, isLocked: Bool)
    
    /// Creates a `Publisher` that returns `SceneItemStatePair`s every time the provided scene item's
    /// state changes.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers. 
    /// - Parameters:
    ///   - sceneName: Name of the scene that the scene item is in.
    ///   - sceneItemId: Unique ID of the scene item.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `SceneItemStatePair` for the requested scene item that
    /// re-publishes every time its state changes.
    public func sceneItemStatePublisher(inScene sceneName: String, withID sceneItemID: Int) throws -> AnyPublisher<SceneItemStatePair, Error> {
        let publisherID = "\(sceneName).\(sceneItemID)"
        if let pub = publisherDataQueue.sync(execute: { publishers.sceneItemState[publisherID] }) {
            return pub
        }
        
        let enabledID = "\(publisherID).enabled"
        let lockedID = "\(publisherID).locked"
        let batch = try sendRequestBatch(requests: [
            OBSRequests.GetSceneItemEnabled(sceneName: sceneName, sceneItemId: sceneItemID)
                .forBatch(withID: enabledID),
            OBSRequests.GetSceneItemLocked(sceneName: sceneName, sceneItemId: sceneItemID)
                .forBatch(withID: lockedID)
        ])
        
        // Get initial enabled value
        let enabledStatus = batch
            .compactMap(\.[enabledID])
            .compactMap { $0 as? OBSRequests.GetSceneItemEnabled.Response }
            .map(\.sceneItemEnabled)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemEnableStateChanged.self, firstOnly: false)
                .filter { event in event.sceneName == sceneName && event.sceneItemId == sceneItemID }
                .map(\.sceneItemEnabled))
        
        // Get initial locked value
        let lockedStatus = batch
            .compactMap(\.[lockedID])
            .compactMap { $0 as? OBSRequests.GetSceneItemLocked.Response }
            .map(\.sceneItemLocked)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemLockStateChanged.self, firstOnly: false)
                .filter { event in event.sceneName == sceneName && event.sceneItemId == sceneItemID }
                .map(\.sceneItemLocked))
        
        // Combine values together
        let pub = Publishers.CombineLatest(enabledStatus, lockedStatus)
            .map { ($0, $1) as SceneItemStatePair }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.sceneItemState.removeValue(forKey: publisherID)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
            publishers.sceneItemState[publisherID] = pub
        }
        
        return pub
    }
}

// MARK: - Specialized Publishers

private struct StudioModeStateKey: PublisherStoreKey {
    typealias Value = AnyPublisher<Bool, Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var studioModeState: AnyPublisher<Bool, Error>? {
        get { self[StudioModeStateKey.self] }
        set { self[StudioModeStateKey.self] = newValue }
    }
}

private struct CurrentSceneNamePairKey: PublisherStoreKey {
    typealias Value = AnyPublisher<OBSSessionManager.SceneNamePair, Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var currentSceneNamePair: AnyPublisher<OBSSessionManager.SceneNamePair, Error>? {
        get { self[CurrentSceneNamePairKey.self] }
        set { self[CurrentSceneNamePairKey.self] = newValue }
    }
}

private struct SceneListKey: PublisherStoreKey {
    typealias Value = AnyPublisher<[OBSRequests.Subtypes.Scene], Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var sceneList: AnyPublisher<[OBSRequests.Subtypes.Scene], Error>? {
        get { self[SceneListKey.self] }
        set { self[SceneListKey.self] = newValue }
    }
}

private struct SceneItemListKey: PublisherStoreKey {
    typealias Value = [String: AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var sceneItemList: [String: AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error>] {
        get { self[SceneItemListKey.self] }
        set { self[SceneItemListKey.self] = newValue }
    }
}

private struct ActiveSceneItemListKey: PublisherStoreKey {
    typealias Value = AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var activeSceneItemList: AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error>? {
        get { self[ActiveSceneItemListKey.self] }
        set { self[ActiveSceneItemListKey.self] = newValue }
    }
}

private struct SceneItemStateKey: PublisherStoreKey {
    typealias Value = [String: AnyPublisher<OBSSessionManager.SceneItemStatePair, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var sceneItemState: [String: AnyPublisher<OBSSessionManager.SceneItemStatePair, Error>] {
        get { self[SceneItemStateKey.self] }
        set { self[SceneItemStateKey.self] = newValue }
    }
}

