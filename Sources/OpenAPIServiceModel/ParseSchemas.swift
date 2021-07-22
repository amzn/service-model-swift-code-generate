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
import Yams

internal extension OpenAPIServiceModel {
    static func parseDefinitionSchemas(model: inout OpenAPIServiceModel, enclosingEntityName: inout String,
                                       schema: JSONSchema, modelOverride: ModelOverride?) {
        switch schema {
        case .boolean:
            model.fieldDescriptions[enclosingEntityName] = .boolean
        case .integer(let integerFormat, let integerContext):
            if integerFormat.format == .int64 {
                model.fieldDescriptions[enclosingEntityName] = Fields.long(rangeConstraint:
                    NumericRangeConstraint<Int>(minimum: integerContext.minimum?.value,
                                                maximum: integerContext.maximum?.value,
                                                exclusiveMinimum: integerContext.minimum?.exclusive ?? false,
                                                exclusiveMaximum: integerContext.maximum?.exclusive ?? false))
            } else {
                model.fieldDescriptions[enclosingEntityName] = Fields.integer(rangeConstraint:
                    NumericRangeConstraint<Int>(minimum: integerContext.minimum?.value,
                                                maximum: integerContext.maximum?.value,
                                                exclusiveMinimum: integerContext.minimum?.exclusive ?? false,
                                                exclusiveMaximum: integerContext.maximum?.exclusive ?? false))
            }

        case .object(_ , let objectContext):
            if case .b(let mapSchema) = objectContext.additionalProperties {
                parseMapDefinitionSchema(mapSchema: mapSchema,
                                         enclosingEntityName: &enclosingEntityName,
                                         model: &model)
            } else {
                var structureDescription = StructureDescription()
                parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                                  model: &model, objectSchema: objectContext, modelOverride: modelOverride)

                model.structureDescriptions[enclosingEntityName] = structureDescription
            }
        case .array(_, let arrayContext):
            parseArrayDefinitionSchemas(arrayMetadata: arrayContext, enclosingEntityName: &enclosingEntityName,
                                        model: &model, modelOverride: modelOverride)
        case .string(_, let stringContext):
            addStringField(metadata: stringContext, schema: schema,
                           model: &model, fieldName: enclosingEntityName, modelOverride: modelOverride)
        case .number(_, let numberContext):
            model.fieldDescriptions[enclosingEntityName] = Fields.double(rangeConstraint:
                NumericRangeConstraint<Double>(minimum: numberContext.minimum?.value,
                                               maximum: numberContext.maximum?.value,
                                               exclusiveMinimum: numberContext.minimum?.exclusive ?? false,
                                               exclusiveMaximum: numberContext.maximum?.exclusive ?? false))
        case .all(let otherSchema, _), .any(let otherSchema, _), .one(let otherSchema, _):
            var structureDescription = StructureDescription()
            parseOtherSchemas(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName, model: &model, otherSchema: otherSchema, modelOverride: modelOverride)
        case .reference:
            break
        case .not:
            fatalError("Schema 'not' not implemented")
        case .fragment:
            fatalError("Schema 'fragment' not implemented")
        }
    }
    
    static func parseObjectSchema(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                  model: inout OpenAPIServiceModel, objectSchema: JSONSchema.ObjectContext,
                                  modelOverride: ModelOverride?) {
        let sortedKeys = objectSchema.properties.keys.sorted(by: <)
        
        for (index, name) in sortedKeys.enumerated() {
            guard let property = objectSchema.properties[name] else {
                continue
            }
            
            var enclosingEntityNameForProperty = enclosingEntityName + name.startingWithUppercase
            parseDefinitionSchemas(model: &model, enclosingEntityName: &enclosingEntityNameForProperty,
                                       schema: property, modelOverride: modelOverride)
                
            structureDescription.members[name] = Member(value: enclosingEntityNameForProperty, position: index,
                                                            required: objectSchema.requiredProperties.contains(name),
                                                            documentation: nil)
        }
    }
    
    static func parseMapDefinitionSchema(mapSchema: JSONSchema,
                                         enclosingEntityName: inout String,
                                         model: inout OpenAPIServiceModel) {
        let valueType: String
        switch mapSchema {
        case .string:
            valueType = "String"
        default:
            fatalError("Not implemented.")
        }

        model.fieldDescriptions[enclosingEntityName] = Fields.map(
            keyType: "String", valueType: valueType,
            lengthConstraint: LengthRangeConstraint<Int>())
    }
    
    static func parseArrayDefinitionSchemas(arrayMetadata: JSONSchema.ArrayContext,
                                            enclosingEntityName: inout String,
                                            model: inout OpenAPIServiceModel,
                                            modelOverride: ModelOverride?) {
        let type: String
        if let value = arrayMetadata.items {
            
            var arrayElementEntityName: String
            
            // If the enclosingEntityName ends in an "s", swap with element name
            if enclosingEntityName.suffix(1).lowercased() == "s" {
                arrayElementEntityName = String(enclosingEntityName.dropLast())
            } else {
                arrayElementEntityName = enclosingEntityName
                enclosingEntityName = "\(enclosingEntityName)s"
            }
                
            parseDefinitionSchemas(model: &model, enclosingEntityName: &arrayElementEntityName,
                                       schema: value, modelOverride: modelOverride)
            type = arrayElementEntityName
            
            let lengthConstraint = LengthRangeConstraint<Int>(minimum: arrayMetadata.minItems,
                                                              maximum: arrayMetadata.maxItems)
            model.fieldDescriptions[enclosingEntityName] = Fields.list(type: type,
                                                                       lengthConstraint: lengthConstraint)
        }
    }
    
    // Parse all, any, one schemas
    static func parseOtherSchemas(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                  model: inout OpenAPIServiceModel, otherSchema: [JSONSchema],
                                  modelOverride: ModelOverride?) {
        for (index, subschema) in otherSchema.enumerated() {
            var enclosingEntityNameForProperty = "\(enclosingEntityName)\(index + 1)"
            
            switch subschema {
            case .object(_, let objectContext):
                parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityNameForProperty,
                                  model: &model, objectSchema: objectContext, modelOverride: modelOverride)
            default:
                fatalError("Non object/structure allOf schemas are not implemented. \(String(describing: subschema.jsonType))")
            }
        }
    }
}
