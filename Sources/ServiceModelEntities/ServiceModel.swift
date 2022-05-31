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
// ServiceModel.swift
// ServiceModelEntities
//

import Foundation

public enum ModelFormat {
    case yaml
    case json
    case xml
}

public enum ServiceModelError: Error {
    case notImplementedException
}

/**
 Protocol for a Service Model description.
 */
public protocol ServiceModel {
    var serviceInformation: ServiceInformation? { get }
    var serviceDescriptions: [String: ServiceDescription] { get }
    var structureDescriptions: [String: StructureDescription] { get }
    var operationDescriptions: [String: OperationDescription] { get }
    var fieldDescriptions: [String: Fields] { get }
    var errorTypes: Set<String> { get }
    var typeMappings: [String: String] { get }
    var errorCodeMappings: [String: String] { get }
    
    /**
     Initialize an instance of this ServiceModel type from a data instance
     that represents that type.
     */
    static func create(data: Data, modelFormat: ModelFormat, modelOverride: ModelOverride?) throws -> Self
    
    /**
     Initialize an instance of this ServiceModel type from a data instance
     that represents that type.
     */
    static func create(dataList: [Data], modelFormat: ModelFormat, modelOverride: ModelOverride?) throws -> Self
}

public extension ServiceModel {
    // Provide default value for backwards compatibility
    var serviceInformation: ServiceInformation? { nil }

    static func create(dataList: [Data], modelFormat: ModelFormat, modelOverride: ModelOverride?) throws -> Self {
        throw ServiceModelError.notImplementedException
    }
}
