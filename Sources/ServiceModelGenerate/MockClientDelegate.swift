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
    public let isThrowingMock: Bool
    public let clientType: ClientType
    public let typeDescription: String
    public let asyncAwaitGeneration: AsyncAwaitGeneration
    
    /**
     Initializer.
 
     - Parameters:
        - baseName: The base name of the Service.
        - isThrowingMock: true to generate a throwing mock; false for a normal mock
        - asyncResultType: The name of the result type to use for async functions.
     */
    public init(baseName: String, isThrowingMock: Bool,
                asyncAwaitGeneration: AsyncAwaitGeneration) {
        self.baseName = baseName
        self.isThrowingMock = isThrowingMock
        self.asyncAwaitGeneration = asyncAwaitGeneration
        
        let name: String
        let additionalConformingProtocol: String
        if isThrowingMock {
            name = "Throwing\(baseName)Client"
            additionalConformingProtocol = "MockThrowingClientProtocol"
            self.typeDescription = "Mock Client for the \(baseName) service that by default always throws from its methods."
        } else {
            name = "Mock\(baseName)Client"
            additionalConformingProtocol = "MockClientProtocol"
            self.typeDescription = "Mock Client for the \(baseName) service by default "
            + "returns the `__default` property of its return type."
        }
        
        self.clientType = .struct(name: name, genericParameters: [],
                                  conformingProtocolNames: ["\(baseName)ClientProtocol", additionalConformingProtocol])
    }
    
    public func getFileDescription(isGenerator: Bool) -> String {
        return self.typeDescription
    }
    
    public func addCustomFileHeader(codeGenerator: ServiceModelCodeGenerator,
                                    delegate: ModelClientDelegate,
                                    fileBuilder: FileBuilder,
                                    isGenerator: Bool) {
        fileBuilder.appendLine("""
            import SmokeAWSHttp
            """)
        
        if case .experimental = self.asyncAwaitGeneration {
            fileBuilder.appendLine("""
                
                #if compiler(>=5.5)
                import _SmokeAWSHttpConcurrency
                #endif
                """)
        }
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
        fileBuilder.appendLine("\(variableName)EventLoopFutureAsync: \(name.startingWithUppercase)EventLoopFutureAsyncType? = nil,")
        fileBuilder.appendLine("\(variableName): \(name.startingWithUppercase)FunctionType? = nil\(postfix)")
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
            fileBuilder.appendLine("let \(variableName)FunctionOverride: \(name.startingWithUppercase)FunctionType?")
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
            fileBuilder.appendLine("self.\(variableName)FunctionOverride = \(variableName)")
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
    
    private func delegateMockImplementationCall(codeGenerator: ServiceModelCodeGenerator,
                                                functionPrefix: String, functionInfix: String,
                                                fileBuilder: FileBuilder, hasInput: Bool,
                                                functionOutputType: String?, operationName: String) {
        let variableName = operationName.upperToLowerCamelCase
        
        if let outputType = functionOutputType {
            let typeName = outputType.getNormalizedTypeName(forModel: codeGenerator.model)
            
            if hasInput {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mock\(functionInfix)ExecuteWithInputWithOutput(
                        input: input,
                        defaultResult: \(typeName).__default,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            } else {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mock\(functionInfix)ExecuteWithoutInputWithOutput(
                        defaultResult: \(typeName).__default,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            }
        } else {
            if hasInput {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mock\(functionInfix)ExecuteWithInputWithoutOutput(
                        input: input,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            } else {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mock\(functionInfix)ExecuteWithoutInputWithoutOutput(
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            }
        }
    }
    
    private func addMockClientOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                            fileBuilder: FileBuilder, hasInput: Bool,
                                            functionOutputType: String?, invokeType: InvokeType,
                                            protocolTypeName: String, operationName: String) {
        let functionPrefix: String
        let functionInfix: String
        switch invokeType {
        case .asyncFunction:
            functionPrefix = "try await "
            functionInfix = ""
        case .eventLoopFutureAsync:
            functionPrefix = ""
            functionInfix = "EventLoopFuture"
        }
        
        fileBuilder.incIndent()
        
        if case .experimental = self.asyncAwaitGeneration, invokeType == .eventLoopFutureAsync {
            fileBuilder.appendLine("#if compiler(>=5.5)", postInc: true)
            fileBuilder.appendLine("if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {", postInc: true)
            
            delegateMockImplementationCall(codeGenerator: codeGenerator,
                                           functionPrefix: functionPrefix,
                                           functionInfix: "AsyncAwareEventLoopFuture",
                                           fileBuilder: fileBuilder,
                                           hasInput: hasInput,
                                           functionOutputType: functionOutputType,
                                           operationName: operationName)
            fileBuilder.appendLine("} else {", preDec: true, postInc: true)
            fileBuilder.appendLine("fatalError( \"Swift >=5.5 unsupported below (macOS 12, iOS 15, tvOS 15, watchOS 8)\")")
            fileBuilder.appendLine("}", preDec: true)
            fileBuilder.appendLine("#else", preDec: true, postInc: true)
            
            delegateMockImplementationCall(codeGenerator: codeGenerator,
                                           functionPrefix: functionPrefix,
                                           functionInfix: functionInfix,
                                           fileBuilder: fileBuilder,
                                           hasInput: hasInput,
                                           functionOutputType: functionOutputType,
                                           operationName: operationName)
            
            fileBuilder.appendLine("#endif", preDec: true)
        } else {
            delegateMockImplementationCall(codeGenerator: codeGenerator,
                                           functionPrefix: functionPrefix,
                                           functionInfix: functionInfix,
                                           fileBuilder: fileBuilder,
                                           hasInput: hasInput,
                                           functionOutputType: functionOutputType,
                                           operationName: operationName)
        }
    
        fileBuilder.appendLine("}", preDec: true)
    }
    
    private func delegateMockThrowingImplementationCall(codeGenerator: ServiceModelCodeGenerator,
                                                        functionPrefix: String, functionInfix: String,
                                                        fileBuilder: FileBuilder, hasInput: Bool,
                                                        functionOutputType: String?, operationName: String) {
        let variableName = operationName.upperToLowerCamelCase
        
        if functionOutputType != nil {
            if hasInput {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mockThrowing\(functionInfix)ExecuteWithInputWithOutput(
                        input: input,
                        defaultError: self.error,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            } else {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mockThrowing\(functionInfix)ExecuteWithoutInputWithOutput(
                        defaultError: self.error,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            }
        } else {
            if hasInput {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mockThrowing\(functionInfix)ExecuteWithInputWithoutOutput(
                        input: input,
                        defaultError: self.error,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            } else {
                fileBuilder.appendLine("""
                    return \(functionPrefix)mockThrowing\(functionInfix)ExecuteWithoutInputWithoutOutput(
                        defaultError: self.error,
                        eventLoop: self.eventLoop,
                        functionOverride: self.\(variableName)FunctionOverride,
                        eventLoopFutureFunctionOverride: self.\(variableName)EventLoopFutureAsyncOverride)
                    """)
            }
        }
    }
    
    private func addThrowingClientOperationBody(codeGenerator: ServiceModelCodeGenerator,
                                                fileBuilder: FileBuilder, hasInput: Bool, functionOutputType: String?,
                                                invokeType: InvokeType, operationName: String) {
        let functionPrefix: String
        let functionInfix: String
        switch invokeType {
        case .asyncFunction:
            functionPrefix = "try await "
            functionInfix = ""
        case .eventLoopFutureAsync:
            functionPrefix = ""
            functionInfix = "EventLoopFuture"
        }
        
        fileBuilder.incIndent()
        
        if case .experimental = self.asyncAwaitGeneration, invokeType == .eventLoopFutureAsync {
            fileBuilder.appendLine("#if compiler(>=5.5)", postInc: true)
            fileBuilder.appendLine("if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {", postInc: true)
            
            delegateMockThrowingImplementationCall(codeGenerator: codeGenerator,
                                                   functionPrefix: functionPrefix,
                                                   functionInfix: "AsyncAwareEventLoopFuture",
                                                   fileBuilder: fileBuilder,
                                                   hasInput: hasInput,
                                                   functionOutputType: functionOutputType,
                                                   operationName: operationName)
            fileBuilder.appendLine("} else {", preDec: true, postInc: true)
            fileBuilder.appendLine("fatalError( \"Swift >=5.5 unsupported below (macOS 12, iOS 15, tvOS 15, watchOS 8)\")")
            fileBuilder.appendLine("}", preDec: true)
            fileBuilder.appendLine("#else", preDec: true, postInc: true)
            
            delegateMockThrowingImplementationCall(codeGenerator: codeGenerator,
                                                   functionPrefix: functionPrefix,
                                                   functionInfix: functionInfix,
                                                   fileBuilder: fileBuilder,
                                                   hasInput: hasInput,
                                                   functionOutputType: functionOutputType,
                                                   operationName: operationName)
            
            fileBuilder.appendLine("#endif", preDec: true)
        } else {
            delegateMockThrowingImplementationCall(codeGenerator: codeGenerator,
                                                   functionPrefix: functionPrefix,
                                                   functionInfix: functionInfix,
                                                   fileBuilder: fileBuilder,
                                                   hasInput: hasInput,
                                                   functionOutputType: functionOutputType,
                                                   operationName: operationName)
        }
    
        fileBuilder.appendLine("}", preDec: true)
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
