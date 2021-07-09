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
// ParseSchemas.swift
// OpenAPIServiceModel
//

import Foundation
import OpenAPIKit
import ServiceModelEntities
import ServiceModelCodeGeneration
// import SwaggerParser
import Yams

internal extension OpenAPIServiceModel {
    static func parseDefinitionSchemas(model: inout OpenAPIServiceModel, enclosingEntityName: inout String,
                                       schema: JSONSchema, modelOverride: ModelOverride?) {
       
    }
    
    static func parseObjectSchema(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                  model: inout OpenAPIServiceModel, objectSchema: JSONSchema.ObjectContext,
                                  modelOverride: ModelOverride?) {
    }
    
    static func parseMapDefinitionSchema(mapSchema: JSONSchema,
                                         enclosingEntityName: inout String,
                                         model: inout OpenAPIServiceModel) {
    }
    
    static func parseArrayDefinitionSchemas(arrayMetadata: JSONSchema.ArrayContext,
                                            enclosingEntityName: inout String,
                                            model: inout OpenAPIServiceModel,
                                            modelOverride: ModelOverride?) {
        
    }
}
