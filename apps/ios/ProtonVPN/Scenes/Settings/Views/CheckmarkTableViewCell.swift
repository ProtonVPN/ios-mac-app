//
//  CheckmarkTableViewCell.swift
//  ProtonVPN - Created on 12.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import UIKit

class CheckmarkTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    
    var completionHandler: (() -> Bool)?

    var isEnabled: Bool = true {
        didSet {
            setup(isEnabled: isEnabled)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        setup(isEnabled: isEnabled)
    }

    func setup(isEnabled: Bool) {
        backgroundColor = .secondaryBackgroundColor()
        tintColor = .normalTextColor()

        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .normalTextColor()
        label.alpha = isEnabled ? 1.0 : 0.25

        accessoryType = .none
    }
    
    func select() {
        if completionHandler?() ?? true {
            accessoryType = .checkmark
        }
    }
    
    func deselect() {
        accessoryType = .none
    }
    
}
