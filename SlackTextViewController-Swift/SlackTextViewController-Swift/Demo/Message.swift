//
//  Message.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 21/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

class Message: NSObject {

    let username: String
    var text: String

    init(username: String, text: String) {
        self.username = username
        self.text = text
    }

}
