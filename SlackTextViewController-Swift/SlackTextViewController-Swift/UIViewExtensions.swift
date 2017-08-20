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

    /// Animates the view's constraints by calling layoutIfNeeded
    ///
    /// - Parameters:
    ///   - bounce: YES if the animation should use spring damping and velocity to give a bouncy effect to animations
    ///   - options: A mask of options indicating how you want to perform the animations
    ///   - animations: An additional block for custom animations
    func slk_animateLayoutIfNeeded(bounce: Bool, options: UIViewAnimationOptions, animations: (() -> Void)?) {
        slk_animateLayoutIfNeeded(bounce: bounce, options: options, animations: animations, completion: nil)
    }

    func slk_animateLayoutIfNeeded(bounce: Bool, options: UIViewAnimationOptions, animations: (() -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
        let duration: TimeInterval = bounce ? 0.65 : 0.2
        slk_animateLayoutIfNeeded(duration: duration, bounce: bounce, options: options, animations: animations, completion: completion)
    }

    /// Animates the view's constraints by calling layoutIfNeeded
    ///
    /// - Parameters:
    ///   - duration: The total duration of the animations, measured in seconds
    ///   - bounce: YES if the animation should use spring damping and velocity to give a bouncy effect to animations
    ///   - options:  mask of options indicating how you want to perform the animations
    ///   - animations: An additional block for custom animations
    func slk_animateLayoutIfNeeded(duration: TimeInterval, bounce: Bool, options: UIViewAnimationOptions, animations: (() -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
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

    /// a layout constraint matching a specific layout attribute and relationship between 2 items, first and second items
    ///
    /// - Parameters:
    ///   - attribute: The layout attribute to use for searching
    ///   - firstItem: The first item in the relationship
    ///   - secondItem: The second item in the relationship
    /// - Returns: A layout constraint
    func slk_constraintForAttribute(_ attribute: NSLayoutAttribute, firstItem: AnyObject?, secondItem: AnyObject?) -> NSLayoutConstraint? {
        let filtered = constraints.filter() {
            ($0.firstAttribute == attribute) &&
                ($0.firstItem === firstItem) &&
                ($0.secondItem === secondItem)
        }
        return filtered.first
    }
    

    /// Returns the view constraints matching a specific layout attribute (top, bottom, left, right, leading, trailing, etc.)
    ///
    /// - Parameter attribute: attribute The layout attribute to use for searching
    /// - Returns: An array of matching constraints
    func slk_constraintsForAttribute(_ attribute: NSLayoutAttribute) -> [NSLayoutConstraint] {
        return constraints.filter() { $0.firstAttribute == attribute }
    }
    
}
