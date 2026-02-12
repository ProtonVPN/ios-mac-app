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

import Ergonomics
import ProtonCoreUIFoundations
import UIKit

/// A two-line, detail cell with a large images at both ends.
final class ImageSubtitleImageTableViewCell: UITableViewCell {
    let titleLabel = UILabel().with {
        $0.font = UIFont.systemFont(ofSize: 17)
        $0.textColor = .normalTextColor()
    }

    let subtitleLabel = UILabel().with {
        $0.font = .systemFont(ofSize: 13, weight: .regular)
        $0.textColor = .weakTextColor()
        $0.numberOfLines = 0
    }

    let leadingImageView = UIImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.contentMode = .scaleAspectFit
    }

    let trailingImageView = UIImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .iconWeak()
    }

    private let labelsStackView = UIStackView().with {
        $0.axis = .vertical
        $0.alignment = .fill
        $0.spacing = 4
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let contentStackView = UIStackView().with {
        $0.axis = .horizontal
        $0.alignment = .center
        $0.spacing = 16
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var selectionHandler: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        selectionStyle = .none
    }

    func select() {
        selectionHandler?()
    }

    private func setupLayout() {
        [titleLabel, subtitleLabel].forEach(labelsStackView.addArrangedSubview)
        [leadingImageView, labelsStackView, trailingImageView].forEach(contentStackView.addArrangedSubview)
        contentView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            leadingImageView.widthAnchor.constraint(equalToConstant: 50),
            leadingImageView.heightAnchor.constraint(equalTo: leadingImageView.widthAnchor),
            trailingImageView.widthAnchor.constraint(equalToConstant: 24),
            trailingImageView.heightAnchor.constraint(equalTo: trailingImageView.widthAnchor),
        ])
    }

    func setupViews() {
        accessoryType = .none
        backgroundColor = .secondaryBackgroundColor()
    }

    func setup(title: NSAttributedString, subtitle: NSAttributedString, leadingImage: UIImage, trailingImage: UIImage, handler: @escaping () -> Void) {
        titleLabel.attributedText = title
        subtitleLabel.attributedText = subtitle
        leadingImageView.image = leadingImage
        trailingImageView.image = trailingImage
        selectionHandler = handler
    }
}
