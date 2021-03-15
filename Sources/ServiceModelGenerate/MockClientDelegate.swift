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
// MockClientDelegate.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

/**
 A ModelClientDelegate that can be used to generate a
 mock or throwing test client from a Service Model.
 */
public struct MockClientDelegate: ModelClientDelegate {
    public let baseName: String
    public let asyncResultType: AsyncResultType?
    public let isThrowingMock: Bool
    public let clientType: ClientType
    public let typeDescription: String
    
    /**
     Initializer.
 
     - Parameters:
        - baseName: The base name of the Service.
        - isThrowingMock: true to generate a throwing mock; false for a normal mock
        - asyncResultType: The name of the result type to use for async functions.
     */
    public init(baseName: String, isThrowingMock: Bool,
                asyncResultType: AsyncResultType? = nil) {
        self.baseName = baseName
        self.isThrowingMock = isThrowingMock
        self.asyncResultType = asyncResultType
        
        let name: String
        if isThrowingMock {
            name = "Throwing\(baseName)Client"
            self.typeDescription = "Mock Client for the \(baseName) service that by default always throws from its methods."
        } else {
            name = "Mock\(baseName)Client"
            self.typeDescription = "Mock Client for the \(baseName) service by default "
            + "returns the `__default` property of its return type."
        }
        
        self.clientType = .struct(name: name, genericParameters: [],
                                  conformingProtocolNames: ["\(baseName)ClientProtocol"])
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
    
    private func addCommonFunctionsForOperation(name: String, index: Int,
                                                sortedOperations: [(String, OperationDescription)], fileBuilder: FileBuilder) {
        let postfix: String
        if index == sortedOperations.count - 1 {
            postfix = ") {"
        } else {
            postfix = ","
        }
        
        let variableName = name.upperToLowerCamelCase
        fileBuilder.appendLine("\(variableName)EventLoopFutureAsync: \(name.startingWithUppercase)EventLoopFutureAsyncType? = nil\(postfix)")
    }
    
    public func addCommonFunctions(codeGenerator: ServiceModelCodeGenerator,
                                   delegate: ModelClientDelegate,
                                   fileBuilder: FileBuilder,
                                   sortedOperations: [(String, OperationDescription)],
                                   isGenerator: Bool) {
        if isThrowingMock {
            fileBuilder.appendLine("let error: \(baseName)Error")
        }
        
        fileBuilder.appendLine("""
            let eventLoop: EventLoop
            let typedErrorProvider: (Swift.Error) -> \(codeGenerator.applicationDescription.baseName)Error = { $0.asTypedError() }
            """)
        
        // for each of the operations
        for (name, _) in sortedOperations {
            let variableName = name.upperToLowerCamelCase
            fileBuilder.appendLine("let \(variableName)EventLoopFutureAsyncOverride: \(name.startingWithUppercase)EventLoopFutureAsyncType?")
        }
        fileBuilder.appendEmptyLine()
        
        fileBuilder.appendLine("""
            /**
             Initializer that creates an instance of this clients. The behavior of individual
             functions can be overridden by passing them to this initializer.
             */
            """)
        
        if isThrowingMock {
            if !sortedOperations.isEmpty {
                fileBuilder.appendLine("""
                    public init(
                            error: \(baseName)Error,
                            eventLoop: EventLoop,
                    """)
            } else {
                fileBuilder.appendLine("""
                    public init(error: \(baseName)Error,
                                eventLoop: EventLoop) {
                    """)
            }
        } else {
            if !sortedOperations.isEmpty {
                fileBuilder.appendLine("""
                    public init(
                            eventLoop: EventLoop,
                    """)
            } else {
                fileBuilder.appendLine("""
                    public init(eventLoop: EventLoop) {
                    """)
            }
        }
        
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        // for each of the operations
        for (index, entry) in sortedOperations.enumerated() {
            addCommonFunctionsForOperation(name: entry.0, index: index, sortedOperations: sortedOperations, fileBuilder: fileBuilder)
        }
        fileBuilder.decIndent()
        
        if isThrowingMock {
            fileBuilder.appendLine("self.error = error")
        }
        
        fileBuilder.appendLine("""
            self.eventLoop = eventLoop
            
            """)
        
        // for each of the operations
        for (name, _) in sortedOperations {
            let variableName = name.upperToLowerCamelCase
            fileBuilder.appendLine("self.\(variableName)EventLoopFutureAsyncOverride = \(variableName)EventLoopFutureAsync")
        }
        
        fileBuilder.decIndent()
        
        fileBuilder.appendLine("""
                }
                """)
    }
    
    public func addOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                 delegate: ModelClientDelegate,
                                 fileBuilder: FileBuilder,
                                 invokeType: InvokeType,
                                 operationName: String,
                                 operationDescription: OperationDescription,
                                 functionInputType: String?,
                                 functionOutputType: String?,
                                 isGenerator: Bool) {
        let hasInput = functionInputType != nil
        
        if isThrowingMock {
            addThrowingClientOperationBody(codeGenerator: codeGenerator,
                                           fileBuilder: fileBuilder, hasInput: hasInput,
                                           functionOutputType: functionOutputType,
                                           invokeType: invokeType, operationName: operationName)
        } else {
            addMockClientOperationBody(codeGenerator: codeGenerator,
                                       fileBuilder: fileBuilder, hasInput: hasInput,
                                       functionOutputType: functionOutputType,
                                       invokeType: invokeType,
                                       protocolTypeName: protocolTypeName,
                                       operationName: operationName)
        }
    }
    
    private func addMockClientOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                            fileBuilder: FileBuilder, hasInput: Bool,
                                            functionOutputType: String?, invokeType: InvokeType,
                                            protocolTypeName: String, operationName: String) {
        fileBuilder.incIndent()
        
        addAsyncOverrideOperationCall(fileBuilder: fileBuilder, operationName: operationName, hasInput: hasInput)
        
        // return a default instance of the output type
        if let outputType = functionOutputType {
            let typeName = outputType.getNormalizedTypeName(forModel: codeGenerator.model)
            
            fileBuilder.appendLine("""
                let result = \(typeName).__default

                let promise = self.eventLoop.makePromise(of: \(typeName).self)
                promise.succeed(result)

                return promise.futureResult
                """)
        } else {
            fileBuilder.appendLine("""
                let promise = self.eventLoop.makePromise(of: Void.self)
                promise.succeed(())

                return promise.futureResult
                """)
        }
    
        fileBuilder.appendLine("}", preDec: true)
    }
    
    private func addThrowingClientOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                                fileBuilder: FileBuilder, hasInput: Bool, functionOutputType: String?,
                                                invokeType: InvokeType, operationName: String) {
        fileBuilder.incIndent()
        
        addAsyncOverrideOperationCall(fileBuilder: fileBuilder, operationName: operationName, hasInput: hasInput)
        
        if let outputType = functionOutputType {
            let typeName = outputType.getNormalizedTypeName(forModel: codeGenerator.model)
            
            fileBuilder.appendLine("""
                let promise = self.eventLoop.makePromise(of: \(typeName).self)
                promise.fail(error)

                return promise.futureResult
                """)
        } else {
            fileBuilder.appendLine("""
                let promise = self.eventLoop.makePromise(of: Void.self)
                promise.fail(error)

                return promise.futureResult
                """)
        }
    
        fileBuilder.appendLine("}", preDec: true)
    }
    
    private func addAsyncOverrideOperationCall(fileBuilder: FileBuilder,
                                               operationName: String, hasInput: Bool) {
        let variableName = operationName.upperToLowerCamelCase
        
        let customFunctionParameters = hasInput ? "input" : ""
    
        fileBuilder.appendLine("""
                if let \(variableName)EventLoopFutureAsyncOverride = \(variableName)EventLoopFutureAsyncOverride {
                    return \(variableName)EventLoopFutureAsyncOverride(\(customFunctionParameters))
                }
                """)
        fileBuilder.appendEmptyLine()
    }
    
    private var protocolTypeName: String {
        switch clientType {
        case .protocol(name: let name):
            return name
        case .struct(name: _, genericParameters: _, conformingProtocolNames: let conformingProtocolNames):
            return conformingProtocolNames.joined(separator: ", ")
        }
    }
}
