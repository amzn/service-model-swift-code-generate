// swift-tools-version:5.4
//
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

import PackageDescription

let package = Package(
    name: "ServiceModelSwiftCodeGenerate",
    platforms: [
        .macOS(.v10_15), .iOS(.v10)
    ],
    products: [
        .library(
            name: "ServiceModelCodeGeneration",
            targets: ["ServiceModelCodeGeneration"]),
        .library(
            name: "ServiceModelEntities",
            targets: ["ServiceModelEntities"]),
        .library(
            name: "ServiceModelGenerate",
            targets: ["ServiceModelGenerate"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ServiceModelCodeGeneration", dependencies: [
                .target(name: "ServiceModelEntities")
            ]
        ),
        .target(
            name: "ServiceModelEntities",
             dependencies: []
        ),
        .target(
            name: "ServiceModelGenerate", 
            dependencies: [
                .target(name: "ServiceModelEntities")
            ]
        ),
        .testTarget(
            name: "ServiceModelEntitiesTests",
            dependencies: [
                .target(name: "ServiceModelEntities")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
