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
// ServiceModelCodeGenerator+generateInvocationsReporting.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public struct InvocationReportingType {
    public let typeName: String
    public let targetImportName: String?
    public let initializeFromOperationsReporting: (_ variableName: String, _ prefix: String, _ fileBuilder: FileBuilder) -> ()
    
    public init(typeName: String, targetImportName: String?,
                initializeFromOperationsReporting: @escaping (_ variableName: String, _ prefix: String, _ fileBuilder: FileBuilder) -> Void) {
        self.typeName = typeName
        self.targetImportName = targetImportName
        self.initializeFromOperationsReporting = initializeFromOperationsReporting
    }
}

public extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport & ClientTargetSupport {
    /**
     Generate an operation enumeration for the model.
     
     - Parameters:
        - invocationReportingType: The type to use for invocation reporting.
     */
    func generateInvocationsReporting(invocationReportingType: InvocationReportingType) {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        let modelTargetName = self.targetSupport.modelTargetName
        let clientTargetName = self.targetSupport.clientTargetName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)InvocationsReporting.swift
            // \(clientTargetName)
            //
            
            import Foundation
            import SmokeHTTPClient
            """)
        
        if let invocationReportingTypeTargetName = invocationReportingType.targetImportName {
            fileBuilder.appendLine("import \(invocationReportingTypeTargetName)")
        }
        
        fileBuilder.appendLine("""
            import \(modelTargetName)
            """)
        
        if case let .external(libraryImport: libraryImport, _) = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        var reportingTypeConformance = ["HTTPClientCoreInvocationReporting"]
        if case .enabled = self.customizations.addSendableConformance {
            reportingTypeConformance.append("Sendable")
        }
        
        let reportingTypeConformanceString = reportingTypeConformance.joined(separator: " & ")
        fileBuilder.appendLine("""
            
            /**
             Invocations reporting for the \(modelTargetName).
             */
            public struct \(baseName)InvocationsReporting<InvocationReportingType: \(reportingTypeConformanceString)> {
            """)
        
        let sortedOperations = model.operationDescriptions.sorted { (left, right) in left.key < right.key }
        
        fileBuilder.incIndent()
        addOperationReportingParameters(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations,
                                        invocationReportingType: invocationReportingType)
        
        fileBuilder.appendEmptyLine()
        addOperationReportingInitializer(fileBuilder: fileBuilder, baseName: baseName, sortedOperations: sortedOperations,
                                         invocationReportingType: invocationReportingType)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("}")
        
        let fileName = "\(baseName)InvocationsReporting.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(clientTargetName)")
    }
    
    private func addOperationReportingParameters(fileBuilder: FileBuilder, baseName: String,
                                                 sortedOperations: [(String, OperationDescription)],
                                                 invocationReportingType: InvocationReportingType) {
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
            
            fileBuilder.appendLine("""
                public let \(variableName): \(invocationReportingType.typeName)<InvocationReportingType>
                """)
        }
    }
    
    private func addOperationReportingInitializer(fileBuilder: FileBuilder, baseName: String,
                                                  sortedOperations: [(String, OperationDescription)],
                                                  invocationReportingType: InvocationReportingType) {
        fileBuilder.appendLine("""
            public init(reporting: InvocationReportingType, operationsReporting: \(baseName)OperationsReporting) {
            """)
        fileBuilder.incIndent()
        sortedOperations.forEach { (name, operation) in
            let variableName = getNormalizedVariableName(modelTypeName: name)
            
            invocationReportingType.initializeFromOperationsReporting(variableName, "self.\(variableName) = ", fileBuilder)
        }
        
        fileBuilder.appendLine("}", preDec: true)
    }
}
