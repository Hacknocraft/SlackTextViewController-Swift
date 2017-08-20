//
//  SLKTextInput.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

/// Searches for any matching string prefix at the text input's caret position. When nothing found, the completion block returns nil values.
protocol SLKTextInput: UITextInput {
    
    /// Searches for any matching string prefix at the text input's caret position. When nothing found, the completion block returns nil values
    /// - Parameters:
    ///   - prefixes: A set of prefixes to search for
    ///   - completion: A completion block called whenever the text processing finishes, successfuly or not. Required.
    func lookForPrefixes(_ prefixes: Set<String>, completion: (String?, String?, NSRange) -> Void)
    
    /// Finds the word close to the caret's position, if any
    /// - Parameters:
    ///   - range: range Returns the range of the found word
    /// - Returns:
    ///   The found word
    func wordAtCaretRange(_ range: inout NSRange) -> String?
    
    /// - Parameters:
    ///   - range: range The range to be used for searching the word
    ///   - rangeInText: rangePointer Returns the range of the found word.
    /// - Returns:
    ///   The found word
    func wordAtRange(_ range: NSRange, rangeInText: inout NSRange)  -> String?

}

extension SLKTextInput {
    
    // MARK: - Default implementations
    
    func lookForPrefixes(_ prefixes: Set<String>, completion: (String?, String?, NSRange) -> Void) {
        
        var wordRange = NSRange(location: 0, length: 0)
        
        guard let word = wordAtCaretRange(&wordRange), prefixes.count > 0 else { return }
        
        if !word.isEmpty {
            for prefix in prefixes where word.hasPrefix(prefix) {
                completion(prefix, word, wordRange)
            }
        } else {
            completion(nil, nil, NSRange(location: 0, length: 0))
        }
        
    }
    
    func wordAtCaretRange(_ range: inout NSRange) -> String? {
        
        return wordAtRange(slk_caretRange, rangeInText: &range)
    }

    @discardableResult
    func wordAtRange(_ range: NSRange, rangeInText: inout NSRange) -> String? {
        let location = range.location
        
        if location == NSNotFound {
            return nil
        }
        
        guard let text = slk_text else { return nil }
        
        // Aborts in case minimum requieres are not fufilled
        if text.isEmpty || location < 0 || (range.location + range.length) > text.length {
            rangeInText = NSRange(location: 0, length: 0)
            return nil
        }
        
        let leftPortion = text.substring(toIndex: location)
        let leftComponents = leftPortion.components(separatedBy: .whitespacesAndNewlines)
        let rightPortion = text.substring(from: location)
        let rightComponents = rightPortion.components(separatedBy: .whitespacesAndNewlines)
        
        guard let rightPart = rightComponents.first, let leftWordPart = leftComponents.last else { return nil }
        
        if location > 0 {
            let characterBeforeCursor = text.substring(with: Range(uncheckedBounds: (location - 1, location)))
            if let whitespaceRange = characterBeforeCursor.rangeOfCharacter(from: .whitespaces)
            {
                let distance = characterBeforeCursor.distance(from: whitespaceRange.lowerBound, to: whitespaceRange.upperBound)
                if distance == 1 {
                    // At the start of a word, just use the word behind the cursor for the current word
                    rangeInText = NSRange(location: location, length: rightPart.length)
                    return rightPart
                }
                
            }
            
        }
        
        // In the middle of a word, so combine the part of the word before the cursor, and after the cursor to get the current word
        rangeInText = NSRange(location: location - leftWordPart.length, length: leftWordPart.length + rightPart.length)
        var word: String = leftWordPart.appending(rightPart)
        let linebreak = "\n"
        
        // If a break is detected, return the last component of the string
        if word.range(of: linebreak) != nil {
            rangeInText = text.nsRange(of: word)
            
            if let last = word.components(separatedBy: linebreak).last {
                word = last
            }
        }
        
        return word
    }
    
    // MARK: - Private methods
    
    var slk_text: String? {
        
        if let range = textRange(from: beginningOfDocument, to: endOfDocument) {
            return text(in: range)
        }
        
        return nil
    }
    
    var slk_caretRange: NSRange {
        
        if let selectedRange = selectedTextRange {
            
            let location = offset(from: beginningOfDocument, to: selectedRange.start)
            let length = offset(from: selectedRange.start, to: selectedRange.end)
            
            return NSRange(location: location, length: length)
        }
        
        return NSRange(location: 0, length: 0)
    }
}
