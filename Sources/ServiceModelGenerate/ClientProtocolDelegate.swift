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
public struct ClientProtocolDelegate: ModelClientDelegate {
    public let clientType: ClientType
    public let baseName: String
    public let typeDescription: String
    public let asyncAwaitGeneration: AsyncAwaitGeneration
    
    /**
     Initializer.
 
     - Parameters:
        - baseName: The base name of the Service.
        - asyncResultType: The name of the result type to use for async functions.
     */
    public init(baseName: String, asyncAwaitGeneration: AsyncAwaitGeneration) {
        self.baseName = baseName
        self.clientType = .protocol(name: "\(baseName)ClientProtocol")
        self.typeDescription = "Client Protocol for the \(baseName) service."
        self.asyncAwaitGeneration = asyncAwaitGeneration
    }
    
    public func getFileDescription(isGenerator: Bool) -> String {
        return self.typeDescription
    }
    
    public func addCustomFileHeader(codeGenerator: ServiceModelCodeGenerator,
                                    delegate: ModelClientDelegate,
                                    fileBuilder: FileBuilder,
                                    isGenerator: Bool) {
        // no custom file header
    }
    
    public func addCommonFunctions(codeGenerator: ServiceModelCodeGenerator,
                                   delegate: ModelClientDelegate,
                                   fileBuilder: FileBuilder,
                                   sortedOperations: [(String, OperationDescription)],
                                   isGenerator: Bool) {
        // for each of the operations
        for (name, operationDescription) in sortedOperations {
            codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                       operationDescription: operationDescription,
                                       delegate: delegate, invokeType: .eventLoopFutureAsync,
                                       forTypeAlias: true, isGenerator: isGenerator)
        }
        
        // for each of the operations
        if case .experimental = self.asyncAwaitGeneration {
            for (index, operation) in sortedOperations.enumerated() {
                let (name, operationDescription) = operation
                
                codeGenerator.addOperation(fileBuilder: fileBuilder, name: name,
                                           operationDescription: operationDescription,
                                           delegate: delegate, invokeType: .asyncFunction,
                                           forTypeAlias: true, isGenerator: isGenerator,
                                           prefixLine: (index == 0) ? "#if compiler(>=5.5) && $AsyncAwait" : nil,
                                           postfixLine: (index == sortedOperations.count - 1) ? "#endif" : nil)
            }
        }
    }
    
    public func addOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                 delegate: ModelClientDelegate,
                                 fileBuilder: FileBuilder, invokeType: InvokeType,
                                 operationName: String,
                                 operationDescription: OperationDescription,
                                 functionInputType: String?,
                                 functionOutputType: String?,
                                 isGenerator: Bool) {
        // nothing to do
    }
}
