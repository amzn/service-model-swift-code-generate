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
// SetOperationInput.swift
// OpenAPIServiceModel
//

import Foundation
import OpenAPIKit30
import ServiceModelEntities
import ServiceModelCodeGeneration
import Yams

internal extension OpenAPIServiceModel {
    struct OperationInputFields {
        let allMembers: [String: Member]
        let pathFields: [String]
        let queryFields: [String]
        let bodyFields: [String]
        let additionalHeaderFields: [String]
    }
    
    static func setOperationInput(bodyStructureName: String?,
                                  operationInputMembers: OperationInputMembers,
                                  description: inout OperationDescription,
                                  model: inout OpenAPIServiceModel,
                                  operationName: String) {
        if let bodyStructureName = bodyStructureName,
            operationInputMembers.queryMembers.isEmpty && operationInputMembers.additionalHeaderMembers.isEmpty
                && operationInputMembers.pathMembers.isEmpty {
            description.input = bodyStructureName
        } else {
            let operationInputFields = getOperationInputFields(bodyStructureName: bodyStructureName,
                                                               operationInputMembers: operationInputMembers,
                                                               model: &model)
            
            let inputModelName = "\(operationName)Request"
            let inputModelDescription = "Input model for the \(operationName) operation."
            let structureDefinition = StructureDescription(members: operationInputFields.allMembers,
                                                           documentation: inputModelDescription)
            
            model.structureDescriptions[inputModelName] = structureDefinition
            description.input = inputModelName
            
            if !operationInputFields.queryFields.isEmpty {
                description.inputDescription = OperationInputDescription(
                    pathFields: operationInputFields.pathFields,
                    queryFields: [],
                    bodyFields: operationInputFields.bodyFields,
                    additionalHeaderFields: operationInputFields.additionalHeaderFields,
                    defaultInputLocation: .query,
                    bodyStructureName: bodyStructureName)
            } else {
                description.inputDescription = OperationInputDescription(
                    pathFields: operationInputFields.pathFields,
                    queryFields: operationInputFields.queryFields,
                    bodyFields: operationInputFields.bodyFields,
                    additionalHeaderFields: operationInputFields.additionalHeaderFields,
                    defaultInputLocation: .body,
                    bodyStructureName: bodyStructureName)
            }
        }
    }
    
    static func getOperationInputFields(bodyStructureName: String?,
                                        operationInputMembers: OperationInputMembers,
                                        model: inout OpenAPIServiceModel) -> OperationInputFields {
        var allMembers: [String: Member] = [:]
        let pathFields: [String]
        let queryFields: [String]
        let bodyFields: [String]
        let additionalHeaderFields: [String]
        
        if let bodyStructureName = bodyStructureName {
                guard let structureDefinition = model.structureDescriptions[bodyStructureName] else {
                    fatalError("No structure with type \(bodyStructureName)")
                }
    
                allMembers.merge(structureDefinition.members) { (old, _) in old }
                bodyFields = [String](structureDefinition.members.keys)
            } else {
                bodyFields = []
            }
    
            allMembers.merge(operationInputMembers.queryMembers) { (old, _) in old }
            queryFields = [String](operationInputMembers.queryMembers.keys)
    
            allMembers.merge(operationInputMembers.additionalHeaderMembers) { (old, _) in old }
            additionalHeaderFields = [String](operationInputMembers.additionalHeaderMembers.keys)
    
            allMembers.merge(operationInputMembers.pathMembers) { (old, _) in old }
            pathFields = [String](operationInputMembers.pathMembers.keys)
    
            let sortedMembers = allMembers.sorted { (left, right) in left.key < right.key }
            var correctedAllMembers: [String: Member] = [:]
            sortedMembers.enumerated().forEach { entry in
                let oldMember = entry.element.value
                let correctedMember = Member(value: oldMember.value,
                                             position: entry.offset,
                                             locationName: oldMember.locationName,
                                             required: oldMember.required,
                                             documentation: oldMember.documentation)
    
                correctedAllMembers[entry.element.key] = correctedMember
            }
        
        return OperationInputFields(allMembers: correctedAllMembers,
                                    pathFields: pathFields,
                                    queryFields: queryFields,
                                    bodyFields: bodyFields,
                                    additionalHeaderFields: additionalHeaderFields)
    }
}
