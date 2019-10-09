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
    func generateClient(delegate: ModelClientDelegate) {
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        
        let typeName: String
        let typeDescription = delegate.typeDescription
        
        let typeDecaration: String
        switch delegate.clientType {
        case .protocol(name: let protocolTypeName):
            typeName = protocolTypeName
            typeDecaration = "protocol \(typeName)"
        case .struct(name: let structTypeName, conformingProtocolName: let protocolTypeName):
            typeName = structTypeName
            typeDecaration = "struct \(typeName): \(protocolTypeName)"
        }
        
        addFileHeader(fileBuilder: fileBuilder, typeName: typeName,
                      delegate: delegate)
        
        delegate.addCustomFileHeader(codeGenerator: self, delegate: delegate,
                                     fileBuilder: fileBuilder)
        
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
                                    sortedOperations: sortedOperations)
        
        // for each of the operations
        for (name, operationDescription) in sortedOperations {
            addOperation(fileBuilder: fileBuilder, name: name,
                         operationDescription: operationDescription,
                         delegate: delegate, invokeType: .async,
                         forTypeAlias: false)
            addOperation(fileBuilder: fileBuilder, name: name,
                         operationDescription: operationDescription,
                         delegate: delegate, invokeType: .sync,
                         forTypeAlias: false)
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
            
            if case .async = invokeType {
                input = "\(labelPrefix)input: \(baseName)Model.\(type), "
            } else {
                input = "\(labelPrefix)input: \(baseName)Model.\(type)"
            }
            
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
            case .sync:
                output = " -> \(baseName)Model.\(type)"
                if !forTypeAlias {
                    fileBuilder.appendLine(" - Returns: The \(type) object to be passed back from the caller of this operation.")
                    fileBuilder.appendLine("     Will be validated before being returned to caller.")
                }
            case .async:
                let asyncResultType = delegate.asyncResultType.typeName
                
                output = "\(labelPrefix)completion: @escaping (\(asyncResultType)<\(baseName)Model.\(type)>) -> ()"
                if !forTypeAlias {
                    fileBuilder.appendLine("     - completion: The \(type) object or an error will be passed to this ")
                    fileBuilder.appendLine("       callback when the operation is complete. The \(type)")
                    fileBuilder.appendLine("       object will be validated before being returned to caller.")
                }
            }
            functionOutputType = type
        } else {
            switch invokeType {
            case .sync:
                if !forTypeAlias {
                    output = ""
                } else {
                    output = " -> ()"
                }
            case .async:
                output = "\(labelPrefix)completion: @escaping (Swift.Error?) -> ()"
                if !forTypeAlias {
                    fileBuilder.appendLine("     - completion: Nil or an error will be passed to this callback when the operation")
                    fileBuilder.appendLine("       is complete.")
                }
            }
            
            functionOutputType = nil
        }
        
        return (output: output, functionOutputType: functionOutputType)
    }
    
    func addOperationError(fileBuilder: FileBuilder,
                           operationDescription: OperationDescription,
                           invokeType: InvokeType, forTypeAlias: Bool) -> String {
        let errors = " throws"
        if !operationDescription.errors.isEmpty && !forTypeAlias {
            var description: String
            
            switch invokeType {
            case .sync:
                description = " - Throws: "
            case .async:
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
    
    private func addOperationBody(fileBuilder: FileBuilder, name: String,
                                  operationDescription: OperationDescription,
                                  delegate: ModelClientDelegate,
                                  invokeType: InvokeType, forTypeAlias: Bool,
                                  operationSignature: OperationSignature) {
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
        
        if !forTypeAlias {
            switch invokeType {
            case .sync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)func \(functionName)\(invokeType.rawValue)(\(input))\(errors)\(output)\(declarationPostfix)
                    """)
            case .async:
                fileBuilder.appendLine("""
                    \(declarationPrefix)func \(functionName)\(invokeType.rawValue)(\(input)\(output))\(errors)\(declarationPostfix)
                    """)
            }
        } else {
            switch invokeType {
            case .sync:
                fileBuilder.appendLine("""
                    \(declarationPrefix)typealias \(functionName)\(invokeType.rawValue)Type = (\(input))\(errors)\(output)\(declarationPostfix)
                    """)
            case .async:
                fileBuilder.appendLine("""
                    \(declarationPrefix)typealias \(functionName)\(invokeType.rawValue)Type = (\(input)\(output))\(errors)\(declarationPostfix) -> ()
                    """)
            }
        }
        
        delegate.addOperationBody(codeGenerator: self, delegate: delegate,
                                  fileBuilder: fileBuilder,
                                  invokeType: invokeType,
                                  operationName: name,
                                  operationDescription: operationDescription,
                                  functionInputType: operationSignature.functionInputType,
                                  functionOutputType: operationSignature.functionOutputType)
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
                               invokeType: InvokeType, forTypeAlias: Bool) {
        if !forTypeAlias {
            let invokeDescription: String
            switch invokeType {
            case .sync:
                invokeDescription = "waiting for the response before returning"
            case .async:
                invokeDescription = "returning immediately and passing the response to a callback"
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
                         delegate: delegate, invokeType: invokeType, forTypeAlias: forTypeAlias, operationSignature: operationSignature)
    }
    
    private func addFileHeader(fileBuilder: FileBuilder,
                               typeName: String,
                               delegate: ModelClientDelegate) {
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        fileBuilder.appendLine("""
            // swiftlint:disable superfluous_disable_command
            // swiftlint:disable file_length line_length identifier_name type_name vertical_parameter_alignment type_body_length
            // -- Generated Code; do not edit --
            //
            // \(typeName).swift
            // \(baseName)Client
            //
            
            import Foundation
            import \(baseName)Model
            import \(delegate.asyncResultType.libraryImport)
            """)
    }
}
