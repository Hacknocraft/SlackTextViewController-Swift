//
//  UIScrollViewExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 17/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

extension UIScrollView {

    // MARK: - Public API

    /// YES if the scrollView's offset is at the very top
    var slk_isAtTop: Bool {
        return slk_visibleRect.midY <= bounds.minY
    }

    /// YES if the scrollView's offset is at the very bottom
    var slk_isAtBottom: Bool {
        return slk_visibleRect.maxY >= slk_bottomRect.maxY
    }

    /// The visible area of the content size
    var slk_visibleRect: CGRect {
        var visibleRect: CGRect = .zero
        visibleRect.origin = contentOffset
        visibleRect.size = frame.size
        return visibleRect
    }

    /// Sets the content offset to the top
    ///
    /// - Parameter animated: YES to animate the transition at a constant velocity to the new offset, NO to make the transition immediate
    func slk_scrollToTop(animated: Bool) {
        if slk_canScroll {
            setContentOffset(.zero, animated: animated)
        }
    }

    /// Sets the content offset to the bottom
    ///
    /// - Parameter animated: YES to animate the transition at a constant velocity to the new offset, NO to make the transition immediate
    func slk_scrollToBottom(animated: Bool) {
        if slk_canScroll {
            setContentOffset(slk_bottomRect.origin, animated: animated)
        }
    }

    /// Stops scrolling, if it was scrolling
    func slk_stopScrolling() {
        if !isDragging {
            return
        }

        var offset = self.contentOffset
        offset.y -= 1.0
        contentOffset = offset

        offset.y += 1.0
        contentOffset = offset
    }

    // MARK: - Private Implementations

    private var slk_bottomRect: CGRect {
        return CGRect(x: 0, y: contentSize.height - bounds.height, width: bounds.width, height: bounds.height)
    }

    private var slk_canScroll: Bool {
        if self.contentSize.height > frame.height {
            return true
        }
        return false
    }

}
