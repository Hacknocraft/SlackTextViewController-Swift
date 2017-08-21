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

    var titleLabel: UILabel?
    var bodyLabel: UILabel?
    var thumbnailView: UIImageView?
    var indexPath: IndexPath?

    var isUsedForMessage = false

    static var defaultFontSize: CGFloat {
        return 15
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
