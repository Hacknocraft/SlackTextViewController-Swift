//
//  SLKTextInputbar.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 16/06/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

enum SLKCounterStyle {
    case none
    case split
    case countdown
    case countdownReversed
}

enum SLKCounterPosition {
    case top
    case bottom
}

let SLKTextInputbarDidMoveNotification = "SLKTextInputbarDidMoveNotification"

/// A custom tool bar encapsulating messaging controls
class SLKTextInputbar: UIToolbar {

    // MARK: - Public properties

    /** The centered text input view.
     The maximum number of lines is configured by default, to best fit each devices dimensions.
     - For iPhone 4       (<=480pts): 4 lines
     - For iPhone 5 & 6   (>=568pts): 6 lines
     - For iPad           (>=768pts): 8 lines
     */
    lazy var textView: SLKTextView = {
        let textView = SLKTextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 15)
        textView.keyboardType = .twitter
        textView.returnKeyType = .default
        textView.enablesReturnKeyAutomatically = true
        textView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 1)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 0)
        textView.layer.cornerRadius = 5
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor(red: 200.0/255.0, green: 200.0/255.0, blue: 205.0/255.0, alpha: 1).cgColor
        return textView
    }()

    /// Optional view to host outlets under the text view, adjusting its height based on its subviews. Non-visible by default. Subviews' layout should be configured using auto-layout as well.
    lazy var contentView: UIView = {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = true
        return contentView
    }()

    /// The custom input accessory view, used as empty achor view to detect the keyboard frame
    override var inputAccessoryView: SLKInputAccessoryView? {
        let inputAccessoryView = SLKInputAccessoryView(frame: .zero)
        inputAccessoryView.backgroundColor = .clear
        inputAccessoryView.isUserInteractionEnabled = false
        return inputAccessoryView
    }

    /// The left action button action
    lazy var leftButton: UIButton = {
        let leftButton = UIButton(type: .system)
        leftButton.translatesAutoresizingMaskIntoConstraints = false
        leftButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        return leftButton
    }()

    /// The right action button action
    lazy var rightButton: UIButton = {
        let rightButton = UIButton(type: .system)
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        rightButton.isEnabled = false

        let title = NSLocalizedString("Send", comment: "")
        rightButton.setTitle(title, for: .normal)

        return rightButton
    }()

    /// YES if the right button should be hidden animatedly in case the text view has no text in it. Default is YES
    var autoHideRightButton: Bool {
        get {
            return _autoHideRightButton
        }
        set {
            if _autoHideRightButton == newValue { return }

            _autoHideRightButton = newValue

            rightButtonWC.constant =  slk_appropriateRightButtonWidth
            rightMarginWC.constant = slk_appropriateRightButtonMargin

            layoutIfNeeded()
        }
    }
    private var _autoHideRightButton = true

    /// YES if animations should have bouncy effects. Default is YES
    var bounces = true

    /// The inner padding to use when laying out content in the view. Default is {5, 8, 5, 8}
    var contentInset: UIEdgeInsets {
        get {
            return _contentInset
        }
        set {
            if _contentInset == newValue { return }

            _contentInset = newValue

            if _contentInset == .zero { return }

            // Add new constraints
            removeConstraints(constraints)
            slk_setupViewConstraints()

            // Add constant values and refresh layout
            slk_updateConstraintConstants()

            super.layoutIfNeeded()
        }
    }
    private var _contentInset = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)

    /// The minimum height based on the intrinsic content size's
    var minimumInputbarHeight: CGFloat {
        var minimumHeight = textView.intrinsicContentSize.height
        minimumHeight += contentInset.top
        minimumHeight += slk_bottomMargin
        return minimumHeight
    }

    /// The most appropriate height calculated based on the amount of lines of text and other factors
    var appropriateHeight: CGFloat {
        var height: CGFloat = 0.0
        let minimumHeight = minimumInputbarHeight

        if textView.numberOfLines == 1 {
            height = minimumHeight
        } else if textView.numberOfLines < textView.maxNumberOfLines {
            height = slk_inputBarHeightForLines(textView.numberOfLines)
        } else {
            height = slk_inputBarHeightForLines(textView.maxNumberOfLines)
        }

        if height < minimumHeight {
            height = minimumHeight
        }

        if isEditing {
            height += self.editorContentViewHeight
        }

        return CGFloat(roundf(Float(height)))
    }

    // MARK: - Text Editing

    /// The view displayed on top if the text input bar, containing the button outlets, when editing is enabled
    var editorContentView: UIView!

    /// The title label displayed in the middle of the accessoryView
    lazy var editorTitle: UILabel = {
        let editorTitle = UILabel()
        editorTitle.translatesAutoresizingMaskIntoConstraints = false
        editorTitle.textAlignment = .center
        editorTitle.backgroundColor = .clear
        editorTitle.font = UIFont.boldSystemFont(ofSize: 15)
        editorTitle.text = NSLocalizedString("Editing Message", comment: "")
        return editorTitle
    }()

    /// The 'cancel' button displayed left in the accessoryView
    lazy var editorLeftButton: UIButton = {
        let editorLeftButton = UIButton(type: .system)
        editorLeftButton.translatesAutoresizingMaskIntoConstraints = false
        editorLeftButton.contentHorizontalAlignment = .left
        editorLeftButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)

        let title = NSLocalizedString("Cancel", comment: "")
        editorLeftButton.setTitle(title, for: .normal)

        return editorLeftButton
    }()

    /// The 'accept' button displayed right in the accessoryView
    lazy var editorRightButton: UIButton = {
        let editorRightButton = UIButton(type: .system)
        editorRightButton.translatesAutoresizingMaskIntoConstraints = false
        editorRightButton.contentHorizontalAlignment = .right
        editorRightButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        editorRightButton.isEnabled = false

        let title = NSLocalizedString("Save", comment: "")
        editorRightButton.setTitle(title, for: .normal)

        return editorRightButton
    }()

    /// The accessory view's maximum height. Default is 38 pts
    var editorContentViewHeight: CGFloat = 38

    /// A Boolean value indicating whether the control is in edit mode
    var isEditing: Bool {
        get {
            return _isEditing
        }
        set {
            if _isEditing == newValue { return }

            _isEditing = newValue
            editorContentView.isHidden = !_isEditing

            contentViewHC.isActive = _isEditing

            setNeedsLayout()
            super.layoutIfNeeded()
        }
    }
    private var _isEditing = false

    /// The label used to display the character counts
    lazy var charCountLabel: UILabel = {
        let charCountLabel = UILabel()
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false
        charCountLabel.backgroundColor = .clear
        charCountLabel.textAlignment = .right
        charCountLabel.font = UIFont.systemFont(ofSize: 11)
        charCountLabel.isHidden = false
        return charCountLabel
    }()

    /// The maximum character count allowed. If larger than 0, a character count label will be displayed on top of the right button. Default is 0, which means limitless
    var maxCharCount = 0

    /// The character counter formatting. Ignored if maxCharCount is 0. Default is None
    var counterStyle: SLKCounterStyle = .none

    /// The character counter layout style. Ignored if maxCharCount is 0. Default is SLKCounterPositionTop
    var counterPosition: SLKCounterPosition {
        get {
            return _counterPosition
        }
        set {
            if _counterPosition == newValue, charCountLabelVCs != nil {
                return
            }
            _counterPosition = newValue

            // Clears the previous constraints
            if let vcs = charCountLabelVCs, vcs.count > 0 {
                removeConstraints(vcs)
                charCountLabelVCs = nil
            }

            let views: [String: Any] = ["rightButton": self.rightButton,
                                      "charCountLabel": self.charCountLabel]
            let metrics = ["top": self.contentInset.top,
                           "bottom": -self.slk_bottomMargin/2.0]

            // Constraints are different depending of the counter's position type
            if counterPosition == .bottom {
                charCountLabelVCs = NSLayoutConstraint.constraints(withVisualFormat: "V:[charCountLabel]-(bottom)-[rightButton]", options: [], metrics: metrics, views: views)
            } else {
                charCountLabelVCs = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(top@750)-[charCountLabel]-(>=0)-|", options: [], metrics: metrics, views: views)
            }

            addConstraints(charCountLabelVCs!)
        }
    }

    private var _counterPosition: SLKCounterPosition = .top

    /// YES if the maxmimum character count has been exceeded
    var limitExceeded: Bool {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if maxCharCount > 0 && text.length > maxCharCount {
            return true
        }
        return false
    }

    /// The normal color used for character counter label. Default is lightGrayColor
    var charCountLabelNormalColor: UIColor = .lightGray

    /// The color used for character counter label when it has exceeded the limit. Default is redColor
    var charCountLabelWarningColor: UIColor = .red

    // MARK: - Private properties

    private var textViewBottomMarginC: NSLayoutConstraint!
    private var contentViewHC: NSLayoutConstraint!
    private var leftButtonWC: NSLayoutConstraint!
    private var leftButtonHC: NSLayoutConstraint!
    private var leftMarginWC: NSLayoutConstraint!
    private var leftButtonBottomMarginC: NSLayoutConstraint!
    private var rightButtonWC: NSLayoutConstraint!
    private var rightMarginWC: NSLayoutConstraint!
    private var rightButtonTopMarginC: NSLayoutConstraint!
    private var rightButtonBottomMarginC: NSLayoutConstraint!
    private var editorContentViewHC: NSLayoutConstraint!
    private var charCountLabelVCs: [NSLayoutConstraint]?

    private var _charCountLabel: UILabel!
    private var previousOrigin: CGPoint = .zero
    private var textViewClass: AnyClass?

    // MARK: - Initialization

    init(textViewClass: AnyClass?) {
        self.textViewClass = textViewClass
        super.init(frame: .zero)
        slk_commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        slk_commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        slk_commonInit()
    }

    private func slk_commonInit() {
        addEditorContentView()

        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(textView)
        addSubview(charCountLabel)
        addSubview(contentView)

        slk_setupViewConstraints()
        slk_updateConstraintConstants()

        counterStyle = .none
        counterPosition = .top

        slk_registerNotifications()

        slk_registerTo(layer, forKeyPath: "path")
        slk_registerTo(leftButton.imageView, forKeyPath: "image")
        slk_registerTo(rightButton.titleLabel, forKeyPath: "font")
    }

    // MARK: - UIView Overrides

    override func layoutIfNeeded() {
        if constraints.count == 0 || window == nil {
            return
        }

        slk_updateConstraintConstants()
        super.layoutIfNeeded()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: minimumInputbarHeight)
    }

    override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    // MARK: - Add Subviews

    private func addEditorContentView() {
        editorContentView = UIView()
        editorContentView.translatesAutoresizingMaskIntoConstraints = false
        editorContentView.backgroundColor = backgroundColor
        editorContentView.clipsToBounds = true
        editorContentView.isHidden = true

        editorContentView.addSubview(editorTitle)
        editorContentView.addSubview(editorLeftButton)
        editorContentView.addSubview(editorRightButton)

        let views: [String: Any] = ["label": editorTitle,
                     "leftButton": editorLeftButton,
                     "rightButton": editorRightButton
        ]

        let metrics = ["left": contentInset.left,
                       "right": contentInset.right
        ]

        editorContentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(left)-[leftButton(60)]-(left)-[label(>=0)]-(right)-[rightButton(60)]-(<=right)-|", options: [], metrics: metrics, views: views))
        editorContentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[leftButton]|", options: [], metrics: metrics, views: views))
        editorContentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[rightButton]|", options: [], metrics: metrics, views: views))
        editorContentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|", options: [], metrics: metrics, views: views))

        addSubview(editorContentView)
    }

    // MARK: - Getters

    private func slk_inputBarHeightForLines(_ numberOfLines: Int) -> CGFloat {
        var height = textView.intrinsicContentSize.height
        if let font = textView.font {
            height -= font.lineHeight
            height += CGFloat(roundf(Float(font.lineHeight) * Float(numberOfLines)))
        }
        height += contentInset.top
        height += slk_bottomMargin
        return height
    }

    private var slk_bottomMargin: CGFloat {
        var margin = contentInset.bottom
        margin += slk_contentViewHeight
        return margin
    }

    private var slk_contentViewHeight: CGFloat {
        if !self.isEditing {
            return contentView.frame.height
        }
        return 0.0
    }

    private var slk_appropriateRightButtonWidth: CGFloat {
        if autoHideRightButton {
            if self.textView.text.length == 0 {
                return 0.0
            }
        }
        return rightButton.intrinsicContentSize.width
    }

    private var slk_appropriateRightButtonMargin: CGFloat {
        if autoHideRightButton {
            if textView.text.length == 0 {
                return 0.0
            }
        }
        return contentInset.right
    }

    // MARK: - Setters

    override var backgroundColor: UIColor? {
        didSet {
            barTintColor = backgroundColor
            editorContentView.backgroundColor = backgroundColor
        }
    }

    override var isHidden: Bool {
        // We don't call super here, since we want to avoid to visually hide the view.
        // The hidden render state is handled by the view controller.
        didSet {
            if !isEditing {
                self.contentViewHC.isActive = isHidden

                super.setNeedsLayout()
                super.layoutIfNeeded()
            }
        }
    }

    // MARK: - Text Editing

    /// Verifies if the text can be edited
    /// - Parameters:
    ///   - text: The text to be edited
    /// - Returns:
    /// YES if the text is editable
    func canEditText(_ text: String) -> Bool {
        if isEditing && self.textView.text == text || isHidden {
            return false
        }

        return true
    }

    ///  Begins editing the text, by updating the 'editing' flag and the view constraints.
    func beginTextEditing() {
        if isEditing || isHidden {
            return
        }

        isEditing = true

        slk_updateConstraintConstants()

        if !self.isFirstResponder {
            layoutIfNeeded()
        }
    }

    /// End editing the text, by updating the 'editing' flag and the view constraints
    func endTextEdition() {
        if !isEditing || isHidden {
            return
        }

        isEditing = false
        slk_updateConstraintConstants()
    }

    // MARK: - Character Counter

    private func slk_updateCounter() {
        let text = textView.text.trimmingCharacters(in: .newlines)

        var counter = ""

        if self.counterStyle == .none {
            counter = "\(text.length)"
        }
        if self.counterStyle == .split {
            counter = "\(text.length)/\(maxCharCount)"
        }
        if self.counterStyle == .countdown {
            counter = "\(text.length - maxCharCount)"
        }
        if self.counterStyle == .countdownReversed {
            counter = "\(maxCharCount - text.length)"
        }

        charCountLabel.text = counter
        charCountLabel.textColor = limitExceeded ? charCountLabelWarningColor : charCountLabelNormalColor
    }

    // MARK: - Notification Events

    @objc private func slk_didChangeTextViewText(_ noti: Notification) {
        guard let textView = noti.object as? SLKTextView,
            textView === self.textView else {
                return
        }

        // Updates the char counter label
        if maxCharCount > 0 {
            slk_updateCounter()
        }

        if autoHideRightButton && !isEditing {
            // Only updates if the width did change
            if rightButtonWC.constant == slk_appropriateRightButtonWidth {
                return
            }

            rightButtonWC.constant = slk_appropriateRightButtonWidth
            rightMarginWC.constant = slk_appropriateRightButtonMargin
            rightButton.layoutIfNeeded() // Avoids the right button to stretch when animating the constraint changes

            let bounces = self.bounces && self.textView.isFirstResponder

            if window != nil {
                slk_animateLayoutIfNeeded(bounce: bounces, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction], animations: nil)
            } else {
                layoutIfNeeded()
            }
        }
    }

    @objc private func slk_didChangeTextViewContentSize(_ noti: Notification) {
        if maxCharCount > 0 {
            let shouldHide = textView.numberOfLines == 1 || isEditing
            charCountLabel.isHidden = shouldHide
        }
    }

    @objc private func slk_didChangeContentSizeCategory(_ noti: Notification) {
        if !textView.isDynamicTypeEnabled {
            return
        }

        layoutIfNeeded()
    }

    // MARK: - View Auto-Layout

    private func slk_setupViewConstraints() {
        let views: [String: Any] = ["textView": self.textView,
                                    "leftButton": self.leftButton,
                                    "rightButton": self.rightButton,
                                    "editorContentView": self.editorContentView,
                                    "charCountLabel": self.charCountLabel,
                                    "contentView": self.contentView]

        let metrics = ["top": self.contentInset.top,
                       "left": self.contentInset.left,
                       "right": self.contentInset.right]

        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(left)-[leftButton(0)]-(<=left)-[textView]-(right)-[rightButton(0)]-(right)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[leftButton(0)]-(0@750)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[rightButton]-(<=0)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(left@250)-[charCountLabel(<=50@1000)]-(right@750)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[editorContentView(0)]-(<=top)-[textView(0@999)]-(0)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[editorContentView]|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[contentView(0)]|", options: [], metrics: metrics, views: views))

        textViewBottomMarginC = slk_constraintForAttribute(.bottom, firstItem: self, secondItem: textView)
        editorContentViewHC = slk_constraintForAttribute(.height, firstItem: editorContentView, secondItem: nil)
        contentViewHC = slk_constraintForAttribute(.height, firstItem: contentView, secondItem: nil)
        contentViewHC.isActive = false // Disabled by default, so the height is calculated with the height of its subviews

        leftButtonWC = slk_constraintForAttribute(.width, firstItem: leftButton, secondItem: nil)
        leftButtonHC = slk_constraintForAttribute(.height, firstItem: leftButton, secondItem: nil)
        leftButtonBottomMarginC = slk_constraintForAttribute(.bottom, firstItem: self, secondItem: leftButton)
        leftMarginWC = slk_constraintsForAttribute(.leading).first

        rightButtonWC = slk_constraintForAttribute(.width, firstItem: rightButton, secondItem: nil)
        rightMarginWC = slk_constraintsForAttribute(.trailing).first
        rightButtonTopMarginC = slk_constraintForAttribute(.top, firstItem: rightButton, secondItem: self)
        rightButtonBottomMarginC = slk_constraintForAttribute(.bottom, firstItem: self, secondItem: rightButton)
    }

    private func slk_updateConstraintConstants() {
        let zero: CGFloat = 0
        textViewBottomMarginC.constant = slk_bottomMargin

        if isEditing {
            editorContentViewHC.constant = editorContentViewHeight

            leftButtonWC.constant = zero
            leftButtonHC.constant = zero
            leftMarginWC.constant = zero
            leftButtonBottomMarginC.constant = zero
            rightButtonWC.constant = zero
            rightMarginWC.constant = zero
        } else {
            self.editorContentViewHC.constant = zero

            guard let leftButtonSize = leftButton.image(for: leftButton.state)?.size else {
                return
            }

            if leftButtonSize.width > 0 {
                self.leftButtonHC.constant = CGFloat(roundf(Float(leftButtonSize.height)))
                self.leftButtonBottomMarginC.constant = CGFloat(roundf(Float((self.intrinsicContentSize.height - leftButtonSize.height) / 2.0))) + self.slk_contentViewHeight / 2.0
            }

            leftButtonWC.constant = CGFloat(roundf(Float(leftButtonSize.width)))
            leftMarginWC.constant = (leftButtonSize.width > 0) ? self.contentInset.left : zero

            rightButtonWC.constant = slk_appropriateRightButtonWidth
            rightMarginWC.constant = slk_appropriateRightButtonMargin

            let rightVerMargin = (self.intrinsicContentSize.height - self.slk_contentViewHeight - self.rightButton.intrinsicContentSize.height) / 2.0
            let rightVerBottomMargin = rightVerMargin + self.slk_contentViewHeight

            rightButtonTopMarginC.constant = rightVerMargin
            rightButtonBottomMarginC.constant = rightVerBottomMargin
        }
    }

    // MARK: - Observers

    private func slk_registerTo( _ object: AnyObject?, forKeyPath keyPath: String) {
        guard let object = object else { return }
        object.addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: nil)
    }

    private func slk_unregisterFrom(_ object: AnyObject?, forKeyPath keyPath: String) {
        guard let object = object else { return }
        object.removeObserver(self, forKeyPath: keyPath)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let object = object else { return }

        if let obj = object as? CALayer, obj === layer && keyPath == "position" {
            if previousOrigin != frame.origin {
                previousOrigin = frame.origin
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: SLKTextInputbarDidMoveNotification), object: self, userInfo: ["origin": NSValue(cgPoint: previousOrigin)])
            }
        } else if let obj = object as? UIImageView, obj === leftButton.imageView && keyPath == "image" {

            let newImage = change?[.newKey] as? UIImage
            let oldImage = change?[.oldKey] as? UIImage

            if newImage != oldImage {
                slk_updateConstraintConstants()
            }

        } else if let obj = object as? UILabel, obj === rightButton.titleLabel && keyPath == "font" {
            slk_updateConstraintConstants()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - NSNotificationCenter registration

    private func slk_registerNotifications() {
        slk_unregisterNotifications()

        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeTextViewText(_:)), name: NSNotification.Name.UITextViewTextDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeTextViewContentSize(_:)), name: NSNotification.Name(rawValue: SLKTextViewContentSizeDidChangeNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(slk_didChangeContentSizeCategory(_:)), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }

    private func slk_unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UITextViewTextDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: SLKTextViewContentSizeDidChangeNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }

    // MARK: - deinit

    deinit {
        slk_unregisterNotifications()

        slk_unregisterFrom(layer, forKeyPath: "position")
        slk_unregisterFrom(leftButton.imageView, forKeyPath: "image")
        slk_unregisterFrom(rightButton.titleLabel, forKeyPath: "font")
    }

}
