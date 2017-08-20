//
//  SLKInputAccessoryView.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

class SLKInputAccessoryView: UIView {

    /// The system keyboard view used as reference
    weak var keyboardViewProxy: UIView?

    override func willMove(toSuperview newSuperview: UIView?) {
        keyboardViewProxy = newSuperview
    }

}
