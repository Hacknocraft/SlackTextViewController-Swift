//
//  StringExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation

extension String {

    var length: Int {
        return characters.count
    }

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

    func substring(with nsRange: NSRange) -> String {
        let startIndex = index(from: nsRange.location)
        let endIndex = index(from: nsRange.location + nsRange.length)
        return substring(with: startIndex..<endIndex)
    }

    func nsRange(of string: String) -> NSRange {
        guard let stringRange = range(of: string) else {
            return NSRange(location: 0, length: 0)
        }

        let lowerInt = distance(from: startIndex, to: stringRange.lowerBound)
        let upperInt = distance(from: startIndex, to: stringRange.upperBound)
        return NSRange(location: lowerInt, length: upperInt - lowerInt)
    }

    func nsRangeOfCharacter(from characterSet: CharacterSet) -> NSRange {
        guard let stringRange = rangeOfCharacter(from: characterSet) else {
            return NSRange(location: 0, length: 0)
        }

        let lowerInt = distance(from: startIndex, to: stringRange.lowerBound)
        let upperInt = distance(from: startIndex, to: stringRange.upperBound)
        return NSRange(location: lowerInt, length: upperInt - lowerInt)
    }

    func range(of searchString: String, options mask: NSString.CompareOptions = [], range rangeOfReceiverToSearch: NSRange) -> NSRange {
        return (self as NSString).range(of: searchString, options: mask, range: rangeOfReceiverToSearch)
    }

    func character(at index: Int) -> unichar {
        return (self as NSString).character(at: index)
    }

}
