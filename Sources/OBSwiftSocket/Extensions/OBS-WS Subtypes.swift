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
