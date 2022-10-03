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
// InitializerType.swift
// ServiceModelCodeGeneration
//

import Foundation

public struct InvocationTraceContextDeclaration {
    public let name: String
    public let importPackage: String?
    
    public init(name: String, importPackage: String? = nil) {
        self.name = name
        self.importPackage = importPackage
    }
}

public enum InitializerType {
    case standard
    case forGenerator
    case copyInitializer
    case genericTraceContextType
    case usesDefaultReportingType(defaultInvocationTraceContext: InvocationTraceContextDeclaration)
    case traceContextTypeFromConfig(configurationObjectName: String)
    case traceContextTypeFromOperationsClient(operationsClientName: String)
    
    public var isCopyInitializer: Bool {
        if case .copyInitializer = self {
            return true
        }
        
        return false
    }

    public var isGenerator: Bool {
        if case .forGenerator = self {
            return true
        }
        
        return false
    }
    
    public var isDefaultReportingType: Bool {
        if case .usesDefaultReportingType = self {
            return true
        }
        
        return false
    }
    
    public var isStandard: Bool {
        if case .standard = self {
            return true
        }
        
        return false
    }
}
