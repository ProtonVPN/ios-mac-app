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
import ProtonCore_UIFoundations

/// A two-line, detail accessory cell with a large image at the leading edge.
final class ImageTableViewCell: StandardTableViewCell {

    @IBOutlet weak var customImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func setupViews(inverted: Bool = false) {
        super.setupViews(inverted: inverted)
        backgroundColor = .secondaryBackgroundColor()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        subtitleLabel.numberOfLines = 0
    }

    func setup(
        title: NSAttributedString,
        subtitle: NSAttributedString,
        image: UIImage,
        handler: @escaping () -> Void
    ) {
        self.titleLabel.attributedText = title
        self.subtitleLabel.attributedText = subtitle
        self.customImageView.image = image
        self.completionHandler = handler
    }
}
