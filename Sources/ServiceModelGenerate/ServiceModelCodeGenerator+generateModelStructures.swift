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
// ServiceModelCodeGenerator+generateModelStructures.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    
    struct StructureElements {
        var codingKeyLines: [String] = []
        var constructorSignatureLines: [String] = []
        var shapeProtocolConstructorLines: [String] = []
        var shapeProtocolConstructionSetupLines: [String] = []
        var shapeProtocolConstructionLines: [String] = []
        var constructorBodyLines: [String] = []
        var customStringConvertableLines: [String] = []
        var variableDeclarationLines: [(line: String, documentation: String?)] = []
        var protocolVariableDeclarationLines: [String] = []
        var associatedTypeLines: [String] = []
    }
    
    /**
     Generate the declarations for types specified in a Service Model.
     */
    func generateModelStructures() {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)ModelStructures.swift
            // \(baseName)Model
            //
            
            import Foundation
            """)
        
        let validatableProtocolExists: Bool
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
            validatableProtocolExists = true
        } else {
            validatableProtocolExists = false
        }
        
        // sort the structures in alphabetical order for output
        let sortedStructures = model.structureDescriptions.sorted { entry1, entry2 in
            return entry1.key < entry2.key
        }
        
        // for each of the structures
        for (name, structureDescription) in sortedStructures {
            generateStructure(name: name,
                              structureDescription: structureDescription,
                              fileBuilder: fileBuilder,
                              includeVariableDocumentation: true,
                              generateShapeProtocol: customizations.generateModelShapeConversions,
                              validatableProtocolExists: validatableProtocolExists)
        }
        
        let fileName = "\(baseName)ModelStructures.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(baseName)Model")
    }
    
    private func addCodingKeyLines(name: String, modelName: String?,
                                   variableName: String, locationName: String,
                                   structureElements: inout StructureElements) {
        let codingKeyValue: String
        if let codingKeyOverride = modelOverride?.getCodingKeyOverride(attributeName: locationName,
                                                                       inType: modelName ?? name) {
            codingKeyValue = codingKeyOverride
        } else {
            codingKeyValue = locationName
        }
        
        // if the locationName is the same as the variableName
        if variableName == codingKeyValue {
            structureElements.codingKeyLines.append("case \(variableName)")
        } else {
            structureElements.codingKeyLines.append("case \(variableName) = \"\(codingKeyValue)\"")
        }
    }
    
    private func getOptionalPostfixes(isRequired: Bool)
        -> (optionalPostfix: String, constructorOptionalPostfix: String ) {
            let optionalPostfix: String
            let constructorOptionalPostfix: String
            if !isRequired {
                optionalPostfix = "?"
                if customizations.optionalsInitializeEmpty {
                    constructorOptionalPostfix = "? = nil"
                } else {
                    constructorOptionalPostfix = "?"
                }
            } else {
                optionalPostfix = ""
                constructorOptionalPostfix = ""
            }
            
            return (optionalPostfix, constructorOptionalPostfix)
    }
    
    private struct ConstructorPrefixes {
        let constructorSignaturePrefix: String
        let shapeProtocolConstructorPrefix: String
        let shapeProtocolConstructionPrefix: String
        let constructorSignaturePostfix: String
        let shapeProtocolConstructorPostfix: String
    }
    
    private func getConstructorPrefixes(index: Int, internalTypeName: String, sortedMembersCount: Int) -> ConstructorPrefixes {
        let constructorSignaturePrefix: String
        let shapeProtocolConstructorPrefix: String
        let shapeProtocolConstructionPrefix: String
        if index == 0 {
            constructorSignaturePrefix = "public init("
            shapeProtocolConstructorPrefix = "init("
            shapeProtocolConstructionPrefix = "return \(internalTypeName)("
        } else {
            constructorSignaturePrefix = "            "
            shapeProtocolConstructorPrefix = "    "
            shapeProtocolConstructionPrefix = "    "
        }
        
        let constructorSignaturePostfix: String
        let shapeProtocolConstructorPostfix: String
        if index == sortedMembersCount - 1 {
            constructorSignaturePostfix = ") {"
            shapeProtocolConstructorPostfix = ")"
        } else {
            constructorSignaturePostfix = ","
            shapeProtocolConstructorPostfix = ","
        }
        
        return ConstructorPrefixes(
            constructorSignaturePrefix: constructorSignaturePrefix,
            shapeProtocolConstructorPrefix: shapeProtocolConstructorPrefix,
            shapeProtocolConstructionPrefix: shapeProtocolConstructionPrefix,
            constructorSignaturePostfix: constructorSignaturePostfix,
            shapeProtocolConstructorPostfix: shapeProtocolConstructorPostfix)
    }
    
    private func updateStructureElementsForMember(
            member: Member, index: Int, internalTypeName: String,
            isRequired: Bool, variableName: String,
            includeVariableDocumentation: Bool, sortedMembersCount: Int,
            structureElements: inout StructureElements) {
        let typeName = member.value.getNormalizedTypeName(forModel: model)
        
        let (optionalPostfix, constructorOptionalPostfix) = getOptionalPostfixes(isRequired: isRequired)
        let prefixes = getConstructorPrefixes(index: index, internalTypeName: internalTypeName, sortedMembersCount: sortedMembersCount)
        
        let shapeToInstanceConversionDetails =
            getShapeToInstanceConversion(fieldType: member.value,
                                         variableName: variableName,
                                         isRequired: isRequired)
        let shapeToInstanceConversion = shapeToInstanceConversionDetails.conversion
        
        if let setup = shapeToInstanceConversionDetails.setup {
            structureElements.shapeProtocolConstructionSetupLines.append(setup)
        }
        
        structureElements.constructorSignatureLines.append(
            "\(prefixes.constructorSignaturePrefix)\(variableName): \(typeName)\(constructorOptionalPostfix)\(prefixes.constructorSignaturePostfix)")
        structureElements.shapeProtocolConstructorLines.append(
            "\(prefixes.shapeProtocolConstructorPrefix)\(variableName): \(typeName)\(optionalPostfix)\(prefixes.shapeProtocolConstructorPostfix)")
        structureElements.shapeProtocolConstructionLines.append(
            "\(prefixes.shapeProtocolConstructionPrefix)\(variableName): \(shapeToInstanceConversion)\(prefixes.shapeProtocolConstructorPostfix)")
        structureElements.constructorBodyLines.append("self.\(variableName) = \(variableName)")
        
        // if this is a list that is not required
        let fieldShape = getShapeType(fieldName: member.value)
        
        structureElements.associatedTypeLines.append(contentsOf: fieldShape.associatedTypes)
        
        if isRequired {
            structureElements.customStringConvertableLines.append("""
                if let existingValue = value {
                value = existingValue + ":" + \(variableName)
                } else {
                value = \(variableName)
                }
                """)
        } else {
            structureElements.customStringConvertableLines.append("""
                if let \(variableName) = \(variableName), let existingValue = value {
                value = existingValue + ":" + \(variableName)
                } else if let \(variableName) = \(variableName) {
                value = \(variableName)
                }
                """)
        }
        
        let documentation = includeVariableDocumentation ? member.documentation : nil
        let variableLine = "public var \(variableName): \(typeName)\(optionalPostfix)"
        structureElements.variableDeclarationLines.append((variableLine, documentation))
        
        structureElements.protocolVariableDeclarationLines.append("var \(variableName): \(fieldShape.fieldShape)\(optionalPostfix) { get }")
    }
    
    private func addStructureElementsForMember(entry: (key: String, value: Member),
                                               name: String,
                                               modelName: String?, index: Int,
                                               internalTypeName: String,
                                               sortedMembers: [(key: String, value: Member)],
                                               includeVariableDocumentation: Bool,
                                               structureElements: inout StructureElements) {
        let variableName = getNormalizedVariableName(modelTypeName: entry.key,
                                                     inStructure: name)
        
        let locationName = entry.value.locationName ?? entry.key
        
        addCodingKeyLines(name: name, modelName: modelName, variableName: variableName,
                          locationName: locationName, structureElements: &structureElements)
        
        let isRequired = modelOverride?.getIsRequiredOverride(attributeName: locationName, inType: modelName ?? name) ?? entry.value.required
        
        updateStructureElementsForMember(member: entry.value, index: index,
                                         internalTypeName: internalTypeName, isRequired: isRequired,
                                         variableName: variableName, includeVariableDocumentation: includeVariableDocumentation,
                                         sortedMembersCount: sortedMembers.count,
                                         structureElements: &structureElements)
    }
    
    func generateStructure(name: String,
                           structureDescription: StructureDescription,
                           fileBuilder: FileBuilder,
                           includeVariableDocumentation: Bool,
                           generateShapeProtocol: Bool,
                           validatableProtocolExists: Bool? = nil,
                           modelName: String? = nil) {
        let internalTypeName = name.getNormalizedTypeName(forModel: model)
        
        // sort the members in alphabetical order for output
        let sortedMembers = structureDescription.members.sorted { entry1, entry2 in
            return entry1.value.position < entry2.value.position
        }
        
        // iterate through the members
        var structureElements = StructureElements()
        for (index, entry) in sortedMembers.enumerated() {
            addStructureElementsForMember(entry: entry, name: name, modelName: modelName, index: index,
                                          internalTypeName: internalTypeName, sortedMembers: sortedMembers,
                                          includeVariableDocumentation: includeVariableDocumentation,
                                          structureElements: &structureElements)
        }
        
        addStructureDefinition(name: internalTypeName,
                               documentation: structureDescription.documentation,
                               fileBuilder: fileBuilder, structureElements: structureElements, members: sortedMembers,
                               conformToShapeProtocol: generateShapeProtocol,
                               conformToValidatableProtocol: generateShapeProtocol && validatableProtocolExists == true)
        
        if generateShapeProtocol {
            addShapeProtocol(name: internalTypeName, fileBuilder: fileBuilder,
                             structureElements: structureElements)

            addShapeDefaultFunctions(name: internalTypeName, fileBuilder: fileBuilder,
                                     structureElements: structureElements)
        }
    }

    private func addFieldValidate(field: Fields, fileBuilder: FileBuilder, variableName: String,
                                  optionalInfix: String, typeName: String) {
        let addFieldValidation: Bool
        switch field {
        case .string(regexConstraint: let regexConstraint,
                     lengthConstraint: let lengthConstraint,
                     valueConstraints: let valueConstraints):
            // if this isn't an enumeration
            addFieldValidation = valueConstraints.isEmpty && (regexConstraint != nil || lengthConstraint.hasContraints)
        case .integer(rangeConstraint: let rangeConstraints):
            // if there are constraints
            addFieldValidation = rangeConstraints.hasContraints
        case .long(rangeConstraint: let rangeConstraints):
            // if there are constraints
            addFieldValidation = rangeConstraints.hasContraints
        case .double(rangeConstraint: let rangeConstraints):
            // if there are constraints
            addFieldValidation = rangeConstraints.hasContraints
        case .list(type: _, lengthConstraint: let lengthConstraint):
            // if there are constraints
            addFieldValidation = lengthConstraint.hasContraints
        default:
            // nothing to validate
            addFieldValidation = false
        }
        
        if addFieldValidation {
            fileBuilder.appendLine("try \(variableName)\(optionalInfix).validateAs\(typeName)()")
        }
    }
    
    private func addStructureValidate(fileBuilder: FileBuilder, members: [(key: String, value: Member)], name: String) {
        fileBuilder.appendLine("""
        public func validate() throws {
        """)
        
        fileBuilder.incIndent()
        // iterate through the members
        for (memberName, member) in members {
            let variableName = getNormalizedVariableName(modelTypeName: memberName,
                                                         inStructure: name)
            let isRequired = modelOverride?.getIsRequiredOverride(attributeName: memberName, inType: name) ?? member.required
            let optionalInfix = isRequired ? "" : "?"
            
            let typeName = member.value.getNormalizedTypeName(forModel: model)
            
            if let field = model.fieldDescriptions[member.value] {
                addFieldValidate(field: field, fileBuilder: fileBuilder, variableName: variableName,
                                 optionalInfix: optionalInfix, typeName: typeName)
            } else if model.structureDescriptions[member.value] != nil {
                fileBuilder.appendLine("try \(variableName)\(optionalInfix).validate()")
            }
        }
        fileBuilder.decIndent()
        
        fileBuilder.appendLine("""
        }
        """)
    }
    
    func addStructureDefinition(name: String,
                                documentation: String?, fileBuilder: FileBuilder,
                                structureElements: StructureElements,
                                members: [(key: String, value: Member)],
                                conformToShapeProtocol: Bool,
                                conformToValidatableProtocol: Bool) {
        fileBuilder.appendEmptyLine()
        
        if let documentation = documentation {
            fileBuilder.appendLine("/**")
            
            let formattedDocumentation = formatDocumentation(documentation, maxLineLength: 50)
            formattedDocumentation.forEach { line in fileBuilder.appendLine(" \(line)") }
            fileBuilder.appendLine(" */")
        }
        
        var conformingProtocols: [String] = ["Codable"]
        if conformToValidatableProtocol {
            conformingProtocols.append("Validatable")
        }
        conformingProtocols.append("Equatable")
        if case .enabled = self.customizations.addSendableConformance {
            conformingProtocols.append("Sendable")
        }
        if conformToShapeProtocol {
            conformingProtocols.append("\(name)Shape")
        }
        
        let conformingProtocolsString = conformingProtocols.joined(separator: ", ")
        fileBuilder.appendLine("public struct \(name): \(conformingProtocolsString) {", postInc: true)
        
        structureElements.variableDeclarationLines.forEach { lineDeclaration in
            if let documentation = lineDeclaration.documentation {
               fileBuilder.appendLine("/**")
            
                let formattedDocumentation = formatDocumentation(documentation, maxLineLength: 50)
                formattedDocumentation.forEach { line in fileBuilder.appendLine(" \(line)") }
                fileBuilder.appendLine(" */")
            }
            fileBuilder.appendLine(lineDeclaration.line)
        }

        // append the constructor signature and then the constructor body
        fileBuilder.appendEmptyLine()
        if !structureElements.constructorSignatureLines.isEmpty {
            structureElements.constructorSignatureLines.forEach { line in fileBuilder.appendLine(line) }
            fileBuilder.incIndent()
            structureElements.constructorBodyLines.forEach { line in fileBuilder.appendLine(line) }
        } else {
            fileBuilder.appendLine("public init() {", postInc: true)
        }
        fileBuilder.appendLine("}", preDec: true)
        fileBuilder.appendEmptyLine()
        
        if !structureElements.codingKeyLines.isEmpty {
            fileBuilder.appendLine("enum CodingKeys: String, CodingKey {", postInc: true)
            structureElements.codingKeyLines.forEach { line in fileBuilder.appendLine(line) }
            fileBuilder.appendLine("}", preDec: true)
            fileBuilder.appendEmptyLine()
        }
        
        addStructureValidate(fileBuilder: fileBuilder, members: members, name: name)
        
        fileBuilder.appendLine("}", preDec: true)
    }
}
