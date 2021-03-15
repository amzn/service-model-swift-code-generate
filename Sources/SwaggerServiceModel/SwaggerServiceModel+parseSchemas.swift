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
// SwaggerServiceModel+parseSchemas.swift
// SwaggerServiceModel
//

import Foundation
import ServiceModelEntities
import ServiceModelCodeGeneration
import SwaggerParser
import Yams

internal extension SwaggerServiceModel {
    static func parseDefinitionSchemas(model: inout SwaggerServiceModel, enclosingEntityName: inout String,
                                       schema: SwaggerParser.Schema, modelOverride: ModelOverride?) {
        switch schema.type {
        case .boolean:
            model.fieldDescriptions[enclosingEntityName] = .boolean
        case .integer(.int32, let metadata),.integer(.none, let metadata) :
            
            model.fieldDescriptions[enclosingEntityName] = Fields.integer(rangeConstraint:
                NumericRangeConstraint<Int>(minimum: metadata.minimum,
                                            maximum: metadata.maximum,
                                            exclusiveMinimum: metadata.exclusiveMinimum ?? false,
                                            exclusiveMaximum: metadata.exclusiveMaximum ?? false))
        case .integer(.int64, let metadata):
            model.fieldDescriptions[enclosingEntityName] = Fields.long(rangeConstraint:
                NumericRangeConstraint<Int>(minimum: metadata.minimum,
                                            maximum: metadata.maximum,
                                            exclusiveMinimum: metadata.exclusiveMinimum ?? false,
                                            exclusiveMaximum: metadata.exclusiveMaximum ?? false))
            
        case .structure(let structureSchema):
            var structureDescription = StructureDescription()
            parseStructureSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                                 model: &model, structureSchema: structureSchema, modelOverride: modelOverride)
            
            model.structureDescriptions[enclosingEntityName] = structureDescription
        case .object(let objectSchema):
            if case .b(let mapSchema) = objectSchema.additionalProperties {
                parseMapDefinitionSchema(mapSchema: mapSchema,
                                         enclosingEntityName: &enclosingEntityName,
                                         model: &model)
            } else {
                var structureDescription = StructureDescription()
                parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                                  model: &model, objectSchema: objectSchema, modelOverride: modelOverride)

                model.structureDescriptions[enclosingEntityName] = structureDescription
            }
        case .array(let arrayMetadata):
            parseArrayDefinitionSchemas(arrayMetadata: arrayMetadata, enclosingEntityName: &enclosingEntityName,
                                        model: &model, modelOverride: modelOverride)
        case .allOf(let allOfSchema):
            var structureDescription = StructureDescription()
            parseAllOfSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                             model: &model, allOfSchema: allOfSchema, modelOverride: modelOverride)
            model.structureDescriptions[enclosingEntityName] = structureDescription
        case .string(_, let metadata):
            addStringField(metadata: metadata, schema: schema,
                           model: &model, fieldName: enclosingEntityName, modelOverride: modelOverride)
        case .number(_, let metadata):
            model.fieldDescriptions[enclosingEntityName] = Fields.double(rangeConstraint:
                NumericRangeConstraint<Double>(minimum: metadata.minimum,
                                               maximum: metadata.maximum,
                                               exclusiveMinimum: metadata.exclusiveMinimum ?? false,
                                               exclusiveMaximum: metadata.exclusiveMaximum ?? false))
        case .enumeration:
            model.fieldDescriptions[enclosingEntityName] = Fields.string(regexConstraint: nil, lengthConstraint: LengthRangeConstraint<Int>(),
                                                          valueConstraints: getEnumerationValues(metadata: schema.metadata))
        case .file, .any, .null, .oneOf:
            fatalError("Not implemented.")
        }
    }
    
    static func parseObjectSchema(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                  model: inout SwaggerServiceModel, objectSchema: SwaggerParser.ObjectSchema,
                                  modelOverride: ModelOverride?) {
        let sortedKeys = objectSchema.properties.keys.sorted(by: <)
        
        for (index, name) in sortedKeys.enumerated() {
            guard let property = objectSchema.properties[name] else {
                fatalError()
            }
            switch property.type {
            case .structure(let structure):
                structureDescription.members[name] = Member(value: structure.name, position: index,
                                                            required: objectSchema.required.contains(name),
                                                            documentation: nil)
            default:
                var enclosingEntityNameForProperty = enclosingEntityName + name.startingWithUppercase
                parseDefinitionSchemas(model: &model, enclosingEntityName: &enclosingEntityNameForProperty,
                                       schema: property, modelOverride: modelOverride)
                
                structureDescription.members[name] = Member(value: enclosingEntityNameForProperty, position: index,
                                                            required: objectSchema.required.contains(name),
                                                            documentation: nil)
            }
        }
    }
    
    static func parseMapDefinitionSchema(mapSchema: Schema,
                                         enclosingEntityName: inout String,
                                         model: inout SwaggerServiceModel) {
        let valueType: String
        switch mapSchema.type {
        case .structure(let structureSchema):
            valueType = structureSchema.name
        case .string:
            valueType = "String"
        default:
            fatalError("Not implemented.")
        }

        model.fieldDescriptions[enclosingEntityName] = Fields.map(
            keyType: "String", valueType: valueType,
            lengthConstraint: LengthRangeConstraint<Int>())
    }
    
    static func parseArrayDefinitionSchemas(arrayMetadata: (ArraySchema),
                                            enclosingEntityName: inout String,
                                            model: inout SwaggerServiceModel,
                                            modelOverride: ModelOverride?) {
        let type: String
        switch arrayMetadata.items {
        case .one(let value):
            switch value.type {
            case .structure(let structure):
                type = structure.name
            default:
                var arrayElementEntityName: String
                
                // if the enclosingEntityName ends in an "s"
                if enclosingEntityName.suffix(1).lowercased() == "s" {
                    arrayElementEntityName = String(enclosingEntityName.dropLast())
                } else {
                    arrayElementEntityName = enclosingEntityName
                    enclosingEntityName = "\(enclosingEntityName)s"
                }
                parseDefinitionSchemas(model: &model, enclosingEntityName: &arrayElementEntityName,
                                       schema: value, modelOverride: modelOverride)
                type = arrayElementEntityName
            }
        case .many:
            fatalError("Not implemented.")
        }
        
        let lengthConstraint = LengthRangeConstraint<Int>(minimum: arrayMetadata.metadata.minItems,
                                                          maximum: arrayMetadata.metadata.maxItems)
        model.fieldDescriptions[enclosingEntityName] = Fields.list(type: type,
                                                                   lengthConstraint: lengthConstraint)
    }
    
    /**
     * Objects referencing a single structure should be defined as if they were that structure.
     */
    static func parseStructureSchema(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                     model: inout SwaggerServiceModel, structureSchema: SwaggerParser.Structure<Schema>,
                                     modelOverride: ModelOverride?) {
        switch structureSchema.structure.type {
        case .object(let objectSchema):
            parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                              model: &model, objectSchema: objectSchema, modelOverride: modelOverride)
        default:
            fatalError("Non-object direct structure references are not implemented: \(structureSchema.structure.type)")
        }
    }

    /**
     * AllOf schemas should merge the inline structures and objects into a single defintion.
     */
    static func parseAllOfSchema(structureDescription: inout StructureDescription, enclosingEntityName: inout String,
                                 model: inout SwaggerServiceModel, allOfSchema: SwaggerParser.AllOfSchema,
                                 modelOverride: ModelOverride?) {
        for (index, subschema) in allOfSchema.subschemas.enumerated() {
            var enclosingEntityNameForProperty = "\(enclosingEntityName)\(index + 1)"
            
            switch subschema.type {
            case .structure(let structureSchema):
                parseStructureSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityNameForProperty,
                                     model: &model, structureSchema: structureSchema, modelOverride: modelOverride)
            case .object(let objectSchema):
                parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityNameForProperty,
                                  model: &model, objectSchema: objectSchema, modelOverride: modelOverride)
            default:
                fatalError("Non object/structure allOf schemas are not implemented. \(subschema.type)")
            }
        }
    }
}
