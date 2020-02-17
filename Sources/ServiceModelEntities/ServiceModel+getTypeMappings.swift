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
// ServiceModel+getTypeMappings.swift
// ServiceModelEntities
//

import Foundation

private struct NormalizedNameEntry {
    var count: Int
    var entityTypes: [String: [String]]
}

public extension ServiceModel {
    
    private static func addType(name: String, entityType: String, normalizedTypeNames: inout [String: NormalizedNameEntry]) {
        let internalTypeName = name.startingWithUppercase
        
        let updatedNormalizedNameEntry: NormalizedNameEntry
        // if there is existing types for this normalizedTypeName
        if var normalizedNameEntry = normalizedTypeNames[internalTypeName] {
            let updatedTypeNames: [String]
            // if there are existing types for this typename
            if var existingTypeNames = normalizedNameEntry.entityTypes[entityType] {
                existingTypeNames.append(name)
                updatedTypeNames = existingTypeNames
            } else {
                updatedTypeNames = [name]
            }
            
            normalizedNameEntry.count += 1
            normalizedNameEntry.entityTypes[entityType] = updatedTypeNames
            
            updatedNormalizedNameEntry = normalizedNameEntry
        } else {
            updatedNormalizedNameEntry = NormalizedNameEntry(count: 1, entityTypes: [entityType: [name]])
        }
        
        normalizedTypeNames[internalTypeName] = updatedNormalizedNameEntry
    }
    
    static func getTypeMappings(structureDescriptions: [String: StructureDescription],
                                fieldDescriptions: [String: Fields]) -> [String: String] {
        var normalizedTypeNames: [String: NormalizedNameEntry] = [:]
        
        // iterate through all fields
        fieldDescriptions.forEach { (arg) in
            let (key, value) = arg
            addType(name: key, entityType: value.typeDescription, normalizedTypeNames: &normalizedTypeNames)
        }
        
        // iterate through all structures
        structureDescriptions.keys.forEach { key in
            addType(name: key, entityType: "", normalizedTypeNames: &normalizedTypeNames)
        }
        
        // remove any normalized names not with duplicates
        let duplications = normalizedTypeNames.filter { entry in entry.value.count > 1 }
        
        var typeMapping: [String: String] = [:]
        
        for (normalizedName, normalizedNameEntry) in duplications {
            for (entityType, typeNames) in normalizedNameEntry.entityTypes {
                let entityTypeValue = normalizedNameEntry.entityTypes.count > 1 ? entityType : ""
                
                for (index, typeName) in typeNames.enumerated() {
                    let indexValue = typeNames.count > 1 ? "\(index + 1)" : ""
                    
                    if entityType == "String" && normalizedName == "String"
                            && entityTypeValue.isEmpty {
                        typeMapping[typeName] = "String"
                    } else {
                        typeMapping[typeName] = "\(normalizedName)\(entityTypeValue)\(indexValue)"
                    }
                }
            }
        }
        
        return typeMapping
    }
}
