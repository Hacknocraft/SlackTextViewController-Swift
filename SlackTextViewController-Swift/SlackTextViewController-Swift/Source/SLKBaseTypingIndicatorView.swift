//
//  SLKBaseTypingIndicatorView.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 18/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

/// A base class which conform to `SLKTypingIndicatorProtocol` for typing indicator view. To use a custom typing indicator view, subclass from the class.
open class SLKBaseTypingIndicatorView: UIView {

}

extension SLKBaseTypingIndicatorView: SLKTypingIndicatorProtocol {

    open  func dismissIndicator() {

    }

    open  var isVisible: Bool {
        get {
            return false
        }
        set {

        }
    }

}
