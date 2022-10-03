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
// ModelLocation.swift
// ServiceModelCodeGeneration
//

public enum VersionRequirementType: String, Codable {
    case from
    case branch
    case path
}

public struct ModelPackageDependency {
    public let versionRequirementType: VersionRequirementType
    public let versionRequirement: String?
    public let packageLocation: String
    
    public init (versionRequirementType: VersionRequirementType,
                 versionRequirement: String?,
                 packageLocation: String) {
        self.versionRequirementType = versionRequirementType
        self.versionRequirement = versionRequirement
        self.packageLocation = packageLocation
    }
}

public struct ModelLocation: Codable {
    public let modelProductDependency: String?
    public let modelTargetDependency: String?
    public let modelFilePath: String
    
    public init (modelFilePath: String,
                 modelProductDependency: String?,
                 modelTargetDependency: String?) {
        self.modelFilePath = modelFilePath
        self.modelProductDependency = modelProductDependency
        self.modelTargetDependency = modelTargetDependency
    }
}
