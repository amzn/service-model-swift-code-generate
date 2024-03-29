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
// ClientProtocolDelegate.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

/**
 A ModelClientDelegate that can be used to generate a
 Client protocol from a Service Model.
 */
public struct ClientProtocolDelegate<ModelType: ServiceModel, TargetSupportType>: ModelClientDelegate
where TargetSupportType: ModelTargetSupport & ClientTargetSupport {
    public let clientType: ClientType
    public let baseName: String
    public let typeDescription: String
    public let asyncAwaitAPIs: CodeGenFeatureStatus
    public let eventLoopFutureClientAPIs: CodeGenFeatureStatus
    public let minimumCompilerSupport: MinimumCompilerSupport
    
    /**
     Initializer.
 
     - Parameters:
        - baseName: The base name of the Service.
        - asyncResultType: The name of the result type to use for async functions.
     */
    public init(baseName: String, asyncAwaitAPIs: CodeGenFeatureStatus,
                eventLoopFutureClientAPIs: CodeGenFeatureStatus = .enabled,
                minimumCompilerSupport: MinimumCompilerSupport = .unknown) {
        self.baseName = baseName
        self.clientType = .protocol(name: "\(baseName)ClientProtocol")
        self.typeDescription = "Client Protocol for the \(baseName) service."
        self.asyncAwaitAPIs = asyncAwaitAPIs
        self.eventLoopFutureClientAPIs = eventLoopFutureClientAPIs
        self.minimumCompilerSupport = minimumCompilerSupport
    }
    
    public func addTypeDescription(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                                   delegate: Self,
                                   fileBuilder: FileBuilder,
                                   entityType: ClientEntityType) {
        fileBuilder.appendLine(self.typeDescription)
    }
    
    public func addCustomFileHeader(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                                    delegate: Self,
                                    fileBuilder: FileBuilder,
                                    fileType: ClientFileType) {
        // no custom file header
    }
    
    public func addCommonFunctions(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                                   delegate: Self,
                                   fileBuilder: FileBuilder,
                                   sortedOperations: [(String, OperationDescription)],
                                   entityType: ClientEntityType) {
        if case .enabled = self.eventLoopFutureClientAPIs {
            // for each of the operations
            for (name, operationDescription) in sortedOperations {
                codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                           operationDescription: operationDescription,
                                           delegate: delegate, operationInvokeType: .eventLoopFutureAsync,
                                           forTypeAlias: true, entityType: entityType)
            }
        }
        
        let requiresAsyncAwaitCondition: Bool
        if case .unknown = minimumCompilerSupport {
            requiresAsyncAwaitCondition = true
        } else {
            requiresAsyncAwaitCondition = false
        }
        
        // if there is async/await support
        if case .enabled = self.asyncAwaitAPIs {
            // add async typealiases for Swift 5.5 and greater
            for (index, operation) in sortedOperations.enumerated() {
                let (name, operationDescription) = operation
                
                codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                           operationDescription: operationDescription,
                                           delegate: delegate, operationInvokeType: .asyncFunction,
                                           forTypeAlias: true, entityType: entityType,
                                           prefixLine: (index == 0 && requiresAsyncAwaitCondition) ? asyncAwaitCondition : nil,
                                           postfixLine: (index == sortedOperations.count - 1 && requiresAsyncAwaitCondition) ? "#else" : nil)
            }
            
            if requiresAsyncAwaitCondition {
                // add sync typealiases for Swift 5.5 and greater
                for (index, operation) in sortedOperations.enumerated() {
                    let (name, operationDescription) = operation
                    
                    codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                               operationDescription: operationDescription,
                                               delegate: delegate, operationInvokeType: .syncFunctionForNoAsyncAwaitSupport,
                                               forTypeAlias: true, entityType: entityType,
                                               postfixLine: (index == sortedOperations.count - 1) ? "#endif" : nil)
                }
            }
        // otherwise just add sync typealiases
        } else {
            for operation in sortedOperations {
                let (name, operationDescription) = operation
                
                codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                           operationDescription: operationDescription,
                                           delegate: delegate, operationInvokeType: .syncFunctionForNoAsyncAwaitSupport,
                                           forTypeAlias: true, entityType: entityType)
            }
        }
    }
    
    public func addOperationBody(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                                 delegate: Self,
                                 fileBuilder: FileBuilder, invokeType: InvokeType,
                                 operationName: String,
                                 operationDescription: OperationDescription,
                                 functionInputType: String?,
                                 functionOutputType: String?,
                                 entityType: ClientEntityType) {
        // nothing to do
    }
}
