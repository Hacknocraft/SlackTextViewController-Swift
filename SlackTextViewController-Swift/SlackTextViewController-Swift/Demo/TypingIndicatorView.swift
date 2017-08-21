//
//  TypingIndicatorView.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 21/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

let kTypingIndicatorViewMinimumHeight: CGFloat = 80.0
let kTypingIndicatorViewAvatarHeight: CGFloat = 30.0

class TypingIndicatorView: SLKBaseTypingIndicatorView {

    lazy var thumbnailView: UIImageView? = {
        let thumbnailView = UIImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.isUserInteractionEnabled = false
        thumbnailView.backgroundColor = .gray

        thumbnailView.layer.cornerRadius = kTypingIndicatorViewAvatarHeight / 2.0
        thumbnailView.layer.masksToBounds = true
        return thumbnailView
    }()

    lazy var titleLabel: UILabel? = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = .clear
        titleLabel.isUserInteractionEnabled = false
        titleLabel.numberOfLines = 1
        titleLabel.contentMode = .topLeft
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .lightGray
        return titleLabel
    }()

    lazy var backgroundGradient: CAGradientLayer? = self.makeBackgroundGradient()

    // MARK: - Initializations

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func configureSubviews() {
        addSubview(thumbnailView!)
        addSubview(titleLabel!)
        layer.insertSublayer(backgroundGradient!, at: 0)

        let views: [String: Any] = ["thumbnailView": thumbnailView!,
                                    "titleLabel": titleLabel!]
        let metrics = ["invertedThumbSize": -kTypingIndicatorViewAvatarHeight/2.0]

        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-5-[thumbnailView]-10-[titleLabel]-(>=0)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[thumbnailView]-(invertedThumbSize)-|", options: [], metrics: metrics, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[titleLabel]-(3@750)-|", options: [], metrics: metrics, views: views))
    }

    // MARK: - Override Methods

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundGradient!.frame = bounds
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: height)
    }

    // MARK: - Public API

    func presentIndicator(name: String, image: UIImage) {
        if isVisible || name.length == 0 {
            return
        }

        let text = String(format: "%@ is typing...", name)

        let attributedString = NSMutableAttributedString(string: text)

        attributedString.addAttributes([NSFontAttributeName: UIFont.boldSystemFont(ofSize: 12)], range: text.nsRange(of: name))

        titleLabel?.attributedText = attributedString
        thumbnailView?.image = image

        isVisible = true
    }

    // MARK: - Hit Testing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        dismissIndicator()
    }

    // MARK: - Lifeterm

    deinit {
        titleLabel = nil
        thumbnailView = nil
        backgroundGradient = nil
    }

    // MARK: - Getters

    private func makeBackgroundGradient() -> CAGradientLayer {
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.frame = CGRect(x: 0, y: 0, width: slkKeyWindowBounds.width, height: height)
        backgroundGradient.colors = [UIColor(white: 1, alpha: 0),
                                     UIColor(white: 1, alpha: 0.9),
                                     UIColor(white: 1, alpha: 1)]
        backgroundGradient.locations = [0, 0.5, 1]

        return backgroundGradient
    }

    var height: CGFloat {
        return 0
    }

    // MARK: - SLKTypingIndicatorProtocol

    override func dismissIndicator() {
        if isVisible {
            isVisible = false
        }
    }

}
