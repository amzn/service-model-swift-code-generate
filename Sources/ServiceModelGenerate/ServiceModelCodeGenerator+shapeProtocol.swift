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
// ServiceModelCodeGenerator+shapeProtocol.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

internal extension ServiceModelCodeGenerator {
    func addShapeProtocol(name: String, fileBuilder: FileBuilder,
                                   structureElements: StructureElements) {
        let baseName = applicationDescription.baseName
        // add conformance to Equatable
        fileBuilder.appendLine("""
            
            public protocol \(name)Shape {
            """)
        
        var previousAssociatedTypes: Set<String> = []
        fileBuilder.incIndent()
        if !structureElements.associatedTypeLines.isEmpty {
            structureElements.associatedTypeLines.forEach { line in
                if previousAssociatedTypes.contains(line) {
                    return
                }
                previousAssociatedTypes.insert(line)
                fileBuilder.appendLine("associatedtype " + line)
                
            }
            fileBuilder.appendEmptyLine()
        }
        
        structureElements.protocolVariableDeclarationLines.forEach { line in fileBuilder.appendLine(line) }
        fileBuilder.decIndent()
        
        let willConversionFail = willShapeConversionFail(fieldName: name, alreadySeenShapes: [])
        let failPostix = willConversionFail ? " throws" : ""
        
        fileBuilder.appendLine("""
            
                func as\(baseName)Model\(name)()\(failPostix) -> \(baseName)Model.\(name)
            }
            """)
    }

    func addShapeDefaultFunctions(name: String, fileBuilder: FileBuilder,
                                           structureElements: StructureElements) {
        let baseName = applicationDescription.baseName
        let willConversionFail = willShapeConversionFail(fieldName: name, alreadySeenShapes: [])
        let failPostix = willConversionFail ? " throws" : ""
        
        // add conformance to Equatable
        fileBuilder.appendLine("""
            
            public extension \(name)Shape {
            
                func as\(baseName)Model\(name)()\(failPostix) -> \(baseName)Model.\(name) {
                    if let modelInstance = self as? \(name) {
                        // don't need to convert, already can be serialized
                        return modelInstance
                    } else {
            """)
        
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        fileBuilder.incIndent()
        
        structureElements.shapeProtocolConstructionSetupLines.forEach { line in fileBuilder.appendLine(line) }
        if !structureElements.shapeProtocolConstructionLines.isEmpty {
            structureElements.shapeProtocolConstructionLines.forEach { line in fileBuilder.appendLine(line) }
        } else {
            fileBuilder.appendLine("return \(name)()")
        }
        fileBuilder.decIndent()
        fileBuilder.decIndent()
        fileBuilder.decIndent()
        
        fileBuilder.appendLine("""
                    }
                }
            }
            """)
    }
}
