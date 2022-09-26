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
// ServiceModelCodeGenerator+createOutputStructureStubVariable.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

internal extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport {
    func createOutputStructureStubVariable(
            type: String,
            fileBuilder: FileBuilder,
            declarationPrefix: String,
            memberLocation: [String: LocationOutput],
            payloadAsMember: String?) {
        var outputLines: [String] = []
        let modelTargetName = self.targetSupport.modelTargetName
        
        // if there isn't actually a structure of the type, this is a fatal
        guard let structureDefinition = model.structureDescriptions[type] else {
            fatalError("No structure found of type '\(type)'")
        }
        
        // sort the members in alphabetical order for output
        let sortedMembers = structureDefinition.members.sorted { entry1, entry2 in
            return entry1.value.position < entry2.value.position
        }
        
        if sortedMembers.isEmpty {
            outputLines.append("\(declarationPrefix) \(modelTargetName).\(type)()")
        } else {
            outputLines.append("\(declarationPrefix) \(modelTargetName).\(type)(")
        }
        
        // iterate through each property
        for (index, entry) in sortedMembers.enumerated() {
            let parameterName = getNormalizedVariableName(modelTypeName: entry.key,
                                                      inStructure: type,
                                                      reservedWordsAllowed: true)
            
            let prefix = "    "
            let postfix: String
            if index == structureDefinition.members.count - 1 {
                postfix = ")"
            } else {
                postfix = ","
            }
            
            guard let location = memberLocation[entry.key] else {
                fatalError("Unknown location for member.")
            }
            
            let value: String
            switch location {
            case .body:
                if let payloadAsMember = payloadAsMember {
                    guard payloadAsMember == entry.key else {
                        fatalError("Body member \(entry.key) not part of payload")
                    }
                    
                    value = "body"
                } else {
                    value = "body.\(parameterName)"
                }
            case .headers:
                value = "headers.\(parameterName)"
            }
            
            outputLines.append("\(prefix)\(parameterName): \(value)\(postfix)")
        }
        
        // output the declaration
        if outputLines.isEmpty {
            fileBuilder.appendLine("\(declarationPrefix) \(modelTargetName).\(type)()")
        } else {
            outputLines.forEach { line in fileBuilder.appendLine(line) }
        }
    }
    
    enum LocationOutput {
        case body
        case headers
    }
}
