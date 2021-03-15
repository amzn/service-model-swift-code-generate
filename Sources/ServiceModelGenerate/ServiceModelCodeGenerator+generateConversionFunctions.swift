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
// ServiceModelCodeGenerator+generateConversionFunctions.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

extension ServiceModelCodeGenerator {
    func createArrayConversionFunction(fileBuilder: FileBuilder,
                                       name: String, innerType: String) {
        let typeName = name.getNormalizedTypeName(forModel: model)
        let innerTypeName = innerType.getNormalizedTypeName(forModel: model)
        let baseName = applicationDescription.baseName
        
        let willConversionFail = willShapeConversionFail(fieldName: innerType, alreadySeenShapes: [])
        
        let tryPrefix: String
        let failPostfix: String
        if willConversionFail {
            tryPrefix = "try "
            failPostfix = " throws"
        } else {
            tryPrefix = ""
            failPostfix = ""
        }
        
        let category = getShapeCategory(fieldName: innerType,
                                        collectionAssociatedType: "Element")
        
        switch category {
        case .builtInType:
            return
        case .protocolType(let type):
            fileBuilder.appendLine("""
            
            public extension Array where Element: \(type) {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.map { \(tryPrefix)$0.as\(baseName)Model\(innerTypeName)() }
               }
            }
            """)
        case .collectionType(let whereClause, let builtInInnerTypes):
            // don't need this extension if everything is builtin
            if builtInInnerTypes {
                return
            }
            
            fileBuilder.appendLine("""
            
            public extension Array where \(whereClause) {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.map { \(tryPrefix)$0.as\(baseName)Model\(innerTypeName)() }
               }
            }
            """)
        case .enumType:
            fileBuilder.appendLine("""
            
            public extension Array where Element: CustomStringConvertible {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.map { \(tryPrefix)$0.as\(baseName)Model\(innerTypeName)() }
               }
            }
            """)
        }
    }

    func createMapConversionFunction(fileBuilder: FileBuilder,
                                     name: String, valueType: String) {
        let typeName = name.getNormalizedTypeName(forModel: model)
        let baseName = applicationDescription.baseName
        
        let willConversionFail = willShapeConversionFail(fieldName: valueType, alreadySeenShapes: [])
        
        let tryPrefix: String
        let failPostfix: String
        if willConversionFail {
            tryPrefix = "try "
            failPostfix = " throws"
        } else {
            tryPrefix = ""
            failPostfix = ""
        }
        
        let category = getShapeCategory(fieldName: valueType,
                                        collectionAssociatedType: "Value")
        
        switch category {
        case .builtInType:
            return
        case .protocolType(let type):
            fileBuilder.appendLine("""
            
            public extension Dictionary where Key == String, Value: \(type) {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.mapValues { \(tryPrefix)$0.as\(baseName)Model\(valueType)() }
               }
            }
            """)
        case .collectionType(let whereClause, let builtInInnerTypes):
            // don't need this extension if everything is builtin
            if builtInInnerTypes {
                return
            }
            
            fileBuilder.appendLine("""
            
            public extension Dictionary where Key == String, \(whereClause) {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.mapValues { \(tryPrefix)$0.as\(baseName)Model\(valueType)() }
               }
            }
            """)
        case .enumType:
            fileBuilder.appendLine("""
            
            public extension Dictionary where Value: CustomStringConvertible {
               func as\(baseName)Model\(typeName)()\(failPostfix) -> \(baseName)Model.\(typeName) {
                   return \(tryPrefix)self.mapValues { \(tryPrefix)$0.as\(baseName)Model\(valueType)() }
               }
            }
            """)
        }
    }
}
