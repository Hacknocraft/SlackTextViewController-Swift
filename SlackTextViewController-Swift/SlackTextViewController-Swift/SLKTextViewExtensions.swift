//
//  SLKTextViewExtensions.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 17/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import Foundation
import UIKit

extension SLKTextView {

    func slk_clearText(_ clearUndo: Bool) {
        // Important to call self implementation, as SLKTextView overrides setText: to add additional features.
        attributedText = nil

        if undoManagerEnabled && clearUndo {
            undoManager?.removeAllActions()
        }
    }

    func slk_scrollToCaretPositon(_ animated: Bool) {
        if animated {
            scrollRangeToVisible(selectedRange)
        } else {
            UIView.performWithoutAnimation {
                scrollRangeToVisible(selectedRange)
            }
        }
    }

    override func slk_scrollToBottom(_ animated: Bool) {
        guard let selectedTextRange = selectedTextRange else { return }

        var rect = caretRect(for: selectedTextRange.end)
        rect.size.height += textContainerInset.bottom

        if animated {
            scrollRectToVisible(rect, animated: animated)
        } else {
            UIView.performWithoutAnimation {
                scrollRectToVisible(rect, animated: false)
            }
        }
    }

    func slk_insertNewLineBreak() {
        slk_insertTextAtCaretRange("\n")

        // if the text view cannot expand anymore, scrolling to bottom are not animated to fix a UITextView issue scrolling twice.
        let animated = !isExpanding

        //Detected break. Should scroll to bottom if needed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0125) {
            self.slk_scrollToBottom(animated)
        }
    }

    func slk_insertTextAtCaretRange(_ text: String) {
        let range = slk_insertText(text, in: selectedRange)
        selectedRange = NSRange(location: range.location, length: 0)
    }

    func slk_insertTextAtCaretRange(_ text: String, with attributes: [String: Any]) {
        let range = slk_insert(text, with: attributes, in: selectedRange)
        selectedRange = NSRange(location: range.location, length: 0)
    }

    func slk_insertText(_ text: String, in range: NSRange) -> NSRange {
        let attributedText = slk_defaultAttributedString(for: text)
        return slk_insertAttributedText(attributedText, in: range)
    }

    func slk_insert(_ text: String, with attributes: [String: Any], in range: NSRange) -> NSRange {
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        return slk_insertAttributedText(attributedText, in: range)
    }

    func slk_setAttributes(_ attributes: [String: Any], in range: NSRange) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(attributedString: self.attributedText)

        attributedText.setAttributes(attributes, range: range)
        self.attributedText = attributedText

        return self.attributedText
    }

    func slk_insertAttributedTextAtCaretRange(_ attributedText: NSAttributedString) {
        let range = slk_insertAttributedText(attributedText, in: selectedRange)
        selectedRange = NSRange(location: range.location, length: 0)
    }

    func slk_insertAttributedText(_ attributedText: NSAttributedString, in range: NSRange) -> NSRange {

        // Skip if the attributed text is empty
        if attributedText.length == 0 {
            return NSRange(location: 0, length: 0)
        }

        var newRange = range

        // Registers for undo management
        slk_prepareForUndo("Attributed text appending")

        // Append the new string at the caret position
        if range.length == 0 {
            let leftAttributedString = self.attributedText.attributedSubstring(from: NSRange(location: 0, length: range.location))
            let rightAttributedString = self.attributedText.attributedSubstring(from: NSRange(location: range.location, length: self.attributedText.length - range.location))

            let newAttributedText = NSMutableAttributedString()
            newAttributedText.append(leftAttributedString)
            newAttributedText.append(attributedText)
            newAttributedText.append(rightAttributedString)

            self.attributedText = newAttributedText

            newRange.location += attributedText.length

            return newRange
        }
            // Some text is selected, so we replace it with the new text
        else if (range.location != NSNotFound) && range.length > 0 {

            let mutableAttributeText = NSMutableAttributedString(attributedString: self.attributedText)
            mutableAttributeText.replaceCharacters(in: range, with: attributedText)
            self.attributedText = mutableAttributeText

            newRange.location += self.attributedText.length

            return newRange
        }

        // No text has been inserted, but still return the caret range
        return selectedRange
    }

    func slk_clearAllAttributes(in range: NSRange) {
        let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
        mutableAttributedText.setAttributes(nil, range: range)
        self.attributedText = mutableAttributedText
    }

    func slk_defaultAttributedString(for text: String) -> NSAttributedString {
        var attributes = [String: Any]()

        if textColor != nil {
            attributes[NSForegroundColorAttributeName] = textColor
        }
        if font != nil {
            attributes[NSFontAttributeName] = font
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    func slk_prepareForUndo(_ description: String) {

        if !undoManagerEnabled { return }

        if let prepareInvocation = undoManager?.prepare(withInvocationTarget: self) as? SLKTextView {
            prepareInvocation.text = text
            undoManager?.setActionName(description)
        }
    }

}
