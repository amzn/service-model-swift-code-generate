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
// ModelErrorsDelegate.swift
// ServiceModelCodeGeneration
//

import Foundation

public typealias ErrorType = (normalizedName: String, identity: String)

/**
 Delegate protocol that can customize the generation of errors
 from the Service Model.
 */
public protocol ModelErrorsDelegate {
    /// Specifies what generation to use for the error option set.
    var optionSetGeneration: ErrorOptionSetGeneration { get }
    /// If Encodable conformance for the error type should be generated
    var generateEncodableConformance: Bool { get }
    /// If the CustomStringConvertible conformance for the error type should be generated.
    var generateCustomStringConvertibleConformance: Bool { get }
    /// If the error type should detect and decode validation errors
    var canExpectValidationError: Bool { get }
    
    /**
     Generator for the error type additional imports.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeAdditionalImportsGenerator(fileBuilder: FileBuilder,
                                             errorTypes: [ErrorType])
    
    /**
     Generator for the error type additional error identities.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeAdditionalErrorIdentitiesGenerator(fileBuilder: FileBuilder,
                                                     errorTypes: [ErrorType])
    
    /**
     Indicates the number of additional error cases that will be added.
 
      - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeWillAddAdditionalCases(fileBuilder: FileBuilder,
                                         errorTypes: [ErrorType]) -> Int
    
    /**
     Generator for the error type additional error cases.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeAdditionalErrorCasesGenerator(fileBuilder: FileBuilder,
                                                errorTypes: [ErrorType])
    
    /**
     Generator for the error type CodingKeys.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeCodingKeysGenerator(fileBuilder: FileBuilder,
                                      errorTypes: [ErrorType])
    
    /**
     Generator for the error type identity.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - codingErrorUnknownError: the error that can be thrown for an unknown error.
     - Returns: the variable name used to store the identity.
     */
    func errorTypeIdentityGenerator(fileBuilder: FileBuilder,
                                    codingErrorUnknownError: String) -> String
    
    /**
     Generator for the error type additional decode cases using the error identity.
 
     - Parameters:
        - fileBuilder: The FileBuilder to output to.
        - errorTypes: The sorted list of error types.
     */
    func errorTypeAdditionalErrorDecodeStatementsGenerator(fileBuilder: FileBuilder,
                                                           errorTypes: [ErrorType])
    
    /**
        Generator for the error type additional encode cases using the error identity.
    
        - Parameters:
           - fileBuilder: The FileBuilder to output to.
           - errorTypes: The sorted list of error types.
        */
       func errorTypeAdditionalErrorEncodeStatementsGenerator(fileBuilder: FileBuilder,
                                                              errorTypes: [ErrorType])
    
    /**
        Generator for the error type additional description cases.
    
        - Parameters:
           - fileBuilder: The FileBuilder to output to.
           - errorTypes: The sorted list of error types.
        */
       func errorTypeAdditionalDescriptionCases(fileBuilder: FileBuilder,
                                                errorTypes: [ErrorType])

    /**
        Generator for the error type additional option set items.
    
        - Parameters:
           - fileBuilder: The FileBuilder to output to.
           - optionSetTypeName: The name of the option set structure.
           - errorTypes: The sorted list of error types.
        */
    func errorTypeAdditionalOptionSetItems(fileBuilder: FileBuilder,
                                           optionSetTypeName: String,
                                           errorTypes: [ErrorType])
    
    /**
        Generator for the error type additional option set item descriptions.
    
        - Parameters:
           - fileBuilder: The FileBuilder to output to.
           - errorTypes: The sorted list of error types.
        */
    func errorTypeAdditionalOptionSetItemDescriptions(fileBuilder: FileBuilder,
                                                      errorTypes: [ErrorType])
    
    /**
        Generator for the error type additional error handling extensions.
    
        - Parameters:
           - fileBuilder: The FileBuilder to output to.
           - errorTypes: The sorted list of error types.
           - baseName: The base name for the model.
        */
    func errorTypeAdditionalExtensions(fileBuilder: FileBuilder,
                                       errorTypes: [ErrorType],
                                       baseName: String)
}

public extension ModelErrorsDelegate {
    var errorOptionSetConformance: String {
        switch optionSetGeneration {
        case .generateWithCustomConformance(_, conformanceType: let conformanceType):
            return conformanceType
        default:
            return "CustomStringConvertible"
        }
    }

    func errorTypeAdditionalOptionSetItems(fileBuilder: FileBuilder,
                                           optionSetTypeName: String,
                                           errorTypes: [ErrorType]) {
        // default implementation, do nothing
    }
    
    func errorTypeAdditionalOptionSetItemDescriptions(fileBuilder: FileBuilder,
                                                      errorTypes: [ErrorType]) {
        // default implementation, do nothing
    }
    
    func errorTypeAdditionalExtensions(fileBuilder: FileBuilder,
                                       errorTypes: [ErrorType],
                                       baseName: String) {
        // default implementation, do nothing
    }
}

/**
 Enumeration specifying the options for error option set generation.
 */
public enum ErrorOptionSetGeneration {
    /// Conforms the error option set to CustomStringConvertible.
    case generateWithCustomStringConvertibleConformance
    /// Conforms the error option set a custom protocol with the specified
    /// library import and type
    case generateWithCustomConformance(libraryImport: String, conformanceType: String)
    case noGeneration
}
