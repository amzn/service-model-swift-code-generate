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

/**
 A description of the application being generated from the Service Model.
 */
public struct ApplicationDescription {
    /// The base of the application name that will be used to construct
    /// libraries within the target package such as \(baseName)Model.
    public let baseName: String
    /// The file path where the application should be generated.
    public let baseFilePath: String
    /// A description of the application being generated.
    public let applicationDescription: String
    /// Appended onto the base name to create the full application name.
    public let applicationSuffix: String
    
    public init(baseName: String, baseFilePath: String,
                applicationDescription: String, applicationSuffix: String) {
        self.baseName = baseName
        self.baseFilePath = baseFilePath
        self.applicationDescription = applicationDescription
        self.applicationSuffix = applicationSuffix
    }
}
