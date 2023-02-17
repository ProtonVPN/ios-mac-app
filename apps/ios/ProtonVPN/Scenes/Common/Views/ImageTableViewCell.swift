//
//  Created on 17/02/2023.
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

/// A single line, disclosure accessory cell with a small image at the leading edge.
class ImageTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet private weak var _imageView: UIImageView!

    var completionHandler: (() -> Void)?

    override var imageView: UIImageView? {
        _imageView
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    func select() {
        completionHandler?()
    }

    func setupViews() {
        accessoryType = .disclosureIndicator
        backgroundColor = .secondaryBackgroundColor()
        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
    }

    func setup(title: NSAttributedString, image: UIImage, handler: @escaping () -> Void) {
        titleLabel.attributedText = title
        completionHandler = handler
        imageView?.image = image
    }
}
