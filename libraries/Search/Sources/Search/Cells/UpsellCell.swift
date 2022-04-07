//
//  Created on 08.03.2022.
//
//  Copyright (c) 2022 Proton AG
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

import UIKit

final class UpsellCell: UITableViewCell {
    public static var identifier: String {
        return String(describing: self)
    }

    public static var nib: UINib {
        return UINib(nibName: identifier, bundle: Bundle.module)
    }

    // MARK: Outlets

    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var mainView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var chevronImageView: UIImageView!

    // MARK: Properties

    var numberOfCountries: Int = 0 {
        didSet {
            titleLabel.text = LocalizedString.searchUpsellTitle(numberOfCountries)
        }
    }

    // MARK: Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        baseViewStyle(self)
        baseViewStyle(contentView)
        upsellViewStyle(mainView)
        upsellSubtitleStyle(subtitleLabel)
        upsellTitleStyle(titleLabel)

        subtitleLabel.text = LocalizedString.searchUpsellSubtitle

        iconImageView.tintColor = UIColor(red: 167 / 255, green: 164 / 255, blue: 181 / 255, alpha: 1) // colors.iconWeak
        chevronImageView.tintColor = UIColor(red: 153 / 255, green: 150 / 255, blue: 147 / 255, alpha: 1) // colors.iconHint
    }
}
