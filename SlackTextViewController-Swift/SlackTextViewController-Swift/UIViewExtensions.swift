//
//  UIViewExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 16/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    func slk_animateLayoutIfNeeded(bounce: Bool, options: UIViewAnimationOptions, animations: ((Void) -> Void)?) {
        slk_animateLayoutIfNeeded(bounce: bounce, options: options, animations: animations, completion: nil)
    }

    func slk_animateLayoutIfNeeded(bounce: Bool, options: UIViewAnimationOptions, animations: ((Void) -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
        let duration: TimeInterval = bounce ? 0.65 : 0.2
        slk_animateLayoutIfNeeded(duration: duration, bounce: bounce, options: options, animations: animations, completion: completion)
    }

    func slk_animateLayoutIfNeeded(duration: TimeInterval, bounce: Bool, options: UIViewAnimationOptions, animations: ((Void) -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
        if bounce {
            UIView.animate(withDuration: duration,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.7,
                           options: options,
                           animations: {
                            self.layoutIfNeeded()
                            animations?()
            },
                           completion: completion)
        } else {
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: options,
                           animations: {
                            self.layoutIfNeeded()
                            animations?()
            },
                           completion: completion)
        }
    }

    func slk_constraintForAttribute(_ attribute: NSLayoutAttribute, firstItem: AnyObject?, secondItem: AnyObject?) -> NSLayoutConstraint? {
        let filtered = constraints.filter() {
            ($0.firstAttribute == attribute) &&
                ($0.firstItem === firstItem) &&
                ($0.secondItem === secondItem)
        }
        return filtered.first
    }
    

    func slk_constraintsForAttribute(_ attribute: NSLayoutAttribute) -> [NSLayoutConstraint] {
        return constraints.filter() { $0.firstAttribute == attribute }
    }
    
}
