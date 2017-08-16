//
//  StringExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation

extension String {

    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return substring(from: fromIndex)
    }
    
    func substring(toIndex: Int) -> String {
        let substringIndex = index(from: toIndex)
        return substring(to: substringIndex)
    }
    
    func substring(with range: Range<Int>) -> String {
        let startIndex = index(from: range.lowerBound)
        let endIndex = index(from: range.upperBound)
        return substring(with: startIndex..<endIndex)
    }
    
    func nsRange(of string: String) -> NSRange {
        
        if let stringRange = range(of: string) {
            
            let lowerInt = distance(from: startIndex, to: stringRange.lowerBound)
            let upperInt = distance(from: startIndex, to: stringRange.upperBound)
            return NSRange(location: lowerInt, length: upperInt - lowerInt)
        }
        
        return NSRange(location: 0, length: 0)
    }

    var length: Int {
        return characters.count
    }
}
