// Copyright 2019-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// ServiceModelCodeGenerator+generateOperationsReporting.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    /**
     Generate an operation enumeration for the model.
     */
    func generateOperationsReporting() {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)OperationsReporting.swift
            // \(baseName)Client
            //
            
            import Foundation
            import SmokeAWSCore
            import \(baseName)Model
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        fileBuilder.appendLine("""
            
            /**
             Operation reporting for the \(baseName)Model.
             */
            public struct \(baseName)OperationsReporting {
            """)
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        fileBuilder.incIndent()
        addOperationReportingParameters(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations)
        
        fileBuilder.appendEmptyLine()
        addOperationReportingInitializer(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("}")
        
        let fileName = "\(baseName)OperationsReporting.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(baseName)Client")
    }
    
    private func addOperationReportingParameters(fileBuilder: FileBuilder, baseName: String,
                                               sortedOperations: [(String, OperationDescription)]) {
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
            
            fileBuilder.appendLine("""
                public let \(variableName): StandardSmokeAWSOperationReporting<\(baseName)ModelOperations>
                """)
        }
    }
    
    private func addOperationReportingInitializer(fileBuilder: FileBuilder, baseName: String,
                                                  sortedOperations: [(String, OperationDescription)]) {
        fileBuilder.appendLine("public init(clientName: String, reportingConfiguration: SmokeAWSClientReportingConfiguration<\(baseName)ModelOperations>) {",
                               postInc: true)
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
                        
            fileBuilder.appendLine("""
                self.\(variableName) = StandardSmokeAWSOperationReporting(
                    clientName: clientName, operation: .\(variableName), configuration: reportingConfiguration)
                """)
        }
        
        fileBuilder.appendLine("}", preDec: true)
    }
}
