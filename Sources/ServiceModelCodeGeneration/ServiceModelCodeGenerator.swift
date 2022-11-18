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
// ApplicationDescription.swift
// ServiceModelCodeGeneration
//

import Foundation
import ServiceModelEntities

public protocol ModelTargetSupport {
    var modelTargetName: String { get }
}

public protocol ClientTargetSupport {
    var clientTargetName: String { get }
}

public struct ModelAndClientTargetSupport: ModelTargetSupport, ClientTargetSupport {
    public let modelTargetName: String
    public let clientTargetName: String
    
    public init(modelTargetName: String, clientTargetName: String) {
        self.modelTargetName = modelTargetName
        self.clientTargetName = clientTargetName
    }
}

/// A code generator that uses a Service Model
public struct ServiceModelCodeGenerator<ModelType: ServiceModel, TargetSupportType> {
    public let model: ModelType
    public let applicationDescription: ApplicationDescription
    public let customizations: CodeGenerationCustomizations
    public let modelOverride: ModelOverride<ModelType.OverridesType>?
    public let targetSupport: TargetSupportType
    
    /**
     Constructs the description with an application base name and suffix.
     Libraries for the application will be generated as <baseName><libraryType>
     where <libraryType> is determined by the generator.
     The application itself will be generated with the name <baseName><applicationSuffix>.
 
    - Parameters:
        - baseName: The base name for the generated libraries and executable.
        - applicationSuffix: The suffix for the generated executable.
        - baseFilePath: The file path of the generated package.
        - applicationDescription: A description of the application being created.
     */
    public init(model: ModelType,
                applicationDescription: ApplicationDescription,
                customizations: CodeGenerationCustomizations,
                modelOverride: ModelOverride<ModelType.OverridesType>?,
                targetSupport: TargetSupportType) {
        self.model = model
        self.applicationDescription = applicationDescription
        self.customizations = customizations
        self.modelOverride = modelOverride
        self.targetSupport = targetSupport
    }
}

public extension ServiceModelCodeGenerator {
    var validationErrorType: String {
        let baseName = applicationDescription.baseName
        
        switch customizations.validationErrorDeclaration {
        case .external(_, errorType: let errorType):
            return errorType
        case .internal:
            return "\(baseName)Error"
        }
    }
    
    var unrecognizedErrorType: String {
        let baseName = applicationDescription.baseName
        
        switch customizations.unrecognizedErrorDeclaration {
        case .external(_, errorType: let errorType):
            return errorType
        case .internal:
            return "\(baseName)Error"
        }
    }
}
