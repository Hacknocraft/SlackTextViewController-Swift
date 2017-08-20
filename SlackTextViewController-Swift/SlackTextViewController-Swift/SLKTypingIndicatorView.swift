//
//  SLKTypingIndicatorView.swift
//  SlackTextViewController-Swift
//
//  Created by 曾文志 on 17/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

class SLKTypingIndicatorView: SLKBaseTypingIndicatorView {

    // MARK: - Public Properties

    /// The amount of time a name should keep visible. If is zero, the indicator will not remove nor disappear automatically. Default is 6.0 seconds
    var interval: TimeInterval = 6.0

    /// If YES, the user can dismiss the indicator by tapping on it. Default is NO
    var canResignByTouch = false

    /// The color of the text. Default is grayColor
    var textColor: UIColor = .gray

    /// The font of the text. Default is system font, 12 pts
    var textFont: UIFont = .systemFont(ofSize: 12)

    /// The font to be used when matching a username string. Default is system bold font, 12 pts
    var highlightFont: UIFont = .boldSystemFont(ofSize: 12)

    /// The inner padding to use when laying out content in the view. Default is {10, 40, 10, 10}
    var contentInset: UIEdgeInsets {
        get {
            return _contentInset
        }
        set {
            if (_contentInset == newValue) || (newValue == .zero) { return }

            _contentInset = newValue
            slk_updateConstraintConstants()
        }
    }
    private var _contentInset = UIEdgeInsets(top: 10, left: 40, bottom: 10, right: 10)

    // MARK: - Private Properties

    private var SLKTypingIndicatorViewIdentifier: String {
        return "\(SLKTextViewControllerDomain).\(NSStringFromClass(type(of: self)))"
    }

    /// The text label used to display the typing indicator content
    private lazy var textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.backgroundColor = .clear
        textLabel.contentMode = .topLeft
        textLabel.isUserInteractionEnabled = false
        return textLabel
    }()

    private var usernames = [String]()
    private var timers = [Timer]()

    // Auto-Layout margin constraints used for updating their constants
    private var leftContraint: NSLayoutConstraint?
    private var rightContraint: NSLayoutConstraint?

    // MARK: - Initializers

    override init(frame: CGRect) {
        super.init(frame: frame)
        slk_commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        slk_commonInit()
    }

    private func slk_commonInit() {
        backgroundColor = .white

        addSubview(textLabel)
        slk_setupConstraints()
    }

    // MARK: - Public API

    func insertUsername(_ username: String?) {
        guard let username = username else { return }

        let isShowing = usernames.contains(username)

        if (interval > 0.0) {

            if isShowing, let timer = slk_timerWithIdentifier(username) {
                slk_invalidateTimer(timer)
            }
            let timer = Timer(timeInterval: interval,
                              target: self,
                              selector: #selector(slk_shouldRemoveUsername(_:)),
                              userInfo: [SLKTypingIndicatorViewIdentifier: username],
                              repeats: false)
            RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
            timers.append(timer)
        }

        if isShowing {
            return
        }

        usernames.append(username)

        self.textLabel.attributedText = attributedString

        self.isVisible = true
    }

    func removeUsername(_ username: String?) {
        guard let username = username,
            let nameIndex = usernames.index(of: username) else {
                return
        }
        usernames.remove(at: nameIndex)

        if (usernames.count > 0) {
            textLabel.attributedText = attributedString
        }
        else {
            isVisible = false
        }
    }

    // MARK: - SLKTypingIndicatorProtocol

    override var isVisible: Bool {
        get {
            return _isVisible
        }
        set {
            // Skip when updating the same value, specially to avoid inovking KVO unnecessary
            if _isVisible == newValue { return }

            // Required implementation for key-value observer compliance
            willChangeValue(forKey: "visible")
            _isVisible = newValue

            if !_isVisible {
                slk_invalidateTimers()
            }

            // Required implementation for key-value observer compliance
            didChangeValue(forKey: "visible")
        }
    }
    private var _isVisible = false

    override func dismissIndicator() {
        if isVisible {
            isVisible = false
        }
    }

    // MARK: - Getters

    private var attributedString: NSAttributedString? {
        guard usernames.count != 0,
            let firstObject = usernames.first,
            let lastObject = usernames.last else {
                return nil
        }

        var text = ""

        if (self.usernames.count == 1) {
            text = String(format: NSLocalizedString("%@ is typing", comment: ""), firstObject)
        }
        else if (self.usernames.count == 2) {
            text = String(format: NSLocalizedString("%@ & %@ are typing", comment: ""), firstObject, lastObject)
        }
        else if (self.usernames.count > 2) {
            text = NSLocalizedString("Several people are typing", comment: "")
        }

        let style  = NSMutableParagraphStyle()
        style.alignment = .left;
        style.lineBreakMode = .byTruncatingTail;
        style.minimumLineHeight = 10.0

        let attributes: [String: Any] = [NSFontAttributeName: textFont,
                                         NSForegroundColorAttributeName: textColor,
                                         NSParagraphStyleAttributeName: style]

        let attributedString = NSMutableAttributedString(string: text, attributes: attributes)

        if (self.usernames.count <= 2) {
            attributedString.addAttribute(NSFontAttributeName, value: highlightFont, range: text.nsRange(of: firstObject))
            attributedString.addAttribute(NSFontAttributeName, value: highlightFont, range: text.nsRange(of: lastObject))
        }

        return attributedString
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: height)
    }

    private var height: CGFloat {
        var height = textFont.lineHeight
        height += contentInset.top
        height += contentInset.bottom
        return height
    }

    // MARK: - Setters
    override var isHidden: Bool {
        get {
            return _isHidden
        }
        set {
            if _isHidden == newValue { return }

            if newValue {
                slk_prepareForReuse()
            }

            _isHidden = newValue
        }
    }
    private var _isHidden = false


    // MARK: - Private Methods

    @objc private func slk_shouldRemoveUsername(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: String], let username = userInfo[SLKTypingIndicatorViewIdentifier] else {
            return
        }
        removeUsername(username)
        slk_invalidateTimer(timer)
    }

    private func slk_timerWithIdentifier(_ identifier: String) -> Timer? {
        for timer in timers {
            if let userInfo = timer.userInfo as? [String: String],
                let username = userInfo[SLKTypingIndicatorViewIdentifier],
                identifier == username {
                return timer
            }
        }
        return nil
    }

    private func slk_invalidateTimer(_ timer: Timer) {
        timer.invalidate()
        timers.removeObject(timer)
    }

    private func slk_invalidateTimers() {
        timers.forEach { $0.invalidate() }
        timers.removeAll()
    }

    private func slk_prepareForReuse() {
        slk_invalidateTimers()
        textLabel.text = nil
        usernames.removeAll()
    }

    private func slk_setupConstraints() {
        let views: [String: Any] = ["textLabel": textLabel]

        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[textLabel]|", options: [], metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(0)-[textLabel]-(0@750)-|", options: [], metrics: nil, views: views))

        leftContraint = slk_constraintsForAttribute(.leading).first
        self.leftContraint = slk_constraintsForAttribute(.trailing).first

        slk_updateConstraintConstants()
    }

    private func slk_updateConstraintConstants() {
        leftContraint?.constant = contentInset.left
        rightContraint?.constant = contentInset.right
    }

    // MARK: - Hit Testing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if canResignByTouch {
            dismissIndicator()
        }
    }

    // MARK: - Lifeterm

    deinit {
        slk_invalidateTimers()
    }

}

// MARK: - SLKTypingIndicatorProtocol
protocol SLKTypingIndicatorProtocol: class {
    
    var isVisible: Bool {get set}
    
    func dismissIndicator()
}
