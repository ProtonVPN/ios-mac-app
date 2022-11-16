//
//  Created on 16/11/2022.
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

final class InformationTableViewCell: UITableViewCell {
    struct ViewModel {
        let title: String
        let description: String
        let icon: UIImage
    }
    static var cellIdentifier: String {
        return String(describing: self)
    }
    @IBOutlet private weak var icon: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!

    var viewModel: ViewModel! {
        didSet {
            icon.image = viewModel.icon
            icon.tintColor = .normalTextColor()
            titleLabel.text = viewModel.title
            descriptionLabel.text = viewModel.description
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .normalTextColor()

        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .weakTextColor()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        icon.image = nil
        titleLabel.text = nil
        descriptionLabel.text = nil
    }
}
