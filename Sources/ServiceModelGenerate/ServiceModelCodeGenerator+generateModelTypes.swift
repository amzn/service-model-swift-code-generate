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
// ServiceModelCodeGenerator+generateModelTypes.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    /**
     Generate the declarations for structures specified in a Service Model.
     */
    func generateModelTypes(modelTargetName: String) {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)ModelTypes.swift
            // \(modelTargetName)
            //
            
            import Foundation
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        // sort the fields in alphabetical order for output
        let sortedFields = model.fieldDescriptions.sorted { entry1, entry2 in
            return entry1.key < entry2.key
        }
        
        addFieldDeclarations(sortedFields: sortedFields, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        
        addFieldValidations(sortedFields: sortedFields, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        
        let fileName = "\(baseName)ModelTypes.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(modelTargetName)")
    }
    
    private func addStringFieldValidation(name: String, fieldValueConstraints: [(name: String, value: String)], regexConstraint: String?,
                                          lengthConstraint: LengthRangeConstraint<Int>, modelTargetName: String, fileBuilder: FileBuilder) {
        if fieldValueConstraints.isEmpty && (regexConstraint != nil || lengthConstraint.hasContraints) {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, modelTargetName: modelTargetName, isListWithInnerType: nil, rangeValidation: validateLengthRange,
                                  regexConstraint: regexConstraint, lengthConstraint: lengthConstraint)
            
        }
    }
    
    private func addIntegerFieldValidation(name: String, rangeConstraint: NumericRangeConstraint<Int>,
                                           modelTargetName: String, fileBuilder: FileBuilder) {
        if rangeConstraint.hasContraints {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, modelTargetName: modelTargetName, isListWithInnerType: nil, rangeValidation: validateNumericRange,
                                  regexConstraint: nil, lengthConstraint: rangeConstraint)
            
        }
    }
    
    private func addDoubleFieldValidation(name: String, rangeConstraint: NumericRangeConstraint<Double>,
                                          modelTargetName: String, fileBuilder: FileBuilder) {
        if rangeConstraint.hasContraints {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, modelTargetName: modelTargetName, isListWithInnerType: nil, rangeValidation: validateNumericRange,
                                  regexConstraint: nil, lengthConstraint: rangeConstraint)
            
        }
    }
    
    private func addFieldValidations(sortedFields: [(key: String, value: Fields)],
                                     modelTargetName: String, fileBuilder: FileBuilder) {
        // for each of the fields
        for (name, field) in sortedFields {
            switch field {
            case .string(regexConstraint: let regexConstraint,
                         lengthConstraint: let lengthConstraint,
                         valueConstraints: let fieldValueConstraints):
                addStringFieldValidation(name: name, fieldValueConstraints: fieldValueConstraints,
                                         regexConstraint: regexConstraint, lengthConstraint: lengthConstraint,
                                         modelTargetName: modelTargetName, fileBuilder: fileBuilder)
            case .integer(rangeConstraint: let rangeConstraint):
                addIntegerFieldValidation(name: name, rangeConstraint: rangeConstraint,
                                          modelTargetName: modelTargetName, fileBuilder: fileBuilder)
            case .long(rangeConstraint: let rangeConstraint):
                addIntegerFieldValidation(name: name, rangeConstraint: rangeConstraint,
                                          modelTargetName: modelTargetName, fileBuilder: fileBuilder)
            case .double(rangeConstraint: let rangeConstraint):
                addDoubleFieldValidation(name: name, rangeConstraint: rangeConstraint,
                                         modelTargetName: modelTargetName, fileBuilder: fileBuilder)
            case .list(type: let type, lengthConstraint: let lengthConstraint):
                // create the field validation
                createFieldValidation(fileBuilder: fileBuilder, name: name, modelTargetName: modelTargetName,
                                      isListWithInnerType: type, rangeValidation: validateLengthRange,
                                      regexConstraint: nil, lengthConstraint: lengthConstraint)
            default:
                break
            }
        }
    }
    
    private func addStringFieldDeclaration(name: String, overrideType: String?, regexConstraint: String?,
                                           lengthConstraint: LengthRangeConstraint<Int>,
                                           valueConstraints: [(name: String, value: String)],
                                           modelTargetName: String, fileBuilder: FileBuilder) -> String? {
        // if this is an enumeration
        if !valueConstraints.isEmpty {
            // create the enumeration declaration
            generateEnumerationDeclaration(fileBuilder: fileBuilder,
                                           name: name, modelTargetName: modelTargetName, valueConstraints: valueConstraints)
            
            return nil
        } else if regexConstraint != nil || lengthConstraint.hasContraints {
            // create the field declaration
            createModelTypeAlias(fileBuilder: fileBuilder,
                                 name: name, innerType: "String")
            
            return nil
        }

        return overrideType ?? "String"
    }
    
    private func addListFieldDeclaration(fieldName: String, type: String,
                                         modelTargetName: String, fileBuilder: FileBuilder) -> String? {
        let typeName = type.getNormalizedTypeName(forModel: model)
        
        // create the field declaration
        createModelTypeAlias(fileBuilder: fileBuilder,
                             name: fieldName, innerType: "[\(typeName)]")

        if customizations.generateModelShapeConversions {
            createArrayConversionFunction(modelTargetName: modelTargetName, fileBuilder: fileBuilder,
                                          name: fieldName, innerType: type)
        }
        
        return nil
    }
    
    private func addMapFieldDeclaration(name: String, fieldName: String, keyType: String,
                                        valueType: String, modelTargetName: String,
                                        fileBuilder: FileBuilder) -> String? {
        // Detect enums and replace them with a plain String.
        // Maps with enum keys encode into an array of alternating keys and values, instead of a dictionary.
        // And vice versa, JSON dictionary fails to be decoded into such a map, instead expects an array.
        // See: https://github.com/apple/swift-corelibs-foundation/issues/3690
        let keyTypeName: String
        let additionalComment: String?
        if let keyTypeFieldDescription = model.fieldDescriptions[keyType],
           case .string(regexConstraint: _, lengthConstraint: _, valueConstraints: let valueConstraints) = keyTypeFieldDescription,
           !valueConstraints.isEmpty {
            keyTypeName = "String"
            additionalComment = """
                 Enum type \(keyType.getNormalizedTypeName(forModel: model)) is replaced with String.
                 See: https://github.com/apple/swift-corelibs-foundation/issues/3690
                """
        } else {
            keyTypeName = keyType.getNormalizedTypeName(forModel: model)
            additionalComment = nil
        }

        let valueTypeName = valueType.getNormalizedTypeName(forModel: model)

        // create the field declaration
        createModelTypeAlias(fileBuilder: fileBuilder,
                             name: name, innerType: "[\(keyTypeName): \(valueTypeName)]",
                             additionalComment: additionalComment)

        if customizations.generateModelShapeConversions {
            createMapConversionFunction(modelTargetName: modelTargetName, fileBuilder: fileBuilder,
                                        name: fieldName, valueType: valueType)
        }
        
        return nil
    }
    
    private func addFieldDeclaration(fieldName: String, field: Fields, modelTargetName: String,
                                     fileBuilder: FileBuilder, createdFields: inout Set<String>) {
        let name = fieldName.startingWithUppercase
        let overrideType = modelOverride?.fieldRawTypeOverride?[field.typeDescription]?.typeName
        let innerType: String?
        switch field {
        case .string(regexConstraint: let regexConstraint,
                     lengthConstraint: let lengthConstraint,
                     valueConstraints: let valueConstraints):
            innerType = addStringFieldDeclaration(name: name, overrideType: overrideType,
                                                  regexConstraint: regexConstraint, lengthConstraint: lengthConstraint,
                                                  valueConstraints: valueConstraints,
                                                  modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        case .list(type: let type, lengthConstraint: _):
            innerType = addListFieldDeclaration(fieldName: fieldName, type: type, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        case .map(keyType: let keyType, valueType: let valueType, lengthConstraint: _):
            innerType = addMapFieldDeclaration(name: name, fieldName: fieldName, keyType: keyType,
                                               valueType: valueType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        case .integer:
            innerType = overrideType ?? "Int"
        case .boolean:
            innerType = overrideType ?? "Bool"
        case .double:
            innerType = overrideType ?? "Double"
        case .long:
            innerType = overrideType ?? "Int64"
        case .timestamp:
            innerType = overrideType ?? "String"
        case .data:
            innerType = overrideType ?? "Data"
        }
    
        let typeName = fieldName.getNormalizedTypeName(forModel: model)
    
        guard !createdFields.contains(typeName), let currentInnerType = innerType else {
            return
        }
    
        createdFields.insert(typeName)
    
        createModelTypeAlias(fileBuilder: fileBuilder,
                             name: fieldName, innerType: currentInnerType)
    }
    
    private func addFieldDeclarations(sortedFields: [(key: String, value: Fields)],
                                      modelTargetName: String, fileBuilder: FileBuilder) {
        var createdFields: Set<String> = []
        
        // for each of the fields
        for (fieldName, field) in sortedFields {
            addFieldDeclaration(fieldName: fieldName, field: field, modelTargetName: modelTargetName,
                                fileBuilder: fileBuilder, createdFields: &createdFields)
        }
    }
    
    func createModelTypeAlias(fileBuilder: FileBuilder,
                              name: String, innerType: String,
                              additionalComment: String? = nil) {
        let typeName = name.getNormalizedTypeName(forModel: model)
        
        // avoid redundant declarations
        guard typeName != innerType else {
            return
        }
        
        fileBuilder.appendLine("""
            
            /**
             Type definition for the \(typeName) field.
            """)

        if let additionalComment = additionalComment {
            fileBuilder.appendLine("""
                \(additionalComment)
                """)
        }

        fileBuilder.appendLine("""
             */
            public typealias \(typeName) = \(innerType)
            """)
    }
}
