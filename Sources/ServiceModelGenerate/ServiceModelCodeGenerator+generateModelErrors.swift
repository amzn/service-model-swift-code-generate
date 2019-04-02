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
        
        let allErrorTypes: Set<String>
        if let additionalErrors = modelOverride?.additionalErrors {
            allErrorTypes = model.errorTypes.union(additionalErrors)
        } else {
            allErrorTypes = model.errorTypes
        }
        
        let sortedErrors = getSortedErrors(allErrorTypes: allErrorTypes)
        
        delegate.errorTypeAdditionalImportsGenerator(fileBuilder: fileBuilder, errorTypes: sortedErrors)
        
        if case let .generateWithCustomConformance(libraryImport: libraryImport, _) = delegate.optionSetGeneration {
            fileBuilder.appendLine("import \(libraryImport)")
        }
        
        fileBuilder.appendEmptyLine()
        
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
    
    private func getSortedErrors(allErrorTypes: Set<String>) -> [ErrorType] {
        // determine if any errors will normalize to the same name
        var errorNameCount: [String: Int] = [:]
        allErrorTypes.forEach { errorIdentity in
            let normalizedErrorName = errorIdentity.normalizedErrorName
            
            if let existingCount = errorNameCount[normalizedErrorName] {
                errorNameCount[normalizedErrorName] = existingCount + 1
            } else {
                errorNameCount[normalizedErrorName] = 1
            }
        }
        
        let rawSortedErrors = allErrorTypes.sorted { entry1, entry2 in
            return entry1 < entry2
        }
        
        let sortedErrors: [ErrorType] = rawSortedErrors.map { errorIdentity in
            let normalizedErrorName = errorIdentity.normalizedErrorName
            
            let errorNameCount = errorNameCount[normalizedErrorName] ?? 1
            
            if errorNameCount > 1 {
                // don't normalize the name as there will be a clash
                return (normalizedName: errorIdentity.upperToLowerCamelCase,
                        identity: errorIdentity)
            } else {
                // use the normalized name
                return (normalizedName: normalizedErrorName,
                        identity: errorIdentity)
            }
        }
        
        return sortedErrors
    }

    private func generateProtocolExtension(fileBuilder: FileBuilder,
                                           sortedErrors: [ErrorType],
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
            for error in sortedErrors {
                let internalName = error.normalizedName
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
            for error in sortedErrors {
                let internalName = error.normalizedName
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

    private func generateErrorOptionSet(fileBuilder: FileBuilder,
                                        sortedErrors: [ErrorType],
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
        for (index, error) in sortedErrors.enumerated() {
            let internalName = error.normalizedName
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
        for (index, error) in sortedErrors.enumerated() {
            let internalName = error.normalizedName
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
