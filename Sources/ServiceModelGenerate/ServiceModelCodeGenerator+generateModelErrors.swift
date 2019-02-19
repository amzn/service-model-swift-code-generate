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
// ServiceModelCodeGenerator+generateModelErrors.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    /**
     Generate the errors specified in the Model.
     
     - Parameters:
        - delegate: The delegate to use when generating this client.
     */
    public func generateModelErrors(delegate: ModelErrorsDelegate) {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        fileBuilder.appendLine("""
            // swiftlint:disable superfluous_disable_command
            // swiftlint:disable file_length line_length identifier_name type_name vertical_parameter_alignment
            // -- Generated Code; do not edit --
            //
            // \(baseName)ModelErrors.swift
            // \(baseName)Model
            //
            
            import Foundation
            import LoggerAPI
            """)
        
        if case let .generateWithCustomConformance(libraryImport: libraryImport, _) = delegate.optionSetGeneration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        fileBuilder.appendEmptyLine()
        
        let sortedErrors = model.errorTypes.sorted { entry1, entry2 in
            return entry1 < entry2
        }
        
        generateErrorDefinition(fileBuilder: fileBuilder,
                                sortedErrors: sortedErrors,
                                delegate: delegate)
        generateProtocolExtension(fileBuilder: fileBuilder,
                                  sortedErrors: sortedErrors,
                                  delegate: delegate)
        
        switch delegate.optionSetGeneration {
        case .noGeneration:
            break
        default:
            generateErrorOptionSet(fileBuilder: fileBuilder,
                                   sortedErrors: sortedErrors,
                                   delegate: delegate)
        }
        
        let fileName = "\(baseName)ModelErrors.swift"
        fileBuilder.write(toFile: fileName, atFilePath: "\(applicationDescription.baseFilePath)/Sources/\(baseName)Model")
    }

    private func generateProtocolExtension(fileBuilder: FileBuilder,
                                           sortedErrors: [String],
                                           delegate: ModelErrorsDelegate) {
        let baseName = applicationDescription.baseName
        guard !sortedErrors.isEmpty else {
            return
        }
        
        if delegate.generateCustomStringConvertibleConformance {
            let baseName = applicationDescription.baseName
            // create an option set to specify the possible errors from an operation
            
            fileBuilder.appendLine("""
                extension \(baseName)Error: CustomStringConvertible {
                    public var description: String {
                        switch self {
                """)
            
            fileBuilder.incIndent()
            fileBuilder.incIndent()
            // for each of the errors
            for name in sortedErrors {
                let internalName = name.normalizedErrorName
                fileBuilder.appendLine("""
                    case .\(internalName):
                        return \(internalName)Identity
                    """)
            }
            fileBuilder.decIndent()
            fileBuilder.decIndent()
            
            fileBuilder.appendLine("""
                        }
                    }
                }
                """)
        }
        
        if delegate.generateCustomStringConvertibleConformance
            && delegate.generateEncodableConformance {
                fileBuilder.appendEmptyLine()
        }
        
        if delegate.generateEncodableConformance {
            fileBuilder.appendLine("""
                extension \(baseName)Error: Encodable {
                    public func encode(to encoder: Encoder) throws {
                        switch self {
                """)
            
            fileBuilder.incIndent()
            fileBuilder.incIndent()
            // for each of the errors
            for name in sortedErrors {
                let internalName = name.normalizedErrorName
                fileBuilder.appendLine("""
                    case .\(internalName)(let details):
                        try details.encode(to: encoder)
                    """)
            }
            fileBuilder.decIndent()
            fileBuilder.decIndent()
            
            fileBuilder.appendLine("""
                        }
                    }
                }
                
                """)
        }
    }
    
    private func addErrorIdentities(fileBuilder: FileBuilder,
                                    sortedErrors: [String],
                                    delegate: ModelErrorsDelegate) {
        if delegate.canExpectValidationError {
            fileBuilder.appendLine("""
                private let validationErrorIdentityBuiltIn = "ValidationError"
                
                """)
        }
        
        // for each of the errors
        for name in sortedErrors {
            let internalName = name.normalizedErrorName
            fileBuilder.appendLine("""
                private let \(internalName)Identity = "\(name)"
                """)
        }
    }
    
    private func addCodingError(fileBuilder: FileBuilder) {
        let baseName = applicationDescription.baseName
        fileBuilder.appendLine("""
            
            public enum \(baseName)CodingError: Swift.Error {
                case unknownError
            """)
        
        // if we are using an internal validation error
        if case .internal = customizations.validationErrorDeclaration {
            fileBuilder.appendLine("""
                    case validationError(reason: String)
                """)
        }
        
        // if we are using an internal unrecognized error
        if case .internal = customizations.unrecognizedErrorDeclaration {
            fileBuilder.appendLine("""
                    case unrecognizedError(String, String?)
                """)
        }
        
        fileBuilder.appendLine("""
            }
            """)
        fileBuilder.appendEmptyLine()
    }
    
    private func generateErrorDefinition(fileBuilder: FileBuilder,
                                         sortedErrors: [String],
                                         delegate: ModelErrorsDelegate) {
        let baseName = applicationDescription.baseName
        addErrorIdentities(fileBuilder: fileBuilder, sortedErrors: sortedErrors, delegate: delegate)
        
        // avoid an enum with no cases
        let entityType: String
        if model.errorTypes.count > 0 {
            entityType = "enum"
        } else {
            entityType = "struct"
        }
        
        addCodingError(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            public \(entityType) \(baseName)Error: Swift.Error, Decodable {
            """)
        fileBuilder.incIndent()
        
        // for each of the errors
        for name in sortedErrors {
            let internalName = name.normalizedErrorName
            fileBuilder.appendLine("case \(internalName)(\(name))")
        }
        
        delegate.errorTypeInitializerGenerator(fileBuilder: fileBuilder,
                                               errorTypes: model.errorTypes.sorted(by: <),
                                               codingErrorUnknownError: "\(baseName)CodingError.unknownError")
        
        fileBuilder.incIndent()
        // for each of the errors
        for name in model.errorTypes.sorted(by: <) {
            let internalName = name.normalizedErrorName
            fileBuilder.appendLine("""
                case \(internalName)Identity:
                    let errorPayload = try \(name)(from: decoder)
                    self = \(baseName)Error.\(internalName)(errorPayload)
                """)
        }
        fileBuilder.decIndent()
        
        // If validation errors can be expected
        if delegate.canExpectValidationError {
            fileBuilder.appendLine("""
                    case validationErrorIdentityBuiltIn:
                        let errorMessage = try values.decodeIfPresent(String.self, forKey: .errorMessage) ?? ""
                        throw \(validationErrorType).validationError(reason: errorMessage)
                """)
        }
        
        // Otherwise this is a unrecognized error
        fileBuilder.appendLine("""
                default:
                    throw \(unrecognizedErrorType).unrecognizedError(errorReason, errorMessage)
                }
            }

            """)
        
        fileBuilder.decIndent()
        fileBuilder.appendLine("""
            }
            
            """)
    }

    private func generateErrorOptionSet(fileBuilder: FileBuilder,
                                        sortedErrors: [String],
                                        delegate: ModelErrorsDelegate) {
        let baseName = applicationDescription.baseName
        
        fileBuilder.appendLine("""
            public struct \(baseName)ErrorTypes: OptionSet {
                public let rawValue: Int
            
                public init(rawValue: Int) {
                    self.rawValue = rawValue
                }
            
            """)
        
        // for each of the errors
        for (index, name) in sortedErrors.enumerated() {
            let internalName = name.normalizedErrorName
            fileBuilder.appendLine("    public static let \(internalName) = \(baseName)ErrorTypes(rawValue: \(index + 1))")
        }
        
        fileBuilder.appendLine("""
            }
            
            extension \(baseName)ErrorTypes: \(delegate.errorOptionSetConformance) {
                public var description: String {
                    switch rawValue {
            """)
        
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        // for each of the errors
        for (index, name) in sortedErrors.enumerated() {
            let internalName = name.normalizedErrorName
            fileBuilder.appendLine("""
                case \(index + 1):
                    return \(internalName)Identity
                """)
        }
        fileBuilder.decIndent()
        fileBuilder.decIndent()
        
        fileBuilder.appendLine("""
                    default:
                        return ""
                    }
                }
            }
            """)
    }
}
