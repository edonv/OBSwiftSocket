//
//  Request Subtypes.swift
//
//
//  Created by Edon Valdman on 7/10/22.
//

import Foundation
import JSONValue

// MARK: - OBSRequests

extension OBSRequests {
    /// Namespace for manually sussed-out subtypes of `Requests` and `RequestResponses`.
    public enum Subtypes {
        /// An item within a scene. Not an input, but a *usage* of an input in a scene.
        public struct SceneItem: Codable, Hashable {
            public init(sourceName: String, sceneItemId: Int, inputKind: String? = nil, sourceType: OBSEnums.SourceType, sceneItemIndex: Int, isGroup: Bool? = nil) {
                self.sourceName = sourceName
                self.sceneItemId = sceneItemId
                self.inputKind = inputKind
                self.sourceType = sourceType
                self.sceneItemIndex = sceneItemIndex
                self.isGroup = isGroup
            }
            
            /// The name of the source/scene item.
            public var sourceName: String
            
            /// The unique ID number of the source/scene item. This stays unique when it's used across
            /// different scenes.
            public var sceneItemId: Int
            
            /// The kind of input for the item. For `SourceType.sceneOrGroup`, this is `nil`.
            public var inputKind: String? // Enums.InputKind?
            
            /// The type of source/scene item.
            ///
            /// Can be a `sceneOrGroup` or an `input`.
            public var sourceType: OBSEnums.SourceType
            
            /// The index of the source/scene item in its list.
            ///
            /// - Note: Reverse-indexed. The higher the index, the most recently added, the higher up
            /// in the list in OBS's UI.
            public var sceneItemIndex: Int
            
            /// For `SourceType.sceneOrGroup`, this dictates if it is a group.
            /// For `SourceType.input`, this is `nil`.
            public var isGroup: Bool?
        }
        
        /// A scene in OBS.
        public struct Scene: Codable, Comparable {
            /// The index of the scene in the scene list.
            ///
            /// - Note: Reverse-indexed. The higher the index, the most recently added, the higher up
            /// in the list in OBS's UI.
            public var sceneIndex: Int
            
            /// The name of the scene.
            public var sceneName: String
            
            public init(sceneIndex: Int, sceneName: String) {
                self.sceneIndex = sceneIndex
                self.sceneName = sceneName
            }
            
            public static func < (lhs: Scene, rhs: Scene) -> Bool {
                return lhs.sceneIndex < rhs.sceneIndex
            }
        }
    }
}

extension OBSRequests.GetSceneList.Response {
    /// Maps the `scenes` property to the `OBSRequests.Subtypes.Scene` subtype.
    /// - Throws: A `DecodingError` if decoding fails.
    /// - Returns: Mapped typed `scenes`.
    public func typedScenes() throws -> [OBSRequests.Subtypes.Scene] {
        return try self.scenes.map { try $0.toCodable(OBSRequests.Subtypes.Scene.self) }
    }
}

extension OBSRequests.GetSceneItemList.Response {
    /// Maps the `sceneItems` property to the `OBSRequests.Subtypes.SceneItem` subtype.
    /// - Throws: A `DecodingError` if decoding fails.
    /// - Returns: Mapped typed `sceneItems`.
    public func typedSceneItems() throws -> [OBSRequests.Subtypes.SceneItem] {
        return try self.sceneItems.map { try $0.toCodable(OBSRequests.Subtypes.SceneItem.self) }
    }
}

extension OBSRequests.GetGroupSceneItemList.Response {
    /// Maps the `sceneItems` property to the `OBSRequests.Subtypes.SceneItem` subtype.
    /// - Throws: A `DecodingError` if decoding fails.
    /// - Returns: Mapped typed `sceneItems`.
    public func typedSceneItems() throws -> [OBSRequests.Subtypes.SceneItem] {
        return try self.sceneItems.map { try $0.toCodable(OBSRequests.Subtypes.SceneItem.self) }
    }
}

extension OBSRequests.SetSceneItemTransform {
    public init(sceneName: String, sceneItemId: Int, sceneItemTransform: OBSRequests.Subtypes.Transform) throws {
        self.sceneName = sceneName
        self.sceneItemId = sceneItemId
        self.sceneItemTransform = try JSONValue.fromCodable(sceneItemTransform)
    }
    
    public func typedTransform() throws -> OBSRequests.Subtypes.Transform {
        return try self.sceneItemTransform.toCodable(OBSRequests.Subtypes.Transform.self)
    }
}

extension OBSRequests.GetSceneItemTransform.Response {
    public func typedTransform() throws -> OBSRequests.Subtypes.Transform {
        return try self.sceneItemTransform.toCodable(OBSRequests.Subtypes.Transform.self)
    }
}

extension OBSEnums {
    /// Type of source/scene item.
    public enum SourceType: String, Codable {
        case sceneOrGroup = "OBS_SOURCE_TYPE_SCENE"
        case input = "OBS_SOURCE_TYPE_INPUT"
    }
}
