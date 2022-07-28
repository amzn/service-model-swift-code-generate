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
// CodeGenerationCustomizations.swift
// ServiceModelCodeGeneration
//

import Foundation
import ServiceModelEntities

public enum MinimumCompilerSupport: String, Codable {
    case unknown = "UNKNOWN"
    case v5_6 = "5.6"
    case v5_7 = "5.7"
}

/**
 Specifies customizations to the code generation.
 */
public struct CodeGenerationCustomizations {
    /// How validation errors are declared or used.
    public let validationErrorDeclaration: ErrorDeclaration
    /// How unrecognized errors are declared or used.
    public let unrecognizedErrorDeclaration: ErrorDeclaration
    /// If shape protocols for easy conversion between
    /// model types should be generated.
    public let generateModelShapeConversions: Bool
    /// If optional member variables on model types are initialized empty by default.
    public let optionalsInitializeEmpty: Bool
    /// Header for all generated files
    public let fileHeader: String?
    /// Custom configuration for http clients
    public let httpClientConfiguration: HttpClientConfiguration
    /// If async/await APIs should be included
    public let asyncAwaitAPIs: CodeGenFeatureStatus
    public let addSendableConformance: CodeGenFeatureStatus
    public let eventLoopFutureClientAPIs: CodeGenFeatureStatus
    public let minimumCompilerSupport: MinimumCompilerSupport
    
    public init(validationErrorDeclaration: ErrorDeclaration,
                unrecognizedErrorDeclaration: ErrorDeclaration,
                asyncAwaitAPIs: CodeGenFeatureStatus,
                eventLoopFutureClientAPIs: CodeGenFeatureStatus = .enabled,
                addSendableConformance: CodeGenFeatureStatus = .disabled,
                minimumCompilerSupport: MinimumCompilerSupport = .unknown,
                generateModelShapeConversions: Bool,
                optionalsInitializeEmpty: Bool,
                fileHeader: String?,
                httpClientConfiguration: HttpClientConfiguration) {
        self.validationErrorDeclaration = validationErrorDeclaration
        self.unrecognizedErrorDeclaration = unrecognizedErrorDeclaration
        self.generateModelShapeConversions = generateModelShapeConversions
        self.eventLoopFutureClientAPIs = eventLoopFutureClientAPIs
        self.addSendableConformance = addSendableConformance
        self.minimumCompilerSupport = minimumCompilerSupport
        self.optionalsInitializeEmpty = optionalsInitializeEmpty
        self.fileHeader = fileHeader
        self.httpClientConfiguration = httpClientConfiguration
        self.asyncAwaitAPIs = asyncAwaitAPIs
    }
}

/**
 Enumeration specifying how a particular type of error is declared or used.
 */
public enum ErrorDeclaration {
    /// error of this type are specified externally with the specified
    /// library import and error type
    case external(libraryImport: String, errorType: String)
    /// error of this type should be generated as part of the model errors
    /// code generation
    case `internal`
}
