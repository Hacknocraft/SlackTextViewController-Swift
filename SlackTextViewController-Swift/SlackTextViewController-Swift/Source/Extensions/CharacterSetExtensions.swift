//
//  CharacterSetExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 20/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation

extension CharacterSet {

    func characterIsMember(_ aCharacter: unichar) -> Bool {
        return (self as NSCharacterSet).characterIsMember(aCharacter)
    }

}
