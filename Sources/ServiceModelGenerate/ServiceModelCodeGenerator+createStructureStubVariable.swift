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
// ServiceModelCodeGenerator+createStructureStubVariable.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

let exampleDateString: String = "2013-02-18T17:00:00Z"

internal extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport {
    /**
     Outputs a declaration of a structure with default values for its fields.
     
     - Parameters:
        - type: The type to serialize and output.
        - fileBuilder: The FileBuilder to output to.
        - declarationPrefix: The prefix to add before the variable declaration of the structure.
        - fatalOnError: If errors should be left to propagate or should cause a program fatal;
            The latter option should only be used for unit tests were tests should be
            aborted as early as possible.
     */
    func createStructureStubVariable(type: String,
                                     fileBuilder: FileBuilder,
                                     declarationPrefix: String,
                                     fatalOnError: Bool,
                                     overrideFieldNameProvider: ((String) -> String?)? = nil) {
        var outputLines: [String] = []
        let modelTargetName = self.targetSupport.modelTargetName
        
        // if there isn't actually a structure of the type, this is a fatal
        guard let structureDefinition = model.structureDescriptions[type] else {
            if let field = model.fieldDescriptions[type] {
                let fieldValue = getFieldValue(field, type: type, fileBuilder: fileBuilder,
                                               fatalOnError: fatalOnError, noTypeInference: true)
                
                fileBuilder.appendLine("\(declarationPrefix) \(fieldValue)")
                return
            } else {
                fatalError("No structure found of type '\(type)'")
            }
        }
        
        // sort the members in alphabetical order for output
        let sortedMembers = structureDefinition.members.sorted { entry1, entry2 in
            return entry1.value.position < entry2.value.position
        }
        
        // use the provided overrideFieldNameProvider or by default the one using the model override
        let overrideFieldNameProviderToUse: (String) -> String?
        if let overrideFieldNameProvider = overrideFieldNameProvider {
            overrideFieldNameProviderToUse = overrideFieldNameProvider
        } else {
            overrideFieldNameProviderToUse = { fieldName in
                return self.modelOverride?.namedFieldValuesOverride?[fieldName]
            }
        }
        
        if sortedMembers.isEmpty {
            outputLines.append("\(declarationPrefix) \(modelTargetName).\(type)()")
        } else {
            outputLines.append("\(declarationPrefix) \(modelTargetName).\(type)(")
        }
        
        // iterate through each property
        for (index, entry) in sortedMembers.enumerated() {
            createStructureStubVariableForMember(entry: entry, type: type,
                                                 overrideFieldNameProviderToUse: overrideFieldNameProviderToUse,
                                                 fileBuilder: fileBuilder, fatalOnError: fatalOnError,
                                                 index: index, structureDefinition: structureDefinition, outputLines: &outputLines)
        }
        
        // output the declaration
        if outputLines.isEmpty {
            fileBuilder.appendLine("\(declarationPrefix) \(modelTargetName).\(type)()")
        } else {
            outputLines.forEach { line in fileBuilder.appendLine(line) }
        }
    }
    
    private func getStringFieldValue(valueConstraints: [(name: String, value: String)], regexConstraint: String?,
                                     lengthConstraint: LengthRangeConstraint<Int>, overrideDefaultValue: String?,
                                     noTypeInference: Bool, type: String) -> String {
        let fieldValue: String
        
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
                
                fieldValue = overrideDefaultValue ?? "\"\(testValue)\""
            } else {
                // there are no constraints, use a default value
                fieldValue = overrideDefaultValue ?? "\"value\""
            }
        } else {
            if noTypeInference {
                let typeName = type.getNormalizedTypeName(forModel: model)
                
                fieldValue = overrideDefaultValue ?? "\(typeName).__default"
            } else {
                fieldValue = overrideDefaultValue ?? ".__default"
            }
        }
        
        return fieldValue
    }
    
    private func getListFieldValue(lengthConstraint: LengthRangeConstraint<Int>, listType: String,
                                   fileBuilder: FileBuilder) -> String {
        let fieldValue: String
        
        // if there are constraints
        if lengthConstraint.hasContraints {
            let requiredSize: Int
            if let minimum = lengthConstraint.minimum {
                requiredSize = minimum
            } else {
                requiredSize = 0
            }
            
            // create a list that satifies at least the minimum constraint
            let defaultValue = getDefaultValue(type: listType, fileBuilder: fileBuilder)
            let listConstructor = Array(repeating: "\(defaultValue)", count: requiredSize)
            
            fieldValue = "[\(listConstructor.joined(separator: ", "))]"
        } else {
            // otherwise just return an empty list
            fieldValue = "[]"
        }
        
        return fieldValue
    }
    
    private func getMapFieldValue(lengthConstraint: LengthRangeConstraint<Int>, valueType: String,
                                  fileBuilder: FileBuilder) -> String {
        let fieldValue: String
        
        // if there are constraints
        if lengthConstraint.hasContraints {
            let requiredSize: Int
            if let minimum = lengthConstraint.minimum {
                requiredSize = minimum
            } else {
                requiredSize = 0
            }
            
            // create a map that satifies at least the minimum constraint
            var mapConstructor: [String] = []
            let defaultValue = getDefaultValue(type: valueType, fileBuilder: fileBuilder)
            for index in 0..<requiredSize {
                mapConstructor.append("\"Entry_\(index)\": \(defaultValue)")
            }
            
            fieldValue = "[\(mapConstructor.joined(separator: ", "))]"
        } else {
            // otherwise just return an empty map
            fieldValue = "[:]"
        }
        
        return fieldValue
    }
    
    private func getFieldValue(_ field: Fields, type: String, fileBuilder: FileBuilder,
                               fatalOnError: Bool, noTypeInference: Bool) -> String {
        let fieldValue: String
        let overrideDefaultValue = modelOverride?.fieldRawTypeOverride?[field.typeDescription]?.defaultValue
        switch field {
        case .string(regexConstraint: let regexConstraint,
                     lengthConstraint: let lengthConstraint,
                     valueConstraints: let valueConstraints):
            fieldValue = getStringFieldValue(valueConstraints: valueConstraints, regexConstraint: regexConstraint,
                                             lengthConstraint: lengthConstraint, overrideDefaultValue: overrideDefaultValue,
                                             noTypeInference: noTypeInference, type: type)
        case .boolean:
            fieldValue = overrideDefaultValue ?? "false"
        case .double:
            fieldValue = overrideDefaultValue ?? "0.0"
        case .long:
            fieldValue = overrideDefaultValue ?? "0"
        case .data:
            fieldValue = overrideDefaultValue ?? "Data()"
        case .integer:
            fieldValue = overrideDefaultValue ?? "0"
        case .timestamp:
            fieldValue = overrideDefaultValue ?? "\"\(exampleDateString)\""
        case .list(type: let listType, lengthConstraint: let lengthConstraint):
            fieldValue = getListFieldValue(lengthConstraint: lengthConstraint, listType: listType, fileBuilder: fileBuilder)
        case .map(keyType: _, valueType: let valueType,
                  lengthConstraint: let lengthConstraint):
            fieldValue = getMapFieldValue(lengthConstraint: lengthConstraint, valueType: valueType, fileBuilder: fileBuilder)
        }
        
        return fieldValue
    }
    
    private func createStructureStubVariableForMember(entry: (key: String, value: Member), type: String,
                                                      overrideFieldNameProviderToUse: (String) -> String?,
                                                      fileBuilder: FileBuilder,
                                                      fatalOnError: Bool,
                                                      index: Int,
                                                      structureDefinition: StructureDescription,
                                                      outputLines: inout [String]) {
        let member = entry.value
        let parameterName = getNormalizedVariableName(modelTypeName: entry.key,
                                                      inStructure: type,
                                                      reservedWordsAllowed: true)
        
        let isRequired = modelOverride?.getIsRequiredOverride(attributeName: entry.key, inType: type) ?? member.required
        
        let fieldValue: String
        if !isRequired {
            // if there member is not required, just set it to nil
            fieldValue = "nil"
        } else {
            if let field = model.fieldDescriptions[member.value] {
                if let namedFieldOverride = overrideFieldNameProviderToUse(entry.key) {
                    fieldValue = namedFieldOverride
                } else {
                    fieldValue = getFieldValue(field, type: type, fileBuilder: fileBuilder,
                                               fatalOnError: fatalOnError, noTypeInference: false)
                }
            } else if model.structureDescriptions[member.value] != nil {
                let typeName = member.value.getNormalizedTypeName(forModel: model)
                
                // use the default for this type
                fieldValue = "\(typeName).__default"
            } else {
                fatalError("No structure for field of name '\(member.value)'")
            }
        }
        
        let prefix = "    "
        
        let postfix: String
        if index == structureDefinition.members.count - 1 {
            postfix = ")"
        } else {
            postfix = ","
        }
        // store the lines of a declaration until all members have been processed
        // as members may have to emit declarations for inner structures
        outputLines.append("\(prefix)\(parameterName): \(fieldValue)\(postfix)")
    }
    
    func getDefaultValue(type: String, fileBuilder: FileBuilder) -> String {
        // if there isn't actually a structure of the type, this is a fatal
        guard model.structureDescriptions[type] != nil else {
            if let field = model.fieldDescriptions[type] {
                return getFieldValue(field, type: type, fileBuilder: fileBuilder,
                                     fatalOnError: true, noTypeInference: true)
            } else {
                fatalError("No structure found of type '\(type)'")
            }
        }
        
        let typeName = type.getNormalizedTypeName(forModel: model)
        
        return "\(typeName).__default"
    }
}
