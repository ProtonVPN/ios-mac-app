//
//  EditKeyValueTableViewCell.swift
//  ProtonVPN - Created on 20.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import UIKit

class TitleTextFieldTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = .protonWhite()
        
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.textColor = .protonWhite()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        selectionStyle = .none
    }
    
}
