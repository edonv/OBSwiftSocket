//
//  OBS-WS Subtypes.swift
//  
//
//  Created by Edon Valdman on 7/10/22.
//

import Foundation

extension OBSRequests.GetSceneList.Response {
    public func typedScenes() -> [Scene] {
        return self.scenes.map { try! $0.toCodable(Scene.self) }
    }
    
    public struct Scene: Codable, Comparable {
        public var sceneIndex: Int
        public var sceneName: String
        
        public static func < (lhs: Scene, rhs: Scene) -> Bool {
            return lhs.sceneIndex < rhs.sceneIndex
        }
    }
}

extension OBSEnums {
    public enum SourceType: String, Codable {
        case sceneOrGroup = "OBS_SOURCE_TYPE_SCENE"
        case input = "OBS_SOURCE_TYPE_INPUT"
    }
}

extension OBSRequests {
    public enum Subtypes {
        public struct SceneItem: Codable, Hashable {
            public var sourceName: String
            public var sceneItemId: Int
            /// The kind of input for the item. For `SourceType.sceneOrGroup`, this is `nil`.
            public var inputKind: String? // Enums.InputKind?
            public var sourceType: OBSEnums.SourceType
            public var sceneItemIndex: Int
            /// For `SourceType.sceneOrGroup`, this dictates if it is a group.
            /// For `SourceType.input`, this is `nil`.
            public var isGroup: Bool?
            
    //        public var image: UIImage? {
    //            sourceType.image(isGroup: isGroup, inputKind: inputKind)
    //        }
        }
    }
}

extension OBSRequests.GetSceneItemList.Response {
    public func typedSceneItems() throws -> [OBSRequests.Subtypes.SceneItem] {
        return try self.sceneItems.map { try $0.toCodable(OBSRequests.Subtypes.SceneItem.self) }
    }
}
