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
// OpenAPIServiceModel.swift
// OpenAPIServiceModel
//

import Foundation
import OpenAPIKit30
import ServiceModelEntities
import ServiceModelCodeGeneration
import Yams

/**
 Struct that models the Metadata of the OpenAPI  model.
 */
public struct OpenAPIServiceModel: ServiceModel {
    public var serviceDescriptions: [String: ServiceDescription] = [:]
    public var structureDescriptions: [String: StructureDescription] = [:]
    public var operationDescriptions: [String: OperationDescription] = [:]
    public var fieldDescriptions: [String: Fields] = [:]
    public var errorTypes: Set<String> = []
    public var typeMappings: [String: String] = [:]
    public var errorCodeMappings: [String: String] = [:]
    
    public static func create(data: Data, modelFormat: ModelFormat,
                              modelOverride: ModelOverride?) throws -> OpenAPIServiceModel {
        let definition: OpenAPI.Document
        switch modelFormat {
        case .yaml:
            let decoder = YAMLDecoder()
            let dataAsString = String(data: data, encoding: .utf8)!
            definition = try decoder.decode(OpenAPI.Document.self, from: dataAsString)
        default:
            let decoder = JSONDecoder()
            definition = try decoder.decode(OpenAPI.Document.self, from: data)
        }
        
        return createOpenAPIModel(definition: definition, modelOverride: modelOverride)
    }
}
