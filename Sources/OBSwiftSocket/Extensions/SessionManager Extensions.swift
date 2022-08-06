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
        if let pub = publishers.studioModeState {
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
                print("Main thread inside on complete?:", Thread.isMainThread)
                self?.publishers.studioModeState = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publishers.studioModeState = pub
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
        let existingPub = publisherDataQueue.sync {
            return publishers.currentSceneNamePair
        }
        if let pub = existingPub {
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
                print("currentSceneNamePair completed, removed from store")
                self?.publishers.currentSceneNamePair = nil
            })
            .shareReplay(1)
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
        if let pub = publishers.sceneList {
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
        
        publishers.sceneList = pub
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
        if let pub = publishers.sceneItemList[sceneName] {
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
        
        publishers.sceneItemList[sceneName] = pub
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
        if let pub = publishers.activeSceneItemList {
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
        
        publishers.activeSceneItemList = pub
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
        if let pub = publishers.sceneItemState[publisherID] {
            return pub
        }
        
        let enabledID = "\(sceneName).\(sceneItemID).enabled"
        let lockedID = "\(sceneName).\(sceneItemID).locked"
        let batch = try sendRequestBatch(requests: [
            OBSRequests.GetSceneItemEnabled(sceneName: sceneName, sceneItemId: sceneItemID)
                .toBatch(withID: enabledID),
            OBSRequests.GetSceneItemLocked(sceneName: sceneName, sceneItemId: sceneItemID)
                .toBatch(withID: lockedID)
        ])
        
        // Get initial enabled value
        let enabledStatus = batch
            .compactMap(\.[enabledID])
            .compactMap { $0 as? OBSRequests.GetSceneItemEnabled.Response }
            .map(\.sceneItemEnabled)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemEnableStateChanged.self, firstOnly: false)
                    .filter { event in event.sceneName == sceneName }
                    .map(\.sceneItemEnabled))
        
        // Get initial locked value
        let lockedStatus = batch
            .compactMap(\.[lockedID])
            .compactMap { $0 as? OBSRequests.GetSceneItemLocked.Response }
            .map(\.sceneItemLocked)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.SceneItemLockStateChanged.self, firstOnly: false)
                    .filter { event in event.sceneName == sceneName }
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
        
        publishers.sceneItemState[publisherID] = pub
        return pub
    }
}
