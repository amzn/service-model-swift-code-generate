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
// SwaggerServiceModel+setOperationOutput.swift
// SwaggerServiceModel
//

import Foundation
import ServiceModelEntities
import ServiceModelCodeGeneration
import SwaggerParser
import Yams

internal extension SwaggerServiceModel {
    static func setOperationOutput(operation: SwaggerParser.Operation, operationName: String, model: inout SwaggerServiceModel,
                                   modelOverride: ModelOverride?, description: inout OperationDescription) {
        // iterate through the responses
        for (code, response) in operation.responses {
            switch response {
            case .a(let value):
                var headerMembers: [String: Member] = [:]
                value.headers.enumerated().forEach { entry in
                    let typeName = entry.element.key.safeModelName().startingWithUppercase
                    
                    let headerName = "\(operationName)\(typeName)Header"
                    
                    let header = entry.element.value
                    addField(type: header.type, fieldName: headerName, model: &model, modelOverride: modelOverride)
                    let member = Member(value: headerName,
                                        position: entry.offset,
                                        required: false,
                                        documentation: header.metadata.description)
                    headerMembers[entry.element.key] = member
                }
                
                if let schema = value.schema {
                    addOperationResponseFromSchema(schema, operationName: operationName, forCode: code, index: nil,
                                                   description: &description, model: &model, modelOverride: modelOverride)
                }
                
                // if there are headers
                if !headerMembers.isEmpty {
                    setOperationOutputWithHeaders(description: &description, model: &model, headerMembers: headerMembers,
                                                  operationName: operationName, code: code)
                }
            case .b:
                fatalError("Not implemented.")
            }
        }
    }
    
    private static func setOperationOutputWithHeaders(description: inout OperationDescription, model: inout SwaggerServiceModel,
                                                      headerMembers: [String: Member], operationName: String, code: Int) {
        var allMembers: [String: Member] = [:]
        let bodyFields: [String]
        let headerFields: [String]
        let bodyStructureName = description.output
        
        if let bodyStructureName = bodyStructureName {
            guard let structureDefinition = model.structureDescriptions[bodyStructureName] else {
                fatalError("No structure with type \(bodyStructureName)")
            }
            
            allMembers.merge(structureDefinition.members) { (old, _) in old }
            bodyFields = [String](structureDefinition.members.keys)
        } else {
            bodyFields = []
        }
        
        allMembers.merge(headerMembers) { (old, _) in old }
        headerFields = [String](headerMembers.keys)
        
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
        
        let outputModelName = "\(operationName)\(code)Response"
        let outputModelDescription = "Output model for the \(operationName) operation."
        let structureDefinition = StructureDescription(members: correctedAllMembers,
                                                       documentation: outputModelDescription)
        
        model.structureDescriptions[outputModelName] = structureDefinition
        description.output = outputModelName
        
        description.outputDescription = OperationOutputDescription(
            bodyFields: bodyFields,
            headerFields: headerFields,
            bodyStructureName: bodyStructureName,
            payloadAsMember: nil)
    }
}
