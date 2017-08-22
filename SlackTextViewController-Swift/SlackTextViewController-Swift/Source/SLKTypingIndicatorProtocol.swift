//
//  SLKTypingIndicatorProtocol.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 22/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation

protocol SLKTypingIndicatorProtocol: class {

    var isVisible: Bool { get set }

    func dismissIndicator()
}
