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
// ServiceModelCodeGenerator+shapeUtilityFunctions.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration

private let reservedWords: Set<String> = ["in", "protocol", "return", "default", "public",
                                          "static", "private", "internal", "do", "is", "as", "true"]

public enum ShapeCategory {
    case protocolType(String)
    case collectionType(String)
    case enumType
    case builtInType(String)
}

public extension ServiceModelCodeGenerator {
    private func getMapShapeType(keyType: String, valueType: String) -> (fieldShape: String, associatedTypes: [String]) {
        let keyInnerShape = getShapeType(fieldName: keyType)
        let valueInnerShape = getShapeType(fieldName: valueType)

        let keyFieldShape: String
        let valueFieldShape: String

        var associatedTypes: [String] = []
        if !keyInnerShape.associatedTypes.isEmpty {
            keyFieldShape = keyInnerShape.fieldShape
            associatedTypes.append(contentsOf: keyInnerShape.associatedTypes)
        } else {
            keyFieldShape = keyInnerShape.fieldShape
        }

        if !valueInnerShape.associatedTypes.isEmpty {
            valueFieldShape = valueInnerShape.fieldShape
            associatedTypes.append(contentsOf: valueInnerShape.associatedTypes)
        } else {
            valueFieldShape = valueInnerShape.fieldShape
        }

        let fieldShape = "[\(keyFieldShape): \(valueFieldShape)]"
        
        return (fieldShape: fieldShape, associatedTypes: associatedTypes)
    }
    
    private func getListShapeType(type: String) -> (fieldShape: String, associatedTypes: [String]) {
        let innerShape = getShapeType(fieldName: type)
        let associatedTypes: [String]
        
        if !innerShape.associatedTypes.isEmpty {
            associatedTypes = innerShape.associatedTypes
        } else {
            associatedTypes = []
        }
        
        let fieldShape = "[\(innerShape.fieldShape)]"
        
        return (fieldShape: fieldShape, associatedTypes: associatedTypes)
    }
    
    private func getStringShapeType(typeName: String,
                                    valueConstraints: [(name: String, value: String)]) -> (fieldShape: String, associatedTypes: [String]) {
        let associatedTypes: [String]
        let fieldShape: String
        
        if !valueConstraints.isEmpty {
            fieldShape = "\(typeName)Type"
            associatedTypes = ["\(typeName)Type: CustomStringConvertible"]
        } else {
            fieldShape = "String"
            associatedTypes = []
        }
        
        return (fieldShape: fieldShape, associatedTypes: associatedTypes)
    }
    /**
     Gets the field shape type for the provided field name.
 
     - Parameters:
        - fieldName: the name of the field to retrieve the shape type for.
     */
    func getShapeType(fieldName: String) ->
        (fieldShape: String, associatedTypes: [String]) {
        let typeName = fieldName.getNormalizedTypeName(forModel: model)
            
        let fieldShape: String
        var associatedTypes: [String] = []
        if let field = model.fieldDescriptions[fieldName] {
            switch field {
            case .string(_, _, let valueConstraints):
                (fieldShape, associatedTypes) = getStringShapeType(typeName: typeName, valueConstraints: valueConstraints)
            case .integer:
                fieldShape = "Int"
            case .boolean:
                fieldShape = "Bool"
            case .double:
                fieldShape = "Double"
            case .long:
                fieldShape = "Int"
            case .timestamp:
                fieldShape = "String"
            case .data:
                fieldShape = "Data"
            case .list(let type, _):
                (fieldShape, associatedTypes) = getListShapeType(type: type)
            case .map(let keyType, let valueType, _):
                (fieldShape, associatedTypes) = getMapShapeType(keyType: keyType, valueType: valueType)
            }
        } else if typeName.isBuiltinType {
            fieldShape = typeName
            associatedTypes = []
        } else {
            fieldShape = "\(typeName)Type"
            associatedTypes = ["\(typeName)Type: \(typeName)Shape"]
        }
        
        return (fieldShape, associatedTypes)
    }

    private func getStringShapeCategory(
            valueConstraints: [(name: String, value: String)]) -> ShapeCategory {
        let shapeCategory: ShapeCategory
        if !valueConstraints.isEmpty {
            shapeCategory = .enumType
        } else {
            shapeCategory = .builtInType("String")
        }
        
        return shapeCategory
    }
    
    /**
     Gets the field category type for the provided field name.
 
     - Parameters:
        - fieldName: the name of the field to retrieve the shape type for.
        - collectionAssociatedType: the associated type name for a collection type.
     */
    func getShapeCategory(fieldName: String,
                                 collectionAssociatedType: String) -> ShapeCategory {
        let typeName = fieldName.getNormalizedTypeName(forModel: model)
        
        let shapeCategory: ShapeCategory
        if let field = model.fieldDescriptions[fieldName] {
            switch field {
            case .string(_, _, let valueConstraints):
                shapeCategory = getStringShapeCategory(valueConstraints: valueConstraints)
            case .integer:
                shapeCategory = .builtInType("Int")
            case .boolean:
                shapeCategory = .builtInType("Bool")
            case .double:
                shapeCategory = .builtInType("Double")
            case .long:
                shapeCategory = .builtInType("Int")
            case .timestamp:
                shapeCategory = .builtInType("String")
            case .data:
                shapeCategory = .builtInType("Data")
            case .list(type: let type, lengthConstraint: _):
                let typeName = type.getNormalizedTypeName(forModel: model)
                
                shapeCategory = .collectionType("\(collectionAssociatedType) == [\(typeName)]")
            case .map(keyType: let keyType, valueType: let valueType, lengthConstraint: _):
                let keyTypeName = keyType.getNormalizedTypeName(forModel: model)
                let valueTypeName = valueType.getNormalizedTypeName(forModel: model)
                
                shapeCategory = .collectionType("\(collectionAssociatedType) == [\(keyTypeName): \(valueTypeName)]")
            }
        } else {
            shapeCategory = .protocolType("\(typeName)Shape")
        }
        
        return shapeCategory
    }
    
    private func escapeReservedWords(name: String) -> String {
        if reservedWords.contains(name) {
            return "`\(name)`"
        }
        
        return name
    }
    
    /**
     Returns the normalized name of variable for a type.
     
     - Parameters:
        - modelTypeName: The model name for the type.
     */
    func getNormalizedVariableName(modelTypeName: String,
                                          inStructure: String? = nil,
                                          reservedWordsAllowed: Bool = false) -> String {
        if let inStructure = inStructure, let matchCase = modelOverride?.matchCase,
            matchCase.contains(inStructure) {
            // leave the name alone
            return modelTypeName
        }
        let internalName = modelTypeName.prefix(1).lowercased() + modelTypeName.dropFirst()
        
        let variableName = reservedWordsAllowed ? internalName : escapeReservedWords(name: internalName)
        
        return variableName.safeModelName(replacement: "",
                                 wildCardReplacement: "Star")
    }
    
    /**
     Returns the normalized name of variable for a type.
     
     - Parameters:
        - modelTypeName: The model name for the type.
     */
    func getNormalizedEnumCaseName(modelTypeName: String,
                                          inStructure: String,
                                          usingUpperCamelCase: Bool = false) -> String {
        if let usingUpperCamelCase = modelOverride?.enumerations?.usingUpperCamelCase,
            usingUpperCamelCase.contains(inStructure) {
            let modifiedModelTypeName = modelTypeName.safeModelName(replacement: "",
                                                                    wildCardReplacement: "Star")
            
            // convert from upper camel case
            return escapeReservedWords(name: modifiedModelTypeName.upperToLowerCamelCase)
        } else if let usingUpperCamelCase = modelOverride?.enumerations?.usingUpperCamelCase,
            usingUpperCamelCase.contains("\(inStructure).\(modelTypeName)") {
            let modifiedModelTypeName = modelTypeName.safeModelName(replacement: "",
                                                                    wildCardReplacement: "Star")
            
            // convert from upper camel case
            return escapeReservedWords(name: modifiedModelTypeName.upperToLowerCamelCase)
        } else if usingUpperCamelCase {
            let modifiedModelTypeName = modelTypeName.safeModelName(replacement: "",
                                                                    wildCardReplacement: "Star")
            
            // convert from upper camel case
            return escapeReservedWords(name: modifiedModelTypeName.upperToLowerCamelCase)
        }
        
        let modifiedModelTypeName = modelTypeName.safeModelName(replacement: "_",
                                                                wildCardReplacement: "star")

        let components = modifiedModelTypeName.split(separator: "_")
        
        var convertedName = ""
        for (index, component) in components.enumerated() {
            if index == 0 {
                convertedName += component.lowercased()
            } else {
                convertedName += component.prefix(1).capitalized + component.dropFirst().lowercased()
            }
        }
        
        let firstCharacter = convertedName.prefix(1)
        
        // if the name starts with a digit
        if CharacterSet.decimalDigits.contains(
            firstCharacter.unicodeScalars[firstCharacter.startIndex]) {
            return "_\(convertedName)"
        }
        return escapeReservedWords(name: convertedName)
    }
}
