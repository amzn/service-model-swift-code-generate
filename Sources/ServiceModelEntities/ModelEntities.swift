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
// ModelEntities.swift
// ServiceModelEntities
//

import Foundation

/**
 Description of a service in the model.
 */
public struct ServiceDescription {
    public var operations: [String] = []
    
    public init(operations: [String] = []) {
        self.operations = operations
    }
}

public enum DefaultInputLocation: String, Codable {
    case query = "Query"
    case body = "Body"
}

public struct OperationInputDescription: Codable, Equatable {
    /// the list of fields to be taken from the input path.
    public let pathFields: [String]
    /// the list of fields to be taken from the input query string.
    public let queryFields: [String]
    /// the list of fields to be taken from the input body.
    public let bodyFields: [String]
    /// the tokenized template the path should conform to.
    public let pathTemplateField: String?
    /// the list of fields to be taken from the input request headers.
    public let additionalHeaderFields: [String]
    /// the location of any fields not specified as coming from a specific input location.
    public let defaultInputLocation: DefaultInputLocation
    /// the name of the structure to be used as the body.
    public let bodyStructureName: String?
    /// if the input payload is represented by one of the input type's members.
    public let payloadAsMember: String?
    
    public init(pathFields: [String] = [],
                queryFields: [String] = [],
                bodyFields: [String] = [],
                pathTemplateField: String? = nil,
                additionalHeaderFields: [String] = [],
                defaultInputLocation: DefaultInputLocation,
                bodyStructureName: String? = nil,
                payloadAsMember: String? = nil) {
        self.pathFields = pathFields
        self.queryFields = queryFields
        self.bodyFields = bodyFields
        self.pathTemplateField = pathTemplateField
        self.additionalHeaderFields = additionalHeaderFields
        self.defaultInputLocation = defaultInputLocation
        self.bodyStructureName = bodyStructureName
        self.payloadAsMember = payloadAsMember
    }
    
    public var onlyHasDefaultLocation: Bool {
        return pathFields.isEmpty && queryFields.isEmpty && bodyFields.isEmpty
            && pathTemplateField == nil && additionalHeaderFields.isEmpty
    }
}

public struct OperationOutputDescription: Codable, Equatable {
    /// the list of fields to be encoded as the output's body.
    public let bodyFields: [String]
    /// the list of fields to be encoded as the output's response headers.
    public let headerFields: [String]
    /// the name of the structure to be used as the body.
    public let bodyStructureName: String?
    /// if the output payload is represented by one of the output type's members.
    public let payloadAsMember: String?
    
    public init(bodyFields: [String] = [],
                headerFields: [String] = [],
                bodyStructureName: String? = nil,
                payloadAsMember: String? = nil) {
        self.bodyFields = bodyFields
        self.headerFields = headerFields
        self.bodyStructureName = bodyStructureName
        self.payloadAsMember = payloadAsMember
    }
}

/**
 A description of an operation in the model.
 */
public struct OperationDescription {
    public var input: String?
    public var output: String?
    public var httpVerb: String?
    public var httpUrl: String?
    public var errors: [(type: String, code: Int)]
    public var documentation: String?
    public var inputDescription: OperationInputDescription
    public var outputDescription: OperationOutputDescription
    
    public init(input: String? = nil,
                output: String? = nil,
                httpVerb: String? = nil,
                httpUrl: String? = nil,
                errors: [(type: String, code: Int)] = [],
                documentation: String? = nil,
                inputDescription: OperationInputDescription,
                outputDescription: OperationOutputDescription) {
        self.input = input
        self.output = output
        self.httpVerb = httpVerb
        self.httpUrl = httpUrl
        self.errors = errors
        self.inputDescription = inputDescription
        self.outputDescription = outputDescription
    }
}

/**
 Protocol that represents a constaint on the range of values a property can have.
 */
public protocol RangeConstraint {
    /// If this constraint has constraints on the range
    var hasContraints: Bool { get }
}

/**
 Representation of a potentially half or fully open value length range.
 */
public struct LengthRangeConstraint<LimitType> {
    public let minimum: LimitType?
    public let maximum: LimitType?
    
    public init(minimum: LimitType? = nil,
                maximum: LimitType? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

extension LengthRangeConstraint: RangeConstraint {
    public var hasContraints: Bool {
        return minimum != nil || maximum != nil
    }
}

/**
 Representation of a potentially half or fully open value numeric range.
 */
public struct NumericRangeConstraint<LimitType> {
    public let minimum: LimitType?
    public let maximum: LimitType?
    public let exclusiveMinimum: Bool
    public let exclusiveMaximum: Bool
    
    public init(minimum: LimitType? = nil,
                maximum: LimitType? = nil,
                exclusiveMinimum: Bool = false,
                exclusiveMaximum: Bool = false) {
        self.minimum = minimum
        self.maximum = maximum
        self.exclusiveMinimum = exclusiveMinimum
        self.exclusiveMaximum = exclusiveMaximum
    }
}

extension NumericRangeConstraint: RangeConstraint {
    public var hasContraints: Bool {
        return minimum != nil || maximum != nil
    }
}

/**
 A member of a structure.
 */
public struct Member {
    public let value: String
    public let position: Int
    public let locationName: String?
    public var required: Bool
    public var documentation: String?
    
    public init(value: String, position: Int, locationName: String? = nil,
                required: Bool, documentation: String?) {
        self.value = value
        self.position = position
        self.locationName = locationName
        self.required = required
        self.documentation = documentation
    }
}

/**
 A description of an structure in the model.
 */
public struct StructureDescription {
    public var members: [String: Member]
    public var documentation: String?
    
    public init(members: [String: Member] = [:], documentation: String? = nil) {
        self.members = members
        self.documentation = documentation
    }
}

/**
 The possible type of fields in the model.
 */
public enum Fields {
    case string(regexConstraint: String?,
        lengthConstraint: LengthRangeConstraint<Int>,
        valueConstraints: [(name: String, value: String)])
    case integer(rangeConstraint: NumericRangeConstraint<Int>)
    case boolean
    case double(rangeConstraint: NumericRangeConstraint<Double>)
    case long(rangeConstraint: NumericRangeConstraint<Int>)
    case timestamp
    case list(type: String, lengthConstraint: LengthRangeConstraint<Int>)
    case map(keyType: String, valueType: String,
             lengthConstraint: LengthRangeConstraint<Int>)
    case data
}

extension Fields {
    public var typeDescription: String {
        switch self {
        case .string:
            return "String"
        case .integer:
            return "Integer"
        case .boolean:
            return "Boolean"
        case .double:
            return "Double"
        case .long:
            return "Long"
        case .timestamp:
            return "Timestamp"
        case .list:
            return "List"
        case .map:
            return "Map"
        case .data:
            return "Data"
        }
    }
}

extension String {
    public var isBuiltinType: Bool {
        switch self {
        case "String", "Integer", "Boolean", "Double", "Long", "Timestamp", "Data":
            return true
        default:
            return false
        }
    }
}
