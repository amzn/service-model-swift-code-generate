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
// ServiceModelCodeGenerator+generateModelOperationClientInput.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    internal struct HTTPRequestInputTypes {
        let queryTypeName: String
        let queryTypeConversion: String
        let pathTypeName: String
        let pathTypeConversion: String
        let bodyTypeName: String
        let bodyTypeConversion: String
        let additionalHeadersTypeName: String
        let additionalHeadersTypeConversion: String
        let pathTemplateConversion: String
    }
    
    /**
     Generate client input for each operation.
     */
    func generateModelOperationClientInput(modelTargetName: String, clientTargetName: String) {
        let baseName = applicationDescription.baseName
        
        let fileBuilder = FileBuilder()
        
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)OperationsClientInput.swift
            // \(clientTargetName)
            //
            
            import Foundation
            import SmokeHTTPClient
            import \(modelTargetName)
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        sortedOperations.forEach { operation in
            addOperationHTTPRequestInput(operation: operation.key,
                                         operationDescription: operation.value,
                                         generationType: .requestInput, modelTargetName: modelTargetName,
                                         fileBuilder: fileBuilder)
        }
        
        let fileName = "\(baseName)OperationsClientInput.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(clientTargetName)")
    }
    
    private func addPathOperationHTTPRequestInput(pathMembers: [String: Member],
                                                  inputTypeName: String,
                                                  operationPrefix: String,
                                                  name: String,
                                                  generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                                  modelTargetName: String,
                                                  fileBuilder: FileBuilder) -> (pathTypeName: String, pathTypeConversion: String) {
        let pathTypeName: String
        let pathTypeConversion: String
        if !pathMembers.isEmpty {
            pathTypeName = "\(operationPrefix)Path"
            let structureDefinition = StructureDescription(
                members: pathMembers,
                documentation: "Structure to encode the path input for the \(name) operation.")
            
            if case .supportingStructures = generationType {
                generateStructure(name: pathTypeName,
                                  structureDescription: structureDefinition,
                                  modelTargetName: modelTargetName,
                                  fileBuilder: fileBuilder,
                                  includeVariableDocumentation: false,
                                  generateShapeProtocol: false,
                                  modelName: inputTypeName)
                fileBuilder.appendEmptyLine()
                createConversionFunction(originalTypeName: inputTypeName,
                                         derivedTypeName: pathTypeName,
                                         members: pathMembers,
                                         modelTargetName: modelTargetName,
                                         fileBuilder: fileBuilder)
            }
            
            pathTypeConversion = "encodable.as\(modelTargetName)\(operationPrefix)Path()"
        } else {
            pathTypeName = "String"
            pathTypeConversion = "nil"
        }
        
        return (pathTypeName: pathTypeName, pathTypeConversion: pathTypeConversion)
    }
    
    private func addQueryOperationHTTPRequestInput(queryMembers: [String: Member],
                                                   inputTypeName: String,
                                                   operationPrefix: String,
                                                   name: String,
                                                   generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                                   modelTargetName: String,
                                                   fileBuilder: FileBuilder) -> (queryTypeName: String, queryTypeConversion: String) {
        let queryTypeName: String
        let queryTypeConversion: String
        if !queryMembers.isEmpty {
            queryTypeName = "\(operationPrefix)Query"
            let structureDefinition = StructureDescription(
                members: queryMembers,
                documentation: "Structure to encode the query input for the \(name) operation.")
            
            if case .supportingStructures = generationType {
                generateStructure(name: queryTypeName,
                                  structureDescription: structureDefinition, modelTargetName: modelTargetName,
                                  fileBuilder: fileBuilder,
                                  includeVariableDocumentation: false,
                                  generateShapeProtocol: false,
                                  modelName: inputTypeName)
                fileBuilder.appendEmptyLine()
                createConversionFunction(originalTypeName: inputTypeName,
                                         derivedTypeName: queryTypeName,
                                         members: queryMembers,
                                         modelTargetName: modelTargetName,
                                         fileBuilder: fileBuilder)
            }
            
            queryTypeConversion = "encodable.as\(modelTargetName)\(operationPrefix)Query()"
        } else {
            queryTypeName = "String"
            queryTypeConversion = "nil"
        }
        
        return (queryTypeName: queryTypeName, queryTypeConversion: queryTypeConversion)
    }
    
    private func addBodyOperationHTTPRequestInput(bodyMembers: [String: Member],
                                                  inputTypeName: String,
                                                  operationPrefix: String,
                                                  name: String,
                                                  generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                                  modelTargetName: String,
                                                  fileBuilder: FileBuilder) -> (bodyTypeName: String, bodyTypeConversion: String) {
        let bodyTypeName: String
        let bodyTypeConversion: String
        if !bodyMembers.isEmpty {
            bodyTypeName = "\(operationPrefix)Body"
            let structureDefinition = StructureDescription(
                members: bodyMembers,
                documentation: "Structure to encode the body input for the \(name) operation.")
            
            if case .supportingStructures = generationType {
                generateStructure(name: bodyTypeName,
                                  structureDescription: structureDefinition, modelTargetName: modelTargetName,
                                  fileBuilder: fileBuilder,
                                  includeVariableDocumentation: false,
                                  generateShapeProtocol: false,
                                  modelName: inputTypeName)
                fileBuilder.appendEmptyLine()
                createConversionFunction(originalTypeName: inputTypeName,
                                         derivedTypeName: bodyTypeName,
                                         members: bodyMembers,
                                         modelTargetName: modelTargetName,
                                         fileBuilder: fileBuilder)
            }
            
            bodyTypeConversion = "encodable.as\(modelTargetName)\(operationPrefix)Body()"
        } else {
            bodyTypeName = "String"
            bodyTypeConversion = "nil"
        }
        
        return (bodyTypeName: bodyTypeName, bodyTypeConversion: bodyTypeConversion)
    }
    
    private func addAdditionalHeadersOperationHTTPRequestInput(additionalHeadersMembers: [String: Member],
                                                               inputTypeName: String,
                                                               operationPrefix: String,
                                                               name: String,
                                                               generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                                               modelTargetName: String,
                                                               fileBuilder: FileBuilder)
        -> (additionalHeadersTypeName: String, additionalHeadersTypeConversion: String) {
            let additionalHeadersTypeName: String
            let additionalHeadersTypeConversion: String
            if !additionalHeadersMembers.isEmpty {
                additionalHeadersTypeName = "\(operationPrefix)AdditionalHeaders"
                let structureDefinition = StructureDescription(
                    members: additionalHeadersMembers,
                    documentation: "Structure to encode the body input for the \(name) operation.")
                
                if case .supportingStructures = generationType {
                    generateStructure(name: additionalHeadersTypeName,
                                      structureDescription: structureDefinition, modelTargetName: modelTargetName,
                                      fileBuilder: fileBuilder,
                                      includeVariableDocumentation: false,
                                      generateShapeProtocol: false,
                                      modelName: inputTypeName)
                    fileBuilder.appendEmptyLine()
                    createConversionFunction(originalTypeName: inputTypeName,
                                             derivedTypeName: additionalHeadersTypeName,
                                             members: additionalHeadersMembers,
                                             modelTargetName: modelTargetName,
                                             fileBuilder: fileBuilder)
                }
                
                additionalHeadersTypeConversion = "encodable.as\(modelTargetName)\(operationPrefix)AdditionalHeaders()"
            } else {
                additionalHeadersTypeName = "String"
                additionalHeadersTypeConversion = "nil"
            }
            
            return (additionalHeadersTypeName: additionalHeadersTypeName,
                    additionalHeadersTypeConversion: additionalHeadersTypeConversion)
    }
    
    private func addAsMember(fieldName: String, members: inout [String: Member],
                             unassignedMembers: inout [String: Member]) {
        if let member = unassignedMembers[fieldName] {
            members[fieldName] = member
            unassignedMembers[fieldName] = nil
        }
    }
    
    private func getBodyTypeNameAndConversion(inputDescription: OperationInputDescription, structureDefinition: StructureDescription,
                                              name: String, bodyMembers: [String: Member], inputTypeName: String,
                                              operationPrefix: String, generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                              modelTargetName: String,
                                              fileBuilder: FileBuilder) -> (bodyTypeName: String, bodyTypeConversion: String) {
        if let payloadAsMember = inputDescription.payloadAsMember {
            guard let payloadMember = structureDefinition.members[payloadAsMember] else {
                fatalError("Unknown payload member.")
            }
            
            let parameterName = getNormalizedVariableName(
                modelTypeName: payloadAsMember,
                inStructure: name,
                reservedWordsAllowed: true)
            
            let bodyTypeName = payloadMember.value.getNormalizedTypeName(forModel: model)
            let bodyTypeConversion = "encodable.\(parameterName)"
            
            return (bodyTypeName, bodyTypeConversion)
        } else {
            return addBodyOperationHTTPRequestInput(
                bodyMembers: bodyMembers, inputTypeName: inputTypeName, operationPrefix: operationPrefix, name: name,
                generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        }
    }
    
    private func addMultiLocationOperationHTTPRequestInput(structureDefinition: StructureDescription,
                                                           inputDescription: OperationInputDescription,
                                                           inputType: String,
                                                           inputTypeName: String,
                                                           operationPrefix: String,
                                                           name: String,
                                                           generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                                           modelTargetName: String,
                                                           fileBuilder: FileBuilder) {
        var unassignedMembers = structureDefinition.members
        var pathMembers: [String: Member] = [:]
        var queryMembers: [String: Member] = [:]
        var bodyMembers: [String: Member] = [:]
        var additionalHeadersMembers: [String: Member] = [:]
        
        inputDescription.pathFields.forEach { addAsMember(fieldName: $0, members: &pathMembers, unassignedMembers: &unassignedMembers) }
        inputDescription.queryFields.forEach { addAsMember(fieldName: $0, members: &queryMembers, unassignedMembers: &unassignedMembers) }
        inputDescription.bodyFields.forEach { addAsMember(fieldName: $0, members: &bodyMembers, unassignedMembers: &unassignedMembers) }
        inputDescription.additionalHeaderFields.forEach { addAsMember(fieldName: $0, members: &additionalHeadersMembers,
                                                                      unassignedMembers: &unassignedMembers) }
        
        let pathTemplateConversion: String
        if let name = inputDescription.pathTemplateField,
            unassignedMembers[name] != nil {
            let variableName = getNormalizedVariableName(modelTypeName: name,
                                                         inStructure: inputType)
            pathTemplateConversion = "encodable.\(variableName)"
            unassignedMembers[name] = nil
        } else {
            pathTemplateConversion = "nil"
        }
        
        switch inputDescription.defaultInputLocation {
        case .body:
            bodyMembers.merge(unassignedMembers) { (old, _) in old }
        case .query:
            queryMembers.merge(unassignedMembers) { (old, _) in old }
        }
        
        let (pathTypeName, pathTypeConversion) = addPathOperationHTTPRequestInput(
            pathMembers: pathMembers, inputTypeName: inputTypeName, operationPrefix: operationPrefix, name: name,
            generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        let (queryTypeName, queryTypeConversion) = addQueryOperationHTTPRequestInput(
            queryMembers: queryMembers, inputTypeName: inputTypeName, operationPrefix: operationPrefix, name: name,
            generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        
        let (bodyTypeName, bodyTypeConversion) = getBodyTypeNameAndConversion(
            inputDescription: inputDescription, structureDefinition: structureDefinition,
            name: name, bodyMembers: bodyMembers, inputTypeName: inputTypeName,
            operationPrefix: operationPrefix, generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        
        let (additionalHeadersTypeName, additionalHeadersTypeConversion) = addAdditionalHeadersOperationHTTPRequestInput(
            additionalHeadersMembers: additionalHeadersMembers, inputTypeName: inputTypeName, operationPrefix: operationPrefix, name: name,
            generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder)
        
        let httpRequestInputTypes = HTTPRequestInputTypes(queryTypeName: queryTypeName, queryTypeConversion: queryTypeConversion,
                                                          pathTypeName: pathTypeName, pathTypeConversion: pathTypeConversion,
                                                          bodyTypeName: bodyTypeName, bodyTypeConversion: bodyTypeConversion,
                                                          additionalHeadersTypeName: additionalHeadersTypeName,
                                                          additionalHeadersTypeConversion: additionalHeadersTypeConversion,
                                                          pathTemplateConversion: pathTemplateConversion)
        
        addRequestInputStructure(generationType: generationType, fileBuilder: fileBuilder, name: name,
                                 inputTypeName: inputTypeName, httpRequestInputTypes: httpRequestInputTypes)
    }
    
    func addOperationHTTPRequestInput(operation: String,
                                      operationDescription: OperationDescription,
                                      generationType: ClientInputGenerationType,
                                      modelTargetName: String,
                                      fileBuilder: FileBuilder) {
        
        let name = operation.getNormalizedTypeName(forModel: model)
        
        guard let inputType = operationDescription.input else {
            // nothing to be done
            return
        }
        guard let structureDefinition = model.structureDescriptions[inputType] else {
            fatalError("No structure with type \(inputType)")
        }
        
        let inputDescription: OperationInputDescription
        if let override = modelOverride?.operationInputOverrides?[name] {
            inputDescription = override
        } else {
            inputDescription = operationDescription.inputDescription
        }
        
        let inputTypeName = inputType.getNormalizedTypeName(forModel: model)
        let operationPrefix = "\(name)OperationInput"
        
        if inputDescription.onlyHasDefaultLocation {
            guard case .requestInput = generationType else {
                // nothing to be done
                return
            }
            
            switch inputDescription.defaultInputLocation {
            case .body:
                fileBuilder.appendLine("""
                    
                    /**
                     Type to handle the input to the \(name) operation in a HTTP client.
                     */
                    public typealias \(name)OperationHTTPRequestInput = BodyHTTPRequestInput
                    """)
            case .query:
                fileBuilder.appendLine("""
                    
                    /**
                     Type to handle the input to the \(name) operation in a HTTP client.
                     */
                    public typealias \(name)OperationHTTPRequestInput = QueryHTTPRequestInput
                    """)
            }
        } else {
            addMultiLocationOperationHTTPRequestInput(
                structureDefinition: structureDefinition,
                inputDescription: inputDescription,
                inputType: inputType,
                inputTypeName: inputTypeName,
                operationPrefix: operationPrefix,
                name: name,
                generationType: generationType, modelTargetName: modelTargetName,
                fileBuilder: fileBuilder)
        }
    }
    
    enum ClientInputGenerationType {
        case supportingStructures
        case requestInput
    }
}
