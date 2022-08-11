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
// String+nameConversions.swift
// ServiceModelEntities
//

import Foundation

private let reservedWords: Set<String> = ["in", "protocol", "return", "default", "public", "self",
                                          "static", "private", "internal", "do", "is", "as", "true", "false", "import"]

public extension String {
    /**
     This string starting with an uppercase.
     */
    var startingWithUppercase: String {
        return self.prefix(1).uppercased() + self.dropFirst()
    }
    
    /**
     The normalized name for a type; either a specified type mapping
     from the provided service model or this string startingWithUppercase.
     */
    func getNormalizedTypeName(forModel model: ServiceModel) -> String {
        // if there is a mapping for this name
        if let mappedName = model.typeMappings[self] {
            return mappedName
        }
        
        return self.startingWithUppercase
    }
    
    func safeModelName(replacement: String = "",
                       wildCardReplacement: String = "Star") -> String {
        let modifiedModelTypeName = self
            .replacingOccurrences(of: "-", with: replacement)
            .replacingOccurrences(of: ".", with: replacement)
            .replacingOccurrences(of: " ", with: replacement)
            .replacingOccurrences(of: "/", with: replacement)
            .replacingOccurrences(of: "(", with: replacement)
            .replacingOccurrences(of: ")", with: replacement)
            .replacingOccurrences(of: ":", with: replacement)
            .replacingOccurrences(of: "*", with: "\(replacement)\(wildCardReplacement)")
        
        return modifiedModelTypeName
    }
    
    /**
     This string converted from upper to lower camel case.
     */
    var upperToLowerCamelCase: String {
        return self.prefix(1).lowercased() + self.dropFirst()
    }
    
    /**
     This string converted from lower to upper camel case.
     */
    var lowerToUpperCamelCase: String {
        return self.prefix(1).uppercased() + self.dropFirst()
    }
    
    /**
     The normalized error name; converted from upper to lower camel case
     and any error suffix removed.
     */
    var normalizedErrorName: String {
        let normalizedName = self.upperToLowerCamelCase
        
        // drop any error|fault|exception suffix
        if normalizedName.hasSuffix("Error") {
            return String(normalizedName.dropLast("Error".count))
        } else if normalizedName.hasSuffix("Fault") {
            return String(normalizedName.dropLast("Fault".count))
        } else if normalizedName.hasSuffix("Exception") {
            return String(normalizedName.dropLast("Exception".count))
        }
        
        return normalizedName
    }
    
    func escapeReservedWords() -> String {
        if reservedWords.contains(self) {
            return "`\(self)`"
        }
        
        return self
    }
}
