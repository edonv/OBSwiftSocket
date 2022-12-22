//
//  Misc Symbol Links.swift
//  
//
//  Created by Edon Valdman on 10/15/22.
//

import Foundation

// `{1}[A-Z]\w+`{1}
// TODO: In here, search in external JSON file that has keys (like `requestType.{key used in description}`) to the explicit path that should replace it

/// TODO: misc enums that aren't documented like ``OBSRequests/GetPersistentData/realm``
public enum MiscExplicitOverrwrites: String {
    case enums
    case requests
    case events
    
    public static let links: [MiscExplicitOverrwrites: [String: String]] = [
        .enums: [
            // RequestBatchExecutionType
            "RequestBatchExecutionType.serialRealtime.sleepMillis": "OBSRequests/Sleep/sleepMillis",
            "RequestBatchExecutionType.serialFrame.sleepFrames": "OBSRequests/Sleep/sleepFrame",
            
            // RequestStatus
            "RequestStatus.missingRequestType.requestType": "OpDataTypes/Request/type",
            
            // CloseCode
            "CloseCode.unknownOpCode.op": "Message/operation",
            "CloseCode.notIdentified.Identify": "OpDataTypes/Identify",
            "CloseCode.alreadyIdentified.Identify": "OpDataTypes/Identify",
            "CloseCode.alreadyIdentified.Reidentify": "OpDataTypes/Reidentify",
            "CloseCode.authenticationFailed.Identify": "OpDataTypes/Identify",
            
            // OpCode
            "OpCode.identify.Hello": "OpDataTypes/Hello"
        ],
        
        .requests: [
            "GetPersistentData.realm.OBS_WEBSOCKET_DATA_REALM_GLOBAL": "OBSEnums/PersistentDataRealm/global",
            "GetPersistentData.realm.OBS_WEBSOCKET_DATA_REALM_PROFILE": "OBSEnums/PersistentDataRealm/profile",
            
            "SetPersistentData.realm.OBS_WEBSOCKET_DATA_REALM_GLOBAL": "OBSEnums/PersistentDataRealm/global",
            "SetPersistentData.realm.OBS_WEBSOCKET_DATA_REALM_PROFILE": "OBSEnums/PersistentDataRealm/profile",
            
            "SetVideoSettings.baseWidth": "OBSRequests/SetVideoSettings/baseWidth",
            "SetVideoSettings.baseHeight": "OBSRequests/SetVideoSettings/baseHeight",
            
            "BroadcastCustomEvent.CustomEvent": "OBSEvents/CustomEvent",
            
            "CallVendorRequest.Response.vendorName.vendorName": "OBSRequests/CallVendorRequest/vendorName",
            "CallVendorRequest.Response.requestType.requestType": "OBSRequests/CallVendorRequest/requestType",
            
            "Sleep.SERIAL_REALTIME": "OBSEnums/RequestBatchExecutionType/serialRealtime",
            "Sleep.SERIAL_FRAME": "OBSEnums/RequestBatchExecutionType/serialFrame",
            
            "Sleep.sleepMillis.SERIAL_REALTIME": "OBSEnums/RequestBatchExecutionType/serialRealtime",
            "Sleep.sleepFrames.SERIAL_FRAME": "OBSEnums/RequestBatchExecutionType/serialFrame",
            
            "GetInputSettings.defaultInputSettings": "OBSRequests/GetInputDefaultSettings/Response/defaultInputSettings",
            "GetInputSettings.inputSettings": "OBSRequests/GetInputSettings/Response/inputSettings",
            
            "SetInputVolume.inputVolumeMul.inputVolumeDb": "OBSRequests/SetInputVolume/inputVolumeDb",
            "SetInputVolume.inputVolumeDb.inputVolumeMul": "OBSRequests/SetInputVolume/inputVolumeMul",
            
            "GetInputAudioMonitorType.OBS_MONITORING_TYPE_NONE": "OBSEnums/AudioMonitorType/none",
            "GetInputAudioMonitorType.OBS_MONITORING_TYPE_MONITOR_ONLY": "OBSEnums/AudioMonitorType/monitorOnly",
            "GetInputAudioMonitorType.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT": "OBSEnums/AudioMonitorType/monitorAndOutput",
            
            "PressInputPropertiesButton.propertyName": "OBSRequests/PressInputPropertiesButton/propertyName",
            
            "GetMediaInputStatus.OBS_MEDIA_STATE_NONE": "OBSEnums/MediaInputState/none",
            "GetMediaInputStatus.OBS_MEDIA_STATE_PLAYING": "OBSEnums/MediaInputState/playing",
            "GetMediaInputStatus.OBS_MEDIA_STATE_OPENING": "OBSEnums/MediaInputState/opening",
            "GetMediaInputStatus.OBS_MEDIA_STATE_BUFFERING": "OBSEnums/MediaInputState/buffering",
            "GetMediaInputStatus.OBS_MEDIA_STATE_PAUSED": "OBSEnums/MediaInputState/paused",
            "GetMediaInputStatus.OBS_MEDIA_STATE_STOPPED": "OBSEnums/MediaInputState/stopped",
            "GetMediaInputStatus.OBS_MEDIA_STATE_ENDED": "OBSEnums/MediaInputState/ended",
            "GetMediaInputStatus.OBS_MEDIA_STATE_ERROR": "OBSEnums/MediaInputState/error",
            
            "GetSceneItemBlendMode.OBS_BLEND_NORMAL": "OBSEnums/BlendMode/normal",
            "GetSceneItemBlendMode.OBS_BLEND_ADDITIVE": "OBSEnums/BlendMode/additive",
            "GetSceneItemBlendMode.OBS_BLEND_SUBTRACT": "OBSEnums/BlendMode/subtract",
            "GetSceneItemBlendMode.OBS_BLEND_SCREEN": "OBSEnums/BlendMode/screen",
            "GetSceneItemBlendMode.OBS_BLEND_MULTIPLY": "OBSEnums/BlendMode/multiply",
            "GetSceneItemBlendMode.OBS_BLEND_LIGHTEN": "OBSEnums/BlendMode/lighten",
            "GetSceneItemBlendMode.OBS_BLEND_DARKEN": "OBSEnums/BlendMode/darken",
            
            "DuplicateSceneItem.destinationSceneName.sceneName": "OBSRequests/DuplicateSceneItem/sceneName",
            
            "GetSourceScreenshot.imageWidth": "OBSRequests/GetSourceScreenshot/imageWidth",
            "GetSourceScreenshot.imageHeight": "OBSRequests/GetSourceScreenshot/imageHeight",
            
            "SaveSourceScreenshot.imageWidth": "OBSRequests/SaveSourceScreenshot/imageWidth",
            "SaveSourceScreenshot.imageHeight": "OBSRequests/SaveSourceScreenshot/imageHeight",
            
            "GetCurrentSceneTransitionCursor.transitionCursor": "OBSRequests/GetCurrentSceneTransitionCursor/Response/transitionCursor",
            
            "OpenVideoMixProjector.OBS_WEBSOCKET_VIDEO_MIX_TYPE_PREVIEW": "OBSEnums/VideoMixType/preview",
            "OpenVideoMixProjector.OBS_WEBSOCKET_VIDEO_MIX_TYPE_PROGRAM": "OBSEnums/VideoMixType/program",
            "OpenVideoMixProjector.OBS_WEBSOCKET_VIDEO_MIX_TYPE_MULTIVIEW": "OBSEnums/VideoMixType/multiview",
            "OpenVideoMixProjector.projectorGeometry.monitorIndex": "OBSRequests/OpenVideoMixProjector/monitorIndex",
            
            "OpenSourceProjector.projectorGeometry.monitorIndex": "OBSRequests/OpenSourceProjector/monitorIndex",
        ],
        
        .events: [
            "InputAudioMonitorTypeChanged.OBS_MONITORING_TYPE_NONE": "OBSEnums/AudioMonitorType/none",
            "InputAudioMonitorTypeChanged.OBS_MONITORING_TYPE_MONITOR_ONLY": "OBSEnums/AudioMonitorType/monitorOnly",
            "InputAudioMonitorTypeChanged.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT": "OBSEnums/AudioMonitorType/monitorAndOutput",
        ]
    ]
    
    /// Explicitly written-out typings for properties.
    public static let explicitTypes: [MiscExplicitOverrwrites: [String: String]] = [
        .requests: [
            "GetPersistentData.realm": "OBSEnums.PersistentDataRealm",
            
            "GetInputAudioMonitorType.Response.monitorType": "OBSEnums.AudioMonitorType",
            "SetInputAudioMonitorType.monitorType": "OBSEnums.AudioMonitorType",
            
            "GetMediaInputStatus.Response.mediaState": "OBSEnums.MediaInputState",
            
            "GetSceneItemBlendMode.Response.sceneItemBlendMode": "OBSEnums.BlendMode",
            "SetSceneItemBlendMode.sceneItemBlendMode": "OBSEnums.BlendMode",
            
            "OpenVideoMixProjector.videoMixType": "OBSEnums.VideoMixType",
        ],
        
        .events: [
            "InputAudioMonitorTypeChanged.monitorType": "OBSEnums.AudioMonitorType",
        ]
    ]
    
    /// Explicityly written-out types to add to the generated file.
    public static let addlTypes: [MiscExplicitOverrwrites: String] = [
        .enums: """
                public enum PersistentDataRealm: String, Codable {
                    case global = "OBS_WEBSOCKET_DATA_REALM_GLOBAL"
                    case profile = "OBS_WEBSOCKET_DATA_REALM_PROFILE"
                }
                
                public enum AudioMonitorType: String, Codable {
                    case none = "OBS_MONITORING_TYPE_NONE"
                    case monitorOnly = "OBS_MONITORING_TYPE_MONITOR_ONLY"
                    case monitorAndOutput = "OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT"
                }
                
                public enum MediaInputState: String, Codable {
                    case none = "OBS_MEDIA_STATE_NONE"
                    case playing = "OBS_MEDIA_STATE_PLAYING"
                    case opening = "OBS_MEDIA_STATE_OPENING"
                    case buffering = "OBS_MEDIA_STATE_BUFFERING"
                    case paused = "OBS_MEDIA_STATE_PAUSED"
                    case stopped = "OBS_MEDIA_STATE_STOPPED"
                    case ended = "OBS_MEDIA_STATE_ENDED"
                    case error = "OBS_MEDIA_STATE_ERROR"
                }
                
                public enum BlendMode: String, Codable {
                    case normal = "OBS_BLEND_NORMAL"
                    case additive = "OBS_BLEND_ADDITIVE"
                    case subtract = "OBS_BLEND_SUBTRACT"
                    case screen = "OBS_BLEND_SCREEN"
                    case multiply = "OBS_BLEND_MULTIPLY"
                    case lighten = "OBS_BLEND_LIGHTEN"
                    case darken = "OBS_BLEND_DARKEN"
                }
                
                public enum VideoMixType: String, Codable {
                    case preview = "OBS_WEBSOCKET_VIDEO_MIX_TYPE_PREVIEW"
                    case program = "OBS_WEBSOCKET_VIDEO_MIX_TYPE_PROGRAM"
                    case multivieW = "OBS_WEBSOCKET_VIDEO_MIX_TYPE_MULTIVIEW"
                }
                """
    ]
    
//    public static let fullDefinitions: [MiscExplicitOverrwrites: [String: String]] = [
//        .requests: [
//            "GetPersistentData":
//                                """
//                                /// Gets the value of a "slot" from the selected persistent data realm.
//                                /// - Complexity: `2/5`
//                                /// - Version: Latest Supported RPC Version - `1`
//                                /// - Since: Added in v5.0.0
//                                public struct GetPersistentData: OBSRequest {
//                                    public typealias ResponseType = Response
//
//                                    /// The data realm to select. ``OBSEnums/PersistentDataRealm/global`` or ``OBSEnums/PersistentDataRealm/global``
//                                    public var realm: OBSEnums.PersistentDataRealm
//
//                                    /// The name of the slot to retrieve data from
//                                    public var slotName: String
//
//                                    public init(realm: OBSEnums.PersistentDataRealm, slotName: String) {
//                                        self.realm = realm
//                                        self.slotName = slotName
//                                    }
//
//                                    public struct Response: OBSRequestResponse {
//                                        /// Value associated with the slot. `nil` if not set
//                                        public var slotValue: JSONValue?
//                                    }
//                                }
//                                """,
//            "SetPersistentData":
//                                """
//                                /// Sets the value of a "slot" from the selected persistent data realm.
//                                /// - Complexity: `2/5`
//                                /// - Version: Latest Supported RPC Version - `1`
//                                /// - Since: Added in v5.0.0
//                                public struct SetPersistentData: OBSRequest {
//                                    public typealias ResponseType = EmptyResponse
//
//                                    /// The data realm to select. ``OBSEnums/PersistentDataRealm/global`` or ``OBSEnums/PersistentDataRealm/global``
//                                    public var realm: OBSEnums.PersistentDataRealm
//
//                                    /// The name of the slot to retrieve data from
//                                    public var slotName: String
//
//                                    /// The value to apply to the slot
//                                    public var slotValue: JSONValue
//
//                                    public init(realm: OBSEnums.PersistentDataRealm, slotName: String, slotValue: JSONValue) {
//                                        self.realm = realm
//                                        self.slotName = slotName
//                                        self.slotValue = slotValue
//                                    }
//                                }
//                                """
//
//        ]
//    ]
}
