//
//  MessageViewController.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 21/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit
import LoremIpsum

let DEBUG_CUSTOM_TYPING_INDICATOR = false

class MessageViewController: SLKTextViewController {

    var messages = [Message]()

    var users = ["Allen", "Anna", "Alicia", "Arnold", "Armando", "Antonio", "Brad", "Catalaya", "Christoph", "Emerson", "Eric", "Everyone", "Steve"]
    var channels = ["General", "Random", "iOS", "Bugs", "Sports", "Android", "UI", "SSB"]
    var emojis = ["-1", "m", "man", "machine", "block-a", "block-b", "bowtie", "boar", "boat", "book", "bookmark", "neckbeard", "metal", "fu", "feelsgood"]
    var commands = ["msg", "call", "text", "skype", "kick", "invite"]

    var searchResult: [String]?

    var pipWindow: UIWindow?

    var editingMessage = Message(username: "", text: "")

    override var tableView: UITableView? {
        return super.tableView
    }

    // MARK: - Initialization

    override class func tableViewStyle(for decoder: NSCoder) -> UITableViewStyle {
        return .plain
    }

    func commonInit() {

        if let tableView = self.tableView {
            NotificationCenter.default.addObserver(tableView, selector: #selector(UITableView.reloadData), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(MessageViewController.textInputbarDidMove(_:)), name: NSNotification.Name(rawValue: SLKTextInputbarDidMoveNotification), object: nil)
    }

    override func viewDidLoad() {

        // Register a SLKTextView subclass, if you need any special appearance and/or behavior customisation.
        registerClassForTextView(aClass: MessageTextView.self)

        if DEBUG_CUSTOM_TYPING_INDICATOR == true {
            // Register a UIView subclass, conforming to SLKTypingIndicatorProtocol, to use a custom typing indicator view.
            registerClassForTypingIndicatorView(aClass: TypingIndicatorView.self)
        }

        super.viewDidLoad()

        commonInit()

        // Example's configuration
        configureDataSource()
        configureActionItems()

        // SLKTVC's configuration
        bounces = true
        shakeToClearEnabled = true
        isKeyboardPanningEnabled = true
        shouldScrollToBottomAfterKeyboardShows = false
        isInverted = true

        leftButton.setImage(UIImage(named: "icn_upload"), for: UIControlState())
        leftButton.tintColor = UIColor.gray

        rightButton.setTitle(NSLocalizedString("Send", comment: ""), for: UIControlState())

        textInputbar.autoHideRightButton = true
        textInputbar.maxCharCount = 256
        textInputbar.counterStyle = .split
        textInputbar.counterPosition = .top

        textInputbar.editorTitle.textColor = UIColor.darkGray
        textInputbar.editorLeftButton.tintColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
        textInputbar.editorRightButton.tintColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)

        if DEBUG_CUSTOM_TYPING_INDICATOR == false {
            typingIndicatorView!.canResignByTouch = true
        }

        tableView?.separatorStyle = .none
        tableView?.register(MessageTableViewCell.self, forCellReuseIdentifier: MessageTableViewCell.kMessengerCellIdentifier)

        autoCompletionView?.register(MessageTableViewCell.self, forCellReuseIdentifier: MessageTableViewCell.kAutoCompletionCellIdentifier)
        registerPrefixesForAutoCompletion(prefixes: ["@", "#", ":", "+:", "/"])

        textView.placeholder = "Message"

        textView.registerMarkdownFormattingSymbol("*", title: "Bold")
        textView.registerMarkdownFormattingSymbol("~", title: "Strike")
        textView.registerMarkdownFormattingSymbol("`", title: "Code")
        textView.registerMarkdownFormattingSymbol("```", title: "Preformatted")
        textView.registerMarkdownFormattingSymbol(">", title: "Quote")
    }

    // MARK: - Lifeterm

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Overriden Methods

    override func ignoreTextInputbarAdjustment() -> Bool {
        return super.ignoreTextInputbarAdjustment()
    }

    override func forceTextInputbarAdjustment(for responder: UIResponder!) -> Bool {

        if #available(iOS 8.0, *) {
            guard responder is UIAlertController else {
                // On iOS 9, returning YES helps keeping the input view visible when the keyboard if presented from another app when using multi-tasking on iPad.
                return UIDevice.current.userInterfaceIdiom == .pad
            }
            return true
        } else {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
    }

    // Notifies the view controller that the keyboard changed status.
    override func didChangeKeyboardStatus(_ status: SLKKeyboardStatus) {
        switch status {
        case .willShow:
            print("Will Show")
        case .didShow:
            print("Did Show")
        case .willHide:
            print("Will Hide")
        case .didHide:
            print("Did Hide")
        default:
            break
        }
    }

    // Notifies the view controller that the text will update.
    override func textWillUpdate() {
        super.textWillUpdate()
    }

    // Notifies the view controller that the text did update.
    override func textDidUpdate(animated: Bool) {
        super.textDidUpdate(animated: animated)
    }

    // Notifies the view controller when the left button's action has been triggered, manually.
    override func didPressLeftButton(sender: Any!) {
        super.didPressLeftButton(sender: sender)

        self.dismissKeyboard(animated: true)
        self.performSegue(withIdentifier: "Push", sender: nil)
    }

    // Notifies the view controller when the right button's action has been triggered, manually or by using the keyboard return key.
    override func didPressRightButton(sender: Any!) {

        // This little trick validates any pending auto-correction or auto-spelling just after hitting the 'Send' button
        self.textView.refreshFirstResponder()

        let message = Message(username: LoremIpsum.name(), text: self.textView.text)

        let indexPath = IndexPath(row: 0, section: 0)
        let rowAnimation: UITableViewRowAnimation = self.isInverted ? .bottom : .top
        let scrollPosition: UITableViewScrollPosition = self.isInverted ? .bottom : .top

        tableView?.beginUpdates()
        self.messages.insert(message, at: 0)
        self.tableView?.insertRows(at: [indexPath], with: rowAnimation)
        self.tableView?.endUpdates()

        self.tableView?.scrollToRow(at: indexPath, at: scrollPosition, animated: true)

        // Fixes the cell from blinking (because of the transform, when using translucent cells)
        // See https://github.com/slackhq/SlackTextViewController/issues/94#issuecomment-69929927
        self.tableView?.reloadRows(at: [indexPath], with: .automatic)

        super.didPressRightButton(sender: sender)
    }

    override func didPressArrowKey(keyCommand: UIKeyCommand?) {

        guard let keyCommand = keyCommand else { return }

        if keyCommand.input == UIKeyInputUpArrow && self.textView.text.characters.count == 0 {
            self.editLastMessage(nil)
        } else {
            super.didPressArrowKey(keyCommand: keyCommand)
        }
    }

    override func keyForTextCaching() -> String? {

        return Bundle.main.bundleIdentifier
    }

    // Notifies the view controller when the user has pasted a media (image, video, etc) inside of the text view.
    override func didPasteMediaContent(userInfo: [AnyHashable: Any]) {

        super.didPasteMediaContent(userInfo: userInfo)

        let mediaType = (userInfo[SLKTextViewPastedItemMediaType] as? NSNumber)?.intValue
        let contentType = userInfo[SLKTextViewPastedItemContentType]
        let data = userInfo[SLKTextViewPastedItemData]

        print("didPasteMediaContent : \(String(describing: contentType)) (type = \(String(describing: mediaType)) | data : \(String(describing: data)))")
    }

    // Notifies the view controller when a user did shake the device to undo the typed text
    override func willRequestUndo() {
        super.willRequestUndo()
    }

    // Notifies the view controller when tapped on the right "Accept" button for commiting the edited text
    override func didCommitTextEditing(sender: Any) {

        self.editingMessage.text = self.textView.text
        self.tableView?.reloadData()

        super.didCommitTextEditing(sender: sender)
    }

    // Notifies the view controller when tapped on the left "Cancel" button
    override func didCancelTextEditing(sender: Any) {
        super.didCancelTextEditing(sender: sender)
    }

    override func canPressRightButton() -> Bool {
        return super.canPressRightButton()
    }

    override func canShowTypingIndicator() -> Bool {

        if DEBUG_CUSTOM_TYPING_INDICATOR == true {
            return true
        } else {
            return super.canShowTypingIndicator()
        }
    }

    override func shouldProcessTextForAutoCompletion() -> Bool {
        return true
    }

    override func didChangeAutoCompletion(prefix: String, word: String) {

        var array: [String] = []
        let wordPredicate = NSPredicate(format: "self BEGINSWITH[c] %@", word)

        self.searchResult = nil

        if prefix == "@" {
            if word.characters.count > 0 {
                array = self.users.filter { wordPredicate.evaluate(with: $0) }
            } else {
                array = self.users
            }
        } else if prefix == "#" {

            if word.characters.count > 0 {
                array = self.channels.filter { wordPredicate.evaluate(with: $0) }
            } else {
                array = self.channels
            }
        } else if (prefix == ":" || prefix == "+:") && word.characters.count > 0 {
            array = self.emojis.filter { wordPredicate.evaluate(with: $0) }
        } else if prefix == "/" && self.foundPrefixRange.location == 0 {
            if word.characters.count > 0 {
                array = self.commands.filter { wordPredicate.evaluate(with: $0) }
            } else {
                array = self.commands
            }
        }

        var show = false

        if array.count > 0 {
            let sortedArray = array.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
            self.searchResult = sortedArray
            show = sortedArray.count > 0
        }

        self.showAutoCompletionView(show: show)
    }

    override func heightForAutoCompletionView() -> CGFloat {

        guard let searchResult = self.searchResult else {
            return 0
        }

        guard let autoCompletionView = self.autoCompletionView,
            let cellHeight = self.autoCompletionView?.delegate?.tableView?(autoCompletionView, heightForRowAt: IndexPath(row: 0, section: 0)) else {
                return 0
        }

        return cellHeight * CGFloat(searchResult.count)
    }

}

extension MessageViewController {

    // MARK: - Example's Configuration

    func configureDataSource() {
        let words = Int((arc4random() % 40)+1)
        guard let name = LoremIpsum.name(),
            let text = LoremIpsum.words(withNumber: words) else {
                return
        }

        var array = [Message]()

        for _ in 0..<100 {
            let message = Message(username: name, text: text)
            array.append(message)
        }

        let reversed = array.reversed()

        messages.append(contentsOf: reversed)
    }

    func configureActionItems() {

        let arrowItem = UIBarButtonItem(image: UIImage(named: "icn_arrow_down"), style: .plain, target: self, action: #selector(MessageViewController.hideOrShowTextInputbar(_:)))
        let editItem = UIBarButtonItem(image: UIImage(named: "icn_editing"), style: .plain, target: self, action: #selector(MessageViewController.editRandomMessage(_:)))
        let typeItem = UIBarButtonItem(image: UIImage(named: "icn_typing"), style: .plain, target: self, action: #selector(MessageViewController.simulateUserTyping(_:)))
        let appendItem = UIBarButtonItem(image: UIImage(named: "icn_append"), style: .plain, target: self, action: #selector(MessageViewController.fillWithText(_:)))
        let pipItem = UIBarButtonItem(image: UIImage(named: "icn_pic"), style: .plain, target: self, action: #selector(MessageViewController.togglePIPWindow(_:)))
        self.navigationItem.rightBarButtonItems = [arrowItem, pipItem, editItem, appendItem, typeItem]
    }

    // MARK: - Action Methods

    func hideOrShowTextInputbar(_ sender: AnyObject) {

        guard let buttonItem = sender as? UIBarButtonItem else {
            return
        }

        let hide = !self.isTextInputbarHidden
        let image = hide ? UIImage(named: "icn_arrow_up") : UIImage(named: "icn_arrow_down")

        setTextInputbarHidden(hide, animated: true)
        buttonItem.image = image
    }

    func fillWithText(_ sender: AnyObject) {

        if textView.text.characters.count == 0 {
            var sentences = Int(arc4random() % 4)
            if sentences <= 1 {
                sentences = 1
            }
            textView.text = LoremIpsum.sentences(withNumber: sentences)
        } else {
            textView.slk_insertTextAtCaretRange(" " + LoremIpsum.word())
        }
    }

    func simulateUserTyping(_ sender: AnyObject) {

        if !self.canShowTypingIndicator() {
            return
        }

        if DEBUG_CUSTOM_TYPING_INDICATOR == true {
            guard let indicatorView = typingIndicatorProxyView as? TypingIndicatorView else {
                return
            }

            let scale = UIScreen.main.scale
            let imgSize = CGSize(width: kTypingIndicatorViewAvatarHeight * scale, height: kTypingIndicatorViewAvatarHeight * scale)

            // This will cause the typing indicator to show after a delay ¯\_(ツ)_/¯
            LoremIpsum.asyncPlaceholderImage(with: imgSize, completion: { (image) -> Void in
                guard let cgImage = image?.cgImage else {
                    return
                }
                let thumbnail = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
                indicatorView.presentIndicator(name: LoremIpsum.name(), image: thumbnail)
            })
        } else {
            typingIndicatorView?.insertUsername(LoremIpsum.name())
        }
    }

    func didLongPressCell(_ gesture: UIGestureRecognizer) {

        guard let view = gesture.view else {
            return
        }

        if gesture.state != .began {
            return
        }

        if #available(iOS 8, *) {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alertController.modalPresentationStyle = .popover
            alertController.popoverPresentationController?.sourceView = view.superview
            alertController.popoverPresentationController?.sourceRect = view.frame

            alertController.addAction(UIAlertAction(title: "Edit Message", style: .default, handler: { [unowned self] (_) -> Void in
                self.editCellMessage(gesture)
            }))

            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            self.navigationController?.present(alertController, animated: true, completion: nil)
        } else {
            self.editCellMessage(gesture)
        }
    }

    func editCellMessage(_ gesture: UIGestureRecognizer) {

        guard let messageCell = gesture.view as? MessageTableViewCell,
        let indexPath = messageCell.indexPath else {
            return
        }

        editingMessage = messages[indexPath.row]
            editText(editingMessage.text)

        tableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    func editRandomMessage(_ sender: AnyObject) {

        var sentences = Int(arc4random() % 10)

        if sentences <= 1 {
            sentences = 1
        }

        self.editText(LoremIpsum.sentences(withNumber: sentences))
    }

    func editLastMessage(_ sender: AnyObject?) {

        if textView.text.characters.count > 0 {
            return
        }

        guard let tableView = self.tableView,
            textView.text.characters.count == 0 else {
                return
        }

        let lastSectionIndex = tableView.numberOfSections-1
        let lastRowIndex = tableView.numberOfRows(inSection: lastSectionIndex)-1

        let lastMessage = messages[lastRowIndex]

        self.editText(lastMessage.text)

        tableView.scrollToRow(at: IndexPath(row: lastRowIndex, section: lastSectionIndex), at: .bottom, animated: true)
    }

    func togglePIPWindow(_ sender: AnyObject) {

        if pipWindow == nil {
            showPIPWindow(sender)
        } else {
            hidePIPWindow(sender)
        }
    }

    func showPIPWindow(_ sender: AnyObject) {

        var frame = CGRect(x: view.frame.width - 60.0, y: 0.0, width: 50.0, height: 50.0)
        frame.origin.y = textInputbar.frame.minY - 60.0

        pipWindow = UIWindow(frame: frame)
        pipWindow?.backgroundColor = UIColor.black
        pipWindow?.layer.cornerRadius = 10
        pipWindow?.layer.masksToBounds = true
        pipWindow?.isHidden = false
        pipWindow?.alpha = 0.0

        UIApplication.shared.keyWindow?.addSubview(self.pipWindow!)

        UIView.animate(withDuration: 0.25, animations: { [unowned self] () -> Void in
            self.pipWindow?.alpha = 1.0
        })
    }

    func hidePIPWindow(_ sender: AnyObject) {

        UIView.animate(withDuration: 0.3, animations: { [unowned self] () -> Void in
            self.pipWindow?.alpha = 0.0
            }, completion: { [unowned self] (_) -> Void in
                self.pipWindow?.isHidden = true
                self.pipWindow = nil
        })
    }

    func textInputbarDidMove(_ note: Notification) {

        guard let pipWindow = self.pipWindow else {
            return
        }

        guard let userInfo = (note as NSNotification).userInfo else {
            return
        }

        guard let value = userInfo["origin"] as? NSValue else {
            return
        }

        var frame = pipWindow.frame
        frame.origin.y = value.cgPointValue.y - 60.0

        pipWindow.frame = frame
    }

}

// MARK: - UITableViewDataSource & UIScrollViewDelegate
extension MessageViewController {

    // MARK: - UITableViewDataSource Methods

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if tableView == self.tableView {
            return self.messages.count
        } else {
            if let searchResult = self.searchResult {
                return searchResult.count
            }
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if tableView == self.tableView {
            return self.messageCellForRowAtIndexPath(indexPath)
        } else {
            return self.autoCompletionCellForRowAtIndexPath(indexPath)
        }
    }

    func messageCellForRowAtIndexPath(_ indexPath: IndexPath) -> MessageTableViewCell {

        guard let cell = self.tableView?.dequeueReusableCell(withIdentifier: MessageTableViewCell.kMessengerCellIdentifier) as? MessageTableViewCell else {
            return MessageTableViewCell()
        }

        if cell.gestureRecognizers?.count == nil {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MessageViewController.didLongPressCell(_:)))
            cell.addGestureRecognizer(longPress)
        }

        let message = self.messages[indexPath.row]

        cell.titleLabel?.text = message.username
        cell.bodyLabel?.text = message.text

        cell.indexPath = indexPath
        cell.isUsedForMessage = true

        // Cells must inherit the table view's transform
        // This is very important, since the main table view may be inverted
        if let tableView = self.tableView {
            cell.transform = tableView.transform
        }

        return cell
    }

    func autoCompletionCellForRowAtIndexPath(_ indexPath: IndexPath) -> MessageTableViewCell {

        guard let cell = self.autoCompletionView?.dequeueReusableCell(withIdentifier: MessageTableViewCell.kAutoCompletionCellIdentifier) as? MessageTableViewCell else {
            return MessageTableViewCell()
        }
        cell.indexPath = indexPath
        cell.selectionStyle = .default

        guard let searchResult = self.searchResult else {
            return cell
        }

        guard let prefix = self.foundPrefix else {
            return cell
        }

        var text = searchResult[(indexPath as NSIndexPath).row]

        if prefix == "#" {
            text = "# " + text
        } else if prefix == ":" || prefix == "+:" {
            text = ":\(text):"
        }

        cell.titleLabel?.text = text

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        if tableView == self.tableView {
            let message = self.messages[(indexPath as NSIndexPath).row]

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.alignment = .left

            let pointSize = MessageTableViewCell.defaultFontSize

            let attributes = [
                NSFontAttributeName: UIFont.systemFont(ofSize: pointSize),
                NSParagraphStyleAttributeName: paragraphStyle
            ]

            var width = tableView.frame.width-kMessageTableViewCellAvatarHeight
            width -= 25.0

            let titleBounds = (message.username as NSString).boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            let bodyBounds = (message.text as NSString).boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: nil)

            if message.text.isEmpty {
                return 0
            }

            var height = titleBounds.height
            height += bodyBounds.height
            height += 40

            if height < kMessageTableViewCellMinimumHeight {
                height = kMessageTableViewCellMinimumHeight
            }

            return height
        } else {
            return kMessageTableViewCellMinimumHeight
        }
    }

    // MARK: - UITableViewDelegate Methods

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if tableView == self.autoCompletionView {

            guard let searchResult = self.searchResult else {
                return
            }

            var item = searchResult[(indexPath as NSIndexPath).row]

            if self.foundPrefix == "@" && self.foundPrefixRange.location == 0 {
                item += ":"
            } else if self.foundPrefix == ":" || self.foundPrefix == "+:" {
                item += ":"
            }

            item += " "

            acceptAutoCompletion(string: item, keepPrefix: true)
        }
    }
}

// MARK: - UIScrollViewDelegate Methods
extension MessageViewController {

    // Since SLKTextViewController uses UIScrollViewDelegate to update a few things, it is important that if you override this method, to call super.
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
    }

}

// MARK: - UITextViewDelegate Methods
extension MessageViewController {

    override func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }

    override func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        // Since SLKTextViewController uses UIScrollViewDelegate to update a few things, it is important that if you override this method, to call super.
        return true
    }

    override func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        return super.textView(textView, shouldChangeTextIn: range, replacementText: text)
    }

    override func textView(_ textView: SLKTextView, shouldOfferFormattingFor symbol: String) -> Bool {

        if symbol == ">" {
            let selection = textView.selectedRange

            // The Quote formatting only applies new paragraphs
            if selection.location == 0 && selection.length > 0 {
                return true
            }

            // or older paragraphs too
            let prevString = (textView.text as NSString).substring(with: NSRange(location: selection.location-1, length: 1))

            if CharacterSet.newlines.contains(UnicodeScalar((prevString as NSString).character(at: 0))!) {
                return true
            }

            return false
        }

        return super.textView(textView, shouldOfferFormattingFor: symbol)
    }

    override func textView(_ textView: SLKTextView, shouldInsertSuffixForFormattingWith symbol: String, prefixRange: NSRange) -> Bool {

        if symbol == ">" {
            return false
        }

        return super.textView(textView, shouldInsertSuffixForFormattingWith: symbol, prefixRange: prefixRange)
    }
}
