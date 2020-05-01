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
// ModelOverride.swift
// ServiceModelEntities
//

import Foundation

/// Data model for the ModelOverride input file
public struct ModelOverride: Codable {
    /// attributes of these types should match the original case.
    public let matchCase: Set<String>?
    /// attributes of these types should match the original case.
    public let enumerations: EnumerationNaming?
    /// overrides the default types used for fields.
    public let fieldRawTypeOverride: [String: RawTypeOverride]?
    /// overrides the default value used for fields of a specified name.
    public let namedFieldValuesOverride: [String: String]?
    /// overrides the operation output description for an operation
    public let operationInputOverrides: [String: OperationInputDescription]?
    /// overrides the operation output description for an operation
    public let operationOutputOverrides: [String: OperationOutputDescription]?
    /// if the patterns for string validation should be treated as a pipe-separated
    /// list of alternatives of the form "^{option_1}|{option_2}|{option_3}$"
    public let modelStringPatternsAreAlternativeList: Bool?
    /// structure attributes whose Swift Codable's Coding Key should be overridden from the model
    /// Can be specified as "*.{attributeName}" or "{type}.{attributeName}"
    public let codingKeyOverrides: [String: String]?
    /// structure attributes whose optionality should be overridden from the model
    /// Can be specified as "*.{attributeName}" or "{type}.{attributeName}"
    public let requiredOverrides: [String: Bool]?
    /// any additional error codes that can be returned
    public let additionalErrors: Set<String>?
    /// operations that should be ignored.
    public let ignoreOperations: Set<String>?
    /// response headers that should be ignored.
    public let ignoreResponseHeaders: Set<String>?
    /// request headers that should be ignored.
    public let ignoreRequestHeaders: Set<String>?
    /// overrides the default value used for an enumeration
    public let defaultEnumerationValueOverride: [String: String]?
    
    public init(matchCase: Set<String>? = nil,
                enumerations: EnumerationNaming? = nil,
                fieldRawTypeOverride: [String: RawTypeOverride]? = nil,
                namedFieldOverride: [String: String]? = nil,
                operationInputOverrides: [String: OperationInputDescription]? = nil,
                operationOutputOverrides: [String: OperationOutputDescription]? = nil,
                modelStringPatternsAreAlternativeList: Bool = false,
                codingKeyOverrides: [String: String]? = nil,
                requiredOverrides: [String: Bool]? = nil,
                additionalErrors: Set<String>? = nil,
                ignoreOperations: Set<String>? = nil,
                ignoreResponseHeaders: Set<String>? = nil,
                ignoreRequestHeaders: Set<String>? = nil,
                defaultEnumerationValueOverride: [String: String]? = nil) {
        self.matchCase = matchCase
        self.enumerations = enumerations
        self.fieldRawTypeOverride = fieldRawTypeOverride
        self.namedFieldValuesOverride = namedFieldOverride
        self.operationInputOverrides = operationInputOverrides
        self.operationOutputOverrides = operationOutputOverrides
        self.modelStringPatternsAreAlternativeList = modelStringPatternsAreAlternativeList
        self.codingKeyOverrides = codingKeyOverrides
        self.requiredOverrides = requiredOverrides
        self.additionalErrors = additionalErrors
        self.ignoreOperations = ignoreOperations
        self.ignoreResponseHeaders = ignoreResponseHeaders
        self.ignoreRequestHeaders = ignoreRequestHeaders
        self.defaultEnumerationValueOverride = defaultEnumerationValueOverride
    }
    
    public func getCodingKeyOverride(attributeName: String, inType: String?) -> String? {
        if let codingKeyOverride = codingKeyOverrides?["*.\(attributeName)"] {
            return codingKeyOverride
        } else if let inType = inType,
            let codingKeyOverride = codingKeyOverrides?["\(inType).\(attributeName)"] {
                return codingKeyOverride
        }
        
        return nil
    }
    
    public func getIsRequiredOverride(attributeName: String, inType: String?) -> Bool? {
        if let requiredOverride = requiredOverrides?["*.\(attributeName)"] {
            return requiredOverride
        } else if let inType = inType,
            let requiredOverride = requiredOverrides?["\(inType).\(attributeName)"] {
                return requiredOverride
        }
        
        return nil
    }
}

public struct EnumerationNaming: Codable {
    /// By default, the generator expects enumeration cases to be specifed in upper snake case,
    /// This property indicates the cases of these enumerations have been specified in upper camel case
    public let usingUpperCamelCase: Set<String>?
    
    public init(usingUpperCamelCase: Set<String>?) {
        self.usingUpperCamelCase = usingUpperCamelCase
    }
}

/**
 Allows to type from the model definition to be overridden by a custom type.
 */
public struct RawTypeOverride: Codable {
    /// The custom type name to use as an override.
    public let typeName: String
    /// The custom default value to use for this type.
    public let defaultValue: String
    
    public init(typeName: String, defaultValue: String) {
        self.typeName = typeName
        self.defaultValue = defaultValue
    }
}

public struct AdditionalHttpClient: Decodable {
    public let clientDelegateNameOverride: String?
    public let clientDelegateParameters: [String]?
    public let operations: Set<String>?
    
    public init(clientDelegateNameOverride: String? = nil,
                clientDelegateParameters: [String]? = nil,
                operations: Set<String>? = nil) {
        self.clientDelegateNameOverride = clientDelegateNameOverride
        self.clientDelegateParameters = clientDelegateParameters
        self.operations = operations
    }
}

public enum KnownErrorsDefaultRetryBehavior: String, Decodable {
    case retry
    case fail
}

public struct HttpClientConfiguration: Decodable {
    public let retryOnUnknownError: Bool
    public let knownErrorsDefaultRetryBehavior: KnownErrorsDefaultRetryBehavior
    public let unretriableUnknownErrors: Set<String>
    public let retriableUnknownErrors: Set<String>
    public let clientDelegateNameOverride: String?
    public let clientDelegateParameters: [String]?
    public let additionalClients: [String: AdditionalHttpClient]?
    
    public init(retryOnUnknownError: Bool,
                knownErrorsDefaultRetryBehavior: KnownErrorsDefaultRetryBehavior,
                unretriableUnknownErrors: Set<String>,
                retriableUnknownErrors: Set<String>,
                clientDelegateNameOverride: String? = nil,
                clientDelegateParameters: [String]? = nil,
                additionalClients: [String: AdditionalHttpClient]? = nil) {
        self.retryOnUnknownError = retryOnUnknownError
        self.knownErrorsDefaultRetryBehavior = knownErrorsDefaultRetryBehavior
        self.unretriableUnknownErrors = unretriableUnknownErrors
        self.retriableUnknownErrors = retriableUnknownErrors
        self.clientDelegateNameOverride = clientDelegateNameOverride
        self.clientDelegateParameters = clientDelegateParameters
        self.additionalClients = additionalClients
    }
}
