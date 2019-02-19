// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// FileBuilder.swift
// ServiceModelCodeGeneration
//
//

import Foundation

/// Class that builds the output for a file.
public class FileBuilder {
    private(set) var builder: String = ""
    private var indentation: Int = 0
    
    /// Default initializer.
    public init() {
        
    }
    
    /// Appends an empty line to the output.
    public func appendEmptyLine() {
        builder += "\n"
    }
    
    /**
     Appends the specified content as a line to the output.
     
     - Parameters:
        - content: The string to append to the output.
        - preDec: If the indentation should be incremented prior to appending the content.
        - postInc: If indentation should be decremented after appending the content.
        - referencedTypes: Any types referenced by the line.
     */
    public func appendLine(_ content: String, preDec: Bool = false, postInc: Bool = false) {
        content.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
            appendSingleLine(String(line), preDec: preDec, postInc: postInc)
        }
    }
    
    private func appendSingleLine(_ content: String, preDec: Bool = false, postInc: Bool = false) {
            
        if preDec {
            decIndent()
        }
        
        // add spaces based on the current indentation
        for _ in 0..<indentation {
            builder += "    "
        }
        
        builder += content
        builder += "\n"
        
        if postInc {
            incIndent()
        }
    }
    
    /// Increment the indentation.
    public func incIndent() {
        indentation += 1
    }
    
    /// Decrement the indentation.
    public func decIndent() {
        indentation -= 1
    }
    
    /**
     Add the output from another FileBuilder.
     
     - Parameters:
        - otherBuilder: The builder to append content from.
     */
    public func append(fromBuilder otherBuilder: FileBuilder) {
        builder += otherBuilder.builder
    }
    
    /**
     Write the current output of this FileWriter to an output file.
     
     - Parameters:
        - fileName: The file name to write to.
        - filePath: The directory path to save the file to.
     */
    public func write(toFile fileName: String, atFilePath filePath: String) {
        let fileManager = FileManager.default
        
        do {
            // create any directories as needed
            try fileManager.createDirectory(atPath: filePath,
                                            withIntermediateDirectories: true, attributes: nil)
            
            // Write contents to file
            try builder.write(toFile: filePath + "/" + fileName, atomically: false, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }
}
