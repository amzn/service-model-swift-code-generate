<p align="center">
<a href="https://github.com/amzn/service-model-swift-code-generate/actions">
<img src="https://github.com/amzn/service-model-swift-code-generate/actions/workflows/swift.yml/badge.svg?branch=main" alt="Build - main Branch">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.4|5.5|5.6-orange.svg?style=flat" alt="Swift 5.4, 5.5 and 5.6 Tested">
</a>
<a href="https://gitter.im/SmokeServerSide">
<img src="https://img.shields.io/badge/chat-on%20gitter-ee115e.svg?style=flat" alt="Join the Smoke Server Side community on gitter">
</a>
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>

# ServiceModelSwiftCodeGenerate

ServiceModelSwiftCodeGenerate is a foundational code generation library that can be used
to generate code based on different service models. This library can be integrated into
higher level code generation applications and provides some standard generation functions that can
be called.

# Getting Started

## Step 1: Add the ServiceModelSwiftCodeGenerate dependency

ServiceModelSwiftCodeGenerate uses the Swift Package Manager. To use the framework, add the following dependency
to your Package.swift-

```swift
dependencies: [
    .package(url: "https://github.com/amzn/service-model-swift-code-generate.git", .upToNextMajor(from: "0.1.0"))
]
```

## Step 2: Use the library to generate code

The easiest way to integrate ServiceModelSwiftCodeGenerate into a higher level code generation application is to use
`ServiceModelGenerate.generateFromModel`. This function takes a file path to a xml, json or yaml encoded service model,
will attempt to parse that file into the required service model type and will then pass that model and a `ServiceModelCodeGenerator`
to the provided function which can call any required generation functions.

```swift
extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport & ClientTargetSupport {
    
    func generateFromModel<ModelType: ServiceModel>(serviceModel: ModelType,
                                                    ...) throws {
        let myClientDelegate = ...
        let myModelErrorsDelegate = ...

        generateClient(delegate: myClientDelegate)
        generateModelOperationsEnum()
        generateOperationsReporting()
        generateModelOperationClientInput()
        generateModelOperationClientOutput()
        generateModelOperationHTTPInput()
        generateModelOperationHTTPOutput()
        generateModelStructures()
        generateModelTypes()
        generateModelErrors(delegate: myModelErrorsDelegate)
        generateDefaultInstances(generationType: .internalTypes)

        // Call any custom generation functions as required
    }
}

public struct MyCodeGeneration {    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePath: String,
        modelType: ModelType.Type,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        ...) throws 
    -> ModelType {
        return try ServiceModelGenerate.generateFromModel(
            modelFilePath: modelFilePath,
            customizations: customizations,
            applicationDescription: applicationDescription,
            modelOverride: modelOverride) { (codeGenerator, serviceModel) in
                try codeGenerator.generateFromModel(serviceModel: serviceModel, ...)
        }
    }
}
```

By default, the code generator will use `\(applicationDescription.baseName)Model` for the name of the model target and 
`\(applicationDescription.baseName)Client` for the name of the client target. You can override these defaults by using
the `ModelAndClientTargetSupport` type.
  
```
public struct MyCodeGeneration {
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePath: String,
        modelType: ModelType.Type,
        modelTargetName: String, clientTargetName: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        ...) throws 
    -> ModelType {
        let targetSupport = ModelAndClientTargetSupport(modelTargetName: modelTargetName,
                                                        clientTargetName: clientTargetName)
                                                        
        return try ServiceModelGenerate.generateFromModel(
            modelFilePath: modelFilePath,
            customizations: customizations,
            applicationDescription: applicationDescription,
            targetSupport: targetSupport,
            modelOverride: modelOverride) { (codeGenerator, serviceModel) in
                try codeGenerator.generateFromModel(serviceModel: serviceModel, ...)
        }
    }
}
```

Further, if you are generating additional targets, you can use a custom type that provides the name of
additional targets. This type will have to conform to the `ModelTargetSupport` and `ClientTargetSupport` protocols.

```swift
extension ServiceModelCodeGenerator where TargetSupportType: ModelTargetSupport & ClientTargetSupport & MyCustomTargetSupport {
    
    func generateFromModel<ModelType: ServiceModel>(serviceModel: ModelType,
                                                    ...) throws {
        let myClientDelegate = ...
        let myModelErrorsDelegate = ...

        generateClient(delegate: myClientDelegate)
        generateModelOperationsEnum()
        generateOperationsReporting()
        generateModelOperationClientInput()
        generateModelOperationClientOutput()
        generateModelOperationHTTPInput()
        generateModelOperationHTTPOutput()
        generateModelStructures()
        generateModelTypes()
        generateModelErrors(delegate: myModelErrorsDelegate)
        generateDefaultInstances(generationType: .internalTypes)

        // Call any custom generation functions as required
        // The `targetSupport` attribute will conform to the `MyCustomTargetSupport` protocol.
    }
}

public protocol MyCustomTargetSupport {
    var myCustomTargetName: String { get }
}

public struct MyTargetSupport: ModelTargetSupport, ClientTargetSupport, MyCustomTargetSupport {
    public let modelTargetName: String
    public let clientTargetName: String
    public let myCustomTargetName: String
    
    public init(modelTargetName: String, clientTargetName: String,
                    myCustomTargetName: String) {
        self.modelTargetName = modelTargetName
        self.clientTargetName = clientTargetName
        self.myCustomTargetName = myCustomTargetName
    }
}

public struct MyCodeGeneration {    
    public static func generateFromModel<ModelType: ServiceModel>(
        modelFilePath: String,
        modelType: ModelType.Type,
        modelTargetName: String, clientTargetName: String,
        myCustomTargetName: String,
        customizations: CodeGenerationCustomizations,
        applicationDescription: ApplicationDescription,
        modelOverride: ModelOverride?,
        ...) throws 
    -> ModelType {
        let targetSupport = MyTargetSupport(modelTargetName: modelTargetName,
                                            clientTargetName: clientTargetName,
                                            myCustomTargetName: myCustomTargetName)
                                                        
        return try ServiceModelGenerate.generateFromModel(
            modelFilePath: modelFilePath,
            customizations: customizations,
            applicationDescription: applicationDescription,
            targetSupport: targetSupport,
            modelOverride: modelOverride) { (codeGenerator, serviceModel) in
                try codeGenerator.generateFromModel(serviceModel: serviceModel, ...)
        }
    }
}
```

# Further Concepts

## The ServiceModel Protocol

The `ServiceModel` protocol represents the parsed service model and provides access to descriptions of
the operations, fields and errors. This library provides `SwaggerServiceModel` that conforms to this protocol
and will parse a Swagger 2.0 specification file.

## The ModelClientDelegate protocol

The `ModelClientDelegate` protocol provides customization points for the creation of service clients.

## The ModelErrorsDelegate protocol

The `ModelErrorsDelegate` protocol provides customization points for handling errors returned from an application endpoint conforming to the service model.

## The ModelOverride type

The `ModelOverride` type provides the opportunity to override values from the service model.

## License

This library is licensed under the Apache 2.0 License.
