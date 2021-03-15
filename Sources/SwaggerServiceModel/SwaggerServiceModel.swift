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
// SwaggerServiceModel.swift
// SwaggerServiceModel
//

import Foundation
import ServiceModelEntities
import ServiceModelCodeGeneration
import SwaggerParser
import Yams

/**
 Struct that models the Metadata of the Swagger model.
 */
public struct SwaggerServiceModel: ServiceModel {
    var documentationDescriptions: [String: String] = [:]
    public var serviceDescriptions: [String: ServiceDescription] = [:]
    public var structureDescriptions: [String: StructureDescription] = [:]
    public var operationDescriptions: [String: OperationDescription] = [:]
    public var fieldDescriptions: [String: Fields] = [:]
    public var errorTypes: Set<String> = []
    public var typeMappings: [String: String] = [:]
    public var errorCodeMappings: [String: String] = [:]
    
    public static func create(data: Data, modelFormat: ModelFormat,
                              modelOverride: ModelOverride?) throws -> SwaggerServiceModel {
        let definition: Swagger
        switch modelFormat {
        case .yaml:
            let decoder = YAMLDecoder()
            let dataAsString = String(data: data, encoding: .utf8)!
            let builder = try decoder.decode(SwaggerBuilder.self, from: dataAsString)
            definition = try builder.build(builder)
        default:
            let decoder = JSONDecoder()
            let builder = try decoder.decode(SwaggerBuilder.self, from: data)
            definition = try builder.build(builder)
        }

        return createSwaggerModel(definition: definition, modelOverride: modelOverride)
    }
}
