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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        tintColor = .protonWhite()
        
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .protonWhite()
        
        accessoryType = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
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
