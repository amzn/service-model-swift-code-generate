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
// ServiceModelCodeGenerator+generateDefaultInstances.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public enum DefaultInstancesGenerationType {
    case internalTypes
    case json
}

public extension ServiceModelCodeGenerator {
    /**
     Generate default instances for in a Service Model.
     
     - Parameters:
        - generationType: The type of test input to generate.
     */
    func generateDefaultInstances(generationType: DefaultInstancesGenerationType,
                                  modelTargetName: String) {
        
        let fileBuilder = FileBuilder()
        let baseName = applicationDescription.baseName
        if let fileHeader = customizations.fileHeader {
            fileBuilder.appendLine(fileHeader)
        }
        
        addGeneratedFileHeader(fileBuilder: fileBuilder)
        
        fileBuilder.appendLine("""
            // \(baseName)ModelDefaultInstances.swift
            // \(modelTargetName)
            //
            
            import Foundation
            """)
        
        addDefaultValues(fileBuilder)
        
        func getOverrideFieldName(fieldName: String) -> String? {
            guard modelOverride?.namedFieldValuesOverride?[fieldName] != nil else {
                return nil
            }
            
            let staticFieldName = getNormalizedVariableName(modelTypeName: fieldName)
            return "DefaultValues.\(staticFieldName)"
        }
        
        // sort the structures in alphabetical order for output
        let sortedStructures = model.structureDescriptions.sorted { entry1, entry2 in
            return entry1.key < entry2.key
        }
        
        // iterate through the structures
        for (name, _) in sortedStructures {
            addDefaultStructureInstance(generationType: generationType, modelTargetName: modelTargetName, fileBuilder: fileBuilder,
                                        name: name, getOverrideFieldName: getOverrideFieldName)
        }
        
        let fileName = "\(baseName)ModelDefaultInstances.swift"
        let baseFilePath = applicationDescription.baseFilePath
        fileBuilder.write(toFile: fileName, atFilePath: "\(baseFilePath)/Sources/\(modelTargetName)")
    }
    
    private func addDefaultValues(_ fileBuilder: FileBuilder) {
        if let fieldValues = modelOverride?.namedFieldValuesOverride {
            fileBuilder.appendLine("""

                private struct DefaultValues {
                """)
            fileBuilder.incIndent()
            
            let sortedFields = fieldValues.sorted { $0.key < $1.key }
            
            sortedFields.forEach { field in
                let staticFieldName = getNormalizedVariableName(modelTypeName: field.key)
                fileBuilder.appendLine("static let \(staticFieldName) = \(field.value)")
            }
            
            fileBuilder.decIndent()
            fileBuilder.appendLine("""
                }
                """)
        }
    }
    
    private func addDefaultStructureInstance(generationType: DefaultInstancesGenerationType, modelTargetName: String,
                                             fileBuilder: FileBuilder, name: String, getOverrideFieldName: @escaping (String) -> String?) {
        switch generationType {
        case .internalTypes:
            // create a function that returns the default instance of this structure
            fileBuilder.appendLine("""
                
                public extension \(name) {
                    /**
                     Default instance of the \(name) structure.
                     */
                    static let __default: \(modelTargetName).\(name) = {
                """)
            fileBuilder.incIndent()
            fileBuilder.incIndent()
            createStructureStubVariable(type: name, modelTargetName: modelTargetName,
                                        fileBuilder: fileBuilder,
                                        declarationPrefix: "let defaultInstance =",
                                        fatalOnError: true,
                                        overrideFieldNameProvider: getOverrideFieldName)
            fileBuilder.appendEmptyLine()
            fileBuilder.appendLine("return defaultInstance")
            fileBuilder.appendLine("}()", preDec: true)
            fileBuilder.appendLine("}", preDec: true)
        case .json:
            fileBuilder.appendLine("""
                
                /**
                Serialized default test instance of the \(name) structure.
                */
                """)
            createStructureJsonVariable(type: name, fileBuilder: fileBuilder)
        }
    }
}
