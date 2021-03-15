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
// ServiceModelCodeGenerator+addRequestInputStructure.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

public extension ServiceModelCodeGenerator {
    internal func addRequestInputStructure(generationType: ServiceModelCodeGenerator.ClientInputGenerationType,
                                           fileBuilder: FileBuilder, name: String, inputTypeName: String,
                                           httpRequestInputTypes: HTTPRequestInputTypes) {
        if case .requestInput = generationType {
            fileBuilder.appendLine("""
                
                /**
                 Type to handle the input to the \(name) operation in a HTTP client.
                 */
                public struct \(name)OperationHTTPRequestInput: HTTPRequestInputProtocol {
                    public let queryEncodable: \(httpRequestInputTypes.queryTypeName)?
                    public let pathEncodable: \(httpRequestInputTypes.pathTypeName)?
                    public let bodyEncodable: \(httpRequestInputTypes.bodyTypeName)?
                    public let additionalHeadersEncodable: \(httpRequestInputTypes.additionalHeadersTypeName)?
                    public let pathPostfix: String?
                
                    public init(encodable: \(inputTypeName)) {
                        self.queryEncodable = \(httpRequestInputTypes.queryTypeConversion)
                        self.pathEncodable = \(httpRequestInputTypes.pathTypeConversion)
                        self.bodyEncodable = \(httpRequestInputTypes.bodyTypeConversion)
                        self.additionalHeadersEncodable = \(httpRequestInputTypes.additionalHeadersTypeConversion)
                        self.pathPostfix = \(httpRequestInputTypes.pathTemplateConversion)
                    }
                }
                """)
        }
    }
}
