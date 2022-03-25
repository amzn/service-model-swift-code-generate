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
// ServiceModelCodeGenerator+formatDocumentation.swift
// ServiceModelGenerate
//

import Foundation
import ServiceModelCodeGeneration
import ServiceModelEntities

private let paragraphStart = "<p>"
private let paragraphEnd = "</p>"
private let codeStart = "<code>"
private let codeEnd = "</code>"
private let italicsStart = "<i>"
private let italicsEnd = "</i>"
private let fullStop = "."
private let comma = ","
private let noteStart = "<note>"
private let noteEnd = "</note>"
private let unnumberedListStart = "<ul>"
private let unnumberedListEnd = "</ul>"
private let listItemStart = "<li>"
private let listItemEnd = "</li>"
private let linkStart = "<a"
private let linkEnd = "</a>"

internal extension ServiceModelCodeGenerator {
    struct DocumentationBuilder {
        var documentationLines: [String] = []
        var currentLine = ""
        var isInLink = false
        var linkElements: [String] = []
    }
    
    struct DocumentationWord {
        let word: String
    }
    
    private func handleLinkEnd(documentationBuilder: inout ServiceModelCodeGenerator.DocumentationBuilder,
                               currentWord: inout String) {
        documentationBuilder.linkElements.append(String(currentWord.dropLast(linkEnd.count)))
        
        let firstElement = documentationBuilder.linkElements[0]
        
        let prefixDropped = firstElement.dropFirst("href=\"".count)
        
        if let index = prefixDropped.firstIndex(of: "\"") {
            let link = prefixDropped[..<index]
            let textStartIndex = prefixDropped.index(index, offsetBy: 2)
            var text = prefixDropped[textStartIndex...]
            
            // add any other words to the text
            for linkWord in documentationBuilder.linkElements.dropFirst() {
                text += " \(linkWord)"
            }
            
            currentWord = "[\(text)](\(link))"
        }
        
        documentationBuilder.linkElements = []
        documentationBuilder.isInLink = false
    }
    
    private struct DocumentationState {
        var documentationLines: [String] = []
        var currentLine = ""
        var isInLink = false
        var linkElements: [String] = []
    }

    func formatDocumentation(_ documentation: String, maxLineLength: Int) -> [String] {
        let words = documentation.replacingOccurrences(of: codeStart, with: "")
            .replacingOccurrences(of: codeEnd, with: "")
            .replacingOccurrences(of: italicsStart, with: " *")
            .replacingOccurrences(of: italicsEnd, with: "* ")
            .replacingOccurrences(of: listItemStart, with: "*")
            .split(separator: " ")
        
        var state = DocumentationState()
        for (index, word) in words.enumerated() {
            handleWord(word: word, index: index, wordCount: words.count,
                       maxLineLength: maxLineLength, state: &state)
        }
        
        if !state.currentLine.isEmpty {
            state.documentationLines.append(state.currentLine)
        }
        
        return state.documentationLines
    }
    
    private func handleLinkEnd(state: inout ServiceModelCodeGenerator.DocumentationState,
                               currentWord: inout String) {
        state.linkElements.append(String(currentWord.dropLast(linkEnd.count)))
        
        let firstElement = state.linkElements[0]
        
        let prefixDropped = firstElement.dropFirst("href=\"".count)
        
        if let index = prefixDropped.firstIndex(of: "\"") {
            let link = prefixDropped[..<index]
            let textStartIndex = prefixDropped.index(index, offsetBy: 2)
            var text = prefixDropped[textStartIndex...]
            
            // add any other words to the text
            for linkWord in state.linkElements.dropFirst() {
                text += " \(linkWord)"
            }
            
            currentWord = "[\(text)](\(link))"
        }
        
        state.linkElements = []
        state.isInLink = false
    }
    
    private func fixupParagraphStartWord(currentWord: inout String) {
        // if this word is the start of a paragraph
        if currentWord.hasPrefix(paragraphStart) {
            // remove this prefix
            currentWord = String(currentWord.dropFirst(paragraphStart.count))
        }
    }
    
    private func fixupParagraphEndWord(currentWord: inout String, index: Int,
                                       wordCount: Int) -> Bool {
        var createNewParagraph = false
        // if this word is the end of a paragraph
        if currentWord.hasSuffix(paragraphEnd) {
            // if this isn't the last word of the documentation
            if index != wordCount - 1 {
                createNewParagraph = true
            }
            
            // remove this postfix
            currentWord = String(currentWord.dropLast(paragraphEnd.count))
        }
        
        return createNewParagraph
    }
    
    private func handleWord(word: Substring, index: Int, wordCount: Int,
                            maxLineLength: Int, state: inout DocumentationState) {
        var wordPostfix: String = ""
        var currentWord: String = String(word)
    
        fixupParagraphStartWord(currentWord: &currentWord)
    
        let createNewParagraph = fixupParagraphEndWord(currentWord: &currentWord,
                                                       index: index, wordCount: wordCount)
    
        if currentWord.hasSuffix(fullStop) {
            wordPostfix = fullStop
            currentWord = String(currentWord.dropLast(fullStop.count))
        } else if currentWord.hasSuffix(comma) {
            wordPostfix = comma
            currentWord = String(currentWord.dropLast(comma.count))
        }
    
        if currentWord == noteEnd || currentWord == noteStart ||
                currentWord == unnumberedListStart ||
                currentWord == unnumberedListEnd || currentWord == listItemEnd {
            return
        }
    
        if currentWord == linkStart {
            state.isInLink = true
            return
        } else if state.isInLink {
            if currentWord.hasSuffix(linkEnd) {
                handleLinkEnd(state: &state, currentWord: &currentWord)
            } else {
                state.linkElements.append(currentWord)
                
                return
            }
        }
    
        currentWord += wordPostfix
    
        if state.currentLine.isEmpty {
            state.currentLine = currentWord
        } else {
            state.currentLine += " \(currentWord)"
        }
    
        if createNewParagraph {
            state.documentationLines.append(state.currentLine)
            state.documentationLines.append("")
            state.currentLine = ""
        } else if state.currentLine.count >= maxLineLength {
            state.documentationLines.append(state.currentLine)
            state.currentLine = ""
        }
    }
}
