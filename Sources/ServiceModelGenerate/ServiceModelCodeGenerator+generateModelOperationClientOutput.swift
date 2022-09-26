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
// ServiceModelCodeGenerator+generateModelOperationClientOutput.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport & ClientTargetSupport {
    private struct HTTPResponseOutputTypes {
        let bodyTypeName: String
        let headersTypeName: String
        let membersLocation: [String: LocationOutput]
        let payloadAsMember: String?
    }
    
    /**
     Generate client output for each operation.
     */
    func generateModelOperationClientOutput() {
        let baseName = applicationDescription.baseName
        let modelTargetName = self.targetSupport.modelTargetName
        let clientTargetName = self.targetSupport.clientTargetName
        
        let fileBuilder = FileBuilder()
        
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)OperationsClientOutput.swift
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
        
        var alreadyEmittedTypes: [String: OperationOutputDescription] = [:]
        sortedOperations.forEach { operation in
            addOperationHTTPRequestOutput(operation: operation.key,
                                         operationDescription: operation.value,
                                         generationType: .responseOutput,
                                         fileBuilder: fileBuilder,
                                         alreadyEmittedTypes: &alreadyEmittedTypes)
        }
        
        let fileName = "\(baseName)OperationsClientOutput.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(clientTargetName)")
    }
    
    private func addBodyOperationHTTPResponseOutput(bodyMembers: [String: Member],
                                                    outputTypeName: String,
                                                    operationPrefix: String,
                                                    name: String,
                                                    generationType: ServiceModelCodeGenerator.ClientOutputGenerationType,
                                                    fileBuilder: FileBuilder) -> String {
        let bodyTypeName: String
        if !bodyMembers.isEmpty {
            bodyTypeName = "\(operationPrefix)Body"
            let structureDefinition = StructureDescription(
                members: bodyMembers,
                documentation: "Structure to encode the body input for the \(name) operation.")
            
            if case .supportingStructures = generationType {
                generateStructure(name: bodyTypeName,
                                  structureDescription: structureDefinition,
                                  fileBuilder: fileBuilder,
                                  includeVariableDocumentation: false,
                                  generateShapeProtocol: false,
                                  modelName: outputTypeName)
                fileBuilder.appendEmptyLine()
                createConversionFunction(originalTypeName: outputTypeName,
                                         derivedTypeName: bodyTypeName,
                                         members: bodyMembers,
                                         fileBuilder: fileBuilder)
            }
        } else {
            bodyTypeName = "String"
        }
        
        return bodyTypeName
    }
    
    private func addHeadersOperationHTTPResponseOutput(headersMembers: [String: Member],
                                                       outputTypeName: String,
                                                       operationPrefix: String,
                                                       name: String,
                                                       generationType: ServiceModelCodeGenerator.ClientOutputGenerationType,
                                                       fileBuilder: FileBuilder)
        -> String {
            let headersTypeName: String
            if !headersMembers.isEmpty {
                headersTypeName = "\(operationPrefix)Headers"
                let structureDefinition = StructureDescription(
                    members: headersMembers,
                    documentation: "Structure to encode the body input for the \(name) operation.")
                
                if case .supportingStructures = generationType {
                    generateStructure(name: headersTypeName,
                                      structureDescription: structureDefinition,
                                      fileBuilder: fileBuilder,
                                      includeVariableDocumentation: false,
                                      generateShapeProtocol: false,
                                      modelName: outputTypeName)
                    fileBuilder.appendEmptyLine()
                    createConversionFunction(originalTypeName: outputTypeName,
                                             derivedTypeName: headersTypeName,
                                             members: headersMembers,
                                             fileBuilder: fileBuilder)
                }
            } else {
                headersTypeName = "String"
            }
            
            return headersTypeName
    }
    
    private func addAsMember(fieldName: String, members: inout [String: Member],
                             unassignedMembers: inout [String: Member]) {
        if let member = unassignedMembers[fieldName] {
            members[fieldName] = member
            unassignedMembers[fieldName] = nil
        }
    }
    
    private func addResponseOutputStructure(
            generationType: ServiceModelCodeGenerator.ClientOutputGenerationType,
            fileBuilder: FileBuilder,
            name: String, outputTypeName: String,
            httpResponseOutputTypes: HTTPResponseOutputTypes) {
        if case .responseOutput = generationType {
            fileBuilder.appendLine("""
                
                /**
                 Type to handle the output from the \(name) operation in a HTTP client.
                 */
                extension \(outputTypeName): HTTPResponseOutputProtocol {
                    public typealias BodyType = \(httpResponseOutputTypes.bodyTypeName)
                    public typealias HeadersType = \(httpResponseOutputTypes.headersTypeName)
                
                    public static func compose(bodyDecodableProvider: () throws -> BodyType,
                                               headersDecodableProvider: () throws -> HeadersType) throws -> \(outputTypeName) {
                        let body = try bodyDecodableProvider()
                        let headers = try headersDecodableProvider()
                
                """)
            
            fileBuilder.incIndent()
            fileBuilder.incIndent()
            createOutputStructureStubVariable(type: outputTypeName,
                                              fileBuilder: fileBuilder,
                                              declarationPrefix: "return",
                                              memberLocation: httpResponseOutputTypes.membersLocation,
                                              payloadAsMember: httpResponseOutputTypes.payloadAsMember)
            fileBuilder.decIndent()
            fileBuilder.decIndent()
                
            fileBuilder.appendLine("""
                    }
                }
                """)
        }
    }
    
    private func addMultiLocationOperationHTTPResponseOutput(
        structureDefinition: StructureDescription,
        outputDescription: OperationOutputDescription,
        outputType: String,
        outputTypeName: String,
        operationPrefix: String,
        name: String,
        generationType: ServiceModelCodeGenerator.ClientOutputGenerationType,
        fileBuilder: FileBuilder) {
            var unassignedMembers = structureDefinition.members
            var bodyMembers: [String: Member] = [:]
            var headersMembers: [String: Member] = [:]
            var membersLocation: [String: LocationOutput] = [:]
        
            outputDescription.bodyFields.forEach {
                addAsMember(fieldName: $0, members: &bodyMembers, unassignedMembers: &unassignedMembers)
                membersLocation[$0] = .body
            }
            outputDescription.headerFields.forEach {
                addAsMember(fieldName: $0, members: &headersMembers,
                            unassignedMembers: &unassignedMembers)
                membersLocation[$0] = .headers
            }
            unassignedMembers.forEach { membersLocation[$0.key] = .body }

            bodyMembers.merge(unassignedMembers) { (old, _) in old }
        
            // if there are no body
            if bodyMembers.isEmpty {
                guard case .responseOutput = generationType else {
                    // nothing to be done
                    return
                }
        
                addSingleLocationOperationHttpResponseOutput(fileBuilder: fileBuilder,
                                                             name: name,
                                                             outputTypeName: outputTypeName,
                                                             locationOutput: .headers)
                
                return
            }
        
            let bodyTypeName: String
        
            if let payloadAsMember = outputDescription.payloadAsMember {
                guard let payloadMember = structureDefinition.members[payloadAsMember] else {
                    fatalError("Unknown payload member.")
                }
                
                bodyTypeName = payloadMember.value.getNormalizedTypeName(forModel: model)
            } else {
                bodyTypeName = addBodyOperationHTTPResponseOutput(
                    bodyMembers: bodyMembers, outputTypeName: outputTypeName,
                    operationPrefix: operationPrefix, name: name,
                    generationType: generationType, fileBuilder: fileBuilder)
            }
            let headersTypeName = addHeadersOperationHTTPResponseOutput(
                headersMembers: headersMembers, outputTypeName: outputTypeName, operationPrefix: operationPrefix, name: name,
                generationType: generationType, fileBuilder: fileBuilder)
        
            let httpResponseOutputTypes = HTTPResponseOutputTypes(
                bodyTypeName: bodyTypeName,
                headersTypeName: headersTypeName,
                membersLocation: membersLocation,
                payloadAsMember: outputDescription.payloadAsMember)
        
            addResponseOutputStructure(generationType: generationType, fileBuilder: fileBuilder, name: name,
                                       outputTypeName: outputTypeName, httpResponseOutputTypes: httpResponseOutputTypes)
    }
    
    private func addSingleLocationOperationHttpResponseOutput(
            fileBuilder: FileBuilder,
            name: String,
            outputTypeName: String,
            locationOutput: LocationOutput) {
        let providerToUse: String
        
        switch locationOutput {
        case .body:
            providerToUse = "bodyDecodableProvider"
        case .headers:
            providerToUse = "headersDecodableProvider"
        }
        
        fileBuilder.appendLine("""
            
            /**
             Type to handle the output from the \(name) operation in a HTTP client.
             */
            extension \(outputTypeName): HTTPResponseOutputProtocol {
                public typealias BodyType = \(outputTypeName)
                public typealias HeadersType = \(outputTypeName)
            
                public static func compose(bodyDecodableProvider: () throws -> BodyType,
                                           headersDecodableProvider: () throws -> HeadersType) throws -> \(outputTypeName) {
                    return try \(providerToUse)()
                }
            }
            """)
    }
    
    func addOperationHTTPRequestOutput(operation: String,
                                       operationDescription: OperationDescription,
                                       generationType: ClientOutputGenerationType,
                                       fileBuilder: FileBuilder,
                                       alreadyEmittedTypes: inout [String: OperationOutputDescription]) {
        
        let name = operation.getNormalizedTypeName(forModel: model)
        
        guard let outputType = operationDescription.output else {
            // nothing to be done
            return
        }
        guard let structureDefinition = model.structureDescriptions[outputType] else {
            fatalError("No structure with type \(outputType)")
        }
        
        let outputDescription: OperationOutputDescription
        if let override = modelOverride?.operationOutputOverrides?[name] {
            outputDescription = override
        } else {
            outputDescription = operationDescription.outputDescription
        }
        
        let outputTypeName = outputType.getNormalizedTypeName(forModel: model)
        let operationPrefix = "\(name)OperationOutput"
        
        if let previousOperation = alreadyEmittedTypes[outputTypeName] {
            if previousOperation != outputDescription {
                fatalError("Incompatible duplicate operation outputs for \(outputTypeName)")
            }
            
            return
        }
        alreadyEmittedTypes[outputTypeName] = outputDescription
        
        // if there are no headers
        if outputDescription.headerFields.isEmpty {
            guard case .responseOutput = generationType else {
                // nothing to be done
                return
            }
            
            addSingleLocationOperationHttpResponseOutput(fileBuilder: fileBuilder,
                                                         name: name,
                                                         outputTypeName: outputTypeName,
                                                         locationOutput: .body)
        } else {
            addMultiLocationOperationHTTPResponseOutput(
                structureDefinition: structureDefinition,
                outputDescription: outputDescription,
                outputType: outputType,
                outputTypeName: outputTypeName,
                operationPrefix: operationPrefix,
                name: name,
                generationType: generationType,
                fileBuilder: fileBuilder)
        }
    }
    
    enum ClientOutputGenerationType {
        case supportingStructures
        case responseOutput
    }
}
