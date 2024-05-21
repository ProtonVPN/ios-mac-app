//
//  Created on 14/02/2023.
//
//  Copyright (c) 2023 Proton AG
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
import ProtonCoreUIFoundations

/// A two-line, detail cell with a large images at both ends.
final class ImageSubtitleImageTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var leadingImageView: UIImageView!
    @IBOutlet weak var trailingImageView: UIImageView!

    var selectionHandler: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    func select() {
        selectionHandler?()
    }

    func setupViews() {
        accessoryType = .none
        backgroundColor = .secondaryBackgroundColor()
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .weakTextColor()
        subtitleLabel.numberOfLines = 0
    }
}
