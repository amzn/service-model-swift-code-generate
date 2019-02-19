// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// ServiceModelCodeGenerator+createStructureJsonVariable.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

/// A structure that type-erases an Codable type.
private struct Value: Encodable {
    let handleEncode: (_ encoder: Encoder) throws -> ()
    
    init<EncodableType: Encodable>(_ value: EncodableType) {
        handleEncode = { encoder in
           try value.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try handleEncode(encoder)
    }
}

private func createEncoder() -> JSONEncoder {
    let jsonEncoder = JSONEncoder()
    #if os (Linux)
        jsonDecoder.dateDecodingStrategy = .iso8601
    #elseif os (OSX)
        if #available(OSX 10.12, *) {
            jsonEncoder.dateEncodingStrategy = .iso8601
        }
    #endif
    jsonEncoder.outputFormatting = .prettyPrinted
    
    return jsonEncoder
}

private let jsonEncoder = createEncoder()

internal extension ServiceModelCodeGenerator {
    /**
     Outputs a JSON-serialized version of an structure with default values for its fields.
     
     - Parameters:
        - type: The type to serialize and output.
        - fileBuilder: The FileBuilder to output to.
     - Returns: a tuple of operation to serialized data.
     */
    func createStructureJsonVariable(type: String,
                                     fileBuilder: FileBuilder) {
        let members = generateStructureMembers(type: type)
        
        let jsonData: Data
            
        do {
            jsonData = try jsonEncoder.encode(members)
        } catch {
            fatalError("Unable to encode structure members due to error: \(error)")
        }
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        fileBuilder.appendLine("let serialized\(type) = \"\"\"")
        fileBuilder.incIndent()
        fileBuilder.appendLine(jsonString)
        fileBuilder.appendLine("\"\"\"")
        fileBuilder.decIndent()
    }

    /**
     Outputs a JSON-serialized payload.
     
     - Parameters:
        - data: The data that represents the serialized JSON.
        - fileBuilder: The FileBuilder to output to.
     */
    func emitSerializedJsonPayload(fromData jsonData: Data, fileBuilder: FileBuilder) {
        if let jsonAsString = String(data: jsonData, encoding: .utf8) {
            jsonAsString.split(separator: "\n").forEach { line in fileBuilder.appendLine(String(line)) }
        }
    }

    private func getStringMemberValue(valueConstraints: [(name: String, value: String)],
                                      regexConstraint: String?,
                                      lengthConstraint: LengthRangeConstraint<Int>) -> Value {
        let memberValue: Value
        
        // if this isn't an enumeration
        if valueConstraints.isEmpty {
            // if there are constraints
            if regexConstraint != nil || lengthConstraint.hasContraints {
                
                // create a default value that satifies at least the minimum constraint
                let requiredSize: Int
                if let minimum = lengthConstraint.minimum {
                    requiredSize = minimum
                } else {
                    requiredSize = 0
                }
                var testValue: String = ""
                for index in 0..<requiredSize {
                    testValue += String(index%10)
                }
                
                memberValue = Value(testValue)
            } else {
                // there are no constraints, use a default value
                memberValue = Value("value")
            }
        } else {
            // use the first option in the enumeration
            memberValue = Value(valueConstraints[0].value)
        }
        
        return memberValue
    }
    
    private func getListMemberValue(lengthConstraint: LengthRangeConstraint<Int>, listType: String) -> Value {
        var listMembers: [Value] = []
        let requiredSize: Int
        // if there are constraints
        if lengthConstraint.hasContraints {
            if let minimum = lengthConstraint.minimum {
                requiredSize = minimum > 0 ? minimum : 0
            } else {
                requiredSize = 1
            }
        } else {
            requiredSize = 1
        }
        
        // create a list that satifies at least the minimum constraint
        for _ in 0..<requiredSize {
            listMembers.append(getMemberValue(type: listType))
        }
        
        return Value(listMembers)
    }
    
    private func getMapMemberValue(_ lengthConstraint: LengthRangeConstraint<Int>, _ valueType: String) -> Value {
        var mapMembers: [String: Value] = [:]
        let requiredSize: Int
        // if there are constraints
        if lengthConstraint.hasContraints {
            if let minimum = lengthConstraint.minimum {
                requiredSize = minimum > 0 ? minimum : 0
            } else {
                requiredSize = 1
            }
        } else {
            requiredSize = 1
        }
        
        // create a list that satifies at least the minimum constraint
        for index in 0..<requiredSize {
            mapMembers["Entry_\(index)"] = getMemberValue(type: valueType)
        }
        
        return Value(mapMembers)
    }
    
    private func getMemberValue(type: String) -> Value {
        let memberValue: Value
        if let field = model.fieldDescriptions[type] {
            switch field {
            case .string(regexConstraint: let regexConstraint,
                         lengthConstraint: let lengthConstraint,
                         valueConstraints: let valueConstraints):
                memberValue = getStringMemberValue(valueConstraints: valueConstraints,
                                                   regexConstraint: regexConstraint,
                                                   lengthConstraint: lengthConstraint)
            case .boolean:
                memberValue = Value(false)
            case .double:
                memberValue = Value(0.0)
            case .long, .integer:
                memberValue = Value(0)
            case .data:
                memberValue = Value("value".data(using: .utf8))
            case .timestamp:
                memberValue = Value(String(describing: Date()))
            case .list(type: let listType, lengthConstraint: let lengthConstraint):
                memberValue = getListMemberValue(lengthConstraint: lengthConstraint, listType: listType)
            case .map(keyType: _, valueType: let valueType,
                      lengthConstraint: let lengthConstraint):
                memberValue = getMapMemberValue(lengthConstraint, valueType)
            }
        } else if model.structureDescriptions[type] != nil {
            // generate the members for this inner structure
            memberValue = Value(generateStructureMembers(type: type))
        } else {
            fatalError()
        }
        
        return memberValue
    }

    private func generateStructureMembers(type: String) -> [String: Value] {
        guard let structureDefinition = model.structureDescriptions[type] else {
            fatalError("No structure with type \(type)")
        }
        
        // get a sorted list of the required members of the structure
        let sortedMembers = structureDefinition.members.sorted { entry1, entry2 in
            return entry1.value.position < entry2.value.position
        }
        
        var members: [String: Value] = [:]
        
        // iterate through each member
        for (name, member) in sortedMembers {
            let parameterName = getNormalizedVariableName(modelTypeName: name,
                                                        inStructure: type)
            
            members[parameterName] = getMemberValue(type: member.value)
        }
        
        return members
    }
}
