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
// ServiceModelCodeGenerator+validationFunctions.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

extension ServiceModelCodeGenerator {
    /**
     Generates validation for a field with length constraints.
     
     - Parameters:
        - name: the name of the field being validated.
        - fileBuilder: The FileBuilder to output to.
        - lengthConstraint: the constraints for this field.
     */
    func validateLengthRange<RangeType>(name: String, variableName: String, errorType: String, fileBuilder: FileBuilder,
                                        lengthConstraint: LengthRangeConstraint<RangeType>) {
        // if there is a minimum
        if let minimum = lengthConstraint.minimum {
            fileBuilder.appendLine("if self.count < \(minimum) {", postInc: true)
            fileBuilder.appendLine(
                "throw \(errorType).validationError(reason: \"The provided value to \(name) violated the minimum length constraint.\")")
            fileBuilder.appendLine("}", preDec: true)
        }
        
        if lengthConstraint.hasContraints {
            fileBuilder.appendEmptyLine()
        }
        
        // if there is a maximum
        if let maximum = lengthConstraint.maximum {
            fileBuilder.appendLine("if self.count > \(maximum) {", postInc: true)
            fileBuilder.appendLine(
                "throw \(errorType).validationError(reason: \"The provided value to \(name) violated the maximum length constraint.\")")
            fileBuilder.appendLine("}", preDec: true)
        }
    }

    /**
     Generates validation for a field with range constraints.
     
     - Parameters:
        - name: the name of the field being validated.
        - fileBuilder: The FileBuilder to output to.
        - rangeConstraint: the constraints for this field.
     */
    func validateNumericRange<RangeType>(name: String, variableName: String, errorType: String, fileBuilder: FileBuilder,
                                         rangeConstraint: NumericRangeConstraint<RangeType>) {
        // if there is a minimum
        if let minimum = rangeConstraint.minimum {
            let comparisonOperator = rangeConstraint.exclusiveMinimum ? "<=" : "<"
            
            fileBuilder.appendLine("if self \(comparisonOperator) \(minimum) {", postInc: true)
            fileBuilder.appendLine(
                "throw \(errorType).validationError(reason: \"The provided value to \(name) violated the minimum range constraint.\")")
            fileBuilder.appendLine("}", preDec: true)
        }
        
        if rangeConstraint.hasContraints {
            fileBuilder.appendEmptyLine()
        }
        
        // if there is a maximum
        if let maximum = rangeConstraint.maximum {
            let comparisonOperator = rangeConstraint.exclusiveMinimum ? ">=" : ">"
            fileBuilder.appendLine("if self \(comparisonOperator) \(maximum) {", postInc: true)
            fileBuilder.appendLine(
                "throw \(errorType).validationError(reason: \"The provided value to \(name) violated the maximum range constraint.\")")
            fileBuilder.appendLine("}", preDec: true)
        }
    }

    func createFieldValidation<ConstraintType>(fileBuilder: FileBuilder,
                                               name: String,
                                               isListWithInnerType: String?,
                                               rangeValidation: (String, String, String, FileBuilder, ConstraintType) -> (),
                                               regexConstraint: String?,
                                               lengthConstraint: ConstraintType) where ConstraintType: RangeConstraint {
        let typeName: String
        let extensionName: String
        let extensionDeclaration: String
        let baseName = applicationDescription.baseName
        if let isListWithInnerType = isListWithInnerType {
            typeName = isListWithInnerType.getNormalizedTypeName(forModel: model)
            extensionName = name.getNormalizedTypeName(forModel: model)
            if typeName.isBuiltinType {
                extensionDeclaration = "Array where Element == \(typeName)"
            } else {
                extensionDeclaration = "Array where Element == \(baseName)Model.\(typeName)"
            }
        } else {
            typeName = name.getNormalizedTypeName(forModel: model)
            extensionName = typeName
            extensionDeclaration = "\(baseName)Model.\(typeName)"
        }
        
        // if there are constraints
        if lengthConstraint.hasContraints || regexConstraint != nil {
            
            let variableName = getNormalizedVariableName(modelTypeName: name,
                                                       inStructure: name)
            
            fileBuilder.appendEmptyLine()
            fileBuilder.appendLine("""
                /**
                 Validation for the \(extensionName) field.
                */
                extension \(extensionDeclaration) {
                    public func validateAs\(extensionName)() throws {
                """)
            fileBuilder.incIndent()
            fileBuilder.incIndent()
            
            rangeValidation(name, variableName, validationErrorType, fileBuilder, lengthConstraint)
            
            if lengthConstraint.hasContraints && regexConstraint != nil {
                fileBuilder.appendEmptyLine()
            }
            
            // if there is a regular expression
            if let regexPattern = regexConstraint {
                let escapedPattern = regexPattern.replacingOccurrences(of: "\\", with: "\\\\")
                fileBuilder.appendLine("""
                    guard let matchingRange = self.range(of: "\(escapedPattern)", options: .regularExpression),
                        matchingRange == startIndex..<endIndex else {
                            throw \(validationErrorType).validationError(
                                reason: "The provided value to \(name) violated the regular expression constraint.")
                    }
                    """)
            }
            
            fileBuilder.appendLine("}", preDec: true)
            fileBuilder.appendLine("}", preDec: true)
        }
    }
}
