//
//  UIResponderExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 17/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

extension UIResponder {

    private weak static var _currentFirstResponder: UIResponder?

    static func slk_currentFirstResponder() -> UIResponder? {
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return UIResponder._currentFirstResponder
    }

    @objc private func findFirstResponder(_: AnyObject) {
        UIResponder._currentFirstResponder = self
    }

}
