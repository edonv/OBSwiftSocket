//
//  VideoInput.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation

extension InputSettings {
    public enum VideoCapture {
        public struct Mac: InputSettingsProtocol {
            public static var type: String { "av_capture_input" }
            public static var systemImageName: String? { "camera.fill" }
            
            // Defaults
            
            // -1
            /// - Note: Default setting
            public var color_space: Int
            
            // 4294967295
            /// - Note: Default setting
            public var input_format: Int
            
            // "AVCaptureSessionPreset1280x720"
            /// - Note: Default setting
            public var preset: String
            
            // ""
            /// - Note: Default setting
            public var uid: String
            
            // true
            /// - Note: Default setting
            public var use_preset: Bool
            
            // -1
            /// - Note: Default setting
            public var video_range: Int
            
            // Hidden
            
            // "0x14410000046d081b"
            public var device: String
            
            // "USB Camera"
            public var device_name: String
        }
        
        public struct Windows: InputSettingsProtocol {
            public static var type: String { "dshow_input" }
            public static var systemImageName: String? { "camera.fill" }
            
            // Defaults
            
            // true
            /// - Note: Default setting
            public var active: Bool
            // Enum?
            
            // 0
            /// - Note: Default setting
            public var audio_output_mode: Int
            
            // true
            /// - Note: Default setting
            public var autorotation: Bool
            
            // Enum?
            // "default"
            /// - Note: Default setting
            public var color_range: String
            
            // Enum?
            // "default"
            /// - Note: Default setting
            public var color_space: String
            
            // -1
            /// - Note: Default setting
            public var frame_interval: Int
            
            // false
            /// - Note: Default setting
            public var hw_decode: Bool
            
            // Enum?
            // 0
            /// - Note: Default setting
            public var res_type: Int
            
            // Enum?
            // 0
            /// - Note: Default setting
            public var video_format: Int 
            
            // Hidden
            
            // "USB Video Device:\\\\?\\usb#22vid_046d&pid_081b&mi_00#226&2ddef64f&0&0000#22{65e8773d-8f56-11d0-a3b9-00a0c9223196}\\global",
            public var last_video_device_id: WindowsVideoDeviceIdentifier
            
            // "USB Video Device:\\\\?\\usb#22vid_046d&pid_081b&mi_00#226&2ddef64f&0&0000#22{65e8773d-8f56-11d0-a3b9-00a0c9223196}\\global"
            public var video_device_id: WindowsVideoDeviceIdentifier
        }
    }
}
