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
// ServiceModelCodeGenerator+generateClient.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    private struct OperationSignature {
        let input: String
        let functionInputType: String?
        let output: String
        let functionOutputType: String?
        let errors: String
    }
    
    /**
     Generate a client from the Service Model.
     
     - Parameters:
        - delegate: The delegate to use when generating this client.
     */
    func generateClient(delegate: ModelClientDelegate, isGenerator: Bool) {
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        
        let typeName: String
        let typeDescription = delegate.getFileDescription(isGenerator: isGenerator)
        
        let typePostfix = isGenerator ? "Generator" : ""
        
        let typeDecaration: String
        switch delegate.clientType {
        case .protocol(name: let protocolTypeName):
            typeName = protocolTypeName + typePostfix
            typeDecaration = "protocol \(typeName)"
        case .struct(name: let structTypeName, genericParameters: let genericParameters, conformingProtocolNames: let protocolTypeNames):
            typeName = structTypeName + typePostfix
            
            if isGenerator {
                typeDecaration = "struct \(typeName)"
            } else {
                let genericParametersString: String
                if !genericParameters.isEmpty {
                    let parameters: [String] = genericParameters.map { parameter in
                        if let conformingTypeName = parameter.conformingTypeName {
                            return "\(parameter.typeName): \(conformingTypeName)"
                        } else {
                            return parameter.typeName
                        }
                    }
                    
                    genericParametersString = "<\(parameters.joined(separator: " ,"))>"
                } else {
                    genericParametersString = ""
                }
                typeDecaration = "struct \(typeName)\(genericParametersString): \(protocolTypeNames.joined(separator: ", "))"
            }
        }
        
        addFileHeader(fileBuilder: fileBuilder, typeName: typeName,
                      delegate: delegate, isGenerator: isGenerator)
        
        delegate.addCustomFileHeader(codeGenerator: self, delegate: delegate,
                                     fileBuilder: fileBuilder, isGenerator: isGenerator)
        
        fileBuilder.appendLine("""
            
            /**
             \(typeDescription)
             */
            public \(typeDecaration) {
            """)
        
        fileBuilder.incIndent()
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        delegate.addCommonFunctions(codeGenerator: self, delegate: delegate,
                                    fileBuilder: fileBuilder,
                                    sortedOperations: sortedOperations, isGenerator: isGenerator)
        
        if !isGenerator {
            // for each of the operations
            for (name, operationDescription) in sortedOperations {
                addOperation(fileBuilder: fileBuilder, name: name,
                             operationDescription: operationDescription,
                             delegate: delegate, invokeType: .eventLoopFutureAsync,
                             forTypeAlias: false, isGenerator: isGenerator)
            }
        }
        fileBuilder.appendLine("}", preDec: true)
        let baseFilePath = applicationDescription.baseFilePath
        
        let fileName = "\(typeName).swift"
        fileBuilder.write(toFile: fileName,
                          atFilePath: "\(baseFilePath)/Sources/\(baseName)Client")
    }
    
    private func addOperationInput(fileBuilder: FileBuilder,
                                   operationDescription: OperationDescription,
                                   labelPrefix: String, invokeType: InvokeType,
                                   forTypeAlias: Bool) -> (input: String, functionInputType: String?) {
        let input: String
        let functionInputType: String?
        let baseName = applicationDescription.baseName
        if let inputType = operationDescription.input {
            let type = inputType.getNormalizedTypeName(forModel: model)
            
            input = "\(labelPrefix)input: \(baseName)Model.\(type)"
            
            if !forTypeAlias {
                fileBuilder.appendEmptyLine()
                fileBuilder.appendLine(" - Parameters:")
                fileBuilder.appendLine("     - input: The validated \(type) object being passed to this operation.")
            }
            functionInputType = type
        } else {
            input = ""
            functionInputType = nil
        }
        
        return (input: input, functionInputType: functionInputType)
    }
    
    private func addOperationOutput(fileBuilder: FileBuilder,
                                    operationDescription: OperationDescription,
                                    delegate: ModelClientDelegate,
                                    labelPrefix: String, invokeType: InvokeType,
                                    forTypeAlias: Bool) -> (output: String, functionOutputType: String?) {
        let output: String
        let functionOutputType: String?
        let baseName = applicationDescription.baseName
        if let outputType = operationDescription.output {
            let type = outputType.getNormalizedTypeName(forModel: model)
            
            switch invokeType {
            case .eventLoopFutureAsync:
                output = " -> EventLoopFuture<\(baseName)Model.\(type)>"
                if !forTypeAlias {
                    fileBuilder.appendLine(" - Returns: A future to the \(type) object to be passed back from the caller of this operation.")
                    fileBuilder.appendLine("     Will be validated before being returned to caller.")
                }
            }
            functionOutputType = type
        } else {
            switch invokeType {
            case .eventLoopFutureAsync:
                output = " -> EventLoopFuture<Void>"
            }
            
            functionOutputType = nil
        }
        
        return (output: output, functionOutputType: functionOutputType)
    }
    
    func addOperationError(fileBuilder: FileBuilder,
                           operationDescription: OperationDescription,
                           invokeType: InvokeType, forTypeAlias: Bool) -> String {
        let errors: String
        switch invokeType {
        case .eventLoopFutureAsync:
            errors = ""
        }
        if !operationDescription.errors.isEmpty && !forTypeAlias {
            var description: String
            
            switch invokeType {
            case .eventLoopFutureAsync:
                description = "       The possible errors are: "
            }
            
            let errors = operationDescription.errors
                .sorted(by: <)
                .map { $0.type.normalizedErrorName }
                .joined(separator: ", ")
            
            description += "\(errors)."
            fileBuilder.appendLine(description)
        }
        
        return errors
    }
    
    private func addFunctionDeclarationWithNoInput(forTypeAlias: Bool, invokeType: InvokeType, fileBuilder: FileBuilder,
                                                   declarationPrefix: String, functionName: String, errors: String, output: String,
                                                   declarationPostfix: String) {
        if !forTypeAlias {
            switch invokeType {
            case .eventLoopFutureAsync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)func \(functionName)()\(errors)\(output)\(declarationPostfix)
                    """)
            }
        } else {
            switch invokeType {
            case .eventLoopFutureAsync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)typealias \(functionName)\(invokeType.rawValue)Type = ()\(errors)\(output)\(declarationPostfix)
                    """)
            }
        }
    }
    
    private func addFunctionDeclarationWithInput(forTypeAlias: Bool, invokeType: InvokeType, fileBuilder: FileBuilder,
                                                 declarationPrefix: String, functionName: String, input: String,
                                                 errors: String, output: String, declarationPostfix: String) {
        if !forTypeAlias {
            switch invokeType {
            case .eventLoopFutureAsync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)func \(functionName)(
                            \(input))\(errors)\(output)\(declarationPostfix)
                    """)
            }
        } else {
            switch invokeType {
            case .eventLoopFutureAsync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)typealias \(functionName)\(invokeType.rawValue)Type = (
                            \(input))\(errors)\(output)\(declarationPostfix)
                    """)
            }
        }
    }
    
    private func addOperationBody(fileBuilder: FileBuilder, name: String,
                                  operationDescription: OperationDescription,
                                  delegate: ModelClientDelegate,
                                  invokeType: InvokeType, forTypeAlias: Bool,
                                  operationSignature: OperationSignature,
                                  isGenerator: Bool) {
        let functionName: String
        if !forTypeAlias {
            fileBuilder.appendLine(" */")
            functionName = name.upperToLowerCamelCase
        } else {
            functionName = name.getNormalizedTypeName(forModel: model)
        }
        
        let input = operationSignature.input
        let output = operationSignature.output
        let errors = operationSignature.errors
        
        let declarationPrefix: String
        let declarationPostfix: String
        if case .protocol = delegate.clientType {
            declarationPrefix = ""
            declarationPostfix = ""
        } else {
            declarationPrefix = "public "
            declarationPostfix = " {"
        }
        if input.isEmpty {
            addFunctionDeclarationWithNoInput(forTypeAlias: forTypeAlias, invokeType: invokeType, fileBuilder: fileBuilder,
                                              declarationPrefix: declarationPrefix, functionName: functionName, errors: errors,
                                              output: output, declarationPostfix: declarationPostfix)
        } else {
            addFunctionDeclarationWithInput(forTypeAlias: forTypeAlias, invokeType: invokeType, fileBuilder: fileBuilder,
                                            declarationPrefix: declarationPrefix, functionName: functionName, input: input,
                                            errors: errors, output: output, declarationPostfix: declarationPostfix)
        }
        
        delegate.addOperationBody(codeGenerator: self, delegate: delegate,
                                  fileBuilder: fileBuilder,
                                  invokeType: invokeType,
                                  operationName: name,
                                  operationDescription: operationDescription,
                                  functionInputType: operationSignature.functionInputType,
                                  functionOutputType: operationSignature.functionOutputType,
                                  isGenerator: isGenerator)
    }
    
    /**
     Generates an operation on the client.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - name: The operation name.
        - operationDescription: the description of the operation.
        - delegate: The delegate being used to generate this client.
        - invokeType: the invocation type of the operation.
        - forTypeAlias: true if a typealias for the operation should be generated,
          otherwise the full function
     */
    internal func addOperation(fileBuilder: FileBuilder, name: String,
                               operationDescription: OperationDescription,
                               delegate: ModelClientDelegate,
                               invokeType: InvokeType, forTypeAlias: Bool,
                               isGenerator: Bool) {
        if !forTypeAlias {
            let invokeDescription: String
            switch invokeType {
            case .eventLoopFutureAsync:
                invokeDescription = "returning immediately with an `EventLoopFuture` that will be completed with the result at a later time"
            }
            fileBuilder.appendEmptyLine()
            fileBuilder.appendLine("""
                /**
                 Invokes the \(name) operation \(invokeDescription).
                """)
        }
        
        let labelPrefix = forTypeAlias ? "_ " : ""
        
        // if there is input
        let operationInput = addOperationInput(fileBuilder: fileBuilder, operationDescription: operationDescription,
                                               labelPrefix: labelPrefix, invokeType: invokeType, forTypeAlias: forTypeAlias)
        
        // if there is output
        let operationOuput = addOperationOutput(fileBuilder: fileBuilder, operationDescription: operationDescription,
                                                delegate: delegate, labelPrefix: labelPrefix, invokeType: invokeType,
                                                forTypeAlias: forTypeAlias)
        
        // if there can be errors
        let errors = addOperationError(fileBuilder: fileBuilder, operationDescription: operationDescription,
                                       invokeType: invokeType, forTypeAlias: forTypeAlias)
        
        let operationSignature = OperationSignature(input: operationInput.input,
                                                    functionInputType: operationInput.functionInputType,
                                                    output: operationOuput.output,
                                                    functionOutputType: operationOuput.functionOutputType,
                                                    errors: errors)
        
        addOperationBody(fileBuilder: fileBuilder, name: name, operationDescription: operationDescription,
                         delegate: delegate, invokeType: invokeType, forTypeAlias: forTypeAlias,
                         operationSignature: operationSignature, isGenerator: isGenerator)
    }
    
    func addGeneratedFileHeader(fileBuilder: FileBuilder) {
        fileBuilder.appendLine("""
            // swiftlint:disable superfluous_disable_command
            // swiftlint:disable file_length line_length identifier_name type_name vertical_parameter_alignment
            // swiftlint:disable type_body_length function_body_length generic_type_name cyclomatic_complexity
            // -- Generated Code; do not edit --
            //
            """)
    }
    
    private func addFileHeader(fileBuilder: FileBuilder,
                               typeName: String,
                               delegate: ModelClientDelegate,
                               isGenerator: Bool) {
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(typeName).swift
            // \(baseName)Client
            //
            
            import Foundation
            import \(baseName)Model
            import SmokeAWSCore
            import SmokeHTTPClient
            """)
        
        if !isGenerator {
            fileBuilder.appendLine("""
                import NIO
                """)
        }
        
        if let libraryImport = delegate.asyncResultType?.libraryImport {
            fileBuilder.appendLine("""
                import \(libraryImport)
                """)
        }
    }
}
