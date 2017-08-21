//
//  MessageTableViewCell.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 21/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit

let kMessageTableViewCellMinimumHeight: CGFloat = 50.0
let kMessageTableViewCellAvatarHeight: CGFloat = 30.0

class MessageTableViewCell: UITableViewCell {

    static let kMessengerCellIdentifier = "MessengerCell"
    static let kAutoCompletionCellIdentifier = "AutoCompletionCell"

    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = .clear
        titleLabel.isUserInteractionEnabled = false
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .gray
        titleLabel.font = .boldSystemFont(ofSize: MessageTableViewCell.defaultFontSize)
        return titleLabel
    }()

    lazy var bodyLabel: UILabel = {
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.backgroundColor = .clear
        bodyLabel.isUserInteractionEnabled = false
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .darkGray
        bodyLabel.font = .systemFont(ofSize: MessageTableViewCell.defaultFontSize)
        return bodyLabel
    }()

    lazy var thumbnailView: UIImageView = {
        let thumbnailView = UIImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.isUserInteractionEnabled = false
        thumbnailView.backgroundColor = UIColor(white: 0.9, alpha: 1)

        thumbnailView.layer.cornerRadius = kMessageTableViewCellAvatarHeight / 2.0
        thumbnailView.layer.masksToBounds = true
        return thumbnailView
    }()

    var indexPath: IndexPath?

    var isUsedForMessage = false

    static var defaultFontSize: CGFloat {
        var pointSize: CGFloat = 16.0

        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        pointSize += slk_pointSizeDifference(for: contentSizeCategory)

        return pointSize
    }

    override func awakeFromNib() {
        super.awakeFromNib()

    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .white

        configureSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.selectionStyle = .none

        let pointSize = MessageTableViewCell.defaultFontSize

        titleLabel.font = .boldSystemFont(ofSize: pointSize)
        bodyLabel.font = .systemFont(ofSize: pointSize)

        titleLabel.text = ""
        bodyLabel.text = ""
    }

    private func configureSubviews() {
        contentView.addSubview(thumbnailView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bodyLabel)

        let views: [String: Any] = ["thumbnailView": thumbnailView,
                                    "titleLabel": titleLabel,
                                    "bodyLabel": bodyLabel]

        let metrics = ["tumbSize": kMessageTableViewCellAvatarHeight,
                       "padding": 15,
                       "right": 10,
                       "left": 5]

        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-left-[thumbnailView(tumbSize)]-right-[titleLabel(>=0)]-right-|", options: [], metrics: metrics, views: views))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-left-[thumbnailView(tumbSize)]-right-[bodyLabel(>=0)]-right-|", options: [], metrics: metrics, views: views))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-right-[thumbnailView(tumbSize)]-(>=0)-|", options: [], metrics: metrics, views: views))

        if reuseIdentifier == MessageTableViewCell.kMessengerCellIdentifier {

            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-right-[titleLabel(20)]-left-[bodyLabel(>=0@999)]-left-|", options: [], metrics: metrics, views: views))

        } else {
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[titleLabel]|", options: [], metrics: metrics, views: views))
        }
    }

}
