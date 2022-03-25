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
// SwaggerServiceModel+createSwaggerModel.swift
// SwaggerServiceModel
//

import Foundation
import ServiceModelEntities
import ServiceModelCodeGeneration
import SwaggerParser
import Yams

internal extension SwaggerServiceModel {
    struct OperationInputMembers {
        var queryMembers: [String: Member] = [:]
        var additionalHeaderMembers: [String: Member] = [:]
        var pathMembers: [String: Member] = [:]
    }
    
    static func filterOperations(operations: [OperationType: SwaggerParser.Operation],
                                 modelOverride: ModelOverride?) -> [OperationType: SwaggerParser.Operation] {
        
        guard let ignoreOperations = modelOverride?.ignoreOperations else {
            // no filtering required
            return operations
        }
        
        var filteredOperations: [OperationType: SwaggerParser.Operation] = [:]
        
        operations.forEach { (key, value) in
            if ignoreOperations.contains("*.*") {
                return
            }
            
            if ignoreOperations.contains("*.\(key.rawValue)") {
                return
            }
            
            if let identifier = value.identifier {
                if ignoreOperations.contains("\(identifier).\(key.rawValue)") {
                    return
                }
                
                if ignoreOperations.contains("\(identifier).*") {
                    return
                }
            }
            
            filteredOperations[key] = value
        }
        
        return filteredOperations
    }
    
    static func createSwaggerModel(definition: Swagger, modelOverride: ModelOverride?) -> SwaggerServiceModel {
        var model = SwaggerServiceModel()
        
        for (name, schema) in definition.definitions {
            var enclosingEntityName = name
            parseDefinitionSchemas(model: &model, enclosingEntityName: &enclosingEntityName,
                                   schema: schema, modelOverride: modelOverride)
        }
        
        for (path, pathDefinition) in definition.paths {
            let filteredOperations = filterOperations(operations: pathDefinition.operations,
                                                      modelOverride: modelOverride)
            
            // iterate through the operations
            for (type, operation) in filteredOperations {
                guard let identifier = operation.identifier else {
                    continue
                }
                
                // if there is more than one operation for this path
                let operationName: String
                if filteredOperations.count > 1 {
                    operationName = identifier + type.rawValue.startingWithUppercase
                } else {
                    operationName = identifier
                }
                
                let inputDescription =
                        OperationInputDescription(defaultInputLocation: .body)
                
                var operationDescription = OperationDescription(
                    inputDescription: inputDescription,
                    outputDescription: OperationOutputDescription())
                operationDescription.httpUrl = path
                operationDescription.httpVerb = type.rawValue.uppercased()
                
                parseOperation(description: &operationDescription,
                               operationName: operationName,
                               model: &model, operation: operation,
                               modelOverride: modelOverride)
                
                model.operationDescriptions[operationName] = operationDescription
            }
        }
        
        return model
    }
    
    static func parseOperation(description: inout OperationDescription,
                               operationName: String,
                               model: inout SwaggerServiceModel,
                               operation: SwaggerParser.Operation,
                               modelOverride: ModelOverride?) {
        let (members, bodyStructureName) = getOperationMembersAndBodyStructureName(
            operation: operation,
                            operationName: operationName,
                            model: &model,
                            modelOverride: modelOverride)
        
        setOperationInput(bodyStructureName: bodyStructureName, operationInputMembers: members,
                          description: &description, model: &model, operationName: operationName)
        
        setOperationOutput(operation: operation, operationName: operationName, model: &model,
                           modelOverride: modelOverride, description: &description)
    }
    
    static func getOperationMembersAndBodyStructureName(
            operation: SwaggerParser.Operation,
            operationName: String,
            model: inout SwaggerServiceModel,
            modelOverride: ModelOverride?) -> (members: OperationInputMembers, bodyStructureName: String?) {
        var members = OperationInputMembers()
        var bodyStructureName: String?
        
        for (index, parameter) in operation.parameters.enumerated() {
            switch parameter {
            case .a(let value):
                switch value {
                case .body(fixedFields: _, schema: let schema):
                    getBodyOperationMembers(schema, bodyStructureName: &bodyStructureName,
                                            operationName: operationName, model: &model, modelOverride: modelOverride)
                case .other(let fixedFields, let items):
                    switch fixedFields.location {
                    case .query, .path, .header:
                        getFixedFieldsOperationMembers(fixedFields: fixedFields, operationName: operationName,
                                                       index: index, members: &members, items: items,
                                                       model: &model, modelOverride: modelOverride)
                        
                    default:
                        fatalError("Location not supported")
                    }
                }
            case .b:
                fatalError("Not implemented.")
            }
        }
        
        return (members: members, bodyStructureName: bodyStructureName)
    }
    
    static func getBodyOperationMembers(_ schema: Schema, bodyStructureName: inout String?,
                                        operationName: String, model: inout SwaggerServiceModel, modelOverride: ModelOverride?) {
        switch schema.type {
        case .structure(let structure):
            bodyStructureName = structure.name
        case .object(let objectSchema):
            var enclosingEntityName = "\(operationName)RequestBody"
            var structureDescription = StructureDescription()
            parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                              model: &model, objectSchema: objectSchema, modelOverride: modelOverride)
            
            model.structureDescriptions[enclosingEntityName] = structureDescription
            
            bodyStructureName = enclosingEntityName
        default:
            fatalError("Not implemented.")
        }
    }
    
    static func ignoreRequestHeader(operationName: String, headerName: String,
                                     modelOverride: ModelOverride?) -> Bool {
        
        guard let ignoreRequestHeaders = modelOverride?.ignoreRequestHeaders else {
            // no filtering required
            return false
        }
        
        if ignoreRequestHeaders.contains("*.*") {
            return true
        }
        
        if ignoreRequestHeaders.contains("*.\(headerName)") {
            return true
        }
        
        if ignoreRequestHeaders.contains("\(operationName).\(headerName)") {
            return true
        }
        
        if ignoreRequestHeaders.contains("\(operationName).*") {
            return true
        }
        
        return false
    }
    
    static func getFixedFieldsOperationMembers(fixedFields: FixedParameterFields, operationName: String,
                                               index: Int, members: inout SwaggerServiceModel.OperationInputMembers,
                                               items: Items, model: inout SwaggerServiceModel, modelOverride: ModelOverride?) {
        let typeName = fixedFields.name.safeModelName().startingWithUppercase
        
        let fieldName = "\(operationName)Request\(typeName)"
        let member = Member(value: fieldName,
                            position: index,
                            required: fixedFields.required,
                            documentation: fixedFields.description)
        switch fixedFields.location {
        case .query:
            members.queryMembers[fixedFields.name] = member
        case .path:
            members.pathMembers[fixedFields.name] = member
        case .header:
            guard !ignoreRequestHeader(operationName: operationName, headerName: fixedFields.name, modelOverride: modelOverride) else {
                // ignore header
                return
            }
            
            members.additionalHeaderMembers[fixedFields.name] = member
        default:
            // cannot happen
            break
        }
        
        addField(type: items.type, fieldName: fieldName,
                 model: &model, modelOverride: modelOverride)
    }
    
    static func addOperationResponseFromSchema(_ schema: Schema, operationName: String, forCode code: Int, index: Int?,
                                               description: inout OperationDescription,
                                               model: inout SwaggerServiceModel, modelOverride: ModelOverride?) {
        switch schema.type {
        case .structure(let structure):
            if code >= 200 && code < 300 {
                description.output = structure.name
            } else {
                description.errors.append((type: structure.name, code: code))
                model.errorTypes.insert(structure.name)
            }
        case .oneOf(let schema):
            schema.subschemas.enumerated().forEach { entry in
                addOperationResponseFromSchema(entry.element, operationName: operationName, forCode: code,
                                               index: entry.offset, description: &description,
                                               model: &model, modelOverride: modelOverride)
            }
        case .object(let objectSchema):
            let indexString = index?.description ?? ""
            var structureName = "\(operationName)\(code)Response\(indexString)Body"
            var structureDescription = StructureDescription()
            parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &structureName,
                              model: &model, objectSchema: objectSchema, modelOverride: modelOverride)
            
            model.structureDescriptions[structureName] = structureDescription
            
            if code >= 200 && code < 300 {
                description.output = structureName
            } else {
                description.errors.append((type: structureName, code: code))
                model.errorTypes.insert(structureName)
            }
        default:
            fatalError("Not implemented.")
        }
    }
    
    static func addField(type: ItemsType, fieldName: String,
                         model: inout SwaggerServiceModel, modelOverride: ModelOverride?) {
        switch type {
        case .string(item: let item):
            addStringField(metadata: item.metadata,
                           schema: nil,
                           model: &model,
                           fieldName: fieldName,
                           modelOverride: modelOverride)
        case .number(item: let item):
            model.fieldDescriptions[fieldName] =
                Fields.double(rangeConstraint: NumericRangeConstraint<Double>(
                    minimum: item.metadata?.minimum,
                    maximum: item.metadata?.maximum,
                    exclusiveMinimum: item.metadata?.exclusiveMinimum ?? false,
                    exclusiveMaximum: item.metadata?.exclusiveMaximum ?? false))
        case .integer(item: let item):
            if item.format == IntegerFormat.int64 {
                model.fieldDescriptions[fieldName] =
                    Fields.long(rangeConstraint: NumericRangeConstraint<Int>(
                    minimum: item.metadata?.minimum,
                    maximum: item.metadata?.maximum,
                    exclusiveMinimum: item.metadata?.exclusiveMinimum ?? false,
                    exclusiveMaximum: item.metadata?.exclusiveMaximum ?? false))
            } else {
                model.fieldDescriptions[fieldName] =
                Fields.integer(rangeConstraint: NumericRangeConstraint<Int>(
                    minimum: item.metadata?.minimum,
                    maximum: item.metadata?.maximum,
                    exclusiveMinimum: item.metadata?.exclusiveMinimum ?? false,
                    exclusiveMaximum: item.metadata?.exclusiveMaximum ?? false))
            }
            
        
        case .boolean:
            model.fieldDescriptions[fieldName] = Fields.boolean
        default:
            fatalError("Field type not supported.")
        }
    }

    static func getEnumerationValues(metadata: SwaggerParser.Metadata) -> [(name: String, value: String)] {
       let enumerationValues: [(name: String, value: String)]
        if let values = metadata.enumeratedValues {
            enumerationValues = values.filter { value in value is String }
                .compactMap { value in value as? String }
                .map { value in (name: value, value: value) }
        } else {
            enumerationValues = []
        }
        
        return enumerationValues
    }

    static func addStringField(metadata: StringMetadata?,
                               schema: Schema?,
                               model: inout SwaggerServiceModel,
                               fieldName: String,
                               modelOverride: ModelOverride?) {
        let pattern: String?
        let newValueConstraints: [(name: String, value: String)]
        // if the pattern is a list of alternatives
        if modelOverride?.modelStringPatternsAreAlternativeList ?? false,
            let current = metadata?.pattern,
            let first = current.first, first == "^",
            let last = current.last, last == "$" {
                pattern = nil
                newValueConstraints =
                    current.dropFirst().dropLast().split(separator: "|").map { subString in
                        let value = String(subString)
                        return (name: value, value: value)
                }
        } else {
            pattern = nil
            if let schema = schema {
                newValueConstraints = getEnumerationValues(metadata: schema.metadata)
            } else {
                newValueConstraints = []
            }
        }
        
        model.fieldDescriptions[fieldName] = Fields.string(
            regexConstraint: pattern,
            lengthConstraint: LengthRangeConstraint<Int>(minimum: metadata?.minLength ?? nil,
                                                         maximum: metadata?.maxLength ?? nil),
            valueConstraints: newValueConstraints)
    }
}
