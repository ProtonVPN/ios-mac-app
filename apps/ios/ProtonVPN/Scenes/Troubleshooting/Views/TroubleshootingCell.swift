//
//  TroubleshootingCell.swift
//  ProtonVPN - Created on 2020-04-24.
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

class TroubleshootingCell: UITableViewCell {
    
    // Views
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        titleLabel.textColor = .protonWhite()
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        
        descriptionLabel.isScrollEnabled = false // Enables auto-height
        descriptionLabel.isUserInteractionEnabled = true
        descriptionLabel.isEditable = false
        descriptionLabel.isSelectable = true
        
        descriptionLabel.textContainer.lineFragmentPadding = 0
        descriptionLabel.backgroundColor = backgroundColor
        descriptionLabel.tintColor = .protonGreen()
        descriptionLabel.linkTextAttributes = [
            .foregroundColor: UIColor.protonGreen(),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionStyle = .none
    }
    
    // MARK: - Public setters
    
    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
        }
    }
    
    var descriptionAttributed: NSAttributedString {
        get {
            return descriptionLabel.attributedText
        }
        set {
            let string = NSMutableAttributedString(attributedString: newValue)
            string.addTextAttributes(withColor: .protonFontLightGrey(), font: UIFont.systemFont(ofSize: 17), alignment: .left)
            descriptionLabel.attributedText = string
            descriptionLabel.sizeToFit()
        }
    }
    
}
