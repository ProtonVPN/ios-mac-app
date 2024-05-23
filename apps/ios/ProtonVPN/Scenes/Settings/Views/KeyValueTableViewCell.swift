//
//  KeyValueTableViewCell.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit

class KeyValueTableViewCell: UITableViewCell {
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    
    var completionHandler: (() -> Void)?
    
    var viewModel: [String: String]? {
        didSet {
            if let viewModel = viewModel {
                keyLabel.text = viewModel.first?.key
                valueLabel.text = viewModel.first?.value
            }
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .secondaryBackgroundColor()
        keyLabel.textColor = .weakTextColor()
        valueLabel.textColor = .normalTextColor()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        selectionStyle = .none
    }
    
    func select() {
        completionHandler?()
    }
    
    public func showDisclosure(_ show: Bool) {
        if show {
            accessoryType = .disclosureIndicator
            stackView.spacing = 30 // Makes right label start at the middle of the view
        } else {
            accessoryType = .none
            stackView.spacing = 0
        }
    }
    
}
