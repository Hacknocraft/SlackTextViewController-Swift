//
//  SLKTextViewController.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 17/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit
import ObjectiveC

//  UIKeyboard notification replacement, posting reliably only when showing/hiding the keyboard (not when resizing keyboard, or with inputAccessoryView reloads, etc).
// Only triggered when using SLKTextViewController's text view.
let SLKKeyboardWillShowNotification = "SLKKeyboardWillShowNotification"
let SLKKeyboardDidShowNotification  = "SLKKeyboardDidShowNotification"
let SLKKeyboardWillHideNotification = "SLKKeyboardWillHideNotification"
let SLKKeyboardDidHideNotification  = "SLKKeyboardDidHideNotification"

enum SLKKeyboardStatus {
    case none
    case didHide
    case willShow
    case didShow
    case willHide
}

class SLKTextViewController: UIViewController {

    // MARK: - Pbulic Properties

    /// The main table view managed by the controller object. Created by default initializing with -init or initWithNibName:bundle:
    private(set) var tableView: UITableView?

    /// The main collection view managed by the controller object. Not nil if the controller is initialised with -initWithCollectionViewLayout:
    private(set) var collectionView: UICollectionView?

    /// The main scroll view managed by the controller object. Not nil if the controller is initialised with -initWithScrollView:
    private(set) var scrollView: UIScrollView?

    /// The bottom toolbar containing a text view and buttons.
    private(set) lazy var textInputbar: SLKTextInputbar = self.makeTextInputbar()

    /// The default typing indicator used to display user names horizontally.
    private(set) lazy var typingIndicatorView: SLKTypingIndicatorView? = self.makeTypingIndicatorView()

    // TODO: - need to inherit from UIView
    /// The custom typing indicator view. Default is kind of SLKTypingIndicatorView.
    /// To customize the typing indicator view, you will need to call -registerClassForTypingIndicatorView: nside of any initialization method.
    /// To interact with it directly, you will need to cast the return value of -typingIndicatorProxyView to the appropriate type.
    private(set) lazy var typingIndicatorProxyView: SLKBaseTypingIndicatorView = self.makeTypingIndicatorProxyView()

    /// A single tap gesture used to dismiss the keyboard. SLKTextViewController is its delegate.
    private(set) var singleTapGesture: UIGestureRecognizer!

    /// A vertical pan gesture used for bringing the keyboard from the bottom. SLKTextViewController is its delegate.
    private(set) var verticalPanGesture: UIPanGestureRecognizer!

    /// YES if animations should have bouncy effects. Default is YES.
    var bounces = true {
        didSet {
            textInputbar.bounces = bounces
        }
    }

    /// YES if text view's content can be cleaned with a shake gesture. Default is NO.
    var shakeToClearEnabled = false

    /// YES if keyboard can be dismissed gradually with a vertical panning gesture. Default is YES.
    /// This feature doesn't work on iOS 9 due to no legit alternatives to detect the keyboard view.
    /// Open Radar: http://openradar.appspot.com/radar?id=5021485877952512
    var isKeyboardPanningEnabled = true

    /// YES if an external keyboard has been detected (this value updates only when the text view becomes first responder).
    private(set) var isExternalKeyboardDetected = false

    /// YES if the keyboard has been detected as undocked or split (iPad Only).
    private(set) var isKeyboardUndocked = false

    /// YES if after right button press, the text view is cleared out. Default is YES.
    var shouldClearTextAtRightButtonPress = true

    /// YES if the scrollView should scroll to bottom when the keyboard is shown. Default is NO.
    var shouldScrollToBottomAfterKeyboardShows = false

    /// YES if the main table view is inverted. Default is YES.
    /// This allows the table view to start from the bottom like any typical messaging interface.
    /// If inverted, you must assign the same transform property to your cells to match the orientation (ie: cell.transform = tableView.transform;)
    /// Inverting the table view will enable some great features such as content offset corrections automatically when resizing the text input and/or showing autocompletion
    var isInverted: Bool = true {
        didSet {
            scrollViewProxy?.transform = isInverted ? CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0) : .identity
        }
    }

    /// YES if the view controller is presented inside of a popover controller. If YES, the keyboard won't move the text input bar and tapping on the tableView/collectionView will not cause the keyboard to be dismissed. This property is compatible only with iPad.
    var isPresentedInPopover: Bool {
        get {
            return _isPresentedInPopover && slk_IsIpad
        }
        set {
            _isPresentedInPopover = newValue
        }
    }
    private var _isPresentedInPopover = false

    /// The current keyboard status (will/did hide, will/did show)
    private(set) var keyboardStatus: SLKKeyboardStatus = .none

    /// Convenience accessors (accessed through the text input bar).
    var textView: SLKTextView {
        return textInputbar.textView
    }
    var leftButton: UIButton {
        return textInputbar.leftButton
    }
    var rightButton: UIButton {
        return textInputbar.rightButton
    }

    // MARK: - Keyboard Handling

    /// Presents the keyboard, if not already, animated.
    /// You can override this method to perform additional tasks associated with presenting the keyboard.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Parameter animated: YES if the keyboard should show using an animation.
    func presentKeyboard(animated: Bool) {
        // Skips if already first responder
        if textView.isFirstResponder {  return }

        if !animated {
            UIView.performWithoutAnimation {
                textView.becomeFirstResponder()
            }
        } else {
            textView.becomeFirstResponder()
        }
    }

    /// Dimisses the keyboard, if not already, animated.
    /// You can override this method to perform additional tasks associated with dismissing the keyboard.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Parameter animated: YES if the keyboard should be dismissed using an animation.
    func dismissKeyboard(animated: Bool) {
        // Dismisses the keyboard from any first responder in the window.
        if !textView.isFirstResponder && keyboardHC.constant > 0 {
            view.window?.endEditing(false)
        }

        if !animated {
            UIView.performWithoutAnimation {
                textView.resignFirstResponder()
            }
        } else {
            textView.resignFirstResponder()
        }
    }

    /// Verifies if the text input bar should still move up/down even if it is NOT first responder. Default is NO.
    /// You can override this method to perform additional tasks associated with presenting the view.
    /// You don't need call super since this method doesn't do anything.
    ///
    /// - Parameter responder: The current first responder object
    /// - Returns: YES so the text input bar still move up/down.
    func forceTextInputbarAdjustment(for responder: UIResponder?) -> Bool {
        return false
    }

    /// Verifies if the text input bar should still move up/down when the text view is first responder.
    /// This is very useful when presenting the view controller in a custom modal presentation, when there keyboard events are being handled externally to reframe the presented view.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Returns: YES so the text input bar still move up/down.
    func ignoreTextInputbarAdjustment() -> Bool {
        if isExternalKeyboardDetected && isKeyboardUndocked {
            return true
        }

        return false
    }

    /// Notifies the view controller that the keyboard changed status.
    /// You can override this method to perform additional tasks associated with presenting the view.
    /// You don't need call super since this method doesn't do anything.
    ///
    /// - Parameter status: The new keyboard status.
    func didChangeKeyboardStatus(_ status: SLKKeyboardStatus) {
        // No implementation here. Meant to be overriden in subclass.
    }

    // MARK: - Interaction Notifications

    ///  Notifies the view controller that the text will update.
    /// You can override this method to perform additional tasks associated with text changes.
    /// You MUST call super at some point in your implementation.
    func textWillUpdate() {
        // No implementation here. Meant to be overriden in subclass.
    }

    ///  Notifies the view controller that the text did update.
    /// You can override this method to perform additional tasks associated with text changes.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter animated: If YES, the text input bar will be resized using an animation.
    func textDidUpdate(animated: Bool) {
        if isTextInputbarHidden { return }

        let inputbarHeight = textInputbar.appropriateHeight

        textInputbar.rightButton.isEnabled = canPressRightButton()
        textInputbar.editorRightButton.isEnabled = canPressRightButton()

        if inputbarHeight != textInputbarHC.constant {
            let inputBarHeightDelta = inputbarHeight - textInputbarHC.constant

            let newOffset = CGPoint(x: 0, y: scrollViewProxy!.contentOffset.y + inputBarHeightDelta)
            textInputbarHC.constant = inputbarHeight
            scrollViewHC.constant = slk_appropriateScrollViewHeight

            if animated {

                let bounces = self.bounces && textView.isFirstResponder

                view.slk_animateLayoutIfNeeded(bounce: bounces,
                                               options: [.curveEaseInOut, .layoutSubviews, .beginFromCurrentState],
                                               animations: { [weak self] in
                                                guard let strongSelf = self else { return }

                                                if !strongSelf.isInverted {
                                                    strongSelf.scrollViewProxy?.contentOffset = newOffset
                                                }

                                                if strongSelf.textInputbar.isEditing {
                                                    strongSelf.textView.slk_scrollToCaretPositon(animated: false)
                                                }
                })

            } else {
                view.layoutIfNeeded()
            }
        }

        // Toggles auto-correction if requiered
        slk_enableTypingSuggestionIfNeeded()
    }

    ///  Notifies the view controller that the text selection did change.
    /// Use this method a replacement of UITextViewDelegate's -textViewDidChangeSelection: which is not reliable enough when using third-party keyboards (they don't forward events properly sometimes).
    /// You can override this method to perform additional tasks associated with text changes.
    /// You MUST call super at some point in your implementation.
    func textSelectionDidChange() {
        // The text view must be first responder
        if !textView.isFirstResponder || keyboardStatus != .didShow { return }

        // Skips there is a real text selection
        if textView.isTrackpadEnabled { return }

        if textView.selectedRange.length > 0 {
            if isAutoCompleting && shouldProcessTextForAutoCompletion() {
                cancelAutoCompletion()
            }
            return
        }

        // Process the text at every caret movement
        slk_processTextForAutoCompletion()
    }

    /// Notifies the view controller when the left button's action has been triggered, manually.
    /// You can override this method to perform additional tasks associated with the left button.
    /// You don't need call super since this method doesn't do anything.
    ///
    /// - Parameter sender: The object calling this method.
    func didPressLeftButton(sender: Any?) {
        // No implementation here. Meant to be overriden in subclass.
    }

    /// Notifies the view controller when the right button's action has been triggered, manually or by using the keyboard return key.
    /// You can override this method to perform additional tasks associated with the right button.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter sender: The object calling this method.
    func didPressRightButton(sender: Any?) {
        if shouldClearTextAtRightButtonPress {
            // Clears the text and the undo manager
            textView.slk_clearText(clearUndo: true)
        }

        // Clears cache
        clearCachedText()
    }

    /// Verifies if the right button can be pressed. If NO, the button is disabled.
    /// You can override this method to perform additional tasks. You SHOULD call super to inherit some conditionals.
    ///
    /// - Returns: YES if the right button can be pressed.
    func canPressRightButton() -> Bool {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.length > 0 && !textInputbar.limitExceeded {
            return true
        }

        return false
    }

    /// Notifies the view controller when the user has pasted a supported media content (images and/or videos).
    /// You can override this method to perform additional tasks associated with image/video pasting. You don't need to call super since this method doesn't do anything.
    /// Only supported pastable medias configured in SLKTextView will be forwarded (take a look at SLKPastableMediaType).
    ///
    /// - Parameter userInfo: The payload containing the media data, content and media types.
    func didPasteMediaContent(userInfo: [AnyHashable: Any]) {
        // No implementation here. Meant to be overriden in subclass.
    }

    /// Verifies that the typing indicator view should be shown.
    /// You can override this method to perform additional tasks.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Returns: YES if the typing indicator view should be presented.
    func canShowTypingIndicator() -> Bool {
        // Don't show if the text is being edited or auto-completed.
        if textInputbar.isEditing || isAutoCompleting {
            return false
        }

        return true
    }

    /// Notifies the view controller when the user has shaked the device for undoing text typing.
    /// You can override this method to perform additional tasks associated with the shake gesture.
    /// Calling super will prompt a system alert view with undo option. This will not be called if 'undoShakingEnabled' is set to NO and/or if the text view's content is empty.
    func willRequestUndo() {
        let title = NSLocalizedString("Undo Typing", comment: "")
        let acceptTitle = NSLocalizedString("Undo", comment: "")
        let cancelTitle = NSLocalizedString("Cancel", comment: "")

        if #available(iOS 8, *) {
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            let action = UIAlertAction(title: acceptTitle, style: .default, handler: { _ in
                // Clears the text but doesn't clear the undo manager
                if self.shakeToClearEnabled {
                    self.textView.slk_clearText(clearUndo: false)
                }
            })
            alertController.addAction(action)

            let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
            alertController.addAction(cancel)

            present(alertController, animated: true, completion: nil)

        } else {
            let alert = UIAlertView()
            alert.title = title
            alert.addButton(withTitle: acceptTitle)
            alert.addButton(withTitle: cancelTitle)
            alert.cancelButtonIndex = 1
            alert.tag = kSLKAlertViewClearTextTag
            alert.delegate = self
            alert.show()
        }
    }

    /// Notifies the view controller when the user has pressed the Return key (↵) with an external keyboard.
    /// You can override this method to perform additional tasks.
    // You MUST call super at some point in your implementation.
    ///
    /// - Parameter keyCommand: The UIKeyCommand object being recognized.
    func didPressReturnKey(keyCommand: UIKeyCommand?) {
        if textInputbar.isEditing {
            didCommitTextEditing(sender: keyCommand as Any)
        } else {
            slk_performRightAction()
        }
    }

    /// Notifies the view controller when the user has pressed the Escape key (Esc) with an external keyboard.
    /// You can override this method to perform additional tasks.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter keyCommand: The UIKeyCommand object being recognized.
    func didPressEscapeKey(keyCommand: UIKeyCommand?) {
        if isAutoCompleting {
            cancelAutoCompletion()
        } else if textInputbar.isEditing {
            didCancelTextEditing(sender: keyCommand as Any)
        }

        if ignoreTextInputbarAdjustment() || (textView.isFirstResponder && keyboardHC.constant == slk_appropriateBottomMargin) {
            return
        }

        dismissKeyboard(animated: true)

    }

    /// Notifies the view controller when the user has pressed the arrow key with an external keyboard.
    /// You can override this method to perform additional tasks.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter keyCommand: The UIKeyCommand object being recognized.
    func didPressArrowKey(keyCommand: UIKeyCommand?) {
        if let keyCommand = keyCommand {
            textView.didPressArrowKey(keyCommand: keyCommand)
        }
    }

    // MARK: - Text Input Bar Adjustment

    /// YES if the text inputbar is hidden. Default is NO.
    var isTextInputbarHidden: Bool {
        get {
            return _isTextInputbarHidden
        }
        set {
            setTextInputbarHidden(newValue, animated: false)
        }
    }
    private var _isTextInputbarHidden = false

    /// Changes the visibility of the text input bar.
    /// Calling this method with the animated parameter set to NO is equivalent to setting the value of the toolbarHidden property directly.
    ///
    /// - Parameters:
    ///   - hidden: Specify YES to hide the toolbar or NO to show it.
    ///   - animated: Specify YES if you want the toolbar to be animated on or off the screen.
    func setTextInputbarHidden(_ hidden: Bool, animated: Bool) {
        if _isTextInputbarHidden == hidden { return }

        textInputbar.isHidden = hidden
        _isTextInputbarHidden = hidden

        let animations = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.textInputbarHC.constant = hidden ? 0: strongSelf.textInputbar.appropriateHeight
            strongSelf.view.layoutIfNeeded()
        }

        let completion = { (finished: Bool) in
            if hidden {
                self.dismissKeyboard(animated: true)
            }
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: animations, completion: completion)
        } else {
            animations()
            completion(false)
        }
    }

    // MARK: - Text Edition

    // TODO: - isEditing exists
    /// YES if the text editing mode is active.
    //    private(set) var editing = false

    /// Re-uses the text layout for edition, displaying an accessory view on top of the text input bar with options (cancel & save).
    /// You can override this method to perform additional tasks
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter text: The string text to edit.
    func editText(_ text: String) {
        let attributedText = textView.slk_defaultAttributedString(for: text)
        editAttributedText(attributedText)
    }

    /// Re-uses the text layout for edition, displaying an accessory view on top of the text input bar with options (cancel & save).
    /// You can override this method to perform additional tasks
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter attributedText: The attributed text to edit.
    func editAttributedText(_ attributedText: NSAttributedString) {
        if !textInputbar.canEditText(attributedText.string) { return }

        // Caches the current text, in case the user cancels the edition
        slk_cacheAttributedTextToDisk(textView.attributedText)

        textInputbar.beginTextEditing()

        // Setting the text after calling -beginTextEditing is safer
        textView.attributedText = attributedText

        textView.slk_scrollToCaretPositon(animated: true)

        // Brings up the keyboard if needed
        presentKeyboard(animated: true)
    }

    /// Notifies the view controller when the editing bar's right button's action has been triggered, manually or by using the external keyboard's Return key.
    /// You can override this method to perform additional tasks associated with accepting changes.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter sender: The object calling this method.
    func didCommitTextEditing(sender: Any) {
        if !textInputbar.isEditing { return }

        textInputbar.endTextEdition()

        // Clears the text and but not the undo manager
        textView.slk_clearText(clearUndo: false)
    }

    /// Notifies the view controller when the editing bar's right button's action has been triggered, manually or by using the external keyboard's Esc key.
    /// You can override this method to perform additional tasks associated with accepting changes.
    /// You MUST call super at some point in your implementation.
    ///
    /// - Parameter sender: The object calling this method.
    func didCancelTextEditing(sender: Any) {
        if !textInputbar.isEditing { return }

        textInputbar.endTextEdition()

        // Clears the text and but not the undo manager
        textView.slk_clearText(clearUndo: false)

        // Restores any previous cached text before entering in editing mode
        slk_reloadTextView()
    }

    // MARK: - Text Auto-Completion

    /// The table view used to display autocompletion results.
    fileprivate(set) lazy var autoCompletionView: UITableView? = self.makeAutoCompletionView()

    /// YES if the autocompletion mode is active.
    private(set) var isAutoCompleting: Bool {
        get {
            return _isAutoCompleting
        }
        set {
            if _isAutoCompleting == newValue { return }

            _isAutoCompleting = newValue

            scrollViewProxy?.isScrollEnabled = !newValue
        }
    }
    private var _isAutoCompleting = false

    /// The recently found prefix symbol used as prefix for autocompletion mode.
    var foundPrefix: String?

    /// The range of the found prefix in the text view content.
    var foundPrefixRange = NSRange(location: 0, length: 0)

    /// The recently found word at the text view's caret position.
    var foundWord: String?

    /// An array containing all the registered prefix strings for autocompletion.
    private(set) var registeredPrefixes = Set<String>()

    /// Registers any string prefix for autocompletion detection, like for user mentions or hashtags autocompletion.
    /// The prefix must be valid string (i.e: '@', '#', '\', and so on).
    //. Prefixes can be of any length.
    ///
    /// - Parameter prefixes: An array of prefix strings.
    func registerPrefixesForAutoCompletion(prefixes: [String]?) {

    }

    /// Verifies that controller is allowed to process the textView's text for auto-completion.
    /// You can override this method to disable momentarily the auto-completion feature, or to let it visible for longer time.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Returns: YES if the controller is allowed to process the text for auto-completion.
    func shouldProcessTextForAutoCompletion() -> Bool {
        if registeredPrefixes.isEmpty {
            return false
        }

        return true
    }

    /// During text autocompletion, by default, auto-correction and spell checking are disabled.
    /// Doing so, refreshes the text input to get rid of the Quick Type bar.
    /// You can override this method to avoid disabling in some cases.
    ///
    /// - Returns: YES if the controller should not hide the quick type bar.
    func shouldDisableTypingSuggestionForAutoCompletion() -> Bool {
        if registeredPrefixes.isEmpty {
            return false
        }

        return true
    }

    /// Notifies the view controller either the autocompletion prefix or word have changed.
    /// Use this method to modify your data source or fetch data asynchronously from an HTTP resource.
    /// Once your data source is ready, make sure to call -showAutoCompletionView: to display the view accordingly.
    /// You don't need call super since this method doesn't do anything.
    /// You SHOULD call super to inherit some conditionals.
    ///
    /// - Parameters:
    ///   - prefix: The detected prefix
    ///   - word: The derected word
    func didChangeAutoCompletion(prefix: String, word: String) {
        // No implementation here. Meant to be overriden in subclass.
    }

    /// Use this method to programatically show/hide the autocompletion view.
    /// Right before the view is shown, -reloadData is called. So avoid calling it manually.
    ///
    /// - Parameter show: YES if the autocompletion view should be shown.
    func showAutoCompletionView(show: Bool) {
        // Reloads the tableview before showing/hiding
        if show {
            autoCompletionView?.reloadData()
        }

        isAutoCompleting = show

        // Toggles auto-correction if requiered
        slk_enableTypingSuggestionIfNeeded()

        var viewHeight = show ? heightForAutoCompletionView() : 0.0

        if autoCompletionViewHC.constant == viewHeight {
            return
        }

        // If the auto-completion view height is bigger than the maximum height allows, it is reduce to that size. Default 140 pts.
        let maximumHeight = maximumHeightForAutoCompletionView()

        if viewHeight > maximumHeight {
            viewHeight = maximumHeight
        }

        let contentViewHeight = scrollViewHC.constant + autoCompletionViewHC.constant

        // On iPhone, the auto-completion view can't extend beyond the content view height
        if slk_IsIphone && viewHeight > contentViewHeight {
            viewHeight = contentViewHeight
        }

        autoCompletionViewHC.constant = viewHeight

        view.slk_animateLayoutIfNeeded(bounce: bounces,
                                       options: [.curveEaseInOut, .layoutSubviews,
                                                 .beginFromCurrentState, . allowUserInteraction],
                                       animations: nil)
    }

    /// Use this method to programatically show the autocompletion view, with provided prefix and word to search.
    /// Right before the view is shown, -reloadData is called. So avoid calling it manually.
    ///
    /// - Parameters:
    ///   - prefix: A prefix that is used to trigger autocompletion
    ///   - word: A word to search for autocompletion
    ///   - prefixRange: The range in which prefix spans.
    func showAutoCompletionView(prefix: String, word: String, prefixRange: NSRange) {
        guard registeredPrefixes.contains(prefix) else { return }

        foundPrefix = prefix
        foundWord = word
        foundPrefixRange = prefixRange
        didChangeAutoCompletion(prefix: prefix, word: word)
        showAutoCompletionView(show: true)
    }

    /// Returns a custom height for the autocompletion view. Default is 0.0.
    /// You can override this method to return a custom height.
    ///
    /// - Returns: The autocompletion view's height.
    func heightForAutoCompletionView() -> CGFloat {
        return 0
    }

    /// Returns the maximum height for the autocompletion view. Default is 140 pts.
    /// You can override this method to return a custom max height.
    ///
    /// - Returns: The autocompletion view's max height.
    func maximumHeightForAutoCompletionView() -> CGFloat {
        var maxiumumHeight = SLKAutoCompletionViewDefaultHeight

        if self.isAutoCompleting {
            var scrollViewHeight = self.scrollViewHC.constant
            scrollViewHeight -= slk_topBarsHeight

            if scrollViewHeight < maxiumumHeight {
                maxiumumHeight = scrollViewHeight
            }
        }

        return maxiumumHeight
    }

    /// Cancels and hides the autocompletion view, animated.
    func cancelAutoCompletion() {
        slk_invalidateAutoCompletion()
        slk_hideAutoCompletionViewIfNeeded()
    }

    /// Accepts the autocompletion, replacing the detected word with a new string, keeping the prefix.
    /// This method is a convinience of -acceptAutoCompletionWithString:keepPrefix:
    ///
    /// - Parameter string: The string to be used for replacing autocompletion placeholders.
    func acceptAutoCompletion(string: String?) {
        acceptAutoCompletion(string: string, keepPrefix: true)
    }

    /// Accepts the autocompletion, replacing the detected word with a new string, and optionally replacing the prefix too.
    ///
    /// - Parameters:
    ///   - string: The string to be used for replacing autocompletion placeholders.
    ///   - keepPrefix: YES if the prefix shouldn't be overidden.
    func acceptAutoCompletion(string: String?, keepPrefix: Bool) {
        guard let string = string, !string.isEmpty,
            let foundWord = self.foundWord else {
                return
        }

        var location = foundPrefixRange.location
        if keepPrefix {
            location += foundPrefixRange.length
        }

        var length = foundWord.length
        if !keepPrefix {
            length += foundPrefixRange.length
        }

        let range = NSRange(location: location, length: length)
        let insertionRange = textView.slk_insertText(string, in: range)

        textView.selectedRange = NSRange(location: insertionRange.location, length: 0)

        textView.slk_scrollToCaretPositon(animated: false)

        cancelAutoCompletion()
    }

    // MARK: - Text Caching

    /// Returns the key to be associated with a given text to be cached. Default is nil.
    /// To enable text caching, you must override this method to return valid key.
    /// The text view will be populated automatically when the view controller is configured.
    /// You don't need to call super since this method doesn't do anything.
    ///
    /// - Returns: The string key for which to enable text caching.
    func keyForTextCaching() -> String? {
        // No implementation here. Meant to be overriden in subclass.
        return nil
    }

    /// Removes the current view controller's cached text.
    /// To enable this, you must return a valid key string in -keyForTextCaching.
    func clearCachedText() {
        slk_cacheAttributedTextToDisk(nil)
    }

    /// Removes all the cached text from disk.
    static func clearAllCachedText() {
        var cachedKeys: [String] = []

        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.nsRange(of: SLKTextViewControllerDomain).location != NSNotFound {
            cachedKeys.append(key)
        }

        if cachedKeys.count == 0 {
            return
        }

        for cachedKey in cachedKeys {
            UserDefaults.standard.removeObject(forKey: cachedKey)
        }

        UserDefaults.standard.synchronize()
    }

    /// Caches text to disk.
    func cacheTextView() {
        slk_cacheAttributedTextToDisk(textView.attributedText)
    }

    private func slk_reloadTextView() {
        guard let key = keyForTextCaching() else {
            return
        }

        var cachedAttributedText = NSAttributedString(string: "")

        if let obj = UserDefaults.standard.object(forKey: key) {
            if let string = obj as? String {
                cachedAttributedText = NSAttributedString(string: string)
            } else if let data = obj as? Data, let attributedText = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSAttributedString {
                cachedAttributedText = attributedText
            }
        }

        if textView.attributedText.length == 0 || cachedAttributedText.length > 0 {
            textView.attributedText = cachedAttributedText
        }
    }

    private func slk_keyForPersistency() -> String? {
        guard let key = keyForTextCaching() else {
            return nil
        }
        return "\(SLKTextViewControllerDomain).\(key)"
    }

    private func slk_cacheAttributedTextToDisk(_ attributedText: NSAttributedString?) {
        guard let key = slk_keyForPersistency(), !key.isEmpty else {
            return
        }

        var cachedAttributedText = NSAttributedString(string: "")

        if let obj = UserDefaults.standard.object(forKey: key) {
            if let string = obj as? String {
                cachedAttributedText = NSAttributedString(string: string)
            } else if let data = obj as? Data, let attributedText = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSAttributedString {
                cachedAttributedText = attributedText
            }
        }

        // Caches text only if its a valid string and not already cached
        if let attributedText = attributedText,
            attributedText.length > 0 && attributedText != cachedAttributedText {
            let data = NSKeyedArchiver.archivedData(withRootObject: attributedText)
            UserDefaults.standard.set(data, forKey: key)
        }
            // Clears cache only if it exists
        else if attributedText?.length == 0 && cachedAttributedText.length > 0 {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            // Skips so it doesn't hit 'synchronize' unnecessarily
            return
        }

        UserDefaults.standard.synchronize()
    }

    private func slk_cacheTextToDisk(_ text: String) {
        guard let key = slk_keyForPersistency(), !key.isEmpty else {
            return
        }

        let attributedText = NSAttributedString(string: text)
        slk_cacheAttributedTextToDisk(attributedText)
    }

    // MARK: - Customization

    /// Registers a class for customizing the behavior and appearance of the text view.
    /// You need to call this method inside of any initialization method.
    ///
    /// - Parameter aClass: A SLKTextView subclass
    func registerClassForTextView(aClass: SLKTextView.Type) {
        textViewClass = aClass
    }

    /// Registers a class for customizing the behavior and appearance of the typing indicator view.
    /// You need to call this method inside of any initialization method.
    /// Make sure to conform to SLKTypingIndicatorProtocol and implement the required methods.
    ///
    /// - Parameter aClass: A subclass of SLKBaseTypingIndicatorView.
    func registerClassForTypingIndicatorView(aClass: SLKBaseTypingIndicatorView.Type) {
        typingIndicatorViewClass = aClass
    }

    // MARK: - Private Properties

    // TODO: - need improvement
    /// Feature flagged while waiting to implement a more reliable technique.
    private let SLKBottomPanningEnabled = false

    fileprivate var kSLKAlertViewClearTextTag: Int {
        return NSStringFromClass(SLKTextViewController.self).hash
    }
    private let SLKAutoCompletionViewDefaultHeight: CGFloat = 140
    fileprivate var scrollViewOffsetBeforeDragging: CGPoint = .zero
    fileprivate var keyboardHeightBeforeDragging: CGFloat = 0

    /// The shared scrollView pointer, either a tableView or collectionView
    fileprivate var scrollViewProxy: UIScrollView? {
        get {
            return _scrollViewProxy
        }
        set {
            if _scrollViewProxy === newValue { return }

            _scrollViewProxy = newValue

            singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(slk_didTapScrollView(gesture:)))
            singleTapGesture.delegate = self
            singleTapGesture.require(toFail: _scrollViewProxy.panGestureRecognizer)

            _scrollViewProxy.addGestureRecognizer(singleTapGesture)

            _scrollViewProxy.panGestureRecognizer.addTarget(self, action: #selector(slk_didPanTextInputBar(gesture:)))
        }
    }
    private var _scrollViewProxy: UIScrollView!

    /// A hairline displayed on top of the auto-completion view, to better separate the content from the control.
    fileprivate var autoCompletionHairline: UIView?

    // Auto-Layout height constraints used for updating their constants
    private var scrollViewHC: NSLayoutConstraint!
    private var textInputbarHC: NSLayoutConstraint!
    private var typingIndicatorViewHC: NSLayoutConstraint!
    private var autoCompletionViewHC: NSLayoutConstraint!
    fileprivate var keyboardHC: NSLayoutConstraint!

    /// YES if the user is moving the keyboard with a gesture
    fileprivate var isMovingKeyboard = false

    /// YES if the view controller did appear and everything is finished configurating. This allows blocking some layout animations among other things.
    private var isViewVisible = false

    /// YES if the view controller's view's size is changing by its parent (i.e. when its window rotates or is resized)
    private var isTransitioning = false

    // Optional classes to be used instead of the default ones.
    private var textViewClass: AnyClass?
    private var typingIndicatorViewClass: SLKBaseTypingIndicatorView.Type?

    // MARK: - Initializers

    /// Initializes a text view controller to manage a table view of a given style.
    // If you use the standard -init method, a table view with plain style will be created
    ///
    /// - Parameter tableViewStyle: A constant that specifies the style of main table view that the controller object is to manage (UITableViewStylePlain or UITableViewStyleGrouped).
    init(tableViewStyle: UITableViewStyle) {
        super.init(nibName: nil, bundle: nil)
        self.scrollViewProxy = tableView(style: tableViewStyle)
        slk_commonInit()
    }

    /// Initializes a collection view controller and configures the collection view with the provided layout.
    /// If you use the standard -init method, a table view with plain style will be created.
    ///
    /// - Parameter collectionViewLayout: The layout object to associate with the collection view. The layout controls how the collection view presents its cells and supplementary views.
    init(collectionViewLayout: UICollectionViewLayout) {
        super.init(nibName: nil, bundle: nil)
        self.scrollViewProxy = collectionView(layout: collectionViewLayout)
        slk_commonInit()
    }

    /// Initializes a text view controller to manage an arbitraty scroll view. The caller is responsible for configuration of the scroll view, including wiring the delegate.
    ///
    /// - Parameter scrollView: a UISCrollView to be used as the main content area.
    init(scrollView: UIScrollView) {
        super.init(nibName: nil, bundle: nil)
        self.scrollView = scrollView
        self.scrollView?.translatesAutoresizingMaskIntoConstraints = false
        self.scrollViewProxy = self.scrollView
        slk_commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        let tableViewStyle = type(of: self).tableViewStyle(for: aDecoder)
        let collectionViewLayout = type(of: self).collectionViewLayout(for: aDecoder)

        if let layout = collectionViewLayout {
            scrollViewProxy = collectionView(layout: layout)
        } else {
            scrollViewProxy = tableView(style: tableViewStyle)
        }

        slk_commonInit()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        self.scrollViewProxy = tableView(style: .plain)
        slk_commonInit()
    }

    private func slk_commonInit() {
        slk_registerNotifications()

        isInverted = true // set isInverted again to set scrollViewProxy?.transform
        automaticallyAdjustsScrollViewInsets = true
        extendedLayoutIncludesOpaqueBars = true
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollViewProxy!)
        view.addSubview(autoCompletionView!)
        view.addSubview(typingIndicatorProxyView)
        view.addSubview(textInputbar)

        slk_setupViewConstraints()

        slk_registerKeyCommands()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Invalidates this flag when the view appears
        textView.didNotResignFirstResponder = false

        // Forces laying out the recently added subviews and update their constraints
        view.layoutIfNeeded()

        UIView.performWithoutAnimation {
            // Reloads any cached text
            slk_reloadTextView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        scrollViewProxy?.flashScrollIndicators()
        isViewVisible = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Caches the text before it's too late!
        cacheTextView()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        slk_adjustContentConfigurationIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    // MARK: - Getters

    /// Returns the tableView style to be configured when using Interface Builder. Default is UITableViewStylePlain.
    /// You must override this method if you want to configure a tableView.
    ///
    /// - Parameter decoder: An unarchiver object.
    /// - Returns: The tableView style to be used in the new instantiated tableView.
    class func tableViewStyle(for decoder: NSCoder) -> UITableViewStyle {
        return .plain
    }

    /// Returns the tableView style to be configured when using Interface Builder. Default is nil.
    /// You must override this method if you want to configure a collectionView.
    ///
    /// - Parameter decoder: An unarchiver object
    /// - Returns: The collectionView style to be used in the new instantiated collectionView.
    static func collectionViewLayout(for decoder: NSCoder) -> UICollectionViewLayout? {
        return nil
    }

    private func tableView(style: UITableViewStyle) -> UITableView {
        let tableView = UITableView(frame: .zero, style: style)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.scrollsToTop = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.clipsToBounds = false
        self.tableView = tableView
        return tableView
    }

    private func collectionView(layout: UICollectionViewLayout) -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.scrollsToTop = true
        collectionView.dataSource = self
        collectionView.delegate = self
        return collectionView
    }

    private func makeAutoCompletionView() -> UITableView? {
        let autoCompletionView = UITableView(frame: .zero, style: .plain)
        autoCompletionView.translatesAutoresizingMaskIntoConstraints = false
        autoCompletionView.backgroundColor = UIColor(white: 0.97, alpha: 1)
        autoCompletionView.scrollsToTop = false
        autoCompletionView.dataSource = self
        autoCompletionView.delegate = self

        if #available(iOS 9, *) {
            autoCompletionView.cellLayoutMarginsFollowReadableWidth = false
        }

        autoCompletionHairline = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 0.5))
        autoCompletionHairline?.autoresizingMask = .flexibleWidth
        autoCompletionHairline?.backgroundColor = autoCompletionView.separatorColor
        autoCompletionView.addSubview(autoCompletionHairline!)
        return autoCompletionView
    }

    private func makeTextInputbar() -> SLKTextInputbar {
        let textInputbar = SLKTextInputbar(textViewClass: textViewClass)
        textInputbar.translatesAutoresizingMaskIntoConstraints = false

        textInputbar.leftButton.addTarget(self, action: #selector(didPressLeftButton(sender:)), for: .touchUpInside)
        textInputbar.rightButton.addTarget(self, action: #selector(didPressRightButton(sender:)), for: .touchUpInside)
        textInputbar.editorLeftButton.addTarget(self, action: #selector(didCancelTextEditing(sender:)), for: .touchUpInside)
        textInputbar.editorRightButton.addTarget(self, action: #selector(didCommitTextEditing(sender:)), for: .touchUpInside)

        textInputbar.textView.delegate = self

        verticalPanGesture = UIPanGestureRecognizer(target: self, action: #selector(slk_didPanTextInputBar(gesture:)))
        verticalPanGesture.delegate = self

        textInputbar.addGestureRecognizer(verticalPanGesture)

        return textInputbar
    }

    private func makeTypingIndicatorProxyView() -> SLKBaseTypingIndicatorView {
        let aClass: SLKBaseTypingIndicatorView.Type = self.typingIndicatorViewClass ?? SLKTypingIndicatorView.self
        let typingIndicatorProxyView = aClass.init()
        typingIndicatorProxyView.translatesAutoresizingMaskIntoConstraints = false
        typingIndicatorProxyView.isHidden = true
        typingIndicatorProxyView.addObserver(self, forKeyPath: "isVisible", options: .new, context: nil)
        return typingIndicatorProxyView
    }

    private func makeTypingIndicatorView() -> SLKTypingIndicatorView? {
        if let typingIndicatorView = self.typingIndicatorProxyView as? SLKTypingIndicatorView {
            return typingIndicatorView
        }
        return nil
    }

    // TODO: Is setter need to be implemented?
    override var modalPresentationStyle: UIModalPresentationStyle {
        get {
            if let nav = navigationController {
                return nav.modalPresentationStyle
            }
            return super.modalPresentationStyle
        }
        set {

        }
    }

    private func slk_appropriateKeyboardHeight(from notification: Notification) -> CGFloat {
        // Let's first detect keyboard special states such as external keyboard, undocked or split layouts.
        slk_detectKeyboardStates(in: notification)

        if ignoreTextInputbarAdjustment() {
            return slk_appropriateBottomMargin
        }

        guard let keyboardRect = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }

        return slk_appropriateKeyboardHeight(from: keyboardRect)
    }

    private func slk_appropriateKeyboardHeight(from rect: CGRect) -> CGFloat {
        let keyboardRect = view.convert(rect, from: nil)

        let viewHeight = view.bounds.height
        let keyboardMinY = keyboardRect.minY

        var keyboardHeight = max(0, viewHeight - keyboardMinY)
        let bottomMargin = slk_appropriateBottomMargin

        // When the keyboard height is zero, we can assume there is no keyboard visible
        // In that case, let's see if there are any other views outside of the view hiearchy
        // requiring to adjust the text input bottom margin
        if keyboardHeight < bottomMargin {
            keyboardHeight = bottomMargin
        }

        return keyboardHeight
    }

    private var slk_appropriateBottomMargin: CGFloat {
        // A bottom margin is required only if the view is extended out of it bounds
        if edgesForExtendedLayout.contains(.bottom),
            let tabBar = tabBarController?.tabBar,
            !tabBar.isHidden,
            !hidesBottomBarWhenPushed {
            return tabBar.frame.height
        }

        return 0
    }

    private var slk_appropriateScrollViewHeight: CGFloat {
        var scrollViewHeight = view.bounds.height

        scrollViewHeight -= self.keyboardHC.constant
        scrollViewHeight -= self.textInputbarHC.constant
        scrollViewHeight -= self.autoCompletionViewHC.constant
        scrollViewHeight -= self.typingIndicatorViewHC.constant

        return (scrollViewHeight < 0) ? 0 : scrollViewHeight
    }

    private var slk_topBarsHeight: CGFloat {
        // No need to adjust if the edge isn't available
        guard edgesForExtendedLayout.contains(.top),
            let nav = navigationController else {
            return 0
        }

        var topBarsHeight = nav.navigationBar.frame.height

        if (slk_IsIphone && slk_IsLandscape && slk_IsIOS8AndHigh) || (slk_IsIpad && modalPresentationStyle == .formSheet) || isPresentedInPopover {
            return topBarsHeight
        }

        topBarsHeight +=  UIApplication.shared.statusBarFrame.height

        return topBarsHeight
    }

    private func slk_appropriateKeyboardNotificationName(for noti: Notification) -> String? {
        let name = noti.name

        switch name {

        case NSNotification.Name.UIKeyboardWillShow:
            return SLKKeyboardWillShowNotification

        case NSNotification.Name.UIKeyboardWillHide:
            return SLKKeyboardWillHideNotification

        case NSNotification.Name.UIKeyboardDidShow:
            return SLKKeyboardDidShowNotification

        case NSNotification.Name.UIKeyboardDidHide:
            return SLKKeyboardDidHideNotification

        default:
            return nil
        }
    }

    private func slk_keyboardStatus(for noti: Notification) -> SLKKeyboardStatus {
        let name = noti.name
        switch name {

        case NSNotification.Name.UIKeyboardWillShow:
            return .willShow

        case NSNotification.Name.UIKeyboardDidShow:
            return .didShow

        case NSNotification.Name.UIKeyboardWillHide:
            return .willHide

        case NSNotification.Name.UIKeyboardDidHide:
            return .didHide

        default:
            return .none
        }
    }

    private func slk_isIllogicalKeyboardStatus(newStatus: SLKKeyboardStatus) -> Bool {
        if (keyboardStatus == .didHide && newStatus == .willShow) ||
            (keyboardStatus == .willShow && newStatus == .didShow) ||
            (keyboardStatus == .didShow && newStatus == .willHide) ||
            (keyboardStatus == .willHide && newStatus == .didHide) {
            return false
        }

        return true
    }

    // MARK: - Setters

    override var edgesForExtendedLayout: UIRectEdge {
        get {
            return _edgesForExtendedLayout
        }
        set {
            if _edgesForExtendedLayout == newValue { return }

            _edgesForExtendedLayout = newValue

            slk_updateViewConstraints()
        }
    }
    private var _edgesForExtendedLayout: UIRectEdge = .all

    private func slk_updateKeyboardStatus(status: SLKKeyboardStatus) -> Bool {
        // Skips if trying to update the same status
        if keyboardStatus == status {
            return false
        }
        // Skips illogical conditions
        // Forces the keyboard status when didHide to avoid any inconsistency.
        if status != .didHide && slk_isIllogicalKeyboardStatus(newStatus: status) {
            return false
        }

        keyboardStatus = status

        didChangeKeyboardStatus(status)

        return true
    }

    // MARK: - Notification Events

    @objc private func slk_willShowOrHideKeyboard(noti: Notification) {
        let status = slk_keyboardStatus(for: noti)

        // Skips if the view isn't visible.
        // Skips if it is presented inside of a popover.
        // Skips if textview did refresh only.
        if !isViewVisible || isPresentedInPopover || textView.didNotResignFirstResponder {
            return
        }

        // Skips if it's not the expected textView and shouldn't force adjustment of the text input bar.
        // This will also dismiss the text input bar if it's visible, and exit auto-completion mode if enabled.
        if let currentResponder = UIResponder.slk_currentFirstResponder(),
            currentResponder !== textView && !forceTextInputbarAdjustment(for: currentResponder) {
            slk_dismissTextInputbarIfNeeded()
            return
        }

        // Skips if it's the current status
        if keyboardStatus == status {
            return
        }

        // Programatically stops scrolling before updating the view constraints (to avoid scrolling glitch).
        if status == .willShow {
            scrollViewProxy?.slk_stopScrolling()
        }

        // Stores the previous keyboard height
        let previousKeyboardHeight = keyboardHC.constant

        // Updates the height constraints' constants
        keyboardHC.constant = slk_appropriateKeyboardHeight(from: noti)
        scrollViewHC.constant = slk_appropriateScrollViewHeight

        // Updates and notifies about the keyboard status update
        if slk_updateKeyboardStatus(status: status) {
            slk_postKeyboarStatus(noti: noti)
        }

        // Hides the auto-completion view if the keyboard is being dismissed.
        if !textView.isFirstResponder || status == .willHide {
            slk_hideAutoCompletionViewIfNeeded()
        }

        guard let curve = noti.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Int,
            let duration = noti.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let beginFrame = noti.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? CGRect,
            let endFrame = noti.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect,
            let scrollView = scrollViewProxy else {
                return
        }

        let animations = {
            // Scrolls to bottom only if the keyboard is about to show.
            if self.shouldScrollToBottomAfterKeyboardShows && self.keyboardStatus == .willShow {
                if self.isInverted {
                    scrollView.slk_scrollToTop(animated: true)
                } else {
                    scrollView.slk_scrollToBottom(animated: true)
                }
            }
        }

        // Begin and end frames are the same when the keyboard is shown during navigation controller's push animation.
        // The animation happens in window coordinates (slides from right to left) but doesn't in the view controller's view coordinates.
        // Second condition: check if the height of the keyboard changed.

        if beginFrame != endFrame || fabs(previousKeyboardHeight - keyboardHC.constant) > 0 {
            // Content Offset correction if not inverted and not auto-completing.
            if !isInverted && !isAutoCompleting {

                let scrollViewHeight = scrollViewHC.constant
                let keyboardHeight = keyboardHC.constant
                let contentSize = scrollView.contentSize
                let contentOffset = scrollView.contentOffset

                let newOffset = min(contentSize.height - scrollViewHeight,
                                    contentOffset.y + keyboardHeight - previousKeyboardHeight)

                scrollView.contentOffset = CGPoint(x: contentOffset.x, y: newOffset)
            }

            // Only for this animation, we set bo to bounce since we want to give the impression that the text input is glued to the keyboard.
            view.slk_animateLayoutIfNeeded(duration: duration,
                                           bounce: false,
                                           options: [.layoutSubviews, .beginFromCurrentState, .curveEaseIn, UIViewAnimationOptions(rawValue: UInt(curve << 16))],
                                           animations: animations,
                                           completion: nil)
        } else {
            animations()
        }

    }

    @objc private func slk_didShowOrHideKeyboard(noti: Notification) {
        let status = slk_keyboardStatus(for: noti)

        // Skips if the view isn't visible
        if !isViewVisible {
            if status == .didHide && keyboardStatus == .willHide {
                // Even if the view isn't visible anymore, let's still continue to update all states.
            } else {
                return
            }
        }

        // Skips if it is presented inside of a popover
        // Skips if textview did refresh only
        // Skips if it's the current status
        if isPresentedInPopover || textView.didNotResignFirstResponder || keyboardStatus == status {
            return
        }

        // Updates and notifies about the keyboard status update
        if slk_updateKeyboardStatus(status: status) {
            // Posts custom keyboard notification, if logical conditions apply
            slk_postKeyboarStatus(noti: noti)
        }

        // After showing keyboard, check if the current cursor position could diplay autocompletion
        if textView.isFirstResponder && status == .didShow && !isAutoCompleting {
            DispatchQueue.main.async {
                self.slk_processTextForAutoCompletion()
            }
        }

        // Very important to invalidate this flag after the keyboard is dismissed or presented, to start with a clean state next time.
        isMovingKeyboard = false
    }

    private func slk_didPostSLKKeyboardNotification(_ noti: Notification) {
        guard let object = noti.object as? SLKTextView, object === textView else {
            return
        }
        // Used for debug only
        print("\(NSStringFromClass(type(of: self))) \(#function): \(noti)")
    }

    @objc private func slk_willChangeTextViewText(noti: Notification) {
        // Skips this it's not the expected textView.
        guard let object = noti.object as? SLKTextView, object === textView else {
            return
        }

        textWillUpdate()
    }

    @objc private func slk_didChangeTextViewText(noti: Notification) {
        // Skips this it's not the expected textView.
        guard let object = noti.object as? SLKTextView, object === textView else {
            return
        }

        // Animated only if the view already appeared.
        textDidUpdate(animated: isViewVisible)

        // Process the text at every change, when the view is visible
        if isViewVisible {
            slk_processTextForAutoCompletion()
        }
    }

    @objc private func slk_didChangeTextViewContentSize(noti: Notification) {
        // Skips this it's not the expected textView.
        guard let object = noti.object as? SLKTextView, object === textView else {
            return
        }

        // Animated only if the view already appeared.
        textDidUpdate(animated: isViewVisible)
    }

    @objc private func slk_didChangeTextViewSelectedRange(noti: Notification) {
        // Skips this it's not the expected textView.
        guard let object = noti.object as? SLKTextView, object === textView else {
            return
        }

        textSelectionDidChange()
    }

    @objc private func slk_didChangeTextViewPasteboard(noti: Notification) {
        if !textView.isFirstResponder { return }

        // Notifies only if the pasted item is nested in a dictionary.
        if let userInfo = noti.userInfo as? [String: Any] {
            didPasteMediaContent(userInfo: userInfo)
        }
    }

    @objc private func slk_didShakeTextView(noti: Notification) {
        if !textView.isFirstResponder { return }

        // Notifies of the shake gesture if undo mode is on and the text view is not empty
        if shakeToClearEnabled && textView.text.length > 0 {
            willRequestUndo()
        }
    }

    private func slk_willShowOrHideTypeIndicatorView(_ indicatorView: SLKBaseTypingIndicatorView) {
        // Skips if the typing indicator should not show. Ignores the checking if it's trying to hide.
        if !canShowTypingIndicator() && indicatorView.isVisible { return }

        let systemLayoutSizeHeight = indicatorView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        let height = indicatorView.isVisible ? systemLayoutSizeHeight : 0.0

        typingIndicatorViewHC.constant = height
        scrollViewHC.constant -= height

        if indicatorView.isVisible {
            view.isHidden = false
        }

        view.slk_animateLayoutIfNeeded(bounce: bounces,
                                       options: [.curveEaseInOut],
                                       animations: nil) { _ in

                                        if !indicatorView.isVisible {
                                            indicatorView.isHidden = true
                                        }
        }
    }

    // MARK: - KVO Events

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if let indicatorView = object as? SLKBaseTypingIndicatorView,
            keyPath == "isVisible" {
            slk_willShowOrHideTypeIndicatorView(indicatorView)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - Private Methods

    @objc private func slk_didPanTextInputBar(gesture: UIPanGestureRecognizer) {
        // Textinput dragging isn't supported when
        if view.window == nil || !isKeyboardPanningEnabled ||
            ignoreTextInputbarAdjustment() || isPresentedInPopover {
            return
        }

        DispatchQueue.main.async {
            self.slk_handlePanGestureRecognizer(gesture)
        }
    }

    private func slk_handlePanGestureRecognizer(_ gesture: UIPanGestureRecognizer) {
        // Local variables
        var startPoint: CGPoint = .zero
        var originalFrame: CGRect = .zero
        var dragging = false
        var presenting = false

        // When no keyboard view has been detecting, let's skip any handling.
        guard var keyboardView = textInputbar.inputAccessoryView?.keyboardViewProxy else {
            return
        }

        // Dynamic variables
        let gestureLocation = gesture.location(in: view)
        let gestureVelocity = gesture.velocity(in: view)

        let keyboardMaxY = slkKeyWindowBounds.maxY
        let keyboardMinY = keyboardMaxY - keyboardView.frame.height

        // Skips this if it's not the expected textView.
        // Checking the keyboard height constant helps to disable the view constraints update on iPad when the keyboard is undocked.
        // Checking the keyboard status allows to keep the inputAccessoryView valid when still reacing the bottom of the screen.
        let bottomMargin = slk_appropriateBottomMargin

        if !textView.isFirstResponder || (keyboardHC.constant == bottomMargin && keyboardStatus == .didHide) {

            #if SLKBottomPanningEnabled

                if gesture.view === scrollViewProxy {
                    if gestureVelocity.y > 0 {
                        return
                    } else if (isInverted && !scrollViewProxy?.slk_isAtTop) || (!isInverted && scrollViewProxy?.slk_isAtBottom) {
                        return
                    }
                }
                presenting = true

            #else

                if gesture.view === textInputbar && gestureVelocity.y < 0 {
                    presentKeyboard(animated: true)
                }
                return

            #endif
        }

        switch gesture.state {
        case .began:

            startPoint = .zero
            dragging = false

            if presenting {
                // Let's first present the keyboard without animation
                presentKeyboard(animated: false)

                // So we can capture the keyboard's view
                keyboardView = textInputbar.inputAccessoryView!.keyboardViewProxy!

                originalFrame = keyboardView.frame
                originalFrame.origin.y = view.frame.maxY

                // And move the keyboard to the bottom edge
                // TODO: Fix an occasional layout glitch when the keyboard appears for the first time.
                keyboardView.frame = originalFrame
            }

        case .changed:

            guard textInputbar.frame.contains(gestureLocation) || dragging || presenting else {
                return
            }

            if startPoint == .zero {
                startPoint = gestureLocation
                dragging = true

                if !presenting {
                    originalFrame = keyboardView.frame
                }
            }

            isMovingKeyboard = true

            let transition = CGPoint(x: gestureLocation.x - startPoint.x, y: gestureLocation.y - startPoint.y)

            var keyboardFrame = originalFrame

            if presenting {
                keyboardFrame.origin.y += transition.y
            } else {
                keyboardFrame.origin.y += max(transition.y, 0)
            }

            // Makes sure they keyboard is always anchored to the bottom
            if keyboardFrame.minY < keyboardMinY {
                keyboardFrame.origin.y = keyboardMinY
            }

            keyboardView.frame = keyboardFrame

            keyboardHC.constant = slk_appropriateKeyboardHeight(from: keyboardFrame)
            scrollViewHC.constant = slk_appropriateScrollViewHeight

            // layoutIfNeeded must be called before any further scrollView internal adjustments (content offset and size)
            view.layoutIfNeeded()

            // Overrides the scrollView's contentOffset to allow following the same position when dragging the keyboard
            var offset = scrollViewOffsetBeforeDragging

            if isInverted {
                if !scrollViewProxy!.isDecelerating && scrollViewProxy!.isTracking {
                    scrollViewProxy?.contentOffset = scrollViewOffsetBeforeDragging
                }
            } else {
                let keyboardHeightDelta = keyboardHeightBeforeDragging - keyboardHC.constant
                offset.y -= keyboardHeightDelta

                scrollViewProxy?.contentOffset = offset
            }

        case .possible, .cancelled, .ended, .failed:

            if !dragging {
                break
            }

            let transition = CGPoint(x: 0, y: fabs(gestureLocation.y - startPoint.y))
            var keyboardFrame = originalFrame

            if presenting {
                keyboardFrame.origin.y = keyboardMinY
            }

            // The velocity can be changed to hide or show the keyboard based on the gesture
            let minVelocity: CGFloat = 20.0
            let minDistance = keyboardFrame.height/2.0

            let hide = (gestureVelocity.y > minVelocity) || (presenting && transition.y < minDistance) || (!presenting && transition.y > minDistance)
            if hide {
                keyboardFrame.origin.y = keyboardMaxY
            }

            keyboardHC.constant = slk_appropriateKeyboardHeight(from: keyboardFrame)
            scrollViewHC.constant = slk_appropriateScrollViewHeight

            UIView.animate(withDuration: 0.25,
                           delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState],
                           animations: {

                            self.view.layoutIfNeeded()
                            keyboardView.frame = keyboardFrame

            },
                           completion: { _ in

                            if hide {
                                self.dismissKeyboard(animated: false)
                            }

                            // Tear down
                            startPoint = .zero
                            originalFrame = .zero
                            dragging = false
                            presenting = false

                            self.isMovingKeyboard = false

            })
        }
    }

    @objc private func slk_didTapScrollView(gesture: UIGestureRecognizer) {
        if !isPresentedInPopover && !ignoreTextInputbarAdjustment() {
            dismissKeyboard(animated: true)
        }
    }

    private func slk_didPanTextView(gesture: UIGestureRecognizer) {
        presentKeyboard(animated: true)
    }

    private func slk_performRightAction() {
        guard let actions = rightButton.actions(forTarget: self, forControlEvent: .touchUpInside),
            actions.count > 0,
            canPressRightButton() else {
                return
        }

        rightButton.sendActions(for: .touchUpInside)
    }

    private func slk_postKeyboarStatus(noti: Notification) {
        guard !ignoreTextInputbarAdjustment() && !isTransitioning,
            var userInfo = noti.userInfo,
            var beginFrame = userInfo[UIKeyboardFrameBeginUserInfoKey] as? CGRect,
            var endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
                return
        }

        // Fixes iOS7 oddness with inverted values on landscape orientation
        if !slk_IsIOS8AndHigh && slk_IsLandscape {
            beginFrame = slk_RectInvert(beginFrame)
            endFrame = slk_RectInvert(endFrame)
        }

        let keyboardHeight = endFrame.height

        beginFrame.size.height = keyboardHeight
        endFrame.size.height = keyboardHeight

        userInfo[UIKeyboardFrameBeginUserInfoKey] = NSValue(cgRect: beginFrame)
        userInfo[UIKeyboardFrameEndUserInfoKey] = NSValue(cgRect: endFrame)

        guard let name = slk_appropriateKeyboardNotificationName(for: noti) else {
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: textView, userInfo: userInfo)
    }

    private func slk_enableTypingSuggestionIfNeeded() {
        if !textView.isFirstResponder { return }

        let enable = !isAutoCompleting

        let inputPrimaryLanguage = textView.textInputMode?.primaryLanguage

        // Toggling autocorrect on Japanese keyboards breaks autocompletion by replacing the autocompletion prefix by an empty string.
        // So for now, let's not disable autocorrection for Japanese.

        // Let's avoid refreshing the text view while dictation mode is enabled.
        // This solves a crash some users were experiencing when auto-completing with the dictation input mode.

        if inputPrimaryLanguage == "ja-JP" ||
           inputPrimaryLanguage == "dictation" ||
            (enable == false && !shouldDisableTypingSuggestionForAutoCompletion()) {
            return

        }

        textView.isTypingSuggestionEnabled = enable
    }

    private func slk_dismissTextInputbarIfNeeded() {
        if keyboardHC.constant == slk_appropriateBottomMargin {
            return
        }
        if keyboardHC.constant == slk_appropriateBottomMargin { return }

        keyboardHC.constant = slk_appropriateBottomMargin
        self.scrollViewHC.constant = slk_appropriateScrollViewHeight

        slk_hideAutoCompletionViewIfNeeded()

        view.layoutIfNeeded()
    }

    private func slk_detectKeyboardStates(in notification: Notification) {
        // Tear down
        isExternalKeyboardDetected = false
        isKeyboardUndocked = false

        if isMovingKeyboard { return }

        // Based on http://stackoverflow.com/a/5760910/287403
        // We can determine if the external keyboard is showing by adding the origin.y of the target finish rect (end when showing, begin when hiding) to the inputAccessoryHeight.
        // If it's greater(or equal) the window height, it's an external keyboard.
        guard let beginRect = notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? CGRect,
            let endRect = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect,
            let baseView = view.window?.rootViewController?.view else {
                return
        }

        // Grab the base view for conversions as we don't want window coordinates in < iOS 8
        // iOS 8 fixes the whole coordinate system issue for us, but iOS 7 doesn't rotate the app window coordinate space.

        let screenBounds = UIScreen.main.bounds

        // Convert the main screen bounds into the correct coordinate space but ignore the origin.
        var viewBounds = view.convert(slkKeyWindowBounds, from: nil)
        viewBounds = CGRect(x: 0, y: 0, width: viewBounds.width, height: viewBounds.height)

        // We want these rects in the correct coordinate space as well.
        let convertBegin = baseView.convert(beginRect, from: nil)
        let convertEnd = baseView.convert(endRect, from: nil)

        if notification.name == NSNotification.Name.UIKeyboardWillShow {
            if convertEnd.origin.y >= viewBounds.height {
                isExternalKeyboardDetected = true
            }
        } else if notification.name == NSNotification.Name.UIKeyboardWillHide {
            // The additional logic check here (== to width) accounts for a glitch (iOS 8 only?) where the window has rotated it's coordinates
            // but the beginRect doesn't yet reflect that. It should never cause a false positive.
            if convertBegin.origin.y >= viewBounds.height ||
            convertBegin.origin.y == viewBounds.width {
                isExternalKeyboardDetected = true
            }
        }

        if slk_IsIpad && convertEnd.maxY < screenBounds.maxY {

            // The keyboard is undocked or split (iPad Only)
            isKeyboardUndocked = true

            // An external keyboard cannot be detected anymore
            isExternalKeyboardDetected = false
        }
    }

    private func slk_adjustContentConfigurationIfNeeded() {
        guard var contentInset = scrollViewProxy?.contentInset else { return }

        // When inverted, we need to substract the top bars height (generally status bar + navigation bar's) to align the top of the
        // scrollView correctly to its top edge.
        if isInverted {
            contentInset.bottom = slk_topBarsHeight
            contentInset.top = (contentInset.bottom > 0.0) ? 0.0 : contentInset.top
        } else {
            contentInset.bottom = 0.0
        }

        scrollViewProxy?.contentInset = contentInset
        scrollViewProxy?.scrollIndicatorInsets = contentInset
    }

    private func slk_prepareForInterfaceTransition(duration: TimeInterval) {
        isTransitioning = true

        view.layoutIfNeeded()

        if textView.isFirstResponder {
            textView.slk_scrollToCaretPositon(animated: false)
        } else {
            textView.slk_scrollToBottom(animated: false)
        }

        // Disables the flag after the rotation animation is finished
        // Hacky but works.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.isTransitioning = false
        }
    }

    // MARK: - View Auto-Layout

    private func slk_setupViewConstraints() {
        let views: [String: Any] = ["scrollView": scrollViewProxy!,
                                    "autoCompletionView": autoCompletionView!,
                                    "typingIndicatorView": typingIndicatorProxyView,
                                    "textInputbar": textInputbar]

        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView(0@750)][typingIndicatorView(0)]-0@999-[textInputbar(0)]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[autoCompletionView(0@750)][typingIndicatorView]", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[autoCompletionView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[typingIndicatorView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[textInputbar]|", options: [], metrics: nil, views: views))

        scrollViewHC = view.slk_constraintForAttribute(.height, firstItem: scrollViewProxy, secondItem: nil)
        autoCompletionViewHC = view.slk_constraintForAttribute(.height, firstItem: autoCompletionView, secondItem: nil)
        typingIndicatorViewHC = view.slk_constraintForAttribute(.height, firstItem: typingIndicatorProxyView, secondItem: nil)
        textInputbarHC = view.slk_constraintForAttribute(.height, firstItem: textInputbar, secondItem: nil)
        keyboardHC = view.slk_constraintForAttribute(.bottom, firstItem: view, secondItem: textInputbar)

        slk_updateViewConstraints()
    }

    private func slk_updateViewConstraints() {
        textInputbarHC.constant = textInputbar.minimumInputbarHeight
        scrollViewHC.constant = slk_appropriateScrollViewHeight
        keyboardHC.constant = slk_appropriateKeyboardHeight(from: .null)

        if textInputbar.isEditing {
            textInputbarHC.constant += textInputbar.editorContentViewHeight
        }

        super.updateViewConstraints()
    }

    // MARK: - Keyboard Command registration

    private func slk_registerKeyCommands() {
        // Enter Key
        textView.observeKeyInput("\r", modifiers: [], title: NSLocalizedString("Send/Accept", comment: "")) { [weak self] keyCommand in
            guard let strongSelf = self else { return }
            strongSelf.didPressReturnKey(keyCommand: keyCommand)
        }

        // Esc Key
        textView.observeKeyInput(UIKeyInputEscape, modifiers: [], title: NSLocalizedString("Dismiss", comment: "")) { [weak self] keyCommand in
            guard let strongSelf = self else { return }
            strongSelf.didPressEscapeKey(keyCommand: keyCommand)
        }

        // Up Arrow
        textView.observeKeyInput(UIKeyInputUpArrow, modifiers: [], title: nil) { [weak self] keyCommand in
            guard let strongSelf = self else { return }
            strongSelf.didPressArrowKey(keyCommand: keyCommand)
        }

        // Down Arrow
        textView.observeKeyInput(UIKeyInputDownArrow, modifiers: [], title: nil) { [weak self] keyCommand in
            guard let strongSelf = self else { return }
            strongSelf.didPressArrowKey(keyCommand: keyCommand)
        }
    }

    override var keyCommands: [UIKeyCommand]? {
        return []
    }

    // MARK: - Auto-Completion Text Processing

    private func registerPrefixesForAutoCompletion(prefixes: [String]) {
        if prefixes.isEmpty { return }

        let set = NSMutableSet(set: registeredPrefixes)
        set.addObjects(from: prefixes)

        if let registeredSet = NSSet(set: set) as? Set<String> {
            registeredPrefixes = registeredSet
        }
    }

    private func shouldProcessTextForAutoCompletion(text: String) -> Bool {
        return shouldProcessTextForAutoCompletion()
    }

    private func slk_processTextForAutoCompletion() {
        guard let text = textView.text else { return }

        if (!isAutoCompleting && text.length == 0) || isTransitioning || !shouldProcessTextForAutoCompletion(text: text) {
            return
        }

        textView.lookForPrefixes(registeredPrefixes) { (prefix, word, wordRange) in
            guard let prefix = prefix, let word = word else {  return }

            if prefix.length > 0 && word.length > 0 {

                // Captures the detected symbol prefix
                foundPrefix = prefix

                // Removes the found prefix, or not.
                foundWord = word.substring(from: prefix.length)

                // Used later for replacing the detected range with a new string alias returned in -acceptAutoCompletionWithString:
                foundPrefixRange = NSRange(location: wordRange.location, length: prefix.length)

                slk_handleProcessedWord(word, wordRange: wordRange)
            } else {
                cancelAutoCompletion()
            }
        }
    }

    private func slk_handleProcessedWord(_ word: String, wordRange: NSRange) {
        guard let foundPrefix = foundPrefix,
            let foundWord = foundWord else {
                return
        }

        // Cancel auto-completion if the cursor is placed before the prefix
        if textView.selectedRange.location <= foundPrefixRange.location {
            cancelAutoCompletion()
        }

        if foundPrefix.length > 0 {
            if wordRange.length == 0 || wordRange.length != word.length {
                cancelAutoCompletion()
            }

            if word.length > 0 {
                // If the prefix is still contained in the word, cancels
                if foundWord.nsRange(of: foundPrefix).location != NSNotFound {
                    cancelAutoCompletion()
                }
            } else {
                cancelAutoCompletion()
            }
        } else {
            cancelAutoCompletion()
        }

        didChangeAutoCompletion(prefix: foundPrefix, word: foundWord)
    }

    private func slk_invalidateAutoCompletion() {
        foundPrefix = nil
        foundWord = nil
        foundPrefixRange = NSRange(location: 0, length: 0)

        autoCompletionView?.contentOffset = .zero
    }

    private func slk_hideAutoCompletionViewIfNeeded() {
        if isAutoCompleting {
            showAutoCompletionView(show: false)
        }
    }

    // MARK: - NSNotificationCenter registration

    private func slk_registerNotifications() {
        slk_unregisterNotifications()

        let notificationCenter = NotificationCenter.default

        // Keyboard notifications
        notificationCenter.addObserver(self, selector: #selector(slk_willShowOrHideKeyboard(noti:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_willShowOrHideKeyboard(noti:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didShowOrHideKeyboard(noti:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didShowOrHideKeyboard(noti:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)

        // TODO: need to fix
        #if SLK_KEYBOARD_NOTIFICATION_DEBUG
            notificationCenter.addObserver(self, selector: #selector(slk_didPostSLKKeyboardNotification(_:)), name: SLKKeyboardWillShowNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(slk_didPostSLKKeyboardNotification(_:)), name: SLKKeyboardDidShowNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(slk_didPostSLKKeyboardNotification(_:)), name: SLKKeyboardWillHideNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(slk_didPostSLKKeyboardNotification(_:)), name: SLKKeyboardDidHideNotification, object: nil)
        #endif

        // TextView notifications slk_willChangeTextViewText
        notificationCenter.addObserver(self, selector: #selector(slk_willChangeTextViewText(noti:)), name: NSNotification.Name(rawValue: SLKTextViewTextWillChangeNotification), object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didChangeTextViewText(noti:)), name: NSNotification.Name.UITextViewTextDidChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didChangeTextViewContentSize(noti:)), name: NSNotification.Name(rawValue: SLKTextViewContentSizeDidChangeNotification), object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didChangeTextViewSelectedRange(noti:)), name: NSNotification.Name(rawValue: SLKTextViewSelectedRangeDidChangeNotification), object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didChangeTextViewPasteboard(noti:)), name: NSNotification.Name(rawValue: SLKTextViewDidPasteItemNotification), object: nil)
        notificationCenter.addObserver(self, selector: #selector(slk_didShakeTextView(noti:)), name: NSNotification.Name(rawValue: SLKTextViewDidShakeNotification), object: nil)

        // Application notifications
        notificationCenter.addObserver(self, selector: #selector(cacheTextView), name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
        notificationCenter.addObserver(self, selector: #selector(cacheTextView), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(cacheTextView), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }

    private func slk_unregisterNotifications() {
        let notificationCenter = NotificationCenter.default

        // Keyboard notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardDidHide, object: nil)

        // TODO: need to fix
        #if SLK_KEYBOARD_NOTIFICATION_DEBUG
            notificationCenter.removeObserver(self, name: SLKKeyboardWillShowNotification, object: nil)
            notificationCenter.removeObserver(self, name: SLKKeyboardDidShowNotification, object: nil)
            notificationCenter.removeObserver(self, name: SLKKeyboardWillHideNotification, object: nil)
            notificationCenter.removeObserver(self, name: SLKKeyboardDidHideNotification, object: nil)
        #endif

        // TextView notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.UITextViewTextDidBeginEditing, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UITextViewTextDidEndEditing, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewTextWillChangeNotification), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UITextViewTextDidChange, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewContentSizeDidChangeNotification), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewSelectedRangeDidChangeNotification), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewDidPasteItemNotification), object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewDidShakeNotification), object: nil)

        // Application notifications
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIApplicationWillTerminate, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
    }

    // MARK: - View Auto-Rotation

    @available(iOS 8, *)
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
    }

    @available(iOS 8, *)
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        slk_prepareForInterfaceTransition(duration: coordinator.transitionDuration)
        super.viewWillTransition(to: size, with: coordinator)
    }

    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        if responds(to: #selector(viewWillTransition(to:with:))) {
            return
        }
        slk_prepareForInterfaceTransition(duration: duration)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: - View lifeterm

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    deinit {
        slk_unregisterNotifications()

        typingIndicatorProxyView.removeObserver(self, forKeyPath: "isVisible")
    }
}

// MARK: - UITableViewDataSource
extension SLKTextViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

}

// MARK: - UITableViewDelegate
extension SLKTextViewController: UITableViewDelegate {

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if let scrollViewProxy = self.scrollViewProxy, !scrollViewProxy.scrollsToTop || keyboardStatus == .willShow {
            return false
        }

        if isInverted {
            scrollViewProxy?.slk_scrollToBottom(animated: true)
            return false
        } else {
            return true
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        isMovingKeyboard = false
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isMovingKeyboard = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === autoCompletionView {
            guard let autoCompletionHairline = self.autoCompletionHairline else {
                return
            }

            var frame = autoCompletionHairline.frame
            frame.origin.y = scrollView.contentOffset.y
            autoCompletionHairline.frame = frame

        } else if !isMovingKeyboard {

            scrollViewOffsetBeforeDragging = scrollView.contentOffset
            keyboardHeightBeforeDragging = keyboardHC.constant
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SLKTextViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
    }

}

// MARK: - UICollectionViewDelegate
extension SLKTextViewController: UICollectionViewDelegate {

}

// MARK: - UITextViewDelegate
extension SLKTextViewController: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let slkTextView = textView as? SLKTextView else {
            return true
        }

        let newWordInserted = text.nsRangeOfCharacter(from: .whitespacesAndNewlines).length != NSNotFound

        // Records text for undo for every new word
        if newWordInserted {
            slkTextView.slk_prepareForUndo("Word Change")
        }

        // Detects double spacebar tapping, to replace the default "." insert with a formatting symbol, if needed.
        if slkTextView.isFormattingEnabled && range.location > 0 && text.length > 0 &&
            CharacterSet.whitespaces.characterIsMember(text.character(at: 0)) &&
            CharacterSet.whitespaces.characterIsMember(slkTextView.text.character(at: range.location - 1)) {

            var shouldChange = true

            // Since we are moving 2 characters to the left, we need for to make sure that the string's lenght,
            // before the caret position, is higher than 2.
            if slkTextView.text.substring(toIndex: slkTextView.selectedRange.location).length < 2 {
                return true
            }

            var wordRange = range
            wordRange.location -= 2; // minus the white space added with the double space bar tapping

            if wordRange.location == NSNotFound {
                return true
            }

            let symbols = slkTextView.registeredSymbols

            let invalidCharacters = NSMutableCharacterSet()
            invalidCharacters.formUnion(with: .whitespacesAndNewlines)
            invalidCharacters.formUnion(with: .punctuationCharacters)
            invalidCharacters.removeCharacters(in: symbols.joined(separator: ""))

            for symbol in symbols {

                // Detects the closest registered symbol to the caret, from right to left
                let searchRange = NSRange(location: 0, length: wordRange.location)
                let prefixRange = slkTextView.text.range(of: symbol, options: .backwards, range: searchRange)

                if prefixRange.location == NSNotFound {
                    continue
                }

                let nextCharRange = NSRange(location: prefixRange.location + 1, length: 1)
                let charAfterSymbol = slkTextView.text.substring(with: nextCharRange)

                if prefixRange.length != NSNotFound && !invalidCharacters.characterIsMember(charAfterSymbol.character(at: 0)) {

                    if self.textView(slkTextView, shouldInsertSuffixForFormattingWith: symbol, prefixRange: prefixRange) {

                        var suffixRange = NSRange(location: 0, length: 0)
                        slkTextView.wordAtRange(wordRange, rangeInText: &suffixRange)

                        // Skip if the detected word already has a suffix
                        if slkTextView.text.substring(with: suffixRange).hasSuffix(symbol) {
                            continue
                        }

                        suffixRange.location += suffixRange.length
                        suffixRange.length = 0

                        let lastCharacter = slkTextView.text.substring(with: NSRange(location: suffixRange.location, length: 1))

                        // Checks if the last character was a line break, so we append the symbol in the next line too
                        if NSCharacterSet.newlines.characterIsMember(lastCharacter.character(at: 0)) {
                            suffixRange.location += 1
                        }

                        slkTextView.slk_insertText(symbol, in: suffixRange)
                        shouldChange = false

                        // Reset the original cursor location +1 for the new character
                        let adjustedCursorPosition = NSRange(location: range.location, length: 0)
                        slkTextView.selectedRange = adjustedCursorPosition

                        break // exit
                    }
                }
            }

            return shouldChange
        } else if text == "\n" {
            //Detected break. Should insert new line break programatically instead.
            slkTextView.slk_insertNewLineBreak()

            return false
        } else {
            let userInfo: [String: Any] = ["text": text, "range": NSValue(range: range)]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewTextWillChangeNotification), object: self.textView, userInfo: userInfo)

            return true
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        // Keep to avoid unnecessary crashes. Was meant to be overriden in subclass while calling super.
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        // Keep to avoid unnecessary crashes. Was meant to be overriden in subclass while calling super.
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        // No implementation here. Meant to be overriden in subclass.
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // No implementation here. Meant to be overriden in subclass.
    }
}

// MARK: - SLKTextViewDelegate
extension SLKTextViewController: SLKTextViewDelegate {

    func textView(_ textView: SLKTextView, shouldOfferFormattingFor symbol: String) -> Bool {
        return true
    }

    func textView(_ textView: SLKTextView, shouldInsertSuffixForFormattingWith symbol: String, prefixRange: NSRange) -> Bool {
        if prefixRange.location > 0 {
            let previousCharRange = NSRange(location:prefixRange.location-1, length: 1)
            let previousCharacter = textView.text.substring(with: previousCharRange)

            // Only insert a suffix if the character before the prefix was a whitespace or a line break
            if previousCharacter.nsRangeOfCharacter(from: .whitespacesAndNewlines).location != NSNotFound {
                return true
            } else {
                return false
            }
        }

        return true
    }

}

// MARK: - UIGestureRecognizerDelegate
extension SLKTextViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        if gestureRecognizer === singleTapGesture {
            return textView.isFirstResponder && !ignoreTextInputbarAdjustment()
        } else if gestureRecognizer === verticalPanGesture {
            return isKeyboardPanningEnabled && !ignoreTextInputbarAdjustment()
        }

        return false
    }

}

extension SLKTextViewController: UIAlertViewDelegate {

    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if alertView.tag != kSLKAlertViewClearTextTag || buttonIndex == alertView.cancelButtonIndex {
            return
        }

        // Clears the text but doesn't clear the undo manager
        if shakeToClearEnabled {
            textView.slk_clearText(clearUndo: false)
        }
    }

}
