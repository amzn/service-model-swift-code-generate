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
// CreateOpenAPIServiceModel.swift
// OpenAPIServiceModel
//

import Foundation
import OpenAPIKit30
import ServiceModelEntities
import ServiceModelCodeGeneration
import Yams

let nonErrorCodeRange = 200...299

internal extension OpenAPIServiceModel {
    struct OperationInputMembers {
        var queryMembers: [String: Member] = [:]
        var additionalHeaderMembers: [String: Member] = [:]
        var pathMembers: [String: Member] = [:]
    }
    
    static func filterOperations(operations: [OpenAPI.HttpMethod: OpenAPI.Operation],
                                 modelOverride: ModelOverride?) -> [OpenAPI.HttpMethod: OpenAPI.Operation] {
        
        guard let ignoreOperations = modelOverride?.ignoreOperations else {
            return operations
        }
        
        var filteredOperations: [OpenAPI.HttpMethod: OpenAPI.Operation] = [:]
        
        operations.forEach { (key, value) in
            if ignoreOperations.contains("*.*") {
                return
            }
            
            if ignoreOperations.contains("*.\(key.rawValue)") {
                return
            }
            
            if let identifier = value.operationId {
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
    
    static func createOpenAPIModel(definition: OpenAPI.Document, modelOverride: ModelOverride?) -> OpenAPIServiceModel {
        var model = OpenAPIServiceModel()

        model.serviceInformation = ServiceInformation(
            title: definition.info.title,
            description: definition.info.description,
            version: definition.info.version)

        for (name, schema) in definition.components.schemas {
            var enclosingEntityName = name.rawValue
            parseDefinitionSchemas(model: &model, enclosingEntityName: &enclosingEntityName,
                                   schema: schema, modelOverride: modelOverride, document: definition)
        }
        
        for (path, pathDefinition) in definition.paths {
            var operations:[OpenAPI.HttpMethod: OpenAPI.Operation] = [:]
            
            pathDefinition.endpoints.forEach { endpoint in
                operations[endpoint.method] = endpoint.operation
            }
            
            let filteredOperations = filterOperations(operations: operations,
                                                      modelOverride: modelOverride)
            
            for (type, operation) in filteredOperations {
                guard let operationId = operation.operationId else {
                    continue
                }
                
                // if there is more than one operation for this path
                let operationName: String
                if filteredOperations.count > 1 {
                    operationName = operationId + type.rawValue.lowercased().startingWithUppercase
                } else {
                    operationName = operationId
                }
                
                let inputDescription =
                        OperationInputDescription(defaultInputLocation: .body)
                
                var operationDescription = OperationDescription(
                    inputDescription: inputDescription,
                    outputDescription: OperationOutputDescription())
                operationDescription.httpUrl = path.rawValue
                operationDescription.httpVerb = type.rawValue.uppercased()
                
                parseOperation(description: &operationDescription,
                               operationName: operationName,
                               model: &model, operation: operation,
                               modelOverride: modelOverride, document: definition)
                
                model.operationDescriptions[operationName] = operationDescription
            }
        }
        
        return model
    }
    
    static func parseOperation(description: inout OperationDescription,
                               operationName: String,
                               model: inout OpenAPIServiceModel,
                               operation: OpenAPI.Operation,
                               modelOverride: ModelOverride?,
                               document: OpenAPI.Document) {
        let (members, bodyStructureName) = getOperationMembersAndBodyStructureName(
            operation: operation,
                            operationName: operationName,
                            model: &model,
                            modelOverride: modelOverride, document: document)
        
        setOperationInput(bodyStructureName: bodyStructureName, operationInputMembers: members,
                          description: &description, model: &model, operationName: operationName)
        
        setOperationOutput(operation: operation, operationName: operationName, model: &model,
                           modelOverride: modelOverride, description: &description, document: document)
    }
    
    static func getOperationMembersAndBodyStructureName(
            operation: OpenAPI.Operation,
            operationName: String,
            model: inout OpenAPIServiceModel,
            modelOverride: ModelOverride?, document: OpenAPI.Document) -> (members: OperationInputMembers, bodyStructureName: String?) {
        var members = OperationInputMembers()
        var bodyStructureName: String?
        
        if let requestBody = operation.requestBody {
            switch requestBody {
            case .a:
                fatalError("Unsupported request body reference.")
            case .b(let request):
                getBodyOperationMembers(request, bodyStructureName: &bodyStructureName,
                                        operationName: operationName, model: &model, modelOverride: modelOverride, document: document)
            }
        }
        
        for (index, parameter) in operation.parameters.enumerated() {
            switch parameter {
            case .b(let parameterValue):
                if let schemaValue = parameterValue.schemaOrContent.schemaValue {
                    getFixedFieldsOperationMembers(fixedFields: parameterValue, operationName: operationName,
                                                    index: index, members: &members, items: schemaValue,
                                                    model: &model, modelOverride: modelOverride)
                }
            case .a(_):
                fatalError("Not implemented.")
            }
        }
        
        return (members: members, bodyStructureName: bodyStructureName)
    }
    
    static func getBodyOperationMembers(_ request: OpenAPI.Request, bodyStructureName: inout String?,
                                        operationName: String, model: inout OpenAPIServiceModel,
                                        modelOverride: ModelOverride?, document: OpenAPI.Document) {
        for (_, content) in request.content {
            if let either = content.schema {
                switch either {
                case .a(let reference):
                    if let refName = reference.name {
                        bodyStructureName = refName
                    }
                case .b(let schema):
                    switch schema.value {
                    case .object:
                        var enclosingEntityName = "\(operationName)RequestBody"
                        var structureDescription = StructureDescription()
                        guard let objectContext = schema.objectContext else {
                           continue
                        }
                        parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &enclosingEntityName,
                                          model: &model, objectContext: objectContext, modelOverride: modelOverride, document: document)
                        
                        model.structureDescriptions[enclosingEntityName] = structureDescription
                        
                        bodyStructureName = enclosingEntityName
                    default:
                        // The schemas object and reference are most widely used in the requestBody field
                        fatalError("Not implemented.")
                    }
                }
            }
        }
    }
    
    static func ignoreRequestHeader(operationName: String, headerName: String,
                                     modelOverride: ModelOverride?) -> Bool {
        
        guard let ignoreRequestHeaders = modelOverride?.ignoreRequestHeaders else {
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
    
    static func getFixedFieldsOperationMembers(fixedFields: OpenAPI.Parameter, operationName: String,
                                               index: Int, members: inout OpenAPIServiceModel.OperationInputMembers,
                                               items: JSONSchema, model: inout OpenAPIServiceModel, modelOverride: ModelOverride?) {
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
                return
            }
            
            members.additionalHeaderMembers[fixedFields.name] = member
        default:
            break
        }
        
        addField(item: items, fieldName: fieldName,
                 model: &model, modelOverride: modelOverride)
    }
    
    static func addOperationResponseFromSchema(schema: JSONSchema, operationName: String, forCode code: Int, index: Int?,
                                               description: inout OperationDescription,
                                               model: inout OpenAPIServiceModel, modelOverride: ModelOverride?, document: OpenAPI.Document) {
        switch schema.value {
        case .one(let subschemas, _):
            for (index, subschema) in subschemas.enumerated() {
                switch subschema.value {
                case .reference(let ref, _):
                    addOperationResponseFromReference(reference: ref, operationName: operationName, forCode: code,
                                                      index: index, description: &description,
                                                      model: &model, modelOverride: modelOverride)
                default:
                    addOperationResponseFromSchema(schema: subschema, operationName: operationName, forCode: code,
                                                   index: index, description: &description,
                                                   model: &model, modelOverride: modelOverride, document: document)
                }
            }
        case .object:
            let indexString = index?.description ?? ""
            var structureName = "\(operationName)\(code)Response\(indexString)Body"
            var structureDescription = StructureDescription()
            
            if let objectContext = schema.objectContext {
                parseObjectSchema(structureDescription: &structureDescription, enclosingEntityName: &structureName,
                                  model: &model, objectContext: objectContext, modelOverride: modelOverride, document: document)
                
                model.structureDescriptions[structureName] = structureDescription
                
                if nonErrorCodeRange.contains(code)  {
                    description.output = structureName
                } else {
                    description.errors.append((type: structureName, code: code))
                    model.errorTypes.insert(structureName)
                }
            }
        default:
            fatalError("Not implemented.")
        }
    }
    
    static func addOperationResponseFromReference(reference: JSONReference<JSONSchema>, operationName: String, forCode code: Int,
                                                  index: Int?, description: inout OperationDescription,
                                                  model: inout OpenAPIServiceModel, modelOverride: ModelOverride?) {
        if let refName = reference.name {
            if nonErrorCodeRange.contains(code) {
                description.output = refName
            } else {
                description.errors.append((type: refName, code: code))
                model.errorTypes.insert(refName)
            }
        }
    }
    
    static func addField(item: JSONSchema, fieldName: String,
                         model: inout OpenAPIServiceModel, modelOverride: ModelOverride?) {
        switch item.value {
        case .string(_, let context):
            addStringField(metadata: context,
                           schema: nil,
                           model: &model,
                           fieldName: fieldName,
                           modelOverride: modelOverride)
        case .number(_, let context):
            model.fieldDescriptions[fieldName] =
                Fields.double(rangeConstraint: NumericRangeConstraint<Double>(
                    minimum: context.minimum?.value,
                    maximum: context.maximum?.value,
                    exclusiveMinimum: context.minimum?.exclusive ?? false,
                    exclusiveMaximum: context.maximum?.exclusive ?? false))
        case .integer(let integerFormat, let context):
            if integerFormat.format ==  .int64 {
                model.fieldDescriptions[fieldName] =
                    Fields.long(rangeConstraint: NumericRangeConstraint<Int>(
                    minimum: context.minimum?.value,
                    maximum: context.maximum?.value,
                    exclusiveMinimum: context.minimum?.exclusive ?? false,
                    exclusiveMaximum: context.maximum?.exclusive ?? false))
            } else {
                model.fieldDescriptions[fieldName] =
                Fields.integer(rangeConstraint: NumericRangeConstraint<Int>(
                    minimum: context.minimum?.value,
                    maximum: context.maximum?.value,
                    exclusiveMinimum: context.minimum?.exclusive ?? false,
                    exclusiveMaximum: context.maximum?.exclusive ?? false))
            }
            
        
        case .boolean:
            model.fieldDescriptions[fieldName] = Fields.boolean
        default:
            fatalError("Field type not supported.")
        }
    }

    static func getEnumerationValues(metadata: JSONSchemaContext) -> [(name: String, value: String)] {
       let enumerationValues: [(name: String, value: String)]
        if let allowedValues = metadata.allowedValues {
            enumerationValues = allowedValues.filter { allowedValue in allowedValue.value is String }
                .compactMap { allowedValue in allowedValue.value as? String }
                .map { value in (name: value, value: value) }
        } else {
            enumerationValues = []
        }
        
        return enumerationValues
    }

    static func addStringField(metadata: JSONSchema.StringContext?,
                               schema: JSONSchema?,
                               model: inout OpenAPIServiceModel,
                               fieldName: String,
                               modelOverride: ModelOverride?) {
        let newValueConstraints: [(name: String, value: String)]

        if modelOverride?.modelStringPatternsAreAlternativeList ?? false,
            let regexExpression = metadata?.pattern,
            regexExpression.first == "^",
            regexExpression.last == "$" {
                newValueConstraints =
                    regexExpression.dropFirst().dropLast().split(separator: "|").map { subString in
                        let value = String(subString)
                        return (name: value, value: value)
                    }
        } else {
            if let coreContext = schema?.coreContext {
                newValueConstraints = getEnumerationValues(metadata: coreContext)
            } else {
                newValueConstraints = []
            }
        }
        
        // If minLength is 0, the field is optional and does not require validation
        if metadata?.minLength == 0 {
            model.fieldDescriptions[fieldName] = Fields.string(
                regexConstraint: nil,
                lengthConstraint: LengthRangeConstraint<Int>(minimum: nil,
                                                            maximum: metadata?.maxLength ?? nil),
                valueConstraints: newValueConstraints)
        } else {
            model.fieldDescriptions[fieldName] = Fields.string(
                regexConstraint: nil,
                lengthConstraint: LengthRangeConstraint<Int>(minimum: metadata?.minLength ?? nil,
                                                            maximum: metadata?.maxLength ?? nil),
                valueConstraints: newValueConstraints)
        }
    }
}
