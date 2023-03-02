//
//  StandardTableViewCell.swift
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

class StandardTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet private weak var iconContainer: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    
    var completionHandler: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        selectionStyle = .none
    }

    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
            iconContainer.isHidden = icon == nil
        }
    }
    
    func select() {
        completionHandler?()
    }
    
    func invert() {
        setupViews(inverted: true)
    }
    
    func setupViews(inverted: Bool = false, icon: UIImage? = nil) {
        backgroundColor = .secondaryBackgroundColor()
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        subtitleLabel.font = UIFont.systemFont(ofSize: 17)

        self.icon = icon
        if !inverted {
            titleLabel.textColor = .normalTextColor()
            subtitleLabel.textColor = .weakTextColor()
        } else {
            titleLabel.textColor = .weakTextColor()
            subtitleLabel.textColor = .normalTextColor()
        }
        
    }
}
