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

public struct ServiceModelGenerate {
    private static func getModelDataForFilePath(modelFilePath: String) -> (data: Data, modelFormat: ModelFormat) {
        let file = FileHandle(forReadingAtPath: modelFilePath)
        
        guard let data = file?.readDataToEndOfFile() else {
            fatalError("Specified model file '\(modelFilePath) doesn't exist.'")
        }
        
        if let index = modelFilePath.lastIndex(of: ".") {
            let extensionStartIndex = modelFilePath.index(after: index)
            let fileExtension = String(modelFilePath[extensionStartIndex...])
            
            if let modelFormat = getModelFormat(fromFileExtension: fileExtension) {
                return (data, modelFormat)
            }
        }
        
        fatalError("File path '\(modelFilePath) with unknown extension.'")
    }
    
    private static func getModelFormat(fromFileExtension fileExtension: String) -> ModelFormat? {
        let lowercasedFileExtension = fileExtension.lowercased()
        if lowercasedFileExtension == "yaml" || lowercasedFileExtension == "yml" {
            return .yaml
        } else if lowercasedFileExtension == "json" {
            return .json
        } else if lowercasedFileExtension == "xml" {
            return .xml
        } else {
            return nil
        }
    }
    
    private static func getKnownModelFormat(fromFileExtension fileExtension: String) -> ModelFormat {
        if let modelFormat = getModelFormat(fromFileExtension: fileExtension) {
            return modelFormat
        } else {
            fatalError("Unknown '\(fileExtension) extension.'")
        }
    }
    
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
    public static func generateFromModel<ModelType: ServiceModel, TargetSupportType>(
        modelFilePath: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        targetSupport: TargetSupportType,
        generatorFunction: (ServiceModelCodeGenerator<TargetSupportType>, ModelType) throws -> ()) throws
    -> ModelType {
        let (data, modelFormat) = getModelDataForFilePath(modelFilePath: modelFilePath)
        
        let model = try ModelType.create(data: data, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride,
            targetSupport: targetSupport)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePath: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator<ModelAndClientTargetSupport>, ModelType) throws -> ()) throws
    -> ModelType {
        return try generateFromModel(modelFilePath: modelFilePath,
                                     customizations: customizations,
                                     applicationDescription: applicationDescription,
                                     modelOverride: modelOverride,
                                     targetSupport: applicationDescription.defaultTargetSupport,
                                     generatorFunction: generatorFunction)
    }
    
    /**
     Helper function to initialize code generation from the path to a service model.
 
     - Parameters:
         - modelFilePaths: the file paths to the service model files. Supports either xml, json or yaml encoded models. All files must be a consistent format.
         - customizations: any customizations provided external to the model.
         - applicationDescription: the description of the application being code generated.
         - modelOverride: any overrides for values in the model.
         - generatorFunction: a function that will be provided a code generator and an instantiated ServiceModel
                              which can be used to generate any code that is required.
     */
    public static func generateFromModel<ModelType: ServiceModel, TargetSupportType>(
        modelFilePaths: [String],
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        targetSupport: TargetSupportType,
        generatorFunction: (ServiceModelCodeGenerator<TargetSupportType>, ModelType) throws -> ()) throws
    -> ModelType {
        var modelFormat: ModelFormat?
        let dataList: [Data] = modelFilePaths.map { modelFilePath in
            let (data, thisModelFormat) = getModelDataForFilePath(modelFilePath: modelFilePath)
            
            if let modelFormat = modelFormat, thisModelFormat != modelFormat {
                fatalError("Multiple model files provided of different format: '\(thisModelFormat)' and '\(modelFormat)'")
            }
            modelFormat = thisModelFormat
            
            return data
        }
        
        guard let modelFormat = modelFormat else {
            fatalError("At least one model file needs to be provided.")
        }
        
        let model = try ModelType.create(dataList: dataList, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride,
            targetSupport: targetSupport)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePaths: [String],
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator<ModelAndClientTargetSupport>, ModelType) throws -> ()) throws
    -> ModelType {
        return try generateFromModel(modelFilePaths: modelFilePaths,
                                     customizations: customizations,
                                     applicationDescription: applicationDescription,
                                     modelOverride: modelOverride,
                                     targetSupport: applicationDescription.defaultTargetSupport,
                                     generatorFunction: generatorFunction)
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
    public static func generateFromModel<ModelType: ServiceModel, TargetSupportType>(
        modelDirectoryPath: String,
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        targetSupport: TargetSupportType,
        generatorFunction: (ServiceModelCodeGenerator<TargetSupportType>, ModelType) throws -> ()) throws
    -> ModelType {
        let dataList = try getDataListForModelFiles(atPath: modelDirectoryPath, fileExtension: fileExtension)
        
        let modelFormat = getKnownModelFormat(fromFileExtension: fileExtension)
        
        let model = try ModelType.create(dataList: dataList, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride,
            targetSupport: targetSupport)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelDirectoryPath: String,
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator<ModelAndClientTargetSupport>, ModelType) throws -> ()) throws
    -> ModelType {
        return try generateFromModel(modelDirectoryPath: modelDirectoryPath,
                                     fileExtension: fileExtension,
                                     customizations: customizations,
                                     applicationDescription: applicationDescription,
                                     modelOverride: modelOverride,
                                     targetSupport: applicationDescription.defaultTargetSupport,
                                     generatorFunction: generatorFunction)
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
    public static func generateFromModel<ModelType: ServiceModel, TargetSupportType>(
        modelDirectoryPaths: [String],
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        targetSupport: TargetSupportType,
        generatorFunction: (ServiceModelCodeGenerator<TargetSupportType>, ModelType) throws -> ()) throws
    -> ModelType {
        let dataList = try modelDirectoryPaths.map { path in
            try getDataListForModelFiles(atPath: path, fileExtension: fileExtension)
        }.flatMap { $0 }
        
        let modelFormat = getKnownModelFormat(fromFileExtension: fileExtension)
        
        let model = try ModelType.create(dataList: dataList, modelFormat: modelFormat, modelOverride: modelOverride)
        
        let codeGenerator = ServiceModelCodeGenerator(
            model: model,
            applicationDescription: applicationDescription,
            customizations: customizations,
            modelOverride: modelOverride,
            targetSupport: targetSupport)
        
        try generatorFunction(codeGenerator, model)
        
        return model
    }
    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelDirectoryPaths: [String],
        fileExtension: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        generatorFunction: (ServiceModelCodeGenerator<ModelAndClientTargetSupport>, ModelType) throws -> ()) throws
    -> ModelType {
        return try generateFromModel(modelDirectoryPaths: modelDirectoryPaths,
                                     fileExtension: fileExtension,
                                     customizations: customizations,
                                     applicationDescription: applicationDescription,
                                     modelOverride: modelOverride,
                                     targetSupport: applicationDescription.defaultTargetSupport,
                                     generatorFunction: generatorFunction)
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

private extension ApplicationDescription {
    var defaultTargetSupport: ModelAndClientTargetSupport {
        return ModelAndClientTargetSupport(modelTargetName: "\(self.baseName)Model",
                                           clientTargetName: "\(self.baseName)Client")
    }
}
