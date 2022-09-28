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
// ServiceModelCodeGenerator+generateEnumerationDeclaration.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport {
    /**
     Generates declaration for an enumeration.
     
     - Parameters:
        - model: The Service Model to use.
        - fileBuilder: The FileBuilder to output to.
        - name: the name of the enumeration to generate the declaration for.
        - valueConstraints: the value options for this enumeration.
     */
    func generateEnumerationDeclaration(fileBuilder: FileBuilder,
                                        name: String,
                                        valueConstraints: [(name: String, value: String)]) {
        let typeName = name.getNormalizedTypeName(forModel: model)
        let modelTargetName = self.targetSupport.modelTargetName
        
        fileBuilder.appendEmptyLine()
        fileBuilder.appendLine("/**")
        
        var conformingProtocols: [String] = ["String", "Codable", "CustomStringConvertible", "CaseIterable"]
        if case .enabled = self.customizations.addSendableConformance {
            conformingProtocols.append("Sendable")
        }
        
        let conformingProtocolsString = conformingProtocols.joined(separator: ", ")
        fileBuilder.appendLine(" Enumeration restricting the values of the \(typeName) field.")
        fileBuilder.appendLine(" */")
        fileBuilder.appendLine("public enum \(typeName): \(conformingProtocolsString) {", postInc: true)
        
        let sortedValues = valueConstraints.sorted { (left, right) in left.name < right.name }
        // iterate through the values
        for contraint in sortedValues {
            let internalName = getNormalizedEnumCaseName(modelTypeName: contraint.name,
                                                         inStructure: name)
            // if the value is the same as the internal name
            if internalName == contraint.value {
                fileBuilder.appendLine("case \(internalName)")
            } else {
                fileBuilder.appendLine("case \(internalName) = \"\(contraint.value)\"")
            }
        }
        
        let enumCaseToUse: String
        if let enumCaseToUseOverride = modelOverride?.defaultEnumerationValueOverride?[typeName] {
            enumCaseToUse = enumCaseToUseOverride
        } else {
            enumCaseToUse = sortedValues[0].name
        }
        
        let firstInternalName = getNormalizedEnumCaseName(modelTypeName: enumCaseToUse,
                                                          inStructure: name)
        
        fileBuilder.appendEmptyLine()
        fileBuilder.appendLine("""
            public var description: String {
                return rawValue
            }

            public static let __default: \(typeName) = .\(firstInternalName)
            """)
        fileBuilder.appendLine("}", preDec: true)
        
        if customizations.generateModelShapeConversions {
            fileBuilder.appendEmptyLine()
            fileBuilder.appendLine("""
                public extension CustomStringConvertible {
                    func as\(modelTargetName)\(typeName)() throws -> \(modelTargetName).\(typeName) {
                        let description = self.description
                
                        guard let result = \(typeName)(rawValue: description) else {
                            throw \(validationErrorType).validationError(reason: "Unable to convert value '"
                                + description + "' to a \(modelTargetName).\(name) value.")
                        }
                
                        return result
                    }
                }
                """)
        }
    }
}
