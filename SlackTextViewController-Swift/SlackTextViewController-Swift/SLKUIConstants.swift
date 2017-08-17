//
//  SLKUIConstants.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

var slk_IsLandscape: Bool {
    return UIApplication.shared.statusBarOrientation == .landscapeLeft ||
        UIApplication.shared.statusBarOrientation == .landscapeRight
}

var slk_IsIpad: Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

var slk_IsIphone: Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

var slk_IsIphone4: Bool {
    return slk_IsIphone && slkKeyWindowBounds.size.height < 568
}

var slk_IsIphone5: Bool {
    return slk_IsIphone && slkKeyWindowBounds.size.height == 568
}

var slk_IsIphone6: Bool {
    return slk_IsIphone && slkKeyWindowBounds.size.height == 667
}

var slk_IsIphone6Plus: Bool {
    return slk_IsIphone && (slkKeyWindowBounds.size.height == 736 || slkKeyWindowBounds.size.width == 736) // Both orientations
}

var slk_IsIOS8AndHigh: Bool {
    return integerPartOfsystemVersion >= 8
}

var slk_IsIOS9AndHigh: Bool {
    return integerPartOfsystemVersion >= 9
}

private var integerPartOfsystemVersion: Int {

    let versionParts = UIDevice.current.systemVersion.components(separatedBy: ".")

    if let integerPart = versionParts.first, let versionNumber = Int(integerPart) {
        return versionNumber
    }
    return 0
}

let SLKTextViewControllerDomain = "com.slack.TextViewController"

/// Returns a constant font size difference reflecting the current accessibility settings
/// - Parameters:
///   - category: A content size category constant string
/// - Returns:
/// A float constant font size difference
func slk_pointSizeDifference(for category: UIContentSizeCategory) -> CGFloat {
    
    if category == .extraSmall                        { return -3 }
    if category == .small                             { return -2 }
    if category == .medium                            { return -1 }
    if category == .large                             { return -0 }
    if category == .extraLarge                        { return 2 }
    if category == .extraExtraLarge                   { return 4 }
    if category == .extraExtraExtraLarge              { return 6 }
    if category == .accessibilityMedium               { return 8 }
    if category == .accessibilityLarge                { return 10 }
    if category == .accessibilityExtraLarge           { return 11 }
    if category == .accessibilityExtraExtraLarge      { return 12 }
    if category == .accessibilityExtraExtraExtraLarge { return 13 }
    
    return 0
}

var slkKeyWindowBounds: CGRect {
    if let keyWindow = UIApplication.shared.keyWindow {
        return keyWindow.bounds
    }
    return .zero
}

func slk_RectInvert(_ rect: CGRect) -> CGRect {
    
    var invert: CGRect = .zero
    invert.origin.x = rect.origin.y
    invert.origin.y = rect.origin.x
    invert.size.width = rect.size.height
    invert.size.height = rect.size.width
    return invert;
}
