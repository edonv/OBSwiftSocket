//
//  main.swift
//  
//
//  Created by Edon Valdman on 6/29/22.
//

import Foundation
import JSONValue

generateProtocol()

class OBSWSProtocol: Codable {
    var enums: [OBSEnum]
    var requests: [OBSRequest]
    var events: [OBSEvent]
    
    internal init(enums: [OBSEnum], requests: [OBSRequest], events: [OBSEvent]) {
        self.enums = enums
        self.requests = requests
        self.events = events
    }
}

struct OBSEnum: Codable {
    var enumType: String
    var enumIdentifiers: [EnumIdentifier]
    
    // TODO: this might need to change for the ones that should be OptionSets
    struct EnumIdentifier: Codable {
        var description: String
        var enumIdentifier: String
        var rpcVersion: JSONValue
        var deprecated: Bool
        var initialVersion: String
        var enumValue: JSONValue
    }
}

func globalFormatCategoryName(_ category: String) -> String {
    guard !category.isEmpty else { return "" }
    return category
        .split(separator: " ")
        .map { String($0).prefix(1).uppercased() + String($0).dropFirst() }
        .joined()
        .replacingOccurrences(of: "Ui", with: "UI")
}

struct OBSRequest: Codable, Hashable {
    var description: String
    var requestType: String
    var complexity: Int
    var rpcVersion: String
    var deprecated: Bool
    var initialVersion: String
    var category: String
    var requestFields: [OBSRequestField]
    var responseFields: [OBSResponseField]
    
    mutating func formatCategoryName() {
        category = globalFormatCategoryName(category)
    }
    
    /// Currently only used for `KeyModifiers`
    func generateSubTypeTypes() -> String? {
        guard !requestFields.isEmpty
                && requestFields.contains(where: { $0.valueName.contains(".") }) else { return nil }
        
        let fieldNames = requestFields.map(\.valueName)
        
        // Ones that have `.`'s (like sub-objects)
        let subTypes = requestFields
            .filter { field -> Bool in
                return fieldNames.contains(where: { $0.contains(field.valueName + ".") })
            }
        let normalFields = requestFields
            .filter { field -> Bool in
                return !subTypes.contains(where: { field.valueName.contains($0.valueName + ".") })
            }
        
        var initParams = [String]()
        var initBody = [String]()
        
        var fullStr = normalFields.map { field -> String in
            var valueType = mapType(field.valueType, nil)
            
            if subTypes.contains(where: { $0.valueName.contains(field.valueName) }) {
                valueType = (field.valueName.prefix(1).uppercased() + field.valueName.dropFirst())
            }
            
            // STILL NEED TO ADD INIT HERE
            initParams.append("\(field.valueName): \(valueType)")
            initBody.append("self.\(field.valueName) = \(field.valueName)")
            
            return [
                field.valueDescription
                    .split(separator: "\n")
                    .map { createTabs(2) + "/// \(String($0))" }
                    .joined(separator: "\n"),
                
                createTabs(2) + "public var \(field.valueName): \(valueType)"
            ].joined(separator: "\n")
        }.joined(separator: "\n\n")
        
        fullStr += "\n\n" + createTabs(2)
            + "public init("
            + initParams
            .joined(separator: ", ")
            + ") {\n"
            + initBody
            .map { createTabs(3) + $0 }
            .joined(separator: "\n")
            + "\n" + createTabs(2) + "}"

        fullStr += subTypes.map { sub -> String in
            let subTypeFields = requestFields
                .filter { $0.valueName.contains(sub.valueName + ".") }
                .map { field -> OBSRequestField in
                    var temp = field
                    temp.valueName = temp.valueName
                        .replacingOccurrences(of: sub.valueName + ".", with: "")
                    return temp
                }
            
            let initParams = subTypeFields.map { field -> String in
                let valueType = mapType(field.valueType, nil)
                return "\(field.valueName): \(valueType)"
            }.joined(separator: ", ")
            
            let initBody = "\n" + subTypeFields.map { field -> String in
                "self.\(field.valueName) = \(field.valueName)"
            }
            .map { createTabs(4) + $0 }
            .joined(separator: "\n")
            
            return "\n\n" + createTabs(2) +
                """
                public struct \(sub.valueName.prefix(1).uppercased() + sub.valueName.dropFirst()): Codable {
                """
                + "\n" + subTypeFields.map { field -> String in
                    let valueType = mapType(field.valueType, nil)
                    
                    return [
                        field.valueDescription
                            .split(separator: "\n")
                            .map { createTabs(3) + "/// \(String($0))" }
                            .joined(separator: "\n"),
                        
                        createTabs(3) + "public var \(field.valueName): \(valueType)"
                    ].joined(separator: "\n")
                }.joined(separator: "\n\n")
                + "\n\n" + createTabs(3)
                + "public init(" + initParams + ") {"
                + initBody
                + "\n" + createTabs(3) + "}"
                + "\n" + createTabs(2) + "}"
        }.joined(separator: "\n\n")
        
        return fullStr
    }
    
    struct OBSRequestField: Codable, Hashable, Equatable {
        var valueName: String
        var valueType: String
        var valueDescription: String
        var valueRestrictions: String?
        var valueOptional: Bool
        var valueOptionalBehavior: String?
    }
    
    struct OBSResponseField: Codable, Hashable {
        var valueName: String
        var valueType: String
        var valueDescription: String
    }
}

struct OBSEvent: Codable {
    var description: String
    var eventType: String
    var eventSubscription: String
    var complexity: Int
    var rpcVersion: String
    var deprecated: Bool
    var initialVersion: String
    var category: String
    var dataFields: [OBSEventField]
    
    mutating func formatCategoryName() {
        category = globalFormatCategoryName(category)
    }
    
    struct OBSEventField: Codable {
        var valueName: String
        var valueType: String
        var valueDescription: String
    }
}

// MARK: - Helper Functions

func camelized(_ string: String) -> String {
    guard !string.isEmpty else { return "" }
    var tempStr = string
    
    if tempStr.contains("_")
        && tempStr.allSatisfy({ $0.isUppercase }) {
        tempStr = tempStr
            .split(separator: "_")
            .map { $0.prefix(1) + $0.dropFirst().lowercased() }
            .joined()
    }
    
    // Catch single words that are all caps
    if tempStr.allSatisfy({ $0.isUppercase }) {
        return tempStr.lowercased()
    }
    
    return tempStr.prefix(1).lowercased() + tempStr.dropFirst()
}

func splitByCapitals(_ string: String) -> [String] {
    return string.reduce(into: []) { arr, char in
        if char.isUppercase || arr.count == 0 {
            arr.append(String(char))
        } else {
            arr[arr.count - 1].append(char)
        }
    }
}

func mapType(_ oldType: String, _ valueRestrictions: String?) -> String {
    let newType = oldType
        .replacingOccurrences(of: "Object", with: "JSONValue")
        .replacingOccurrences(of: "Any", with: "JSONValue")
        .replacingOccurrences(of: "Boolean", with: "Bool")
        .replacingOccurrences(of: #"Array\<"#, with: "[", options: .regularExpression)
        .replacingOccurrences(of: #"\>$"#, with: "]", options: .regularExpression)
    
    if let restrictions = valueRestrictions,
       restrictions.contains(".") {
        return newType
            .replacingOccurrences(of: "Number", with: "Double")
    } else {
        return newType
            .replacingOccurrences(of: "Number", with: "Int")
    }
}

func createTabs(_ numberOfTabs: Int) -> String {
    var str = ""
    for _ in 0..<numberOfTabs {
        str += "    "
    }
    return str
}

/// MARK: - Generating Functions

func generateEnums(_ enums: [OBSEnum]) -> String {
    let fullStr = enums.map { e -> String in
        let enumName = e.enumType
            .replacingOccurrences(of: "WebSocket", with: "")
            .replacingOccurrences(of: "Obs", with: "")
            .replacingOccurrences(of: "Ui", with: "UI")
        
        var header: String
        let body: String
        
        let valueClosure: (OBSEnum.EnumIdentifier) -> String
        
        if e.enumIdentifiers.contains(where: { v in
            guard case .string(let str) = v.enumValue else { return false }
            return str.contains("<")
        }) {
            header =
                """
                public struct \(enumName): OptionSet, Codable {
                    public let rawValue: Int
                    public init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                
                """
                .split(separator: "\n")
                .map { createTabs(1) + $0 }
                .joined(separator: "\n")
                + "\n"
            
            valueClosure = { enumId -> String in
                if case .string(let str) = enumId.enumValue {
                    if str.contains("|") {
                        // Example: [.general, .config, .scenes, .inputs, .transitions, .filters, .outputs, .sceneItems, .mediaInputs, .vendors]
                        let value = "[." + str
                            .replacingOccurrences(of: "(", with: "")
                            .replacingOccurrences(of: ")", with: "")
                            .replacingOccurrences(of: " ", with: "")
                            .split(separator: "|")
                            .map { camelized(String($0)) }
                            .joined(separator: ", .") + "]"
                        
                        return "public static let \(camelized(enumId.enumIdentifier)): \(enumName) = \(value)"
                    } else {
                        let value = str
                            .replacingOccurrences(of: "(", with: "")
                            .replacingOccurrences(of: ")", with: "")
                        
                        return "public static let \(camelized(enumId.enumIdentifier)) = \(enumName)(rawValue: \(value))"
                    }
                } else if case .int(let i) = enumId.enumValue {
                    return "public static let \(camelized(enumId.enumIdentifier)) = \(i)"
                } else {
                    return ""
                }
            }
        } else {
            header = createTabs(1) + "public enum \(enumName): Int, Codable {"
            
            valueClosure = { enumId -> String in
                let value: String
                var identifier = enumId.enumIdentifier
                    .replacingOccurrences(of: "WEBSOCKET_", with: "")
                    .replacingOccurrences(of: "OBS_", with: "")
                
                // split by capital letters
                for substring in splitByCapitals(enumName) {
                    if let range = identifier.lowercased().range(of: substring.lowercased()) {
                        identifier.removeSubrange(range)
//                        identifier = identifier
//                            .replacingOccurrences(of: "__", with: "_")
                        
//                        while identifier.prefix(1) == "_" {
                        identifier = String(identifier.drop(while: { $0 == "_" }))
//                            identifier = String(identifier.dropFirst())
//                        }
                    }
                }
                
                switch enumId.enumValue {
                case .string(let str):
                    value = Int(str) != nil ? "\(Int(str)!)" : "\"\(str)\""
                case .int(let i):
                    value = "\(i)"
                default:
                    return ""
                }
                
                return "case \(camelized(identifier)) = \(value)"
            }
        }
        
        body = e.enumIdentifiers
            .map { c -> String in
                let rpcVersion: Int = {
                    switch c.rpcVersion {
                    case .string(let str):
                        return Int(str)!
                    case .int(let i):
                        return i
                    default:
                        return 0
                    }
                }()
                
                
                var string = [
                    // /// An input has been created.
                    c.description
                        .replacingOccurrences(of: "Note:", with: "- Note:")
                        .split(separator: "\n")
                        .map { String($0) },
                    [
                        // /// - Latest Supported RPC Version: `1`
                        "- Version: Latest Supported RPC Version - `\(rpcVersion)`",
                        
                        // /// - Added in v5.0.0
                        "- Since: Added in v\(c.initialVersion)",
                    ]
                ]
                .flatMap { $0 }
                .map { "\(createTabs(2))/// " + $0 }
                .joined(separator: "\n")
                
                string += "\n" + createTabs(2) + valueClosure(c) // case hello = 0
                return string
            }.joined(separator: "\n\n")
        
        if e.enumIdentifiers.allSatisfy({ enumId -> Bool in
            guard case .string = enumId.enumValue else { return false }
            return true
        }) {
            header = header
                .replacingOccurrences(of: "Int", with: "String")
        }
        
        return [
            header,
            body,
            createTabs(1) + "}"
        ]
        .joined(separator: "\n")
        .replacingOccurrences(of: "``", with: "`")
    }.joined(separator: "\n\n")
    
    return
        """
        public enum OBSEnums {
        \(fullStr)
        }
        """
}

func generateRequests(_ reqs: [OBSRequest]) -> String {
    // Fields to skip (if not empty, generate custom encode decode functions)
    var fieldsToSkip = [OBSRequest: [OBSRequest.OBSRequestField]]()
    
    let fullStr = reqs.map { r -> String in
        let reqName = r.requestType
        
        var finalStr =
            """
            \(r.description
                // .replacingOccurrences(of: "\n\n", with: "\n")
                .replacingOccurrences(of: "Note:", with: "- Note:")
                .split(separator: "\n")
                .map { "/// \(String($0))" }
                .joined(separator: "\n///\n")
                .replacingOccurrences(of: "///\n/// -", with: "/// -"))
            
            /// - Complexity: `\(r.complexity)/5`
            /// - Version: Latest Supported RPC Version - `\(r.rpcVersion)`
            /// - Since: Added in v\(r.initialVersion)
            public struct \(reqName): OBSRequest {
                public typealias ResponseType = \(r.responseFields.isEmpty ? "EmptyResponse" : "Response")
            """
            .split(separator: "\n")
            .map { createTabs(1) + $0 }
            .joined(separator: "\n")
        
        if !r.requestFields.isEmpty {
            if let typesWithSubTypes = r.generateSubTypeTypes() {
                finalStr += "\n\n" + typesWithSubTypes
            } else {
                var initParams = [String]()
                var initBody = [String]()
                
                // Request Fields
                let reqFields = r.requestFields.map { field -> String in
                    var valueType = mapType(field.valueType, field.valueRestrictions)
                    
                    if let range = field.valueDescription.range(of: #"(`\w+`) enum"#, options: .regularExpression) {
                        let substring = String(field.valueDescription[range])
                            .replacingOccurrences(of: "`", with: "")
                            .replacingOccurrences(of: " enum", with: "")
                            .replacingOccurrences(of: "Obs", with: "")
                        valueType = "OBSEnums." + substring
                    }
                    
                    var optionalTerm = "Optional"
                    // If valueOptional is false && valueDescription contains "null", add a `?` to the type
                    // || if valueOptional is true && valueDescription doesn't contain "null", add a `?` to the type
                    if (!field.valueOptional && field.valueDescription.contains("null"))
                        || (field.valueOptional && !field.valueDescription.contains("null")) {
                        valueType += "?"
                    } else if field.valueOptional && field.valueDescription.contains("null") {
                        // If valueOptional is true && valueDescription contains "null", make the type `Excludable<\(valueType)>`
                        valueType = "Excludable<\(valueType)>"
                        optionalTerm = "Excluded"
                    }
                    
                    // In addition...
                    // if valueOptional is true && valueDescription doesn't contain "null"...
                    // OR if valueOptional is true && valueDescription contains "null" (needs to be specially marked for Ignorable type)
                    // this means that the property shouldn't be included in the payload
                    // SO add custom encode/decode functions that use `encodeIfPresent`/`decodeIfPresent` on that property (still mark as optional `?`)
                    
                    if field.valueOptional {
                        // the `if` is abbreviated because it might as well be
                    // if (field.valueOptional && !field.valueDescription.contains("null"))
                       //  || (field.valueOptional && field.valueDescription.contains("null")) {
                        fieldsToSkip[r, default: []].append(field)
                    }
                    
                    initParams.append("\(field.valueName): \(valueType)")
                    initBody.append("self.\(field.valueName) = \(field.valueName)")
                    
                    return [
                        field.valueDescription
                            .replacingOccurrences(of: "TODO", with: "- ToDo")
                            .replacingOccurrences(of: "Note", with: "- Note")
                            .replacingOccurrences(of: "**Very important note**", with: "- Important")
                            .replacingOccurrences(of: "\n-", with: "-")
//                            .replacingOccurrences(of: "null", with: "`nil`")
//                            .replacingOccurrences(of: "``", with: "`")
                            .split(separator: "\n")
                            .map { "/// " + $0 }
                            .joined(separator: "\n"),
                        
                        field.valueRestrictions != nil
                            ? "/// - Requires: Value Restrictions - `\(field.valueRestrictions!)`"
                            : nil,
                        
                        field.valueOptionalBehavior != nil
                            ? "/// - Important: \(optionalTerm) Behavior - `\(field.valueOptionalBehavior!)`"
                            : nil,
                        
                        "public var \(field.valueName): \(valueType)",
                    ]
                    .compactMap { $0 }
                    .map { createTabs(2) + $0 }
                    .joined(separator: "\n")
                }.joined(separator: "\n\n")
                
                finalStr += "\n\n" + reqFields
                
                // Public Explicit Init
                finalStr += "\n\n" + createTabs(2)
                    + "public init("
                    + initParams
                        .joined(separator: ", ")
                    + ") {\n"
                    + initBody
                        .map { createTabs(3) + $0 }
                        .joined(separator: "\n")
                    + "\n" + createTabs(2) + "}"
            }
        } else {
            finalStr += "\n\n" + createTabs(2) + "public init() {}"
        }

        if !r.responseFields.isEmpty {
            finalStr += "\n\n" + createTabs(2) +
                """
                public struct Response: OBSRequestResponse {
                \(r.responseFields.map { field -> String in
                    let valueType = mapType(field.valueType, nil)
                    
                    let optional = field.valueDescription.contains("null")
                        ? "?" : ""
                    
                    return [
                        field.valueDescription
                            .replacingOccurrences(of: "null", with: "`nil`")
                            .split(separator: "\n")
                            .map { createTabs(3) + "/// \(String($0))" }
                            .joined(separator: "\n"),
                        
                        createTabs(3) + "public var \(field.valueName): \(valueType)" + optional
                    ].joined(separator: "\n")
                }.joined(separator: "\n\n"))
                \(createTabs(2))}
                """
//                .split(separator: "\n")
//                .map { createTabs(2) + $0 }
//                .joined(separator: "\n")
        }
        
        if fieldsToSkip.keys.contains(r) {
            finalStr += "\n\n" +
                """
                enum CodingKeys: String, CodingKey {
                    case \(r.requestFields
                            .map(\.valueName)
                            .joined(separator: ", "))
                }
                """
                .split(separator: "\n")
                .map { createTabs(2) + $0 }
                .joined(separator: "\n")
        }
        
        finalStr += "\n" + createTabs(1) + "}"
        return finalStr
            .replacingOccurrences(of: "``", with: "`")
    }.joined(separator: "\n\n")
    
    let allTypes =
        """
        public enum AllTypes: String, Codable {
        \(reqs
            .map { createTabs(1) + "case " + $0.requestType }
            .joined(separator: "\n"))
            
            public func convertResponseData(_ resData: JSONValue?) throws -> OBSRequestResponse? {
                guard let data = resData else { return nil }
                
                switch self {
        \(reqs
            .map { r -> String in
                if r.requestType == "BroadcastCustomEvent" {
                    return
                        """
                            case .BroadcastCustomEvent:
                            return try data.toCodable(OBSRequests.EmptyResponse.self)
                            // return OBSRequests.BroadcastCustomEvent<E: OBSEvent>.ResponseType.self
                        """
                } else {
                    return "case ." + r.requestType + ":"
                        + "\n" + createTabs(3) + "return try data.toCodable(OBSRequests.\(r.requestType).ResponseType.self)"
                }
            }
            .map { createTabs(2) + $0 }
            .joined(separator: "\n"))
                }
            }
        }
        """
        .split(separator: "\n")
        .map { createTabs(1) + $0 }
        .joined(separator: "\n")
    
    var codableFuncs = ""
    if !fieldsToSkip.isEmpty {
        for (r, skippableFields) in fieldsToSkip {
            codableFuncs += "\n\n"
            
            var encodableStr = ""
            var decodableStr = ""
            
            for field in r.requestFields {
                let valueType = mapType(field.valueType, field.valueRestrictions)
                encodableStr += "\n\(createTabs(2))"
                decodableStr += "\n\(createTabs(2))"
                
                // If field should only be coded if present
                if skippableFields.contains(field) {
                    // try container.encodeIfPresent(display, forKey: .display)
                    encodableStr += "try container.encodeIfPresent(\(field.valueName), forKey: .\(field.valueName))"
                    
                    // Needs to be marked as Excludable type (or set to .excluded)
                    if field.valueOptional && field.valueDescription.contains("null") {
                        decodableStr += "self.\(field.valueName) = try container.decodeIfPresent(Excludable<\(valueType)>.self, forKey: .\(field.valueName)) ?? .excluded"
                    } else { // if present
                        // self.display = try container.decodeIfPresent(Int?.self, forKey: .display)
                        decodableStr += "self.\(field.valueName) = try container.decodeIfPresent(\(valueType).self, forKey: .\(field.valueName))"
                    }
                } else {
                    // try container.encode(show_cursor, forKey: .show_cursor)
                    encodableStr += "try container.encode(\(field.valueName), forKey: .\(field.valueName))"
                    
                    // self.show_cursor = try container.decode(Bool.self, forKey: .show_cursor)
                    decodableStr += "self.\(field.valueName) = try container.decode(\(valueType).self, forKey: .\(field.valueName))"
                }
            }
            
            codableFuncs +=
                """
                extension OBSRequests.\(r.requestType): Encodable {
                    public func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                \(encodableStr)
                    }
                }
                
                extension OBSRequests.\(r.requestType): Decodable {
                    public init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                \(decodableStr)
                    }
                }
                """
        }
    }
    
    return
        """
        public enum OBSRequests {
            public struct EmptyResponse: OBSRequestResponse {}
            public typealias FailedReqResponse = OpDataTypes.RequestResponse
            public typealias FailedBatchReqResponse = OpDataTypes.RequestBatchResponse.Response

        \(fullStr)
        
        \(allTypes)
        }\(codableFuncs)
        """
}

func generateEvents(_ events: [OBSEvent]) -> String {
    let fullStr = events.map { ev -> String in
        let eventName = ev.eventType
        
        var finalStr =
            """
            \(ev.description
                .replacingOccurrences(of: "Note:", with: "- Note:")
                // .replacingOccurrences(of: "\n\n", with: "\n")
                .split(separator: "\n")
                .map { "/// \(String($0))" }
                .joined(separator: "\n"))
            /// - Complexity: `\(ev.complexity)/5`
            /// - Version: Latest Supported RPC Version - `\(ev.rpcVersion)`
            /// - Since: Added in v\(ev.initialVersion)
            public struct \(eventName): OBSEvent {
            """
            .split(separator: "\n")
            .map { createTabs(1) + $0 }
            .joined(separator: "\n")
        
        if !ev.dataFields.isEmpty {
            var initParams = [String]()
            var initBody = [String]()
            
            // Data Fields
            let dataFields = ev.dataFields.map { field -> String in
                var valueType = mapType(field.valueType, nil)
                if let range = field.valueDescription.range(of: #"(`\w+`) enum"#, options: .regularExpression) {
                    let substring = String(field.valueDescription[range])
                        .replacingOccurrences(of: "`", with: "")
                        .replacingOccurrences(of: " enum", with: "")
                        .replacingOccurrences(of: "Obs", with: "")
                    valueType = "OBSEnums." + substring
                }
                
                initParams.append("\(field.valueName): \(valueType)")
                initBody.append("self.\(field.valueName) = \(field.valueName)")
                
                return [
                    field.valueDescription
                        .replacingOccurrences(of: "TODO", with: "- ToDo")
                        .replacingOccurrences(of: "Note", with: "- Note")
                        .replacingOccurrences(of: "**Very important note**", with: "- Important")
                        .split(separator: "\n")
                        .map { "/// \(String($0))" }
                        .joined(separator: "\n"),
                    
                    "public var \(field.valueName): \(valueType)",
                ]
                .map { createTabs(2) + $0 }
                .joined(separator: "\n")
            }.joined(separator: "\n\n")
            
            finalStr += "\n" + dataFields
            
            // Public Explicit Init
            finalStr += "\n\n" + createTabs(2)
                + "public init("
                + initParams
                .joined(separator: ", ")
                + ") {\n"
                + initBody
                .map { createTabs(3) + $0 }
                .joined(separator: "\n")
                + "\n" + createTabs(2) + "}"
        } else {
            finalStr += "\n" + createTabs(2) + "public init() {}"
        }

        return finalStr + "\n" + createTabs(1) + "}"
    }
    .joined(separator: "\n\n")
    .replacingOccurrences(of: "``", with: "`")
    
    let allTypes =
        """
        public enum AllTypes: String, Codable {
        \(events
            .map { createTabs(1) + "case " + $0.eventType }
            .joined(separator: "\n"))
            
            public static func event(ofType type: AllTypes, from eventData: JSONValue) throws -> OBSEvent? {
                switch type {
        \(events
            .map { e -> String in
                return "case ." + e.eventType + ":"
                    + "\n" + createTabs(3) + "return try eventData.toCodable(OBSEvents.\(e.eventType).self)"
            }
            .map { createTabs(2) + $0 }
            .joined(separator: "\n"))
        }
            }
        }
        """
        .split(separator: "\n")
        .map { createTabs(1) + $0 }
        .joined(separator: "\n")
    
    return
        """
        public enum OBSEvents {
        \(fullStr)
        
        \(allTypes)
        }
        """
}

// MARK: - Start Script

func generateProtocol() {
    let protocolJson = Bundle.module.url(
        forResource: "Resources/protocol",
        withExtension: "json"
    )!
    
    let data = try! Data(contentsOf: protocolJson, options: .mappedIfSafe)
    
    let decoder = JSONDecoder()
    let fullProtocol = try! decoder.decode(OBSWSProtocol.self, from: data)

    for i in 0..<fullProtocol.requests.count {
        fullProtocol.requests[i].formatCategoryName()
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short

    let source =
        """
        //
        //  Protocol.swift
        //  OBSwiftSocket
        //
        //  Generated by script on \(dateFormatter.string(from: Date())).
        //  Script written by Edon Valdman
        //

        import Foundation
        import JSONValue

        // MARK: - Enums

        \(generateEnums(fullProtocol.enums))

        // MARK: - Requests

        \(generateRequests(fullProtocol.requests))

        // MARK: - Events
        
        \(generateEvents(fullProtocol.events))

        """
    
    // TODO: group the requests and events by category?
    
    let filePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("OBSwiftSocket")
        .appendingPathComponent("Generated")
        .appendingPathComponent("Types.swift")
    
    do {
//        var swiftConfig = SwiftFormatConfiguration.Configuration()
//        swiftConfig.indentation = .spaces(4)
//        let swiftFormatter = SwiftFormatter(configuration: swiftConfig)
//
//        let fileHandle = try FileHandle(forWritingTo: filePath)
//        var output = FileHandlerOutputStream(fileHandle)
//
//        try swiftFormatter.format(source: source, assumingFileURL: nil, to: &output)
        
//        try source.write(to: &output)
//        print(URL(fileURLWithPath: ".", isDirectory: true))
        
        try source.write(to: filePath,
                         atomically: true,
                         encoding: .utf8)
        
//        let success = FileManager.default.createFile(atPath: "./OBSwiftSocket/Generated/Types.swift",
//                                       contents: source.data(using: .utf8))
//        print(success)
        
        print("Success!")
    } catch {
        print("Error writing source: \(error)")
    }
}

struct FileHandlerOutputStream: TextOutputStream {
    private let fileHandle: FileHandle
    let encoding: String.Encoding
    
    init(_ fileHandle: FileHandle, encoding: String.Encoding = .utf8) {
        self.fileHandle = fileHandle
        self.encoding = encoding
    }
    
    mutating func write(_ string: String) {
        if let data = string.data(using: encoding) {
//            if ios 13
//            #if <#T##condition###>
            fileHandle.write(data)
            
            // if ios 14+
            // fileHandle.write(contentsOf: data)
        }
    }
}
