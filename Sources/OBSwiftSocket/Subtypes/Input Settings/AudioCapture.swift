//
//  AudioCapture.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation

extension InputSettings {
    public enum AudioInputCapture {
        public struct Mac: InputSettingsProtocol {
            public static var type: String { "coreaudio_input_capture" }
            public static var systemImageName: String? { "mic.fill" }
            
            // "default"
            /// Default setting
            public var device_id: String
            
            // No Hidden
        }
        
        public struct Windows: InputSettingsProtocol {
            public static var type: String { "wasapi_input_capture" }
            public static var systemImageName: String? { "mic.fill" }
            
            // "default"
            /// Default setting
            public var device_id: String
            
            // false
            /// Default setting
            public var use_device_timing: Bool
            
            // No Hidden
        }
    }
    
    public enum AudioOutputCapture {
        public struct Mac: InputSettingsProtocol {
            public static var type: String { "coreaudio_output_capture" }
            public static var systemImageName: String? {
                if #available(iOS 14, *) {
                    return "speaker.wave.2.fill"
                } else {
                    return "speaker.2.fill"
                }
            }
            
            // "SoundflowerEngine:0"
            /// - Note: Default setting
            public var device_id: String
            
            // No Hidden
        }
        
        public struct Windows: InputSettingsProtocol {
            public static var type: String { "wasapi_output_capture" }
            public static var systemImageName: String? {
                if #available(iOS 14, *) {
                    return "speaker.wave.2.fill"
                } else {
                    return "speaker.2.fill"
                }
            }
            
            // "default"
            /// - Note: Default setting
            public var device_id: String
            
            // false
            /// - Note: Default setting
            public var use_device_timing: Bool
        }
    }
    
    public struct ApplicationOutputCapture: InputSettingsProtocol {
        public static var type: String { "wasapi_process_output_capture" }
        public static var systemImageName: String? {
            if #available(iOS 14, *) {
                return "speaker.wave.2.circle.fill"
            } else {
                return "speaker.2.fill"
            }
        }
        
        // No Defaults
        
        // "Twitch Chat Overlay:HwndWrapper[TransparentTwitchChatWPF.exe;;b80a529d-72e4-4bff-b36f-adb167d20ee8]:TransparentTwitchChatWPF.exe"
        public var window: String
    }
}
