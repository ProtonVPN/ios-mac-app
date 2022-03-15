//
//  Created on 02.03.2022.
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

import Foundation
import UIKit

final class PlaceholderItemView: UIView {

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var iconImageView: UIImageView!

    // MARK: - Properties

    var item: PlaceholderItem? {
        didSet {
            guard let item = item else {
                return
            }

            let title = NSAttributedString(string: "\(item.title): ", attributes: [NSAttributedString.Key.foregroundColor: colors.text, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .semibold)])
            let subtitle = NSAttributedString(string: item.subtitle, attributes: [NSAttributedString.Key.foregroundColor: colors.weakText, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15)])
            let text = NSMutableAttributedString()
            text.append(title)
            text.append(subtitle)

            titleLabel.attributedText = text
        }
    }

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        iconImageView.tintColor = colors.brand
    }
}
