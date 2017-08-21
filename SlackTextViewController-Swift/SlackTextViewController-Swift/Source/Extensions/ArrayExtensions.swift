//
//  ArrayExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 17/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation

extension Array where Element: Equatable {

    mutating func removeObject(_ object: Element) {
        if let index = index(of: object) {
            remove(at: index)
        }
    }

}
