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
// ModelClientDelegate.swift
// ServiceModelCodeGeneration
//

import Foundation
import ServiceModelEntities

/**
 Delegate protocol that can customize the generation of a client
 from the Service Model.
 */
public protocol ModelClientDelegate {
    /// The type of client being generated.
    var clientType: ClientType { get }
    /// The result type to use for asynchronous functions.
    var asyncResultType: AsyncResultType? { get }
    
    func getFileDescription(isGenerator: Bool) -> String
    
    /**
     Add any custom file headers to the client file.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
     */
    func addCustomFileHeader(codeGenerator: ServiceModelCodeGenerator,
                             delegate: ModelClientDelegate,
                             fileBuilder: FileBuilder,
                             isGenerator: Bool)
    
    /**
     Add any common functions to the body of the client type.
 
     - Parameters:
        - codeGenerator: The code generator being used.
        - delegate: the delegate being used.
        - fileBuilder: The FileBuilder to output to.
        - sortedOperations: A list of sorted operations from the current model.
     */
    func addCommonFunctions(codeGenerator: ServiceModelCodeGenerator,
                            delegate: ModelClientDelegate,
                            fileBuilder: FileBuilder,
                            sortedOperations: [(String, OperationDescription)],
                            isGenerator: Bool)
    
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
    func addOperationBody(codeGenerator: ServiceModelCodeGenerator,
                          delegate: ModelClientDelegate,
                          fileBuilder: FileBuilder,
                          invokeType: InvokeType,
                          operationName: String,
                          operationDescription: OperationDescription,
                          functionInputType: String?,
                          functionOutputType: String?,
                          isGenerator: Bool)
}

/// The type of client being generated.
public enum ClientType {
    /// A protocol with the specified name
    case `protocol`(name: String)
    /// A struct with the specified name and conforming to the specified protocol
    case `struct`(name: String, genericParameters: [(typeName: String, conformingTypeName: String?)], conformingProtocolName: String)
}

/**
 The result type to use for asynchronous functions.
 */
public struct AsyncResultType {
    /// The name of this type.
    public let typeName: String
    /// The library import for this type.
    public let libraryImport: String
    
    public init(typeName: String, libraryImport: String) {
        self.typeName = typeName
        self.libraryImport = libraryImport
    }
}

/**
 Specifies the invocation style for a client function being generated.
 */
public enum InvokeType: String {
    case sync = "Sync"
    case async = "Async"
}

public extension ModelClientDelegate {
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
