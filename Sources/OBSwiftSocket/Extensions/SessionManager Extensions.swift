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
    /// A pair of a program and preview scene names. If `previewScene` is `nil`, OBS is in Studio Mode.
    typealias SceneNamePair = (programScene: String, previewScene: String?)
    
    /// Creates a `Publisher` that returns `SceneNamePair`s every time the current program and preview
    /// scenes change.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `SceneNamePair` that re-publishes every time the current
    /// program and preview scenes change.
    func activeScenePublisher() throws -> AnyPublisher<SceneNamePair, Error> {
        // Get initial program scene
        let programScene = try sendRequest(OBSRequests.GetCurrentProgramScene())
            .map(\.currentProgramSceneName)
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.CurrentProgramSceneChanged.self,
                                            firstOnly: false)
                    .map(\.sceneName))
        
        // Get initial preview scene
        let previewScene = try sendRequest(OBSRequests.GetCurrentPreviewScene())
            .map { $0.currentPreviewSceneName as String? }
            // Catch errors
            // If the error is specifically Errors.requestResponseNotSuccess(.studioModeNotActive), replace with nil
            // Otherwise, pass the error along.
            .catch { error -> AnyPublisher<String?, Error> in
                guard case Errors.requestResponseNotSuccess(let status) = error,
                      status.code == .studioModeNotActive else { return Fail(error: error).eraseToAnyPublisher() }
                return Just(nil)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            // Merge in listener for value changes
            .merge(with: try listenForEvent(OBSEvents.CurrentPreviewSceneChanged.self,
                                            firstOnly: false)
                    .map { $0.sceneName as String? })
        
        return Publishers.Zip(programScene, previewScene)
            .map { $0 as SceneNamePair }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the current scene list, updating with any changes.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene list that re-publishes every time the list changes.
    func sceneListPublisher() throws -> AnyPublisher<[OBSRequests.Subtypes.Scene], Error> {
        // Get initial value
        let getCurrentSceneList = try sendRequest(OBSRequests.GetSceneList())
        
        // Listen for updates to scene list
        let sceneCreatedListener = try listenForEvent(OBSEvents.SceneCreated.self, firstOnly: false)
            .ignoreOutput()
        let sceneRemovedListener = try listenForEvent(OBSEvents.SceneRemoved.self, firstOnly: false)
            .ignoreOutput()
        let sceneNameChangedListener = try listenForEvent(OBSEvents.SceneNameChanged.self, firstOnly: false)
            .ignoreOutput()
        let sceneListChanedListener = try listenForEvent(OBSEvents.SceneListChanged.self, firstOnly: false)
            .ignoreOutput()
        
        let eventListener = Publishers.Merge4(sceneCreatedListener,
                                              sceneRemovedListener,
                                              sceneNameChangedListener,
                                              sceneListChanedListener)
            .tryFlatMap { _ in try self.sendRequest(OBSRequests.GetSceneList()) }
        
        return Publishers.Merge(getCurrentSceneList, eventListener)
            .tryMap { try $0.typedScenes() }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that returns the provided scene's list of scene items, updating with any changes.
    /// - Parameter sceneName: Name of the scene to get the scene list for.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing the scene item list that re-publishes every time the list changes.
    func sceneItemListPublisher(forScene sceneName: String) throws -> AnyPublisher<[OBSRequests.Subtypes.SceneItem], Error> {
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
            .filter { [sceneName] updatedScene in updatedScene == sceneName }
            .ignoreOutput()
            .tryFlatMap { _ in try self.sendRequest(OBSRequests.GetSceneItemList(sceneName: sceneName)) }
        
        return Publishers.Merge(getCurrentSceneItemList, eventListener)
            .tryMap { try $0.typedSceneItems() }
            .eraseToAnyPublisher()
    }
}
