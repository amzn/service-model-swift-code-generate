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
// SetOperationOutput.swift
// OpenAPIServiceModel
//

import Foundation
import OpenAPIKit
import ServiceModelEntities
import ServiceModelCodeGeneration
import Yams

internal extension OpenAPIServiceModel {
    static func filterHeaders(operation: OpenAPI.Operation, code: Int, headers: OpenAPI.Header.Map,
                              modelOverride: ModelOverride?) -> OpenAPI.Header.Map {
        
        guard let ignoreResponseHeaders = modelOverride?.ignoreResponseHeaders else {
            return headers
        }
        
        var filteredHeaders: OpenAPI.Header.Map = [:]
        
        headers.forEach { (key, value) in
            if ignoreResponseHeaders.contains("*.*.*") {
                return
            }
            
            if ignoreResponseHeaders.contains("*.*.\(key)") {
                return
            }
            
            if ignoreResponseHeaders.contains("*.\(code).*") {
                return
            }
            
            if let identifier = operation.operationId {
                if ignoreResponseHeaders.contains("\(identifier).\(code).\(key)") {
                    return
                }
                
                if ignoreResponseHeaders.contains("\(identifier).*.\(key)") {
                    return
                }
                
                if ignoreResponseHeaders.contains("\(identifier).\(code).*") {
                    return
                }
            }
            
            filteredHeaders[key] = value
        }
        
        return filteredHeaders
    }
    
    static func setOperationOutput(operation: OpenAPI.Operation, operationName: String, model: inout OpenAPIServiceModel,
                                   modelOverride: ModelOverride?, description: inout OperationDescription) {
        for (code, response) in operation.responses {
            switch response {
            case .b(let value):
                switch code {
                case .status(let code):
                    if let headers = value.headers {
                        let filteredHeaders = filterHeaders(operation: operation, code: code,
                                                            headers: headers, modelOverride: modelOverride)
                        var headerMembers: [String: Member] = [:]
                        filteredHeaders.enumerated().forEach { entry in
                            let typeName = entry.element.key.safeModelName().startingWithUppercase
                            
                            let headerName = "\(operationName)\(typeName)Header"
                            
                            if let header = entry.element.value.b  {
                                if let schema = header.schemaOrContent.schemaValue {
                                    addField(item: schema, fieldName: headerName, model: &model, modelOverride: modelOverride)
                                    let member = Member(value: headerName,
                                                        position: entry.offset,
                                                        required: false,
                                                        documentation: header.description)
                                    headerMembers[entry.element.key] = member
                                    
                                    addOperationResponseFromSchema(schema: schema, operationName: operationName, forCode: code, index: nil,
                                                                   description: &description, model: &model, modelOverride: modelOverride)
                                }
                            }
                        }
                        if !headerMembers.isEmpty {
                            setOperationOutputWithHeaders(description: &description, model: &model, headerMembers: headerMembers,
                                                          operationName: operationName, code: code)
                        }
                    }
                default:
                    let message = code
                    print(message)
                    fatalError("Not implemented")
                }
            case .a:
                let message = response
                print(message)
                fatalError("Not implemented.")
            }
        }
    }
    
    private static func setOperationOutputWithHeaders(description: inout OperationDescription, model: inout OpenAPIServiceModel,
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
