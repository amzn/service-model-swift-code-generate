// Copyright 2019-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// ServiceModelCodeGenerator+shapeConversion.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

internal extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport {
    func createConversionFunction(originalTypeName: String,
                                  derivedTypeName: String,
                                  members: [String: Member],
                                  fileBuilder: FileBuilder) {
        let modelTargetName = self.targetSupport.modelTargetName
        let postfix: String
        if members.isEmpty {
            postfix = ")"
        } else {
            postfix = ""
        }
        
        fileBuilder.appendLine("""
            public extension \(originalTypeName) {
                func as\(modelTargetName)\(derivedTypeName)() -> \(derivedTypeName) {
                    return \(derivedTypeName)(\(postfix)
            """)
        
        // get a sorted list of the required members of the structure
        let sortedMembers = members.sorted { entry1, entry2 in
            return entry1.value.position < entry2.value.position
        }
        
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        sortedMembers.enumerated().forEach { details in
            let variableName = getNormalizedVariableName(modelTypeName: details.element.key)
            
            let postfix: String
            if details.offset == members.count - 1 {
                postfix = ")"
            } else {
                postfix = ","
            }
            fileBuilder.appendLine("\(variableName): \(variableName)\(postfix)")
        }
        
        fileBuilder.decIndent()
        fileBuilder.decIndent()
        fileBuilder.decIndent()
        fileBuilder.appendLine("""
                }
            }
            """)
    }
    
    private func getStringShapeToInstanceConversion(valueConstraints: [(name: String, value: String)], isRequired: Bool,
                                                    fieldName: String, baseName: String,
                                                    variableName: String) -> (setup: String?, fieldShape: String) {
        let setup: String?
        let fieldShape: String
        if !valueConstraints.isEmpty {
            let capitalizedVariableName = variableName.lowerToUpperCamelCase
            let modelTargetName = self.targetSupport.modelTargetName
            if isRequired {
                setup = """
                guard let converted\(capitalizedVariableName) = \(modelTargetName).\(fieldName)(rawValue: \(variableName).description) else {
                    throw \(validationErrorType).validationError(reason: "Unable to convert value '"
                        + \(variableName).description + "' of field '\(variableName)' to a \(modelTargetName).\(fieldName) value.")
                }
                """
            } else {
                setup = """
                let converted\(capitalizedVariableName): \(modelTargetName).\(fieldName)?
                if let description = \(variableName)?.description {
                    if let new\(fieldName) = \(modelTargetName).\(fieldName)(rawValue: description) {
                        converted\(capitalizedVariableName) = new\(fieldName)
                    } else {
                        throw \(validationErrorType).validationError(reason: "Unable to convert value '"
                            + description + "' of field '\(variableName)' to a \(modelTargetName).\(fieldName) value.")
                    }
                } else {
                    converted\(capitalizedVariableName) = nil
                }
                """
            }
            
            fieldShape = "converted\(capitalizedVariableName)"
        } else {
            fieldShape = variableName
            setup = nil
        }
        
        return (setup, fieldShape)
    }
    
    private func getListShapeToInstanceConversion(fieldName: String, type: String,
                                                  variableName: String, isRequired: Bool) -> (setup: String?, fieldShape: String) {
        let willConversionFail = willShapeConversionFail(fieldName: type, alreadySeenShapes: [])
        let failPostfix = willConversionFail ? "try " : ""
        let optionalInfix = isRequired ? "" : "?"

        let typeName = type.getNormalizedTypeName(forModel: model)
        let modelTargetName = self.targetSupport.modelTargetName

        let conversionDetails = getShapeToInstanceConversion(fieldType: type,
                                                             variableName: "entry",
                                                             isRequired: true)
        
        var setupBuilder: String
        // if there is no conversion
        let capitalizedVariableName = variableName.lowerToUpperCamelCase
        if conversionDetails.conversion == "entry" {
            setupBuilder = "let converted\(capitalizedVariableName) = \(variableName)"
        } else {
            let fieldType = "[\(modelTargetName).\(typeName)]\(optionalInfix)"
            setupBuilder = "let converted\(capitalizedVariableName): \(fieldType) = \(failPostfix)\(variableName)\(optionalInfix).map { entry in\n"

            if let setup = conversionDetails.setup {
                setup.split(separator: "\n").forEach { line in setupBuilder += "    \(line)\n" }
            }
            setupBuilder += """
                return \(conversionDetails.conversion)
            }
            """
        }
        
        return (setupBuilder, "converted\(capitalizedVariableName)")
    }
    
    private func getMapShapeToInstanceConversion(fieldName: String, keyType: String,
                                                 valueType: String, variableName: String,
                                                 isRequired: Bool) -> (setup: String?, fieldShape: String) {
        let willConversionFail = willShapeConversionFail(fieldName: valueType, alreadySeenShapes: [])
        let failPostfix = willConversionFail ? "try " : ""
        let optionalInfix = isRequired ? "" : "?"

        let keyTypeName = keyType.getNormalizedTypeName(forModel: model)
        let valueTypeName = valueType.getNormalizedTypeName(forModel: model)
        let modelTargetName = self.targetSupport.modelTargetName

        let conversionDetails = getShapeToInstanceConversion(fieldType: valueType,
                                                             variableName: "entry",
                                                             isRequired: true)
        
        let fullKeyTypeName = keyTypeName.isBuiltinType ? keyTypeName : "\(modelTargetName).\(keyTypeName)"
        
        // if there is actually conversion on each element
        if conversionDetails.conversion != "entry" && !valueTypeName.isBuiltinType {
            let fullValueTypeName = "\(modelTargetName).\(valueTypeName)"
            
            let capitalizedVariableName = variableName.lowerToUpperCamelCase
            let fieldType = "[\(fullKeyTypeName): \(fullValueTypeName)]\(optionalInfix)"
            
            var setupBuilder =
                "let converted\(capitalizedVariableName): \(fieldType) = \(failPostfix)\(variableName)\(optionalInfix).mapValues { entry in\n"

            if let setup = conversionDetails.setup {
                setup.split(separator: "\n").forEach { line in setupBuilder += "    \(line)\n" }
            }
            setupBuilder += """
                return \(conversionDetails.conversion)
            }
            """

            return (setupBuilder, "converted\(capitalizedVariableName)")
        } else {
            return (nil, variableName)
        }
    }
    
    func getShapeToInstanceConversion(fieldType: String, variableName: String,
                                      isRequired: Bool)
        -> (conversion: String, setup: String?) {
            
        let baseName = applicationDescription.baseName
        let modelTargetName = self.targetSupport.modelTargetName
        let fieldName = fieldType.getNormalizedTypeName(forModel: model)
        let fieldShape: String
        var setup: String?
        if let field = model.fieldDescriptions[fieldType] {
            switch field {
            case .string(_, _, let valueConstraints):
                (setup, fieldShape) = getStringShapeToInstanceConversion(valueConstraints: valueConstraints, isRequired: isRequired,
                                                                         fieldName: fieldName, baseName: baseName, variableName: variableName)
            case .list(let type, _):
                (setup, fieldShape) = getListShapeToInstanceConversion(fieldName: fieldName, type: type,
                                                                       variableName: variableName, isRequired: isRequired)
            case .map(let keyType, let valueType, _):
                (setup, fieldShape) = getMapShapeToInstanceConversion(fieldName: fieldName, keyType: keyType,
                                                                      valueType: valueType, variableName: variableName, isRequired: isRequired)
            default:
                fieldShape = variableName
            }
        } else {
            let optionalInfix = isRequired ? "" : "?"
            
            let willConversionFail = willShapeConversionFail(fieldName: fieldName, alreadySeenShapes: [])
            let failPostfix = willConversionFail ? "try " : ""
            
            fieldShape = "\(failPostfix)\(variableName)\(optionalInfix).as\(modelTargetName)\(fieldName)()"
        }
        
        return (fieldShape, setup)
    }
    
    func willShapeConversionFail(fieldName: String, alreadySeenShapes: Set<String>) -> Bool {
        if alreadySeenShapes.contains(fieldName) {
            // this is a self referencing type structure
            // and this type has already been checked above
            return false
        }
        var newAlreadySeenShapes = alreadySeenShapes
        newAlreadySeenShapes.insert(fieldName)
        
        if let field = model.fieldDescriptions[fieldName] {
            switch field {
            case .string(_, _, let valueConstraints):
                if !valueConstraints.isEmpty {
                    return true
                }
            case .list(type: let type, lengthConstraint: _):
                return willShapeConversionFail(fieldName: type, alreadySeenShapes: newAlreadySeenShapes)
            case .map( keyType: _, let valueType, lengthConstraint: _ ):
                return willShapeConversionFail( fieldName: valueType, alreadySeenShapes: newAlreadySeenShapes )
            default:
                break
            }
        } else if let structureDescriptions = model.structureDescriptions[fieldName] {
            
            // iterate through each member
            for (_, member) in structureDescriptions.members {
                if willShapeConversionFail(fieldName: member.value, alreadySeenShapes: newAlreadySeenShapes) {
                    return true
                }
            }
        }
        
        return false
    }
}
