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
// ServiceModelGenerate.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities
import SwaggerParser
import Yams

public struct ServiceModelGenerate {
    /**
     Helper function to initialize code generation from the path to a service model.
 
     - Parameters:
         - modelFilePath: the file path to the service model file. Supports either xml, json or yaml encoded models.
         - customizations: any customizations provided external to the model.
         - applicationDescription: the description of the application being code generated.
         - modelOverride: any overrides for values in the model.
         - generatorFunction: a function that will be provided a code generator and an instantiated ServiceModel
                              which can be used to generate any code that is required.
     */
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePath: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator, ModelType) throws -> ()) throws -> ModelType {
            
        let file = FileHandle(forReadingAtPath: modelFilePath)
        
        guard let data = file?.readDataToEndOfFile() else {
            fatalError("Specified model file '\(modelFilePath) doesn't exist.'")
        }
        
        let modelFormat: ModelFormat
        if modelFilePath.lowercased().hasSuffix(".yaml") || modelFilePath.lowercased().hasSuffix(".yml") {
            modelFormat = .yaml
        } else if modelFilePath.lowercased().hasSuffix(".json") {
            modelFormat = .json
        } else if modelFilePath.lowercased().hasSuffix(".xml") {
            modelFormat = .xml
        } else {
            fatalError("File path '\(modelFilePath) with unknown extension.'")
        }
        
        let model = try ModelType.create(data: data, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    /**
     Helper function to initialize code generation from the path to a service model.
 
     - Parameters:
         - modelDirectoryPath: the path to the service model files. Supports either xml, json or yaml encoded models.
         - fileExtension: the type of file extension to generate models for.
         - customizations: any customizations provided external to the model.
         - applicationDescription: the description of the application being code generated.
         - modelOverride: any overrides for values in the model.
         - generatorFunction: a function that will be provided a code generator and an instantiated ServiceModel
                              which can be used to generate any code that is required.
     */
    public static func generateFromModel<ModelType: ServiceModel>(
        modelDirectoryPath: String,
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator, ModelType) throws -> ()) throws -> ModelType {
        
        let dataList = try getDataListForModelFiles(atPath: modelDirectoryPath, fileExtension: fileExtension)
        
        let modelFormat: ModelFormat
        if fileExtension == "yaml" || fileExtension == "yml" {
            modelFormat = .yaml
        } else if fileExtension == "json" {
            modelFormat = .json
        } else if fileExtension == "xml" {
            modelFormat = .xml
        } else {
            fatalError("Unknown '\(fileExtension) extension.'")
        }
        
        let model = try ModelType.create(dataList: dataList, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    /**
     Helper function to initialize code generation from the paths to service models.
 
     - Parameters:
         - modelDirectoryPaths: the paths to the service model files. Supports either xml, json or yaml encoded models.
         - fileExtension: the type of file extension to generate models for.
         - customizations: any customizations provided external to the model.
         - applicationDescription: the description of the application being code generated.
         - modelOverride: any overrides for values in the model.
         - generatorFunction: a function that will be provided a code generator and an instantiated ServiceModel
                              which can be used to generate any code that is required.
     */
    public static func generateFromModel<ModelType: ServiceModel>(
        modelDirectoryPaths: [String],
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator, ModelType) throws -> ()) throws -> ModelType {
        
        let dataList = try modelDirectoryPaths.map { path in
            try getDataListForModelFiles(atPath: path, fileExtension: fileExtension)
        }.flatMap { $0 }
        
        let modelFormat: ModelFormat
        if fileExtension == "yaml" || fileExtension == "yml" {
            modelFormat = .yaml
        } else if fileExtension == "json" {
            modelFormat = .json
        } else if fileExtension == "xml" {
            modelFormat = .xml
        } else {
            fatalError("Unknown '\(fileExtension) extension.'")
        }
        
        let model = try ModelType.create(dataList: dataList, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    private static func getDataListForModelFiles(atPath modelDirectoryPath: String, fileExtension: String) throws -> [Data] {
        let modelFilePaths = try FileManager.default.contentsOfDirectory(atPath: modelDirectoryPath)
            
        return try modelFilePaths.flatMap { modelFileName -> [Data] in
            let modelFilePath = "\(modelDirectoryPath)/\(modelFileName)"
            
            guard modelFileName.lowercased().hasSuffix(".\(fileExtension)") else {
                var isDirectory = ObjCBool(true)
                if FileManager.default.fileExists(atPath: modelFilePath, isDirectory: &isDirectory), isDirectory.boolValue {
                    return try getDataListForModelFiles(atPath: modelFilePath, fileExtension: fileExtension)
                }
                
                return []
            }
            
            let file = FileHandle(forReadingAtPath: modelFilePath)
            
            guard let data = file?.readDataToEndOfFile() else {
                fatalError("Specified model file '\(modelFilePath) doesn't exist.'")
            }
            
            return [data]
        }
    }
}
