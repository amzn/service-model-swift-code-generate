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
// ServiceModelCodeGenerator+generateOperationsReporting.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public struct OperationsReportingType {
    public let typeName: String
    public let targetImportName: String?
    public let initializeFromConfiguration: (_ variableName: String, _ prefix: String, _ fileBuilder: FileBuilder) -> ()
    
    public init(typeName: String, targetImportName: String?,
                initializeFromConfiguration: @escaping (_ variableName: String, _ prefix: String, _ fileBuilder: FileBuilder) -> Void) {
        self.typeName = typeName
        self.targetImportName = targetImportName
        self.initializeFromConfiguration = initializeFromConfiguration
    }
}

public extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport & ClientTargetSupport {
    /**
     Generate an operation enumeration for the model.
     
     - Parameters:
        - operationsReportingType: The type to use for operations reporting.
     */
    func generateOperationsReporting(operationsReportingType: OperationsReportingType) {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        let modelTargetName = self.targetSupport.modelTargetName
        let clientTargetName = self.targetSupport.clientTargetName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)OperationsReporting.swift
            // \(clientTargetName)
            //
            
            import Foundation
            import SmokeHTTPClient
            """)
        
        if let operationsReportingTypeTargetName = operationsReportingType.targetImportName {
            fileBuilder.appendLine("import \(operationsReportingTypeTargetName)")
        }
        
        fileBuilder.appendLine("""
            import \(modelTargetName)
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        fileBuilder.appendLine("""
            
            /**
             Operation reporting for the \(modelTargetName).
             */
            public struct \(baseName)OperationsReporting {
            """)
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        fileBuilder.incIndent()
        addOperationReportingParameters(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations,
                                        operationsReportingType: operationsReportingType)
        
        fileBuilder.appendEmptyLine()
        addOperationReportingInitializer(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations,
                                         operationsReportingType: operationsReportingType)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("}")
        
        let fileName = "\(baseName)OperationsReporting.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(clientTargetName)")
    }
    
    private func addOperationReportingParameters(fileBuilder: FileBuilder, baseName: String,
                                                 sortedOperations: [(String, OperationDescription)],
                                                 operationsReportingType: OperationsReportingType) {
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
            
            fileBuilder.appendLine("""
                public let \(variableName): \(operationsReportingType.typeName)<\(baseName)ModelOperations>
                """)
        }
    }
    
    private func addOperationReportingInitializer(fileBuilder: FileBuilder, baseName: String,
                                                  sortedOperations: [(String, OperationDescription)],
                                                  operationsReportingType: OperationsReportingType) {
        fileBuilder.appendLine("public init(clientName: String, reportingConfiguration: HTTPClientReportingConfiguration<\(baseName)ModelOperations>) {",
                               postInc: true)
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
            
            operationsReportingType.initializeFromConfiguration(variableName, "self.\(variableName) = ", fileBuilder)
        }
        
        fileBuilder.appendLine("}", preDec: true)
    }
}
