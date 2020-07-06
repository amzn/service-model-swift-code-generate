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
    func generateModelTypes() {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)ModelTypes.swift
            // \(baseName)Model
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
        
        addFieldDeclarations(sortedFields: sortedFields, fileBuilder: fileBuilder)
        
        addFieldValidations(sortedFields: sortedFields, fileBuilder: fileBuilder)
        
        let fileName = "\(baseName)ModelTypes.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(baseName)Model")
    }
    
    private func addStringFieldValidation(name: String, fieldValueConstraints: [(name: String, value: String)], regexConstraint: String?,
                                          lengthConstraint: LengthRangeConstraint<Int>, fileBuilder: FileBuilder) {
        if fieldValueConstraints.isEmpty && (regexConstraint != nil || lengthConstraint.hasContraints) {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, isListWithInnerType: nil, rangeValidation: validateLengthRange,
                                  regexConstraint: regexConstraint, lengthConstraint: lengthConstraint)
            
        }
    }
    
    private func addIntegerFieldValidation(name: String, rangeConstraint: NumericRangeConstraint<Int>, fileBuilder: FileBuilder) {
        if rangeConstraint.hasContraints {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, isListWithInnerType: nil, rangeValidation: validateNumericRange,
                                  regexConstraint: nil, lengthConstraint: rangeConstraint)
            
        }
    }
    
    private func addDoubleFieldValidation(name: String, rangeConstraint: NumericRangeConstraint<Double>, fileBuilder: FileBuilder) {
        if rangeConstraint.hasContraints {
            // create the field validation
            createFieldValidation(fileBuilder: fileBuilder,
                                  name: name, isListWithInnerType: nil, rangeValidation: validateNumericRange,
                                  regexConstraint: nil, lengthConstraint: rangeConstraint)
            
        }
    }
    
    private func addFieldValidations(sortedFields: [(key: String, value: Fields)], fileBuilder: FileBuilder) {
        // for each of the fields
        for (name, field) in sortedFields {
            switch field {
            case .string(regexConstraint: let regexConstraint,
                         lengthConstraint: let lengthConstraint,
                         valueConstraints: let fieldValueConstraints):
                addStringFieldValidation(name: name, fieldValueConstraints: fieldValueConstraints,
                                         regexConstraint: regexConstraint, lengthConstraint: lengthConstraint,
                                         fileBuilder: fileBuilder)
            case .integer(rangeConstraint: let rangeConstraint):
                addIntegerFieldValidation(name: name, rangeConstraint: rangeConstraint, fileBuilder: fileBuilder)
            case .long(rangeConstraint: let rangeConstraint):
                addIntegerFieldValidation(name: name, rangeConstraint: rangeConstraint, fileBuilder: fileBuilder)
            case .double(rangeConstraint: let rangeConstraint):
                addDoubleFieldValidation(name: name, rangeConstraint: rangeConstraint, fileBuilder: fileBuilder)
            case .list(type: let type, lengthConstraint: let lengthConstraint):
                // create the field validation
                createFieldValidation(fileBuilder: fileBuilder, name: name,
                                      isListWithInnerType: type, rangeValidation: validateLengthRange,
                                      regexConstraint: nil, lengthConstraint: lengthConstraint)
            default:
                break
            }
        }
    }
    
    private func addStringFieldDeclaration(name: String, overrideType: String?, regexConstraint: String?,
                                           lengthConstraint: LengthRangeConstraint<Int>,
                                           valueConstraints: [(name: String, value: String)], fileBuilder: FileBuilder) -> String? {
        // if this is an enumeration
        if !valueConstraints.isEmpty {
            // create the enumeration declaration
            generateEnumerationDeclaration(fileBuilder: fileBuilder,
                                           name: name, valueConstraints: valueConstraints)
            
            return nil
        } else if regexConstraint != nil || lengthConstraint.hasContraints {
            // create the field declaration
            createModelTypeAlias(fileBuilder: fileBuilder,
                                 name: name, innerType: "String")
            
            return nil
        }

        return overrideType ?? "String"
    }
    
    private func addListFieldDeclaration(fieldName: String, type: String, fileBuilder: FileBuilder) -> String? {
        let typeName = type.getNormalizedTypeName(forModel: model)
        
        // create the field declaration
        createModelTypeAlias(fileBuilder: fileBuilder,
                             name: fieldName, innerType: "[\(typeName)]")

        if customizations.generateModelShapeConversions {
            createArrayConversionFunction(fileBuilder: fileBuilder,
                                          name: fieldName, innerType: type)
        }
        
        return nil
    }
    
    private func addMapFieldDeclaration(name: String, fieldName: String, keyType: String,
                                        valueType: String, fileBuilder: FileBuilder) -> String? {
        let keyTypeName = keyType.getNormalizedTypeName(forModel: model)
        let valueTypeName = valueType.getNormalizedTypeName(forModel: model)

        // create the field declaration
        createModelTypeAlias(fileBuilder: fileBuilder,
                             name: name, innerType: "[\(keyTypeName): \(valueTypeName)]")

        if customizations.generateModelShapeConversions {
            createMapConversionFunction(fileBuilder: fileBuilder,
                                        name: fieldName, valueType: valueType)
        }
        
        return nil
    }
    
    private func addFieldDeclaration(fieldName: String, field: Fields,
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
                                                   valueConstraints: valueConstraints, fileBuilder: fileBuilder)
        case .list(type: let type, lengthConstraint: _):
            innerType = addListFieldDeclaration(fieldName: fieldName, type: type, fileBuilder: fileBuilder)
        case .map(keyType: let keyType, valueType: let valueType, lengthConstraint: _):
            innerType = addMapFieldDeclaration(name: name, fieldName: fieldName, keyType: keyType,
                                                valueType: valueType, fileBuilder: fileBuilder)
        case .integer:
            innerType = overrideType ?? "Int"
        case .boolean:
            innerType = overrideType ?? "Bool"
        case .double:
            innerType = overrideType ?? "Double"
        case .long:
            innerType = overrideType ?? "Int"
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
    
    private func addFieldDeclarations(sortedFields: [(key: String, value: Fields)], fileBuilder: FileBuilder) {
        var createdFields: Set<String> = []
        
        // for each of the fields
        for (fieldName, field) in sortedFields {
            addFieldDeclaration(fieldName: fieldName, field: field, fileBuilder: fileBuilder, createdFields: &createdFields)
        }
    }
    
    func createModelTypeAlias(fileBuilder: FileBuilder,
                              name: String, innerType: String) {
        let typeName = name.getNormalizedTypeName(forModel: model)
        
        // avoid redundant declarations
        guard typeName != innerType else {
            return
        }
        
        fileBuilder.appendLine("""
            
            /**
             Type definition for the \(typeName) field.
             */
            public typealias \(typeName) = \(innerType)
            """)
    }
}
