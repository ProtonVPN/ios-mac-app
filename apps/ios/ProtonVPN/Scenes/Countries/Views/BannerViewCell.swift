//
//  OneLineTableViewCell.swift
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

class BannerViewCell: UITableViewCell {

    @IBOutlet weak var roundedBackgroundView: UIView!
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var rightShevron: UIImageView!
    
    var viewModel: BannerViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            leftImageView.image = viewModel.leftIcon.image
            label.text = viewModel.text
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .backgroundColor()
        label.textColor = .normalTextColor()
        label.font = .systemFont(ofSize: 13)

        rightShevron.image = UIImage(systemName: "chevron.right")
        rightShevron.tintColor = .iconHint()

        roundedBackgroundView.backgroundColor = .secondaryBackgroundColor()
        roundedBackgroundView.layer.cornerRadius = 12
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionStyle = .none
    }
    
}
