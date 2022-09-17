//
//  Event Subtypes.swift
//  
//
//  Created by Edon Valdman on 9/17/22.
//

import Foundation

// MARK: - OBSEvents

extension OBSEvents {
    public enum Subtypes {
        public typealias Scene = OBSRequests.Subtypes.Scene
//        public struct SceneItem: Codable {
//            public init(sceneItemId: Int, sceneItemIndex: Int) {
//                self.sceneItemId = sceneItemId
//                self.sceneItemIndex = sceneItemIndex
//            }
//
//            /// The unique ID number of the source/scene item. This stays unique when it's used across
//            /// different scenes.
//            public var sceneItemId: Int
//
//            /// The index of the source/scene item in its list.
//            ///
//            /// - Note: Reverse-indexed. The higher the index, the most recently added, the higher up
//            /// in the list in OBS's UI.
//            public var sceneItemIndex: Int
//        }
    }
}

extension OBSEvents.SceneListChanged {
    /// Maps the `scenes` property to the `OBSRequests.Subtypes.Scene` subtype.
    /// - Throws: A `DecodingError` if decoding fails.
    /// - Returns: Mapped typed `scenes`.
    public func typedScenes() throws -> [OBSEvents.Subtypes.Scene] {
        return try self.scenes.map { try $0.toCodable(OBSRequests.Subtypes.Scene.self) }
    }
}

//extension OBSEvents.SceneItemListReindexed {
//    /// Maps the `sceneItems` property to the `OBSEvents.Subtypes.SceneItem` subtype.
//    /// - Throws: A `DecodingError` if decoding fails.
//    /// - Returns: Mapped typed `sceneItems`.
//    public func typedSceneItems() throws -> [OBSEvents.Subtypes.SceneItem] {
//        return try self.sceneItems.map { try $0.toCodable(OBSEvents.Subtypes.SceneItem.self) }
//    }
//}

