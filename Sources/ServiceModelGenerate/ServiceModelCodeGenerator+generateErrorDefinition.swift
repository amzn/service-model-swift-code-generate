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
// ServiceModelCodeGenerator+generateErrorDefinition.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    
    internal func generateErrorDefinition(fileBuilder: FileBuilder,
                                          sortedErrors: [ErrorType],
                                          delegate: ModelErrorsDelegate) {
        let baseName = applicationDescription.baseName
        addErrorIdentities(fileBuilder: fileBuilder, sortedErrors: sortedErrors,
                           delegate: delegate)
        
        let errorPayloadTypeName = generateErrorPayloadType(fileBuilder: fileBuilder,
                                                            sortedErrors: sortedErrors,
                                                            delegate: delegate)
        
        let entityType = getEntityType(fileBuilder: fileBuilder, sortedErrors: sortedErrors,
                                       delegate: delegate)
                
        fileBuilder.appendLine("""
            
            public \(entityType) \(baseName)Error: Swift.Error, Decodable {
            """)
        fileBuilder.incIndent()
        
        addErrorCases(fileBuilder: fileBuilder, sortedErrors: sortedErrors,
                      errorPayloadTypeName: errorPayloadTypeName)
        
        // add any additional error cases from the delegate
        delegate.errorTypeAdditionalErrorCasesGenerator(
            fileBuilder: fileBuilder,
            errorTypes: sortedErrors)
        
        // add the coding keys from the delegate
        fileBuilder.appendEmptyLine()
        delegate.errorTypeCodingKeysGenerator(fileBuilder: fileBuilder,
                                              errorTypes: sortedErrors)
        
        fileBuilder.appendEmptyLine()
        fileBuilder.appendLine("public init(from decoder: Decoder) throws {", postInc: true)
        
        // add code to get the identity variable from the delegate
        let identityVariable = delegate.errorTypeIdentityGenerator(
            fileBuilder: fileBuilder,
            codingErrorUnknownError: "\(baseName)Error.unknownError")
        
        fileBuilder.appendEmptyLine()
        fileBuilder.appendLine("switch \(identityVariable) {")
        
        addErrorDecodeStatements(fileBuilder: fileBuilder, sortedErrors: sortedErrors,
                                 delegate: delegate, errorPayloadTypeName: errorPayloadTypeName)
        fileBuilder.decIndent()
        
        // Otherwise this is a unrecognized error
        fileBuilder.appendLine("""
                default:
                    self = \(unrecognizedErrorType).unrecognizedError(errorReason, errorMessage)
                }
            }

            """)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("""
            }
            
            """)
    }
    
    private func generateErrorPayloadType(fileBuilder: FileBuilder,
                                          sortedErrors: [ErrorType],
                                          delegate: ModelErrorsDelegate) -> String {
        // if there are additional errors, create a payload type for them
        let errorPayloadTypeName = "\(applicationDescription.baseName)ErrorPayload"
        if modelOverride?.additionalErrors?.count ?? 0 > 0 {
            fileBuilder.appendEmptyLine()
            fileBuilder.appendLine("""
                public struct \(errorPayloadTypeName): Codable {
                    public let type: String
                    public let message: String
                """)
            
            // use the coding keys from the delegate for this type.
            fileBuilder.appendEmptyLine()
            fileBuilder.incIndent()
            delegate.errorTypeCodingKeysGenerator(fileBuilder: fileBuilder,
                                                  errorTypes: sortedErrors)
            fileBuilder.decIndent()
            fileBuilder.appendLine("""
                }
                """)
        }
        
        return errorPayloadTypeName
    }
    
    private func addErrorCases(fileBuilder: FileBuilder, sortedErrors: [ErrorType],
                               errorPayloadTypeName: String) {
        // for each of the errors
        for error in sortedErrors {
            let enumName = getNormalizedEnumCaseName(
                modelTypeName: error.normalizedName,
                inStructure: "\(applicationDescription.baseName)Error",
                usingUpperCamelCase: true)
            
            let payload: String
            // if this is an error from the model
            if model.errorTypes.contains(error.identity) {
                payload = error.identity
            } else {
                payload = errorPayloadTypeName
            }
            
            fileBuilder.appendLine("case \(enumName)(\(payload))")
        }
    }
    
    private func addErrorDecodeStatements(fileBuilder: FileBuilder,
                                          sortedErrors: [ErrorType],
                                          delegate: ModelErrorsDelegate,
                                          errorPayloadTypeName: String) {
        let baseName = applicationDescription.baseName
        
        // for each of the errors
        for error in sortedErrors {
            let identityName = getNormalizedVariableName(
                modelTypeName: error.normalizedName,
                inStructure: nil,
                reservedWordsAllowed: true)
            
            let parameterName = getNormalizedVariableName(
                modelTypeName: error.normalizedName,
                inStructure: "\(baseName)Error",
                reservedWordsAllowed: true)
            
            let payload: String
            if model.errorTypes.contains(error.identity) {
                payload = error.identity
            } else {
                payload = errorPayloadTypeName
            }
            
            fileBuilder.appendLine("""
                case \(identityName)Identity:
                    let errorPayload = try \(payload)(from: decoder)
                    self = \(baseName)Error.\(parameterName)(errorPayload)
                """)
        }
        
        // If validation errors can be expected
        if delegate.canExpectValidationError {
            fileBuilder.appendLine("""
                case validationErrorIdentityBuiltIn:
                    let errorMessage = try values.decodeIfPresent(String.self, forKey: .errorMessage) ?? ""
                    throw \(validationErrorType).validationError(reason: errorMessage)
                """)
        }
        
        // add any additional error decode statements from the delegate
        delegate.errorTypeAdditionalErrorDecodeStatementsGenerator(
            fileBuilder: fileBuilder,
            errorTypes: sortedErrors)
    }
    
    private func addErrorIdentities(fileBuilder: FileBuilder,
                                    sortedErrors: [ErrorType],
                                    delegate: ModelErrorsDelegate) {
        if delegate.canExpectValidationError {
            fileBuilder.appendLine("""
                private let validationErrorIdentityBuiltIn = "ValidationError"
                
                """)
        }
        
        // for each of the errors
        for error in sortedErrors {
            let identityName = getNormalizedVariableName(
                modelTypeName: error.normalizedName,
                inStructure: nil,
                reservedWordsAllowed: true)
            
            let rawIdentity = error.identity
            let identity = model.errorCodeMappings[rawIdentity] ?? rawIdentity
            
            fileBuilder.appendLine("""
                private let \(identityName)Identity = "\(identity)"
                """)
        }
        
        delegate.errorTypeAdditionalErrorIdentitiesGenerator(fileBuilder: fileBuilder, errorTypes: sortedErrors)
    }
    
    private func getEntityType(fileBuilder: FileBuilder,
                               sortedErrors: [ErrorType],
                               delegate: ModelErrorsDelegate) -> String {
        // add any additional error cases from the delegate
        let additionalCases = delegate.errorTypeWillAddAdditionalCases(fileBuilder: fileBuilder, errorTypes: sortedErrors)
        
        // avoid an enum with no cases
        let entityType: String
        if sortedErrors.count + additionalCases > 0 {
            entityType = "enum"
        } else {
            entityType = "struct"
        }
        
        return entityType
    }
}
