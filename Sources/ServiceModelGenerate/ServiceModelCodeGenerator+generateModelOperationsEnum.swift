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
// ServiceModelCodeGenerator+generateModelOperationsEnum.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    /**
     Generate an operation enumeration for the model.
     */
    public func generateModelOperationsEnum() {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        fileBuilder.appendLine("""
            // swiftlint:disable superfluous_disable_command
            // swiftlint:disable file_length line_length identifier_name type_name vertical_parameter_alignment
            // -- Generated Code; do not edit --
            //
            // \(baseName)ModelOperations.swift
            // \(baseName)Model
            //
            
            import Foundation
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        fileBuilder.appendLine("""
            
            /**
             Operation enumeration for the \(baseName)Model.
             */
            public enum \(baseName)ModelOperations: String {
            """)
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        fileBuilder.incIndent()
        addOperationCases(sortedOperations: sortedOperations, fileBuilder: fileBuilder)
        fileBuilder.appendEmptyLine()
        
        addOperationPathEnum(fileBuilder, sortedOperations)
        fileBuilder.appendLine("""
            }
            """)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("}")
        
        var alreadyEmittedTypes: [String: OperationOutputDescription] = [:]
        sortedOperations.forEach { operation in
            addOperationHTTPRequestInput(operation: operation.key,
                                         operationDescription: operation.value,
                                         generationType: .supportingStructures,
                                         fileBuilder: fileBuilder)
            
            addOperationHTTPRequestOutput(operation: operation.key,
                                          operationDescription: operation.value,
                                          generationType: .supportingStructures,
                                          fileBuilder: fileBuilder,
                                          alreadyEmittedTypes: &alreadyEmittedTypes)
        }
        
        let fileName = "\(baseName)ModelOperations.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(baseName)Model")
    }
    
    private func addOperationCases(sortedOperations: [(key: String, value: OperationDescription)], fileBuilder: FileBuilder) {
        // for each of the operations
        for (name, _) in sortedOperations {
            // convert to lower camel case
            let internalName = name.upperToLowerCamelCase
            
            if internalName == name {
                fileBuilder.appendLine("case \(internalName)")
            } else {
                fileBuilder.appendLine("case \(internalName) = \"\(name)\"")
            }
        }
    }
    
    private func addOperationPathEnum(_ fileBuilder: FileBuilder, _ sortedOperations: [(key: String, value: OperationDescription)]) {
        fileBuilder.appendLine("""
            public var operationPath: String {
                switch self {
            """)
        
        fileBuilder.incIndent()
        // for each of the operations
        for (name, operation) in sortedOperations {
            // convert to lower camel case
            let internalName = name.upperToLowerCamelCase
            
            fileBuilder.appendLine("""
                case .\(internalName):
                    return "\(operation.httpUrl ?? "/")"
                """)
        }
        fileBuilder.decIndent()
        
        fileBuilder.appendLine("""
                }
            """)
    }
}
