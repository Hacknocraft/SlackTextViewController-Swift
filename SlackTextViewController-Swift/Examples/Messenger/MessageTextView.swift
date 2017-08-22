//
//  MessageTextView.swift
//  SlackTextViewController-Swift
//
//  Created by Lebron on 21/08/2017.
//  Copyright © 2017 hacknocraft. All rights reserved.
//

import UIKit
import SlackTextViewController_Swift

class MessageTextView: SLKTextView {

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        // Do something
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        backgroundColor = .white

        placeholder = NSLocalizedString("Message", comment: "")
        placeholderColor = .lightGray
        pastableMediaTypes = .all

        layer.borderColor = UIColor(red: 217.0/255.0, green: 217.0/255.0, blue: 217.0/255.0, alpha: 1).cgColor
    }

}
