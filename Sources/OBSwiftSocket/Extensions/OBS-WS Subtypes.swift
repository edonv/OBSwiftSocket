//
//  OBS-WS Subtypes.swift
//  
//
//  Created by Edon Valdman on 7/10/22.
//

import Foundation

extension OBSRequests.GetSceneList.Response {
    func typedScenes() -> [Scene] {
        return self.scenes.map { try! $0.toCodable(Scene.self) }
    }
    
    struct Scene: Codable, Comparable, Identifiable {
        var id: String {
            return name
        }
        
        var index: Int
        var name: String
        
        enum CodingKeys: String, CodingKey {
            case index = "sceneIndex"
            case name = "sceneName"
        }
        
        static func < (lhs: Scene, rhs: Scene) -> Bool {
            return lhs.index < rhs.index
        }
    }
}
