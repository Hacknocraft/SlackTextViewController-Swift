//
//  SLKTextView.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit
import ObjectiveC

let SLKTextViewTextWillChangeNotification = "SLKTextViewTextWillChangeNotification"
let SLKTextViewContentSizeDidChangeNotification = "SLKTextViewContentSizeDidChangeNotification"
let SLKTextViewSelectedRangeDidChangeNotification = "SLKTextViewSelectedRangeDidChangeNotification"
let SLKTextViewDidPasteItemNotification = "SLKTextViewDidPasteItemNotification"
let SLKTextViewDidShakeNotification = "SLKTextViewDidShakeNotification"

let SLKTextViewPastedItemContentType = "SLKTextViewPastedItemContentType"
let SLKTextViewPastedItemMediaType = "SLKTextViewPastedItemMediaType"
let SLKTextViewPastedItemData = "SLKTextViewPastedItemData"

let SLKTextViewGenericFormattingSelectorPrefix = "slk_format_"

struct SLKPastableMediaTypes: OptionSet {

    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let none = SLKPastableMediaTypes(rawValue: 0)
    static let png = SLKPastableMediaTypes(rawValue: 1 << 0)
    static let jpeg = SLKPastableMediaTypes(rawValue: 1 << 1)
    static let tiff = SLKPastableMediaTypes(rawValue: 1 << 2)
    static let gif = SLKPastableMediaTypes(rawValue: 1 << 3)
    static let mov = SLKPastableMediaTypes(rawValue: 1 << 4)
    static let passbook = SLKPastableMediaTypes(rawValue: 1 << 5)
    static let images: SLKPastableMediaTypes = [.png, .jpeg, .tiff, .gif]
    static let videos: SLKPastableMediaTypes = [.mov]
    static let all: SLKPastableMediaTypes = [.images, .mov]

}

class SLKTextView: UITextView, SLKTextInput {

    // MARK: - Public properties

    weak var textViewDelegate: SLKTextViewDelegate?

    /// The placeholder text string. Default is nil
    var placeholder: String! {
        get {
            return placeholderLabel.text
        }
        set {
            placeholderLabel.text = newValue
            accessibilityLabel = newValue

            setNeedsLayout()
        }
    }

    /// The placeholder color. Default is lightGrayColor
    var placeholderColor: UIColor {
        get {
            return placeholderLabel.textColor
        }
        set {
            placeholderLabel.textColor = newValue
        }
    }

    /// The placeholder's number of lines. Default is 1
    var placeholderNumberOfLines = 1 {
        didSet {
            placeholderLabel.numberOfLines = placeholderNumberOfLines
            setNeedsLayout()
        }
    }

    /// The placeholder's font. Default is the textView's font
    var placeholderFont: UIFont! {
        get {
            return placeholderLabel.font
        }
        set {
            if newValue == nil {
                placeholderLabel.font = font
            } else {
                placeholderLabel.font = newValue
            }
        }
    }

    /// The maximum number of lines before enabling scrolling. Default is 0 wich means limitless. If dynamic type is enabled, the maximum number of lines will be calculated proportionally to the user preferred font size
    var maxNumberOfLines: Int {
        var numberOfLines = 0

        if slk_IsLandscape {
            if slk_IsIphone4 || slk_IsIphone5 {
                numberOfLines = 2 // 2 lines max on smaller iPhones
            } else if slk_IsIphone {
                numberOfLines /= 2 // Half size on larger iPhone
            }
        }

        if isDynamicTypeEnabled {
            let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            let pointSizeDifference = slk_pointSizeDifference(for: contentSizeCategory)
            var factor = pointSizeDifference / initialFontSize

            if fabs(factor) > 0.75 {
                factor = 0.75
            }

            numberOfLines -= Int(floorf(Float(CGFloat(numberOfLines) * factor))) // Calculates a dynamic number of lines depending of the user preferred font size
        }

        return numberOfLines
    }

    /// The current displayed number of lines
    var numberOfLines: Int {
        guard let font = self.font else { return 0 }

        var contentSize = self.contentSize
        var contentHeight = contentSize.height
        contentHeight -= textContainerInset.top + textContainerInset.bottom

        var lines = Int(fabs(contentHeight / font.lineHeight))

        // This helps preventing the content's height to be larger that the bounds' height
        // Avoiding this way to have unnecessary scrolling in the text view when there is only 1 line of content
        if lines == 1 && contentSize.height > bounds.size.height {
            contentSize.height = bounds.size.height
            self.contentSize = contentSize
        }

        // Let's fallback to the minimum line count
        if lines == 0 {
            lines = 1
        }

        return lines
    }

    /// The supported media types allowed to be pasted in the text view, such as images or videos. Default is None
    var pastableMediaTypes: SLKPastableMediaTypes = .none

    /// YES if the text view is and can still expand it self, depending if the maximum number of lines are reached
    var isExpanding: Bool {
        if numberOfLines >= maxNumberOfLines {
            return true
        }
        return false
    }

    /// YES if quickly refreshed the textview without the intension to dismiss the keyboard. @view -disableQuicktypeBar: for more details
    var didNotResignFirstResponder = false

    /** YES if the magnifying glass is visible.
     This feature is deprecated since there are no legit alternatives to detect the magnifying glass.
     Open Radar: http://openradar.appspot.com/radar?id=5021485877952512
     */
//    @property (nonatomic, getter=isLoupeVisible) BOOL loupeVisible DEPRECATED_ATTRIBUTE;

    /// YES if the keyboard track pad has been recognized. iOS 9 only
    var isTrackpadEnabled = false

    /// YES if autocorrection and spell checking are enabled. On iOS8, this property also controls the predictive QuickType bar from being visible. Default is YES
    var isTypingSuggestionEnabled: Bool {
        get {
            return (autocorrectionType == .no) ? false : true
        }
        set {
            if isTypingSuggestionEnabled == newValue { return }

            autocorrectionType = newValue ? .default : .no
            spellCheckingType = newValue ? .default: .no
        }
    }

    /// YES if the text view supports undoing, either using UIMenuController, or with ctrl+z when using an external keyboard. Default is YES
    var isUndoManagerEnabled: Bool {
        get {
            return _isUndoManagerEnabled
        }
        set {
            if _isUndoManagerEnabled == newValue { return }

            undoManager?.levelsOfUndo = 10
            undoManager?.removeAllActions()
            undoManager?.setActionIsDiscardable(true)

            _isUndoManagerEnabled = newValue
        }
    }
    private var _isUndoManagerEnabled = true

    /// YES if the font size should dynamically adapt based on the font sizing option preferred by the user. Default is YES
    var isDynamicTypeEnabled: Bool {
        get {
            return _isDynamicTypeEnabled
        }
        set {
            if _isDynamicTypeEnabled == newValue { return }

            _isDynamicTypeEnabled = newValue

            guard let font = font else { return }

            let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            setFont(name: font.fontName, pointSize: initialFontSize, contentSizeCategory: contentSizeCategory)
        }
    }
    private var _isDynamicTypeEnabled = true

    // MARK: - Private properties

    /// The label used as placeholder
    private var placeholderLabel: UILabel!

    /// The initial font point size, used for dynamic type calculations
    private var initialFontSize: CGFloat = 0

    // Used for moving the caret up/down
    private var verticalMoveDirection: UITextLayoutDirection!
    private var verticalMoveStartCaretRect: CGRect = .zero
    private var verticalMoveLastCaretRect: CGRect = .zero

    // Used for detecting if the scroll indicator was previously flashed
    private var didFlashScrollIndicators = false

    private var registeredFormattingTitles = [String]()
    private var registeredFormattingSymbols = [String]()
    private var formatting = false

    // The keyboard commands available for external keyboards
    private var registeredKeyCommands = [String: UIKeyCommand]()
    private var registeredKeyCallbacks = [String: (UIKeyCommand) -> Void]()

    // MARK: - Initialization

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        slk_commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        slk_commonInit()
    }

    private func slk_commonInit() {
        isEditable = true
        isSelectable = true
        isScrollEnabled = true
        scrollsToTop = false
        isDirectionalLockEnabled = true
        dataDetectorTypes = UIDataDetectorTypes(rawValue: 0)

        slk_registerNotifications()

        addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)

        initPlaceholderLabel()
    }

    private func initPlaceholderLabel() {
        placeholderLabel = UILabel()
        placeholderLabel.clipsToBounds = false
        placeholderLabel.numberOfLines = 1
        placeholderLabel.autoresizesSubviews = false
        placeholderLabel.font = font
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.textColor = .lightGray
        placeholderLabel.isHidden = true
        placeholderLabel.isAccessibilityElement = false
        addSubview(placeholderLabel)
    }

    // MARK: - UIView Overrides

    override var intrinsicContentSize: CGSize {
        if var height = font?.lineHeight {
            height += textContainerInset.top + textContainerInset.bottom
            return CGSize(width: UIViewNoIntrinsicMetric, height: height)
        }
        return .zero
    }

    override class var requiresConstraintBasedLayout: Bool {
            return true
    }

    override func layoutIfNeeded() {
        if window == nil {
            return
        }
        super.layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.placeholderLabel.isHidden = slk_shouldHidePlaceholder()

        if !placeholderLabel.isHidden {

            UIView.performWithoutAnimation {

                placeholderLabel.frame = slk_placeholderRectThatFits(bounds)
                sendSubview(toBack: placeholderLabel)
            }
        }
    }

    // MARK: - Getters

    private func slk_pastedItem() -> Any? {

        guard let contentType = slk_pasteboardContentType() else { return nil }

        if let data = UIPasteboard.general.data(forPasteboardType: contentType) {

            let mediaType = slk_pastableMediaType(from: contentType)
            let userInfo: [String: Any] = [SLKTextViewPastedItemContentType: contentType,
                                           SLKTextViewPastedItemMediaType: mediaType,
                                           SLKTextViewPastedItemData: data]
            return userInfo
        }

        if let url = UIPasteboard.general.url {
            return url.absoluteString
        }

        if let string = UIPasteboard.general.string {
            return string
        }

        return nil
    }

    /// Checks if any supported media found in the general pasteboard
    private func slk_isPasteboardItemSupported() -> Bool {
        if let type = slk_pasteboardContentType(), type.length > 0 {
            return true
        }
        return false
    }

    private func slk_pasteboardContentType() -> String? {
        guard let types = slk_supportedMediaTypes() else { return nil }

        let pasteboardTypes = UIPasteboard.general.types
        var subpredicates = [NSPredicate]()

        for type in types {
            subpredicates.append(NSPredicate(format: "SELF == %@", type))
        }

        let filteredTypes = pasteboardTypes.filter({ (type) -> Bool in
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
            return compoundPredicate.evaluate(with: type)
        })

        return filteredTypes.first
    }

    private func slk_supportedMediaTypes() -> [String]? {

        if pastableMediaTypes == .none {
            return nil
        }

        var types = [String]()

        if pastableMediaTypes.contains(.png), let type = stringFrom(.png) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.jpeg), let type = stringFrom(.jpeg) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.tiff), let type = stringFrom(.tiff) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.gif), let type = stringFrom(.gif) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.mov), let type = stringFrom(.mov) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.passbook), let type = stringFrom(.passbook) {
            types.append(type)
        }
        if pastableMediaTypes.contains(.images), let type = stringFrom(.images) {
            types.append(type)
        }

        return types
    }

    private func stringFrom(_ type: SLKPastableMediaTypes) -> String? {

        if type == .png {
            return "public.png"
        }
        if type == .jpeg {
            return "public.jpeg"
        }
        if type == .tiff {
            return "public.tiff"
        }
        if type == .gif {
            return "com.compuserve.gif"
        }
        if type == .mov {
            return "com.apple.quicktime"
        }
        if type == .passbook {
            return "com.apple.pkpass"
        }
        if type == .images {
            return "com.apple.uikit.image"
        }

        return nil
    }

    private func slk_pastableMediaType(from string: String) -> SLKPastableMediaTypes {

        if string == stringFrom(.png) {
            return .png
        }
        if string == stringFrom(.jpeg) {
            return .jpeg
        }
        if string == stringFrom(.tiff) {
            return .tiff
        }
        if string == stringFrom(.gif) {
            return .gif
        }
        if string == stringFrom(.mov) {
            return .mov
        }
        if string == stringFrom(.passbook) {
            return .passbook
        }
        if string == stringFrom(.images) {
            return .images
        }

        return .none
    }

    private func slk_shouldHidePlaceholder() -> Bool {

        if placeholder == nil {
            return true
        }

        if placeholder.length == 0 || text.length > 0 {
            return true
        }

        return false
    }

    /// Returns only a supported pasted item
    private func slk_placeholderRectThatFits(_ bounds: CGRect) -> CGRect {
        let padding = textContainer.lineFragmentPadding

        var rect: CGRect = .zero
        rect.size.height = placeholderLabel.sizeThatFits(bounds.size).height
        rect.size.width = textContainer.size.width - padding * 2.0
        rect.origin.x += padding

        return rect
    }

    // MARK: - Setters

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(CGPoint(x: 0, y: contentOffset.y), animated: animated)
    }

    // MARK: - UITextView Overrides

    override var selectedRange: NSRange {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewSelectedRangeDidChangeNotification), object: self, userInfo: nil)
        }
    }

    override var selectedTextRange: UITextRange? {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewSelectedRangeDidChangeNotification), object: self, userInfo: nil)
        }
    }

    override var text: String! {
        get {
            return attributedText.string
        }
        set {
            // Registers for undo management
            slk_prepareForUndo("Text Set")

            if newValue != nil {
                attributedText = slk_defaultAttributedString(for: newValue)
            } else {
                attributedText = nil
            }

            NotificationCenter.default.post(name: .UITextViewTextDidChange, object: self)
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            // Registers for undo management
            slk_prepareForUndo("Attributed Text Set")

            NotificationCenter.default.post(name: .UITextViewTextDidChange, object: self)
        }
    }

    override var font: UIFont? {
        didSet {
            guard let font = font else { return }

            let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
            setFont(name: font.fontName, pointSize: font.pointSize, contentSizeCategory: contentSizeCategory)

            initialFontSize = font.pointSize
        }
    }

    private func setFont(name: String, pointSize: CGFloat, contentSizeCategory: UIContentSizeCategory) {
        var size = pointSize
        if isDynamicTypeEnabled {
            size += slk_pointSizeDifference(for: contentSizeCategory)
        }
        let dynamicFont = UIFont(name: name, size: size)

        super.font = dynamicFont

        // Updates the placeholder font too
        placeholderLabel.font = dynamicFont
    }

    override var textAlignment: NSTextAlignment {
        didSet {
            // Updates the placeholder text alignment too
            placeholderLabel.textAlignment = textAlignment
        }
    }

    // MARK: - UITextInput Overrides

    @available(iOS 9.0, *)
    override func beginFloatingCursor(at point: CGPoint) {
        super.beginFloatingCursor(at: point)

        isTrackpadEnabled = true
    }

    @available(iOS 9.0, *)
    override func endFloatingCursor() {
        super.endFloatingCursor()

        isTrackpadEnabled = false

        // We still need to notify a selection change in the textview after the trackpad is disabled
        textViewDelegate?.textViewDidChangeSelection?(self)

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewSelectedRangeDidChangeNotification), object: self, userInfo: nil)
    }

    // MARK: - UIResponder Overrides

    override var canBecomeFirstResponder: Bool {
        slk_addCustomMenuControllerItems()
        return super.canBecomeFirstResponder
    }

    override var canResignFirstResponder: Bool {
        if isUndoManagerEnabled {
            undoManager?.removeAllActions()
        }

        return super.canResignFirstResponder
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if formatting {
            if let title = slk_formattingTitle(from: action),
                let symbol = slk_formattingSymbol(with: title) {

                if symbol.length > 0 {
                    if let shouldOfferFormatting = textViewDelegate?.textView?(self, shouldOfferFormattingFor: symbol) {

                        return shouldOfferFormatting

                    } else {
                        return true
                    }
                }
            }

            return false
        }

        if action == #selector(delete(_:)) {
            return false
        }

        if action == #selector(slk_presentFormattingMenu(_:)) {
            return selectedRange.length > 0 ? true : false
        }

        if action == #selector(paste(_:)) && slk_isPasteboardItemSupported() {
            return true
        }

        guard let undoManager = undoManager else {
            return super.canPerformAction(action, withSender: sender)
        }

        if isUndoManagerEnabled {

            if action == #selector(slk_undo(_:)) {
                if undoManager.undoActionIsDiscardable {
                    return false
                }
                return undoManager.canUndo
            }

            if action == #selector(slk_redo(_:)) {
                if undoManager.redoActionIsDiscardable {
                    return false
                }
                return undoManager.canRedo
            }
        }

        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        guard let pastedItem = slk_pastedItem() else { return }

        if let item = pastedItem as? [String: Any] {

            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewDidPasteItemNotification), object: nil, userInfo: item)

        } else if let item = pastedItem as? String {

            // Respect the delegate yo!
            if textViewDelegate?.textView?(self, shouldChangeTextIn: selectedRange, replacementText: item) != nil {
                return
            }

            // Inserting the text fixes a UITextView bug whitch automatically scrolls to the bottom
            // and beyond scroll content size sometimes when the text is too long
            slk_insertTextAtCaretRange(item)
        }
    }

    // MARK: - NSObject Overrides

    // TODO: OBJC_SWIFT_UNAVAILABLE

//    - (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
//    {
//    if ([super methodSignatureForSelector:sel]) {
//    return [super methodSignatureForSelector:sel];
//    }
//    return [super methodSignatureForSelector:@selector(slk_format:)];
//    }
//
//    - (void)forwardInvocation:(NSInvocation *)invocation
//    {
//    NSString *title = [self slk_formattingTitleFromSelector:[invocation selector]];
//
//    if (title.length > 0) {
//    [self slk_format:title];
//    }
//    else {
//    [super forwardInvocation:invocation];
//    }
//    }
//    

    // MARK: - Custom Actions

    private func slk_flashScrollIndicatorsIfNeeded() {
        if (numberOfLines == maxNumberOfLines + 1) && !didFlashScrollIndicators {
            didFlashScrollIndicators = true
            super.flashScrollIndicators()
        } else if didFlashScrollIndicators {
            didFlashScrollIndicators = false
        }
    }

    /*Some text view properties don't update when it's already firstResponder (auto-correction, spelling-check, etc.)
     To be able to update the text view while still being first responder, requieres to switch quickly from -resignFirstResponder to -becomeFirstResponder.
     When doing so, the flag 'didNotResignFirstResponder' is momentarly set to YES before it goes back to -isFirstResponder, to be able to prevent some tasks to be excuted because of UIKeyboard notifications.

     You can also use this method to confirm an auto-correction programatically, before the text view resigns first responder.
     */

    func refreshFirstResponder() {
        if !isFirstResponder {
            return
        }

        didNotResignFirstResponder = true
        resignFirstResponder()

        didNotResignFirstResponder = false
        becomeFirstResponder()
    }

    func refreshInputViews() {

        didNotResignFirstResponder = true

        super.reloadInputViews()

        didNotResignFirstResponder = false
    }

    private func slk_addCustomMenuControllerItems() {
        let undo = UIMenuItem(title: NSLocalizedString("Undo", comment: ""), action: #selector(slk_undo(_:)))
        let redo = UIMenuItem(title: NSLocalizedString("Redo", comment: ""), action: #selector(slk_redo(_:)))

        var items = [undo, redo]

        if registeredFormattingTitles.count > 0 {
            let format = UIMenuItem(title: NSLocalizedString("Format", comment: ""), action: #selector(slk_presentFormattingMenu(_:)))
            items.append(format)
        }

        UIMenuController.shared.menuItems = items
    }

    @objc private func slk_undo(_ sender: Any?) {
        undoManager?.undo()
    }

    @objc private func slk_redo(_ sender: Any?) {
        undoManager?.redo()
    }

    @objc private func slk_presentFormattingMenu(_ sender: Any?) {
        var items = [UIMenuItem]()

        for name in registeredFormattingTitles {
            let sel = String(format: "%@%@", SLKTextViewGenericFormattingSelectorPrefix, name)
            let item = UIMenuItem(title: name, action: Selector(sel))
            items.append(item)
        }

        formatting = true

        let menu = UIMenuController.shared
        menu.menuItems = items

        let targetRect = layoutManager.boundingRect(forGlyphRange: selectedRange, in: textContainer)
        menu.setTargetRect(targetRect, in: self)
        menu.setMenuVisible(true, animated: true)
    }

    private func slk_formattingTitle(from selector: Selector) -> String? {
        let selectorString = NSStringFromSelector(selector)

        if selectorString.range(of: SLKTextViewGenericFormattingSelectorPrefix) != nil {
            return selectorString.substring(from: SLKTextViewGenericFormattingSelectorPrefix.length)
        }

        return nil
    }

    private func slk_formattingSymbol(with title: String) -> String? {
        guard let idx = registeredFormattingTitles.index(of: title) else { return nil }

        if idx <= registeredFormattingSymbols.count - 1 {
            return registeredFormattingSymbols[idx]
        }

        return nil
    }

    private func slk_format(_ title: String) {
        guard let symbol = slk_formattingSymbol(with: title), symbol.length > 0 else { return }

        let selection = selectedRange

        var range = slk_insertText(symbol, in: NSRange(location: selection.location, length: 0))
        range.location += selection.length
        range.length = 0

        // The default behavior is to add a closure
        var addClosure = true
        if let shouldInsertSuffix = textViewDelegate?.textView?(self, shouldInsertSuffixForFormattingWith: symbol, prefixRange: selection) {
            addClosure = shouldInsertSuffix
        }

        if addClosure {
            selectedRange = slk_insertText(symbol, in: range)
        }
    }

    // MARK: - Markdown Formatting

    /// Registers any string markdown symbol for formatting tooltip, presented after selecting some text. The symbol must be valid string (i.e: '*', '~', '_', and so on). This also checks if no repeated symbols are inserted, and respects the ordering for the tooltip
    /// - Parameters:
    ///   - symbol: A markdown symbol to be prefixed and sufixed to a text selection
    ///   - title: The tooltip item title for this formatting
    func registerMarkdownFormattingSymbol(_ symbol: String, title: String) {

        var registeredFormattingTitles = [String]()
        var registeredFormattingSymbols = [String]()

        // Adds the symbol if not contained already
        if !registeredSymbols.contains(symbol) {
            registeredFormattingTitles.append(symbol)
            registeredFormattingSymbols.append(symbol)
        }
    }

    /// YES if the a markdown closure symbol should be added automatically after double spacebar tap, just like the native gesture to add a sentence period. Default is YES. This will always be NO if there isn't any registered formatting symbols.
    var isFormattingEnabled: Bool {
        return (registeredFormattingSymbols.count > 0) ? true : false
    }

    /// An array of the registered formatting symbols.
    var registeredSymbols: [String] {
        return registeredFormattingSymbols
    }

    // MARK: - Notification Events

    @objc private func slk_didBeginEditing(_ noti: Notification) {
        guard let object = noti.object as? SLKTextView, object === self else {
            return
        }

        // Do something
    }

    @objc private func slk_didChangeText(_ noti: Notification) {
        guard let object = noti.object as? SLKTextView, object === self else {
            return
        }

        if placeholderLabel.isHidden != slk_shouldHidePlaceholder() {
            setNeedsLayout()
        }

        slk_flashScrollIndicatorsIfNeeded()
    }

    @objc private func slk_didEndEditing(_ noti: Notification) {
        guard let object = noti.object as? SLKTextView, object === self else {
            return
        }

        // Do something
    }

    @objc private func slk_didChangeTextInputMode(_ noti: Notification) {
        // Do something
    }

    @objc private func slk_didChangeContentSizeCategory(_ noti: Notification) {

        guard isDynamicTypeEnabled == true,
            let contentSizeCategory = noti.userInfo?[UIContentSizeCategoryNewValueKey] as? UIContentSizeCategory,
            let font = self.font else {
                return
        }

        setFont(name: font.fontName, pointSize: initialFontSize, contentSizeCategory: contentSizeCategory)

        let copyText = text
        // Reloads the content size of the text view
        text = ""
        text = copyText
    }

    @objc private func slk_willShowMenuController(_ noti: Notification) {

        // Do something
    }

    @objc private func slk_didHideMenuController(_ noti: Notification) {
        formatting = false
        slk_addCustomMenuControllerItems()
    }

    // MARK: - KVO Listener

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if let obj = object as? SLKTextView, obj === self,
            keyPath == "contentSize" {

            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewContentSizeDidChangeNotification), object: self, userInfo: nil)

        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - Motion Events

    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {

        if let e = event, e.type == .motion && e.subtype == .motionShake {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextViewDidShakeNotification), object: self)
        }
    }

    // MARK: - External Keyboard Support

    /// Registers and observes key commands' updates, when the text view is first responder. Instead of typically overriding UIResponder's -keyCommands method, it is better to use this API for easier and safer implementation of key input detection
    /// - Parameters:
    ///   - input: The keys that must be pressed by the user. Required
    ///   - modifiers: The bit mask of modifier keys that must be pressed. Use 0 if none
    ///   - title: The title to display to the user. Optional
    ///   - completion: A completion block called whenever the key combination is detected. Required
    func observeKeyInput(_ input: String, modifiers: UIKeyModifierFlags, title: String?, completion: @escaping (UIKeyCommand) -> Void) {

        let keyCommand = UIKeyCommand(input: input, modifierFlags: modifiers, action: #selector(didDetect(_:)))

        if #available(iOS 9, *) {
            keyCommand.discoverabilityTitle = title
        }

        let key = self.key(for: keyCommand)

        registeredKeyCommands[key] = keyCommand
        registeredKeyCallbacks[key] = completion
    }

    @objc private func didDetect(_ keyCommand: UIKeyCommand) {
        let key = self.key(for: keyCommand)

        if let completion = registeredKeyCallbacks[key] {
            completion(keyCommand)
        }
    }

    private func key(for keyCommand: UIKeyCommand) -> String {
       return String(format: "%@_%ld", keyCommand.input, keyCommand.modifierFlags.rawValue)
    }

    override var keyCommands: [UIKeyCommand]? {
        return Array(registeredKeyCommands.values)
    }

    // MARK: - Up/Down Cursor Movement

    /// Notifies the text view that the user pressed any arrow key. This is used to move the cursor up and down while having multiple lines.
    func didPressArrowKey(keyCommand: UIKeyCommand) {

        if !keyCommand.isKind(of: UIKeyCommand.self) || text.length == 0 || numberOfLines < 2 {
            return
        }

        if keyCommand.input == UIKeyInputUpArrow {
            slk_moveCursor(to: .up)
        } else if keyCommand.input == UIKeyInputDownArrow {
            slk_moveCursor(to: .down)
        }
    }

    private func slk_moveCursor(to direction: UITextLayoutDirection) {

        guard let start = (direction == .up) ? selectedTextRange?.start : selectedTextRange?.end else {
            return
        }

        if slk_isNewVerticalMovement(for: start, in: direction) {
            verticalMoveDirection = direction
            verticalMoveStartCaretRect = caretRect(for: start)
        }

        let end = slk_closestPosition(to: start, in: direction)
        verticalMoveLastCaretRect = caretRect(for: end)
        selectedTextRange = textRange(from: end, to: end)

        slk_scrollToCaretPositon(animated: false)
    }

    // Based on code from Ruben Cabaco
    // https://gist.github.com/rcabaco/6765778

    private func slk_closestPosition(to position: UITextPosition, in direction: UITextLayoutDirection) -> UITextPosition {

        // Only up/down are implemented. No real need for left/right since that is native to UITextInput.
        assert(direction == .up || direction == .down)

        // Translate the vertical direction to a horizontal direction.
        let lookupDirection: UITextLayoutDirection = (direction == .up) ? .left : .right
        // Walk one character at a time in `lookupDirection` until the next line is reached.
        var checkPosition = position
        var closestPosition = position
        let startingCaretRect = caretRect(for: position)
        var nextLineCaretRect: CGRect = .zero
        var isInNextLine = false

        while true {
            let nextPosition = self.position(from: checkPosition, in: lookupDirection, offset: 1)

            if nextPosition == nil {
                break
            }

            if let next = nextPosition, compare(checkPosition, to: next) == .orderedSame {
                break
            }

            checkPosition = nextPosition!
            let checkRect = caretRect(for: checkPosition)
            if startingCaretRect.midY != checkRect.midY {

                // While on the next line stop just above/below the starting position
                if lookupDirection == .left && checkRect.midX <= verticalMoveStartCaretRect.midX {
                    closestPosition = checkPosition
                    break
                }

                if lookupDirection == .right && checkRect.midX >= verticalMoveStartCaretRect.midX {
                    closestPosition = checkPosition
                    break
                }

                // But don't skip lines.
                if isInNextLine && checkRect.midY != nextLineCaretRect.midY {
                    break
                }

                isInNextLine = true
                nextLineCaretRect = checkRect
                closestPosition = checkPosition
            }
        }

        return closestPosition
    }

    private func slk_isNewVerticalMovement(for position: UITextPosition, in direction: UITextLayoutDirection) -> Bool {

        let caretRect = self.caretRect(for: position)
        let noPreviousStartPosition = verticalMoveStartCaretRect.equalTo(.zero)
        let caretMovedSinceLastPosition = !caretRect.equalTo(verticalMoveLastCaretRect)
        let directionChanged = verticalMoveDirection != direction
        let newMovement = noPreviousStartPosition || caretMovedSinceLastPosition || directionChanged

        return newMovement
    }

    // MARK: - NSNotificationCenter registration

    private func slk_registerNotifications() {
        slk_unregisterNotifications()

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didBeginEditing(_:)), name: NSNotification.Name.UITextViewTextDidBeginEditing, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeText(_:)), name: .UITextViewTextDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didEndEditing(_:)), name: .UITextViewTextDidEndEditing, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeTextInputMode(_:)), name: .UITextViewTextDidEndEditing, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeContentSizeCategory(_:)), name: .UIContentSizeCategoryDidChange, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_willShowMenuController(_:)), name: .UIMenuControllerWillShowMenu, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didHideMenuController(_:)), name: .UIMenuControllerDidHideMenu, object: nil)
    }

    private func slk_unregisterNotifications() {

        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidBeginEditing, object: nil)

        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidChange, object: nil)

        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidEndEditing, object: nil)

        NotificationCenter.default.removeObserver(self, name: .UITextInputCurrentInputModeDidChange, object: nil)

        NotificationCenter.default.removeObserver(self, name: .UIContentSizeCategoryDidChange, object: nil)
    }

    // MARK: - Lifeterm

    deinit {
        slk_unregisterNotifications()
        removeObserver(self, forKeyPath: NSStringFromSelector(#selector(setter: contentSize)))
    }
}

@objc protocol SLKTextViewDelegate: UITextViewDelegate {

    /// Asks the delegate whether the specified formatting symbol should be displayed in the tooltip. This is useful to remove some tooltip options when they no longer apply in some context. For example, Blockquotes formatting requires the symbol to be prefixed at the begining of a paragraph
    /// - Parameters:
    ///   - textView: The text view containing the changes
    ///   - symbol: The formatting symbol to be verified
    /// - Returns: 
    /// YES if the formatting symbol should be displayed in the tooltip. Default is YES.
    @objc optional func textView(_ textView: SLKTextView, shouldOfferFormattingFor symbol: String) -> Bool

    /// Asks the delegate whether the specified formatting symbol should be suffixed, to close the formatting wrap
    /// - Parameters:
    ///   - prefixRange: The prefix range
    @objc optional func textView(_ textView: SLKTextView, shouldInsertSuffixForFormattingWith symbol: String, prefixRange: NSRange) -> Bool
}
