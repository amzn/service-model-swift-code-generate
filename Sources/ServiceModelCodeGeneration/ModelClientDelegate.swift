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
// ModelClientDelegate.swift
// ServiceModelCodeGeneration
//

import Foundation
import ServiceModelEntities

public enum CodeGenFeatureStatus: String, Codable {
    case disabled = "DISABLED"
    case enabled = "ENABLED"
}

public enum ClientFileType {
    case clientImplementation
    case clientConfiguration
    case clientGenerator
    
    public var isGenerator: Bool {
        if case .clientGenerator = self {
            return true
        }
        
        return false
    }
}

public struct InitializationStructs {
    public let configurationObjectName: String
    public let operationsClientName: String
    
    public init(configurationObjectName: String,
                operationsClientName: String) {
        self.configurationObjectName = configurationObjectName
        self.operationsClientName = operationsClientName
    }
}

public enum ClientEntityType {
    case clientImplementation(initializationStructs: InitializationStructs?)
    case configurationObject
    case operationsClient(configurationObjectName: String)
    case clientGenerator
    
    public var isGenerator: Bool {
        if case .clientGenerator = self {
            return true
        }
        
        return false
    }
    
    public var isClientImplementation: Bool {
        if case .clientImplementation = self {
            return true
        }
        
        return false
    }
}

/**
 Delegate protocol that can customize the generation of a client
 from the Service Model.
 */
public protocol ModelClientDelegate {
    associatedtype ModelType: ServiceModel
    associatedtype TargetSupportType
    
    /// The type of client being generated.
    var clientType: ClientType { get }

    var asyncAwaitAPIs: CodeGenFeatureStatus { get }
    var eventLoopFutureClientAPIs: CodeGenFeatureStatus { get }
    var minimumCompilerSupport: MinimumCompilerSupport { get }
        
    /**
     Add any custom file headers to the client file.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
     */
    func addCustomFileHeader(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                             delegate: Self,
                             fileBuilder: FileBuilder,
                             fileType: ClientFileType)
    
    /**
     Adds the type description to the header comment.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
     */
    func addTypeDescription(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                            delegate: Self,
                            fileBuilder: FileBuilder,
                            entityType: ClientEntityType)
    
    /**
     Add any common functions to the body of the client type.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
        - sortedOperations: A list of sorted operations from the current model.
     */
    func addCommonFunctions(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                            delegate: Self,
                            fileBuilder: FileBuilder,
                            sortedOperations: [(String, OperationDescription)],
                            entityType: ClientEntityType)
    
    /**
     Add the body for an operation to the client type.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
        - invokeType: How the function is being invoked.
        - operationName: the name of the operation.
        - operationDescription: the description of the operation.
        - functionInputType: the input type to the operation.
        - functionOutputType: the output type for the operation.
     */
    func addOperationBody(codeGenerator: ServiceModelCodeGenerator<ModelType, TargetSupportType>,
                          delegate: Self,
                          fileBuilder: FileBuilder,
                          invokeType: InvokeType,
                          operationName: String,
                          operationDescription: OperationDescription,
                          functionInputType: String?,
                          functionOutputType: String?,
                          entityType: ClientEntityType)
}

/// The type of client being generated.
public enum ClientType {
    /// A protocol with the specified name
    case `protocol`(name: String)
    /// A struct with the specified name and conforming to the specified protocol
    case `struct`(name: String, genericParameters: [(typeName: String, conformingTypeName: String?)], conformingProtocolNames: [String])
}

/**
 Specifies the invocation style for a client function being generated.
 */
public enum InvokeType: String {
    case asyncFunction = "Function"
    case eventLoopFutureAsync = "EventLoopFutureAsync"
}

public extension ModelClientDelegate {
    var eventLoopFutureClientAPIs: CodeGenFeatureStatus {
        return .enabled
    }
    
    var minimumCompilerSupport: MinimumCompilerSupport {
        return .unknown
    }
    
    func getHttpClientForOperation(name: String, httpClientConfiguration: HttpClientConfiguration?) -> String {
        if let additionalClients = httpClientConfiguration?.additionalClients {
            for (key, value) in additionalClients {
                if value.operations?.contains(name) ?? false {
                    return key
                }
            }
        }
        
        return "httpClient"
    }
}
