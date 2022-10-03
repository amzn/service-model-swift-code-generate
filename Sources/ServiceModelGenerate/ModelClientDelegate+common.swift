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
// ModelClientDelegate+common.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public typealias SpecificErrorBehaviour = (retriableErrors: [String], unretriableErrors: [String], defaultBehaviorErrorsCount: Int)

public extension ModelClientDelegate where TargetSupportType: ModelTargetSupport {
    func getSpecificErrors(codeGenerator: ServiceModelCodeGenerator<TargetSupportType>, baseName: String) -> SpecificErrorBehaviour {
        let sortedErrors = codeGenerator.getSortedErrors(allErrorTypes: codeGenerator.model.errorTypes)
        
        var retriableErrors: [String] = []
        var unretriableErrors: [String] = []
        var defaultBehaviorErrorsCount: Int = 0
        
        let httpClientConfiguration = codeGenerator.customizations.httpClientConfiguration
        
        sortedErrors.forEach { errorType in
            let errorIdentity = errorType.identity
            let enumName = codeGenerator.getNormalizedEnumCaseName(
                modelTypeName: errorType.normalizedName,
                inStructure: "\(baseName)Error",
                usingUpperCamelCase: true)
            
            if case .fail = httpClientConfiguration.knownErrorsDefaultRetryBehavior,
                httpClientConfiguration.retriableUnknownErrors.contains(errorIdentity) {
                retriableErrors.append( ".\(enumName)")
            } else if case .retry = httpClientConfiguration.knownErrorsDefaultRetryBehavior,
                httpClientConfiguration.unretriableUnknownErrors.contains(errorIdentity) {
                unretriableErrors.append( ".\(enumName)")
            } else {
                defaultBehaviorErrorsCount += 1
            }
        }
        
        return (retriableErrors, unretriableErrors, defaultBehaviorErrorsCount)
    }
}

public extension ModelClientDelegate {
    func addTypedErrorRetriableExtension(codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
                                         fileBuilder: FileBuilder, baseName: String,
                                         specificErrorBehaviour: SpecificErrorBehaviour) {
        let errorType = "\(baseName)Error"
        let httpClientConfiguration = codeGenerator.customizations.httpClientConfiguration
        
        let retriableErrors = specificErrorBehaviour.retriableErrors
        let unretriableErrors = specificErrorBehaviour.unretriableErrors
        let defaultBehaviorErrorsCount = specificErrorBehaviour.defaultBehaviorErrorsCount
        
        fileBuilder.appendLine("""
            
             extension \(errorType): ConvertableError {
                public static func asUnrecognizedError(error: Swift.Error) -> \(errorType) {
                    return error.asUnrecognized\(baseName)Error()
                }
            """)
        
        if !(retriableErrors.isEmpty && unretriableErrors.isEmpty) {
            fileBuilder.appendLine("""
                
                    public func isRetriable() -> Bool? {
                """)
            
            addRetriableSwitchStatement(fileBuilder: fileBuilder, retriableErrors: retriableErrors,
                                        unretriableErrors: unretriableErrors,
                                        defaultBehaviorErrorsCount: defaultBehaviorErrorsCount,
                                        httpClientConfiguration: httpClientConfiguration)
            
            fileBuilder.appendLine("""
                }
            """)
        }
        
        fileBuilder.appendLine("""
        }
        """)
    }
    
    private func addRetriableSwitchStatement(fileBuilder: FileBuilder, retriableErrors: [String],
                                             unretriableErrors: [String], defaultBehaviorErrorsCount: Int,
                                             httpClientConfiguration: HttpClientConfiguration) {
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        fileBuilder.appendLine("""
                switch self {
                """)
        
        if !retriableErrors.isEmpty {
            let joinedCases = retriableErrors.sorted(by: <)
                .joined(separator: ", ")
            
            fileBuilder.appendLine("""
                case \(joinedCases):
                    return true
                """)
        }
        
        if !unretriableErrors.isEmpty {
            let joinedCases = unretriableErrors.sorted(by: <)
                .joined(separator: ", ")
            
            fileBuilder.appendLine("""
                case \(joinedCases):
                    return false
                """)
        }
        
        if defaultBehaviorErrorsCount != 0 {
            fileBuilder.appendLine("""
                default:
                    return nil
                """)
        }
        
        fileBuilder.appendLine("""
                }
                """)
        fileBuilder.decIndent()
        fileBuilder.decIndent()
    }
    
    func addErrorRetriableExtension(codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
                                    fileBuilder: FileBuilder, baseName: String) {
        let errorType = "\(baseName)Error"
                
        fileBuilder.appendLine("""
            
            private extension SmokeHTTPClient.HTTPClientError {
                func isRetriable() -> Bool {
                    if let typedError = self.cause as? \(errorType), let isRetriable = typedError.isRetriable() {
                        return isRetriable
                    } else {
                        return self.isRetriableAccordingToCategory
                    }
                }
            }
            """)
    }
    
    func addClientOperationMetricsParameters(fileBuilder: FileBuilder, baseName: String,
                                             codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
                                             sortedOperations: [(String, OperationDescription)],
                                             entityType: ClientEntityType) {
        guard entityType.isGenerator || entityType.isClientImplementation else {
            // nothing to do
            return
        }
        
        fileBuilder.appendEmptyLine()
        fileBuilder.appendLine("""
            let operationsReporting: \(baseName)OperationsReporting
            """)
        
        if !entityType.isGenerator {
            fileBuilder.appendLine("""
                let invocationsReporting: \(baseName)InvocationsReporting<InvocationReportingType>
                """)
        }
    }
    
    func addOperationsClientConfigInitializer(fileBuilder: FileBuilder,
                                              entityType: ClientEntityType) {
        if case .operationsClient(let configurationObjectName) = entityType {
            fileBuilder.appendLine("""
                
                public init(config: \(configurationObjectName)<InvocationReportingType>,
                            httpClient: HTTPOperationsClient? = nil) {
                    self.config = config
                    self.httpClient = httpClient ?? self.config.createHTTPOperationsClient()
                }
                """)
        }
    }
    
    func addClientInitializerFromConfigWithInvocationAttributes(fileBuilder: FileBuilder,
                                                                configurationObjectName: String) {
        fileBuilder.appendLine("""
            
            public init<TraceContextType: InvocationTraceContext, InvocationAttributesType: HTTPClientInvocationAttributes>(
                config: \(configurationObjectName)<StandardHTTPClientCoreInvocationReporting<TraceContextType>>,
                invocationAttributes: InvocationAttributesType,
                httpClient: HTTPOperationsClient? = nil)
            where InvocationReportingType == StandardHTTPClientCoreInvocationReporting<TraceContextType> {
                self.init(config: config,
                          logger: invocationAttributes.logger,
                          internalRequestId: invocationAttributes.internalRequestId,
                          eventLoop: !config.ignoreInvocationEventLoop ? invocationAttributes.eventLoop : nil,
                          httpClient: httpClient,
                          outwardsRequestAggregator: invocationAttributes.outwardsRequestAggregator)
            }
            """)
    }
    
    func addClientInitializerFromOperationsWithInvocationAttributes(fileBuilder: FileBuilder,
                                                                    operationsClientName: String) {
        fileBuilder.appendLine("""
            
            public init<TraceContextType: InvocationTraceContext, InvocationAttributesType: HTTPClientInvocationAttributes>(
                operationsClient: \(operationsClientName)<StandardHTTPClientCoreInvocationReporting<TraceContextType>>,
                invocationAttributes: InvocationAttributesType)
            where InvocationReportingType == StandardHTTPClientCoreInvocationReporting<TraceContextType> {
                self.init(operationsClient: operationsClient,
                          logger: invocationAttributes.logger,
                          internalRequestId: invocationAttributes.internalRequestId,
                          eventLoop: !operationsClient.config.ignoreInvocationEventLoop ? invocationAttributes.eventLoop : nil,
                          outwardsRequestAggregator: invocationAttributes.outwardsRequestAggregator)
            }
            """)
    }
    
    func addClientGeneratorWithTraceContext(
            fileBuilder: FileBuilder,
            baseName: String,
            codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
            targetsAPIGateway: Bool,
            contentType: String) {
        guard case .struct(let clientName, _, _) = clientType else {
            fatalError()
        }
        
        fileBuilder.appendLine("""
            
            public func with<NewTraceContextType: InvocationTraceContext>(
                    logger: Logging.Logger,
                    internalRequestId: String = "none",
                    traceContext: NewTraceContextType,
                    eventLoop: EventLoop? = nil) -> Generic\(clientName)<StandardHTTPClientCoreInvocationReporting<NewTraceContextType>> {
                let reporting = StandardHTTPClientCoreInvocationReporting(
                    logger: logger,
                    internalRequestId: internalRequestId,
                    traceContext: traceContext,
                    eventLoop: eventLoop)
                
                return with(reporting: reporting)
            }
            """)
    }
    
    func addClientGeneratorWithLogger(
            fileBuilder: FileBuilder,
            baseName: String,
            codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
            targetsAPIGateway: Bool,
            invocationTraceContext: InvocationTraceContextDeclaration,
            contentType: String) {
        guard case .struct(let clientName, _, _) = clientType else {
            fatalError()
        }
        
        fileBuilder.appendLine("""
            
            public func with(
                    logger: Logging.Logger,
                    internalRequestId: String = "none",
                    eventLoop: EventLoop? = nil) -> Generic\(clientName)<StandardHTTPClientCoreInvocationReporting<\(invocationTraceContext.name)>> {
                let reporting = StandardHTTPClientCoreInvocationReporting(
                    logger: logger,
                    internalRequestId: internalRequestId,
                    traceContext: \(invocationTraceContext.name)(),
                    eventLoop: eventLoop)
                
                return with(reporting: reporting)
            }
            """)
    }
    
    func addClientOperationMetricsInitializerBody(fileBuilder: FileBuilder, baseName: String,
                                                  codeGenerator: ServiceModelCodeGenerator<TargetSupportType>,
                                                  sortedOperations: [(String, OperationDescription)],
                                                  entityType: ClientEntityType, initializerType: InitializerType,
                                                  inputPrefix: String) {
        guard entityType.isGenerator || entityType.isClientImplementation else {
            // nothing to do
            return
        }
        
        guard case .struct(let clientName, _, _) = clientType else {
            fatalError()
        }
        
        if !initializerType.isCopyInitializer {
            fileBuilder.appendLine("""
                self.operationsReporting = \(baseName)OperationsReporting(clientName: "\(clientName)", reportingConfiguration: \(inputPrefix)reportingConfiguration)
                """)
        } else {
            fileBuilder.appendLine("""
                self.operationsReporting = operationsReporting
                """)
        }
        
        if !initializerType.isGenerator {
            fileBuilder.appendLine("""
                self.invocationsReporting = \(baseName)InvocationsReporting(reporting: reporting, operationsReporting: self.operationsReporting)
                """)
        }
    }
}
